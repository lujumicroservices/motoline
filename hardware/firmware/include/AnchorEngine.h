#pragma once

// ANCHOR (reference station) live engine:
//  - Welford mean/std of E/N/U (local tangent plane at first good fix) for good
//    fixes (3D, gnssFixOK, hAcc <= ANCHOR_MAX_HACC_M, numSV >= ANCHOR_MIN_SV)
//    after a stabilization period and outside IMU-disturbed intervals.
//  - 1 Hz ring buffer (10 min) for robust medians (last 60 s and full window).
//  - Per-epoch error vs REF antenna position (ref mark + ANT_H) in E/N/U.
//  - READY when converged; IMU bump/move detection with invalid intervals.
#include <Arduino.h>
#include <algorithm>
#include <cmath>
#include <cstring>

#include "HardwareConfig.h"
#include "RoleConfig.h"
#include "UbxParser.h"

namespace riderlab {

struct Enu {
  double e = 0, n = 0, u = 0;
};

class LocalFrame {
 public:
  void set(double lat, double lon, double h) {
    lat0_ = lat;
    lon0_ = lon;
    h0_ = h;
    const double a = 6378137.0, f = 1.0 / 298.257223563, e2 = f * (2 - f);
    const double s = sin(lat * DEG_TO_RAD);
    const double w = sqrt(1 - e2 * s * s);
    rn_ = a / w;
    rm_ = a * (1 - e2) / (w * w * w);
    coslat_ = cos(lat * DEG_TO_RAD);
    ok_ = true;
  }
  bool ok() const { return ok_; }
  Enu toEnu(double lat, double lon, double h) const {
    Enu r;
    r.n = (lat - lat0_) * DEG_TO_RAD * (rm_ + h0_);
    r.e = (lon - lon0_) * DEG_TO_RAD * (rn_ + h0_) * coslat_;
    r.u = h - h0_;
    return r;
  }
  void toLlh(const Enu& v, double& lat, double& lon, double& h) const {
    lat = lat0_ + v.n / (rm_ + h0_) * RAD_TO_DEG;
    lon = lon0_ + v.e / ((rn_ + h0_) * coslat_) * RAD_TO_DEG;
    h = h0_ + v.u;
  }

 private:
  double lat0_ = 0, lon0_ = 0, h0_ = 0, rn_ = 1, rm_ = 1, coslat_ = 1;
  bool ok_ = false;
};

struct AnchorEvent {
  char kind[12];
  float value;
};

struct InvalidSpan {
  double towStart = -1, towEnd = -1;
  char reason[8] = "";
};

class AnchorEngine {
 public:
  // ---------------- GNSS ----------------
  struct EpochOut {
    bool good = false;       // passes fix gates
    bool valid = false;      // good && !disturbed && !stabilizing
    bool stab = false;
    bool refOk = false;      // d* relative to REF (else relative to mean)
    Enu d;                   // antenna error (m)
  };

  EpochOut onPvt(const UbxPvt& p, const RefPoint& ref, float antH, uint32_t nowMs) {
    EpochOut o;
    lastPvtMs_ = nowMs;
    lastFix_ = p.fixType;
    lastSv_ = p.numSV;
    lastHacc_ = p.hAccM();
    lastVacc_ = p.vAccM();
    lastPdop_ = p.pDOP * 0.01f;
    sep_ = p.hMsl() - p.hEll();
    o.good = p.good3d() && p.hAccM() <= ANCHOR_MAX_HACC_M && p.numSV >= ANCHOR_MIN_SV;
    if (!p.good3d()) return o;
    if (!frame_.ok()) frame_.set(p.latDeg(), p.lonDeg(), p.hEll());
    const Enu x = frame_.toEnu(p.latDeg(), p.lonDeg(), p.hEll());
    last_ = x;
    if (o.good && firstGoodMs_ == 0) firstGoodMs_ = nowMs;
    o.stab = firstGoodMs_ == 0 || (nowMs - firstGoodMs_) < ANCHOR_STAB_S * 1000UL;
    o.valid = o.good && !o.stab && !disturbed(nowMs);
    if (o.valid) {
      addWelford(x);
      const uint32_t sec = p.iTOW / 1000;
      if (sec != lastRingSec_) {
        lastRingSec_ = sec;
        pushRing(x);
      }
    }
    updateRef(ref, antH);
    if (refValid_) {
      o.refOk = true;
      o.d = {x.e - refEnu_.e, x.n - refEnu_.n, x.u - refEnu_.u};
    } else if (n_ > 0) {
      o.d = {x.e - mean_[0], x.n - mean_[1], x.u - mean_[2]};
    }
    lastD_ = o.d;
    lastRefOk_ = o.refOk;
    return o;
  }

