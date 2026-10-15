#pragma once

// NEO-M9N link + configuration (M5 Module GNSS M135).
// - Data link: UART RX auto-hunt (validated by NMEA checksum or UBX frame), or
//   u-blox DDC (I2C 0x42) if the module exposes it.
// - Command path (to configure the receiver): DDC if present, else a UART TX
//   pin found by polling UBX-MON-VER and waiting for the answer on RX.
// - ONE shared receiver profile (HardwareConfig.h) applied with UBX-CFG-VALSET
//   (RAM layer, re-applied on every boot) in BOTH roles.
// Config keys verified against the u-blox M9 interface description.

#include <Arduino.h>
#include <HardwareSerial.h>
#include <TinyGPSPlus.h>
#include <Wire.h>
#include <cstring>
#include <driver/gpio.h>
#include <esp_timer.h>

#include "DiagLog.h"
#include "HardwareConfig.h"
#include "UbxParser.h"

namespace riderlab {

struct GnssFix {
  bool valid = false;
  double lat = 0;
  double lng = 0;
  double alt = 0;
  double speedMps = -1;
  double heading = -1;
  double accM = -1;
  int sats = -1;
  double hdop = -1;
  uint32_t utcMs = 0;
  uint32_t chars = 0;
  uint32_t bytes = 0;
  uint8_t hz = 0;
  uint8_t fixType = 0;  // 0.6.2-circuit.7-rastro: UBX fixType (0 = unknown / NMEA path)
};

namespace ubxkey {
// CFG-SIGNAL
static constexpr uint32_t GPS_ENA = 0x1031001f, GPS_L1CA = 0x10310001;
static constexpr uint32_t SBAS_ENA = 0x10310020, SBAS_L1CA = 0x10310005;
static constexpr uint32_t GAL_ENA = 0x10310021, GAL_E1 = 0x10310007;
static constexpr uint32_t BDS_ENA = 0x10310022, BDS_B1 = 0x1031000d;
static constexpr uint32_t QZSS_ENA = 0x10310024, QZSS_L1CA = 0x10310012;
static constexpr uint32_t GLO_ENA = 0x10310025, GLO_L1 = 0x10310018;
// CFG-RATE / NAVSPG / SBAS
static constexpr uint32_t RATE_MEAS = 0x30210001, RATE_NAV = 0x30210002;
static constexpr uint32_t DYNMODEL = 0x20110021, MINELEV = 0x201100a4;
static constexpr uint32_t SBAS_RANGING = 0x10360003, SBAS_DIFFCORR = 0x10360004;
// Ports
static constexpr uint32_t UART1_BAUD = 0x40520001;
static constexpr uint32_t UART1_OUT_UBX = 0x10740001, UART1_OUT_NMEA = 0x10740002;
static constexpr uint32_t I2C_OUT_UBX = 0x10720001, I2C_OUT_NMEA = 0x10720002;
// CFG-MSGOUT (UART1 / I2C)
static constexpr uint32_t PVT_U1 = 0x20910007, PVT_I2C = 0x20910006;
static constexpr uint32_t SAT_U1 = 0x20910016, SAT_I2C = 0x20910015;
static constexpr uint32_t DOP_U1 = 0x20910039, DOP_I2C = 0x20910038;
static constexpr uint32_t GGA_U1 = 0x209100bb, GGA_I2C = 0x209100ba;
static constexpr uint32_t RMC_U1 = 0x209100ac, RMC_I2C = 0x209100ab;
static constexpr uint32_t GLL_U1 = 0x209100ca, GLL_I2C = 0x209100c9;
static constexpr uint32_t GSA_U1 = 0x209100c0, GSA_I2C = 0x209100bf;
static constexpr uint32_t GSV_U1 = 0x209100c5, GSV_I2C = 0x209100c4;
static constexpr uint32_t VTG_U1 = 0x209100b1, VTG_I2C = 0x209100b0;
}  // namespace ubxkey

class GnssService {
 public:
  struct Combo {
    int rx;
    uint32_t baud;
  };
  // Measured on the bike unit: NEO_TXD lands on G35. Others cover other DIP
  // positions. First kBootCombos are tried at boot; the rest at runtime.
  // Preferred-first: measured ANCHOR stack (rx16 + tx12). Never listen on G0/G12
  // (strapping / host-TX). Never drive G0 (strapping) or G18/G19/G23 (SD/LCD SPI).
  static constexpr Combo kCombos[] = {
      {16, 38400}, {16, 115200}, {16, 9600},
      {35, 38400}, {35, 115200}, {35, 9600},  {34, 38400}, {36, 38400}, {36, 115200},
      {15, 38400}, {13, 38400},  {17, 38400}, {15, 115200},
      {13, 115200}, {17, 115200}, {36, 9600}, {15, 9600},
      {13, 9600},  {17, 9600},   {2, 38400},  {5, 38400},
      {26, 38400}, {2, 115200}, {5, 115200}, {26, 115200},
      {34, 115200}, {34, 9600},
  };
  static constexpr size_t kComboCount = sizeof(kCombos) / sizeof(kCombos[0]);
  static constexpr size_t kBootCombos = 14;
  // Host TX toward NEO_RXD. Keep G12 (working path on ANCHOR). Never G0/G18/G19/G23.
  static constexpr int kTxCandidates[] = {12, 17, 15, 13, 16, 2, 5, 26};

