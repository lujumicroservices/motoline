#pragma once

// UBX framing/demux for u-blox M9 (NEO-M9N, protocol 32.x).
// Layouts verified against the u-blox M9 interface description
// (NAV-PVT 92 B, NAV-SAT 8+12*n B, NAV-DOP 18 B, ACK 2 B, MON-VER 40+30*n B).
// NMEA bytes pass through untouched so TinyGPS keeps working on the same UART.

#include <Arduino.h>
#include <cstring>

namespace riderlab {

struct UbxPvt {
  uint32_t iTOW = 0;
  uint16_t year = 0;
  uint8_t month = 0, day = 0, hour = 0, min = 0, sec = 0, valid = 0;
  uint32_t tAcc = 0;
  int32_t nano = 0;
  uint8_t fixType = 0, flags = 0, flags2 = 0, numSV = 0;
  int32_t lon = 0, lat = 0, height = 0, hMSL = 0;
  uint32_t hAcc = 0, vAcc = 0;
  int32_t velN = 0, velE = 0, velD = 0, gSpeed = 0, headMot = 0;
  uint32_t sAcc = 0, headAcc = 0;
  uint16_t pDOP = 0, flags3 = 0;
  int64_t rxUs = 0;  // esp_timer at frame end

  bool gnssFixOk() const { return flags & 0x01; }
  bool diffSoln() const { return flags & 0x02; }
  uint8_t carrSoln() const { return (flags >> 6) & 0x03; }
  bool invalidLlh() const { return flags3 & 0x0001; }
  bool timeOk() const { return (valid & 0x07) == 0x07; }  // date+time+fullyResolved
  double latDeg() const { return lat * 1e-7; }
  double lonDeg() const { return lon * 1e-7; }
  double hEll() const { return height * 1e-3; }
  double hMsl() const { return hMSL * 1e-3; }
  float hAccM() const { return hAcc * 1e-3f; }
  float vAccM() const { return vAcc * 1e-3f; }
  bool good3d() const { return fixType == 3 && gnssFixOk() && !invalidLlh(); }
};

struct UbxSatBlock {
  uint8_t gnssId, svId, cno;
  int8_t elev;
  int16_t azim, prRes;
  uint32_t flags;
  bool used() const { return flags & 0x08; }
  uint8_t quality() const { return flags & 0x07; }
};

struct UbxSat {
  static constexpr int kMax = 64;
  uint32_t iTOW = 0;
  uint8_t numSvs = 0;  // stored (<= kMax)
  uint8_t used = 0;
  uint8_t usedByGnss[8] = {};  // index = gnssId (0 GPS,1 SBAS,2 GAL,3 BDS,5 QZSS,6 GLO)
  float meanCnoUsed = 0;
  uint32_t usedHash = 0;  // FNV-1a over sorted (gnssId<<8|svId) of used SVs
  int64_t rxUs = 0;
  UbxSatBlock sv[kMax];
};

struct UbxDop {
  uint32_t iTOW = 0;
  uint16_t g = 0, p = 0, t = 0, v = 0, h = 0, n = 0, e = 0;  // *0.01
  int64_t rxUs = 0;
};

class UbxParser {
 public:
  enum Result : uint8_t { kNone = 0, kPassNmea = 1, kFrame = 2 };

  // Returns kPassNmea when the byte belongs to the ASCII stream.
  Result feed(uint8_t b, int64_t nowUs) {
    switch (st_) {
      case 0:
        if (b == 0xB5) {
          st_ = 1;
          return kNone;
        }
        return kPassNmea;
      case 1:
        if (b == 0x62) {
          st_ = 2;
          return kNone;
        }
        st_ = 0;
        return feed(b, nowUs);
      case 2:
        cls_ = b;
        ckA_ = ckB_ = 0;
        ck(b);
        st_ = 3;
        return kNone;
      case 3:
        id_ = b;
        ck(b);
        st_ = 4;
        return kNone;
      case 4:
        len_ = b;
        ck(b);
        st_ = 5;
        return kNone;
      case 5:
        len_ |= (uint16_t)b << 8;
        ck(b);
        pos_ = 0;
        if (len_ > sizeof(buf_)) {
          overflow_++;
          st_ = 0;
          return kNone;
        }
        st_ = len_ ? 6 : 7;
        return kNone;
      case 6:
        buf_[pos_++] = b;
        ck(b);
        if (pos_ >= len_) st_ = 7;
        return kNone;
      case 7:
        st_ = (b == ckA_) ? 8 : 0;
        if (st_ == 0) bad_++;
        return kNone;
      case 8:
        st_ = 0;
        if (b != ckB_) {
          bad_++;
          return kNone;
        }
        ok_++;
        lastOkUs_ = nowUs;
        dispatch(nowUs);
        return kFrame;
    }
    st_ = 0;
    return kNone;
  }