  void updateRef(const RefPoint& ref, float antH) {
    refValid_ = false;
    if (!ref.set || !frame_.ok()) return;
    // Height domain = ellipsoidal; MSL refs converted with receiver geoid sep.
    const double hAntEll = ref.h + antH - (ref.hMsl ? sep_ : 0.0);
    refEnu_ = frame_.toEnu(ref.lat, ref.lon, hAntEll);
    refValid_ = true;
  }

  // ---------------- stats ----------------
  uint32_t n() const { return n_; }
  bool haveMean() const { return n_ > 0; }
  Enu mean() const { return {mean_[0], mean_[1], mean_[2]}; }
  Enu stdev() const {
    if (n_ < 2) return {0, 0, 0};
    return {sqrt(m2_[0] / (n_ - 1)), sqrt(m2_[1] / (n_ - 1)), sqrt(m2_[2] / (n_ - 1))};
  }
  void meanLlh(double& lat, double& lon, double& hEll) const {
    frame_.toLlh(mean(), lat, lon, hEll);
  }
  double sep() const { return sep_; }
  Enu offsetVsRef() const {
    return {mean_[0] - refEnu_.e, mean_[1] - refEnu_.n, mean_[2] - refEnu_.u};
  }
  bool refValid() const { return refValid_; }
  bool median(int lastN, Enu& out) const {
    const int cnt = ringCount_ < lastN || lastN <= 0 ? ringCount_ : lastN;
    if (cnt < 5) return false;
    float tmp[kRing];
    for (int axis = 0; axis < 3; ++axis) {
      for (int i = 0; i < cnt; ++i) {
        const int idx = (ringHead_ - 1 - i + kRing) % kRing;
        tmp[i] = ring_[axis][idx];
      }
      std::nth_element(tmp, tmp + cnt / 2, tmp + cnt);
      const double m = tmp[cnt / 2];
      if (axis == 0) out.e = m;
      else if (axis == 1) out.n = m;
      else out.u = m;
    }
    return true;
  }
  // Horizontal |median(last 60 s) - mean|
  float drift60() const {
    Enu m;
    if (!median(60, m) || n_ == 0) return -1;
    return (float)hypot(m.e - mean_[0], m.n - mean_[1]);
  }

  uint32_t stabLeftS(uint32_t nowMs) const {
    if (firstGoodMs_ == 0) return ANCHOR_STAB_S;
    const uint32_t el = (nowMs - firstGoodMs_) / 1000;
    return el >= ANCHOR_STAB_S ? 0 : ANCHOR_STAB_S - el;
  }
  uint32_t avgElapsedS(uint32_t nowMs) const {
    return firstValidMs_ ? (nowMs - firstValidMs_) / 1000 : 0;
  }

  // READY: stabilized, enough samples, receiver happy, no recent disturbance,
  // mean no longer wandering. Returns a short reason when not ready.
  bool ready(uint32_t nowMs, const char** why) const {
    if (firstGoodMs_ == 0) return (*why = "sin fix bueno", false);
    if (stabLeftS(nowMs) > 0) return (*why = "estabilizando", false);
    if (n_ < 60 * GNSS_TARGET_HZ) return (*why = "pocas muestras", false);
    if (lastFix_ != 3) return (*why = "fix<3D", false);
    if (lastHacc_ > ANCHOR_READY_HACC_M) return (*why = "hAcc alto", false);
    if (lastSv_ < ANCHOR_READY_SV) return (*why = "pocos sat", false);
    if (lastBumpMs_ && nowMs - lastBumpMs_ < 60000) return (*why = "golpe <60s", false);
    if (moved_) return (*why = "MOVIDA", false);
    const float d = drift60();
    if (d < 0 || d > ANCHOR_READY_DRIFT_M) return (*why = "media deriva", false);
    *why = "";
    return true;
  }

  void resetAverage(uint32_t nowMs) {
    n_ = 0;
    memset(mean_, 0, sizeof(mean_));
    memset(m2_, 0, sizeof(m2_));
    ringCount_ = ringHead_ = 0;
    firstValidMs_ = 0;
    firstGoodMs_ = 0;  // restart stabilization
    moved_ = false;
    (void)nowMs;
  }