  // ---------------- link ----------------
  bool beginAuto(HardwareSerial& serial, int prefRx = -1, uint32_t prefBaud = 0) {
    serial_ = &serial;
    if (prefRx >= 0 && prefBaud) {
      openUart(prefRx, -1, prefBaud, "boot-pref");
      if (waitValid(1300)) return markLocked();
    }
    for (size_t i = 0; i < kBootCombos; ++i) {
      comboIdx_ = i;
      openUart(kCombos[i].rx, -1, kCombos[i].baud, "boot-hunt");
      if (waitValid(1300)) return markLocked();
    }
    comboIdx_ = 0;
    openUart(kCombos[0].rx, -1, kCombos[0].baud, "boot-nolink");
    return false;
  }

  bool beginI2c(TwoWire& wire) {
    wire_ = &wire;
    if (!ddcPresent()) return false;
    useI2c_ = true;
    locked_ = true;
    snprintf(linkBuf_, sizeof(linkBuf_), "i2c 0x42");
    lastValidMs_ = millis();
    return true;
  }

  void setWire(TwoWire& wire) { wire_ = &wire; }

  void poll() {
    if (useI2c_) {
      pollDdc(&parser_, true);
      return;
    }
    if (!serial_) return;
    lastPollMs_ = millis();
    {
      const int a = serial_->available();
      if (a > rxHigh_) rxHigh_ = a;
      if (a > 0) lastByteMs_ = lastPollMs_;
    }
    // Stop after each decoded PVT/SAT/DOP so the caller can consume it before
    // the next one overwrites it (UART RX buffer holds the backlog).
    while (serial_->available() > 0) {
      if (feedByte((uint8_t)serial_->read(), esp_timer_get_time())) break;
    }
    // 0.5.2: link liveness is measured here, after the bytes were actually parsed
    // (not from loop timing in maintain()).
    noteValid(millis());
  }

  // PPS input pin: never listen/reset it during the runtime hunt (gpio_reset_pin
  // on the PPS pin kills its interrupt until reboot).
  void setAvoidRx(int pin) { avoidRx_ = pin; }
  int avoidRx() const { return avoidRx_; }

  // Runtime: relink when data stops (receiver reset -> back to 38400 default)
  // and keep hunting other combos if nothing was ever found.
  // 0.5.2: call AFTER the UART was drained (handleGnssData/poll) in this loop.
  //  - lost = no valid frame for 4 s, judged only right after a poll with the RX
  //    backlog drained (a slow loop with bytes waiting is NOT a lost link);
  //  - hunt alternates the last good combo (rx16 @ 115200) with one alternative;
  //  - a hunt step is judged only after its UART was polled past its dwell;
  //  - same-pin baud changes use updateBaudRate() (no end()/begin() data loss).
  void maintain() {
    const uint32_t now = millis();
    const uint32_t maintGap = lastMaintainMs_ ? now - lastMaintainMs_ : 0;
    lastMaintainMs_ = now;
    noteValid(now);
    if (useI2c_) return;
    const int avail = serial_ ? serial_->available() : 0;
    const bool polledNow = lastPollMs_ && (int32_t)(lastPollMs_ - (now - 250)) >= 0;
    if (locked_) {
      if (now - lastValidMs_ > 4000 && polledNow && avail <= kBacklog) {
        Serial.println("GNSS link lost -> relink");
        // DIAG: maint_gap = time since the previous maintain() call (= loop iteration gap).
        gDiag.logf("gnss",
                   "LINK LOST reason=no-valid-frame silent_ms=%lu byte_silent_ms=%lu limit_ms=4000 "
                   "maint_gap_ms=%lu rx_avail=%d rx_hw=%d link=%s cfg=%s bytes=%lu ubx_ok=%lu "
                   "ubx_bad=%lu nmea_bad=%lu len_ovf=%lu buf_full=%lu fifo_ovf=%lu frame_err=%lu",
                   (unsigned long)(now - lastValidMs_),
                   (unsigned long)(lastByteMs_ ? now - lastByteMs_ : 0), (unsigned long)maintGap,
                   avail, rxHigh_, linkBuf_, cfgStatus_, (unsigned long)bytes_,
                   (unsigned long)parser_.okFrames(), (unsigned long)parser_.badFrames(),
                   (unsigned long)gps_.failedChecksum(), (unsigned long)parser_.overflows(),
                   (unsigned long)uartBufFull_, (unsigned long)uartFifoOvf_,
                   (unsigned long)uartFrameErr_);
        lostAtMs_ = now;
        locked_ = false;
        cfgTried_ = false;
        relinks_++;
        huntStep_ = 0;
        huntAlt_ = 0;
        huntNext(now, maintGap);
      }
      return;
    }
    if (lastSwitchMs_ == 0) {  // forceRelink() / first hunt
      huntNext(now, maintGap);
      return;
    }
    // Valid data on the current combo -> relock immediately (no need to wait the dwell).
    if (validCount() != huntBase_) {
      markLocked();
      gDiag.logf("gnss", "RELOCK %s after_lost_ms=%lu dwell_ms=%lu hunt_step=%u", linkBuf_,
                 (unsigned long)(lostAtMs_ ? now - lostAtMs_ : 0),
                 (unsigned long)(now - lastSwitchMs_), (unsigned)huntStep_);
      return;
    }
    // Judge the step only once its UART was polled after the dwell ended and the
    // backlog is drained (a loop stall during the dwell does not fail the step).
    if (now - lastSwitchMs_ < dwellMs_) return;
    if (!lastPollMs_ || (int32_t)(lastPollMs_ - (lastSwitchMs_ + dwellMs_)) < 0) return;
    if (avail > kBacklog) return;
    gDiag.logf("gnss",
               "HUNT step-fail rx=%d baud=%lu dwell_ms=%lu maint_gap_ms=%lu new_valid=0 "
               "rx_avail=%d bytes_since_open=%lu step=%u",
               rx_, (unsigned long)baud_, (unsigned long)(now - lastSwitchMs_),
               (unsigned long)maintGap, avail, (unsigned long)(bytes_ - bytesAtOpen_),
               (unsigned)huntStep_);
    huntNext(now, maintGap);
  }

