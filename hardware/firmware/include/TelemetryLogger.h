#pragma once

#include <Arduino.h>
#include <SD.h>
#include <esp_timer.h>

#include "HardwareConfig.h"
#include "EventLog.h"
#include "UbxParser.h"
#include "BaroService.h"

namespace riderlab {

// Session = /riderlab/sessions/<id>/
//   manifest.json   (rewritten every 30 s + at stop; complete=false until stop)
//   gnss.ndjson     legacy schema (ingest), now fed from NAV-PVT when available
//   imu.ndjson      + tow (GPS time of week, ms)
//   baro.ndjson     + pa, temp_c, alt_m, tow, gnss hMSL/height/vAcc
//   quality.ndjson  health counters
//   pvt.ndjson      UBX-NAV-PVT every epoch (both roles)
//   sat.ndjson      UBX-NAV-SAT ~1 Hz (both roles)
//   dop.ndjson      UBX-NAV-DOP ~1 Hz
//   marks.ndjson    events (coloc, checkpoints, bumps, ref changes...)
//   anchor_err.ndjson + anchor_summary.json (anchor role)
class TelemetryLogger {
 public:
  bool beginSd() {
    // Basic TF slot: must pass CS=GPIO4. Plain SD.begin() often fails here.
    const uint32_t speeds[] = {SD_SPI_HZ, 10000000UL, 4000000UL, 1000000UL};
    bool ok = false;
    for (uint32_t hz : speeds) {
      wdtFeed();
      SD.end();
      delay(20);
      if (SD.begin(SD_CS_PIN, SPI, hz, "/sd", SD_MAX_FILES)) {  // 0.5.4: see HardwareConfig.h
        ok = true;
        hz_ = hz;
        slots_ = SD_MAX_FILES;
        break;
      }
    }
    if (!ok) {
      err_ = "SD.begin failed";
      loge("sd", "begin failed");
      return false;
    }
    if (!SD.exists("/riderlab")) SD.mkdir("/riderlab");
    if (!SD.exists("/riderlab/sessions")) SD.mkdir("/riderlab/sessions");
    sdOk_ = true;
    err_ = "ok";
    return true;
  }

  // 0.6.9e: the FAT mount reserves 6.2 KB + slots x 4.14 KB in ONE block (~47 KB at 10).
  // Uploading needs <= 2 files open at a time, so it remounts with few slots to give
  // mbedTLS (2 x 16.7 KB records + handshake) ~29 KB back. Caller guarantees that no
  // File is open. Tries slots down to minSlots (the heap after Wi-Fi may miss the full
  // block by a few hundred bytes); below that falls back to the small mount -> false.
  bool remountSd(uint8_t slots, uint8_t minSlots) {
    if (!sdOk_ || recording_ || slots == slots_) return sdOk_;
    if (minSlots > slots) minSlots = slots;
    if (slots_ >= minSlots && slots_ <= slots) return true;
    SD.end();
    delay(5);
    for (uint8_t s = slots; s >= minSlots && s > 0; --s) {
      if (SD.begin(SD_CS_PIN, SPI, hz_, "/sd", s)) {
        slots_ = s;
        return true;
      }
    }
    if (minSlots > kSmallSlots && SD.begin(SD_CS_PIN, SPI, hz_, "/sd", kSmallSlots)) {
      slots_ = kSmallSlots;
      return false;
    }
    sdOk_ = false;
    slots_ = 0;
    err_ = "SD remount failed";
    return false;
  }
  static constexpr uint8_t kSmallSlots = 3;
  uint8_t sdSlots() const { return slots_; }

  bool sdOk() const { return sdOk_; }
  const String& err() const { return err_; }
  bool recording() const { return recording_; }
  const String& sessionId() const { return sessionId_; }
  const String& sessionDir() const { return sessionDir_; }

  // extraJson: comma-prefixed JSON members appended to manifest (role, ref...).
  void setManifestExtra(const String& extraJson) { extra_ = extraJson; }

