// RiderLab logger — GNSS + IMU + baro → microSD; Wi‑Fi upload after stop.
// Roles (persistent, NVS): RIDER (default, bike unit) / ANCHOR (static
// reference station on a marked paddock point). Same receiver profile in both.
#include <Arduino.h>
#include <M5Unified.h>
#include <SD.h>
#include <WiFi.h>
#include <Wire.h>
#include <driver/gpio.h>
#include <esp_timer.h>
#include <esp_bt.h>
#include "BlePair.h"

#include "HardwareConfig.h"
#include "UiChrome.h"
#include "PpsClock.h"
#include "GpsClock.h"
#include "GnssService.h"
#include "ImuService.h"
#include "BaroService.h"
#include "TelemetryLogger.h"
#include "WifiUploader.h"
#include "RideIndex.h"
#include "EventLog.h"
#include "RoleConfig.h"
#include "AnchorEngine.h"
#include "DiagLog.h"
#include "UploadTask.h"
#include <new>
#include <Preferences.h>
#include "CircuitFile.h"
#include "LapTimer.h"
#include "LiveDelta.h"  // 0.6.2-circuit.7-rastro
#include "CircuitEmbedded_suave.h"  // 0.6.2-circuit.2: smoothed edges
#include "CircuitView.h"
#include "CircuitIndex.h"  // 0.6.7-autocircuit

using namespace riderlab;

static PpsClock pps;
static GpsClock gclock;
static GnssService gnss;
static ImuService imu;
static BaroService baro;
static TelemetryLogger logger;
static WifiUploader uploader;
static RideIndex rides;
static RoleConfig role;
static AnchorEngine anc;
static AnchorUi ancUi;

static uint32_t lastImuUs = 0;
static uint32_t lastImuLogMs = 0;
static uint32_t lastBaroSampleUs = 0;
static uint32_t lastBaroLogMs = 0;
static uint32_t lastUiMs = 0;
static uint32_t lastLogMs = 0;
static uint32_t lastBeatMs = 0;
static uint32_t lastSummaryMs = 0;
static uint32_t lastQualityMs = 0;
static uint32_t lastInputMs = 0;
static uint32_t bootMs = 0;
static uint32_t movedAlertUntil = 0;
static bool dimmed = false;
static bool userStopped = false;
static bool coloc = false;
static int markNo = 0;
static String uiLine = "ready";
static UiState ui;
static bool wantUpload = false;
static uint32_t lastWifiTryMs = 0;
static uint32_t uploadAfterMs = 0;
// 0.5.2 upload scheduler: real wait between attempts + exponential backoff.
// 0.6.2-circuit.7-rastro: home status bar state
static bool upLastErr = false;          // last upload job failed (cleared on success)
static int32_t sdFreeMb = -1;           // cached SD free space (MB), -1 = not measured
static bool sdFreeDirty = true;         // re-measure when idle (boot, after a recording)
static uint32_t nextWifiTryMs = 0;      // earliest automatic attempt (millis)
static uint32_t wifiBackoffMs = 0;      // 0 = no backoff active
static uint8_t wifiFailStreak = 0;
static bool wifiScanning = false;       // async pre-join scan in flight
static uint32_t wifiScanT0 = 0;
// 0.5.3 uploader task (core 0). loop() owns SD/LCD; the task owns Wi-Fi + TLS.
static UploadTask upTask;
// 0.6.8-ble pairing mode state
static riderlab::BlePair ble;
static char gBlePin[8] = "";
static uint32_t gBleT0 = 0, gBleExitAt = 0;
static int gBleBad = 0;
static const char* gBleExitWhy = "done";
static bool gBleAuthed = false;
static String gBleLine;
static WifiUploader::WifiSnap gWifiSnap;  // pre-BLE-WIFI snapshot (serial WIFIUNDO)
// The BT controller memory (~60 KB DRAM) is given back to the heap at boot unless this boot was requested
// for pairing (NVS rl_ble/boot). Once released it cannot be re-taken without a reboot, so EMPAREJAR from a
// normal boot = save the flag + restart straight into pairing; leaving pairing releases it again.
static bool gBtMemFree = false;
static uint8_t gBlePairBoot = 0;  // 1 = menu, 2 = serial
static UploadJob upJob;                 // prepared by loop(), copied into the task on start
static bool upTaskOk = false;
static bool pendingRadioOff = false;    // radio off deferred until the task is idle
static uint8_t lastUpPhase = 0;
static uint32_t upStartMs = 0;
static int upPassOk = 0;
static char upCancelWhy[16] = "";
// 0.5.4: 8-bit heap sampled by loop() while the task is in the TLS phase.
static uint32_t tlsMinFree8 = 0xFFFFFFFFUL, tlsMinBig8 = 0xFFFFFFFFUL, tlsSamples = 0;
static uint32_t tlsLastSampleMs = 0;
static BaroSample lastBaro;
static bool haveBaro = false;
static float lastAx = 0, lastAy = 0, lastAz = 0, lastGx = 0, lastGy = 0, lastGz = 0;
static const char* resetName = "?";

static double towNow() {
  const char* s;
  return gclock.towAt(esp_timer_get_time(), &s);
}

static String hwId() {
  char b[16];
  const uint64_t mac = ESP.getEfuseMac();
  snprintf(b, sizeof(b), "%012llx", (unsigned long long)(mac & 0xFFFFFFFFFFFFULL));
  return String(b);
}

static void autoManifestJson(char* b, size_t n);
static String manifestExtra() {
  char rcv[420];
  gnss.configJson(rcv, sizeof(rcv));
  const RefPoint& r = role.ref();
  char ref[260];
  if (r.set) {
    snprintf(ref, sizeof(ref),
             "{\"id\":\"%s\",\"lat\":%.9f,\"lon\":%.9f,\"h\":%.3f,\"h_type\":\"%s\","
             "\"source\":\"%s\",\"sigma_m\":%.3f}",
             r.id, r.lat, r.lon, r.h, r.hMsl ? "msl" : "ell", r.source, r.sigma);
  } else {
    strcpy(ref, "null");
  }
  char buf[1100];
  snprintf(buf, sizeof(buf),
           ",\"role\":\"%s\",\"hw_id\":\"%s\",\"boot_reset\":\"%s\",\"prev_session\":\"%s\","
           "\"ant_h_m\":%.3f,\"ref\":%s,\"receiver\":%s,"
           "\"baro\":{\"chip\":\"BMP280\",\"osrs_p\":4,\"osrs_t\":1,\"iir\":16,\"odr_hz\":83,"
           "\"sample_hz\":%lu,\"log_hz\":%lu},\"imu_log_hz\":%lu,\"clock\":\"%s\",\"keep_sd\":%s",
           role.roleName(), hwId().c_str(), resetName, role.lastSession().c_str(), role.antH(),
           ref, rcv, (unsigned long)BARO_SAMPLE_HZ, (unsigned long)BARO_LOG_HZ,
           (unsigned long)(role.anchor() ? ANCHOR_IMU_LOG_HZ : IMU_TARGET_HZ),
           pps.good() ? "pps" : "rx", role.keepSd() ? "true" : "false");
  if (role.anchor()) return String(buf);
  char au[600];
  autoManifestJson(au, sizeof au);  // 0.6.3-auto
  return String(buf) + au;
}

static void fillRidesUi() {
  const int n = rides.count();
  ui.rideCount = n;
  const int vis = n > 5 ? 5 : n;
  if (vis == 0) ui.rideSel = 0;
  else if (ui.rideSel >= vis) ui.rideSel = vis - 1;
  for (int i = 0; i < 5; ++i) {
    ui.rides[i].label[0] = 0;
    ui.rides[i].cloud = false;
    if (i >= vis) continue;
    const RideRec& r = rides.newest(i);
    char shortId[9];
    strncpy(shortId, r.id, 8);
    shortId[8] = 0;
    snprintf(ui.rides[i].label, sizeof(ui.rides[i].label), "%s  %u pts", shortId,
             (unsigned)r.gnss);
    ui.rides[i].cloud = r.cloud;
    ui.rides[i].ok = r.cloud || r.gnss > 0;
  }
}

static void paint(const GnssFix& fix);
// 0.6.7: boot step timing (straight to Serial, SD-independent)
static uint32_t gBootStepMs = 0;
static void bootStep(const char* what) {
  const uint32_t now = millis();
  Serial.printf("BOOTSTEP %-14s t_ms=%lu dt_ms=%lu\n", what, (unsigned long)now,
                (unsigned long)(gBootStepMs ? now - gBootStepMs : 0));
  gBootStepMs = now;
}
static bool gUpHold = false;  // 0.6.7: UPLOAD HOLD (NVS rl_up/hold): no automatic uploads while ON
static void circuitPaint();
static bool circFollowing();  // 0.6.6-follow
static void circuitRelease(const char* why);

// ---- 0.6.7-autocircuit state ----
static CircuitIndex cidx;
static int gCircSel = -1;          // entry circuitLoad() uses (-1 = nothing chosen / detected -> 0.6.6 default)
static int gCircDet = -1;          // auto-detected entry, -1 = none
static int gCircLoaded = -1;       // entry currently held in crt
static bool gCircManual = false;   // manual choice: holds until reboot or AUTOMATICO
static bool gAutoOpen = true;      // AUTOOPEN (NVS rl_view/ao, ON by default)
static bool gLastFollow = true;    // last circuit view (NVS rl_view/lv): true = FOLLOW (default), false = MAP
static bool gCircAutoOpenPending = false;
static uint32_t gCircAutoOpenAt = 0;
// 0.6.9-trail: session without circuit -> Trail page (bare follow + speed), opened from loop like the circuit
static bool gTrailPending = false;
static uint32_t gTrailAt = 0;
static void trailClose(const char* why);
static void trailResetAnchor();
static char gToast[40] = "";
static uint32_t gToastUntil = 0;
static int gListIdx[5] = {-1, -1, -1, -1, -1};
static constexpr float kDetectM = 500.f, kLoseM = 2000.f, kDetectHaccM = 5.f;
static constexpr const char* kEmbeddedName = "8 Horas Zapopan";

static void radioOff() {
  WiFi.disconnect(true, false);
  WiFi.mode(WIFI_OFF);
}

// 0.5.3: never pull the radio from under the uploader task; defer until idle.
static void requestRadioOff() {
  if (upTask.busy()) {
    pendingRadioOff = true;
    return;
  }
  radioOff();
}

// 0.5.3: the ONE cancel path (buttons, recording start, serial UPCANCEL).
// Non-blocking: sets the task's flag; the task closes the socket and reports.
static void cancelUpload(const char* why) {
  if (!upTask.busy() || upTask.cancelRequested()) return;
  upTask.cancel();
  snprintf(upCancelWhy, sizeof(upCancelWhy), "%s", why);
  gDiag.logf("upload", "CANCEL request why=%s phase=%s sid=%.13s t_ms=%lu", why,
             UploadTask::phaseName(upTask.phase()), upJob.sid,
             (unsigned long)(millis() - upStartMs));
}

static void mark(const char* kind, float v, const char* note) {
  logger.logMark(kind, towNow(), v, note);
  gLog.logf(LogLvl::Info, "mark", "%s v=%.3f %s", kind, v, note ? note : "");
}

static const char* pageName() {
  switch (ui.page) {
    case UiPage::Home:
      return "home";
    case UiPage::Menu:
      return "menu";
    case UiPage::Wifi:
      return "wifi";
    case UiPage::Rides:
      return "rides";
    case UiPage::About:
      return "about";
    case UiPage::Circuit:
      return "circuit";
    case UiPage::CircuitList:
      return "circuits";
    case UiPage::Trail:
      return "trail";
    case UiPage::BlePair:
      return "ble";
    default:
      return "?";
  }
}

// ======================= 0.6.3-auto: automatic sessions, idle GNSS rate, standby dim =======================
// States (rider role only):
//   OFF      auto disabled (AUTO OFF): manual A only, GNSS stays at the session rate.
//   ARMED    no session; GNSS at idleHz (default 1 Hz); evaluated on EVERY PVT (= once per second at 1 Hz).
//   CAND     one good fix > START_KMH seen: GNSS switched to 10 Hz at once; session opens after START_S of
//            good fixes all > START_KMH. A good fix <= START_KMH fails the candidate; 10 s after the last
//            fast fix the receiver goes back to idleHz (ARMED).
//   REC_AUTO session opened by the logic; closes after STOP_S continuous good fixes < STOP_KMH, or
//            after FIXLOSS_S without a good fix (shorter dropouts are ignored). Tail is marked.
//   REC_MAN  session opened with A/menu/serial: never auto-closed (manual override).
//   ESPERA   after a manual stop: no auto start until a good fix < STOP_KMH is seen (no instant re-arm).
// Hysteresis = start > START_KMH (15) vs stop < STOP_KMH (7) + time windows. Sessions always at 10 Hz.
struct AutoCfg {
  bool on = true;
  float startKmh = 15.f;
  uint16_t startS = 3;
  float stopKmh = 7.f;
  uint16_t stopS = 60;
  uint16_t fixLossS = 20;
  float hAccM = 5.f;
  uint8_t idleHz = 1;
  uint8_t preS = 5;
  bool dimOn = true;
  uint16_t dimS = 30;
  uint8_t dimPct = 12;
};
static AutoCfg acfg;
enum class AutoSt : uint8_t { Off, Armed, Cand, RecAuto, RecManual, Inhibit };
static AutoSt ast = AutoSt::Armed;
static bool simOn = false;
static float simKmh = 0.f;
static uint32_t candT0 = 0, candLastAbove = 0, slowSince = 0, lostSince = 0, lastEvalMs = 0;
static int64_t candUs = 0, slowUs = 0;
static bool gAutoStart = false, gAutoStop = false;
static char gAutoStopWhy[20] = "manual";
static float lastEvalKmh = 0.f;
static bool lastEvalGood = false;
struct SessInfo {
  bool autoTrig = false, sim = false;
  bool simPos = false;  // 0.6.5-simpos: positions injected over serial -> never uploaded
  int64_t candUs = 0;
  uint16_t prePvt = 0, prePvtCand = 0, preBaro = 0;
  char stopReason[20] = "";
  float tailS = -1.f;
  int64_t tailUs = 0;
};
static SessInfo sinfo;

static const char* autoStName(AutoSt s) {
  switch (s) {
    case AutoSt::Off: return "OFF";
    case AutoSt::Armed: return "ARMED";
    case AutoSt::Cand: return "CAND";
    case AutoSt::RecAuto: return "REC_AUTO";
    case AutoSt::RecManual: return "REC_MANUAL";
    case AutoSt::Inhibit: return "INHIBIT";
  }
  return "?";
}
static void autoSet(AutoSt s, const char* why) {
  if (s == ast) return;
  gDiag.logf("auto", "STATE %s -> %s why=%s kmh=%.1f good=%d sim=%d nav_hz=%u t_ms=%lu",
             autoStName(ast), autoStName(s), why, lastEvalKmh, (int)lastEvalGood, (int)simOn,
             (unsigned)gnss.navHz(), (unsigned long)millis());
  Serial.printf("AUTO %s -> %s (%s) t_ms=%lu\n", autoStName(ast), autoStName(s), why,
                (unsigned long)millis());
  ast = s;
}

static void autoLoad() {
  Preferences p;
  if (!p.begin("rl_auto", true)) return;
  acfg.on = p.getBool("on", acfg.on);
  acfg.startKmh = p.getFloat("sk", acfg.startKmh);
  acfg.startS = p.getUShort("ss", acfg.startS);
  acfg.stopKmh = p.getFloat("pk", acfg.stopKmh);
  acfg.stopS = p.getUShort("ps", acfg.stopS);
  acfg.fixLossS = p.getUShort("fl", acfg.fixLossS);
  acfg.hAccM = p.getFloat("ha", acfg.hAccM);
  acfg.idleHz = p.getUChar("ih", acfg.idleHz);
  acfg.dimOn = p.getBool("dOn", acfg.dimOn);
  acfg.dimS = p.getUShort("dS", acfg.dimS);
  acfg.dimPct = p.getUChar("dP", acfg.dimPct);
  p.end();
}
static void autoSave() {
  Preferences p;
  if (!p.begin("rl_auto", false)) return;
  p.putBool("on", acfg.on);
  p.putFloat("sk", acfg.startKmh);
  p.putUShort("ss", acfg.startS);
  p.putFloat("pk", acfg.stopKmh);
  p.putUShort("ps", acfg.stopS);
  p.putUShort("fl", acfg.fixLossS);
  p.putFloat("ha", acfg.hAccM);
  p.putUChar("ih", acfg.idleHz);
  p.putBool("dOn", acfg.dimOn);
  p.putUShort("dS", acfg.dimS);
  p.putUChar("dP", acfg.dimPct);
  p.end();
}

static void autoManifestJson(char* b, size_t n) {
  snprintf(b, n,
           ",\"auto\":{\"trigger\":\"%s\",\"sim\":%s,\"sim_pos\":%s,\"cfg\":{\"start_kmh\":%.1f,\"start_s\":%u,"
           "\"stop_kmh\":%.1f,\"stop_s\":%u,\"fixloss_s\":%u,\"hacc_m\":%.1f,\"idle_hz\":%u},"
           "\"preroll\":{\"s\":%u,\"pvt\":%u,\"pvt_after_cand\":%u,\"baro\":%u,\"hz_before_cand\":%u,"
           "\"hz_after_cand\":%u,\"cand_t_us\":%lld},\"stop_reason\":\"%s\",\"tail_s\":%.1f,"
           "\"tail_from_us\":%lld}",
           sinfo.autoTrig ? "auto" : "manual", sinfo.sim ? "true" : "false",
           sinfo.simPos ? "true" : "false", acfg.startKmh,
           (unsigned)acfg.startS, acfg.stopKmh, (unsigned)acfg.stopS, (unsigned)acfg.fixLossS,
           acfg.hAccM, (unsigned)acfg.idleHz, (unsigned)acfg.preS, (unsigned)sinfo.prePvt,
           (unsigned)sinfo.prePvtCand, (unsigned)sinfo.preBaro, (unsigned)acfg.idleHz,
           (unsigned)GNSS_TARGET_HZ, (long long)sinfo.candUs, sinfo.stopReason, sinfo.tailS,
           (long long)sinfo.tailUs);
}

// ---- pre-roll rings (filled only while no session is open) ----
static constexpr int kPreN = 56;  // >= 5 s at 10 Hz
static UbxPvt prePvt[kPreN];
static uint32_t prePvtPps[kPreN];
static int preHead = 0, preCnt = 0;
struct PreBaro {
  BaroSample b;
  double tow;
  const char* src;
  uint32_t pps;
};
static PreBaro preBaro[kPreN];
static int pbHead = 0, pbCnt = 0;
static void prePushPvt(const UbxPvt& p, uint32_t seq) {
  prePvt[preHead] = p;
  prePvtPps[preHead] = seq;
  preHead = (preHead + 1) % kPreN;
  if (preCnt < kPreN) preCnt++;
}
static void prePushBaro(const BaroSample& b, double tow, const char* src, uint32_t seq) {
  preBaro[pbHead] = {b, tow, src, seq};
  pbHead = (pbHead + 1) % kPreN;
  if (pbCnt < kPreN) pbCnt++;
}
static uint32_t pvtUtcMs(const UbxPvt& p) {
  int64_t ms = ((int64_t)p.hour * 3600 + p.min * 60 + p.sec) * 1000 +
               (p.nano >= 0 ? (p.nano + 500000) / 1000000 : -((-p.nano + 500000) / 1000000));
  if (ms < 0) ms += 86400000;
  return (uint32_t)ms;
}
// pass 1 (replay=false) only counts, for the manifest written by startSession().
static void prerollRun(bool replay) {
  const int64_t cut = esp_timer_get_time() - (int64_t)acfg.preS * 1000000;
  uint16_t n = 0, nc = 0, nb = 0;
  for (int k = 0; k < preCnt; ++k) {
    const int i = (preHead - preCnt + k + kPreN) % kPreN;
    const UbxPvt& p = prePvt[i];
    if (p.rxUs < cut) continue;
    n++;
    if (sinfo.candUs && p.rxUs >= sinfo.candUs) nc++;
    if (!replay) continue;
    logger.logPvt(p, prePvtPps[i]);
    if (p.fixType >= 2 && p.gnssFixOk() && !p.invalidLlh())
      logger.logGnssAt(p.rxUs, prePvtPps[i], p.latDeg(), p.lonDeg(), p.hMsl(), p.gSpeed * 1e-3,
                       p.headMot * 1e-5, p.hAccM(), p.numSV, p.pDOP * 0.01, pvtUtcMs(p));
  }
  for (int k = 0; k < pbCnt; ++k) {
    const int i = (pbHead - pbCnt + k + kPreN) % kPreN;
    if (preBaro[i].b.midUs < cut) continue;
    nb++;
    if (replay) logger.logBaro(preBaro[i].pps, preBaro[i].b, preBaro[i].tow, preBaro[i].src, nullptr, -1);
  }
  sinfo.prePvt = n;
  sinfo.prePvtCand = nc;
  sinfo.preBaro = nb;
  if (replay) preCnt = pbCnt = 0;
}

// ---- GNSS rate management + switch-latency measurement ----
static uint32_t rateGenSeen = 0, rateRetryMs = 0;
static bool rateWatch = false;
static uint8_t rateTo = 0;
static int64_t rateCmdUs = 0, rateAckUs = 0, lastPvtRxUs = 0;
static uint8_t autoRateWant() {
  if (role.anchor() || !acfg.on || logger.recording()) return GNSS_TARGET_HZ;
  return (ast == AutoSt::Armed || ast == AutoSt::Inhibit) ? acfg.idleHz : GNSS_TARGET_HZ;
}
static void autoRateApply(uint8_t want, const char* why) {
  const uint8_t from = gnss.navHz();
  uint32_t ackMs = 0;
  rateCmdUs = esp_timer_get_time();
  const bool ok = gnss.setNavRate(want, &ackMs);
  rateAckUs = rateCmdUs + (int64_t)ackMs * 1000;
  gDiag.logf("auto", "RATE %u->%u Hz cmd(VALSET RAM CFG-RATE-MEAS=%u ms) ack=%d ack_ms=%lu why=%s state=%s",
             (unsigned)from, (unsigned)want, (unsigned)(1000 / want), (int)ok, (unsigned long)ackMs,
             why, autoStName(ast));
  Serial.printf("AUTO RATE %u->%u Hz ack=%d ack_ms=%lu why=%s\n", (unsigned)from, (unsigned)want,
                (int)ok, (unsigned long)ackMs, why);
  if (!ok) {
    rateRetryMs = millis() + 3000;
    return;
  }
  rateRetryMs = 0;
  rateTo = want;
  rateWatch = true;
}
static void autoRateService(uint32_t now) {
  if (!gnss.configured()) return;
  if (rateGenSeen != gnss.cfgGen()) rateGenSeen = gnss.cfgGen();  // reconfigure -> back at 10 Hz
  const uint8_t want = autoRateWant();
  if (want == gnss.navHz()) return;
  if (rateRetryMs && (int32_t)(now - rateRetryMs) < 0) return;
  autoRateApply(want, "service");
}
static void autoRateWatchPvt(const UbxPvt& p) {
  const int64_t dt = lastPvtRxUs ? p.rxUs - lastPvtRxUs : 0;
  lastPvtRxUs = p.rxUs;
  if (!rateWatch || p.rxUs <= rateAckUs) {
    if (rateWatch && esp_timer_get_time() - rateCmdUs > 5000000) rateWatch = false;
    return;
  }
  const bool fast = rateTo >= 5;
  const bool hit = fast ? (dt > 0 && dt < 150000) : (dt > 700000);
  if (hit) {
    rateWatch = false;
    gDiag.logf("auto", "RATE effective %u Hz: cmd->ack %lld ms, cmd->first %s-spaced fix %lld ms "
               "(dt=%lld ms iTOW=%lu)",
               (unsigned)rateTo, (long long)((rateAckUs - rateCmdUs) / 1000), fast ? "100ms" : "1s",
               (long long)((p.rxUs - rateCmdUs) / 1000), (long long)(dt / 1000),
               (unsigned long)p.iTOW);
    Serial.printf("AUTO RATE effective %u Hz cmd->ack=%lldms cmd->first_fix=%lldms dt=%lldms iTOW=%lu\n",
                  (unsigned)rateTo, (long long)((rateAckUs - rateCmdUs) / 1000),
                  (long long)((p.rxUs - rateCmdUs) / 1000), (long long)(dt / 1000),
                  (unsigned long)p.iTOW);
  } else if (esp_timer_get_time() - rateCmdUs > 5000000) {
    rateWatch = false;
    gDiag.logf("auto", "RATE effective-check timeout to=%u Hz last_dt=%lld ms", (unsigned)rateTo,
               (long long)(dt / 1000));
  }
}