  // After PINSCAN (pins reset) or on request: hunt + reconfigure.
  void forceRelink() {
    locked_ = false;
    cfgTried_ = false;
    huntStep_ = 0;
    huntAlt_ = 0;
    lastSwitchMs_ = 0;
    if (rx_ < 0) rx_ = kCombos[0].rx;
  }
  void requestReconfigure() { cfgTried_ = false; }

  // ---------------- configuration ----------------
  bool needsConfigure() const { return locked_ && !cfgTried_; }

  bool configure(TwoWire& wire, int prefTx = -1) {
    wire_ = &wire;
    cfgTried_ = true;
    cfgOk_ = false;
    acks_ = naks_ = 0;
    strcpy(cfgStatus_, "none");
    // 1) command path
    if (ddcPresent()) {
      path_ = Path::I2c;
      ddcParser_.clearMonVer();
      sendUbx(0x0A, 0x04, nullptr, 0);
      waitFor([&] { return ddcParser_.monVerSeen(); }, 600);
      Serial.printf("GNSS cmd path i2c monver=%d\n", (int)ddcParser_.monVerSeen());
    } else if (!useI2c_) {
      path_ = Path::None;
      if (!huntTx(prefTx)) {
        strcpy(cfgStatus_, "no-cmd-path");
        Serial.println("GNSS: no command path (receiver keeps its defaults)");
        return false;
      }
    } else {
      strcpy(cfgStatus_, "no-cmd-path");
      return false;
    }
    UbxParser& cp = cmdParser();
    if (cp.monVerSeen()) strncpy(fwVer_, cp.fwVer(), sizeof(fwVer_) - 1);

    // 2) signals: only touch (and restart GNSS) when they differ
    using namespace ubxkey;
    const uint8_t sbas = GNSS_USE_SBAS ? 1 : 0;
    const uint32_t sigKeys[] = {GPS_ENA, GPS_L1CA, SBAS_ENA, SBAS_L1CA, GAL_ENA, GAL_E1,
                                BDS_ENA, BDS_B1,   QZSS_ENA, QZSS_L1CA, GLO_ENA, GLO_L1};
    const uint8_t sigVals[] = {1, 1, sbas, sbas, 1, 1, 1, 1, 1, 1, 1, 1};
    bool sigSame = false;
    if (valget(sigKeys, 12)) {
      sigSame = true;
      for (int i = 0; i < 12; ++i)
        if (cp.valgetU8(sigKeys[i]) != sigVals[i]) sigSame = false;
    }
    if (!sigSame) {
      Kv kv[12];
      for (int i = 0; i < 12; ++i) kv[i] = {sigKeys[i], sigVals[i]};
      const bool ok = valset(kv, 12);
      Serial.printf("GNSS signals set ok=%d -> GNSS restart\n", (int)ok);
      const uint8_t rst[4] = {0x00, 0x00, 0x02, 0x00};  // hot, controlled GNSS-only reset
      sendUbx(0x06, 0x04, rst, 4);
      waitFor([] { return false; }, 1200);
    } else {
      Serial.println("GNSS signals already match profile");
    }
    // 3) navigation
    const uint16_t meas = (uint16_t)(1000 / GNSS_TARGET_HZ);
    Kv nav[] = {{RATE_MEAS, meas},
                {RATE_NAV, 1},
                {DYNMODEL, GNSS_DYNMODEL},
                {MINELEV, (uint32_t)(uint8_t)GNSS_MIN_ELEV_DEG},
                {SBAS_RANGING, sbas},
                {SBAS_DIFFCORR, sbas}};
    const bool okNav = valset(nav, 6);
    navHz_ = GNSS_TARGET_HZ;  // 0.6.3-auto: configure() always leaves the receiver at the session rate
    cfgGen_++;
    // 4) outputs on the data port
    bool okOut;
    if (useI2c_) {
      Kv out[] = {{I2C_OUT_UBX, 1},  {I2C_OUT_NMEA, 1}, {PVT_I2C, 1},
                  {SAT_I2C, GNSS_SAT_EVERY_N}, {DOP_I2C, GNSS_DOP_EVERY_N},
                  {GGA_I2C, GNSS_TARGET_HZ}, {RMC_I2C, GNSS_TARGET_HZ},
                  {GLL_I2C, 0}, {GSA_I2C, 0}, {GSV_I2C, 0}, {VTG_I2C, 0}};
      okOut = valset(out, 11);
    } else {
      Kv out[] = {{UART1_OUT_UBX, 1}, {UART1_OUT_NMEA, 1}, {PVT_U1, 1},
                  {SAT_U1, GNSS_SAT_EVERY_N}, {DOP_U1, GNSS_DOP_EVERY_N},
                  {GGA_U1, GNSS_TARGET_HZ}, {RMC_U1, GNSS_TARGET_HZ},
                  {GLL_U1, 0}, {GSA_U1, 0}, {GSV_U1, 0}, {VTG_U1, 0}};
      okOut = valset(out, 11);
      if (path_ == Path::I2c) {
        Kv q[] = {{I2C_OUT_NMEA, 0}, {I2C_OUT_UBX, 1}};  // keep DDC quiet (ACKs only)
        valset(q, 2);
      }
    }
    // 5) faster UART (UBX PVT 10 Hz + SAT + DOP + NMEA 1 Hz)
    if (!useI2c_ && baud_ != GNSS_FAST_BAUD) switchBaud(GNSS_FAST_BAUD);
    measureHz();
    cfgOk_ = okNav && okOut;
    snprintf(cfgStatus_, sizeof(cfgStatus_), "%s", cfgOk_ ? "ok" : (acks_ ? "partial" : "noack"));
    gDiag.logf("gnss", "CFG %s acks=%u naks=%u path=%s link=%s hz=%u", cfgStatus_,
               (unsigned)acks_, (unsigned)naks_, pathTag(), linkBuf_, (unsigned)hz_);
    Serial.printf("GNSS cfg %s acks=%u naks=%u path=%s baud=%lu hz=%u fw=%s\n", cfgStatus_,
                  (unsigned)acks_, (unsigned)naks_, pathTag(), (unsigned long)baud_,
                  (unsigned)hz_, fwVer_);
    return cfgOk_;
  }