  // --- latest decoded messages + "new" flags ---
  bool takePvt() { return take(newPvt_); }
  bool takeSat() { return take(newSat_); }
  bool takeDop() { return take(newDop_); }
  const UbxPvt& pvt() const { return pvt_; }
  const UbxSat& sat() const { return sat_; }
  const UbxDop& dop() const { return dop_; }

  // ACK tracking for one outstanding command.
  void expectAck(uint8_t cls, uint8_t id) {
    ackCls_ = cls;
    ackId_ = id;
    ackState_ = 0;
  }
  int ackState() const { return ackState_; }  // 0 pending, 1 ACK, -1 NAK

  bool monVerSeen() const { return monVer_; }
  void clearMonVer() { monVer_ = false; }
  const char* fwVer() const { return fwVer_; }

  bool valgetSeen() const { return valget_; }
  void clearValget() { valget_ = false; }
  // Returns value bytes of key in last VALGET response (or -1 if absent).
  int valgetU8(uint32_t key) const {
    if (valLen_ < 4) return -1;
    size_t i = 4;
    while (i + 4 < valLen_) {
      uint32_t k;
      memcpy(&k, valBuf_ + i, 4);
      const uint8_t sz = sizeFor(k);
      if (sz == 0) return -1;
      if (k == key) return valBuf_[i + 4];
      i += 4 + sz;
    }
    return -1;
  }

  uint32_t okFrames() const { return ok_; }
  uint32_t badFrames() const { return bad_; }
  uint32_t overflows() const { return overflow_; }
  int64_t lastOkUs() const { return lastOkUs_; }

  static uint8_t sizeFor(uint32_t key) {
    switch ((key >> 28) & 0x07) {
      case 1:
      case 2:
        return 1;
      case 3:
        return 2;
      case 4:
        return 4;
      case 5:
        return 8;
    }
    return 0;
  }

 private:
  static bool take(bool& f) {
    const bool r = f;
    f = false;
    return r;
  }
  void ck(uint8_t b) {
    ckA_ = (uint8_t)(ckA_ + b);
    ckB_ = (uint8_t)(ckB_ + ckA_);
  }
  template <typename T>
  T rd(size_t off) const {
    T v;
    memcpy(&v, buf_ + off, sizeof(T));
    return v;
  }