  // ---------------- IMU disturbance ----------------
  void onImu(float ax, float ay, float az, float gx, float gy, float gz, uint32_t nowMs,
             double tow) {
    const float amag = sqrtf(ax * ax + ay * ay + az * az);
    if (!imuInit_) {
      lp_[0] = ax;
      lp_[1] = ay;
      lp_[2] = az;
      imuInit_ = true;
      baseStartMs_ = nowMs;
    }
    const float alpha = 0.01f;  // ~1 s at 100 Hz
    for (int i = 0; i < 3; ++i) lp_[i] += alpha * ((i == 0 ? ax : i == 1 ? ay : az) - lp_[i]);
    imuSane_ = amag > 7.0f && amag < 12.5f;
    lastAmag_ = amag;
    if (!imuSane_) return;
    const float dx = ax - lp_[0], dy = ay - lp_[1], dz = az - lp_[2];
    const float dev = sqrtf(dx * dx + dy * dy + dz * dz);
    // Baseline (gravity + gyro bias) after 3 s quiet.
    if (!haveBase_) {
      if (dev > DIST_BUMP_MS2) {
        baseStartMs_ = nowMs;
        gbN_ = 0;
        gb_[0] = gb_[1] = gb_[2] = 0;
        gb2_ = 0;
        return;
      }
      gb_[0] += gx;
      gb_[1] += gy;
      gb_[2] += gz;
      gb2_ += gx * gx + gy * gy + gz * gz;
      gbN_++;
      if (nowMs - baseStartMs_ > 3000 && gbN_ > 50) {
        for (int i = 0; i < 3; ++i) {
          g0_[i] = lp_[i];
          gb_[i] /= gbN_;
        }
        const float meanSq = gb_[0] * gb_[0] + gb_[1] * gb_[1] + gb_[2] * gb_[2];
        const float var = gb2_ / gbN_ - meanSq;
        gyroSane_ = sqrtf(meanSq) < 10.0f * DEG_TO_RAD && var < sqf(2.0f * DEG_TO_RAD);
        haveBase_ = true;
        push("imu_base", gyroSane_ ? 1 : 0);
      }
      return;
    }
    float gdev = 0;
    if (gyroSane_) {
      const float ux = gx - gb_[0], uy = gy - gb_[1], uz = gz - gb_[2];
      gdev = sqrtf(ux * ux + uy * uy + uz * uz) * RAD_TO_DEG;
    }
    const bool bump = dev > DIST_BUMP_MS2 || (gyroSane_ && gdev > DIST_GYRO_DPS);
    if (bump) {
      if (!disturbed(nowMs)) {
        bumps_++;
        openSpan(tow, "bump");
        push("bump", dev);
      }
      lastBumpMs_ = nowMs;
      peakDev_ = std::max(peakDev_, dev);
    } else if (spanOpen_ && !disturbed(nowMs)) {
      closeSpan(tow);
    }
    // Tilt vs baseline (sustained 2 s) => anchor moved.
    const float dot = lp_[0] * g0_[0] + lp_[1] * g0_[1] + lp_[2] * g0_[2];
    const float nl = sqrtf(lp_[0] * lp_[0] + lp_[1] * lp_[1] + lp_[2] * lp_[2]);
    const float n0 = sqrtf(g0_[0] * g0_[0] + g0_[1] * g0_[1] + g0_[2] * g0_[2]);
    float c = (nl > 0 && n0 > 0) ? dot / (nl * n0) : 1;
    c = c > 1 ? 1 : (c < -1 ? -1 : c);
    tiltDeg_ = acosf(c) * RAD_TO_DEG;
    if (tiltDeg_ > DIST_TILT_DEG) {
      if (tiltSinceMs_ == 0) tiltSinceMs_ = nowMs;
      if (!moved_ && nowMs - tiltSinceMs_ > 2000) {
        moved_ = true;
        moves_++;
        lastBumpMs_ = nowMs;
        if (!spanOpen_) openSpan(tow, "move");
        else strncpy(spans_[(spanCount_ - 1) % kSpans].reason, "move", 7);
        push("moved", tiltDeg_);
        movedPending_ = true;
      }
    } else {
      tiltSinceMs_ = 0;
    }
  }

  // After a move: re-baseline when quiet again and restart averaging.
  bool takeMoved() {
    const bool r = movedPending_;
    movedPending_ = false;
    if (r) {
      for (int i = 0; i < 3; ++i) g0_[i] = lp_[i];
    }
    return r;
  }