  // ---------------- data ----------------
  bool consumeFix() {
    if (!pendingFix_) return false;
    pendingFix_ = false;
    return true;
  }
  bool takePvt() { return take(newPvt_); }
  bool takeSat() { return take(newSat_); }
  bool takeDop() { return take(newDop_); }
  // 0.6.5-simpos: while SIMPOS is on, pvt()/snapshot() return the injected fix (the real receiver keeps
  // being parsed so the link watchdog/hunt never fires, but its PVTs are not handed to the consumers).
  const UbxPvt& pvt() const { return simOn_ ? simPvt_ : parser_.pvt(); }
  const UbxSat& sat() const { return parser_.sat(); }
  const UbxDop& dop() const { return parser_.dop(); }
  bool ubxActive() const {
    return lastPvtMs_ && (millis() - lastPvtMs_) < 2500;
  }

  GnssFix snapshot() {
    GnssFix f;
    f.bytes = bytes_;
    f.chars = gps_.charsProcessed();
    f.hz = hz_;
    if (simOn_ || ubxActive()) {  // 0.6.5-simpos: never fall back to the real NMEA fix while simulating
      if (simOn_) simCheckStale();
      const UbxPvt& p = pvt();
      f.valid = p.fixType >= 2 && p.gnssFixOk() && !p.invalidLlh();
      f.lat = p.latDeg();
      f.lng = p.lonDeg();
      f.alt = p.hMsl();
      f.speedMps = p.gSpeed * 1e-3;
      f.heading = p.headMot * 1e-5;
      f.accM = p.hAccM();
      f.sats = p.numSV;
      f.fixType = p.fixType;
      const UbxDop& d = parser_.dop();
      f.hdop = (d.iTOW && (p.iTOW - d.iTOW) < 3000) ? d.h * 0.01 : p.pDOP * 0.01;
      int64_t ms = ((int64_t)p.hour * 3600 + p.min * 60 + p.sec) * 1000 +
                   (p.nano >= 0 ? (p.nano + 500000) / 1000000 : -((-p.nano + 500000) / 1000000));
      if (ms < 0) ms += 86400000;
      f.utcMs = (uint32_t)ms;
      return f;
    }
    f.valid = gps_.location.isValid() && gps_.location.age() < 3000;
    if (f.valid) {
      f.lat = gps_.location.lat();
      f.lng = gps_.location.lng();
    }
    if (gps_.altitude.isValid()) f.alt = gps_.altitude.meters();
    if (gps_.speed.isValid()) f.speedMps = gps_.speed.mps();
    if (gps_.course.isValid()) f.heading = gps_.course.deg();
    if (gps_.satellites.isValid()) f.sats = static_cast<int>(gps_.satellites.value());
    if (gps_.hdop.isValid()) f.hdop = gps_.hdop.hdop();
    if (gps_.date.isValid() && gps_.time.isValid()) {
      f.utcMs = gps_.time.hour() * 3600000UL + gps_.time.minute() * 60000UL +
                gps_.time.second() * 1000UL + gps_.time.centisecond() * 10UL;
    }
    return f;
  }

  const char* linkTag() const { return linkBuf_; }
  bool locked() const { return locked_; }
  int rxPin() const { return rx_; }
  int txPin() const { return txLive_; }
  uint32_t baud() const { return baud_; }
  uint8_t hz() const { return hz_; }
  // 0.6.3-auto: runtime navigation rate (UBX-CFG-VALSET CFG-RATE-MEAS, RAM layer, ACK-checked).
  bool setNavRate(uint8_t hz, uint32_t* ackMs = nullptr) {
    if (hz < 1) hz = 1;
    if (hz > GNSS_TARGET_HZ) hz = GNSS_TARGET_HZ;
    const uint32_t t0 = millis();
    Kv kv[] = {{ubxkey::RATE_MEAS, (uint32_t)(1000 / hz)}};
    const bool ok = valset(kv, 1);
    if (ackMs) *ackMs = millis() - t0;
    if (ok) navHz_ = hz;
    return ok;
  }
  uint8_t navHz() const { return navHz_; }
  uint32_t cfgGen() const { return cfgGen_; }
  bool configured() const { return cfgOk_; }
  bool cfgTried() const { return cfgTried_; }
  const char* cfgStatus() const { return cfgStatus_; }
  const char* fwVer() const { return fwVer_; }
  const char* pathTag() const {
    switch (path_) {
      case Path::I2c:
        return "i2c";
      case Path::UartTx:
        return pathBuf_;
      default:
        return "none";
    }
  }
  uint32_t ubxOk() const { return parser_.okFrames(); }
  uint32_t ubxBad() const { return parser_.badFrames(); }
  uint32_t relinks() const { return relinks_; }
  // ---- DIAG health ----
  uint32_t bytesTotal() const { return bytes_; }
  uint32_t validFrames() const { return validCount(); }
  uint32_t nmeaBad() const { return gps_.failedChecksum(); }
  uint32_t lenOverflows() const { return parser_.overflows(); }
  uint32_t uartBufFull() const { return uartBufFull_; }
  uint32_t uartFifoOvf() const { return uartFifoOvf_; }
  uint32_t uartFrameErr() const { return uartFrameErr_; }
  uint32_t silentMs() const { return millis() - lastValidMs_; }
  int takeRxHigh() {
    const int h = rxHigh_;
    rxHigh_ = 0;
    return h;
  }
  int foundTx() const { return foundTx_; }
  TinyGPSPlus& gps() { return gps_; }