// ---- standby dim ----
static void autoWake(uint32_t now, const char* why) {
  lastInputMs = now;
  if (dimmed && !role.anchor()) {
    dimmed = false;
    M5.Display.setBrightness(255);
    gDiag.logf("auto", "DIM off why=%s", why);
  }
}
static void autoDimService(uint32_t now) {
  if (role.anchor()) return;
  // 0.6.4 fix: signed age (lastInputMs can be set later in the same loop than `now`, e.g. by stopRec());
  // 0.6.3 saw that as ~49 days -> "DIM on" + "DIM off" flicker at every auto close.
  const int32_t age = (int32_t)(now - lastInputMs);
  const bool want = acfg.dimOn && !logger.recording() && age >= (int32_t)(acfg.dimS * 1000UL);
  if (want && !dimmed) {
    dimmed = true;
    M5.Display.setBrightness((uint8_t)(255 * acfg.dimPct / 100));
    gDiag.logf("auto", "DIM on after_s=%u level=%u%% state=%s", (unsigned)acfg.dimS,
               (unsigned)acfg.dimPct, autoStName(ast));
  } else if (!want && dimmed) {
    autoWake(now, logger.recording() ? "session" : "config");
  }
}

static void startRec(const char* why);
static void bleExit(const char* why);
static void stopRec();
static void circuitSessionEdge(const char* why);  // 0.6.4
static void processPvtEvent(uint32_t nowMs);       // 0.6.5-simpos
static void processFixEvent();                     // 0.6.5-simpos

static void autoClose(const char* why) {
  snprintf(gAutoStopWhy, sizeof gAutoStopWhy, "%s", why);
  gAutoStop = true;
  stopRec();
  gAutoStop = false;
}

static void autoStep(uint32_t now, bool good, float kmh) {
  lastEvalMs = now;
  lastEvalKmh = kmh;
  lastEvalGood = good;
  if (logger.recording() && (simOn || gnss.simOn())) sinfo.sim = true;
  if (logger.recording() && gnss.simOn()) sinfo.simPos = true;  // 0.6.5-simpos
  if (good && kmh > acfg.stopKmh) autoWake(now, "speed");
  char w[48];
  switch (ast) {
    case AutoSt::Off:
    case AutoSt::RecManual:
      return;
    case AutoSt::Inhibit:
      if (good && kmh < acfg.stopKmh) autoSet(AutoSt::Armed, "manual-stop-cleared(slow)");
      return;
    case AutoSt::Armed:
      if (good && kmh > acfg.startKmh) {
        candT0 = candLastAbove = now;
        candUs = esp_timer_get_time();
        snprintf(w, sizeof w, "fix>%.0fkmh(%.1f)", acfg.startKmh, kmh);
        autoSet(AutoSt::Cand, w);
        cancelUpload("auto-cand");
        autoRateApply(GNSS_TARGET_HZ, "candidate");  // immediately, inside this PVT callback
      }
      return;
    case AutoSt::Cand:
      if (good && kmh > acfg.startKmh) {
        if (!candT0) {
          candT0 = now;
          candUs = esp_timer_get_time();
          gDiag.logf("auto", "CAND restart kmh=%.1f", kmh);
        }
        candLastAbove = now;
        if (now - candT0 >= acfg.startS * 1000UL) {
          snprintf(w, sizeof w, "sustained %.1fs>%.0fkmh", (now - candT0) / 1000.f, acfg.startKmh);
          gDiag.logf("auto", "START confirm %s", w);
          gAutoStart = true;
          startRec((simOn || gnss.simOn()) ? "auto-sim" : "auto");
          gAutoStart = false;
          autoSet(logger.recording() ? AutoSt::RecAuto : AutoSt::Armed,
                  logger.recording() ? w : "start-refused");
        }
      } else if (good && candT0) {
        gDiag.logf("auto", "CAND fail kmh=%.1f after_ms=%lu", kmh, (unsigned long)(now - candT0));
        candT0 = 0;
      }
      if (!candT0 && now - candLastAbove >= 10000) autoSet(AutoSt::Armed, "cand-timeout-10s");
      return;
    case AutoSt::RecAuto:
      if (!good) {
        if (!lostSince) {
          lostSince = now;
          gDiag.logf("auto", "FIXLOSS begin");
        }
        if (now - lostSince >= acfg.fixLossS * 1000UL) autoClose("fixloss");
        return;
      }
      if (lostSince) {
        gDiag.logf("auto", "FIXLOSS end after_ms=%lu (ignored)", (unsigned long)(now - lostSince));
        lostSince = 0;
      }
      if (kmh < acfg.stopKmh) {
        if (!slowSince) {
          slowSince = now;
          slowUs = esp_timer_get_time();
          gDiag.logf("auto", "SLOW begin kmh=%.1f", kmh);
        }
        if (now - slowSince >= acfg.stopS * 1000UL) autoClose("slow");
      } else if (slowSince) {
        gDiag.logf("auto", "SLOW cancel kmh=%.1f after_ms=%lu", kmh, (unsigned long)(now - slowSince));
        slowSince = 0;
      }
      return;
  }
}

static void autoOnPvt(const UbxPvt& p, uint32_t now) {
  autoRateWatchPvt(p);
  if (role.anchor()) return;
  if (!logger.recording()) prePushPvt(p, pps.seq());
  const bool good = simOn || (p.fixType >= 3 && p.gnssFixOk() && !p.invalidLlh() &&
                              p.hAccM() <= acfg.hAccM);
  const float kmh = simOn ? simKmh : p.gSpeed * 0.0036f;
  autoStep(now, good, kmh);
}

// Timers that must fire even without PVTs (dead link) + rate + dim.
static void autoTick(uint32_t now) {
  if (role.anchor()) return;
  if (ast == AutoSt::RecAuto && lastEvalMs && now - lastEvalMs >= acfg.fixLossS * 1000UL)
    autoClose("no-pvt");
  if (ast == AutoSt::Cand && candT0 && now - candLastAbove > 3000) candT0 = 0;
  if (ast == AutoSt::Cand && !candT0 && now - candLastAbove >= 10000)
    autoSet(AutoSt::Armed, "cand-timeout-10s");
  autoRateService(now);
  autoDimService(now);
}

static void autoFillUi() {
  ui.autoTag[0] = ui.autoShort[0] = 0;
  ui.autoColor = C_MUTED;
  ui.autoSt = (uint8_t)ast;  // 0.6.4: status-bar REC icon
  if (role.anchor()) return;
  const char* sim = (simOn || gnss.simOn()) ? " SIM" : "";  // 0.6.5-simpos: also SIMPOS
  switch (ast) {
    case AutoSt::Off:
      snprintf(ui.autoTag, sizeof ui.autoTag, logger.recording() ? "REC" : "AUTO OFF");
      snprintf(ui.autoShort, sizeof ui.autoShort, "OFF");
      break;
    case AutoSt::Armed:
      snprintf(ui.autoTag, sizeof ui.autoTag, "AUTO ARMADO %uHz%s", (unsigned)gnss.navHz(), sim);
      snprintf(ui.autoShort, sizeof ui.autoShort, "ARMADO");
      ui.autoColor = C_OK;
      break;
    case AutoSt::Cand:
      snprintf(ui.autoTag, sizeof ui.autoTag, "AUTO CANDIDATO %.1fs%s",
               candT0 ? (millis() - candT0) / 1000.f : 0.f, sim);
      snprintf(ui.autoShort, sizeof ui.autoShort, "CAND");
      ui.autoColor = C_ORANGE;
      break;
    case AutoSt::RecAuto:
      snprintf(ui.autoTag, sizeof ui.autoTag, "GRABANDO AUTO%s", sim);
      snprintf(ui.autoShort, sizeof ui.autoShort, "AUTO");
      ui.autoColor = C_REC;
      break;
    case AutoSt::RecManual:
      snprintf(ui.autoTag, sizeof ui.autoTag, "GRABANDO MANUAL%s", sim);
      snprintf(ui.autoShort, sizeof ui.autoShort, "MAN");
      ui.autoColor = C_REC;
      break;
    case AutoSt::Inhibit:
      snprintf(ui.autoTag, sizeof ui.autoTag, "AUTO ESPERA <%.0f%s", acfg.stopKmh, sim);
      snprintf(ui.autoShort, sizeof ui.autoShort, "ESPERA");
      ui.autoColor = C_LV_YEL;
      break;
  }
}

static void autoPrint() {
  Serial.printf("AUTO %s state=%s sim=%s nav_hz=%u meas_hz=%u start>%.1fkmh/%us stop<%.1fkmh/%us "
                "fixloss=%us hacc<=%.1fm idlehz=%u preroll=%us dim=%s/%us/%u%% dimmed=%d "
                "last_kmh=%.1f good=%d cand_ms=%lu slow_ms=%lu simpos=%d\n",
                acfg.on ? "ON" : "OFF", autoStName(ast), simOn ? String(simKmh, 1).c_str() : "off",
                (unsigned)gnss.navHz(), (unsigned)gnss.hz(), acfg.startKmh, (unsigned)acfg.startS,
                acfg.stopKmh, (unsigned)acfg.stopS, (unsigned)acfg.fixLossS, acfg.hAccM,
                (unsigned)acfg.idleHz, (unsigned)acfg.preS, acfg.dimOn ? "ON" : "OFF",
                (unsigned)acfg.dimS, (unsigned)acfg.dimPct, (int)dimmed, lastEvalKmh,
                (int)lastEvalGood, (unsigned long)(candT0 ? millis() - candT0 : 0),
                (unsigned long)(slowSince ? millis() - slowSince : 0), (int)gnss.simOn());
}

// returns true if handled
static bool autoSerial(const String& line) {
  const char* c = line.c_str();
  float f1;
  unsigned u1, u2;
  if (line == "AUTO?" || line == "AUTO") {
  } else if (line == "AUTO ON" || line == "AUTO OFF") {
    acfg.on = line == "AUTO ON";
    autoSave();
    if (!acfg.on) autoSet(logger.recording() ? AutoSt::RecManual : AutoSt::Off, "AUTO OFF");
    else autoSet(logger.recording() ? (ast == AutoSt::RecManual ? AutoSt::RecManual : AutoSt::RecAuto)
                                    : AutoSt::Armed, "AUTO ON");
  } else if (sscanf(c, "AUTO START %f %u", &f1, &u1) == 2) {
    acfg.startKmh = f1, acfg.startS = (uint16_t)u1;
    autoSave();
  } else if (sscanf(c, "AUTO STOP %f %u", &f1, &u1) == 2) {
    acfg.stopKmh = f1, acfg.stopS = (uint16_t)u1;
    autoSave();
  } else if (sscanf(c, "AUTO FIXLOSS %u", &u1) == 1) {
    acfg.fixLossS = (uint16_t)u1;
    autoSave();
  } else if (sscanf(c, "AUTO HACC %f", &f1) == 1) {
    acfg.hAccM = f1;
    autoSave();
  } else if (sscanf(c, "AUTO IDLEHZ %u", &u1) == 1) {
    acfg.idleHz = (uint8_t)(u1 < 1 ? 1 : (u1 > GNSS_TARGET_HZ ? GNSS_TARGET_HZ : u1));
    autoSave();
  } else if (line == "AUTO DEFAULTS") {
    const AutoCfg d;
    acfg.startKmh = d.startKmh, acfg.startS = d.startS, acfg.stopKmh = d.stopKmh,
    acfg.stopS = d.stopS, acfg.fixLossS = d.fixLossS, acfg.hAccM = d.hAccM, acfg.idleHz = d.idleHz;
    autoSave();
  } else if (line == "SIMSPD OFF") {
    simOn = false;
    gDiag.logf("auto", "SIMSPD off");
    Serial.println("SIMSPD OFF");
    return true;
  } else if (sscanf(c, "SIMSPD %f", &f1) == 1) {
    simOn = true;
    simKmh = f1;
    gDiag.logf("auto", "SIMSPD %.1f km/h (auto logic only; not logged as GNSS)", f1);
    Serial.printf("SIMSPD %.1f\n", f1);
    return true;
  } else if (line == "DIM?" || line == "DIM") {
  } else if (line == "DIM ON" || line == "DIM OFF") {
    acfg.dimOn = line == "DIM ON";
    autoSave();
  } else if (sscanf(c, "DIM %u %u", &u1, &u2) == 2) {
    acfg.dimS = (uint16_t)u1;
    acfg.dimPct = (uint8_t)(u2 < 1 ? 1 : (u2 > 100 ? 100 : u2));
    autoSave();
    if (dimmed) M5.Display.setBrightness((uint8_t)(255 * acfg.dimPct / 100));
  } else {
    return false;
  }
  autoPrint();
  return true;
}
// ===================================================================================================

static void startRec(const char* why) {
  if (ble.on()) bleExit("rec-start");  // 0.6.8: recording always wins over pairing
  const uint32_t t0 = millis();
  gDiag.logf("rec", "START request why=%s role=%s rec=%d sd=%d userStopped=%d page=%s wifi=%d "
             "pending=%d gnss=%s fix=%d",
             why, role.roleName(), (int)logger.recording(), (int)logger.sdOk(), (int)userStopped,
             pageName(), (int)(WiFi.getMode() != WIFI_OFF), rides.pendingCount(), gnss.linkTag(),
             (int)gnss.snapshot().valid);
  wantUpload = false;
  cancelUpload("rec-start");
  if (wifiScanning) {
    WiFi.scanDelete();
    wifiScanning = false;
  }
  requestRadioOff();
  const char* did =
      uploader.deviceId().length() ? uploader.deviceId().c_str() : "unpaired";
  logger.setPins(gnss.rxPin(), gnss.txPin());
  // 0.6.3-auto: sessions always at the full rate; pre-roll + trigger info for the manifest
  if (!role.anchor() && !logger.recording() && gnss.configured() && gnss.navHz() != GNSS_TARGET_HZ)
    autoRateApply(GNSS_TARGET_HZ, "session-start");
  sinfo = SessInfo();
  sinfo.autoTrig = gAutoStart;
  sinfo.sim = simOn || gnss.simOn();
  sinfo.simPos = gnss.simOn();  // 0.6.5-simpos
  sinfo.candUs = gAutoStart ? candUs : 0;
  if (!role.anchor()) prerollRun(false);
  logger.setManifestExtra(manifestExtra());
  if (logger.startSession(did, role.anchor())) {
    if (!role.anchor()) {
      prerollRun(true);
      char pn[64];
      snprintf(pn, sizeof pn, "pvt=%u after_cand=%u baro=%u idle_hz=%u", (unsigned)sinfo.prePvt,
               (unsigned)sinfo.prePvtCand, (unsigned)sinfo.preBaro, (unsigned)acfg.idleHz);
      mark("preroll", (float)acfg.preS, pn);
      mark(gAutoStart ? "auto_start" : "manual_start", 0,
           gnss.simOn() ? "simpos" : (simOn ? "sim" : ""));
      if (!gAutoStart && ast != AutoSt::Off) autoSet(AutoSt::RecManual, why);
      autoWake(millis(), "session");
      circuitSessionEdge(gAutoStart ? "open-auto" : "open-manual");  // 0.6.4
      // 0.6.7-autocircuit: open the detected/chosen circuit AFTER the session is running (loop, ~150 ms)
      if (gAutoOpen && gCircSel >= 0 && ui.page != UiPage::Circuit) {
        gCircAutoOpenPending = true;
        gCircAutoOpenAt = millis() + 150;
      }
      // 0.6.9-trail: no circuit detected/chosen -> fading trail + speed instead of the speedometer
      trailResetAnchor();
      if (gAutoOpen && gCircSel < 0 && ui.page == UiPage::Home) {
        gTrailPending = true;
        gTrailAt = millis() + 150;
      }
    }
    rides.addLocal(logger.sessionId(), 0);
    mark("session_start", 0, why);
    if (role.lastSession().length()) mark("prev_session", 0, role.lastSession().c_str());
    role.setLastSession(logger.sessionId());
    uiLine = role.anchor() ? "Ancla grabando" : "Recording…";
    lastSummaryMs = millis();
    gDiag.logf("rec", "START ok id=%s ms=%lu", logger.sessionId().c_str(),
               (unsigned long)(millis() - t0));
  } else {
    uiLine = String("Start fail: ") + logger.err();
    const char* reason = !logger.sdOk() ? "sd-not-ok" : (logger.recording() ? "already-recording"
                                                                             : "logger-error");
    gDiag.logf("rec", "START REFUSED reason=%s err=%s ms=%lu", reason, logger.err().c_str(),
               (unsigned long)(millis() - t0));
  }
}

static void writeAnchorSummary(bool complete) {
  if (!role.anchor() || logger.sessionDir().length() == 0) return;
  constexpr size_t kBuf = 3600;  // 0.6.8: heap (anchor role only) -> DRAM for the BLE controller
  char* buf = (char*)malloc(kBuf);
  if (!buf) return;
  const size_t n = anc.summaryJson(buf, kBuf, role.ref(), role.antH(), millis(),
                                   logger.secondsRecording(), complete);
  if (n) logger.writeSessionFile("anchor_summary.json", buf);
  free(buf);
}

static void stopRec() {
  const uint32_t t0 = millis();
  const String id = logger.sessionId();
  const uint16_t g = (uint16_t)logger.gnssCount();
  gDiag.logf("rec", "STOP request id=%s rec=%d gnss_pts=%u secs=%lu page=%s", id.c_str(),
             (int)logger.recording(), (unsigned)g, (unsigned long)logger.secondsRecording(),
             pageName());
  if (coloc) {
    coloc = false;
    mark("coloc_end", 0, "stop");
  }
  if (!role.anchor()) {  // 0.6.3-auto
    snprintf(sinfo.stopReason, sizeof sinfo.stopReason, "%s", gAutoStop ? gAutoStopWhy : "manual");
    if (gAutoStop && slowSince) {
      sinfo.tailS = (millis() - slowSince) / 1000.f;
      sinfo.tailUs = slowUs;
      mark("stationary_tail", sinfo.tailS, "speed<stop_kmh since tail_from_us (trim candidate)");
    }
    mark(gAutoStop ? "auto_stop" : "manual_stop", 0, sinfo.stopReason);
    logger.setManifestExtra(manifestExtra());
  }
  mark("session_stop", 0, "");
  writeAnchorSummary(true);
  logger.stopSession();
  writeAnchorSummary(true);  // summary survives with complete=true
  // 0.6.5-simpos: simulated-position sessions stay on the SD but never enter the upload queue
  // (gnss=0 in the ride index = not pending; REUP skips them too).
  // 0.6.9b: NO distinction any more: SIMPOS sessions enter the upload queue like real ones (HOLD/pairing apply)
  const bool noUpload = false;
  rides.updateGnss(id, noUpload ? 0 : g);
  if (noUpload) {
    gDiag.logf("simpos", "session %s sim_pos=1 gnss_pts=%u -> no upload", id.c_str(), (unsigned)g);
    Serial.printf("SIMPOS session %s closed pts=%u (sim, not uploaded)\n", id.c_str(), (unsigned)g);
  }
  uiLine = g > 0 ? (noUpload ? "Stopped (sim)" : "Stopped") : "Stopped 0 pts";
  sdFreeDirty = true;  // 0.6.2-circuit.7-rastro: refresh SD free space when idle
  paint(gnss.snapshot());
  if (!role.anchor() && uploader.configured() && g > 0 && !noUpload) {
    wantUpload = true;
    uploadAfterMs = millis() + 4000;
  }
  if (!role.anchor()) {
    slowSince = lostSince = candT0 = 0;
    autoSet(!acfg.on ? AutoSt::Off : (gAutoStop ? AutoSt::Armed : AutoSt::Inhibit),
            gAutoStop ? gAutoStopWhy : "manual-stop");
    lastInputMs = millis();  // dim countdown starts at session end
    circuitSessionEdge(gAutoStop ? "close-auto" : "close-manual");  // 0.6.4
    gTrailPending = false;
    trailClose("stop");  // 0.6.9-trail: back to the home speedometer
  }
  gDiag.logf("rec", "STOP done id=%s ms=%lu rec=%d wantUpload=%d upload_in_ms=%d wifi_cfg=%d "
             "pending=%d keepsd=%d",
             id.c_str(), (unsigned long)(millis() - t0), (int)logger.recording(), (int)wantUpload,
             wantUpload ? 4000 : -1, (int)uploader.configured(), rides.pendingCount(),
             (int)role.keepSd());
}

static const char* fixName(uint8_t f) {
  switch (f) {
    case 2:
      return "2D";
    case 3:
      return "3D";
    case 4:
      return "3D+DR";
    case 5:
      return "time";
    default:
      return "no";
  }
}