  bool startSession(const char* deviceId, bool anchor) {
    if (!sdOk_ || recording_) return false;
    sessionId_ = makeSessionId();
    sessionDir_ = String("/riderlab/sessions/") + sessionId_;
    if (!SD.mkdir(sessionDir_)) {
      err_ = "mkdir session failed";
      loge("rec", "mkdir failed");
      return false;
    }
    anchor_ = anchor;
    gnss_ = SD.open(sessionDir_ + "/gnss.ndjson", FILE_WRITE);
    imu_ = SD.open(sessionDir_ + "/imu.ndjson", FILE_WRITE);
    baro_ = SD.open(sessionDir_ + "/baro.ndjson", FILE_WRITE);
    quality_ = SD.open(sessionDir_ + "/quality.ndjson", FILE_WRITE);
    pvt_ = SD.open(sessionDir_ + "/pvt.ndjson", FILE_WRITE);
    sat_ = SD.open(sessionDir_ + "/sat.ndjson", FILE_WRITE);
    dop_ = SD.open(sessionDir_ + "/dop.ndjson", FILE_WRITE);
    marks_ = SD.open(sessionDir_ + "/marks.ndjson", FILE_WRITE);
    if (anchor_) aerr_ = SD.open(sessionDir_ + "/anchor_err.ndjson", FILE_WRITE);
    if (!gnss_ || !imu_ || !baro_ || !quality_ || !pvt_ || !sat_ || !dop_ || !marks_ ||
        (anchor_ && !aerr_)) {
      err_ = "open ndjson failed";
      loge("rec", "open ndjson failed");
      closeFiles();
      return false;
    }
    startedUs_ = esp_timer_get_time();
    deviceId_ = deviceId ? deviceId : "unknown";
    gnssCount_ = imuCount_ = baroCount_ = pvtCount_ = satCount_ = aerrCount_ = markCount_ = 0;
    flushCounter_ = 0;
    lastFlushMs_ = lastManifestMs_ = millis();
    recording_ = true;
    writeManifest(false);
    gLog.logf(LogLvl::Info, "rec", "start %s role=%s", sessionId_.c_str(),
              anchor_ ? "anchor" : "rider");
    return true;
  }

  void stopSession() {
    if (!recording_) return;
    recording_ = false;
    endedUs_ = esp_timer_get_time();
    flushAll();
    wdtFeed();
    closeFiles();
    wdtFeed();
    writeManifest(true);
    wdtFeed();
    gLog.logf(LogLvl::Info, "rec", "stop %s gnss=%lu pvt=%lu imu=%lu", sessionId_.c_str(),
              (unsigned long)gnssCount_, (unsigned long)pvtCount_, (unsigned long)imuCount_);
  }

  // Periodic: time-based flush (power-loss resilience) + manifest refresh.
  void tick(uint32_t nowMs) {
    if (!recording_) return;
    if (nowMs - lastFlushMs_ >= FLUSH_EVERY_MS) {
      lastFlushMs_ = nowMs;
      flushAll();
    }
    if (nowMs - lastManifestMs_ >= MANIFEST_EVERY_MS) {
      lastManifestMs_ = nowMs;
      writeManifest(false);
    }
  }

  void logGnss(uint32_t ppsSeq, double lat, double lng, double alt, double speedMps,
               double heading, double accM, int sats, double hdop, uint32_t utcMs) {
    logGnssAt(esp_timer_get_time(), ppsSeq, lat, lng, alt, speedMps, heading, accM, sats, hdop,
              utcMs);
  }
  // 0.6.3-auto: same row with an explicit t_us (pre-roll replay keeps the original receive time).
  void logGnssAt(int64_t t, uint32_t ppsSeq, double lat, double lng, double alt, double speedMps,
                 double heading, double accM, int sats, double hdop, uint32_t utcMs) {
    if (!recording_ || !gnss_) return;
    gnss_.printf(
        "{\"t_us\":%lld,\"pps_seq\":%lu,\"lat\":%.7f,\"lng\":%.7f,\"alt\":%.2f,"
        "\"speed_mps\":%.3f,\"heading\":%.2f,\"acc_m\":%.2f,\"sats\":%d,"
        "\"hdop\":%.2f,\"utc_ms\":%lu}\n",
        (long long)t, (unsigned long)ppsSeq, lat, lng, alt, speedMps, heading, accM,
        sats, hdop, (unsigned long)utcMs);
    gnssCount_++;
    maybeFlush();
  }

  void logImu(uint32_t ppsSeq, float ax, float ay, float az, float gx, float gy,
              float gz, double tow) {
    if (!recording_ || !imu_) return;
    const int64_t t = esp_timer_get_time();
    imu_.printf(
        "{\"t_us\":%lld,\"pps_seq\":%lu,\"ax\":%.5f,\"ay\":%.5f,\"az\":%.5f,"
        "\"gx\":%.6f,\"gy\":%.6f,\"gz\":%.6f,\"tow\":%.1f}\n",
        (long long)t, (unsigned long)ppsSeq, ax, ay, az, gx, gy, gz, tow);
    imuCount_++;
    maybeFlush();
  }