  // JSON object describing the live receiver setup (manifest).
  void configJson(char* out, size_t n) const {
    snprintf(out, n,
             "{\"profile\":\"%s\",\"cfg\":\"%s\",\"cmd_path\":\"%s\",\"link\":\"%s\","
             "\"baud\":%lu,\"hz_target\":%lu,\"hz\":%u,\"dynmodel\":%u,\"min_elev\":%d,"
             "\"sbas\":%d,\"gnss\":\"GPS+GLO+GAL+BDS+QZSS%s\",\"acks\":%u,\"naks\":%u,"
             "\"fw\":\"%s\"}",
             GNSS_PROFILE_NAME, cfgStatus_, pathTag(), linkBuf_, (unsigned long)baud_,
             (unsigned long)GNSS_TARGET_HZ, (unsigned)hz_, (unsigned)GNSS_DYNMODEL,
             (int)GNSS_MIN_ELEV_DEG, GNSS_USE_SBAS ? 1 : 0, GNSS_USE_SBAS ? "+SBAS" : "",
             (unsigned)acks_, (unsigned)naks_, fwVer_);
  }

  // ---------------- 0.6.5-simpos: injected position fixes ----------------
  static constexpr uint32_t kSimStaleMs = 2500;
  void simEnable(bool on) {
    simOn_ = on;
    simHave_ = false;
    simLastMs_ = 0;
    simPvt_ = UbxPvt();  // fixType 0 until the first injected fix
    newPvt_ = false;     // drop any pending (real or simulated) PVT event at the switch
    pendingFix_ = false;
  }
  bool simOn() const { return simOn_; }
  bool simFresh() const { return simOn_ && simHave_ && (millis() - simLastMs_) < kSimStaleMs; }
  int32_t simAgeMs() const { return simHave_ ? (int32_t)(millis() - simLastMs_) : -1; }
  uint32_t simRx() const { return simRx_; }
  uint32_t simStales() const { return simStales_; }
  void injectPvt(const UbxPvt& p) {
    simPvt_ = p;
    simHave_ = true;
    simLastMs_ = millis();
    simRx_++;
    newPvt_ = true;
    lastPvtMs_ = simLastMs_;
    noteEpoch();
  }
  // Real receiver PVT (always the receiver's, for the GPS clock while simulating).
  bool takeRealPvt() { return take(newRealPvt_); }
  const UbxPvt& realPvt() const { return parser_.pvt(); }
  bool realPvtActive() const { return lastRealPvtMs_ && (millis() - lastRealPvtMs_) < 2500; }

  // 0.6.9g DORMIR: UBX-RXM-PMREQ v0 (infinite backup, forced), woken by any UART RX edge.
  // RAM config is lost in backup; boot re-applies it like after a power cycle.
  bool sleepBackup() {
    if (path_ != Path::UartTx || !serial_ || txLive_ < 0) return false;
    uint8_t p[16] = {};
    p[8] = 0x06;   // flags: backup | force
    p[12] = 0x08;  // wakeupSources: uartrx
    return sendUbx(0x02, 0x41, p, sizeof p);
  }

 private:
  // Injected fixes stopped > kSimStaleMs: the simulated fix becomes "no fix" (never freeze the last one).
  void simCheckStale() {
    if (!simOn_ || simFresh()) return;
    if (simPvt_.fixType != 0 || (simPvt_.flags & 0x01)) {
      simPvt_.fixType = 0;
      simPvt_.flags = 0;
      simPvt_.flags3 |= 0x0001;  // invalidLlh
      simPvt_.gSpeed = simPvt_.velN = simPvt_.velE = simPvt_.velD = 0;
      simPvt_.numSV = 0;
      simStales_++;
      gDiag.logf("simpos", "STALE no injected fix for %ld ms -> fix lost", (long)simAgeMs());
    }
  }

  enum class Path : uint8_t { None, I2c, UartTx };
  struct Kv {
    uint32_t key;
    uint32_t val;
  };

  static bool take(bool& f) {
    const bool r = f;
    f = false;
    return r;
  }

  uint32_t validCount() const { return parser_.okFrames() + gps_.passedChecksum(); }

  // true when a PVT/SAT/DOP frame was just decoded
  bool feedByte(uint8_t c, int64_t nowUs) {
    bytes_++;
    bool msg = false;
    const UbxParser::Result r = parser_.feed(c, nowUs);
    if (r == UbxParser::kPassNmea) {
      if (gps_.encode((char)c)) {
        if (gps_.date.isUpdated()) {
          (void)gps_.date.value();
          if (!simOn_ && !ubxActive()) noteEpoch();
        }
      }
    } else if (r == UbxParser::kFrame) {
      if (parser_.takePvt()) {
        newRealPvt_ = true;
        lastRealPvtMs_ = millis();
        if (!simOn_) {
          newPvt_ = true;
          lastPvtMs_ = lastRealPvtMs_;
          noteEpoch();
        } else if (!simFresh()) {
          // 0.6.5-simpos: injected fixes stale -> hand out a "no fix" PVT at the receiver cadence so
          // the consumers see a fix loss (auto FIXLOSS, circuit fix invalid) instead of a frozen fix.
          simCheckStale();
          simPvt_.rxUs = parser_.pvt().rxUs;
          newPvt_ = true;
          lastPvtMs_ = lastRealPvtMs_;
          noteEpoch();
        }
        msg = true;
      }
      if (parser_.takeSat()) newSat_ = msg = true;
      if (parser_.takeDop()) newDop_ = msg = true;
    }
    return msg;
  }