static void fillAnchorUi() {
  const uint32_t now = millis();
  AnchorUi& a = ancUi;
  for (auto& l : a.lines) l[0] = 0;
  for (auto& c : a.colors) c = C_FG;
  const UbxPvt& p = gnss.pvt();
  const bool ubx = gnss.ubxActive();
  const uint32_t rs = logger.secondsRecording();
  const char* why = "";
  const bool rdy = anc.ready(now, &why);
  if (a.page == 1) {
    snprintf(a.state, sizeof(a.state), "CALIDAD GNSS");
    a.stateColor = C_FG;
    snprintf(a.lines[0], 54, "enlace %s  cmd %s", gnss.linkTag(), gnss.pathTag());
    snprintf(a.lines[1], 54, "cfg %s  %u Hz  baud %lu", gnss.cfgStatus(), (unsigned)gnss.hz(),
             (unsigned long)gnss.baud());
    a.colors[1] = toneOk(gnss.configured());
    snprintf(a.lines[2], 54, "fw %s", gnss.fwVer()[0] ? gnss.fwVer() : "?");
    const UbxSat& s = gnss.sat();
    snprintf(a.lines[3], 54, "usados %u: G%u R%u E%u C%u J%u S%u", (unsigned)s.used,
             s.usedByGnss[0], s.usedByGnss[6], s.usedByGnss[2], s.usedByGnss[3],
             s.usedByGnss[5], s.usedByGnss[1]);
    snprintf(a.lines[4], 54, "C/N0 usados %.1f dBHz  rastreados %u", s.meanCnoUsed,
             (unsigned)s.numSvs);
    snprintf(a.lines[5], 54, "UBX ok %lu bad %lu relink %lu", (unsigned long)gnss.ubxOk(),
             (unsigned long)gnss.ubxBad(), (unsigned long)gnss.relinks());
    snprintf(a.lines[6], 54, "PPS %s n=%lu glitch %lu lag %ldms", pps.state(),
             (unsigned long)pps.count(), (unsigned long)pps.glitches(),
             (long)(gclock.lastLagUs() / 1000));
    a.colors[6] = toneOk(pps.good());
    snprintf(a.lines[7], 54, "IMU |a| %.2f tilt %.2f golpes %lu mov %lu", anc.amag(),
             anc.tiltDeg(), (unsigned long)anc.bumps(), (unsigned long)anc.moves());
    a.colors[7] = toneOk(anc.imuSane());
    snprintf(a.lines[8], 54, "baro %s err %lu T %.1fC", baro.ready() ? "ok" : "--",
             (unsigned long)baro.errors(), baro.lastTempC());
    snprintf(a.lines[9], 54, "pvt %lu err %lu baro %lu", (unsigned long)logger.pvtCount(),
             (unsigned long)logger.aerrCount(), (unsigned long)logger.baroCount());
    snprintf(a.lines[10], 54, "ses %.20s", logger.sessionId().c_str());
    return;
  }
  // ---- page 0: position ----
  if (!gnss.locked()) {
    snprintf(a.state, sizeof(a.state), "GNSS SIN ENLACE");
    a.stateColor = C_REC;
  } else if (now < movedAlertUntil) {
    snprintf(a.state, sizeof(a.state), "ANCLA MOVIDA!");
    a.stateColor = C_REC;
  } else if (anc.disturbed(now)) {
    snprintf(a.state, sizeof(a.state), "GOLPE - NO TOCAR");
    a.stateColor = C_WARN;
  } else if (!logger.recording()) {
    snprintf(a.state, sizeof(a.state), userStopped ? "DETENIDA (A=REC)" : "ESPERANDO FIX");
    a.stateColor = C_WARN;
  } else if (rdy) {
    snprintf(a.state, sizeof(a.state), "REC %02lu:%02lu LISTA", (unsigned long)(rs / 60),
             (unsigned long)(rs % 60));
    a.stateColor = C_OK;
  } else if (anc.stabLeftS(now) > 0) {
    const uint32_t l = anc.stabLeftS(now);
    snprintf(a.state, sizeof(a.state), "REC %02lu:%02lu ESTAB %lu:%02lu",
             (unsigned long)(rs / 60), (unsigned long)(rs % 60), (unsigned long)(l / 60),
             (unsigned long)(l % 60));
    a.stateColor = C_WARN;
  } else {
    snprintf(a.state, sizeof(a.state), "REC %02lu:%02lu %s", (unsigned long)(rs / 60),
             (unsigned long)(rs % 60), why);
    a.stateColor = C_WARN;
  }
  if (ubx) {
    snprintf(a.lines[0], 54, "fix %s sv %u pDOP %.1f hAcc %.2f vAcc %.2f", fixName(p.fixType),
             (unsigned)p.numSV, p.pDOP * 0.01, p.hAccM(), p.vAccM());
    a.colors[0] = toneOk(p.good3d() && p.hAccM() <= ANCHOR_READY_HACC_M);
  } else {
    const GnssFix f = gnss.snapshot();
    snprintf(a.lines[0], 54, "NMEA fix %d sv %d (sin UBX: cfg %s)", (int)f.valid, f.sats,
             gnss.cfgStatus());
    a.colors[0] = C_WARN;
  }
  const uint32_t el = anc.avgElapsedS(now);
  snprintf(a.lines[1], 54, "N %lu  prom %02lu:%02lu  %uHz cfg %s", (unsigned long)anc.n(),
           (unsigned long)(el / 60), (unsigned long)(el % 60), (unsigned)gnss.hz(),
           gnss.cfgStatus());
  if (anc.haveMean()) {
    double lat, lon, h;
    anc.meanLlh(lat, lon, h);
    const Enu sd = anc.stdev();
    snprintf(a.lines[2], 54, "media %.8f %.8f", lat, lon);
    snprintf(a.lines[3], 54, "h elip %.2f  msl %.2f  ant %.2f", h, h + anc.sep(), role.antH());
    snprintf(a.lines[4], 54, "std E %.2f N %.2f U %.2f m", sd.e, sd.n, sd.u);
  } else {
    snprintf(a.lines[2], 54, "media: (esperando muestras validas)");
  }
  const RefPoint& r = role.ref();
  if (r.set) {
    snprintf(a.lines[5], 54, "REF %.10s %s s=%.2f h=%s", r.id, r.source, r.sigma,
             r.hMsl ? "msl" : "elip");
    if (anc.haveMean() && anc.refValid()) {
      const Enu o = anc.offsetVsRef();
      snprintf(a.lines[6], 54, "media-REF E%+.2f N%+.2f U%+.2f", o.e, o.n, o.u);
    }
  } else {
    snprintf(a.lines[5], 54, "REF: ninguna (serial REF ... o REF FROM AVG)");
    a.colors[5] = C_WARN;
  }
  const Enu& d = anc.lastD();
  snprintf(a.lines[7], 54, "err %s E%+.2f N%+.2f U%+.2f", anc.lastRefOk() ? "REF" : "med", d.e,
           d.n, d.u);
  const float d60 = anc.drift60();
  snprintf(a.lines[8], 54, "med60-media %s  why:%s", d60 < 0 ? "--" : String(d60, 2).c_str(),
           rdy ? "ok" : why);
  snprintf(a.lines[9], 54, "baro %.2f hPa %.1fC  IMU %s", haveBaro ? lastBaro.pa / 100.0 : 0.0,
           haveBaro ? lastBaro.tempC : 0.0f,
           !anc.imuSane() ? "??" : (anc.disturbed(now) ? "GOLPE" : "quieto"));
  snprintf(a.lines[10], 54, "PPS %s  SD %s  WiFi off  %s", pps.state(),
           logger.sdOk() ? "ok" : "--", uiLine.c_str());
  a.colors[10] = toneOk(pps.good() && logger.sdOk());
}

static void paint(const GnssFix& fix) {
  ui.anchor = role.anchor();
  ui.anc = &ancUi;
  ui.colocOn = coloc;
  ui.recording = logger.recording();
  autoFillUi();
  ui.sdOk = logger.sdOk();
  ui.imuOk = imu.ready();
  ui.baroOk = baro.ready();
  ui.gnssLock = gnss.locked();
  ui.wifiCfg = uploader.configured();
  ui.wifiOn = WiFi.status() == WL_CONNECTED;
  ui.wifiRssi = ui.wifiOn ? WiFi.RSSI() : 0;
  const String liveSsid = ui.wifiOn ? WiFi.SSID() : uploader.ssid();
  strncpy(ui.wifiSsid, liveSsid.c_str(), sizeof(ui.wifiSsid) - 1);
  ui.wifiSsid[sizeof(ui.wifiSsid) - 1] = 0;
  ui.wifiIp[0] = 0;
  if (ui.wifiOn) {
    const String ip = WiFi.localIP().toString();
    strncpy(ui.wifiIp, ip.c_str(), sizeof(ui.wifiIp) - 1);
    ui.wifiIp[sizeof(ui.wifiIp) - 1] = 0;
  }
  ui.wifiLine = uploader.lastStatus().c_str();
  ui.fix = fix.valid;
  ui.sats = fix.sats;
  ui.gnssHz = fix.hz;
  ui.bat = M5.Power.getBatteryLevel();
  ui.speedKmh = fix.valid && fix.speedMps > 0 ? fix.speedMps * 3.6f : 0;
  ui.lat = fix.lat;
  ui.lng = fix.lng;
  ui.status = uiLine.c_str();
  ui.toast = (gToastUntil && (int32_t)(millis() - gToastUntil) < 0) ? gToast : "";  // 0.6.7
  ui.gnssTag = gnss.linkTag();
  ui.gnssFixType = fix.fixType;  // 0.6.2-circuit.7-rastro: home status bar
  ui.gnssAccM = fix.accM > 0 ? (float)fix.accM : -1.f;
  ui.sdFreeMb = sdFreeMb;
  ui.pending = rides.pendingCount();
  ui.upBusy = upTask.busy();
  ui.upErr = upLastErr;
  ui.upTaskOk = upTaskOk;
  ui.charging = M5.Power.isCharging() == m5::Power_Class::is_charging;
  if (ui.anchor) fillAnchorUi();
  fillRidesUi();
  drawUi(ui);
  if (ui.page == UiPage::Circuit && !circFollowing()) circuitPaint();  // 0.6.6: follow has its own tick
}

// ---- 0.6.2-circuit.6: dark-only UI. The old NVS "rl_ui"/"dark" key (0.6.2 .. .5) is erased once. ----
static void themeEraseLegacy() {
  Preferences p;
  bool has = false;
  if (p.begin("rl_ui", true)) {
    has = p.isKey("dark");
    p.end();
  }
  if (has && p.begin("rl_ui", false)) {
    p.remove("dark");
    p.end();
    Serial.println("THEME legacy NVS key erased (dark only)");
  }
}

// ---- 0.6.0-circuit: optional circuit page (Beta X H). Zero heap until opened. ----------------
// Data (Circuit + LapTimer + LiveDelta, ~6.7 KB heap; LiveDelta +2.1 KB since 0.6.2-circuit.7-rastro) is allocated on first open and kept so lap/sector timing
// continues off-page; the view (~14 KB) only while the page is shown. BOTH are freed before any
// Wi-Fi use (scan, join, upload start) so the uploader keeps its 40 KB TLS block. Source:
// /riderlab/circuit.rlc on SD (read-only) if present & valid, else the embedded 2026-10-09 circuit.
struct CircuitRt {
  Circuit c;
  LapTimer lt;
  LiveDelta ld;  // 0.6.2-circuit.7-rastro: live sector delta (best profile every 5 m)
  CircuitRt() : lt(c) {}
};
static CircuitRt* crt = nullptr;
static CircuitView cview;
static LiveFix cfix;
static bool circFollowing() { return cview.following(); }  // 0.6.6-follow
static char circSrc[24] = "none";
static uint32_t circGateHits = 0, circDrawnHits = 0xFFFFFFFFUL, circSkips = 0, circRenders = 0;
static bool circLowMem = false, circRenderLogged = false;
static uint32_t circWrongUntil = 0;
static constexpr const char* kCircuitPath = "/riderlab/circuit.rlc";

static void circuitLogMem(const char* what) {
  const Mem8 m = mem8();
  gDiag.logf("circuit", "%s src=%s data=%d view=%d page=%s heap=%u free8=%lu big8=%lu min8=%lu",
             what, circSrc, (int)(crt != nullptr), (int)cview.active(), pageName(), ESP.getFreeHeap(),
             (unsigned long)m.free, (unsigned long)m.big, (unsigned long)m.min);
}

// 0.6.7: nothing chosen/detected -> legacy SD file if present, else the embedded circuit (as 0.6.6)
static int circDefaultIdx() { return cidx.legacyIdx >= 0 ? cidx.legacyIdx : (cidx.n > 0 ? 0 : -1); }
static bool circuitLoad() {
  const int want = (gCircSel >= 0 && gCircSel < cidx.n) ? gCircSel : circDefaultIdx();
  if (crt && gCircLoaded == want) return true;
  if (crt) circuitRelease("switch-circuit");
  crt = new (std::nothrow) CircuitRt();
  if (!crt) return false;
  bool ok = false;
  const char* path = want >= 0 ? cidx.e[want].path : "";
  if (path[0] && logger.sdOk()) {  // read-only; never written/deleted here
    ok = CircuitIndex::readFile(path, crt->c);
    const char* bn = strrchr(path, '/');
    if (ok) snprintf(circSrc, sizeof circSrc, "sd:%s", bn ? bn + 1 : path);
    else gDiag.logf("circuit", "SD %s invalid -> embedded", path);
  }
  (void)kCircuitPath;
  if (!ok) {
    ok = crt->c.parse(kEmbeddedCircuit, kEmbeddedCircuitLen);
    if (ok) snprintf(circSrc, sizeof circSrc, "%s", kEmbeddedCircuitTag);
  }
  if (!ok) {
    delete crt;
    crt = nullptr;
    snprintf(circSrc, sizeof circSrc, "none");
    gDiag.logf("circuit", "LOAD FAIL (embedded parse)");
    gCircLoaded = -1;
    return false;
  }
  gCircLoaded = strncmp(circSrc, "sd:", 3) == 0 ? want : 0;
  crt->lt.reset();
  crt->ld.reset(crt->c);
  cfix = LiveFix();
  circGateHits = 0;
  circDrawnHits = 0xFFFFFFFFUL;
  gDiag.logf("circuit", "LOAD ok src=%s name=%s ccw=%d outer=%u inner=%u center=%u gates=%u sectors=%u "
             "len_m=%.1f anchor=%.7f,%.7f",
             circSrc, crt->c.name, (int)crt->c.ccw, (unsigned)crt->c.nO, (unsigned)crt->c.nI,
             (unsigned)crt->c.nC, (unsigned)crt->c.nG, (unsigned)crt->c.nSec, crt->c.lenM,
             crt->c.lat0, crt->c.lon0);
  return true;
}

// Free everything (view + data). Called before any Wi-Fi use.
static void circuitRelease(const char* why) {
  if (!crt && !cview.active() && !cview.bareActive()) return;  // 0.6.9: the trail band is freed too
  cview.end();
  delete crt;
  crt = nullptr;
  gCircLoaded = -1;
  if (ui.page == UiPage::Circuit) ui.page = UiPage::Home;
  char w[48];
  snprintf(w, sizeof w, "RELEASE why=%s", why);
  circuitLogMem(w);
}

static void circuitClose(const char* why) {  // leave the page, keep timing data
  cview.end();
  if (ui.page == UiPage::Circuit) ui.page = UiPage::Home;
  char w[48];
  snprintf(w, sizeof w, "CLOSE why=%s", why);
  circuitLogMem(w);
}

static bool circuitOpen(const char* why) {
  if (role.anchor()) {
    uiLine = "ancla: sin circuito";
    return false;
  }
  if (ui.page == UiPage::Trail || cview.bareActive()) trailClose("circuit-open");  // 0.6.9: one view at a time
  if (upTask.busy() || wifiScanning) {
    uiLine = "CIRCUITO: WiFi ocupado";
    gDiag.logf("circuit", "OPEN refused why=%s reason=wifi-busy", why);
    return false;
  }
  if (WiFi.getMode() != WIFI_OFF) radioOff();  // idle radio: the user chose the map
  circuitLogMem("OPEN pre");
  const Mem8 m0 = mem8();
  if (m0.free < CircuitView::kMinFree8 || m0.big < CircuitView::kMinBig8 || !circuitLoad()) {
    uiLine = "CIRCUITO: poca RAM";
    gDiag.logf("circuit", "OPEN refused why=%s reason=%s", why, crt ? "heap" : "load/heap");
    return false;
  }
  if (!cview.begin(&crt->c)) {
    uiLine = "CIRCUITO: poca RAM";
    gDiag.logf("circuit", "OPEN refused why=%s reason=view-heap", why);
    return false;
  }
  ui.page = UiPage::Circuit;
  cview.setMode(CircuitMode::Map);
  if (gLastFollow && !cview.setFollow(true)) uiLine = "SEGUIR: poca RAM";  // 0.6.7: last view (NVS)
  const uint32_t t0 = millis();
  cview.drawStatic(logger.recording());
  const uint32_t ms = millis() - t0;
  circDrawnHits = 0xFFFFFFFFUL;
  circRenderLogged = false;
  circLowMem = false;
  char w[64];
  snprintf(w, sizeof w, "OPEN ok why=%s mode=%s static_ms=%lu", why, cview.modeName(), (unsigned long)ms);
  circuitLogMem(w);
  return true;
}

static void circuitOnPvt() {  // every PVT (10 Hz), only while circuit data is loaded
  if (!crt || role.anchor()) return;
  const GnssFix f = gnss.snapshot();
  if (!f.valid || (f.accM > 0 && f.accM > 8.0)) {
    cfix.valid = false;
    return;
  }
  float x, y;
  crt->c.enu(f.lat, f.lng, x, y);
  const double t = f.utcMs / 1000.0;
  const float v = f.speedMps > 0 ? (float)f.speedMps : 0.f;
  const int hit = crt->lt.onFix(x, y, t, v);
  crt->ld.onFix(crt->c, crt->lt, x, y, t);  // 0.6.2-circuit.7-rastro
  if (crt->lt.wrongWay()) {
    crt->lt.clearWrongWay();
    circWrongUntil = millis() + 3000;
  }
  if (hit >= 0) {
    ++circGateHits;
    gDiag.logf("circuit", "GATE g=%d lap=%d sector=%d t=%.2f last_lap=%.2f", hit, crt->lt.lap(),
               crt->lt.sector() + 1, t, crt->lt.lastLap());
  }
  cfix.x = x;
  cfix.y = y;
  cfix.kmh = v * 3.6f;
  cfix.head = (float)f.heading;  // 0.6.6-follow: heading of motion (track-up view)
  cfix.tS = t;
  cfix.valid = true;
}

static void circuitPaint() {
  if (!cview.active() || !crt) return;
  const Mem8 m = mem8();
  // 0.6.6-follow: the follow band is pre-allocated and a frame allocates nothing -> lower floor
  const uint32_t needFree = cview.following() ? 16000 : CircuitView::kMinBig8;
  const uint32_t needBig = cview.following() ? 8000 : CircuitView::kMinBig8;
  if (m.free < needFree || m.big < needBig) {  // low heap: skip drawing
    ++circSkips;
    if (!circLowMem) circuitLogMem("SKIP low-heap");
    circLowMem = true;
    return;
  }
  circLowMem = false;
  const bool changed = circGateHits != circDrawnHits;
  circDrawnHits = circGateHits;
  const uint32_t t0 = millis();
  cview.update(cfix, crt->lt, crt->ld, logger.recording(), changed);
  ++circRenders;
  if (!circRenderLogged) {
    circRenderLogged = true;
    char w[64];
    snprintf(w, sizeof w, "RENDER ok mode=%s tick_ms=%lu fix=%d", cview.modeName(),
             (unsigned long)(millis() - t0), (int)cfix.valid);
    circuitLogMem(w);
  }
}

static void circuitStatus() {
  const Mem8 m = mem8();
  Serial.printf("CIRCUIT src=%s data=%d view=%d page=%s mode=%s lap=%d sector=%d gates_hit=%lu renders=%lu "
                "skips=%lu fix=%d x=%.1f y=%.1f heap=%u free8=%lu big8=%lu min8=%lu\n",
                circSrc, (int)(crt != nullptr), (int)cview.active(), pageName(),
                cview.modeName(), crt ? crt->lt.lap() : -1,
                crt ? crt->lt.sector() + 1 : 0, (unsigned long)circGateHits, (unsigned long)circRenders,
                (unsigned long)circSkips, (int)cfix.valid, cfix.x, cfix.y, ESP.getFreeHeap(),
                (unsigned long)m.free, (unsigned long)m.big, (unsigned long)m.min);
  if (crt) {
    for (int k = 0; k < crt->c.nSec && k < SectorTimes::kMax; ++k)
      Serial.printf("CIRCUIT S%d cur=%.2f last=%.2f best=%.2f\n", k + 1, crt->lt.current().t[k],
                    crt->lt.last().t[k], crt->lt.best(k));
    Serial.printf("CIRCUIT RASTRO sector=%d ref=%d delta=%+.2f colour=%s crossings=%lu ld_bytes=%u\n",
                  crt->ld.sector() + 1, (int)crt->ld.hasRef(), crt->ld.delta(),
                  crt->ld.behind() ? "yellow" : "purple", (unsigned long)crt->ld.crossings(),
                  (unsigned)LiveDelta::bytes());
  }
}
// 0.6.4: session opened/closed (auto or manual): partial lap, live delta pass and trace restart;
// sector bests + best profiles are kept for the day. No-op while the circuit data is not loaded.
static void circuitSessionEdge(const char* why) {
  if (!crt) return;
  crt->lt.resetLap();
  crt->ld.resetLap();
  cview.clearTrace(logger.recording());
  circGateHits++;  // sector table refresh
  gDiag.logf("circuit", "SESSION edge why=%s lap/trace reset (bests kept)", why);
}
// ---- end 0.6.0-circuit --------------------------------------------------------------------------

// ---- 0.6.7-autocircuit: circuit index, detection, auto open, manual choice -----------------------
static void circToast(const char* t) {
  snprintf(gToast, sizeof gToast, "%s", t);
  gToastUntil = millis() + 3000;
  if (!gToastUntil) gToastUntil = 1;
}
static void circIndexBuild(const char* why) {
  const uint32_t t0 = millis();
  if (crt && !logger.recording()) circuitRelease("index");
  cidx.build(logger.sdOk(), kEmbeddedCircuit, kEmbeddedCircuitLen, kEmbeddedName);
  gCircSel = gCircDet = -1;
  gCircManual = false;
  gDiag.logf("circuit", "INDEX why=%s n=%d legacy=%d scan[%s] ms=%lu heap=%u", why, cidx.n, cidx.legacyIdx, cidx.dbg,
             (unsigned long)(millis() - t0), ESP.getFreeHeap());
  if (logger.sdOk()) cidx.scanBegin();  // 0.6.7: directory verified incrementally from loop()
  for (int i = 0; i < cidx.n; ++i)
    gDiag.logf("circuit", "INDEX #%d name=%s src=%s len_m=%.1f anchor=%.6f,%.6f bbox_m=%.0f..%.0f,%.0f..%.0f", i,
               cidx.e[i].name, cidx.e[i].path[0] ? cidx.e[i].path : "embedded", cidx.e[i].lenM, cidx.e[i].lat0,
               cidx.e[i].lon0, cidx.e[i].x0, cidx.e[i].x1, cidx.e[i].y0, cidx.e[i].y1);
}
// <= 1 Hz on PVT. Good fix = valid, 3D, hAcc <= 5 m. Hysteresis: once detected, the choice holds until the
// fix is > 2 km from that circuit (or reboot); GPS jumps never re-select or repeat the banner.
static void circDetect(uint32_t nowMs) {
  static uint32_t lastMs = 0;
  if (role.anchor() || cidx.n == 0 || nowMs - lastMs < 1000) return;
  const GnssFix f = gnss.snapshot();
  if (!f.valid || f.fixType < 3 || f.accM <= 0 || f.accM > kDetectHaccM) return;
  lastMs = nowMs;
  cidx.updateDist(f.lat, f.lng);
  if (gCircManual) return;
  if (gCircDet >= 0) {
    if (cidx.e[gCircDet].distM > kLoseM) {
      gDiag.logf("circuit", "DETECT lost #%d name=%s dist_m=%.0f (> %.0f) rec=%d", gCircDet, cidx.e[gCircDet].name,
                 cidx.e[gCircDet].distM, kLoseM, (int)logger.recording());
      gCircDet = -1;
      if (!logger.recording()) gCircSel = -1;  // a running session keeps its circuit
    }
    return;
  }
  const int i = cidx.nearest(kDetectM);
  if (i < 0) return;
  gCircDet = gCircSel = i;
  char t[40];
  snprintf(t, sizeof t, "%s detectado", cidx.e[i].name);
  circToast(t);
  gDiag.logf("circuit", "DETECT ok #%d name=%s dist_m=%.0f hacc=%.1f page=%s rec=%d", i, cidx.e[i].name,
             cidx.e[i].distM, f.accM, pageName(), (int)logger.recording());
}
// 0.6.7: one /riderlab/circuits entry per loop iteration (only changed files are parsed)
static void circScanService() {
  if (!cidx.scanning() || logger.recording()) return;
  bool changed = false;
  if (!cidx.scanStep(changed)) return;
  gDiag.logf("circuit", "SCAN done scan[%s] changed=%d n=%d", cidx.dbg, (int)changed, cidx.n);
  if (changed) {
    if (crt && gCircLoaded >= cidx.nFixed) circuitRelease("index-changed");
    if (gCircSel >= cidx.nFixed) gCircSel = -1;
    if (gCircDet >= cidx.nFixed) gCircDet = -1;
    if (gCircManual && gCircSel < 0) gCircManual = false;
    for (int i = cidx.nFixed; i < cidx.n; ++i)
      gDiag.logf("circuit", "INDEX #%d name=%s src=%s len_m=%.1f anchor=%.6f,%.6f bbox_m=%.0f..%.0f,%.0f..%.0f", i,
                 cidx.e[i].name, cidx.e[i].path, cidx.e[i].lenM, cidx.e[i].lat0, cidx.e[i].lon0, cidx.e[i].x0,
                 cidx.e[i].x1, cidx.e[i].y0, cidx.e[i].y1);
  }
}
static void circSelectManual(int i, const char* why) {
  gCircManual = true;
  gCircSel = i;
  gDiag.logf("circuit", "SELECT manual #%d name=%s why=%s", i, cidx.e[i].name, why);
}
static void circSelectAuto(const char* why) {
  gCircManual = false;
  gCircSel = gCircDet = -1;  // re-detect on the next good fix
  gDiag.logf("circuit", "SELECT auto why=%s", why);
}
static void circuitsPrint() {
  const GnssFix f = gnss.snapshot();
  Serial.printf("CIRCUITS n=%d sel=%d det=%d manual=%d loaded=%d autoopen=%d last_view=%s fix=%d fix_type=%u hacc=%.1f\n",
                cidx.n, gCircSel, gCircDet, (int)gCircManual, gCircLoaded, (int)gAutoOpen,
                gLastFollow ? "follow" : "map", (int)f.valid, (unsigned)f.fixType, f.accM);
  int ord[CircuitIndex::kMax];
  const int m = cidx.sorted(ord, CircuitIndex::kMax);
  for (int k = 0; k < m; ++k) {
    const CircEntry& e = cidx.e[ord[k]];
    char ds[16];
    if (e.distM < 0) snprintf(ds, sizeof ds, "?");
    else snprintf(ds, sizeof ds, "%.0f", e.distM);
    Serial.printf("CIRCUITS %d. #%d name=%s src=%s dist_m=%s len_m=%.1f anchor=%.6f,%.6f%s%s\n", k + 1, ord[k], e.name,
                  e.path[0] ? e.path : "embedded", ds, e.lenM, e.lat0, e.lon0, ord[k] == gCircSel ? " SELECTED" : "",
                  ord[k] == gCircDet ? " DETECTED" : "");
  }
}
static void circListFill() {
  int ord[CircuitIndex::kMax];
  const int m = cidx.sorted(ord, CircuitIndex::kMax);
  const int k = m > 4 ? 4 : m;
  ui.circSel = 0;
  for (int r = 0; r < k; ++r) {
    const CircEntry& e = cidx.e[ord[r]];
    gListIdx[r] = ord[r];
    snprintf(ui.circName[r], sizeof ui.circName[r], "%s", e.name);
    char ds[12];
    if (e.distM < 0) snprintf(ds, sizeof ds, "--");
    else if (e.distM < 1000) snprintf(ds, sizeof ds, "%.0f m", e.distM);
    else snprintf(ds, sizeof ds, "%.1f km", e.distM / 1000.f);
    const char* tag = ord[r] == gCircSel ? (gCircManual ? " elegido" : " detectado") : "";
    snprintf(ui.circInfo[r], sizeof ui.circInfo[r], "%s%s", ds, tag);
    if (ord[r] == gCircSel) ui.circSel = r;
  }
  gListIdx[k] = -1;
  snprintf(ui.circName[k], sizeof ui.circName[k], "AUTOMATICO");
  snprintf(ui.circInfo[k], sizeof ui.circInfo[k], "%s", gCircManual ? "" : "activo");
  ui.circN = k + 1;
}
static void circMenuOpen() {  // Menu > CIRCUITO
  if (cidx.n <= 1) {  // one circuit: open directly (as 0.6.6)
    if (!circuitOpen("menu")) ui.page = UiPage::Home;
    return;
  }
  circListFill();
  ui.page = UiPage::CircuitList;
}
static void circAutoOpenService(uint32_t nowMs) {
  if (!gCircAutoOpenPending || (int32_t)(nowMs - gCircAutoOpenAt) < 0) return;
  gCircAutoOpenPending = false;
  if (!logger.recording() || ui.page == UiPage::Circuit || gCircSel < 0 || gCircSel >= cidx.n) return;
  const UiPage prev = ui.page;
  const uint32_t t0 = millis();
  const bool ok = circuitOpen("auto-session");
  if (!ok) ui.page = prev;
  const Mem8 m = mem8();
  gDiag.logf("circuit", "AUTOOPEN %s name=%s mode=%s ms=%lu reason=%s free8=%lu big8=%lu min8=%lu", ok ? "ok" : "FAIL",
             cidx.e[gCircSel].name, ok ? cview.modeName() : "-", (unsigned long)(millis() - t0),
             ok ? "-" : uiLine.c_str(), (unsigned long)m.free, (unsigned long)m.big, (unsigned long)m.min);
  paint(gnss.snapshot());
}
// ---- end 0.6.7-autocircuit -------------------------------------------------------------------------