  bool disturbed(uint32_t nowMs) const {
    return lastBumpMs_ != 0 && (nowMs - lastBumpMs_) < DIST_GUARD_MS;
  }
  bool moved() const { return moved_; }
  bool imuSane() const { return imuSane_; }
  bool imuBaseline() const { return haveBase_; }
  bool gyroSane() const { return gyroSane_; }
  float tiltDeg() const { return tiltDeg_; }
  float amag() const { return lastAmag_; }
  uint32_t bumps() const { return bumps_; }
  uint32_t moves() const { return moves_; }

  bool popEvent(AnchorEvent& ev) {
    if (evN_ == 0) return false;
    ev = ev_[0];
    for (int i = 1; i < evN_; ++i) ev_[i - 1] = ev_[i];
    evN_--;
    return true;
  }

  // ---------------- last epoch (UI) ----------------
  const Enu& lastD() const { return lastD_; }
  bool lastRefOk() const { return lastRefOk_; }
  uint8_t lastFix() const { return lastFix_; }
  uint8_t lastSv() const { return lastSv_; }
  float lastHacc() const { return lastHacc_; }
  float lastVacc() const { return lastVacc_; }
  float lastPdop() const { return lastPdop_; }

  // anchor_summary.json body.
  size_t summaryJson(char* out, size_t cap, const RefPoint& ref, float antH, uint32_t nowMs,
                     uint32_t sessionS, bool complete) const {
    double lat = 0, lon = 0, h = 0;
    if (n_) meanLlh(lat, lon, h);
    const Enu sd = stdev();
    Enu m60, mall;
    const bool h60 = median(60, m60);
    const bool hall = median(0, mall);
    const char* why = "";
    const bool rdy = ready(nowMs, &why);
    int o = snprintf(
        out, cap,
        "{\"schema\":\"riderlab_anchor_summary.v1\",\"complete\":%s,\"duration_s\":%lu,"
        "\"n\":%lu,\"avg_elapsed_s\":%lu,\"ready\":%s,\"not_ready\":\"%s\","
        "\"mean\":{\"lat\":%.9f,\"lon\":%.9f,\"h_ell\":%.3f,\"h_msl\":%.3f},"
        "\"std_m\":{\"e\":%.3f,\"n\":%.3f,\"u\":%.3f},"
        "\"median60_minus_mean_m\":{\"e\":%.3f,\"n\":%.3f,\"u\":%.3f,\"ok\":%s},"
        "\"median_all_minus_mean_m\":{\"e\":%.3f,\"n\":%.3f,\"u\":%.3f,\"ok\":%s},"
        "\"ant_h_m\":%.3f,",
        complete ? "true" : "false", (unsigned long)sessionS, (unsigned long)n_,
        (unsigned long)avgElapsedS(nowMs), rdy ? "true" : "false", why, lat, lon, h, h + sep_,
        sd.e, sd.n, sd.u, h60 ? m60.e - mean_[0] : 0, h60 ? m60.n - mean_[1] : 0,
        h60 ? m60.u - mean_[2] : 0, h60 ? "true" : "false", hall ? mall.e - mean_[0] : 0,
        hall ? mall.n - mean_[1] : 0, hall ? mall.u - mean_[2] : 0, hall ? "true" : "false",
        antH);
    if (o < 0 || (size_t)o >= cap) return 0;
    if (n_ == 0) {  // no valid average yet: null instead of zeros
      char* m = strstr(out, "\"mean\":{");
      char* e = m ? strstr(m, "},\"std_m\"") : nullptr;
      if (m && e) {
        const char* rep = "\"mean\":null";
        const size_t rl = strlen(rep);
        memmove(m + rl, e + 1, strlen(e + 1) + 1);
        memcpy(m, rep, rl);
        o = (int)strlen(out);
      }
    }
    if (ref.set) {
      const Enu off = offsetVsRef();
      o += snprintf(out + o, cap - o,
                    "\"ref\":{\"id\":\"%s\",\"lat\":%.9f,\"lon\":%.9f,\"h\":%.3f,\"h_type\":\"%s\","
                    "\"source\":\"%s\",\"sigma_m\":%.3f},"
                    "\"offset_vs_ref_m\":{\"e\":%.3f,\"n\":%.3f,\"u\":%.3f,\"valid\":%s},",
                    ref.id, ref.lat, ref.lon, ref.h, ref.hMsl ? "msl" : "ell", ref.source,
                    ref.sigma, n_ ? off.e : 0.0, n_ ? off.n : 0.0, n_ ? off.u : 0.0,
                    (refValid_ && n_) ? "true" : "false");
    } else {
      o += snprintf(out + o, cap - o, "\"ref\":null,");
    }
    o += snprintf(out + o, cap - o,
                  "\"imu\":{\"sane\":%s,\"gyro_sane\":%s,\"bumps\":%lu,\"moves\":%lu,"
                  "\"tilt_deg\":%.2f},\"invalid\":[",
                  imuSane_ ? "true" : "false", gyroSane_ ? "true" : "false",
                  (unsigned long)bumps_, (unsigned long)moves_, tiltDeg_);
    const int first = spanCount_ > kSpans ? spanCount_ - kSpans : 0;
    for (int i = first; i < spanCount_ && (size_t)o + 64 < cap; ++i) {
      const InvalidSpan& s = spans_[i % kSpans];
      o += snprintf(out + o, cap - o, "%s{\"tow_ms\":[%.0f,%.0f],\"reason\":\"%s\"}",
                    i == first ? "" : ",", s.towStart, s.towEnd, s.reason);
    }
    o += snprintf(out + o, cap - o, "],\"invalid_total\":%d}\n", spanCount_);
    return (size_t)o < cap ? (size_t)o : 0;
  }