  // hpa kept for the legacy reader; tow aligns both units; gnss_* = latest PVT.
  void logBaro(uint32_t ppsSeq, const BaroSample& b, double tow, const char* tsrc,
               const UbxPvt* p, int32_t gnssAgeMs) {
    if (!recording_ || !baro_) return;
    if (p && gnssAgeMs >= 0 && gnssAgeMs < 2000 && p->fixType >= 3) {
      baro_.printf(
          "{\"t_us\":%lld,\"pps_seq\":%lu,\"hpa\":%.3f,\"pa\":%.2f,\"temp_c\":%.2f,"
          "\"alt_m\":%.2f,\"n\":%u,\"tow\":%.1f,\"tsrc\":\"%s\",\"gnss_hmsl\":%.3f,"
          "\"gnss_h\":%.3f,\"vacc\":%.3f,\"gnss_age_ms\":%ld}\n",
          (long long)b.midUs, (unsigned long)ppsSeq, b.pa / 100.0, b.pa, b.tempC, b.altM,
          (unsigned)b.n, tow, tsrc, p->hMsl(), p->hEll(), p->vAccM(), (long)gnssAgeMs);
    } else {
      baro_.printf(
          "{\"t_us\":%lld,\"pps_seq\":%lu,\"hpa\":%.3f,\"pa\":%.2f,\"temp_c\":%.2f,"
          "\"alt_m\":%.2f,\"n\":%u,\"tow\":%.1f,\"tsrc\":\"%s\"}\n",
          (long long)b.midUs, (unsigned long)ppsSeq, b.pa / 100.0, b.pa, b.tempC, b.altM,
          (unsigned)b.n, tow, tsrc);
    }
    baroCount_++;
    maybeFlush();
  }

  void logPvt(const UbxPvt& p, uint32_t ppsSeq) {
    if (!recording_ || !pvt_) return;
    pvt_.printf(
        "{\"t_us\":%lld,\"tow\":%lu,\"utc\":\"%04u-%02u-%02uT%02u:%02u:%02u\",\"ns\":%ld,"
        "\"tv\":%u,\"tacc\":%lu,\"fix\":%u,\"ok\":%u,\"diff\":%u,\"carr\":%u,\"sv\":%u,"
        "\"lat\":%.7f,\"lon\":%.7f,\"h\":%.3f,\"msl\":%.3f,\"hacc\":%.3f,\"vacc\":%.3f,"
        "\"vn\":%.3f,\"ve\":%.3f,\"vd\":%.3f,\"gs\":%.3f,\"hdg\":%.2f,\"sacc\":%.3f,"
        "\"pdop\":%.2f,\"inv\":%u,\"pps\":%lu}\n",
        (long long)p.rxUs, (unsigned long)p.iTOW, p.year, p.month, p.day, p.hour, p.min, p.sec,
        (long)p.nano, (unsigned)p.valid, (unsigned long)p.tAcc, (unsigned)p.fixType,
        (unsigned)p.gnssFixOk(), (unsigned)p.diffSoln(), (unsigned)p.carrSoln(),
        (unsigned)p.numSV, p.latDeg(), p.lonDeg(), p.hEll(), p.hMsl(), p.hAccM(), p.vAccM(),
        p.velN * 1e-3, p.velE * 1e-3, p.velD * 1e-3, p.gSpeed * 1e-3, p.headMot * 1e-5,
        p.sAcc * 1e-3, p.pDOP * 0.01, (unsigned)p.invalidLlh(), (unsigned long)ppsSeq);
    pvtCount_++;
    maybeFlush();
  }