// ---- 0.6.9-trail: session with NO circuit -> rider trail (CircuitView bare follow) + speed top-right ----
// Local frame: first good fix of the session (re-anchored at 2.5 km so the int16 dm trail never overflows).
// Heap: only the follow band + trail ring (CircuitView::followAlloc, same limits as FOLLOW); nothing static
// beyond a few scalars. Freed when the page closes (session stop, B, circuit open, any cview.end()).
static LiveFix tfix;
static bool gTrAnch = false;
static double gTrLat0 = 0, gTrLon0 = 0, gTrKx = 1, gTrKy = 1;
static uint32_t trSkips = 0;
static void trailResetAnchor() {
  gTrAnch = false;
  tfix = LiveFix();
}
static void trailOnPvt() {  // every PVT while recording (cheap: a few float ops)
  if (!logger.recording() || role.anchor()) return;
  const GnssFix f = gnss.snapshot();
  if (!f.valid || (f.accM > 0 && f.accM > 8.0)) {  // same quality gate as circuitOnPvt
    tfix.valid = false;
    return;
  }
  if (!gTrAnch) {
    gTrLat0 = f.lat;
    gTrLon0 = f.lng;
    CircuitIndex::kxy(f.lat, gTrKx, gTrKy);
    gTrAnch = true;
  }
  float x = (float)((f.lng - gTrLon0) * gTrKx), y = (float)((f.lat - gTrLat0) * gTrKy);
  if (fabsf(x) > 2500.f || fabsf(y) > 2500.f) {
    cview.bareShift(x, y);  // trail kept continuous in the new frame
    gTrLat0 = f.lat;
    gTrLon0 = f.lng;
    CircuitIndex::kxy(f.lat, gTrKx, gTrKy);
    x = y = 0;
  }
  const float v = f.speedMps > 0 ? (float)f.speedMps : 0.f;
  tfix.x = x;
  tfix.y = y;
  tfix.kmh = v * 3.6f;
  tfix.head = (float)f.heading;
  tfix.tS = f.utcMs / 1000.0;
  tfix.valid = true;
}
// 0.6.9b: y 0..41 = the home status bar (same drawing, icons refreshed on change); y 42..77 = speed row
// (km/h, same rounding as home, right aligned, overwritten in place = no flicker); map from kTrailTop.
static constexpr int kTrailTop = 78;
static void trailHeader(bool force) {
  const GnssFix f = gnss.snapshot();
  char spd[8];
  if (f.valid) snprintf(spd, sizeof spd, "%.0f", f.speedMps > 0 ? f.speedMps * 3.6 : 0.0);
  else snprintf(spd, sizeof spd, "--");
  static char last[8] = "";
  auto& d = M5.Display;
  if (force) {
    drawHomeBar(ui);  // badge + icons + RIDER chip, exactly as the home screen
    d.fillRect(0, 42, 320, kTrailTop - 42, C_BG);
    last[0] = 0;
  }
  d.startWrite();
  if (!force) drawHomeStatus(ui, false);  // only the icons whose state changed (ui filled by paint())
  if (force || strcmp(spd, last) != 0) {
    strcpy(last, spd);
    d.setTextDatum(lgfx::textdatum_t::middle_right);
    d.setTextSize(1);
    d.setFont(&fonts::FreeSansBold18pt7b);
    d.setTextColor(f.valid ? C_FG : C_LV_GRY, C_BG);
    d.setTextPadding(104);  // overwrite the previous value (no clear -> no flicker)
    d.drawString(spd, 270, 60);
    d.setTextPadding(0);
    if (force) {
      d.setFont(&fonts::Font2);
      d.setTextDatum(lgfx::textdatum_t::middle_left);
      d.setTextColor(C_MUTED, C_BG);
      d.drawString("km/h", 276, 64);
    }
  }
  d.setFont(&fonts::Font0);
  d.endWrite();
}
static void trailDrawStatic() {
  trailHeader(true);
  drawButtonBar(M5.Display, logger.recording() ? "STOP" : "REC", "VELOC.", logger.recording() ? "MARK" : " ");
  cview.bareUpdate(tfix);
}
static bool trailOpen(const char* why) {
  if (ui.page == UiPage::Trail && cview.bareActive()) return true;
  if (role.anchor() || !logger.recording()) return false;
  if (ui.page == UiPage::Circuit || cview.active()) return false;  // the circuit view has priority
  if (upTask.busy() || wifiScanning) {
    uiLine = "RASTRO: WiFi ocupado";
    return false;
  }
  if (!cview.beginBare(kTrailTop)) {
    uiLine = "RASTRO: poca RAM";  // home speedometer stays
    const Mem8 m = mem8();
    gDiag.logf("trail", "OPEN refused why=%s reason=heap free8=%lu big8=%lu", why, (unsigned long)m.free,
               (unsigned long)m.big);
    return false;
  }
  ui.page = UiPage::Trail;
  const uint32_t t0 = millis();
  trailDrawStatic();
  const Mem8 m = mem8();
  gDiag.logf("trail", "OPEN ok why=%s band=%d zoom=%.0f static_ms=%lu anchor=%d free8=%lu big8=%lu min8=%lu", why,
             cview.followBand(), cview.followZoom(), (unsigned long)(millis() - t0), (int)gTrAnch,
             (unsigned long)m.free, (unsigned long)m.big, (unsigned long)m.min);
  return true;
}
static void trailClose(const char* why) {
  if (!cview.bareActive() && ui.page != UiPage::Trail) return;
  cview.endBare();
  if (ui.page == UiPage::Trail) ui.page = UiPage::Home;
  const Mem8 m = mem8();
  gDiag.logf("trail", "CLOSE why=%s free8=%lu big8=%lu", why, (unsigned long)m.free, (unsigned long)m.big);
}
static void trailService(uint32_t nowMs) {
  if (gTrailPending && (int32_t)(nowMs - gTrailAt) >= 0) {
    gTrailPending = false;
    if (logger.recording() && ui.page == UiPage::Home && gCircSel < 0) trailOpen("auto-session");
  }
  if (ui.page != UiPage::Trail) return;
  if (!logger.recording() || !cview.bareActive()) {  // session over, or band freed (circuit/Wi-Fi release)
    trailClose(logger.recording() ? "band-lost" : "stop");
    paint(gnss.snapshot());
    return;
  }
  // same cadence as FOLLOW: every new fix (10 Hz) or at least every 300 ms
  static double trT = -1;
  static uint32_t trMs = 0, trLogMs = 0;
  if ((tfix.valid && tfix.tS != trT) || nowMs - trMs >= 300) {
    trT = tfix.tS;
    trMs = nowMs;
    const Mem8 m = mem8();
    if (m.free < 16000 || m.big < 8000) ++trSkips;  // same low-heap floor as the follow paint
    else cview.bareUpdate(tfix);
    trailHeader(false);
  }
  if (nowMs - trLogMs >= 10000) {
    trLogMs = nowMs;
    const Mem8 m = mem8();
    gDiag.logf("trail", "fps=%.1f render_ms=%.1f max_ms=%.1f band=%d zoom=%.0f head=%.0f live=%d fix=%d skips=%lu "
               "free8=%lu big8=%lu min8=%lu", cview.followFps(), cview.followMsAvg(), cview.followMsMax(),
               cview.followBand(), cview.followZoom(), cview.followHead(), (int)cview.followHeadLive(),
               (int)tfix.valid, (unsigned long)trSkips, (unsigned long)m.free, (unsigned long)m.big,
               (unsigned long)m.min);
  }
}
// ---- end 0.6.9-trail ----