  void noteEpoch() {
    pendingFix_ = true;
    const uint32_t now = millis();
    if (now - hzWindowMs_ >= 1000) {
      hz_ = (uint8_t)(epochCount_ > 50 ? 50 : epochCount_);
      epochCount_ = 0;
      hzWindowMs_ = now;
    }
    epochCount_++;
  }

  bool markLocked() {
    locked_ = true;
    lastValidMs_ = millis();
    lastValidCount_ = validCount();
    if (!useI2c_ && rx_ >= 0 && baud_) {  // 0.5.2: last good combo for the runtime hunt
      goodRx_ = rx_;
      goodBaud_ = baud_;
    }
    snprintf(linkBuf_, sizeof(linkBuf_), "rx%d%s %luk LOCK", rx_,
             txLive_ >= 0 ? (String(" tx") + txLive_).c_str() : "",
             (unsigned long)(baud_ / 1000));
    return true;
  }

  void openUart(int rx, int tx, uint32_t baud, const char* why = "?") {
    if (!serial_) return;
    // 0.5.2: parse whatever is still buffered before end() frees the RX ring.
    const int drained = drainRx();
    gDiag.logf("uart", "Serial2 end/begin rx=%d tx=%d baud=%lu why=%s (prev rx=%d tx=%d baud=%lu) "
               "drained=%d",
               rx, tx, (unsigned long)baud, why, rx_, txLive_, (unsigned long)baud_, drained);
    serial_->end();
    delay(10);
    gpio_reset_pin(static_cast<gpio_num_t>(rx));
    if (tx >= 0) gpio_reset_pin(static_cast<gpio_num_t>(tx));
    // G34..G39 are input-only and have no internal pulls.
    pinMode(rx, rx >= 34 ? INPUT : INPUT_PULLUP);
    serial_->setRxBufferSize(4096);  // 115200 bursts while SD flushes
    serial_->begin(baud, SERIAL_8N1, rx, tx);
    // DIAG: count RX ring-buffer-full / FIFO overflow / framing errors. end()
    // clears the callback, so re-arm after every begin().
    serial_->onReceiveError([this](hardwareSerial_error_t e) {
      if (e == UART_BUFFER_FULL_ERROR) uartBufFull_++;
      else if (e == UART_FIFO_OVF_ERROR) uartFifoOvf_++;
      else if (e == UART_FRAME_ERROR) uartFrameErr_++;
    });
    bytesAtOpen_ = bytes_;
    rx_ = rx;
    txLive_ = tx;
    baud_ = baud;
    huntBase_ = validCount();
    lastSwitchMs_ = millis();
    snprintf(linkBuf_, sizeof(linkBuf_), "rx%d %luk", rx, (unsigned long)(baud / 1000));
  }

  // 0.5.2 runtime hunt helpers ------------------------------------------------
  static constexpr int kBacklog = 64;  // RX bytes still waiting = loop behind, not link loss

  void noteValid(uint32_t now) {
    const uint32_t vc = validCount();
    if (vc != lastValidCount_) {
      lastValidCount_ = vc;
      lastValidMs_ = now;
    }
  }

  int drainRx() {
    if (!serial_) return 0;
    int n = 0;
    const int64_t t = esp_timer_get_time();
    while (serial_->available() > 0 && n < 8192) {
      feedByte((uint8_t)serial_->read(), t);
      n++;
    }
    if (n) lastByteMs_ = millis();
    noteValid(millis());
    return n;
  }

  // Same pins, other baud: keep the driver and its RX ring (no end()/begin()).
  void retune(uint32_t baud, const char* why) {
    const int drained = drainRx();
    gDiag.logf("uart", "Serial2 baud-only rx=%d baud=%lu why=%s (prev baud=%lu) drained=%d", rx_,
               (unsigned long)baud, why, (unsigned long)baud_, drained);
    serial_->updateBaudRate(baud);
    baud_ = baud;
    bytesAtOpen_ = bytes_;
    huntBase_ = validCount();
    lastSwitchMs_ = millis();
    snprintf(linkBuf_, sizeof(linkBuf_), "rx%d %luk", rx_, (unsigned long)(baud / 1000));
  }

  void huntOpen(int rx, uint32_t baud, const char* why) {
    if (rx == rx_ && baud == baud_ && serial_) {
      // already there: keep listening (fresh dwell), no reopen
      drainRx();
      bytesAtOpen_ = bytes_;
      huntBase_ = validCount();
      lastSwitchMs_ = millis();
      gDiag.logf("uart", "Serial2 keep rx=%d baud=%lu why=%s", rx, (unsigned long)baud, why);
    } else if (rx == rx_ && serial_) {
      retune(baud, why);
    } else {
      openUart(rx, -1, baud, why);
    }
  }

