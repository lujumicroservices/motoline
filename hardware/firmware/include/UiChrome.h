#pragma once

#include <cstring>
#include <M5Unified.h>
#include "BrandIcon.h"
#include "HardwareConfig.h"

namespace riderlab {

// 0.6.2-circuit.6: dark is the only theme (Claro, TEMA menu item, THEME toggle and NVS key removed).
static constexpr uint16_t C_BG = 0x0000;
static constexpr uint16_t C_FG = 0xFFFF;
static constexpr uint16_t C_ORANGE = 0xF9C0;  // ~#FF4B00
static constexpr uint16_t C_TEAL = 0x07F4;
static constexpr uint16_t C_MUTED = 0xAD55;
static constexpr uint16_t C_REC = 0xF800;
static constexpr uint16_t C_OK = 0x07E0;  // clear green — good / locked / saved
static constexpr uint16_t C_WARN = 0xF9C0;
static constexpr uint16_t C_DIM = 0x4208;

inline uint16_t toneOk(bool ok) { return ok ? C_OK : C_WARN; }

inline uint16_t toneStatus(const char* t) {
  if (!t || !t[0]) return C_MUTED;
  if (strstr(t, "fail") || strstr(t, "Fail") || strstr(t, "missing") ||
      strstr(t, "Stop first") || strstr(t, "SIN") || strstr(t, "no wifi")) {
    return C_WARN;
  }
  return C_OK;
}

static constexpr int kMenuItems = 7;  // 0.6.8-ble: + EMPAREJAR (4), ABOUT 5, BACK 6
enum class UiPage { Home, Menu, About, Wifi, Rides, Circuit, CircuitList, BlePair, Trail };  // 0.6.9: Trail  // 0.6.0: Circuit drawn by CircuitView

struct RideRow {
  char label[28] = {};
  bool cloud = false;
  bool ok = false;
};

// Anchor screen: main formats the lines, UiChrome only paints them.
struct AnchorUi {
  static constexpr int kLines = 11;
  char state[30] = {};
  uint16_t stateColor = 0;
  char lines[kLines][54] = {};
  uint16_t colors[kLines] = {};
  int page = 0;  // 0 = position, 1 = quality
};

struct UiState {
  UiPage page = UiPage::Home;
  bool anchor = false;
  AnchorUi* anc = nullptr;
  bool colocOn = false;
  int menuIdx = 0;
  int rideSel = 0;
  int rideCount = 0;
  RideRow rides[5];
  bool recording = false;
  bool sdOk = false;
  bool imuOk = false;
  bool baroOk = false;
  bool gnssLock = false;
  bool wifiCfg = false;
  bool wifiOn = false;
  bool fix = false;
  int sats = 0;
  int gnssHz = 0;
  int bat = 0;
  int wifiRssi = 0;
  float speedKmh = 0;
  float lat = 0;
  float lng = 0;
  char wifiSsid[24] = {};
  char wifiIp[18] = {};
  const char* status = "";
  const char* gnssTag = "";
  const char* wifiLine = "";
  // 0.6.2-circuit.7-rastro: home status bar inputs
  uint8_t gnssFixType = 0;   // UBX fixType (0 = unknown/NMEA, 2 = 2D, 3 = 3D)
  float gnssAccM = -1;       // hAcc (m), -1 unknown
  int32_t sdFreeMb = -1;     // -1 = not measured yet
  int pending = 0;           // rides waiting for upload
  bool upBusy = false;       // upload job running
  bool upErr = false;        // last upload job failed (cleared on success)
  bool upTaskOk = true;      // upload task started at boot
  bool charging = false;
  // 0.6.3-auto (merged in 0.6.4-consolidated)
  char autoTag[28] = {};       // AUTO ARMADO / CANDIDATO / GRABANDO AUTO ...
  uint16_t autoColor = 0xAD55;
  char autoShort[8] = {};      // circuit header: ARMADO / CAND / AUTO / MAN / ESPERA / OFF
  uint8_t autoSt = 0;          // 0 OFF 1 ARMED 2 CAND 3 REC_AUTO 4 REC_MANUAL 5 INHIBIT(ESPERA)
  // 0.6.7-autocircuit
  const char* toast = "";      // ~3 s banner on Home ("8 Horas Zapopan detectado"), "" = none
  int circN = 0, circSel = 0;  // circuit list rows (<= 4 circuits + AUTOMATICO)
  char circName[5][22] = {};
  char circInfo[5][24] = {};
  // 0.6.8-ble pairing page
  char bleName[20] = {};
  char blePin[8] = {};
  char bleLine[44] = {};
  int bleLeftS = 0;
  bool bleConn = false, bleAuthed = false;
};

// ---- 0.6.2-circuit.7-rastro: home status bar (icons right of the brand badge) ----------------------
// Each metric -> level; colour green/yellow/red (grey = unknown / not applicable). Thresholds:
//   GNSS  green: fix valid, 3D (or type unknown), hAcc <= 2.5 m, sats >= 12
//         yellow: fix valid but not green (2D, hAcc 2.5..8 m, sats < 12)
//         red: no fix / link not locked / hAcc > 8 m (fix rejected by the lap timer)
//   SD    green: mounted, free > 500 MB (or not measured yet) | yellow: free <= 500 MB | red: not mounted
//   BAT   green > 50 % | yellow 20..50 % | red < 20 % | grey unknown; bolt when charging
//   NUBE  green: nothing pending | yellow: rides pending or upload running |
//         red: upload task failed at boot, last upload failed with rides still pending, or rides pending
//         and no Wi-Fi/Azure configured
//   IMU / BARO  green: ready | red: failed
//   REC   (0.6.4: auto-session state) red dot + "A" = recording auto, red dot + "M" = recording manual,
//         green ring = ARMED (waiting for speed), yellow dot = CANDIDATE (>15 km/h, confirming 3 s),
//         yellow ring = ESPERA (after a manual stop, until < 7 km/h), grey ring = AUTO OFF / idle
enum class Lvl : uint8_t { Grey, Green, Yellow, Red };
static constexpr uint16_t C_LV_YEL = 0xFFE0, C_LV_RED = 0xF800, C_LV_GRY = 0x6B4D;
inline uint16_t lvlColor(Lvl l) {
  return l == Lvl::Green ? C_OK : (l == Lvl::Yellow ? C_LV_YEL : (l == Lvl::Red ? C_LV_RED : C_LV_GRY));
}
inline Lvl lvlGnss(const UiState& s) {
  if (!s.fix || (s.gnssAccM > 8.f)) return Lvl::Red;
  const bool d3 = s.gnssFixType >= 3 || s.gnssFixType == 0;
  if (d3 && s.gnssAccM > 0 && s.gnssAccM <= 2.5f && s.sats >= 12) return Lvl::Green;
  return Lvl::Yellow;
}
inline Lvl lvlSd(const UiState& s) {
  if (!s.sdOk) return Lvl::Red;
  return (s.sdFreeMb >= 0 && s.sdFreeMb <= 500) ? Lvl::Yellow : Lvl::Green;
}
inline Lvl lvlBat(const UiState& s) {
  if (s.bat < 0 || s.bat > 100) return Lvl::Grey;
  return s.bat > 50 ? Lvl::Green : (s.bat >= 20 ? Lvl::Yellow : Lvl::Red);
}
inline Lvl lvlUp(const UiState& s) {
  if (!s.upTaskOk) return Lvl::Red;
  if (s.pending > 0 && (s.upErr || !s.wifiCfg) && !s.upBusy) return Lvl::Red;
  if (s.upBusy || s.pending > 0) return Lvl::Yellow;
  return Lvl::Green;
}

// 0.6.2-circuit.6: icon drawn as-is on the black field (no Claro badge corners).
inline void drawBadge(M5GFX& d, int x, int y, bool big) {
  d.setSwapBytes(true);
  if (big) d.pushImage(x, y, kIconW, kIconW, kIcon);
  else d.pushImage(x, y, kIconSmW, kIconSmW, kIconSm);
}

inline void drawWordmark(M5GFX& d, int cx, int y, float scale) {
  const int ts = scale >= 1.4f ? 3 : 2;
  d.setTextSize(ts);
  d.setTextDatum(lgfx::textdatum_t::top_left);
  const char* a = "RIDER";
  const char* b = "LAB";
  const int aw = d.textWidth(a);
  const int bw = d.textWidth(b);
  const int gap = 2;
  const int x0 = cx - (aw + gap + bw) / 2;
  d.setTextColor(C_FG, C_BG);
  d.drawString(a, x0, y);
  d.setTextColor(C_ORANGE, C_BG);
  d.drawString(b, x0 + aw + gap, y);
  const int barY = y + d.fontHeight() + 3;
  const int barW = aw - 4;
  for (int i = 0; i < barW; ++i) {
    const float t = barW <= 1 ? 0 : (float)i / (float)(barW - 1);
    const int r = (int)(255 - t * 255);
    const int g = (int)(75 + t * 145);
    const int bl = (int)(t * 180);
    const uint16_t c = ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (bl >> 3);
    d.fillRect(x0 + i, barY, 1, 3, c);
  }
}

inline void drawButtonBar(M5GFX& d, const char* a, const char* b, const char* c) {
  const int y = 212;
  d.fillRect(0, y, 320, 28, C_BG);
  d.drawFastHLine(0, y, 320, C_ORANGE);
  const int xs[3] = {0, 107, 214};
  const char* labels[3] = {a, b, c};
  d.setTextSize(1);
  d.setTextDatum(lgfx::textdatum_t::middle_center);
  for (int i = 0; i < 3; ++i) {
    const int x = xs[i];
    d.fillRect(x + 4, y + 4, 98, 20, C_FG);
    d.setTextColor(C_BG, C_FG);
    d.drawString(labels[i], x + 53, y + 14);
  }
}

inline void playBootSplash() {
  auto& d = M5.Display;
  d.setSwapBytes(true);
  d.fillScreen(C_BG);

  M5Canvas spr(&d);
  if (spr.createSprite(kIconW, kIconH)) {
    spr.setSwapBytes(true);
    spr.pushImage(0, 0, kIconW, kIconH, kIcon);
    for (int i = 0; i <= 10; ++i) {
      const float z = 0.12f + 0.88f * (i / 10.0f);
      d.fillScreen(C_BG);
      spr.pushRotateZoom(160, 100, 0, z, z);
      wdtFeed();
      delay(28);
    }
    spr.deleteSprite();
    drawBadge(d, 160 - kIconW / 2, 52, true);  // final frame
  } else {
    drawBadge(d, 160 - kIconW / 2, 52, true);
    delay(200);
  }

  drawWordmark(d, 160, 168, 1.4f);
  d.setTextSize(1);
  d.setTextDatum(lgfx::textdatum_t::top_center);
  d.setTextColor(C_MUTED, C_BG);
  d.drawString("LOGGER", 160, 208);
  delay(350);
}

inline void drawBootStatus(const char* line) {
  auto& d = M5.Display;
  d.fillRect(0, 220, 320, 20, C_BG);
  d.setTextSize(1);
  d.setTextDatum(lgfx::textdatum_t::bottom_center);
  d.setTextColor(C_MUTED, C_BG);
  d.drawString(line, 160, 236);
}

inline void drawLiveBat(const UiState& s) {
  auto& d = M5.Display;
  d.fillRect(250, 4, 70, 14, C_BG);
  d.setTextSize(1);
  d.setTextDatum(lgfx::textdatum_t::top_right);
  d.setTextColor(toneOk(s.bat >= 20), C_BG);
  char bat[16];
  snprintf(bat, sizeof(bat), "%d%%", s.bat);
  d.drawString(bat, 314, 8);
}

// icon cell: 20 x 20 at (x, y). Primitives only, no bitmaps, no heap.
inline void iconGnss(M5GFX& d, int x, int y, uint16_t c) {  // crosshair / fix target
  const int cx = x + 10, cy = y + 10;
  d.drawCircle(cx, cy, 6, c); d.drawCircle(cx, cy, 5, c);
  d.fillCircle(cx, cy, 2, c);
  d.fillRect(cx - 1, y, 2, 4, c); d.fillRect(cx - 1, y + 16, 2, 4, c);
  d.fillRect(x, cy - 1, 4, 2, c); d.fillRect(x + 16, cy - 1, 4, 2, c);
}
inline void iconSd(M5GFX& d, int x, int y, uint16_t c) {  // SD card, clipped corner, contacts
  d.fillRoundRect(x + 4, y + 1, 13, 18, 2, c);
  d.fillTriangle(x + 4, y + 1, x + 9, y + 1, x + 4, y + 6, C_BG);
  for (int i = 0; i < 3; ++i) d.fillRect(x + 8 + 3 * i, y + 3, 2, 4, C_BG);
}
inline void iconBat(M5GFX& d, int x, int y, uint16_t c, int pct, bool chg) {  // outline + level fill
  d.drawRect(x, y + 5, 17, 11, c); d.drawRect(x + 1, y + 6, 15, 9, c);
  d.fillRect(x + 17, y + 8, 3, 5, c);
  const int w = pct < 0 ? 0 : (pct >= 100 ? 11 : (pct * 11 + 50) / 100);
  if (w > 0) d.fillRect(x + 3, y + 8, w, 5, c);
  if (chg) {  // bolt, black with the level colour around it
    d.fillTriangle(x + 9, y + 6, x + 5, y + 11, x + 9, y + 11, C_BG);
    d.fillTriangle(x + 8, y + 10, x + 12, y + 10, x + 8, y + 15, C_BG);
  }
}
inline void iconCloud(M5GFX& d, int x, int y, uint16_t c, bool busy) {  // cloud + up arrow cut-out
  d.fillCircle(x + 6, y + 12, 4, c); d.fillCircle(x + 11, y + 9, 6, c); d.fillCircle(x + 15, y + 12, 4, c);
  d.fillRect(x + 6, y + 12, 10, 5, c);
  d.fillTriangle(x + 11, y + 6, x + 7, y + 11, x + 15, y + 11, C_BG);
  d.fillRect(x + 10, y + 11, 3, busy ? 6 : 4, C_BG);
}
inline void iconImu(M5GFX& d, int x, int y, uint16_t c) {  // three axes
  const int ox = x + 7, oy = y + 13;
  d.fillRect(ox - 1, y + 3, 2, oy - y - 2, c); d.fillTriangle(ox, y + 1, ox - 3, y + 5, ox + 3, y + 5, c);       // z
  d.fillRect(ox, oy - 1, 11, 2, c); d.fillTriangle(x + 19, oy, x + 15, oy - 3, x + 15, oy + 3, c);              // x
  d.drawLine(ox, oy, x + 2, y + 18, c); d.drawLine(ox + 1, oy, x + 3, y + 18, c);                             // y
  d.fillCircle(x + 2, y + 18, 2, c);
}
inline void iconBaro(M5GFX& d, int x, int y, uint16_t c) {  // gauge
  d.drawCircle(x + 10, y + 10, 8, c); d.drawCircle(x + 10, y + 10, 7, c);
  d.drawLine(x + 10, y + 10, x + 14, y + 5, c); d.drawLine(x + 10, y + 11, x + 15, y + 6, c);
  d.fillCircle(x + 10, y + 10, 2, c);
  d.fillRect(x + 6, y + 15, 9, 2, c);
}
inline void iconRec(M5GFX& d, int x, int y, bool rec, uint8_t ast) {
  const int cx = x + 10, cy = y + 10;
  if (rec) {
    d.fillCircle(cx, cy, 8, C_REC);
    if (ast == 3 || ast == 4) {
      d.setFont(&fonts::Font0); d.setTextSize(1); d.setTextDatum(lgfx::textdatum_t::middle_center);
      d.setTextColor(C_FG, C_REC);
      d.drawString(ast == 3 ? "A" : "M", cx + 1, cy + 1);
    }
    return;
  }
  const uint16_t c = ast == 1 ? C_OK : ((ast == 2 || ast == 5) ? C_LV_YEL : C_LV_GRY);
  if (ast == 2) d.fillCircle(cx, cy, 7, c);
  else { d.drawCircle(cx, cy, 7, c); d.drawCircle(cx, cy, 6, c); }
}
static constexpr int kStatX0 = 56, kStatY = 13, kStatPitch = 27;
// Redraws only the icons whose state changed (force: all). ~0.3 ms per icon.
inline void drawHomeStatus(const UiState& s, bool force) {
  auto& d = M5.Display;
  const uint8_t st[7] = {(uint8_t)lvlGnss(s), (uint8_t)lvlSd(s),
                         (uint8_t)((uint8_t)lvlBat(s) | ((s.bat < 0 ? 0 : (s.bat + 5) / 10) << 2) | (s.charging ? 0x80 : 0)),
                         (uint8_t)((uint8_t)lvlUp(s) | (s.upBusy ? 4 : 0)), (uint8_t)(s.imuOk ? 1 : 3),
                         (uint8_t)(s.baroOk ? 1 : 3), (uint8_t)((s.recording ? 0x80 : 0) | s.autoSt)};
  static uint8_t last[7] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
  for (int i = 0; i < 7; ++i) {
    if (!force && st[i] == last[i]) continue;
    last[i] = st[i];
    const int x = kStatX0 + i * kStatPitch;
    d.fillRect(x, kStatY, 20, 20, C_BG);
    switch (i) {
      case 0: iconGnss(d, x, kStatY, lvlColor(lvlGnss(s))); break;
      case 1: iconSd(d, x, kStatY, lvlColor(lvlSd(s))); break;
      case 2: iconBat(d, x, kStatY, lvlColor(lvlBat(s)), s.bat, s.charging); break;
      case 3: iconCloud(d, x, kStatY, lvlColor(lvlUp(s)), s.upBusy); break;
      case 4: iconImu(d, x, kStatY, lvlColor(s.imuOk ? Lvl::Green : Lvl::Red)); break;
      case 5: iconBaro(d, x, kStatY, lvlColor(s.baroOk ? Lvl::Green : Lvl::Red)); break;
      default: iconRec(d, x, kStatY, s.recording, s.autoSt); break;
    }
  }
}

// 0.6.2-circuit.7-rastro: home body = speed only (big) + one transient action line (6 s), redrawn on change.
inline void drawHomeLive(const UiState& s, bool force = false) {
  auto& d = M5.Display;
  d.setSwapBytes(true);
  d.startWrite();
  drawHomeStatus(s, force);
  {  // 0.6.7-autocircuit: circuit-detected banner (y 43..71), drawn/cleared only on change
    static char lastToast[40] = "";
    const char* tz = s.toast ? s.toast : "";
    if (force || strncmp(tz, lastToast, sizeof(lastToast) - 1) != 0) {
      strncpy(lastToast, tz, sizeof(lastToast) - 1);
      lastToast[sizeof(lastToast) - 1] = 0;
      d.fillRect(0, 43, 320, 28, C_BG);
      if (tz[0]) {
        d.fillRoundRect(6, 44, 308, 26, 5, C_ORANGE);
        d.setTextDatum(lgfx::textdatum_t::middle_center);
        d.setTextSize(1);
        d.setFont(&fonts::FreeSansBold9pt7b);
        d.setTextColor(C_FG, C_ORANGE);
        d.drawString(tz, 160, 57);
        d.setFont(&fonts::Font0);
      }
    }
  }
  static char lastSpd[8] = "";
  char spd[8];
  if (s.fix) snprintf(spd, sizeof(spd), "%.0f", s.speedKmh);
  else snprintf(spd, sizeof(spd), "--");
  if (force || strcmp(spd, lastSpd) != 0) {
    strcpy(lastSpd, spd);
    d.fillRect(10, 72, 300, 72, C_BG);
    d.setTextDatum(lgfx::textdatum_t::middle_center);
    d.setFont(&fonts::Font7);  // 7-segment, 48 px digits
    d.setTextSize(1);
    d.setTextColor(s.fix ? C_FG : C_LV_GRY, C_BG);
    d.drawString(spd, 160, 108);
    d.setFont(&fonts::Font0);
  }
  if (force) {
    d.setTextDatum(lgfx::textdatum_t::middle_center);
    d.setTextSize(1);
    d.setTextColor(C_MUTED, C_BG);
    d.drawString("km/h", 160, 152);
  }
  // 0.6.4: auto-session state line (one line, its own colour), redrawn only when the text changes
  static char lastAuto[28] = "\x01";
  if (force || strcmp(s.autoTag, lastAuto) != 0) {
    strncpy(lastAuto, s.autoTag, sizeof(lastAuto) - 1);
    lastAuto[sizeof(lastAuto) - 1] = 0;
    d.fillRect(0, 160, 320, 18, C_BG);
    if (s.autoTag[0]) {
      d.setTextDatum(lgfx::textdatum_t::middle_center);
      d.setTextSize(1);
      d.setFont(&fonts::Font2);
      d.setTextColor(s.autoColor, C_BG);
      d.drawString(s.autoTag, 160, 168);
      d.setFont(&fonts::Font0);
    }
  }
  // transient action/status line (e.g. "Stopped", "subiendo 2", "Stop first"), cleared after 6 s
  static char lastMsg[40] = "";
  static uint32_t msgAt = 0;
  static bool msgShown = false;
  const char* m = s.status ? s.status : "";
  const uint32_t now = millis();
  if (strncmp(m, lastMsg, sizeof(lastMsg) - 1) != 0) {
    strncpy(lastMsg, m, sizeof(lastMsg) - 1);
    lastMsg[sizeof(lastMsg) - 1] = 0;
    msgAt = now;
    msgShown = false;
    force = true;
  }
  const bool want = lastMsg[0] && (now - msgAt) < 6000;
  if (force || want != msgShown) {
    d.fillRect(0, 180, 320, 24, C_BG);
    if (want) {
      d.setTextDatum(lgfx::textdatum_t::middle_center);
      d.setTextSize(1);
      d.setFont(&fonts::Font2);
      d.setTextColor(toneStatus(lastMsg), C_BG);
      d.drawString(lastMsg, 160, 192);
      d.setFont(&fonts::Font0);
    }
    msgShown = want;
  }
  d.endWrite();
}

inline void drawRoleBadge(const UiState& s) {
  auto& d = M5.Display;
  d.setTextSize(1);
  d.setTextDatum(lgfx::textdatum_t::middle_center);
  if (s.anchor) {
    d.fillRect(246, 22, 70, 18, C_ORANGE);
    d.setTextColor(C_BG, C_ORANGE);
    d.setTextSize(2);
    d.drawString("ANCLA", 281, 31);
  } else {
    d.fillRect(262, 24, 54, 14, C_FG);
    d.setTextColor(C_BG, C_FG);
    d.drawString("RIDER", 289, 31);  // home (rider) draws its own compact chip next to the status bar
  }
}

// 0.6.9b: home status bar (badge, status icons, RIDER chip, rule at y 40) - shared by Home and the Trail page
inline void drawHomeBar(const UiState& s) {
  auto& d = M5.Display;
  d.setSwapBytes(true);
  d.fillRect(0, 0, 320, 42, C_BG);
  drawBadge(d, 8, 6, false);
  d.setTextSize(1);
  d.setTextDatum(lgfx::textdatum_t::middle_center);
  d.fillRoundRect(256, 15, 58, 16, 3, C_FG);
  d.setTextColor(C_BG, C_FG);
  d.drawString("RIDER", 285, 23);
  d.drawFastHLine(56, 40, 258, C_DIM);
  d.startWrite();
  drawHomeStatus(s, true);
  d.endWrite();
}

inline void drawHome(const UiState& s) {
  auto& d = M5.Display;
  d.setSwapBytes(true);
  d.fillScreen(C_BG);
  drawBadge(d, 8, 6, false);
  // 0.6.2-circuit.7-rastro: status icons right of the badge (wordmark stays on splash / About);
  // compact RIDER chip at the right edge, thin orange rule under the header
  d.setTextSize(1);
  d.setTextDatum(lgfx::textdatum_t::middle_center);
  d.fillRoundRect(256, 15, 58, 16, 3, C_FG);
  d.setTextColor(C_BG, C_FG);
  d.drawString("RIDER", 285, 23);
  d.drawFastHLine(56, 40, 258, C_DIM);
  drawButtonBar(d, s.recording ? "STOP" : "REC", "MENU", s.recording ? "MARK" : "SEND");
  drawHomeLive(s, true);
  if (s.colocOn) {
    d.setTextSize(1);
    d.setTextDatum(lgfx::textdatum_t::middle_center);
    d.fillRect(120, 50, 80, 16, C_TEAL);
    d.setTextColor(C_FG, C_TEAL);
    d.drawString("COLOC", 160, 58);
  }
}

// ---------------- ANCHOR ----------------
inline void drawAnchorLive(const UiState& s) {
  if (!s.anc) return;
  auto& d = M5.Display;
  static M5Canvas* spr = nullptr;
  static bool tried = false;
  if (!tried) {
    tried = true;
    spr = new M5Canvas(&d);
    spr->setColorDepth(8);
    if (!spr->createSprite(320, 164)) {
      delete spr;
      spr = nullptr;
    }
  }
  LovyanGFX* g = spr ? (LovyanGFX*)spr : (LovyanGFX*)&d;
  const int oy = spr ? 0 : 46;
  if (spr) spr->fillSprite(C_BG);
  else d.fillRect(0, 46, 320, 164, C_BG);
  const AnchorUi& a = *s.anc;
  g->setTextDatum(lgfx::textdatum_t::top_left);
  g->setTextSize(2);
  g->setTextColor(a.stateColor, C_BG);
  g->drawString(a.state, 6, oy + 2);
  g->setTextSize(1);
  for (int i = 0; i < AnchorUi::kLines; ++i) {
    if (!a.lines[i][0]) continue;
    g->setTextColor(a.colors[i] ? a.colors[i] : C_FG, C_BG);
    g->drawString(a.lines[i], 6, oy + 22 + i * 13);
  }
  if (spr) spr->pushSprite(0, 46);
  drawLiveBat(s);
}

inline void drawAnchorHome(const UiState& s) {
  auto& d = M5.Display;
  d.setSwapBytes(true);
  d.fillScreen(C_BG);
  drawBadge(d, 8, 6, false);
  drawWordmark(d, 150, 8, 1.0f);
  drawRoleBadge(s);
  drawButtonBar(d, s.recording ? "STOP" : "REC", "MENU", "PAGINA");
  drawAnchorLive(s);
}

inline void drawMenu(const UiState& s) {
  auto& d = M5.Display;
  d.fillScreen(C_BG);
  d.setSwapBytes(true);
  drawBadge(d, 8, 6, false);
  drawWordmark(d, 168, 8, 1.0f);

  static const char* items[] = {"RECORD / STOP", "WIFI", "RIDES", "CIRCUITO", "EMPAREJAR", "ABOUT", "BACK"};
  d.setTextSize(2);
  d.setTextDatum(lgfx::textdatum_t::middle_left);
  for (int i = 0; i < kMenuItems; ++i) {  // 0.6.8: 7 items, 24 px pitch
    const int y = 49 + i * 24;
    if (i == s.menuIdx) {
      d.fillRect(8, y - 11, 304, 22, C_ORANGE);
      d.setTextColor(C_FG, C_ORANGE);
    } else {
      d.setTextColor(C_FG, C_BG);
    }
    d.drawString(items[i], 20, y);
  }
  drawButtonBar(d, "UP", "OK", "DOWN");
  drawLiveBat(s);
}

// 0.6.7-autocircuit: Menu > CIRCUITO list, nearest first, big rows (gloves). A up, B choose, C down.
inline void drawCircuitList(const UiState& s) {
  auto& d = M5.Display;
  d.fillScreen(C_BG);
  d.setSwapBytes(true);
  drawBadge(d, 8, 6, false);
  d.setFont(&fonts::Font0);
  d.setTextSize(2);
  d.setTextDatum(lgfx::textdatum_t::middle_left);
  d.setTextColor(C_FG, C_BG);
  d.drawString("CIRCUITO", 120, 22);
  for (int i = 0; i < s.circN && i < 5; ++i) {
    const int y = 62 + i * 32;
    const bool sel = i == s.circSel;
    const uint16_t bg = sel ? C_ORANGE : C_BG;
    if (sel) d.fillRoundRect(6, y - 14, 308, 28, 4, C_ORANGE);
    d.setFont(&fonts::Font0);
    d.setTextSize(2);
    d.setTextDatum(lgfx::textdatum_t::middle_left);
    d.setTextColor(C_FG, bg);
    char nm[14];
    snprintf(nm, sizeof(nm), "%s", s.circName[i]);
    d.drawString(nm, 14, y);
    d.setFont(&fonts::Font2);
    d.setTextSize(1);
    d.setTextDatum(lgfx::textdatum_t::middle_right);
    d.setTextColor(sel ? C_FG : C_MUTED, bg);
    d.drawString(s.circInfo[i], 308, y);
  }
  d.setFont(&fonts::Font0);
  d.setTextSize(1);
  drawButtonBar(d, "ARRIBA", "ELEGIR", "ABAJO");
  drawLiveBat(s);
}

// 0.6.8-ble: pairing page. Live part (PIN, status, countdown) redrawn by drawBleLive.
inline void drawBleLive(const UiState& s, bool force = false) {
  auto& d = M5.Display;
  static char last[96] = "";
  char key[96];
  snprintf(key, sizeof key, "%s|%s|%s|%d|%d|%d", s.bleName, s.blePin, s.bleLine, s.bleLeftS, (int)s.bleConn,
           (int)s.bleAuthed);
  if (!force && strcmp(key, last) == 0) return;
  memcpy(last, key, sizeof last);
  d.startWrite();
  d.fillRect(0, 44, 320, 166, C_BG);
  d.setTextDatum(lgfx::textdatum_t::middle_center);
  d.setFont(&fonts::Font2);
  d.setTextSize(1);
  d.setTextColor(C_MUTED, C_BG);
  d.drawString(s.bleName, 160, 54);
  d.drawString("PIN para la app", 160, 74);
  d.setFont(&fonts::Font7);
  d.setTextColor(s.bleAuthed ? C_OK : C_FG, C_BG);
  d.drawString(s.blePin, 160, 116);
  d.setFont(&fonts::Font2);
  d.setTextColor(toneStatus(s.bleLine), C_BG);
  d.drawString(s.bleLine, 160, 162);
  char t[40];
  snprintf(t, sizeof(t), "%s  %d:%02d", s.bleConn ? (s.bleAuthed ? "APP OK" : "APP CONECTADA") : "ESPERANDO APP",
           s.bleLeftS / 60, s.bleLeftS % 60);
  d.setTextColor(s.bleConn ? C_OK : C_MUTED, C_BG);
  d.drawString(t, 160, 190);
  d.setFont(&fonts::Font0);
  d.endWrite();
}
inline void drawBle(const UiState& s) {
  auto& d = M5.Display;
  d.fillScreen(C_BG);
  d.setSwapBytes(true);
  drawBadge(d, 8, 6, false);
  d.setFont(&fonts::Font0);
  d.setTextSize(2);
  d.setTextDatum(lgfx::textdatum_t::middle_left);
  d.setTextColor(C_FG, C_BG);
  d.drawString("EMPAREJAR", 110, 22);
  drawButtonBar(d, " ", "SALIR", " ");
  drawBleLive(s, true);
}

inline void drawAbout(const UiState& s) {
  auto& d = M5.Display;
  d.fillScreen(C_BG);
  d.setSwapBytes(true);
  drawBadge(d, 160 - kIconW / 2, 16, true);
  drawWordmark(d, 160, 122, 1.4f);
  d.setTextSize(1);
  d.setTextDatum(lgfx::textdatum_t::top_center);
  d.setTextColor(C_MUTED, C_BG);
  d.drawString(FIRMWARE_VERSION, 160, 168);
  d.drawString(s.anchor ? "ROL: ANCLA  (serial ROLE RIDER)" : "A rec  B menu  C send/mark", 160, 186);
  d.setTextColor(toneOk(s.fix || s.gnssLock), C_BG);
  d.drawString(s.gnssTag, 160, 200);
  drawButtonBar(d, " ", "BACK", " ");
}

inline void drawWifi(const UiState& s) {
  auto& d = M5.Display;
  d.fillScreen(C_BG);
  d.setSwapBytes(true);
  drawBadge(d, 8, 6, false);
  drawWordmark(d, 168, 8, 1.0f);
  d.setTextSize(2);
  d.setTextDatum(lgfx::textdatum_t::top_left);
  d.setTextColor(C_FG, C_BG);
  d.drawString("WIFI", 16, 52);
  d.setTextSize(1);
  d.setTextColor(C_MUTED, C_BG);
  d.drawString(s.wifiSsid[0] ? s.wifiSsid : "(sin red guardada)", 16, 86);
  d.setTextColor(toneOk(s.wifiOn), C_BG);
  const char* st = s.wifiOn ? "CONECTADO" : (s.wifiSsid[0] ? "DESCONECTADO" : "SIN RED");
  d.drawString(st, 16, 108);
  if (s.wifiOn) {
    d.setTextColor(C_OK, C_BG);
    char line[40];
    snprintf(line, sizeof(line), "IP %s", s.wifiIp[0] ? s.wifiIp : "-");
    d.drawString(line, 16, 128);
    snprintf(line, sizeof(line), "RSSI %d dBm", s.wifiRssi);
    d.drawString(line, 16, 144);
  }
  const char* wline = s.wifiLine && s.wifiLine[0] ? s.wifiLine : s.status;
  d.setTextColor(toneStatus(wline), C_BG);
  d.drawString(wline, 16, 164);
  d.setTextColor(C_MUTED, C_BG);
  d.drawString("ESP32 solo 2.4 GHz", 16, 180);
  drawLiveBat(s);
  drawButtonBar(d, "CONN", "BACK", "SCAN");
}

inline void drawWifiLive(const UiState& s) {
  auto& d = M5.Display;
  d.startWrite();
  d.fillRect(0, 80, 320, 128, C_BG);
  d.setTextSize(1);
  d.setTextDatum(lgfx::textdatum_t::top_left);
  d.setTextColor(C_MUTED, C_BG);
  d.drawString(s.wifiSsid[0] ? s.wifiSsid : "(sin red guardada)", 16, 86);
  d.setTextColor(toneOk(s.wifiOn), C_BG);
  const char* st = s.wifiOn ? "CONECTADO" : (s.wifiSsid[0] ? "DESCONECTADO" : "SIN RED");
  d.drawString(st, 16, 108);
  if (s.wifiOn) {
    d.setTextColor(C_OK, C_BG);
    char line[40];
    snprintf(line, sizeof(line), "IP %s", s.wifiIp[0] ? s.wifiIp : "-");
    d.drawString(line, 16, 128);
    snprintf(line, sizeof(line), "RSSI %d dBm", s.wifiRssi);
    d.drawString(line, 16, 144);
  }
  const char* wline = s.wifiLine && s.wifiLine[0] ? s.wifiLine : s.status;
  d.setTextColor(toneStatus(wline), C_BG);
  d.drawString(wline, 16, 164);
  d.setTextColor(C_MUTED, C_BG);
  d.drawString("ESP32 solo 2.4 GHz", 16, 180);
  drawLiveBat(s);
  d.endWrite();
}

inline void drawRides(const UiState& s) {
  auto& d = M5.Display;
  d.fillScreen(C_BG);
  d.setSwapBytes(true);
  drawBadge(d, 8, 6, false);
  drawWordmark(d, 168, 8, 1.0f);
  d.setTextSize(1);
  d.setTextDatum(lgfx::textdatum_t::top_left);
  d.setTextColor(C_MUTED, C_BG);
  char head[32];
  snprintf(head, sizeof(head), "RECORRIDOS  %d", s.rideCount);
  d.drawString(head, 16, 50);
  if (s.rideCount == 0) {
    d.setTextColor(C_FG, C_BG);
    d.drawString("Sin historial", 16, 80);
  }
  for (int i = 0; i < 5; ++i) {
    if (i >= s.rideCount) break;
    const int y = 70 + i * 26;
    if (i == s.rideSel) {
      d.fillRect(8, y - 4, 304, 24, C_ORANGE);
      d.setTextColor(C_FG, C_ORANGE);
    } else {
      d.setTextColor(C_FG, C_BG);
    }
    d.drawString(s.rides[i].label, 16, y);
    d.setTextColor(toneOk(s.rides[i].ok), i == s.rideSel ? C_ORANGE : C_BG);
    d.setTextDatum(lgfx::textdatum_t::top_right);
    d.drawString(s.rides[i].cloud ? "CLOUD" : "SD", 304, y);
    d.setTextDatum(lgfx::textdatum_t::top_left);
  }
  drawLiveBat(s);
  drawButtonBar(d, "UP", "BACK", "DOWN");
}

inline void drawRidesLive(const UiState& s) {
  auto& d = M5.Display;
  d.startWrite();
  drawLiveBat(s);
  d.endWrite();
}

inline void drawMenuLive(const UiState& s) {
  auto& d = M5.Display;
  d.startWrite();
  drawLiveBat(s);
  d.endWrite();
}

inline void drawAboutLive(const UiState& s) {
  auto& d = M5.Display;
  d.startWrite();
  d.fillRect(40, 196, 240, 14, C_BG);
  d.setTextSize(1);
  d.setTextDatum(lgfx::textdatum_t::top_center);
  d.setTextColor(toneOk(s.fix || s.gnssLock), C_BG);
  d.drawString(s.gnssTag, 160, 200);
  d.endWrite();
}

inline void drawUi(const UiState& s) {
  static UiPage lastPage = UiPage::Home;
  static int lastMenu = -1;
  static int lastRide = -1;
  static int lastCircSel = -1;  // 0.6.7
  static bool lastRec = false;
  static bool lastWifi = false;
  static bool inited = false;
  const bool chrome = !inited || s.page != lastPage ||
                      (s.page == UiPage::Menu && s.menuIdx != lastMenu) ||
                      (s.page == UiPage::Rides && s.rideSel != lastRide) ||
                      (s.page == UiPage::CircuitList && s.circSel != lastCircSel) ||
                      (s.page == UiPage::Wifi && s.wifiOn != lastWifi) ||
                      (s.page == UiPage::Home && s.recording != lastRec);
  const bool force = false;
  inited = true;
  lastPage = s.page;
  lastMenu = s.menuIdx;
  lastRide = s.rideSel;
  lastCircSel = s.circSel;
  lastRec = s.recording;
  lastWifi = s.wifiOn;
  (void)force;
  if (s.page == UiPage::Circuit) return;  // 0.6.0: main/CircuitView paints it; leaving forces chrome
  if (s.page == UiPage::Trail) return;    // 0.6.9: main (trailPaint) paints it; leaving forces chrome
  if (s.page == UiPage::Menu) {
    if (chrome) drawMenu(s);
    else drawMenuLive(s);
    return;
  }
  if (s.page == UiPage::BlePair) {  // 0.6.8
    if (chrome) drawBle(s);
    else drawBleLive(s);
    return;
  }
  if (s.page == UiPage::CircuitList) {  // 0.6.7
    if (chrome) drawCircuitList(s);
    else drawMenuLive(s);
    return;
  }
  if (s.page == UiPage::About) {
    if (chrome) drawAbout(s);
    else drawAboutLive(s);
    return;
  }
  if (s.page == UiPage::Wifi) {
    if (chrome) drawWifi(s);
    else drawWifiLive(s);
    return;
  }
  if (s.page == UiPage::Rides) {
    if (chrome) drawRides(s);
    else drawRidesLive(s);
    return;
  }
  static bool lastAnchor = false;
  static int lastAncPage = -1;
  static bool lastColoc = false;
  if (s.anchor) {
    const int pg = s.anc ? s.anc->page : 0;
    if (chrome || !lastAnchor || pg != lastAncPage) drawAnchorHome(s);
    else drawAnchorLive(s);
    lastAnchor = true;
    lastAncPage = pg;
    return;
  }
  const bool redo = chrome || lastAnchor || s.colocOn != lastColoc;
  lastAnchor = false;
  lastColoc = s.colocOn;
  if (redo) drawHome(s);
  else drawHomeLive(s);
}

}  // namespace riderlab