// ---------------- 0.6.8-ble: Bluetooth pairing mode ----------------
static void bleHeap(const char* tag) {
  gDiag.logf("ble", "%s heap=%lu free8=%lu big8=%lu min8=%lu", tag, (unsigned long)ESP.getFreeHeap(),
             (unsigned long)heap_caps_get_free_size(MALLOC_CAP_8BIT),
             (unsigned long)heap_caps_get_largest_free_block(MALLOC_CAP_8BIT),
             (unsigned long)heap_caps_get_minimum_free_size(MALLOC_CAP_8BIT));
}
static String bleName() {
  uint8_t mac[6] = {};
  esp_read_mac(mac, ESP_MAC_WIFI_STA);
  char b[20];
  snprintf(b, sizeof b, "Metrica-%02X%02X", mac[4], mac[5]);
  return String(b);
}
static String bleJsonEsc(const String& v) {
  String o;
  for (size_t i = 0; i < v.length(); ++i) {
    const char c = v[i];
    if (c == '"' || c == '\\') { o += '\\'; o += c; }
    else if ((uint8_t)c >= 0x20) o += c;
  }
  return o;
}
static String bleInfoJson() {
  uint8_t mac[6] = {};
  esp_read_mac(mac, ESP_MAC_WIFI_STA);
  char hw[16];
  snprintf(hw, sizeof hw, "%02x%02x%02x%02x%02x%02x", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  String s = String("{\"hw\":\"") + hw + "\",\"fw\":\"" + FIRMWARE_VERSION + "\",\"role\":\"" +
             role.roleName() + "\",\"paired\":" + (uploader.paired() ? "true" : "false") +
             ",\"device_id\":\"" + bleJsonEsc(uploader.paired() ? uploader.deviceIdMasked() : String("")) + "\",\"wifi\":" +
             (uploader.wifiReady() ? "true" : "false") + ",\"authed\":" + (gBleAuthed ? "true" : "false") +
             ",\"mtu\":" + String((int)ble.mtu()) + "}";
  return s;
}
// minimal JSON string field reader: "key" : "value" (handles \" \\ \/ escapes). false = missing.
static bool jsonStr(const char* js, const char* key, String& out) {
  char pat[32];
  snprintf(pat, sizeof pat, "\"%s\"", key);
  const char* p = strstr(js, pat);
  if (!p) return false;
  p += strlen(pat);
  while (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n') ++p;
  if (*p != ':') return false;
  ++p;
  while (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n') ++p;
  if (*p != '"') return false;
  ++p;
  out = "";
  while (*p && *p != '"') {
    if (*p == '\\') {
      ++p;
      if (!*p) return false;
      if (*p != '"' && *p != '\\' && *p != '/') return false;
    }
    out += *p++;
    if (out.length() > 300) return false;
  }
  return *p == '"';
}
static bool bleTokenOk(const String& v, size_t lo, size_t hi) {
  if (v.length() < lo || v.length() > hi) return false;
  for (size_t i = 0; i < v.length(); ++i) {
    const char c = v[i];
    if (!(isalnum((unsigned char)c) || c == '-' || c == '_' || c == '.')) return false;
  }
  return true;
}
static void bleStatus(bool ok, const char* what, const String& extra = "") {
  String j = String("{\"ok\":") + (ok ? "true" : "false") + (ok ? ",\"msg\":\"" : ",\"err\":\"") + what + "\"" +
             extra + "}";
  ble.notify(j);
  gBleLine = String(ok ? "" : "ERR ") + what;
  gDiag.logf("ble", "STATUS %s", j.c_str());  // never carries a secret
}
static const char* bleRefuse() {
  if (logger.recording()) return "grabando";
  if (WiFi.getMode() != WIFI_OFF || wifiScanning || upTask.busy()) return "WiFi activo";
  return nullptr;
}
static bool bleEnter(const char* why) {
  if (ble.on()) return true;
  if (const char* r = bleRefuse()) {
    uiLine = String("BLE no: ") + r;
    gDiag.logf("ble", "ENTER refused why=%s (%s)", why, r);
    return false;
  }
  if (gBtMemFree) {  // controller memory was released at boot -> reboot into pairing mode
    Preferences p;
    if (p.begin("rl_ble", false)) {
      p.putUChar("boot", strcmp(why, "serial") == 0 ? 2 : 1);
      p.end();
    }
    gDiag.logf("ble", "ENTER why=%s -> restart into pairing mode", why);
    Serial.println("BLE restart-to-pair");
    auto& d = M5.Display;
    d.fillScreen(C_BG);
    d.setTextDatum(lgfx::textdatum_t::middle_center);
    d.setFont(&fonts::Font4);
    d.setTextColor(C_FG, C_BG);
    d.drawString("EMPAREJAR...", 160, 120);
    d.setFont(&fonts::Font0);
    Serial.flush();
    delay(300);
    ESP.restart();
    return false;
  }
  circuitRelease("ble");  // keep the heap for the BLE stack
  bleHeap("pre");
  const String nm = bleName();
  snprintf(gBlePin, sizeof gBlePin, "%06lu", (unsigned long)(esp_random() % 1000000UL));
  gBleBad = 0;
  gBleAuthed = false;
  gBleExitAt = 0;
  gBleExitWhy = "done";
  if (!ble.begin(nm.c_str())) {
    uiLine = "BLE fallo init";
    bleHeap("init-fail");
    return false;
  }
  gBleT0 = millis();
  ble.setInfo(bleInfoJson());
  gBleLine = "Abre la app RiderLab";
  snprintf(ui.bleName, sizeof ui.bleName, "%s", nm.c_str());
  ui.page = UiPage::BlePair;
  gDiag.logf("ble", "ON name=%s why=%s", nm.c_str(), why);
  bleHeap("on");
  return true;
}
static void bleExit(const char* why) {
  if (!ble.on()) return;
  bleHeap("before-off");
  ble.end();
  const esp_err_t rel = esp_bt_controller_mem_release(ESP_BT_MODE_BTDM);  // controller RAM back to heap
  gBtMemFree = true;
  gBleAuthed = false;
  gBlePin[0] = 0;
  gDiag.logf("ble", "OFF why=%s mem_release=%d", why, (int)rel);
  bleHeap("off");
  uiLine = String("BLE fin: ") + why;
  // The NimBLE allocations split the big DRAM block (largest ~35 KB after deinit, TLS upload needs 40 KB),
  // so when nothing is recording the mode ends with a clean restart (heap as a normal boot).
  if (!logger.recording() && strcmp(why, "rec-start") != 0) {
    Serial.printf("BLE off why=%s -> restart (clean heap)\n", why);
    auto& d = M5.Display;
    d.fillScreen(C_BG);
    d.setTextDatum(lgfx::textdatum_t::middle_center);
    d.setFont(&fonts::Font4);
    d.setTextColor(strcmp(why, "paired") == 0 ? C_OK : C_FG, C_BG);
    d.drawString(strcmp(why, "paired") == 0 ? "EMPAREJADO" : "BLE FIN", 160, 110);
    d.setFont(&fonts::Font2);
    d.setTextColor(C_MUTED, C_BG);
    d.drawString(why, 160, 140);
    d.setFont(&fonts::Font0);
    Serial.flush();
    delay(1200);
    ESP.restart();
  }
  if (ui.page == UiPage::BlePair) ui.page = UiPage::Home;
}
static void bleService(uint32_t now) {
  if (!ble.on()) return;
  if (now - gBleT0 > riderlab::BlePair::kTimeoutMs) { bleExit("timeout"); return; }
  if (gBleExitAt && (int32_t)(now - gBleExitAt) >= 0) { bleExit(gBleExitWhy); return; }
  if (const char* r = bleRefuse()) { bleExit(r); return; }
  if (ble.takeDisconnect()) {
    if (gBleAuthed) gDiag.logf("ble", "disconnect (auth reset)");
    gBleAuthed = false;
    ble.setInfo(bleInfoJson());
  }
  riderlab::BlePair::Msg m;
  if (ble.take(m)) {
    const String v(m.data);
    if (m.kind == riderlab::BlePair::K_AUTH) {
      String pin = v;
      pin.trim();
      if (gBleAuthed) bleStatus(true, "auth_ok");
      else if (pin == gBlePin) {
        gBleAuthed = true;
        bleStatus(true, "auth_ok");
      } else {
        ++gBleBad;
        const int left = riderlab::BlePair::kMaxBadPin - gBleBad;
        bleStatus(false, "bad_pin", String(",\"left\":") + left);
        if (left <= 0) { gBleExitAt = now + 600; gBleExitWhy = "bad-pin"; }
      }
      ble.setInfo(bleInfoJson());
    } else if (!gBleAuthed) {
      bleStatus(false, "auth_required");
    } else if (m.kind == riderlab::BlePair::K_PAIR) {
      String id, sec, url;
      if (v.indexOf('{') < 0 || v.indexOf('}') < 0) bleStatus(false, "bad_json");
      else if (!jsonStr(m.data, "device_id", id) ||
               (!jsonStr(m.data, "secret", sec) && !jsonStr(m.data, "device_secret", sec)) ||
               !jsonStr(m.data, "ingest_url", url))
        bleStatus(false, "missing_fields");
      else if (!bleTokenOk(id, 3, 64) || !bleTokenOk(sec, 16, 128) || !url.startsWith("https://") ||
               url.length() > 200)
        bleStatus(false, "bad_fields");
      else {
        uploader.saveCredentials(id, sec, url);  // same store as serial PAIR
        uiLine = "Paired";
        gDiag.logf("ble", "PAIR saved device_id=%s url_len=%d", uploader.deviceIdMasked().c_str(), (int)url.length());
        ble.setInfo(bleInfoJson());
        bleStatus(true, "paired");
        gBleExitWhy = "paired";
        gBleExitAt = now + 3000;  // let the app read STATUS / INFO, then finish
      }
    } else if (m.kind == riderlab::BlePair::K_WIFI) {
      String ssid, pass;
      if (v.indexOf('{') < 0) bleStatus(false, "bad_json");
      else if (!jsonStr(m.data, "ssid", ssid) || !jsonStr(m.data, "pass", pass)) bleStatus(false, "missing_fields");
      else if (!ssid.length() || ssid.length() > 32 || pass.length() > 64) bleStatus(false, "bad_fields");
      else {
        if (!gWifiSnap.ok) gWifiSnap = uploader.snapshotWifi();
        uploader.setActiveKeepOld(ssid, pass);  // same as serial WIFISET
        gDiag.logf("ble", "WIFI saved ssid=%s pass=%s", ssid.c_str(), WifiUploader::mask(pass).c_str());
        ble.setInfo(bleInfoJson());
        bleStatus(true, "wifi_saved");
      }
    }
  }
  const uint32_t left = (riderlab::BlePair::kTimeoutMs - (now - gBleT0)) / 1000;
  ui.bleLeftS = (int)left;
  ui.bleConn = ble.connected();
  ui.bleAuthed = gBleAuthed;
  snprintf(ui.blePin, sizeof ui.blePin, "%s", gBlePin);
  snprintf(ui.bleLine, sizeof ui.bleLine, "%s", gBleLine.c_str());
}

static void tryWifiNow() {
  if (logger.recording()) {
    uiLine = "Stop first";
    return;
  }
  if (role.anchor()) {
    uiLine = "ancla: WiFi off";
    return;
  }
  if (upTask.busy()) {  // 0.5.3: the uploader task owns the radio right now
    uiLine = "subiendo…";
    return;
  }
  circuitRelease("wifi-join");  // 0.6.0
  uiLine = "conectando…";
  paint(gnss.snapshot());
  gDiag.logf("wifi", "JOIN begin (menu) ssid=%s", uploader.ssid().c_str());
  const uint32_t tj = millis();
  const bool joined = uploader.connect();
  gDiag.logf("wifi", "JOIN end ok=%d ms=%lu status=%s rssi=%d", (int)joined,
             (unsigned long)(millis() - tj), uploader.lastStatus().c_str(),
             joined ? (int)WiFi.RSSI() : 0);
  if (joined) {
    uiLine = WiFi.localIP().toString();
    paint(gnss.snapshot());
    if (rides.hasLocalPending()) {  // 0.5.3: hand over to the uploader task
      wantUpload = true;
      uploadAfterMs = millis();
    }
  } else {
    uiLine = uploader.lastStatus();
  }
}

// Bench diagnostic: a driven UART line idles HIGH, so a pulldown that still
// reads HIGH means something is transmitting on that pin. Edges mean traffic.
// PPS normally on G34; if the DIP routes NEO_TXD to G34, PPS must be on G35.
static int ppsPin() { return gnss.rxPin() == GNSS_PPS_PIN ? 35 : GNSS_PPS_PIN; }

static void scanGnssPins(bool waitButton = true) {
  static constexpr int pins[] = {0, 2, 5, 12, 13, 15, 16, 17, 19, 26, 34, 35, 36};
  auto& d = M5.Display;
  d.fillScreen(TFT_BLACK);
  d.setCursor(0, 0);
  d.setTextSize(1);
  d.println("PIN SCAN");
  Serial.println("--- PIN SCAN ---");
  for (int p : pins) {
    const bool inputOnly = (p == 34 || p == 35);
    gpio_reset_pin(static_cast<gpio_num_t>(p));
    pinMode(p, inputOnly ? INPUT : INPUT_PULLDOWN);
    delay(3);
    const bool driven = digitalRead(p) == HIGH;
    const uint32_t window = driven ? 1200 : 200;
    uint32_t edges = 0;
    int last = digitalRead(p);
    const uint32_t t0 = millis();
    while (millis() - t0 < window) {
      const int v = digitalRead(p);
      if (v != last) {
        edges++;
        last = v;
      }
    }
    d.printf("G%-2d %s edges=%lu\n", p, driven ? "HI" : "lo",
             (unsigned long)edges);
    Serial.printf("G%d %s edges=%lu\n", p, driven ? "HI" : "lo",
                  (unsigned long)edges);
  }
  Serial.println("--- I2C SCAN ---");
  d.print("I2C:");
  for (uint8_t addr = 0x08; addr < 0x78; ++addr) {
    Wire.beginTransmission(addr);
    if (Wire.endTransmission() == 0) {
      d.printf(" %02X", addr);
      Serial.printf("i2c 0x%02X\n", addr);
    }
  }
  d.println();
  // Probe u-blox DDC on every unexplained address: 0xFD/0xFE hold the pending
  // byte count, 0xFF streams the NMEA/UBX payload.
  Serial.println("--- DDC PROBE ---");
  for (uint8_t addr : {(uint8_t)0x42, (uint8_t)0x75}) {
    Wire.beginTransmission(addr);
    Wire.write(0xFD);
    if (Wire.endTransmission(false) != 0) {
      Serial.printf("0x%02X: no ack on 0xFD\n", addr);
      continue;
    }
    if (Wire.requestFrom((int)addr, 2) != 2) {
      Serial.printf("0x%02X: no count\n", addr);
      continue;
    }
    uint16_t avail = (uint16_t)Wire.read() << 8;
    avail |= Wire.read();
    Serial.printf("0x%02X: avail=%u\n", addr, avail);
    if (avail == 0 || avail == 0xFFFF) continue;
    const uint8_t want = avail > 32 ? 32 : (uint8_t)avail;
    const uint8_t got = Wire.requestFrom((int)addr, (int)want);
    Serial.printf("0x%02X raw:", addr);
    for (uint8_t i = 0; i < got; ++i) {
      const uint8_t b = Wire.read();
      Serial.printf(" %02X", b);
    }
    Serial.println();
  }
  Serial.println("--- SCAN END ---");
  d.println("BtnA = continuar");
  const uint32_t hold = millis();
  while (waitButton && millis() - hold < 8000) {
    M5.update();
    if (M5.BtnA.wasPressed()) break;
    delay(20);
  }
}
// Hold BtnA + BtnC while powering on: pick the persistent role on screen.
static void roleSelectScreen() {
  auto& d = M5.Display;
  d.fillScreen(C_BG);
  d.setTextDatum(lgfx::textdatum_t::top_left);
  d.setTextColor(C_FG, C_BG);
  d.setTextSize(2);
  d.drawString("ROL DEL EQUIPO", 16, 20);
  d.setTextSize(1);
  d.drawString(String("Actual: ") + (role.anchor() ? "ANCLA" : "RIDER (moto)"), 16, 56);
  d.drawString("Suelta los botones y elige:", 16, 80);
  d.drawString("A = RIDER (moto)   B = cancelar   C = ANCLA", 16, 100);
  drawButtonBar(d, "RIDER", "CANCEL", "ANCLA");
  const uint32_t t0 = millis();
  while (M5.BtnA.isPressed() || M5.BtnC.isPressed()) {  // wait release
    M5.update();
    wdtFeed();
    delay(10);
    if (millis() - t0 > 10000) break;
  }
  const uint32_t t1 = millis();
  while (millis() - t1 < 15000) {
    M5.update();
    wdtFeed();
    if (M5.BtnA.wasClicked()) {
      role.setRole(Role::Rider);
      break;
    }
    if (M5.BtnC.wasClicked()) {
      role.setRole(Role::Anchor);
      break;
    }
    if (M5.BtnB.wasClicked()) break;
    delay(10);
  }
  d.fillRect(0, 130, 320, 40, C_BG);
  d.setTextSize(2);
  d.setTextColor(role.anchor() ? C_ORANGE : C_FG, C_BG);
  d.drawString(role.anchor() ? "-> ANCLA" : "-> RIDER", 16, 136);
  delay(1200);
}

static void printHelp() {
  Serial.println(
      "RiderLab serial:\n"
      "  HELP | STATUS | ANCHOR\n"
      "  ROLE | ROLE ANCHOR | ROLE RIDER      (persists, reboots)\n"
      "  ANT_H <m>                            antenna height over the mark\n"
      "  REF <lat>|<lon>|<h>|<source>|<sigma_m>|<point_id>[|ell|msl]\n"
      "  REF FROM AVG | REF CLEAR | REF?\n"
      "  AVG RESET                            restart anchor averaging\n"
      "  MARK [label] | COLOC START | COLOC END\n"
      "  KEEPSD ON|OFF                        keep session on SD after upload\n"
      "  THEME?                             UI theme (fixed: DARK)\n"
      "  AUTO ON|OFF | AUTO?                auto sessions (default ON)\n"
      "  AUTO START <kmh> <s> | AUTO STOP <kmh> <s> | AUTO FIXLOSS <s> | AUTO HACC <m>\n"
      "  AUTO IDLEHZ <1..10> | AUTO DEFAULTS   GNSS rate while armed (default 1)\n"
      "  SIMSPD <kmh> | SIMSPD OFF          bench: fake speed for the auto logic only\n"
      "  SIMPOS ON|OFF|?                    bench: positions from serial (P lines); sessions upload like real ones (0.6.9b)\n"
      "  P <utc_ms> <lat_e7> <lon_e7> <hmsl_mm> <gspeed_mm_s> <head_e5> <hacc_mm> <nsv>   (SIMPOS, no echo)\n"
      "  VIEW | VIEW FOLLOW|MAP|TOGGLE      circuit view; FOLLOW = rider-centred track-up (hold C on the page)\n"
      "  VIEW TRAIL | VIEW SPEED        0.6.9: no-circuit session view: fading trail + speed / home speedometer (hold B on home)\n"
      "  CIRCUITS? | CIRCUIT SELECT <n|AUTO> | AUTOOPEN ON|OFF|?  (0.6.7 circuit index / auto detect / auto open)\n"
      "  BLE PAIR | BLE OFF | BLE?  (0.6.8 pairing mode, bench) | WIFIUNDO (undo BLE WIFI of this boot)\n"
  "  CIRCUIT TESTWRITE | CIRCUIT TESTDEL | CIRCUIT REINDEX     bench: Bugambilias test circuit (one fixed file)\n"
  "  FOLLOW ZOOM <m> | FOLLOW FADE <s>  follow width m (150) / trail fade s (25), NVS | SHOT = screen dump\n"
      "  DIM ON|OFF | DIM <s> <pct> | DIM?  standby dim (default ON 30 s 12 pct)\n"
      "  GNSS | GNSSCFG | PINSCAN | IMU | BARO\n"
      "  WIFI ssid|pass  PAIR id|secret|url  AZURE key|url  WIFISCAN\n"
      "  LIST | DUMP <session>/<file> | LOG | LOGCLR\n"
      "  DIAG | DIAG ALL | DIAGCLR             field diag log (/riderlab/diag.log)\n"
      "  WIFISET ssid|pass (new active, old kept disabled) | WIFI?\n"
      "  UPCANCEL (cancel running upload, same path as a button) | UPSTAT\n"
      "  REUP <session>|ALL                   re-queue ride(s) still on SD for upload\n"
      "  CIRCUIT | CIRCUIT OPEN|MAP|SECTORS|CLOSE|FREE   circuit page (0.6.0)\n"
      "Buttons: A rec/stop, B menu, C upload(idle)/MARK(rec), hold C 1 s = COLOC (rider)\n"
      "Menu > CIRCUITO: A rec/stop, B salir, C mapa/sectores\n"
      "Boot: hold B = pin scan; hold A+C = role select");
}

static void printRef() {
  const RefPoint& r = role.ref();
  if (!r.set) {
    Serial.println("REF none");
    return;
  }
  Serial.printf("REF id=%s lat=%.9f lon=%.9f h=%.3f (%s) src=%s sigma=%.3f ant_h=%.3f\n", r.id,
                r.lat, r.lon, r.h, r.hMsl ? "msl" : "ell", r.source, r.sigma, role.antH());
}

static void printAnchor() {
  const uint32_t now = millis();
  const char* why = "";
  const bool rdy = anc.ready(now, &why);
  double lat = 0, lon = 0, h = 0;
  if (anc.haveMean()) anc.meanLlh(lat, lon, h);
  const Enu sd = anc.stdev();
  Serial.printf(
      "ANCHOR role=%s rec=%d n=%lu ready=%d(%s) mean=%.9f,%.9f,h_ell=%.3f std=%.3f/%.3f/%.3f "
      "err=%s %+.3f/%+.3f/%+.3f bumps=%lu moves=%lu imu=%d tilt=%.2f\n",
      role.roleName(), (int)logger.recording(), (unsigned long)anc.n(), (int)rdy, why, lat, lon,
      h, sd.e, sd.n, sd.u, anc.lastRefOk() ? "ref" : "mean", anc.lastD().e, anc.lastD().n,
      anc.lastD().u, (unsigned long)anc.bumps(), (unsigned long)anc.moves(),
      (int)anc.imuSane(), anc.tiltDeg());
  if (anc.refValid() && anc.haveMean()) {
    const Enu o = anc.offsetVsRef();
    Serial.printf("ANCHOR mean-REF E%+.3f N%+.3f U%+.3f m\n", o.e, o.n, o.u);
  }
  printRef();
}

static void refChanged(const char* why) {
  anc.updateRef(role.ref(), role.antH());
  logger.setManifestExtra(manifestExtra());
  char note[96];
  const RefPoint& r = role.ref();
  snprintf(note, sizeof(note), "%s %s %.8f %.8f %.3f", why, r.id, r.lat, r.lon, r.h);
  mark("ref", r.sigma, note);
}

// ===================================================================================================
// 0.6.5-simpos: simulated positions over the USB serial console.
//   SIMPOS ON | SIMPOS OFF | SIMPOS?
//   P <utc_ms> <lat_e7> <lon_e7> <hmsl_mm> <gspeed_mm_s> <head_e5> <hacc_mm> <nsv>   (no echo)
// While ON the u-blox keeps being parsed (link watchdog/hunt and GPS clock unchanged) but every
// consumer (circuit, auto, SD) sees only the injected fixes. No P line for > 2.5 s = fix lost.
static uint32_t simBad = 0, simIgnored = 0;
static size_t serRxBuf = 0;
static void simPosPrint() {
  const UbxPvt& sp = gnss.pvt();
  const UbxPvt& rp = gnss.realPvt();
  Serial.printf("SIMPOS on=%d fresh=%d rx=%lu bad=%lu ignored=%lu stales=%lu age_ms=%ld fix=%u "
                "lat=%.7f lon=%.7f kmh=%.1f | real: pvt=%d fix=%u sv=%u link=%s relinks=%lu "
                "nav_hz=%u rxbuf=%u\n",
                (int)gnss.simOn(), (int)gnss.simFresh(), (unsigned long)gnss.simRx(),
                (unsigned long)simBad, (unsigned long)simIgnored, (unsigned long)gnss.simStales(),
                (long)gnss.simAgeMs(), gnss.simOn() ? (unsigned)sp.fixType : 0u,
                gnss.simOn() ? sp.latDeg() : 0.0, gnss.simOn() ? sp.lonDeg() : 0.0,
                gnss.simOn() ? sp.gSpeed * 0.0036f : 0.f, (int)gnss.realPvtActive(),
                (unsigned)rp.fixType, (unsigned)rp.numSV, gnss.linkTag(),
                (unsigned long)gnss.relinks(), (unsigned)gnss.navHz(), (unsigned)serRxBuf);
}
static bool simPosLine(const char* c) {
  long long v[8];
  const char* q = c + 2;
  int n = 0;
  for (; n < 8; ++n) {
    char* e = nullptr;
    v[n] = strtoll(q, &e, 10);
    if (e == q) break;
    q = e;
  }
  if (n != 8 || v[0] < 0 || v[1] < -900000000LL || v[1] > 900000000LL || v[2] < -1800000000LL ||
      v[2] > 1800000000LL || v[4] < 0 || v[6] < 0) {
    simBad++;
    return false;
  }
  if (!gnss.simOn()) {
    simIgnored++;
    return false;
  }
  UbxPvt p;
  const uint32_t ms = (uint32_t)(v[0] % 86400000LL);
  p.iTOW = ms;  // not a real time of week; simulated PVTs carry valid=0 (GpsClock ignores them)
  const UbxPvt& rp = gnss.realPvt();
  p.year = rp.year, p.month = rp.month, p.day = rp.day;
  p.hour = ms / 3600000UL;
  p.min = (ms / 60000UL) % 60;
  p.sec = (ms / 1000UL) % 60;
  p.nano = (int32_t)(ms % 1000UL) * 1000000;
  p.valid = 0;
  p.fixType = 3;
  p.flags = 0x01;  // gnssFixOK
  p.numSV = (uint8_t)(v[7] < 0 ? 0 : (v[7] > 255 ? 255 : v[7]));
  p.lat = (int32_t)v[1];
  p.lon = (int32_t)v[2];
  p.hMSL = p.height = (int32_t)v[3];
  p.hAcc = (uint32_t)v[6];
  p.vAcc = (uint32_t)v[6] * 2;
  p.gSpeed = (int32_t)v[4];
  p.headMot = (int32_t)v[5];
  const double hr = v[5] * 1e-5 * M_PI / 180.0;
  p.velN = (int32_t)lround(p.gSpeed * cos(hr));
  p.velE = (int32_t)lround(p.gSpeed * sin(hr));
  p.sAcc = 200;
  p.headAcc = 100000;
  p.pDOP = 100;
  p.rxUs = esp_timer_get_time();
  gnss.injectPvt(p);
  if (gnss.takePvt()) processPvtEvent(millis());  // right away: no fix is lost to a burst of lines
  processFixEvent();
  return true;
}
static bool simPosSerial(const String& line) {
  if (line.length() > 2 && line[0] == 'P' && line[1] == ' ') {
    simPosLine(line.c_str());
    return true;
  }
  if (line == "SIMPOS ON") {
    if (role.anchor()) {
      Serial.println("SIMPOS refused (anchor role)");
      return true;
    }
    if (!gnss.simOn()) {
      gnss.simEnable(true);
      simBad = simIgnored = 0;
      cfix.valid = false;
      if (logger.recording()) sinfo.sim = sinfo.simPos = true;
      gDiag.logf("simpos", "ON rec=%d real_fix=%u link=%s", (int)logger.recording(),
                 (unsigned)gnss.realPvt().fixType, gnss.linkTag());
    }
  } else if (line == "SIMPOS OFF") {
    if (gnss.simOn()) {
      gDiag.logf("simpos", "OFF rx=%lu bad=%lu stales=%lu rec=%d", (unsigned long)gnss.simRx(),
                 (unsigned long)simBad, (unsigned long)gnss.simStales(), (int)logger.recording());
      gnss.simEnable(false);
      cfix.valid = false;
    }
  } else if (line != "SIMPOS?" && line != "SIMPOS") {
    return false;
  }
  simPosPrint();
  return true;
}

// ===================================================================================================
// 0.6.6-follow: rider-centred track-up circuit view (CircuitView Follow) + bench screenshot.
//   VIEW | VIEW? | VIEW FOLLOW | VIEW MAP | VIEW TOGGLE      (opens the circuit page if needed)
//   FOLLOW ZOOM <m> | FOLLOW ZOOM?                            metres across the screen (20..400, NVS)
//   SHOT                                                      LCD readback -> serial (RLE565 + base64)
// Button: on the circuit page HOLD C (1 s) toggles Follow <-> previous view (A = rec/stop, B = exit,
// C click = cycle views stay as in 0.6.4; hold C was unused on that page).
static void viewLoad() {
  Preferences p;
  if (!p.begin("rl_view", false)) return;
  // 02:00: default zoom 60 -> 100 m; 0.6.9c: 100 -> 150 m. A zoom saved before the change (fzv < 2) is
  // dropped once, so every device takes the new default.
  if (p.getUChar("fzv", 0) < 2) {
    p.remove("fz");
    p.putUChar("fzv", 2);
  }
  cview.setFollowZoom(p.getFloat("fz", CircuitView::kZoomDefault));
  cview.setFollowFade(p.getFloat("ff", 25.f));
  gLastFollow = p.getUChar("lv", 1) != 0;  // 0.6.7
  gAutoOpen = p.getUChar("ao", 1) != 0;    // 0.6.7
  p.end();
}
// 0.6.7: remember FOLLOW vs MAP (any other view counts as MAP) for the next open
static void viewRemember() {
  if (!cview.active()) return;
  const bool f = cview.following();
  if (f == gLastFollow) return;
  gLastFollow = f;
  Preferences p;
  if (p.begin("rl_view", false)) {
    p.putUChar("lv", f ? 1 : 0);
    p.end();
  }
  gDiag.logf("circuit", "LASTVIEW %s saved", f ? "follow" : "map");
}
static void viewSave() {
  Preferences p;
  if (!p.begin("rl_view", false)) return;
  p.putFloat("fz", cview.followZoom());
  p.putFloat("ff", cview.followFade());
  p.end();
}
static void viewPrint() {
  const Mem8 m = mem8();
  Serial.printf("VIEW page=%s mode=%s follow=%d zoom_m=%.0f fade_s=%.0f band_rows=%d fps=%.1f render_ms=%.1f max_ms=%.1f "
                "frames=%lu head=%.1f head_live=%d free8=%lu big8=%lu min8=%lu\n",
                pageName(), cview.active() ? cview.modeName() : (cview.bareActive() ? "trail" : "closed"), (int)cview.following(),
                cview.followZoom(), cview.followFade(), cview.followBand(), cview.followFps(), cview.followMsAvg(),
                cview.followMsMax(), (unsigned long)cview.followFrames(), cview.followHead(),
                (int)cview.followHeadLive(), (unsigned long)m.free, (unsigned long)m.big, (unsigned long)m.min);
}
static bool viewFollow(bool on, const char* why) {
  if (on && ui.page != UiPage::Circuit && !circuitOpen(why)) return false;
  if (!cview.active()) return false;
  const bool ok = cview.setFollow(on);
  cview.drawStatic(logger.recording());
  gDiag.logf("circuit", "VIEW %s why=%s ok=%d band=%d zoom=%.0f", cview.modeName(), why, (int)ok,
             cview.followBand(), cview.followZoom());
  if (!ok) uiLine = "SEGUIR: poca RAM";
  viewRemember();  // 0.6.7
  return ok;
}
static void b64row(const uint8_t* in, size_t n, char* out) {
  static const char* T = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  size_t o = 0;
  for (size_t i = 0; i < n; i += 3) {
    const uint32_t v = (uint32_t)in[i] << 16 | (i + 1 < n ? (uint32_t)in[i + 1] << 8 : 0) | (i + 2 < n ? in[i + 2] : 0);
    out[o++] = T[(v >> 18) & 63];
    out[o++] = T[(v >> 12) & 63];
    out[o++] = i + 1 < n ? T[(v >> 6) & 63] : '=';
    out[o++] = i + 2 < n ? T[v & 63] : '=';
  }
  out[o] = 0;
}
static void screenShot() {  // bench only: blocks the loop ~1-3 s
  // 0.6.8: buffers on the heap only while a shot runs (static DRAM went to the BLE controller)
  uint8_t* mem = (uint8_t*)malloc(2 * 320 + 3 * 320 + 4 * 320 + 8);
  if (!mem) { Serial.println("SHOT ERR heap"); return; }
  uint16_t* row = (uint16_t*)mem;
  uint8_t* rle = mem + 2 * 320;
  char* b64 = (char*)(mem + 5 * 320);
  auto& d = M5.Display;
  const int w = d.width(), h = d.height();
  const uint32_t t0 = millis();
  Serial.printf("SHOT BEGIN w=%d h=%d fmt=rle565b64 page=%s mode=%s\n", w, h, pageName(),
                cview.active() ? cview.modeName() : "-");
  for (int y = 0; y < h; ++y) {
    d.readRect(0, y, w, 1, row);
    size_t n = 0;
    for (int x = 0; x < w;) {
      int r = 1;
      while (x + r < w && r < 256 && row[x + r] == row[x]) ++r;
      rle[n++] = (uint8_t)(r - 1);
      rle[n++] = (uint8_t)(row[x] & 0xFF);
      rle[n++] = (uint8_t)(row[x] >> 8);
      x += r;
    }
    b64row(rle, n, b64);
    Serial.printf("R %d %s\n", y, b64);
    wdtFeed();
  }
  Serial.printf("SHOT END ms=%lu\n", (unsigned long)(millis() - t0));
  free(mem);
}
static bool viewSerial(const String& line) {
  float f1;
  if (line == "VIEW" || line == "VIEW?") {
  } else if (line == "VIEW FOLLOW") {
    viewFollow(true, "serial");
  } else if (line == "VIEW MAP") {
    if (ui.page != UiPage::Circuit) circuitOpen("serial");
    if (cview.active()) {
      cview.setMode(CircuitMode::Map);
      cview.drawStatic(logger.recording());
      viewRemember();  // 0.6.7
    }
  } else if (line == "VIEW TRAIL") {  // 0.6.9: needs a session and no circuit page
    if (!trailOpen("serial")) Serial.println("VIEW TRAIL refused (no session / circuit open / heap)");
  } else if (line == "VIEW SPEED") {  // 0.6.9: home speedometer
    if (ui.page == UiPage::Trail) {
      trailClose("serial-speed");
      paint(gnss.snapshot());
    }
  } else if (line == "VIEW TOGGLE") {
    viewFollow(!cview.following(), "serial");
  } else if (line == "FOLLOW ZOOM?" || line == "FOLLOW ZOOM") {
  } else if (sscanf(line.c_str(), "FOLLOW ZOOM %f", &f1) == 1) {
    cview.setFollowZoom(f1);
    viewSave();
    if (cview.following()) cview.drawStatic(logger.recording());
  } else if (sscanf(line.c_str(), "FOLLOW FADE %f", &f1) == 1) {
    cview.setFollowFade(f1);
    viewSave();
  } else if (line == "SHOT") {
    screenShot();
    return true;
  } else {
    return false;
  }
  viewPrint();
  return true;
}

static void handleSerialLine(String line) {
  if (simPosSerial(line)) {
    // 0.6.5-simpos: SIMPOS / P lines
  } else if (viewSerial(line)) {
    // 0.6.6-follow: VIEW / FOLLOW ZOOM / SHOT
  } else if (autoSerial(line)) {
    // 0.6.3-auto: AUTO / SIMSPD / DIM
  } else if (line == "HELP" || line == "?") {
    printHelp();
  } else if (line == "ROLE") {
    Serial.printf("ROLE %s\n", role.roleName());
  } else if (line == "ROLE ANCHOR" || line == "ROLE ANCLA" || line == "ROLE RIDER") {
    const Role r = line == "ROLE RIDER" ? Role::Rider : Role::Anchor;
    if (logger.recording()) stopRec();
    role.setRole(r);
    Serial.printf("ROLE -> %s (reboot)\n", role.roleName());
    Serial.flush();
    delay(300);
    ESP.restart();
  } else if (line.startsWith("ANT_H ")) {
    const float h = line.substring(6).toFloat();
    if (h >= 0 && h < 10) {
      role.setAntH(h);
      refChanged("ant_h");
      Serial.printf("ANT_H %.3f\n", h);
    } else {
      Serial.println("ANT_H ERR (0..10 m)");
    }
  } else if (line == "REF?" || line == "REF") {
    printRef();
  } else if (line == "REF CLEAR") {
    role.clearRef();
    refChanged("clear");
    Serial.println("REF cleared");
  } else if (line == "REF FROM AVG") {
    if (anc.n() < 60 * GNSS_TARGET_HZ) {
      Serial.printf("REF FROM AVG ERR: need >= %lu valid samples (have %lu)\n",
                    (unsigned long)(60 * GNSS_TARGET_HZ), (unsigned long)anc.n());
    } else {
      double lat, lon, h;
      anc.meanLlh(lat, lon, h);
      const Enu sd = anc.stdev();
      RefPoint r;
      r.lat = lat;
      r.lon = lon;
      r.h = h - role.antH();  // mark = antenna - ANT_H
      r.hMsl = false;
      strcpy(r.source, "avg");
      // Absolute uncertainty of a NEO-M9N average is ~0.5-1.5 m (not the epoch std).
      r.sigma = std::max(1.0f, (float)hypot(sd.e, sd.n));
      snprintf(r.id, sizeof(r.id), "avg-%.8s", logger.sessionId().c_str());
      role.setRef(r);
      refChanged("from_avg");
      Serial.println("REF set from current average (local origin, source=avg)");
      printRef();
    }
  } else if (line.startsWith("REF ")) {
    String f[7];
    String rest = line.substring(4);
    int k = 0;
    while (k < 7) {
      const int b = rest.indexOf('|');
      if (b < 0) {
        f[k++] = rest;
        break;
      }
      f[k++] = rest.substring(0, b);
      rest = rest.substring(b + 1);
    }
    RefPoint r;
    r.lat = strtod(f[0].c_str(), nullptr);
    r.lon = strtod(f[1].c_str(), nullptr);
    r.h = strtod(f[2].c_str(), nullptr);
    if (k < 6 || fabs(r.lat) > 90 || fabs(r.lon) > 180 || r.h < -500 || r.h > 9000 ||
        (r.lat == 0 && r.lon == 0)) {
      Serial.println("REF ERR usage: REF <lat>|<lon>|<h>|<source>|<sigma_m>|<point_id>[|ell|msl]");
    } else {
      f[3].trim();
      f[5].trim();
      strncpy(r.source, f[3].c_str(), sizeof(r.source) - 1);
      r.sigma = f[4].toFloat();
      strncpy(r.id, f[5].c_str(), sizeof(r.id) - 1);
      f[6].trim();
      f[6].toLowerCase();
      r.hMsl = (k >= 7 && f[6] == "msl");
      role.setRef(r);
      refChanged("serial");
      printRef();
    }
  } else if (line == "AVG RESET") {
    anc.resetAverage(millis());
    mark("avg_reset", 0, "serial");
    Serial.println("AVG reset");
  } else if (line == "ANCHOR" || line == "STATUS") {
    printAnchor();
    Serial.printf("GNSS link=%s cfg=%s path=%s hz=%u ubx=%lu bad=%lu pps=%s glitch=%lu\n",
                  gnss.linkTag(), gnss.cfgStatus(), gnss.pathTag(), (unsigned)gnss.hz(),
                  (unsigned long)gnss.ubxOk(), (unsigned long)gnss.ubxBad(), pps.state(),
                  (unsigned long)pps.glitches());
  } else if (line.startsWith("MARK")) {
    String note = line.length() > 5 ? line.substring(5) : String("serial");
    mark("cp", ++markNo, note.c_str());
    Serial.printf("MARK %d\n", markNo);
  } else if (line == "COLOC START") {
    coloc = true;
    mark("coloc_start", 0, "serial");
  } else if (line == "COLOC END") {
    coloc = false;
    mark("coloc_end", 0, "serial");
  } else if (line == "BLE PAIR" || line == "BLE OFF" || line == "BLE?") {  // 0.6.8 bench
    if (line == "BLE PAIR") {
      if (bleEnter("serial")) Serial.printf("BLE PIN %s\n", gBlePin);  // USB already allows PAIR directly
    } else if (line == "BLE OFF") {
      bleExit("serial");
    }
    Serial.printf("BLE on=%d btmem_free=%d conn=%d authed=%d bad=%d mtu=%d conns=%lu left_s=%ld heap=%lu big8=%lu min8=%lu\n",
                  (int)ble.on(), (int)gBtMemFree, (int)ble.connected(), (int)gBleAuthed, gBleBad, (int)ble.mtu(),
                  (unsigned long)ble.connects(),
                  ble.on() ? (long)((riderlab::BlePair::kTimeoutMs - (millis() - gBleT0)) / 1000) : 0L,
                  (unsigned long)ESP.getFreeHeap(),
                  (unsigned long)heap_caps_get_largest_free_block(MALLOC_CAP_8BIT),
                  (unsigned long)heap_caps_get_minimum_free_size(MALLOC_CAP_8BIT));
  } else if (line == "WIFIUNDO") {  // 0.6.8: undo the BLE WIFI write(s) of this boot
    if (gWifiSnap.ok) {
      uploader.restoreWifi(gWifiSnap);
      gWifiSnap = WifiUploader::WifiSnap();
      Serial.println("WIFIUNDO restored");
    } else {
      Serial.println("WIFIUNDO nothing");
    }
    uploader.printSlots();
  } else if (line == "UPLOAD HOLD" || line == "UPLOAD RESUME" || line == "UPLOAD?") {  // 0.6.7
    if (line != "UPLOAD?") {
      gUpHold = line == "UPLOAD HOLD";
      Preferences p;
      if (p.begin("rl_up", false)) {
        p.putUChar("hold", gUpHold ? 1 : 0);
        p.end();
      }
      if (gUpHold) cancelUpload("hold");
      gDiag.logf("upload", "HOLD %d (serial)", (int)gUpHold);
    }
    Serial.printf("UPLOAD hold=%d pending=%d recovering=%d\n", (int)gUpHold, rides.pendingCount(),
                  (int)rides.recovering());
  } else if (line == "CIRCUITS?" || line == "CIRCUITS") {  // 0.6.7-autocircuit
    circuitsPrint();
  } else if (line.startsWith("CIRCUIT SELECT ")) {
    const String a = line.substring(15);
    if (a == "AUTO") circSelectAuto("serial");
    else if (a.length() && isDigit(a[0]) && a.toInt() < cidx.n) circSelectManual(a.toInt(), "serial");
    else Serial.println("CIRCUIT SELECT ERR (n|AUTO)");
    circuitsPrint();
  } else if (line == "AUTOOPEN ON" || line == "AUTOOPEN OFF") {
    gAutoOpen = line == "AUTOOPEN ON";
    Preferences p;
    if (p.begin("rl_view", false)) {
      p.putUChar("ao", gAutoOpen ? 1 : 0);
      p.end();
    }
    Serial.printf("AUTOOPEN %s\n", gAutoOpen ? "ON" : "OFF");
  } else if (line == "AUTOOPEN?" || line == "AUTOOPEN") {
    Serial.printf("AUTOOPEN %s\n", gAutoOpen ? "ON" : "OFF");
  } else if (line == "CIRCUIT TESTWRITE" || line == "CIRCUIT TESTDEL") {  // bench only, one fixed file
    if (logger.recording() || !logger.sdOk()) {
      Serial.println("CIRCUIT TEST refused (recording or no SD)");
    } else if (line == "CIRCUIT TESTWRITE") {
      String why;
      const size_t n = CircuitIndex::writeTest(why);
      Serial.printf("CIRCUIT TESTWRITE %s bytes=%u path=%s\n", why.c_str(), (unsigned)n, CircuitIndex::kTestPath);
      gDiag.logf("circuit", "TESTWRITE %s bytes=%u path=%s", why.c_str(), (unsigned)n, CircuitIndex::kTestPath);
      if (n) circIndexBuild("testwrite");
    } else {
      const bool ok = CircuitIndex::deleteTest();
      Serial.printf("CIRCUIT TESTDEL %s path=%s\n", ok ? "ok" : "absent/fail", CircuitIndex::kTestPath);
      gDiag.logf("circuit", "TESTDEL %s path=%s", ok ? "ok" : "absent/fail", CircuitIndex::kTestPath);
      circIndexBuild("testdel");
    }
    circuitsPrint();
  } else if (line == "CIRCUIT REINDEX") {
    if (!logger.recording()) circIndexBuild("serial");
    circuitsPrint();
  } else if (line == "CIRCUIT" || line == "CIRCUIT?") {  // 0.6.0
    circuitStatus();
  } else if (line == "CIRCUIT OPEN") {
    if (ui.page != UiPage::Circuit) circuitOpen("serial");
    paint(gnss.snapshot());
    circuitStatus();
  } else if (line == "CIRCUIT SECTORS" || line == "CIRCUIT MAP" || line == "CIRCUIT NEXT" ||
             (line.length() == 10 && line.startsWith("CIRCUIT S") && line[9] >= '1' && line[9] <= '4')) {
    if (cview.active()) {  // 0.6.1: CIRCUIT S1..S4 = sector view, NEXT = same as button C
      if (line == "CIRCUIT MAP") cview.setMode(CircuitMode::Map);
      else if (line == "CIRCUIT SECTORS") cview.setMode(CircuitMode::Sectors);
      else if (line == "CIRCUIT NEXT") cview.nextMode();
      else cview.setMode(CircuitMode::Sector, line[9] - '1');
      const uint32_t t0 = millis();
      cview.drawStatic(logger.recording());
      gDiag.logf("circuit", "MODE %s elev=%d static_ms=%lu", cview.modeName(), (int)cview.elevOk(),
                 (unsigned long)(millis() - t0));
      viewRemember();  // 0.6.7
      paint(gnss.snapshot());
    }
    circuitStatus();
  } else if (line == "CIRCUIT CLOSE") {
    if (ui.page == UiPage::Circuit) circuitClose("serial");
    paint(gnss.snapshot());
    circuitStatus();
  } else if (line == "CIRCUIT FREE") {
    circuitRelease("serial");
    paint(gnss.snapshot());
    circuitStatus();
  } else if (line == "THEME" || line == "THEME?" || line.startsWith("THEME ")) {
    Serial.println("THEME DARK (fixed)");  // 0.6.2-circuit.6: dark is the only theme
  } else if (line == "KEEPSD ON" || line == "KEEPSD OFF") {
    role.setKeepSd(line == "KEEPSD ON");
    uploader.setKeepLocal(role.keepSd());
    Serial.printf("KEEPSD %d (effective %d)\n", (int)role.keepSdPref(), (int)role.keepSd());
  } else if (line == "GNSS") {
    char b[420];
    gnss.configJson(b, sizeof(b));
    Serial.printf("GNSS %s\n", b);
  } else if (line == "GNSSCFG") {
    gnss.requestReconfigure();
  } else if (line == "PINSCAN") {
    scanGnssPins(false);
    gnss.forceRelink();
    pps.begin(ppsPin());
    gnss.setAvoidRx(pps.pin());
    paint(gnss.snapshot());
  } else if (line == "IMU") {
    Serial.printf("IMU a=%.3f,%.3f,%.3f |a|=%.3f g=%.4f,%.4f,%.4f sane=%d gyro=%d base=%d tilt=%.2f\n",
                  lastAx, lastAy, lastAz, sqrtf(lastAx * lastAx + lastAy * lastAy + lastAz * lastAz),
                  lastGx, lastGy, lastGz, (int)anc.imuSane(), (int)anc.gyroSane(),
                  (int)anc.imuBaseline(), anc.tiltDeg());
  } else if (line == "BARO") {
    Serial.printf("BARO ready=%d pa=%.2f T=%.2f alt_isa=%.2f err=%lu\n", (int)baro.ready(),
                  baro.lastPa(), baro.lastTempC(), BaroService::isaAlt(baro.lastPa()),
                  (unsigned long)baro.errors());
  } else if (line == "DIAG" || line == "DIAG ALL") {
    gDiag.dump(logger.sdOk(), line == "DIAG ALL");
  } else if (line == "DIAGCLR") {
    gDiag.clear(logger.sdOk());
  } else if (line == "WIFI?") {
    uploader.printSlots();
  } else if (line.startsWith("WIFISET ")) {
    const String rest = line.substring(8);
    const int b1 = rest.indexOf('|');
    if (b1 > 0 && b1 < (int)rest.length() - 1) {
      uploader.setActiveKeepOld(rest.substring(0, b1), rest.substring(b1 + 1));
      Serial.println("WIFISET ok (password not echoed)");
      uploader.printSlots();
      gDiag.logf("wifi", "slots changed: active=%s old=%s old_enabled=%d",
                 uploader.ssid().c_str(),
                 uploader.oldSsid().length() ? uploader.oldSsid().c_str() : "(none)",
                 (int)uploader.slotBEnabled());
      uiLine = "WiFi saved";
    } else {
      Serial.println("WIFISET ERR use WIFISET ssid|pass");
    }
  } else if (line.startsWith("WIFI ")) {
    String rest = line.substring(5);
    const int b1 = rest.indexOf('|');
    const int b2 = rest.indexOf('|', b1 + 1);
    if (b1 > 0 && b2 > b1) {
      uploader.saveWifi(rest.substring(0, b1), rest.substring(b2 + 1),
                        rest.substring(b1 + 1, b2));
      uiLine = "WiFi saved";
    } else if (b1 > 0) {
      uploader.saveWifi(rest.substring(0, b1), rest.substring(b1 + 1));
      uiLine = "WiFi saved";
    }
  } else if (line == "UPCANCEL") {
    // Same path as a button press / recording start.
    Serial.printf("UPCANCEL busy=%d phase=%s\n", (int)upTask.busy(),
                  UploadTask::phaseName(upTask.phase()));
    cancelUpload("serial");
  } else if (line == "UPSTAT") {
    const Mem8 m = mem8();
    Serial.printf("UPSTAT task=%d busy=%d phase=%s cancel=%d pending=%d ok_this_boot=%d "
                  "fails=%u next_in_ms=%ld heap=%u largest=%lu free8=%lu min8=%lu "
                  "stack_free=%lu\n",
                  (int)upTaskOk, (int)upTask.busy(), UploadTask::phaseName(upTask.phase()),
                  (int)upTask.cancelRequested(), rides.pendingCount(), upPassOk,
                  (unsigned)wifiFailStreak, (long)(nextWifiTryMs - millis()), ESP.getFreeHeap(),
                  (unsigned long)m.big, (unsigned long)m.free, (unsigned long)m.min,
                  (unsigned long)upTask.stackHighWater());
  } else if (line.startsWith("REUP ")) {
    // 0.5.5: re-queue rides uploaded truncated by <=0.5.4. Only flips cloud=1 -> 0
    // in the index for sessions whose gnss.ndjson is still on the SD. Deletes nothing.
    if (upTask.busy() || logger.recording()) {
      Serial.println("REUP ERR busy (upload or recording)");
    } else {
      const String which = line.substring(5);
      const int n = rides.requeueCloud(which);
      Serial.printf("REUP %s requeued=%d pending=%d\n", which.c_str(), n, rides.pendingCount());
      gDiag.logf("upload", "REUP %.13s requeued=%d pending=%d", which.c_str(), n,
                 rides.pendingCount());
      if (n > 0) wantUpload = true;
    }
  } else if (line == "WIFISCAN") {
    if (!role.anchor() && !upTask.busy()) uploader.dumpScan();
  } else if (line.startsWith("AZURE ")) {
    String rest = line.substring(6);
    const int bar = rest.indexOf('|');
    if (bar > 0) {
      uploader.saveCredentials(uploader.deviceId().length() ? uploader.deviceId()
                                                            : "unpaired",
                               rest.substring(bar + 1), rest.substring(0, bar));
    } else {
      uploader.saveCredentials(uploader.deviceId().length() ? uploader.deviceId()
                                                            : "unpaired",
                               rest, AZURE_INGEST_URL);
    }
    uiLine = "Azure saved";
    } else if (line == "LIST") {
      // Session inventory over USB, so the SD never has to leave the device.
      Serial.println("LIST BEGIN");
      File dir = SD.open("/riderlab/sessions");
      if (dir) {
        for (File e = dir.openNextFile(); e; e = dir.openNextFile()) {
          if (e.isDirectory()) {
            File sub = SD.open(String("/riderlab/sessions/") + e.name());
            for (File f = sub.openNextFile(); f; f = sub.openNextFile()) {
              Serial.printf("L %s/%s %lu\n", e.name(), f.name(),
                            (unsigned long)f.size());
              f.close();
            }
            sub.close();
          }
          e.close();
        }
        dir.close();
      }
      Serial.println("LIST END");
      Serial.println("RIDES BEGIN");
      for (int i = 0; i < rides.count(); ++i) {
        const RideRec& r = rides.newest(i);
        Serial.printf("R %s gnss=%u cloud=%d\n", r.id, (unsigned)r.gnss,
                      r.cloud ? 1 : 0);
      }
      Serial.println("RIDES END");
    } else if (line == "LOG") {
      gLog.dumpTail();
    } else if (line == "LOGCLR") {
      gLog.clear();
      uiLine = "log cleared";
    } else if (line.startsWith("DUMP ")) {
      const String path = String("/riderlab/sessions/") + line.substring(5);
      File f = SD.open(path, FILE_READ);
      if (!f) {
        Serial.printf("DUMP ERR %s\n", path.c_str());
      } else {
        Serial.printf("DUMP BEGIN %s %lu\n", path.c_str(),
                      (unsigned long)f.size());
        // Multi-MB files block loop() for minutes, so feed the task watchdog.
        uint8_t buf[512];
        while (f.available()) {
          const size_t n = f.read(buf, sizeof(buf));
          if (n == 0) break;
          Serial.write(buf, n);
          // 0.5.3: discard GNSS bytes while blocked here. Otherwise UART2 overflows
          // and the driver's "FIFO Overflow" warnings share UART0 with the dump
          // (measured: ~3.9 KB/s instead of ~11 KB/s at 115200).
          while (Serial2.available() > 0) Serial2.read();
          upTask.serviceIo();
          yield();
        }
        f.close();
        Serial.println();
        Serial.println("DUMP END");
      }
    } else if (line.startsWith("PAIR ")) {
    String rest = line.substring(5);
    const int b1 = rest.indexOf('|');
    const int b2 = rest.indexOf('|', b1 + 1);
    if (b1 > 0 && b2 > b1) {
      uploader.saveCredentials(rest.substring(0, b1),
                               rest.substring(b1 + 1, b2),
                               rest.substring(b2 + 1));
      uiLine = "Paired";
    }
  } else if (line.length()) {
    Serial.printf("? %s (HELP)\n", line.c_str());
  }
}

static void bootGnss() {
  drawBootStatus("GNSS…");
  wdtFeed();
  gnss.setWire(Wire);
  if (gnss.beginAuto(Serial2, role.gnssRx(), role.gnssBaud())) {
    gLog.logf(LogLvl::Info, "gnss", "link %s", gnss.linkTag());
  } else if (gnss.beginI2c(Wire)) {
    logi("gnss", "link I2C 0x42");
  } else {
    loge("gnss", "no uart/i2c (keeps hunting)");
  }
}

static void configureGnss() {
  drawBootStatus("GNSS config…");
  // 0.5.2: ALWAYS re-arm PPS after a (re)link/hunt, not only on a pin change: a
  // hunt step on the PPS pin used to gpio_reset_pin() it and kill the interrupt.
  const int ppsPrevPin = pps.pin();
  const bool ppsRebegin = true;
  pps.begin(ppsPin());
  gnss.setAvoidRx(pps.pin());
  gDiag.logf("pps", "PPS re-begin pin=%d prev_pin=%d why=%s relinks=%lu n=%lu glitch=%lu",
             pps.pin(), ppsPrevPin, gnss.relinks() ? "relink" : "boot-cfg",
             (unsigned long)gnss.relinks(), (unsigned long)pps.count(),
             (unsigned long)pps.glitches());
  const bool ok = gnss.configure(Wire, role.gnssTx());
  role.setGnssLink(gnss.rxPin(), gnss.baud(), gnss.foundTx() >= 0 ? gnss.foundTx() : role.gnssTx());
  gLog.logf(ok ? LogLvl::Info : LogLvl::Warn, "gnss", "cfg %s path=%s link=%s hz=%u",
            gnss.cfgStatus(), gnss.pathTag(), gnss.linkTag(), (unsigned)gnss.hz());
  // DIAG: PPS state after (re)config (PPS was re-armed above).
  gDiag.logf("gnss", "CONFIGURE done ok=%d relinks=%lu pps_pin=%d pps_rebegin=%d pps_state=%s "
             "pps_n=%lu pps_glitch=%lu rec=%d",
             (int)ok, (unsigned long)gnss.relinks(), pps.pin(), (int)ppsRebegin, pps.state(),
             (unsigned long)pps.count(), (unsigned long)pps.glitches(), (int)logger.recording());
  if (logger.recording()) {
    logger.setPins(gnss.rxPin(), gnss.txPin());
    logger.setManifestExtra(manifestExtra());
    mark("gnss_cfg", ok ? 1 : 0, gnss.cfgStatus());
  }
}

void setup() {
  serRxBuf = Serial.setRxBufferSize(1024);  // 0.6.5-simpos: before Serial.begin (M5.begin)
  auto cfg = M5.config();
  cfg.serial_baudrate = 115200;
  cfg.clear_display = true;
  M5.begin(cfg);
  Serial.begin(115200);
  delay(50);
  // 0.6.8-ble: only BLE is ever used -> Classic-BT controller memory back to the heap now; the BLE part
  // too unless this boot was requested for pairing.
  {
    Preferences p;
    if (p.begin("rl_ble", false)) {
      gBlePairBoot = p.getUChar("boot", 0);
      if (gBlePairBoot) p.putUChar("boot", 0);  // one shot
      p.end();
    }
  }
  esp_bt_controller_mem_release(gBlePairBoot ? ESP_BT_MODE_CLASSIC_BT : ESP_BT_MODE_BTDM);
  gBtMemFree = !gBlePairBoot;
  bootMs = millis();
  resetName = EventLog::resetName(esp_reset_reason());

  role.load();
  autoLoad();  // 0.6.3-auto
  viewLoad();  // 0.6.6-follow
  ast = acfg.on ? AutoSt::Armed : AutoSt::Off;
  cview.autoTag = ui.autoShort;
  themeEraseLegacy();  // 0.6.2-circuit.6
  M5.update();
  if (M5.BtnA.isPressed() && M5.BtnC.isPressed()) roleSelectScreen();

  // Show life immediately (before SD/I2C which can stall).
  M5.Display.setBrightness(255);
  M5.Display.fillScreen(C_BG);
  M5.Display.setTextColor(C_FG, C_BG);
  playBootSplash();
  drawBootStatus(role.anchor() ? "ROL: ANCLA" : "ROL: RIDER");
  Serial.printf("\n==== RIDERLAB %s %s  ROLE=%s  hw=%s ====\n", FIRMWARE_NAME, FIRMWARE_VERSION,
                role.anchor() ? "ANCHOR (reference station)" : "RIDER", hwId().c_str());
  {
    const Mem8 m = mem8();
    gLog.logf(LogLvl::Info, "boot", "%s %s role=%s rst=%s heap=%u free8=%lu big8=%lu min8=%lu",
              FIRMWARE_NAME, FIRMWARE_VERSION, role.roleName(), resetName, ESP.getFreeHeap(),
              (unsigned long)m.free, (unsigned long)m.big, (unsigned long)m.min);
  }

  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);
  {  // one-line bus census in the boot log (expect 0x69 BMI270, 0x76 BMP280, 0x42 u-blox DDC)
    char found[160] = "";
    size_t n = 0;
    for (uint8_t addr = 0x08; addr < 0x78; ++addr) {
      Wire.beginTransmission(addr);
      if (Wire.endTransmission() == 0 && n + 6 < sizeof(found))
        n += snprintf(found + n, sizeof(found) - n, " 0x%02X", addr);
    }
    gLog.logf(LogLvl::Info, "i2c", "scan sda=%d scl=%d:%s", I2C_SDA_PIN, I2C_SCL_PIN, n ? found : " none");
  }
  M5.update();
  if (M5.BtnB.isPressed()) scanGnssPins();  // hold BtnB at boot to diagnose pins
  M5.BtnC.setHoldThresh(1000);

  bootGnss();
  pps.begin(ppsPin());
  gnss.setAvoidRx(pps.pin());  // 0.5.2: runtime hunt never touches the PPS pin
  if (gnss.locked()) configureGnss();
  wdtFeed();

  drawBootStatus("IMU…");
  wdtFeed();
  if (!imu.begin(Wire, ADDR_BMI270)) {
    gLog.logf(LogLvl::Error, "imu", "init fail: %s", imu.status());
  } else {
    float ax, ay, az, gx, gy, gz;
    delay(20);
    if (imu.read(ax, ay, az, gx, gy, gz)) {
      gLog.logf(LogLvl::Info, "imu", "ok %s |a|=%.2f m/s2 g=%.3f,%.3f,%.3f rad/s", imu.status(),
                sqrtf(ax * ax + ay * ay + az * az), gx, gy, gz);
    } else {
      logi("imu", "ok (no sample)");
    }
  }

  drawBootStatus("BARO…");
  wdtFeed();
  if (!baro.begin(Wire, ADDR_BMP280)) {
    loge("baro", "init fail");
  } else {
    delay(30);
    baro.sample();
    gLog.logf(LogLvl::Info, "baro", "ok %.2f Pa %.2f C (P x4 T x1 IIR16 ~83 Hz)",
              baro.lastPa(), baro.lastTempC());
  }

  drawBootStatus("SD…");
  wdtFeed();
  bootStep("pre-sd");
  if (!logger.beginSd()) {
    bootStep("beginSd-FAIL");
    gLog.logf(LogLvl::Error, "sd", "%s", logger.err().c_str());
  } else {
    bootStep("beginSd");
    gLog.beginSd();
    bootStep("eventlog");
    rides.begin();
    bootStep("rides-index");
    uploader.setIndex(&rides);
    const Mem8 m = mem8();
    gLog.logf(LogLvl::Info, "sd", "ok rides=%d max_files=%d free8=%lu big8=%lu", rides.count(),
              (int)SD_MAX_FILES, (unsigned long)m.free, (unsigned long)m.big);
  }

  uploader.loadPrefs();
  uploader.setKeepLocal(role.keepSd());
  {
    const Mem8 m = mem8();
    gDiag.logf("boot", "==== %s %s role=%s rst=%s hw=%s rides=%d pending=%d keepsd=%d sd=%d "
               "diag_size=%lu sd_max_files=%d free8=%lu big8=%lu min8=%lu ====",
               FIRMWARE_NAME, FIRMWARE_VERSION, role.roleName(), resetName, hwId().c_str(),
               rides.count(), rides.pendingCount(), (int)role.keepSd(), (int)logger.sdOk(),
               (unsigned long)gDiag.fileSize(logger.sdOk()), (int)SD_MAX_FILES,
               (unsigned long)m.free, (unsigned long)m.big, (unsigned long)m.min);
  }
  gDiag.logf("boot", "wifi active=%s en=%d old=%s old_en=%d azure=%d radio=%s", 
             uploader.ssid().length() ? uploader.ssid().c_str() : "(none)",
             (int)uploader.slotAEnabled(),
             uploader.oldSsid().length() ? uploader.oldSsid().c_str() : "(none)",
             (int)uploader.slotBEnabled(), (int)uploader.configured(),
             role.anchor() ? "off(anchor role)" : "on-demand");
  gDiag.logf("boot", "simpos serial_rxbuf=%u (0.6.5-simpos)", (unsigned)serRxBuf);
  Serial.printf("SIMPOS ready serial_rxbuf=%u\n", (unsigned)serRxBuf);
  gDiag.logf("boot", "gnss link=%s cfg=%s path=%s hz=%u", gnss.linkTag(), gnss.cfgStatus(),
             gnss.pathTag(), (unsigned)gnss.hz());
  bootStep("prefs+boot-log");
  gDiag.service(millis(), logger.sdOk(), true);
  bootStep("diag");
  if (role.anchor()) {
    radioOff();
    const RefPoint& r = role.ref();
    gLog.logf(LogLvl::Info, "anchor", "mode ON ref=%s ant_h=%.3f autostart=fix",
              r.set ? r.id : "none", role.antH());
    uiLine = "ancla: esperando fix";
  } else {
    upTaskOk = upTask.begin();
    {
      const Mem8 m = mem8();
      gDiag.logf("upload",
                 "TASK %s core=0 prio=1 stack=12288 chunk=%lu heap=%u largest=%lu free8=%lu "
                 "min8=%lu tls_need=%lu",
                 upTaskOk ? "ok" : "FAIL", (unsigned long)UploadTask::kChunk, ESP.getFreeHeap(),
                 (unsigned long)m.big, (unsigned long)m.free, (unsigned long)m.min,
                 (unsigned long)UploadTask::kTlsNeedLargest);
    }
    gLog.logf(LogLvl::Info, "boot", "ready wifi=%d azure=%d",
              (int)uploader.wifiReady(), (int)uploader.configured());
    if (uploader.configured() && rides.hasLocalPending()) {
      wantUpload = true;
      uploadAfterMs = millis() + 5000;
      uiLine = String("cola ") + rides.pendingCount();
      gLog.logf(LogLvl::Info, "azure", "boot pending=%d", rides.pendingCount());
    }
  }
  bootStep("pre-circuits");
  circIndexBuild("boot");  // 0.6.7-autocircuit: light index (SD mounted above)
  bootStep("circuits");
  {
    Preferences p;
    if (p.begin("rl_up", true)) {
      gUpHold = p.getUChar("hold", 0) != 0;
      p.end();
    }
  }
  Serial.printf("BOOT ready_ms=%lu uphold=%d ble_boot=%d\n", (unsigned long)millis(), (int)gUpHold,
                (int)gBlePairBoot);
  lastInputMs = millis();
  if (gBlePairBoot && bleEnter(gBlePairBoot == 2 ? "serial" : "menu") && gBlePairBoot == 2)
    Serial.printf("BLE PIN %s\n", gBlePin);
  paint(gnss.snapshot());
}

static bool haveSat = false;
// 0.6.5-simpos: one PVT event (real or injected) through every consumer. Same order as 0.6.4.
static void processPvtEvent(uint32_t nowMs) {
  const UbxPvt& p = gnss.pvt();
  if (!gnss.simOn()) gclock.onPvt(p, pps);  // simulated: the clock follows the real receiver
  if (crt) circuitOnPvt();  // 0.6.0 lap/sector timer (10 Hz)
  trailOnPvt();             // 0.6.9-trail: local frame for the no-circuit trail
  circDetect(nowMs);        // 0.6.7-autocircuit (<= 1 Hz, good 3D fix only)
  autoOnPvt(p, nowMs);      // 0.6.3-auto: evaluated on EVERY PVT (1 Hz idle, 10 Hz otherwise)
  if (logger.recording()) logger.logPvt(p, pps.seq());
  if (role.anchor()) {
    const AnchorEngine::EpochOut eo = anc.onPvt(p, role.ref(), role.antH(), nowMs);
    if (logger.recording() && p.good3d()) {
      logger.logAnchorErr(p, eo.d.e, eo.d.n, eo.d.u, eo.refOk, eo.valid, eo.stab,
                          anc.disturbed(nowMs), haveSat ? &gnss.sat() : nullptr,
                          haveBaro ? lastBaro.pa : 0, haveBaro ? lastBaro.tempC : 0);
    }
  }
}
static void processFixEvent() {
  if (logger.recording() && gnss.consumeFix()) {
    const GnssFix fix = gnss.snapshot();
    if (fix.valid) {
      logger.logGnss(pps.seq(), fix.lat, fix.lng, fix.alt,
                     fix.speedMps >= 0 ? fix.speedMps : 0, fix.heading,
                     fix.accM, fix.sats, fix.hdop, fix.utcMs);
    }
  }
}

static void handleGnssData(uint32_t nowMs) {
  for (int k = 0; k < 12; ++k) {
    gnss.poll();
    bool any = false;
    if (gnss.takeRealPvt()) {  // 0.6.5-simpos: GPS clock keeps following the receiver while simulating
      any = true;
      if (gnss.simOn()) gclock.onPvt(gnss.realPvt(), pps);
    }
    if (gnss.takePvt()) {
      any = true;
      processPvtEvent(nowMs);
    }
    if (gnss.takeSat()) {
      any = true;
      haveSat = true;
      if (logger.recording()) logger.logSat(gnss.sat());
    }
    if (gnss.takeDop()) {
      any = true;
      if (logger.recording()) logger.logDop(gnss.dop());
    }
    if (logger.recording() && gnss.consumeFix()) {
      any = true;
      const GnssFix fix = gnss.snapshot();
      if (fix.valid) {
        logger.logGnss(pps.seq(), fix.lat, fix.lng, fix.alt,
                       fix.speedMps >= 0 ? fix.speedMps : 0, fix.heading,
                       fix.accM, fix.sats, fix.hdop, fix.utcMs);
      }
    }
    if (!any) break;
  }
}

static void handleImu(uint32_t nowMs) {
  const uint32_t nowUs = micros();
  const uint32_t imuPeriodUs = 1000000UL / IMU_TARGET_HZ;
  const bool need = logger.recording() || role.anchor();
  if (!need || !imu.ready() || (nowUs - lastImuUs) < imuPeriodUs) return;
  lastImuUs = nowUs;
  float ax, ay, az, gx, gy, gz;
  if (!imu.read(ax, ay, az, gx, gy, gz)) return;
  lastAx = ax, lastAy = ay, lastAz = az, lastGx = gx, lastGy = gy, lastGz = gz;
  const double tow = towNow();
  if (role.anchor()) {
    anc.onImu(ax, ay, az, gx, gy, gz, nowMs, tow);
    AnchorEvent ev;
    while (anc.popEvent(ev)) mark(ev.kind, ev.value, "imu");
    if (anc.takeMoved()) {
      anc.resetAverage(nowMs);
      movedAlertUntil = nowMs + 120000;
      mark("avg_reset", 0, "moved");
      // wake the screen so whoever moved it sees the warning
      lastInputMs = nowMs;
    }
  }
  if (logger.recording()) {
    const uint32_t logHz = role.anchor() ? ANCHOR_IMU_LOG_HZ : IMU_TARGET_HZ;
    if (logHz >= IMU_TARGET_HZ || nowMs - lastImuLogMs >= 1000 / logHz) {
      lastImuLogMs = nowMs;
      logger.logImu(pps.seq(), ax, ay, az, gx, gy, gz, tow);
    }
  }
}

static void handleBaro(uint32_t nowMs) {
  if (!baro.ready()) return;
  const uint32_t nowUs = micros();
  if (nowUs - lastBaroSampleUs >= 1000000UL / BARO_SAMPLE_HZ) {
    lastBaroSampleUs = nowUs;
    baro.sample();
  }
  if (nowMs - lastBaroLogMs >= 1000 / BARO_LOG_HZ) {
    lastBaroLogMs = nowMs;
    BaroSample b;
    if (!baro.take(b)) return;
    lastBaro = b;
    haveBaro = true;
    const char* src = "none";
    const double tow = gclock.towAt(b.midUs, &src);
    if (!logger.recording()) {
      if (!role.anchor()) prePushBaro(b, tow, src, pps.seq());  // 0.6.3-auto pre-roll
      return;
    }
    const UbxPvt& p = gnss.pvt();
    const int32_t age = gnss.ubxActive() ? (int32_t)((b.midUs - p.rxUs) / 1000) : -1;
    logger.logBaro(pps.seq(), b, tow, src, gnss.ubxActive() ? &p : nullptr, age);
  }
}

static void anchorAutomation(uint32_t nowMs) {
  if (!role.anchor()) return;
  if (!logger.recording() && logger.sdOk() && !userStopped) {
    const bool fix = (gnss.ubxActive() && gnss.pvt().good3d()) || gnss.snapshot().valid;
    if (fix) startRec("auto-fix");
    else if (nowMs - bootMs > 300000) startRec("auto-nofix-baro");  // baro ref still useful
  }
  if (logger.recording() && nowMs - lastSummaryMs >= ANCHOR_SUMMARY_EVERY_MS) {
    lastSummaryMs = nowMs;
    writeAnchorSummary(false);
  }
  // Screen dim (power) — wake on any button or on a move alarm.
  const bool wantDim = nowMs - lastInputMs > ANCHOR_DIM_AFTER_MS;
  if (wantDim != dimmed) {
    dimmed = wantDim;
    M5.Display.setBrightness(dimmed ? ANCHOR_DIM_LEVEL : 255);
  }
}

// ---------------- DIAG: loop timing / stalls / UART health (0.5.1-diag) ----------------
enum DiagSec : uint8_t { S_UPD, S_MAINT, S_CFG, S_GNSS, S_IMU, S_BARO, S_TICK, S_AUTO, S_BTN,
                         S_UP, S_SER, S_UI, S_DIAG, S_N };
static const char* const kSecName[S_N] = {"m5upd", "gnss_maint", "gnss_cfg", "gnss_data",
                                          "imu", "baro", "sd_tick", "anchor_auto", "buttons",
                                          "wifi_upload", "serial", "display", "diag_sd"};
static uint32_t secMs[S_N];
static uint32_t secT0 = 0, loopT0 = 0, prevLoopT0 = 0, prevLoopEnd = 0;
static uint32_t winLoopMax = 0, winLoops = 0, winLoopSum = 0, winStalls = 0;
static uint32_t lastStallLogMs = 0, stallSuppressed = 0, lastHealthMs = 0;
static uint32_t hBytes = 0, hValid = 0, hUbxOk = 0, hUbxBad = 0, hNmeaBad = 0, hLenOvf = 0;
static uint32_t hBufFull = 0, hFifoOvf = 0, hFrameErr = 0;

static inline void secMark(DiagSec s) {
  const uint32_t n = millis();
  secMs[s] += n - secT0;
  secT0 = n;
}

static void diagLoopBegin() {
  const uint32_t n = millis();
  prevLoopT0 = loopT0;
  loopT0 = n;
  secT0 = n;
  for (auto& v : secMs) v = 0;
  if (prevLoopEnd && n - prevLoopEnd >= 200) {
    gDiag.logf("stall", "OUTSIDE-LOOP gap_ms=%lu (between loop() calls)",
               (unsigned long)(n - prevLoopEnd));
  }
}

static void diagLoopEnd(uint32_t nowMs) {
  const uint32_t end = millis();
  prevLoopEnd = end;
  const uint32_t total = end - loopT0;
  winLoops++;
  winLoopSum += total;
  if (total > winLoopMax) winLoopMax = total;
  if (total >= 200) {
    winStalls++;
    if (total >= 1000 || end - lastStallLogMs >= 5000) {
      int worst = 0;
      for (int i = 1; i < S_N; ++i)
        if (secMs[i] > secMs[worst]) worst = i;
      char parts[200];
      size_t o = 0;
      parts[0] = 0;
      for (int i = 0; i < S_N && o + 24 < sizeof(parts); ++i)
        if (secMs[i] >= 5)
          o += snprintf(parts + o, sizeof(parts) - o, " %s=%lu", kSecName[i],
                        (unsigned long)secMs[i]);
      gDiag.logf("stall", "LOOP total_ms=%lu cause=%s(%lu) rec=%d wifi=%d page=%s gnss=%s "
                 "suppressed=%lu parts:%s",
                 (unsigned long)total, kSecName[worst], (unsigned long)secMs[worst],
                 (int)logger.recording(), (int)(WiFi.getMode() != WIFI_OFF), pageName(),
                 gnss.linkTag(), (unsigned long)stallSuppressed, parts);
      lastStallLogMs = end;
      stallSuppressed = 0;
    } else {
      stallSuppressed++;
    }
  }
  (void)nowMs;
}

// Every 10 s: G16 UART health + loop timing window.
static void diagHealth(uint32_t nowMs) {
  if (lastHealthMs && nowMs - lastHealthMs < 10000) return;
  const uint32_t dt = lastHealthMs ? nowMs - lastHealthMs : 0;
  lastHealthMs = nowMs;
  const uint32_t b = gnss.bytesTotal(), v = gnss.validFrames(), uo = gnss.ubxOk(),
                 ub = gnss.ubxBad(), nb = gnss.nmeaBad(), lo = gnss.lenOverflows(),
                 bf = gnss.uartBufFull(), fo = gnss.uartFifoOvf(), fe = gnss.uartFrameErr();
  if (dt) {
    const GnssFix f = gnss.snapshot();
    gDiag.logf("uart",
               "HEALTH link=%s locked=%d cfg=%s B/s=%lu valid/s=%.1f ubx_ok+%lu ubx_bad+%lu "
               "nmea_bad+%lu len_ovf+%lu buf_full+%lu fifo_ovf+%lu frame_err+%lu rx_hw=%d/4096 "
               "silent_ms=%lu hz=%u fix=%d sv=%d relinks=%lu loop_max=%lu loop_avg=%lu "
               "stalls=%lu rec=%d wifi=%d minheap=%u pps=%s/%lu pin=%d free8=%lu big8=%lu "
               "min8=%lu",
               gnss.linkTag(), (int)gnss.locked(), gnss.cfgStatus(),
               (unsigned long)((b - hBytes) * 1000UL / dt), (v - hValid) * 1000.0 / dt,
               (unsigned long)(uo - hUbxOk), (unsigned long)(ub - hUbxBad),
               (unsigned long)(nb - hNmeaBad), (unsigned long)(lo - hLenOvf),
               (unsigned long)(bf - hBufFull), (unsigned long)(fo - hFifoOvf),
               (unsigned long)(fe - hFrameErr), gnss.takeRxHigh(),
               (unsigned long)gnss.silentMs(), (unsigned)gnss.hz(), (int)f.valid, f.sats,
               (unsigned long)gnss.relinks(), (unsigned long)winLoopMax,
               (unsigned long)(winLoops ? winLoopSum / winLoops : 0), (unsigned long)winStalls,
               (int)logger.recording(), (int)(WiFi.getMode() != WIFI_OFF),
               (unsigned)ESP.getMinFreeHeap(), pps.state(), (unsigned long)pps.count(),
               pps.pin(), (unsigned long)heap_caps_get_free_size(MALLOC_CAP_8BIT),
               (unsigned long)heap_caps_get_largest_free_block(MALLOC_CAP_8BIT),
               (unsigned long)heap_caps_get_minimum_free_size(MALLOC_CAP_8BIT));
  }
  hBytes = b, hValid = v, hUbxOk = uo, hUbxBad = ub, hNmeaBad = nb, hLenOvf = lo;
  hBufFull = bf, hFifoOvf = fo, hFrameErr = fe;
  winLoopMax = winLoops = winLoopSum = winStalls = 0;
}

// ---------------- 0.5.2 upload scheduler ----------------
// - the wait is measured from the END of an attempt (old code stamped
//   lastWifiTryMs before the 12-24 s join, so it retried immediately forever);
// - failed join / failed pass -> backoff 30 s, 60 s, 120 s, 240 s, max 5 min;
//   reset on success;
// - a non-blocking scan runs first; no join when no enabled SSID is in range;
// - the loop (M5.update / buttons / GNSS) keeps running between attempts.
static void wifiBackoff(const char* reason, uint32_t endMs) {
  if (wifiFailStreak < 250) wifiFailStreak++;
  uint32_t w = 30000UL << (wifiFailStreak > 5 ? 4 : wifiFailStreak - 1);
  if (w > 300000UL) w = 300000UL;
  wifiBackoffMs = w;
  nextWifiTryMs = endMs + w;
  gDiag.logf("wifi", "BACKOFF reason=%s fails=%u next_in_ms=%lu pending=%d", reason,
             (unsigned)wifiFailStreak, (unsigned long)w, rides.pendingCount());
  if (ui.page != UiPage::Wifi) requestRadioOff();
}

static void wifiBackoffReset(const char* why, uint32_t endMs, uint32_t gapMs) {
  if (wifiFailStreak || wifiBackoffMs)
    gDiag.logf("wifi", "BACKOFF reset why=%s after_fails=%u", why, (unsigned)wifiFailStreak);
  wifiFailStreak = 0;
  wifiBackoffMs = 0;
  nextWifiTryMs = endMs + gapMs;
}

// ---------------- 0.5.3 streamed upload (loop side) ----------------
static bool appendEsc(char* dst, size_t cap, size_t& n, const char* s) {
  const size_t len = strlen(s);
  for (size_t i = 0; i < len; ++i) {
    if (n + 3 > cap) return false;
    n += UploadTask::escape((const uint8_t*)s + i, 1, dst + n);
  }
  dst[n] = 0;
  return true;
}
static bool appendLit(char* dst, size_t cap, size_t& n, const char* s) {
  const size_t len = strlen(s);
  if (n + len + 1 > cap) return false;
  memcpy(dst + n, s, len);
  n += len;
  dst[n] = 0;
  return true;
}
static bool appendRaw(char* dst, size_t cap, size_t& n, const char* s, size_t len) {
  if (n + len + 1 > cap) return false;
  memcpy(dst + n, s, len);
  n += len;
  dst[n] = 0;
  return true;
}

// 0 = ready, 1 = skip this ride (marked no-upload), 2 = cannot upload now.
// Reproduces the <=0.5.2 payload exactly, without holding it in RAM.
static int prepareJob(const char* sid) {
  UploadJob& j = upJob;
  snprintf(j.sid, sizeof(j.sid), "%s", sid);
  snprintf(j.gnssPath, sizeof(j.gnssPath), "/riderlab/sessions/%s/gnss.ndjson", sid);
  if (!uploader.fillJobNet(j)) {
    gDiag.logf("upload", "PREP fail sid=%.13s reason=no-net-or-creds", sid);
    return 2;
  }
  // manifest: first balanced {...} of the first 2048 bytes (firstJsonObject()).
  static char man[2049];
  size_t mn = 0;
  {
    char mp[96];
    snprintf(mp, sizeof(mp), "/riderlab/sessions/%s/manifest.json", sid);
    File f = SD.open(mp, FILE_READ);
    if (f) {
      mn = f.read((uint8_t*)man, 2048);
      f.close();
    }
  }
  man[mn] = 0;
  const char* mStart = nullptr;
  size_t mLen = 0;
  {
    const char* a = (const char*)memchr(man, '{', mn);
    if (a) {
      int depth = 0;
      for (const char* q = a; q < man + mn; ++q) {
        if (*q == '{') depth++;
        else if (*q == '}' && --depth == 0) {
          mStart = a;
          mLen = (size_t)(q - a + 1);
          break;
        }
      }
    }
    if (!mStart) {
      mStart = "{}";
      mLen = 2;
    }
  }
  // 0.5.5: gnss = the WHOLE file (<=0.5.4 cut it at 24000 B => truncated blobs
  // with HTTP 200). Only a trailing partial line (no '\n') is left out.
  File g = SD.open(j.gnssPath, FILE_READ);
  if (!g) {
    rides.markNoUpload(sid);
    gDiag.logf("upload", "PREP skip sid=%.13s reason=no-gnss-file (marked no-upload)", sid);
    return 1;
  }
  const uint32_t size = g.size();
  if (size > UploadTask::kGnssMax) {  // never send part of a ride; stays pending
    g.close();
    gDiag.logf("upload", "PREP fail sid=%.13s reason=gnss-too-big size=%lu max=%lu", sid,
               (unsigned long)size, (unsigned long)UploadTask::kGnssMax);
    return 2;
  }
  const uint32_t cap = size;
  static uint8_t buf[UploadTask::kChunk];
  uint32_t pos = 0, esc = 0, escAtNl = 0;
  int32_t lastNl = -1;
  while (pos < cap) {
    const uint32_t want = (cap - pos) > sizeof(buf) ? sizeof(buf) : (cap - pos);
    const int got = g.read(buf, want);
    if (got <= 0) break;
    for (int i = 0; i < got; ++i) {
      esc += UploadTask::escLen(buf[i]);
      if (buf[i] == '\n') {
        lastNl = (int32_t)(pos + i);
        escAtNl = esc;
      }
    }
    pos += got;
    wdtFeed();  // 0.5.5: whole-file scan can take >1 s on big rides
  }
  g.close();
  if (pos != cap) {
    gDiag.logf("upload", "PREP fail sid=%.13s reason=sd-read pos=%lu cap=%lu", sid,
               (unsigned long)pos, (unsigned long)cap);
    return 2;
  }
  j.gnssFile = size;
  j.gnssRaw = cap;
  j.gnssEsc = esc;
  if (cap > 0 && lastNl > 16 && (uint32_t)lastNl + 1 < cap) {  // drop only a partial last line
    j.gnssRaw = (uint32_t)lastNl + 1;
    j.gnssEsc = escAtNl;
  }
  if (j.gnssRaw < 16) {
    rides.markNoUpload(sid);
    gDiag.logf("upload", "PREP skip sid=%.13s reason=empty-gnss raw=%lu (marked no-upload)", sid,
               (unsigned long)j.gnssRaw);
    return 1;
  }
  const char* did = j.devId[0] ? j.devId : "unpaired";
  size_t n = 0;
  const size_t pc = sizeof(j.prefix);
  bool ok = appendLit(j.prefix, pc, n, "{\"device_id\":\"") && appendEsc(j.prefix, pc, n, did) &&
            appendLit(j.prefix, pc, n, "\",\"session_id\":\"") &&
            appendEsc(j.prefix, pc, n, sid) &&
            appendLit(j.prefix, pc, n, "\",\"manifest\":") &&
            appendRaw(j.prefix, pc, n, mStart, mLen) &&
            appendLit(j.prefix, pc, n, ",\"gnss_ndjson\":\"");
  if (!ok) {
    gDiag.logf("upload", "PREP fail sid=%.13s reason=prefix-overflow", sid);
    return 2;
  }
  j.prefixLen = (uint16_t)n;
  j.total = (uint32_t)n + j.gnssEsc + 2;  // + closing "}
  return 0;
}

static bool startNextUpload(const char* why) {
  if (!upTaskOk || upTask.busy() || logger.recording() || ast == AutoSt::Cand) return false;
  circuitRelease("upload");  // 0.6.0: give the uploader its heap back BEFORE prepare/TLS
  for (int guard = 0; guard <= RideIndex::kMax; ++guard) {
    const String sid = rides.pendingId();
    if (!sid.length()) return false;
    const uint32_t tp = millis();
    const int pr = prepareJob(sid.c_str());
    if (pr == 1) continue;
    if (pr == 2) {
      wifiBackoff("prep-fail", millis());
      return false;
    }
    if (!upTask.start(upJob)) return false;
    upStartMs = millis();
    lastUpPhase = UploadTask::JOIN;
    upCancelWhy[0] = 0;
    tlsMinFree8 = tlsMinBig8 = 0xFFFFFFFFUL;
    tlsSamples = 0;
    const Mem8 m = mem8();
    gDiag.logf("upload",
               "START sid=%.13s why=%s total=%lu gnss_file=%lu gnss_raw=%lu gnss_esc=%lu prefix=%u prep_ms=%lu "
               "heap=%u largest=%lu free8=%lu min8=%lu keepsd=%d pending=%d",
               upJob.sid, why, (unsigned long)upJob.total, (unsigned long)upJob.gnssFile,
               (unsigned long)upJob.gnssRaw,
               (unsigned long)upJob.gnssEsc, (unsigned)upJob.prefixLen,
               (unsigned long)(upStartMs - tp), ESP.getFreeHeap(), (unsigned long)m.big,
               (unsigned long)m.free, (unsigned long)m.min, (int)role.keepSd(),
               rides.pendingCount());
    uiLine = String("subiendo ") + rides.pendingCount();
    return true;
  }
  return false;
}

static void onUploadResult(const UploadResult& r) {
  lastWifiTryMs = millis();
  gDiag.logf("upload",
             "END sid=%.13s http=%d status=%s ms=%lu join=%lu tls=%lu send=%lu wait=%lu "
             "sent=%lu/%lu chunks=%lu heap_start=%lu heap_min=%lu heap_pre_tls=%lu "
             "largest_pre_tls=%lu stack_free=%lu rssi=%d ip=%s cancelled=%d phase=%s resp=%.40s",
             r.sid, r.http, r.status, (unsigned long)r.ms, (unsigned long)r.joinMs,
             (unsigned long)r.tlsMs, (unsigned long)r.sendMs, (unsigned long)r.waitMs,
             (unsigned long)r.sent, (unsigned long)r.total, (unsigned long)r.chunks,
             (unsigned long)r.heapStart, (unsigned long)r.heapMin, (unsigned long)r.heapPreTls,
             (unsigned long)r.largestPreTls, (unsigned long)upTask.stackHighWater(), (int)r.rssi,
             r.ip, (int)r.cancelled, r.phaseAtEnd, r.resp);
  if (r.lowMem) {
    gDiag.logf("upload", "SKIP lowmem largest=%lu need=%lu free8=%lu min8=%lu sid=%.13s",
               (unsigned long)r.largestPreTls, (unsigned long)UploadTask::kTlsNeedLargest,
               (unsigned long)r.free8PreTls, (unsigned long)r.min8PreTls, r.sid);
  } else if (r.tlsTried) {
    // min8 is boot-wide; a lower value after TLS means the low was hit during TLS.
    const bool newLow = r.min8PostTls < r.min8PreTls;
    gDiag.logf("upload",
               "TLS %s ms=%lu pre: free8=%lu big8=%lu | post: free8=%lu big8=%lu | "
               "min8_during_tls=%s%lu (boot_min8 pre=%lu post=%lu) | loop_sampled: "
               "min_free8=%lu min_big8=%lu n=%lu",
               r.tlsOk ? "ok" : "FAIL", (unsigned long)r.tlsMs, (unsigned long)r.free8PreTls,
               (unsigned long)r.largestPreTls, (unsigned long)r.free8PostTls,
               (unsigned long)r.largestPostTls, newLow ? "" : ">=",
               (unsigned long)(newLow ? r.min8PostTls : r.min8PreTls),
               (unsigned long)r.min8PreTls, (unsigned long)r.min8PostTls,
               (unsigned long)(tlsSamples ? tlsMinFree8 : 0),
               (unsigned long)(tlsSamples ? tlsMinBig8 : 0), (unsigned long)tlsSamples);
  }
  if (r.cancelled) {
    gDiag.logf("upload", "CANCELLED sid=%.13s why=%s ack_ms=%lu phase=%s", r.sid, upCancelWhy,
               (unsigned long)r.cancelAckMs, r.phaseAtEnd);
    uiLine = "subida cancelada";
    wifiBackoff("cancelled", millis());
    return;
  }
  if (r.http >= 200 && r.http < 300 && r.sent == r.total && r.total > 0) {
    // 0.5.5: cloud=1 only if the server answered 2xx AND every body byte went out.
    // CRITICAL: KEEPSD -> index only (cloud=1). Nothing on the SD is deleted,
    // truncated or created. Delete only when KEEPSD is OFF everywhere.
    const bool keep = role.keepSd() || uploader.keepLocal();
    if (keep) {
      rides.markCloudKeep(String(r.sid));
      gDiag.logf("upload", "KEEP sid=%.13s cloud=1 (keepsd=1: SD untouched)", r.sid);
    } else {
      gDiag.logf("upload", "DELETE sid=%.13s (keepsd=0)", r.sid);
      rides.markCloudAndDelete(String(r.sid), String("/riderlab/sessions/") + r.sid);
    }
    upPassOk++;
    upLastErr = false;  // 0.6.2-circuit.7-rastro
    gLog.logf(LogLvl::Info, "https", "%d id=%s bytes=%lu", r.http, r.sid, (unsigned long)r.sent);
    if (rides.pendingCount() > 0 && !logger.recording()) {
      wifiBackoffReset("progress", millis(), 0);
      if (startNextUpload("next")) return;
    }
    wifiBackoffReset("queue-empty", millis(), 8000);
    uiLine = String("Azure ") + upPassOk;
    if (ui.page != UiPage::Wifi) requestRadioOff();
    return;
  }
  uiLine = r.status;
  upLastErr = true;  // 0.6.2-circuit.7-rastro: red cloud while rides stay pending
  wifiBackoff(!r.joined ? "join-fail" : r.status, millis());
}

static void serviceUpload(uint32_t nowMs) {
  upTask.serviceIo();
  UploadResult r;
  while (upTask.takeResult(r)) onUploadResult(r);
  const uint8_t ph = upTask.phase();
  if (ph == UploadTask::TLS && nowMs - tlsLastSampleMs >= 5) {  // 0.5.4: TLS low-water
    tlsLastSampleMs = nowMs;
    const uint32_t f8 = heap_caps_get_free_size(MALLOC_CAP_8BIT);
    const uint32_t b8 = heap_caps_get_largest_free_block(MALLOC_CAP_8BIT);
    if (f8 < tlsMinFree8) tlsMinFree8 = f8;
    if (b8 < tlsMinBig8) tlsMinBig8 = b8;
    tlsSamples++;
  }
  if (ph != lastUpPhase) {
    const Mem8 m = mem8();
    gDiag.logf("upload", "PHASE %s t_ms=%lu heap=%u largest=%lu free8=%lu min8=%lu io=%lu",
               UploadTask::phaseName(ph), (unsigned long)(millis() - upStartMs), ESP.getFreeHeap(),
               (unsigned long)m.big, (unsigned long)m.free, (unsigned long)m.min,
               (unsigned long)upTask.ioServed());
    lastUpPhase = ph;
  }
  if (upTask.busy()) return;
  if (pendingRadioOff) {
    pendingRadioOff = false;
    if (WiFi.getMode() != WIFI_OFF && (logger.recording() || ui.page != UiPage::Wifi)) radioOff();
  }
  if (logger.recording() || !upTaskOk) return;
  if (ble.on()) return;                  // 0.6.8: no Wi-Fi while pairing
  if (gUpHold && !wifiScanning) return;  // 0.6.7: UPLOAD HOLD
  if (wifiScanning) {
    const int sr = uploader.scanPoll();
    if (sr == WIFI_SCAN_RUNNING && nowMs - wifiScanT0 < 8000) return;
    wifiScanning = false;
    String seen;
    int rssi = 0;
    const bool vis = sr >= 0 && uploader.enabledSsidSeen(sr, seen, rssi);
    gDiag.logf("wifi", "SCAN done n=%d ms=%lu enabled_seen=%d ssid=%s rssi=%d", sr,
               (unsigned long)(nowMs - wifiScanT0), (int)vis, vis ? seen.c_str() : "-", rssi);
    uploader.scanDone();
    if (vis) {
      if (!startNextUpload("scan")) requestRadioOff();
    } else {
      wifiBackoff(sr < 0 ? "scan-failed" : "ssid-not-seen", millis());
    }
    return;
  }
  if (!uploader.configured() || !uploader.hasPending()) return;
  const bool forced = wantUpload && (int32_t)(nowMs - uploadAfterMs) >= 0;
  const bool timed = nowMs > 4000 && (int32_t)(nowMs - nextWifiTryMs) >= 0;
  if (!forced && !timed) return;
  wantUpload = false;
  if (WiFi.status() == WL_CONNECTED) {  // still associated: skip the scan
    startNextUpload("assoc");
    return;
  }
  circuitRelease("wifi-scan");  // 0.6.0
  wifiScanT0 = nowMs;
  wifiScanning = uploader.startScan();
  gDiag.logf("wifi", "SCAN start ok=%d forced=%d fails=%u pending=%d", (int)wifiScanning,
             (int)forced, (unsigned)wifiFailStreak, rides.pendingCount());
  if (!wifiScanning) wifiBackoff("scan-start-failed", millis());
}

void loop() {
  diagLoopBegin();
  M5.update();
  secMark(S_UPD);
  const uint32_t nowMs = millis();
  // 0.5.2: drain/parse the UART FIRST, then judge the link (maintain) — a slow
  // previous iteration must not look like a dead receiver.
  handleGnssData(nowMs);
  upTask.serviceIo();  // 0.5.3: hand the uploader its next SD chunk (loop owns SD/SPI)
  secMark(S_GNSS);
  gnss.maintain();
  secMark(S_MAINT);
  pps.service();
  if (gnss.needsConfigure()) configureGnss();
  secMark(S_CFG);
  handleImu(nowMs);
  secMark(S_IMU);
  handleBaro(nowMs);
  secMark(S_BARO);
  logger.tick(nowMs);
  // 0.6.2-circuit.7-rastro: SD free space for the home status icon, measured only when idle (boot +10 s,
  // after each recording); f_getfree can take a while on a big card, so never while recording/uploading.
  if (sdFreeDirty && nowMs > 10000 && !logger.recording() && !upTask.busy()) {
    sdFreeDirty = false;
    if (logger.sdOk()) {
      const uint32_t t0 = millis();
      const uint64_t tot = SD.totalBytes(), used = SD.usedBytes();
      sdFreeMb = tot > used ? (int32_t)((tot - used) >> 20) : 0;
      gDiag.logf("sd", "FREE mb=%ld total_mb=%lu ms=%lu", (long)sdFreeMb, (unsigned long)(tot >> 20),
                 (unsigned long)(millis() - t0));
    } else sdFreeMb = -1;
  }
  secMark(S_TICK);
  anchorAutomation(nowMs);
  autoTick(nowMs);  // 0.6.3-auto
  secMark(S_AUTO);

  if (logger.recording()) {
    wantUpload = false;
    cancelUpload("rec");
    if (wifiScanning) {
      WiFi.scanDelete();
      wifiScanning = false;
    }
    if (WiFi.getMode() != WIFI_OFF && !upTask.busy()) radioOff();
  }

  // Anchor: when the screen is dimmed the first press only wakes it; the
  // click/hold that follows on release is swallowed (or expires after 2 s).
  static bool wakeSwallow = false;
  static uint32_t wakeAtMs = 0;
  const bool anyBtn = M5.BtnA.wasPressed() || M5.BtnB.wasPressed() || M5.BtnC.wasPressed();
  if (anyBtn) {
    if (dimmed) {  // 0.6.3-auto: rider standby dim too: first press only wakes
      wakeSwallow = true;
      wakeAtMs = nowMs;
      dimmed = false;
      M5.Display.setBrightness(255);
      if (!role.anchor()) gDiag.logf("auto", "DIM off why=button (press swallowed)");
    }
    lastInputMs = nowMs;
    cancelUpload("button");  // 0.5.3: any press cancels a running upload (< 1 s)
  }
  const bool anyRelease = M5.BtnA.wasClicked() || M5.BtnB.wasClicked() ||
                          M5.BtnC.wasClicked() || M5.BtnC.wasHold();
  bool swallow = false;
  if (wakeSwallow) {
    if (anyRelease) {
      swallow = true;
      wakeSwallow = false;
    } else if (nowMs - wakeAtMs > 2000) {
      wakeSwallow = false;
    }
  }
  if (anyBtn || anyRelease) {
    gDiag.logf("btn", "%s A=%d/%d B=%d/%d C=%d/%d Chold=%d page=%s menu=%d rec=%d dimmed=%d "
               "wakeSwallow=%d swallow=%d loop_gap_ms=%lu",
               anyRelease ? "RELEASE" : "PRESS", (int)M5.BtnA.wasPressed(),
               (int)M5.BtnA.wasClicked(), (int)M5.BtnB.wasPressed(), (int)M5.BtnB.wasClicked(),
               (int)M5.BtnC.wasPressed(), (int)M5.BtnC.wasClicked(), (int)M5.BtnC.wasHold(),
               pageName(), (int)ui.menuIdx, (int)logger.recording(), (int)dimmed,
               (int)wakeSwallow, (int)swallow,
               (unsigned long)(prevLoopT0 ? loopT0 - prevLoopT0 : 0));
  }

  // Buttons: Home A=REC B=MENU C=SEND/MARK (anchor: C=PAGE) · Menu A=UP B=OK C=DOWN
  if (swallow) {
    // consume
  } else if (ui.page == UiPage::About) {
    if (M5.BtnB.wasClicked()) ui.page = UiPage::Home;
  } else if (ui.page == UiPage::Wifi) {
    if (M5.BtnB.wasClicked()) {
      requestRadioOff();
      ui.page = UiPage::Menu;
    }
    if (M5.BtnA.wasClicked()) tryWifiNow();
    if (M5.BtnC.wasClicked() && !role.anchor() && !upTask.busy()) {
      uiLine = "scan…";
      paint(gnss.snapshot());
      const int n = uploader.dumpScan();
      uiLine = String("scan ") + n;
      paint(gnss.snapshot());
      tryWifiNow();
    }
  } else if (ui.page == UiPage::Rides) {
    const int vis = ui.rideCount > 5 ? 5 : ui.rideCount;
    if (M5.BtnA.wasClicked() && vis > 0) ui.rideSel = (ui.rideSel + vis - 1) % vis;
    if (M5.BtnC.wasClicked() && vis > 0) ui.rideSel = (ui.rideSel + 1) % vis;
    if (M5.BtnB.wasClicked()) ui.page = UiPage::Menu;
  } else if (ui.page == UiPage::Menu) {
    if (M5.BtnA.wasClicked()) ui.menuIdx = (ui.menuIdx + kMenuItems - 1) % kMenuItems;  // 6 items
    if (M5.BtnC.wasClicked()) ui.menuIdx = (ui.menuIdx + 1) % kMenuItems;
    if (M5.BtnB.wasClicked()) {
      switch (ui.menuIdx) {
        case 0:
          ui.page = UiPage::Home;
          if (!logger.recording()) {
            userStopped = false;
            startRec("menu");
          } else {
            userStopped = true;
            stopRec();
          }
          break;
        case 1:
          ui.page = UiPage::Wifi;
          if (!logger.recording()) tryWifiNow();
          else uiLine = "Stop first";
          break;
        case 2:
          ui.page = UiPage::Rides;
          ui.rideSel = 0;
          break;
        case 3:
          circMenuOpen();  // 0.6.7: list when > 1 circuit (uiLine says why on failure)
          break;
        case 4:
          bleEnter("menu");  // 0.6.8: EMPAREJAR (uiLine says why if refused)
          break;
        case 5:
          ui.page = UiPage::About;
          break;
        default:
          ui.page = UiPage::Home;
          break;
      }
    }
  } else if (ui.page == UiPage::BlePair) {  // 0.6.8: B = SALIR
    if (M5.BtnB.wasClicked()) bleExit("button");
  } else if (ui.page == UiPage::CircuitList) {  // 0.6.7: A up, C down, B choose (AUTOMATICO = detection)
    if (M5.BtnA.wasClicked() && ui.circN > 0) ui.circSel = (ui.circSel + ui.circN - 1) % ui.circN;
    if (M5.BtnC.wasClicked() && ui.circN > 0) ui.circSel = (ui.circSel + 1) % ui.circN;
    if (M5.BtnB.wasClicked()) {
      const int i = gListIdx[ui.circSel < 0 ? 0 : (ui.circSel > 4 ? 4 : ui.circSel)];
      if (i < 0) {
        circSelectAuto("menu");
        uiLine = "Circuito: automatico";
        ui.page = UiPage::Home;
      } else {
        circSelectManual(i, "menu");
        if (!circuitOpen("menu-list")) ui.page = UiPage::Home;
      }
    }
  } else if (ui.page == UiPage::Trail) {  // 0.6.9: A rec/stop, B speedometer (home), C MARK / hold COLOC (as home)
    if (M5.BtnA.wasClicked()) {
      if (!logger.recording()) {
        userStopped = false;
        startRec("button-trail");
      } else {
        userStopped = true;
        stopRec();  // closes the trail page
      }
    }
    if (M5.BtnB.wasClicked()) trailClose("button-speed");
    if (M5.BtnC.wasHold() && logger.recording()) {
      coloc = !coloc;
      mark(coloc ? "coloc_start" : "coloc_end", 0, "button");
      uiLine = coloc ? "COLOC: junto al ancla" : "COLOC fin";
    } else if (M5.BtnC.wasClicked() && logger.recording()) {
      mark("cp", ++markNo, "button");
      uiLine = String("MARK ") + markNo;
    }
  } else if (ui.page == UiPage::Circuit) {  // 0.6.0: A rec/stop (as Home), B exit, C cycles views
    if (M5.BtnA.wasClicked()) {
      if (!logger.recording()) {
        userStopped = false;
        startRec("button-circuit");
      } else {
        userStopped = true;
        stopRec();
      }
      if (ui.page == UiPage::Circuit) cview.drawStatic(logger.recording());
    }
    if (M5.BtnB.wasClicked()) circuitClose("button");
    if (M5.BtnC.wasHold() && cview.active()) viewFollow(!cview.following(), "button-holdC");  // 0.6.6
    if (M5.BtnC.wasClicked() && cview.active()) {  // 0.6.1: Map -> S1 .. Sn -> table -> Map
      cview.nextMode();
      cview.drawStatic(logger.recording());
      gDiag.logf("circuit", "MODE %s elev=%d", cview.modeName(), (int)cview.elevOk());
      viewRemember();  // 0.6.7
    }
  } else {
    if (M5.BtnA.wasClicked()) {
      if (!logger.recording()) {
        userStopped = false;
        startRec("button");
      } else {
        userStopped = true;
        stopRec();
      }
    }
    if (M5.BtnB.wasClicked()) {
      ui.page = UiPage::Menu;
      ui.menuIdx = 0;
    }
    if (M5.BtnB.wasHold() && logger.recording() && !role.anchor()) trailOpen("button-holdB");  // 0.6.9: back to the trail
    if (role.anchor()) {
      if (M5.BtnC.wasClicked()) ancUi.page = (ancUi.page + 1) % 2;
    } else {
      if (M5.BtnC.wasHold() && logger.recording()) {
        coloc = !coloc;
        mark(coloc ? "coloc_start" : "coloc_end", 0, "button");
        uiLine = coloc ? "COLOC: junto al ancla" : "COLOC fin";
      } else if (M5.BtnC.wasClicked()) {
        if (logger.recording()) {
          mark("cp", ++markNo, "button");
          uiLine = String("MARK ") + markNo;
        } else {
          wantUpload = true;
          uploadAfterMs = nowMs;
        }
      }
    }
  }

  if (M5.BtnA.wasClicked() || M5.BtnB.wasClicked() || M5.BtnC.wasClicked() ||
      M5.BtnC.wasHold()) {
    paint(gnss.snapshot());
  }
  secMark(S_BTN);

  circAutoOpenService(nowMs);  // 0.6.7-autocircuit
  trailService(nowMs);         // 0.6.9-trail
  bleService(nowMs);           // 0.6.8-ble
  circScanService();           // 0.6.7: incremental circuit directory scan
  if (rides.recovering() && !logger.recording() && !upTask.busy()) rides.recoverStep(5);  // 0.6.7: ~5 ms/loop
  if (!role.anchor()) serviceUpload(nowMs);
  // 0.6.0 safety net: the circuit never holds heap while the radio/uploader is in use.
  if ((crt || cview.active()) && (upTask.busy() || wifiScanning || WiFi.getMode() != WIFI_OFF))
    circuitRelease("wifi-active");
  secMark(S_UP);

  {  // 0.6.5-simpos: non-blocking line assembly (10 Hz P lines must never stall the loop)
    static String serLine;
    int budget = 2048;
    while (Serial.available() && budget-- > 0) {
      const char ch = (char)Serial.read();
      if (ch == '\n') {
        serLine.trim();
        handleSerialLine(serLine);
        serLine = "";
      } else if (serLine.length() < 300) {
        serLine += ch;
      }
    }
  }
  secMark(S_SER);

  // 0.6.6-follow: render on every new fix (10 Hz) or at least every 300 ms; header included.
  if (ui.page == UiPage::Circuit && cview.following()) {
    static double folT = -1;
    static uint32_t folMs = 0, folLogMs = 0;
    if ((cfix.valid && cfix.tS != folT) || nowMs - folMs >= 300) {
      folT = cfix.tS;
      folMs = nowMs;
      circuitPaint();
    }
    if (nowMs - folLogMs >= 10000) {
      folLogMs = nowMs;
      const Mem8 m = mem8();
      gDiag.logf("circuit", "FOLLOW fps=%.1f render_ms=%.1f max_ms=%.1f band=%d zoom=%.0f head=%.0f live=%d "
                 "free8=%lu big8=%lu min8=%lu", cview.followFps(), cview.followMsAvg(), cview.followMsMax(),
                 cview.followBand(), cview.followZoom(), cview.followHead(), (int)cview.followHeadLive(),
                 (unsigned long)m.free, (unsigned long)m.big, (unsigned long)m.min);
    }
  }
  uint32_t uiPeriod = 1000 / HEALTH_UI_HZ;
  if (role.anchor()) uiPeriod = dimmed ? 2000 : 500;
  else if (dimmed) uiPeriod = 1000;  // 0.6.3-auto: standby dim -> 1 Hz redraw
  if (nowMs - lastUiMs >= uiPeriod) {
    lastUiMs = nowMs;
    paint(gnss.snapshot());
  }
  if (nowMs - lastBeatMs >= 60000) {
    lastBeatMs = nowMs;
    const Mem8 m = mem8();
    gLog.logf(LogLvl::Info, "beat",
              "role=%s rec=%d n=%lu pending=%d wifi=%d heap=%u free8=%lu big8=%lu min8=%lu",
              role.roleName(), (int)logger.recording(), (unsigned long)anc.n(),
              rides.pendingCount(), (int)(WiFi.status() == WL_CONNECTED), ESP.getFreeHeap(),
              (unsigned long)m.free, (unsigned long)m.big, (unsigned long)m.min);
  }
  if (logger.recording() && nowMs - lastQualityMs >= 10000) {
    lastQualityMs = nowMs;
    logger.logQuality("ubx_ok", gnss.ubxOk());
    logger.logQuality("ubx_bad", gnss.ubxBad());
    logger.logQuality("pps", pps.count());
    logger.logQuality("pps_glitch", pps.glitches());
    logger.logQuality("baro_err", baro.errors());
    logger.logQuality("heap", ESP.getFreeHeap());
    logger.logQuality("bat", (uint32_t)M5.Power.getBatteryLevel());
  }
  if (nowMs - lastLogMs >= (1000 / HEALTH_LOG_HZ)) {
    lastLogMs = nowMs;
    const GnssFix st = gnss.snapshot();
    Serial.printf("gnss %s hz=%u uart=%lu fix=%d sats=%d pps=%lu(%s) chars=%lu bad=%lu ubx=%lu/%lu cfg=%s\n",
                  gnss.linkTag(), (unsigned)st.hz, (unsigned long)st.bytes, (int)st.valid, st.sats,
                  (unsigned long)pps.count(), pps.state(), (unsigned long)st.chars,
                  (unsigned long)gnss.gps().failedChecksum(), (unsigned long)gnss.ubxOk(),
                  (unsigned long)gnss.ubxBad(), gnss.cfgStatus());
    if (st.valid) {
      Serial.printf("FIX,%lu,%.7f,%.7f,%.2f,%.2f,%.1f,%d,%.2f\n",
                    (unsigned long)st.utcMs, st.lat, st.lng, st.alt,
                    st.speedMps >= 0 ? st.speedMps : 0.0, st.heading, st.sats,
                    st.hdop);
    }
    if (role.anchor() && (nowMs / 1000) % 5 == 0) {
      const char* why = "";
      const bool rdy = anc.ready(nowMs, &why);
      const Enu sd = anc.stdev();
      Serial.printf("anchor rec=%d n=%lu std=%.2f/%.2f/%.2f err=%+.2f/%+.2f/%+.2f ready=%d %s baro=%.1fPa imu=%s\n",
                    (int)logger.recording(), (unsigned long)anc.n(), sd.e, sd.n, sd.u,
                    anc.lastD().e, anc.lastD().n, anc.lastD().u, (int)rdy, why,
                    haveBaro ? lastBaro.pa : 0.0,
                    !anc.imuSane() ? "??" : (anc.disturbed(nowMs) ? "BUMP" : "still"));
    }
  }
  secMark(S_UI);
  diagHealth(nowMs);
  gDiag.service(nowMs, logger.sdOk());
  secMark(S_DIAG);
  diagLoopEnd(nowMs);
}