  // Even steps: last good combo. Odd steps: same RX at the receiver-reset bauds,
  // then the combo list (skipping the PPS pin and the good combo itself).
  void huntNext(uint32_t now, uint32_t maintGap) {
    (void)now;
    (void)maintGap;
    const bool haveGood = goodRx_ >= 0 && goodBaud_ != 0;
    if (haveGood && (huntStep_ % 2) == 0) {
      dwellMs_ = 2000;
      huntOpen(goodRx_, goodBaud_, huntStep_ == 0 ? "hunt-good-first" : "hunt-good-retry");
    } else {
      dwellMs_ = 1500;
      static const uint32_t sameBauds[2] = {38400, 9600};
      const int baseRx = haveGood ? goodRx_ : rx_;
      if (huntAlt_ < 2 && baseRx >= 0 && baseRx != avoidRx_) {
        huntOpen(baseRx, sameBauds[huntAlt_++], "relink-same-rx");
      } else {
        for (size_t k = 0; k < kComboCount; ++k) {
          comboIdx_ = (comboIdx_ + 1) % kComboCount;
          const Combo& c = kCombos[comboIdx_];
          if (c.rx == avoidRx_) continue;
          if (haveGood && c.rx == goodRx_ && c.baud == goodBaud_) continue;
          break;
        }
        huntOpen(kCombos[comboIdx_].rx, kCombos[comboIdx_].baud, "hunt-combo");
      }
    }
    gDiag.logf("gnss", "HUNT step=%u try rx=%d baud=%lu dwell_ms=%lu good=rx%d@%lu avoid_rx=%d",
               (unsigned)huntStep_, rx_, (unsigned long)baud_, (unsigned long)dwellMs_, goodRx_,
               (unsigned long)goodBaud_, avoidRx_);
    huntStep_++;
  }

  bool waitValid(uint32_t ms) {
    const uint32_t base = validCount();
    const uint32_t t0 = millis();
    while (millis() - t0 < ms) {
      wdtFeed();
      poll();
      if (validCount() != base) return true;
      delay(5);
    }
    return false;
  }

  template <typename F>
  bool waitFor(F cond, uint32_t ms) {
    const uint32_t t0 = millis();
    while (millis() - t0 < ms) {
      wdtFeed();
      poll();
      if (path_ == Path::I2c && !useI2c_) pollDdc(&ddcParser_, false);
      if (cond()) return true;
      delay(3);
    }
    return cond();
  }

  UbxParser& cmdParser() { return (path_ == Path::I2c && !useI2c_) ? ddcParser_ : parser_; }

  bool huntTx(int prefTx) {
    int order[12];
    int n = 0;
    if (prefTx >= 0) order[n++] = prefTx;
    for (int t : kTxCandidates)
      if (t != prefTx) order[n++] = t;
    const uint32_t keepBaud = baud_;
    for (int i = 0; i < n; ++i) {
      const int tx = order[i];
      if (tx == rx_) continue;
      openUart(rx_, tx, keepBaud, "tx-hunt");
      delay(20);
      path_ = Path::UartTx;
      parser_.clearMonVer();
      for (int k = 0; k < 2 && !parser_.monVerSeen(); ++k) {
        sendUbx(0x0A, 0x04, nullptr, 0);
        waitFor([&] { return parser_.monVerSeen(); }, 450);
      }
      Serial.printf("GNSS TX G%d monver=%d\n", tx, (int)parser_.monVerSeen());
      if (parser_.monVerSeen()) {
        snprintf(pathBuf_, sizeof(pathBuf_), "uart-tx%d", tx);
        foundTx_ = tx;
        markLocked();
        return true;
      }
      openUart(rx_, -1, keepBaud, "tx-hunt-release");
      gpio_reset_pin(static_cast<gpio_num_t>(tx));  // release the candidate
    }
    path_ = Path::None;
    openUart(rx_, -1, keepBaud, "tx-hunt-none");
    markLocked();
    return false;
  }

  void switchBaud(uint32_t target) {
    using namespace ubxkey;
    const uint32_t old = baud_;
    Kv kv[] = {{UART1_BAUD, target}};
    sendValset(kv, 1);  // ACK may arrive at either baud; verify by data instead
    delay(120);
    openUart(rx_, txLive_, target, "baud-switch");
    if (waitValid(1600)) {
      markLocked();
      Serial.printf("GNSS UART -> %lu ok\n", (unsigned long)target);
      return;
    }
    Serial.printf("GNSS UART %lu silent, back to %lu\n", (unsigned long)target,
                  (unsigned long)old);
    openUart(rx_, txLive_, old, "baud-back");
    if (waitValid(1600)) markLocked();
  }

  void measureHz() {
    const uint32_t c0 = parser_.okFrames();
    (void)c0;
    epochCount_ = 0;
    hzWindowMs_ = millis();
    uint32_t pvts = 0;
    const uint32_t t0 = millis();
    while (millis() - t0 < 1100) {
      wdtFeed();
      poll();
      if (newRealPvt_) {  // 0.6.5-simpos: count the receiver's PVTs only
        pvts++;
        newRealPvt_ = false;
        newPvt_ = false;
      }
      delay(2);
    }
    if (pvts) hz_ = (uint8_t)(pvts > 50 ? 50 : pvts);
  }

  bool valget(const uint32_t* keys, int n) {
    uint8_t p[4 + 4 * 16];
    if (n > 16) return false;
    p[0] = 0;  // version
    p[1] = 0;  // RAM layer
    p[2] = p[3] = 0;
    for (int i = 0; i < n; ++i) memcpy(p + 4 + 4 * i, &keys[i], 4);
    UbxParser& cp = cmdParser();
    cp.clearValget();
    sendUbx(0x06, 0x8B, p, (uint16_t)(4 + 4 * n));
    return waitFor([&] { return cp.valgetSeen(); }, 600);
  }

  uint16_t buildValset(const Kv* kv, int n, uint8_t* p) {
    p[0] = 0;     // version
    p[1] = 0x01;  // RAM only: re-applied every boot, old firmware unaffected
    p[2] = p[3] = 0;
    uint16_t o = 4;
    for (int i = 0; i < n; ++i) {
      memcpy(p + o, &kv[i].key, 4);
      o += 4;
      const uint8_t sz = UbxParser::sizeFor(kv[i].key);
      memcpy(p + o, &kv[i].val, sz);  // little-endian
      o += sz;
    }
    return o;
  }