 private:
  static constexpr int kRing = 600;
  static constexpr int kSpans = 24;
  static float sqf(float v) { return v * v; }

  void addWelford(const Enu& x) {
    if (n_ == 0) firstValidMs_ = millis();
    n_++;
    const double v[3] = {x.e, x.n, x.u};
    for (int i = 0; i < 3; ++i) {
      const double d = v[i] - mean_[i];
      mean_[i] += d / n_;
      m2_[i] += d * (v[i] - mean_[i]);
    }
  }
  void pushRing(const Enu& x) {
    ring_[0][ringHead_] = (float)x.e;
    ring_[1][ringHead_] = (float)x.n;
    ring_[2][ringHead_] = (float)x.u;
    ringHead_ = (ringHead_ + 1) % kRing;
    if (ringCount_ < kRing) ringCount_++;
  }
  void push(const char* kind, float v) {
    if (evN_ >= 8) return;
    strncpy(ev_[evN_].kind, kind, sizeof(ev_[0].kind) - 1);
    ev_[evN_].kind[sizeof(ev_[0].kind) - 1] = 0;
    ev_[evN_].value = v;
    evN_++;
  }
  void openSpan(double tow, const char* why) {
    InvalidSpan& s = spans_[spanCount_ % kSpans];
    s.towStart = tow;
    s.towEnd = -1;
    strncpy(s.reason, why, sizeof(s.reason) - 1);
    s.reason[sizeof(s.reason) - 1] = 0;
    spanCount_++;
    spanOpen_ = true;
  }
  void closeSpan(double tow) {
    if (!spanOpen_ || spanCount_ == 0) return;
    spans_[(spanCount_ - 1) % kSpans].towEnd = tow;
    spanOpen_ = false;
    push("bump_end", 0);
  }

  LocalFrame frame_;
  uint32_t n_ = 0;
  double mean_[3] = {0, 0, 0}, m2_[3] = {0, 0, 0};
  float ring_[3][kRing];
  int ringHead_ = 0, ringCount_ = 0;
  uint32_t lastRingSec_ = 0xFFFFFFFF;
  uint32_t firstGoodMs_ = 0, firstValidMs_ = 0, lastPvtMs_ = 0;
  Enu last_, lastD_, refEnu_;
  bool refValid_ = false, lastRefOk_ = false;
  double sep_ = 0;
  uint8_t lastFix_ = 0, lastSv_ = 0;
  float lastHacc_ = 99, lastVacc_ = 99, lastPdop_ = 99;
  // IMU
  bool imuInit_ = false, imuSane_ = false, haveBase_ = false, gyroSane_ = false;
  float lp_[3] = {0, 0, 0}, g0_[3] = {0, 0, 0}, gb_[3] = {0, 0, 0}, gb2_ = 0;
  uint32_t gbN_ = 0, baseStartMs_ = 0, lastBumpMs_ = 0, tiltSinceMs_ = 0;
  float tiltDeg_ = 0, peakDev_ = 0, lastAmag_ = 0;
  bool moved_ = false, movedPending_ = false, spanOpen_ = false;
  uint32_t bumps_ = 0, moves_ = 0;
  InvalidSpan spans_[kSpans];
  int spanCount_ = 0;
  AnchorEvent ev_[8];
  int evN_ = 0;
};

}  // namespace riderlab