  void logSat(const UbxSat& s) {
    if (!recording_ || !sat_) return;
    sat_.printf(
        "{\"t_us\":%lld,\"tow\":%lu,\"n\":%u,\"used\":%u,\"hash\":\"%08lx\",\"cno_used\":%.1f,"
        "\"sv\":[",
        (long long)s.rxUs, (unsigned long)s.iTOW, (unsigned)s.numSvs, (unsigned)s.used,
        (unsigned long)s.usedHash, s.meanCnoUsed);
    for (int i = 0; i < s.numSvs; ++i) {
      const UbxSatBlock& b = s.sv[i];
      // [gnssId, svId, cno, elev, azim, flags, prRes_dm]
      sat_.printf("%s[%u,%u,%u,%d,%d,%lu,%d]", i ? "," : "", (unsigned)b.gnssId,
                  (unsigned)b.svId, (unsigned)b.cno, (int)b.elev, (int)b.azim,
                  (unsigned long)b.flags, (int)b.prRes);
    }
    sat_.print("]}\n");
    satCount_++;
    maybeFlush();
  }

  void logDop(const UbxDop& d) {
    if (!recording_ || !dop_) return;
    dop_.printf(
        "{\"t_us\":%lld,\"tow\":%lu,\"g\":%.2f,\"p\":%.2f,\"t\":%.2f,\"v\":%.2f,\"h\":%.2f,"
        "\"n\":%.2f,\"e\":%.2f}\n",
        (long long)d.rxUs, (unsigned long)d.iTOW, d.g * 0.01, d.p * 0.01, d.t * 0.01,
        d.v * 0.01, d.h * 0.01, d.n * 0.01, d.e * 0.01);
    maybeFlush();
  }

  void logMark(const char* kind, double tow, float value, const char* note) {
    if (!recording_ || !marks_) return;
    marks_.printf("{\"t_us\":%lld,\"tow\":%.1f,\"kind\":\"%s\",\"v\":%.3f,\"note\":\"%s\"}\n",
                  (long long)esp_timer_get_time(), tow, kind, value, note ? note : "");
    marks_.flush();  // rare + precious
    markCount_++;
  }

  void logAnchorErr(const UbxPvt& p, double dE, double dN, double dU, bool refOk, bool valid,
                    bool stab, bool dist, const UbxSat* s, double pa, float tc) {
    if (!recording_ || !aerr_) return;
    aerr_.printf(
        "{\"t_us\":%lld,\"tow\":%lu,\"dE\":%.3f,\"dN\":%.3f,\"dU\":%.3f,\"ref\":%u,"
        "\"valid\":%u,\"stab\":%u,\"dist\":%u,\"fix\":%u,\"sv\":%u,\"hacc\":%.3f,"
        "\"vacc\":%.3f,\"pdop\":%.2f,\"used\":%u,\"hash\":\"%08lx\",\"pa\":%.2f,"
        "\"temp_c\":%.2f}\n",
        (long long)p.rxUs, (unsigned long)p.iTOW, dE, dN, dU, (unsigned)refOk, (unsigned)valid,
        (unsigned)stab, (unsigned)dist, (unsigned)p.fixType, (unsigned)p.numSV, p.hAccM(),
        p.vAccM(), p.pDOP * 0.01, s ? (unsigned)s->used : 0u,
        s ? (unsigned long)s->usedHash : 0ul, pa, tc);
    aerrCount_++;
    maybeFlush();
  }

  void logQuality(const char* kind, uint32_t value) {
    if (!recording_ || !quality_) return;
    const int64_t t = esp_timer_get_time();
    quality_.printf("{\"t_us\":%lld,\"kind\":\"%s\",\"value\":%lu}\n", (long long)t,
                    kind, (unsigned long)value);
  }

  // Atomic-ish text file write in the session dir (tmp → rename).
  bool writeSessionFile(const char* name, const char* body) {
    if (sessionDir_.length() == 0 || !sdOk_) return false;
    const String path = sessionDir_ + "/" + name;
    const String tmp = path + ".tmp";
    SD.remove(tmp);
    File f = SD.open(tmp, FILE_WRITE);
    if (!f) return false;
    f.print(body);
    f.flush();
    f.close();
    SD.remove(path);
    if (!SD.rename(tmp, path)) {
      File g = SD.open(path, FILE_WRITE);
      if (!g) return false;
      g.print(body);
      g.close();
      SD.remove(tmp);
    }
    return true;
  }

  uint32_t gnssCount() const { return gnssCount_; }
  uint32_t imuCount() const { return imuCount_; }
  uint32_t pvtCount() const { return pvtCount_; }
  uint32_t baroCount() const { return baroCount_; }
  uint32_t aerrCount() const { return aerrCount_; }
  uint32_t secondsRecording() const {
    return recording_ ? (uint32_t)((esp_timer_get_time() - startedUs_) / 1000000) : 0;
  }