  void dispatch(int64_t nowUs) {
    if (cls_ == 0x01 && id_ == 0x07 && len_ >= 92) {
      UbxPvt& p = pvt_;
      p.iTOW = rd<uint32_t>(0);
      p.year = rd<uint16_t>(4);
      p.month = buf_[6];
      p.day = buf_[7];
      p.hour = buf_[8];
      p.min = buf_[9];
      p.sec = buf_[10];
      p.valid = buf_[11];
      p.tAcc = rd<uint32_t>(12);
      p.nano = rd<int32_t>(16);
      p.fixType = buf_[20];
      p.flags = buf_[21];
      p.flags2 = buf_[22];
      p.numSV = buf_[23];
      p.lon = rd<int32_t>(24);
      p.lat = rd<int32_t>(28);
      p.height = rd<int32_t>(32);
      p.hMSL = rd<int32_t>(36);
      p.hAcc = rd<uint32_t>(40);
      p.vAcc = rd<uint32_t>(44);
      p.velN = rd<int32_t>(48);
      p.velE = rd<int32_t>(52);
      p.velD = rd<int32_t>(56);
      p.gSpeed = rd<int32_t>(60);
      p.headMot = rd<int32_t>(64);
      p.sAcc = rd<uint32_t>(68);
      p.headAcc = rd<uint32_t>(72);
      p.pDOP = rd<uint16_t>(76);
      p.flags3 = rd<uint16_t>(78);
      p.rxUs = nowUs;
      newPvt_ = true;
    } else if (cls_ == 0x01 && id_ == 0x35 && len_ >= 8) {
      UbxSat& s = sat_;
      s.iTOW = rd<uint32_t>(0);
      int n = buf_[5];
      if ((size_t)(8 + 12 * n) > len_) n = (len_ - 8) / 12;
      if (n > UbxSat::kMax) n = UbxSat::kMax;
      s.numSvs = (uint8_t)n;
      s.used = 0;
      memset(s.usedByGnss, 0, sizeof(s.usedByGnss));
      uint16_t keys[UbxSat::kMax];
      int nk = 0;
      uint32_t cnoSum = 0;
      for (int i = 0; i < n; ++i) {
        const size_t o = 8 + 12 * i;
        UbxSatBlock& b = s.sv[i];
        b.gnssId = buf_[o];
        b.svId = buf_[o + 1];
        b.cno = buf_[o + 2];
        b.elev = (int8_t)buf_[o + 3];
        b.azim = rd<int16_t>(o + 4);
        b.prRes = rd<int16_t>(o + 6);
        b.flags = rd<uint32_t>(o + 8);
        if (b.used()) {
          s.used++;
          if (b.gnssId < 8) s.usedByGnss[b.gnssId]++;
          cnoSum += b.cno;
          keys[nk++] = (uint16_t)((b.gnssId << 8) | b.svId);
        }
      }
      for (int i = 1; i < nk; ++i) {  // insertion sort (<= 64)
        const uint16_t k = keys[i];
        int j = i - 1;
        while (j >= 0 && keys[j] > k) {
          keys[j + 1] = keys[j];
          --j;
        }
        keys[j + 1] = k;
      }
      uint32_t h = 2166136261u;
      for (int i = 0; i < nk; ++i) {
        h = (h ^ (keys[i] >> 8)) * 16777619u;
        h = (h ^ (keys[i] & 0xFF)) * 16777619u;
      }
      s.usedHash = h;
      s.meanCnoUsed = nk ? (float)cnoSum / nk : 0;
      s.rxUs = nowUs;
      newSat_ = true;
    } else if (cls_ == 0x01 && id_ == 0x04 && len_ >= 18) {
      dop_.iTOW = rd<uint32_t>(0);
      dop_.g = rd<uint16_t>(4);
      dop_.p = rd<uint16_t>(6);
      dop_.t = rd<uint16_t>(8);
      dop_.v = rd<uint16_t>(10);
      dop_.h = rd<uint16_t>(12);
      dop_.n = rd<uint16_t>(14);
      dop_.e = rd<uint16_t>(16);
      dop_.rxUs = nowUs;
      newDop_ = true;
    } else if (cls_ == 0x05 && len_ >= 2) {
      if (buf_[0] == ackCls_ && buf_[1] == ackId_) ackState_ = (id_ == 0x01) ? 1 : -1;
    } else if (cls_ == 0x0A && id_ == 0x04 && len_ >= 40) {
      monVer_ = true;
      fwVer_[0] = 0;
      for (size_t o = 40; o + 30 <= len_; o += 30) {
        char ext[31];
        memcpy(ext, buf_ + o, 30);
        ext[30] = 0;
        if (strncmp(ext, "FWVER=", 6) == 0 || strncmp(ext, "PROTVER=", 8) == 0) {
          if (fwVer_[0]) strncat(fwVer_, " ", sizeof(fwVer_) - strlen(fwVer_) - 1);
          strncat(fwVer_, ext, sizeof(fwVer_) - strlen(fwVer_) - 1);
        }
      }
    } else if (cls_ == 0x06 && id_ == 0x8B) {
      valLen_ = len_ > sizeof(valBuf_) ? sizeof(valBuf_) : len_;
      memcpy(valBuf_, buf_, valLen_);
      valget_ = true;
    }
  }

  uint8_t st_ = 0, cls_ = 0, id_ = 0, ckA_ = 0, ckB_ = 0;
  uint16_t len_ = 0, pos_ = 0;
  uint8_t buf_[8 + 12 * 72];
  UbxPvt pvt_;
  UbxSat sat_;
  UbxDop dop_;
  bool newPvt_ = false, newSat_ = false, newDop_ = false;
  uint8_t ackCls_ = 0, ackId_ = 0;
  volatile int ackState_ = 0;
  bool monVer_ = false;
  char fwVer_[64] = {};
  bool valget_ = false;
  uint8_t valBuf_[128];
  size_t valLen_ = 0;
  uint32_t ok_ = 0, bad_ = 0, overflow_ = 0;
  int64_t lastOkUs_ = 0;
};

}  // namespace riderlab