  void sendValset(const Kv* kv, int n) {
    uint8_t p[112];
    const uint16_t len = buildValset(kv, n, p);
    sendUbx(0x06, 0x8A, p, len);
  }

  bool valset(const Kv* kv, int n) {
    UbxParser& cp = cmdParser();
    for (int attempt = 0; attempt < 2; ++attempt) {
      cp.expectAck(0x06, 0x8A);
      sendValset(kv, n);
      waitFor([&] { return cp.ackState() != 0; }, 700);
      if (cp.ackState() == 1) {
        acks_++;
        return true;
      }
      if (cp.ackState() == -1) {
        naks_++;
        Serial.printf("GNSS VALSET NAK key0=%08lx\n", (unsigned long)kv[0].key);
        return false;
      }
    }
    Serial.printf("GNSS VALSET no ack key0=%08lx\n", (unsigned long)kv[0].key);
    return false;
  }

  bool ddcPresent() {
    if (!wire_) return false;
    wire_->beginTransmission(ADDR_UBLOX_I2C);
    return wire_->endTransmission() == 0;
  }

  void pollDdc(UbxParser* target, bool dataLink) {
    if (!wire_) return;
    wire_->beginTransmission(ADDR_UBLOX_I2C);
    wire_->write(0xFD);
    if (wire_->endTransmission(false) != 0) return;
    if (wire_->requestFrom((int)ADDR_UBLOX_I2C, 2) != 2) return;
    uint16_t avail = (uint16_t)wire_->read() << 8;
    avail |= wire_->read();
    if (avail == 0 || avail == 0xFFFF) return;
    if (avail > 512) avail = 512;
    const int64_t now = esp_timer_get_time();
    while (avail > 0) {
      const uint8_t want = avail > 32 ? 32 : (uint8_t)avail;
      const uint8_t got = wire_->requestFrom((int)ADDR_UBLOX_I2C, (int)want);
      if (got == 0) return;
      for (uint8_t i = 0; i < got; ++i) {
        const uint8_t c = (uint8_t)wire_->read();
        if (dataLink) {
          feedByte(c, now);
        } else {
          target->feed(c, now);
        }
      }
      avail -= got;
    }
  }

  bool sendUbx(uint8_t cls, uint8_t id, const uint8_t* payload, uint16_t len) {
    uint8_t frame[8 + 120];
    if (len > 120) return false;
    uint8_t ckA = 0, ckB = 0;
    frame[0] = 0xB5;
    frame[1] = 0x62;
    frame[2] = cls;
    frame[3] = id;
    frame[4] = (uint8_t)(len & 0xFF);
    frame[5] = (uint8_t)(len >> 8);
    if (len) memcpy(frame + 6, payload, len);
    for (uint16_t i = 2; i < 6 + len; ++i) {
      ckA = (uint8_t)(ckA + frame[i]);
      ckB = (uint8_t)(ckB + ckA);
    }
    frame[6 + len] = ckA;
    frame[7 + len] = ckB;
    const uint16_t n = (uint16_t)(8 + len);
    bool ok = false;
    if (path_ == Path::I2c && wire_) {
      wire_->beginTransmission(ADDR_UBLOX_I2C);
      wire_->write(frame, n);
      ok = wire_->endTransmission() == 0;
    } else if (serial_ && txLive_ >= 0) {
      serial_->write(frame, n);
      serial_->flush();
      ok = true;
    }
    return ok;
  }

  HardwareSerial* serial_ = nullptr;
  TwoWire* wire_ = nullptr;
  TinyGPSPlus gps_;
  UbxParser parser_;
  UbxParser ddcParser_;
  Path path_ = Path::None;
  uint32_t bytes_ = 0;
  size_t comboIdx_ = 0;
  int rx_ = -1;
  int txLive_ = -1;
  int foundTx_ = -1;
  uint32_t baud_ = 0;
  uint32_t lastSwitchMs_ = 0;
  uint32_t huntBase_ = 0;
  uint8_t huntStep_ = 0;
  uint8_t huntAlt_ = 0;
  uint32_t dwellMs_ = 1500;
  int goodRx_ = -1;
  uint32_t goodBaud_ = 0;
  int avoidRx_ = -1;
  uint32_t lastPollMs_ = 0, lastByteMs_ = 0;
  uint32_t lastValidMs_ = 0;
  uint32_t lastValidCount_ = 0;
  uint32_t lastPvtMs_ = 0;
  uint32_t hzWindowMs_ = 0;
  uint16_t epochCount_ = 0;
  uint8_t hz_ = 0;
  uint8_t navHz_ = GNSS_TARGET_HZ;
  uint32_t cfgGen_ = 0;
  uint16_t acks_ = 0, naks_ = 0;
  uint32_t relinks_ = 0;
  // DIAG
  uint32_t lastMaintainMs_ = 0, lostAtMs_ = 0, bytesAtOpen_ = 0;
  int rxHigh_ = 0;
  volatile uint32_t uartBufFull_ = 0, uartFifoOvf_ = 0, uartFrameErr_ = 0;
  bool locked_ = false;
  bool useI2c_ = false;
  bool cfgTried_ = false;
  bool cfgOk_ = false;
  bool pendingFix_ = false;
  bool newPvt_ = false, newSat_ = false, newDop_ = false;
  // 0.6.5-simpos
  bool newRealPvt_ = false;
  uint32_t lastRealPvtMs_ = 0;
  bool simOn_ = false, simHave_ = false;
  uint32_t simLastMs_ = 0, simRx_ = 0, simStales_ = 0;
  UbxPvt simPvt_;
  char linkBuf_[32] = "?";
  char pathBuf_[16] = "";
  char cfgStatus_[16] = "none";
  char fwVer_[64] = "";
};

}  // namespace riderlab