 private:
  String makeSessionId() {
    // UUID-ish from MAC + time (ingest accepts any stable local_id string).
    uint64_t mac = ESP.getEfuseMac();
    char buf[40];
    snprintf(buf, sizeof(buf), "%08lx-%04lx-%04lx-%04lx-%08lx%04lx",
             (unsigned long)((mac >> 16) & 0xffffffff),
             (unsigned long)(esp_timer_get_time() & 0xffff),
             (unsigned long)((esp_timer_get_time() >> 16) & 0xffff),
             (unsigned long)((mac >> 8) & 0xffff), (unsigned long)(mac & 0xffffffff),
             (unsigned long)(millis() & 0xffff));
    return String(buf);
  }

  void maybeFlush() {
    if (++flushCounter_ >= 200) {
      flushCounter_ = 0;
      flushAll();
      lastFlushMs_ = millis();
    }
  }

  void flushAll() {
    File* fs[] = {&gnss_, &imu_, &baro_, &quality_, &pvt_, &sat_, &dop_, &marks_, &aerr_};
    for (File* f : fs) {
      wdtFeed();
      if (*f) f->flush();
    }
  }

  void closeFiles() {
    File* fs[] = {&gnss_, &imu_, &baro_, &quality_, &pvt_, &sat_, &dop_, &marks_, &aerr_};
    for (File* f : fs) {
      if (*f) {
        f->close();
        *f = File();
      }
    }
  }

  void writeManifest(bool ended) {
    static char buf[2700];  // 0.6.3-auto: + "auto" block (loop task only)
    int o = snprintf(
        buf, sizeof(buf),
        "{\"schema\":\"riderlab_logger.v1\",\"firmware\":\"%s\",\"version\":\"%s\","
        "\"device_id\":\"%s\",\"session_id\":\"%s\","
        "\"pins\":{\"gnss_rx\":%d,\"gnss_tx\":%d,\"pps\":%d},"
        "\"rates\":{\"gnss_hz\":%lu,\"imu_hz\":%lu,\"baro_hz\":%lu},"
        "\"started_us\":%lld,\"ended_us\":%lld,"
        "\"counts\":{\"gnss\":%lu,\"imu\":%lu,\"baro\":%lu,\"pvt\":%lu,\"sat\":%lu,"
        "\"anchor_err\":%lu,\"marks\":%lu},"
        "\"complete\":%s",
        FIRMWARE_NAME, FIRMWARE_VERSION, deviceId_.c_str(), sessionId_.c_str(), gnssRx_,
        gnssTx_, GNSS_PPS_PIN, (unsigned long)GNSS_TARGET_HZ, (unsigned long)IMU_TARGET_HZ,
        (unsigned long)BARO_LOG_HZ, (long long)startedUs_, ended ? (long long)endedUs_ : 0LL,
        (unsigned long)gnssCount_, (unsigned long)imuCount_, (unsigned long)baroCount_,
        (unsigned long)pvtCount_, (unsigned long)satCount_, (unsigned long)aerrCount_,
        (unsigned long)markCount_, ended ? "true" : "false");
    if (o < 0 || o >= (int)sizeof(buf)) return;
    snprintf(buf + o, sizeof(buf) - o, "%s}\n", extra_.c_str());
    writeSessionFile("manifest.json", buf);
  }

 public:
  void setPins(int rx, int tx) {
    gnssRx_ = rx;
    gnssTx_ = tx;
  }

 private:
  bool sdOk_ = false;
  uint32_t hz_ = SD_SPI_HZ;
  uint8_t slots_ = 0;
  bool recording_ = false;
  bool anchor_ = false;
  String err_ = "not started";
  String sessionId_;
  String sessionDir_;
  String deviceId_;
  String extra_;
  File gnss_, imu_, baro_, quality_, pvt_, sat_, dop_, marks_, aerr_;
  int64_t startedUs_ = 0;
  int64_t endedUs_ = 0;
  uint32_t gnssCount_ = 0, imuCount_ = 0, baroCount_ = 0, pvtCount_ = 0, satCount_ = 0,
           aerrCount_ = 0, markCount_ = 0;
  uint32_t flushCounter_ = 0;
  uint32_t lastFlushMs_ = 0, lastManifestMs_ = 0;
  int gnssRx_ = -1, gnssTx_ = -1;
};

}  // namespace riderlab
