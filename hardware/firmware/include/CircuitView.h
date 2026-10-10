// 0.6.0-circuit: circuit screen for M5Stack Basic v2.7 (ESP32, NO PSRAM). Header-only on purpose:
// included ONLY from main.cpp (UiChrome.h/BrandIcon must not be duplicated in another TU).
//
// 0.6.0-circuit.2: track corridor filled medium grey (0x8410) with a triangle strip between the edges
// (no sprite); edges + gate lines drawn on top in each sector's colour, no fill.
// 0.6.1-circuit: palette S1 red, S2 cyan, S3 green, S4 orange (= sector images); gate labels are
// filled chips (dark text on light colours, never yellow-on-white). Button C cycles
// Map -> S1 -> S2 -> S3 (-> S4) -> Sectors table -> Map. Sector view: that sector fitted to the map
// area (y 34..165), its corridor grey + edges/gates in the sector colour, rest of the track faint,
// centerline tinted by elevation, live dot + trail; elevation profile strip y 166..211 (altitude vs
// distance, min/max, climb/descent, live marker projected on the centerline). Elevation lives in
// flash (CircuitElevation.h, 276 x int16) and is only used when the loaded circuit is the one it was
// built for (anchor within 30 m, length within 3 %).
// Memory: no full-screen sprite (320x240x16 = 150 KB would starve the uploader; TLS needs a 40 000 B
// largest block). Heap while the page is open: header sprite 320x34 @8-bit = 10.9 KB + edge cache
// (~1.1 KB) + trail ring 300 x 6 B = 1.8 KB  =>  ~14 KB (unchanged in 0.6.1; profile cache = 312 B
// .bss). Zero heap when the page is closed. begin() refuses when free8 < 60 KB or largest8 < 40 KB.
// main frees it before ANY Wi-Fi use.
// 0.6.2: (theme) since 0.6.2-circuit.6 dark only for every view (field, header, table, profile strip, outlines); dot erase
// restores direction arrows, gate label chips and the sector-view corner text. Rotation sign verified
// against betaxh/hd/sectores/sector_S*_m5_320x240.png (same CCW convention: no flip).
// 0.6.2-circuit.4: track fill bright orange 0xFC60 (both themes); edges/gates/centerline get a black
// casing so S1 red etc. stay readable on orange; S4 = magenta; direction arrows black.
// 0.6.2-circuit.5: no edge lines at all: the circuit is one thick orange stroke (corridor fill + orange
// edge stroke, wider than the real track). Sectors marked by ONE white line
// beside the stroke, alternating sides S1 outer, S2 inner, S3 outer, S4 inner. Gates, S/F,
// arrows, elevation, coordinates, dot/trail, themes unchanged. +2 B/edge point heap (outward normals).
// 0.6.2-circuit.7-rastro (draft): the speed-coloured trail is replaced by the live track trace ("rastro"):
// the rider's GPS path for the CURRENT LAP, drawn as a 3 px line with a 1 px black casing on top of the
// orange stroke, coloured per new segment by LiveDelta: PURPLE (kPur) = on pace for the sector best
// (or no reference yet: first pass counts as best), YELLOW (kYel) = behind the sector best. Points are
// stored every >= 2 m (or on colour change) in a 720-point ring (4.3 KB heap, was 300 x 6 B = 1.8 KB);
// trace + ticks are cleared at S/F (one full static redraw per lap). Where a sector boundary was
// crossed, a short white tick (black casing) is drawn across the trace (max 8 per lap, .bss).
// Header: live delta chip (+0.42 / -0.18) in the same colour, right of the sector timer.
// Layout: y 0..33 header sprite | y 34..211 map / sector+profile / table | y 212..239 button bar.
#pragma once
#include <M5Unified.h>
#include <esp_heap_caps.h>
#include <new>
#include "UiChrome.h"
#include "CircuitFile.h"
#include "CircuitElevation.h"
#include "LapTimer.h"
#include "LiveDelta.h"

namespace riderlab {

enum class CircuitMode : uint8_t { Map, Sector, Sectors };

struct LiveFix {
  float x = 0, y = 0, kmh = 0;
  double tS = 0;
  bool valid = false;
};

class CircuitView {
 public:
  static constexpr uint32_t kMinFree8 = 60000;   // open only with margin
  static constexpr uint32_t kMinBig8 = 40000;    // == UploadTask::kTlsNeedLargest
  static constexpr int W = 320, HDR = 34, Y1 = 212, MARGIN = 8, TRAIL_MAX = 720, TICK_MAX = 8;
  static constexpr int PY0 = 166, PT = 178, PB = 209, PX0 = 4, PX1 = 315, PW = PX1 - PX0 + 1;
  static constexpr float kStrokeMap = 1.5f;    // 0.6.2-circuit.5: orange edge stroke radius (px): stroke wider than track
  static constexpr float kStrokeSec = 2.0f;
  static constexpr float kMarkGap = 1.5f;      // gap between the orange stroke and the sector marker line (px)
  static uint16_t cMark() { return (uint16_t)TFT_WHITE; }  
  static constexpr uint16_t C_TRACK = 0xFC60;   // 0.6.2-circuit.4: bright orange RGB ~255,140,0 (was grey 0x8410)
  // dark-only colours (0.6.2-circuit.6); track = C_TRACK (orange)
  static uint16_t cFaintE() { return (uint16_t)0x52AA; }  // other sectors
  static uint16_t cPanel() { return (uint16_t)0x18E3; }   // strip / table bg
  static uint16_t cRow() { return (uint16_t)0x2965; }     // table row
  static uint16_t cInk() { return (uint16_t)TFT_WHITE; }
  static uint16_t cSub() { return (uint16_t)0xC618; }     // secondary text
  static uint16_t cHdr() { return (uint16_t)0x2104; }     // header sprite
  // per-sector view rotation (deg, CCW) for the embedded Beta X H circuit, from the reference crops
  static float secRotDeg(int k) { static constexpr float r[4] = {27.f, -9.f, 27.f, 0.f}; return r[k & 3]; }
  static uint16_t bg() { return C_BG; }  // map + sector view field follows the theme
  static uint16_t secColor(int k) {             // S1 red, S2 cyan, S3 green, S4 magenta
    static constexpr uint16_t c[4] = {0xF800, 0x07FF, 0x07E0, 0xF81F};  // S4 magenta (orange = track)
    return c[k & 3];
  }
  // 0.6.2-circuit.7-rastro: F1-style live colours, chosen for sunlight on the 2.0" IPS (bright, saturated,
  // far from the orange stroke 0xFC60 in green): violet ~(190,70,255) and pure yellow (255,255,0).
  static constexpr uint16_t kPur = 0xBA3F, kYel = 0xFFE0;
  static constexpr float kTraceR = 1.5f, kCaseR = 2.5f, kMinStepDm = 20;  // 3 px core, 1 px casing, 2 m
  static uint16_t secInk(int k) { return (k & 3) == 0 ? (uint16_t)TFT_WHITE : (uint16_t)TFT_BLACK; }

  bool begin(const Circuit* c) {
    end();
    if (!c || c->nO < 2 || c->nI < 2) return false;
    if (heap_caps_get_free_size(MALLOC_CAP_8BIT) < kMinFree8 ||
        heap_caps_get_largest_free_block(MALLOC_CAP_8BIT) < kMinBig8)
      return false;
    c_ = c;
    scr_ = (int16_t*)malloc(sizeof(int16_t) * 2 * (c->nO + c->nI));
    sdm_ = (uint16_t*)malloc(sizeof(uint16_t) * (c->nO + c->nI));  // progress (dm) per edge point
    sec_ = (uint8_t*)malloc(c->nO + c->nI);                          // sector per edge point
    nrm_ = (int8_t*)malloc(2 * (c->nO + c->nI));                     // 0.6.2-circuit.5: outward normal x,y (/127)
    trail_ = (TP*)malloc(sizeof(TP) * TRAIL_MAX);
    hdr_ = new (std::nothrow) M5Canvas(&M5.Display);
    if (!scr_ || !sdm_ || !sec_ || !nrm_ || !trail_ || !hdr_) { end(); return false; }
    hdr_->setColorDepth(8);
    if (!hdr_->createSprite(W, HDR)) { end(); return false; }
    classify();
    elevCheck();
    project();
    return true;
  }
  void end() {
    free(scr_); scr_ = nullptr;
    free(sdm_); sdm_ = nullptr;
    free(sec_); sec_ = nullptr;
    free(nrm_); nrm_ = nullptr;
    free(trail_); trail_ = nullptr;
    if (hdr_) { hdr_->deleteSprite(); delete hdr_; hdr_ = nullptr; }
    c_ = nullptr; trailN_ = trailHead_ = 0; dotX_ = -100; markX_ = -100;
    nTick_ = 0; lapSeen_ = -1; crossSeen_ = 0xFFFFFFFFUL;
  }
  bool active() const { return hdr_ != nullptr && c_ != nullptr; }
  // 0.6.4: auto/manual session opened or closed -> empty trace + ticks (full redraw when visible)
  void clearTrace(bool recording) {
    trailN_ = trailHead_ = 0; nTick_ = 0; lapSeen_ = -1; crossSeen_ = 0xFFFFFFFFUL;
    if (active() && mode_ != CircuitMode::Sectors) drawStatic(recording);
  }
  const char* autoTag = nullptr;  // 0.6.3-auto: short auto-session tag for the header
  CircuitMode mode() const { return mode_; }
  int sectorShown() const { return secK_; }
  int nShown() const { return c_ ? (c_->nSec > 4 ? 4 : (c_->nSec < 1 ? 1 : c_->nSec)) : 0; }
  bool elevOk() const { return elevOk_; }
  void setMode(CircuitMode m, int k = 0) {
    mode_ = m;
    secK_ = (m == CircuitMode::Sector && active()) ? (k < 0 ? 0 : (k >= nShown() ? nShown() - 1 : k)) : 0;
    if (active()) project();
  }
  // Button C: Map -> S1 .. Sn -> Sectors table -> Map
  void nextMode() {
    if (mode_ == CircuitMode::Map) setMode(CircuitMode::Sector, 0);
    else if (mode_ == CircuitMode::Sector) {
      if (secK_ + 1 < nShown()) setMode(CircuitMode::Sector, secK_ + 1);
      else setMode(CircuitMode::Sectors);
    } else setMode(CircuitMode::Map);
  }
  const char* modeName() const {
    static const char* s[4] = {"s1", "s2", "s3", "s4"};
    return mode_ == CircuitMode::Map ? "map" : (mode_ == CircuitMode::Sectors ? "sectors" : s[secK_ & 3]);
  }

  // Full redraw of the body + button bar (page open, mode change, REC toggle). ~25-70 ms.
  void drawStatic(bool recording) {
    if (!active()) return;
    auto& d = M5.Display;
    d.startWrite();
    if (mode_ != CircuitMode::Sectors) {
      d.fillRect(0, HDR, W, mapY1_ - HDR, bg());
      fillCorridor(0, HDR, W, mapY1_ - HDR);
      if (mode_ == CircuitMode::Sector) drawCenterElev(0, HDR, W, mapY1_ - HDR);
      drawChevrons(0, HDR, W, mapY1_ - HDR);
      drawEdges(0, HDR, W, mapY1_ - HDR);
      drawGates();
      d.setClipRect(0, HDR, W, mapY1_ - HDR);
      drawTrace(trailN_);  // 0.6.2-circuit.7-rastro: kept lap trace (casing pass, colour pass, ticks)
      d.clearClipRect();
      if (mode_ == CircuitMode::Sector) { chooseInfoPos(); drawSectorInfo(); drawProfileStatic(); }
    } else {
      d.fillRect(0, HDR, W, Y1 - HDR, cPanel());
    }
    d.endWrite();
    char cl[8];
    if (mode_ == CircuitMode::Map) snprintf(cl, sizeof cl, "S1");
    else if (mode_ == CircuitMode::Sector) {
      if (secK_ + 1 < nShown()) snprintf(cl, sizeof cl, "S%d", secK_ + 2);
      else snprintf(cl, sizeof cl, "TABLA");
    } else snprintf(cl, sizeof cl, "MAPA");
    drawButtonBar(d, recording ? "STOP" : "REC", "SALIR", cl);
    dotX_ = -100;
    markX_ = -100;
    sectorsDirty_ = true;
  }

  // 5 Hz: header sprite + dot/trail delta (map, sector) + profile marker (sector) or sector table.
  void update(const LiveFix& f, const LapTimer& lt, const LiveDelta& ld, bool recording, bool timesChanged) {
    if (!active()) return;
    // 0.6.2-circuit.7-rastro: new lap -> clear trace + ticks (full static redraw, once per lap)
    if (lapSeen_ < 0) lapSeen_ = lt.lap();
    if (lt.lap() != lapSeen_) {
      lapSeen_ = lt.lap();
      trailN_ = trailHead_ = 0; nTick_ = 0;
      if (mode_ != CircuitMode::Sectors) drawStatic(recording);
    }
    const uint16_t tcol = ld.behind() ? kYel : kPur;
    drawHeader(f, lt, ld, recording);
    if (mode_ == CircuitMode::Sectors) {
      if (timesChanged || sectorsDirty_) drawSectorPanel(lt);
      sectorsDirty_ = false;
      return;
    }
    if (!f.valid) return;
    int16_t px, py;
    toPx(f.x, f.y, px, py);
    auto& d = M5.Display;
    d.startWrite();
    if (dotX_ > -50) {  // erase old dot: repaint background + corridor/edges/recent trail in its box
      const int bx = dotX_ - 6, by = dotY_ - 6;
      d.setClipRect(0, HDR, W, mapY1_ - HDR);
      d.fillRect(bx, by, 13, 13, bg());
      d.clearClipRect();
      fillCorridor(bx, by, 13, 13);  // restores the orange corridor, background outside
      if (mode_ == CircuitMode::Sector) drawCenterElev(bx, by, 13, 13);
      drawChevrons(bx, by, 13, 13);  // 0.6.2: arrows restored under the old dot
      drawEdges(bx, by, 13, 13);
      drawGates(bx, by, 13, 13);     // 0.6.2: incl. label chips (clipped)
      if (mode_ == CircuitMode::Sector && ((bx < infoX_ + 160 && bx + 13 > infoX_ && by < infoY_ + 19 && by + 13 > infoY_) ||
                                           (bx + 13 > W - 30 && by < HDR + 32)))
        drawSectorInfo();            // 0.6.2: corner coordinates / north arrow never smudged
      if (clip(bx, by, 13, 13)) {
        drawTrace(24);  // recent trace segments + ticks under the old dot
        d.clearClipRect();
      }
    }
    // 0.6.2-circuit.7-rastro: append + draw the new trace segment in the live colour
    const TP np = {(int16_t)lroundf(f.x * 10.f), (int16_t)lroundf(f.y * 10.f), tcol};
    d.setClipRect(0, HDR, W, mapY1_ - HDR);
    bool store = trailN_ == 0;
    if (trailN_) {
      const TP& l = trail_[(trailHead_ + TRAIL_MAX - 1) % TRAIL_MAX];
      const float dd = hypotf((float)(np.x - l.x), (float)(np.y - l.y));
      store = dd >= kMinStepDm || l.col != tcol;
      if (dd > 600) { store = true; }  // >60 m jump (GNSS glitch / re-entry): no connecting line
      else if (store) {
        int16_t lx, ly;
        toPxDm(l, lx, ly);
        d.drawWideLine(lx, ly, px, py, kCaseR, TFT_BLACK);
        if (trailN_ > 1) {  // restore the previous segment's core where the new casing overlapped it
          const TP& p2 = trail_[(trailHead_ + TRAIL_MAX - 2) % TRAIL_MAX];
          int16_t qx, qy;
          toPxDm(p2, qx, qy);
          if (hypotf((float)(l.x - p2.x), (float)(l.y - p2.y)) <= 600) d.drawWideLine(qx, qy, lx, ly, kTraceR, l.col);
        }
        d.drawWideLine(lx, ly, px, py, kTraceR, tcol);
      }
    }
    if (store) {
      trail_[trailHead_] = np;
      trailHead_ = (trailHead_ + 1) % TRAIL_MAX;
      if (trailN_ < TRAIL_MAX) ++trailN_;
    }
    // sector boundary crossed since the last tick: tick across the trace (S/F has its checkered gate)
    if (crossSeen_ == 0xFFFFFFFFUL) crossSeen_ = ld.crossings();
    if (ld.crossings() != crossSeen_) {
      crossSeen_ = ld.crossings();
      if (ld.crossSector() > 0 && nTick_ < TICK_MAX && trailN_ > 1) {
        const TP& b = trail_[(trailHead_ + TRAIL_MAX - 1) % TRAIL_MAX];
        const TP& a = trail_[(trailHead_ + TRAIL_MAX - 2) % TRAIL_MAX];
        float dx = (float)(b.x - a.x), dy = (float)(b.y - a.y);
        const float l = hypotf(dx, dy) + 1e-3f;
        TK t = {(int16_t)lroundf(ld.crossX() * 10.f), (int16_t)lroundf(ld.crossY() * 10.f),
                (int8_t)lroundf(-dy / l * 127.f), (int8_t)lroundf(dx / l * 127.f)};
        ticks_[nTick_++] = t;
        drawTick(t);
      }
    }
    const bool inArea = px > -6 && px < W + 6 && py > HDR - 6 && py < mapY1_ + 6;
    if (inArea) {
      d.fillCircle(px, py, 4, TFT_RED);
      d.drawCircle(px, py, 5, TFT_WHITE);
    }
    d.clearClipRect();
    if (mode_ == CircuitMode::Sector) drawMarker(f);
    d.endWrite();
    if (inArea) { dotX_ = px; dotY_ = py; } else dotX_ = -100;
  }

 private:
  struct TP { int16_t x, y; uint16_t col; };  // trail point in decimetres (anchor frame), live colour
  struct TK { int16_t x, y; int8_t nx, ny; };  // sector tick: crossing point (dm) + normal to travel (world, /127)

  // 0.6.2-circuit.7-rastro: last n trace segments (clip already set): black casing pass, colour pass, ticks.
  void drawTrace(int n) {
    auto& d = M5.Display;
    if (n > trailN_) n = trailN_;
    for (int pass = 0; pass < 2; ++pass) {
      for (int i = n - 1; i >= 1; --i) {
        const TP& a = trail_[(trailHead_ + TRAIL_MAX - i - 1) % TRAIL_MAX];
        const TP& b = trail_[(trailHead_ + TRAIL_MAX - i) % TRAIL_MAX];
        if (hypotf((float)(b.x - a.x), (float)(b.y - a.y)) > 600) continue;  // glitch gap
        int16_t ax, ay, bx, by;
        toPxDm(a, ax, ay); toPxDm(b, bx, by);
        if ((ax < -8 && bx < -8) || (ax > W + 8 && bx > W + 8) || (ay < HDR - 8 && by < HDR - 8) ||
            (ay > mapY1_ + 8 && by > mapY1_ + 8)) continue;
        if (pass == 0) d.drawWideLine(ax, ay, bx, by, kCaseR, TFT_BLACK);
        else d.drawWideLine(ax, ay, bx, by, kTraceR, b.col);
      }
    }
    for (int t = 0; t < nTick_; ++t) drawTick(ticks_[t]);
  }
  void drawTick(const TK& t) {  // ~13 px white bar across the trace, 1 px black casing
    auto& d = M5.Display;
    int16_t cx, cy, ex, ey;
    toPxDm({t.x, t.y, 0}, cx, cy);
    toPx(t.x * 0.1f + t.nx / 127.f, t.y * 0.1f + t.ny / 127.f, ex, ey);  // 1 m along the normal -> screen dir
    float dx = ex - cx, dy = ey - cy;
    const float l = hypotf(dx, dy) + 1e-3f;
    dx = dx / l * 6.f; dy = dy / l * 6.f;
    d.drawWideLine(cx - dx, cy - dy, cx + dx, cy + dy, 2.0f, TFT_BLACK);
    d.drawWideLine(cx - dx, cy - dy, cx + dx, cy + dy, 1.0f, TFT_WHITE);
  }

  // sector of every edge point + sector bounds (m along the centerline). Once per begin().
  void classify() {
    const float u = c_->unit;
    nb_ = 0;
    for (int g = 0; g < c_->nG && nb_ < 4; ++g) if (c_->gate[g].kind <= 1) bnd_[nb_++] = c_->gate[g].s_dm / 10.f;
    if (nb_ == 0) bnd_[nb_++] = 0;
    bnd_[nb_] = c_->lenM;
    for (int i = 0; i < c_->nO + c_->nI; ++i) {
      const CPt& p = i < c_->nO ? c_->outer[i] : c_->inner[i - c_->nO];
      int seg; float dist;
      float s = c_->progress(p.x * u, p.y * u, seg, dist);
      // the first/last few points sit on the S/F seam: keep them monotonic with their neighbours
      const int li = i < c_->nO ? i : i - c_->nO, n = i < c_->nO ? c_->nO : c_->nI;
      if (li < n / 8 && s > c_->lenM * 0.75f) s = 0;
      if (li > n - n / 8 && s < c_->lenM * 0.25f) s = c_->lenM;
      sdm_[i] = (uint16_t)fminf(fmaxf(s * 10.f, 0.f), 65535.f);
      int k = 0;
      for (int b = 1; b < nb_; ++b) if (s >= bnd_[b]) k = b;
      sec_[i] = (uint8_t)k;
    }
    // 0.6.2-circuit.5: outward (away from the centerline) unit normal per edge point, world frame, once
    for (int e = 0; e < 2; ++e) {
      const CPt* P = e == 0 ? c_->outer : c_->inner;
      const int n = e == 0 ? c_->nO : c_->nI, base = e == 0 ? 0 : c_->nO;
      for (int i = 0; i < n; ++i) {
        const CPt& a = P[(i + n - 1) % n]; const CPt& b = P[(i + 1) % n];
        float tx = (b.x - a.x) * u, ty = (b.y - a.y) * u;
        const float l = sqrtf(tx * tx + ty * ty) + 1e-6f;
        float nx = -ty / l, ny = tx / l;
        int seg; float d1, d2;
        const float px = P[i].x * u, py = P[i].y * u;
        c_->progress(px + nx * 0.8f, py + ny * 0.8f, seg, d1);
        c_->progress(px - nx * 0.8f, py - ny * 0.8f, seg, d2);
        if (d2 > d1) { nx = -nx; ny = -ny; }
        nrm_[2 * (base + i)] = (int8_t)lroundf(nx * 127.f);
        nrm_[2 * (base + i) + 1] = (int8_t)lroundf(ny * 127.f);
      }
    }
  }
  // elevation table only applies to the circuit it was generated for
  void elevCheck() {
    const float dy = (float)((c_->lat0 - kElevLat0) * 111000.0);
    const float dx = (float)((c_->lon0 - kElevLon0) * 111000.0 * cos(kElevLat0 * M_PI / 180));
    elevOk_ = sqrtf(dx * dx + dy * dy) < 30.f && fabsf(c_->lenM - kElevLenM) < 0.03f * kElevLenM;
    zMin_ = 1e9f; zMax_ = -1e9f;
    if (!elevOk_) return;
    for (int i = 0; i < kElevN; ++i) { const float z = kElevDm[i] / 10.f; zMin_ = fminf(zMin_, z); zMax_ = fmaxf(zMax_, z); }
  }
  float elevAt(float s) const {  // m relative to S/F
    float q = s / c_->lenM * kElevLenM / kElevStepM;
    if (q < 0) q = 0;
    if (q > kElevN - 1) q = (float)(kElevN - 1);
    const int i = (int)q;
    const int j = i + 1 < kElevN ? i + 1 : i;
    const float t = q - i;
    return (kElevDm[i] * (1 - t) + kElevDm[j] * t) / 10.f;
  }
  static uint16_t ramp(float t) {  // hypsometric: blue -> green -> yellow -> red
    t = t < 0 ? 0 : (t > 1 ? 1 : t);
    uint8_t r, g, b;
    if (t < 1.f / 3) { const float v = t * 3; r = 0; g = (uint8_t)(90 + 110 * v); b = (uint8_t)(255 * (1 - v)); }
    else if (t < 2.f / 3) { const float v = (t - 1.f / 3) * 3; r = (uint8_t)(240 * v); g = 200 + (uint8_t)(30 * v); b = 0; }
    else { const float v = (t - 2.f / 3) * 3; r = 240; g = (uint8_t)(230 * (1 - v)); b = 0; }
    return M5.Display.color565(r, g, b);
  }
  uint16_t elevColor(float z) const { return ramp((z - zMin_) / fmaxf(zMax_ - zMin_, 1.f)); }
  float s0() const { return bnd_[secK_]; }
  float s1() const { return secK_ + 1 < nb_ ? bnd_[secK_ + 1] : c_->lenM; }

  // Choose the transform for the current mode and project the edge cache.
  void project() {
    mapY1_ = mode_ == CircuitMode::Sector ? PY0 : Y1;
    const float rot = (mode_ == CircuitMode::Sector && elevOk_) ? secRotDeg(secK_) * (float)(M_PI / 180) : 0.f;
    cr_ = cosf(rot); sr_ = sinf(rot);
    float x0 = 1e9f, x1 = -1e9f, y0 = 1e9f, y1 = -1e9f;
    const float u = c_->unit;
    auto acc = [&](float wx, float wy) {
      const float x = cr_ * wx - sr_ * wy, y = sr_ * wx + cr_ * wy;
      x0 = fminf(x0, x); x1 = fmaxf(x1, x); y0 = fminf(y0, y); y1 = fmaxf(y1, y); };
    const bool sec = mode_ == CircuitMode::Sector;
    for (int i = 0; i < c_->nO + c_->nI; ++i) {
      if (sec && sec_[i] != secK_) continue;
      const CPt& p = i < c_->nO ? c_->outer[i] : c_->inner[i - c_->nO];
      acc(p.x * u, p.y * u);
    }
    if (sec) {  // include both gates of the sector
      int ord = 0;
      for (int g = 0; g < c_->nG; ++g) {
        if (c_->gate[g].kind == 2) continue;
        if (ord == secK_ || ord == (secK_ + 1) % nShown()) {
          acc(c_->gate[g].a.x * u, c_->gate[g].a.y * u);
          acc(c_->gate[g].b.x * u, c_->gate[g].b.y * u);
        }
        ++ord;
      }
    }
    if (x1 < x0) { x0 = -10; x1 = 10; y0 = -10; y1 = 10; }
    const int mg = sec ? 14 : MARGIN;
    const float mh = (float)(mapY1_ - HDR - 2 * mg), mw = (float)(W - 2 * mg);
    k_ = fminf(mw / fmaxf(x1 - x0, 1.f), mh / fmaxf(y1 - y0, 1.f));
    ax_ = W / 2.f - k_ * (x0 + x1) / 2.f;
    ay_ = HDR + (mapY1_ - HDR) / 2.f + k_ * (y0 + y1) / 2.f;
    int j = 0;
    for (int i = 0; i < c_->nO; ++i, j += 2) toPx(c_->outer[i].x * u, c_->outer[i].y * u, scr_[j], scr_[j + 1]);
    for (int i = 0; i < c_->nI; ++i, j += 2) toPx(c_->inner[i].x * u, c_->inner[i].y * u, scr_[j], scr_[j + 1]);
    dotX_ = -100;
  }
  bool clip(int cx, int cy, int cw, int ch) {  // clip to box ∩ map area; false if empty
    int x0 = cx < 0 ? 0 : cx, y0 = cy < HDR ? HDR : cy;
    int x1 = cx + cw > W ? W : cx + cw, y1 = cy + ch > mapY1_ ? mapY1_ : cy + ch;
    if (x1 <= x0 || y1 <= y0) return false;
    M5.Display.setClipRect(x0, y0, x1 - x0, y1 - y0);
    bx0_ = x0; by0_ = y0; bx1_ = x1; by1_ = y1;
    return true;
  }
  // Triangle strip between outer and inner edges, merged by progress. ~nO+nI triangles, no heap.
  template <class F> void forEachTri(F&& f) const {
    const int nO = c_->nO, nI = c_->nI;
    const int16_t* o = scr_; const int16_t* in = scr_ + 2 * nO;
    const uint16_t* so = sdm_; const uint16_t* si = sdm_ + nO;
    const uint8_t* ko = sec_; const uint8_t* ki = sec_ + nO;
    int i = 0, j = 0;
    while (i < nO - 1 || j < nI - 1) {
      const bool advO = j >= nI - 1 || (i < nO - 1 && so[i + 1] <= si[j + 1]);
      if (advO) { f(o[2 * i], o[2 * i + 1], o[2 * i + 2], o[2 * i + 3], in[2 * j], in[2 * j + 1], ko[i]); ++i; }
      else { f(in[2 * j], in[2 * j + 1], in[2 * j + 2], in[2 * j + 3], o[2 * i], o[2 * i + 1], ki[j]); ++j; }
    }
    // close the loop across S/F
    f(o[2 * (nO - 1)], o[2 * (nO - 1) + 1], o[0], o[1], in[2 * (nI - 1)], in[2 * (nI - 1) + 1], ko[0]);
    f(in[2 * (nI - 1)], in[2 * (nI - 1) + 1], in[0], in[1], o[0], o[1], ko[0]);
  }
  void fillCorridor(int cx, int cy, int cw, int ch) {
    auto& d = M5.Display;
    if (!clip(cx, cy, cw, ch)) return;
    const int x0 = bx0_, y0 = by0_, x1 = bx1_, y1 = by1_;
    const bool sec = mode_ == CircuitMode::Sector;
    forEachTri([&](int ax, int ay, int bx, int by, int qx, int qy, uint8_t k) {
      const int mnx = ax < bx ? (ax < qx ? ax : qx) : (bx < qx ? bx : qx);
      const int mxx = ax > bx ? (ax > qx ? ax : qx) : (bx > qx ? bx : qx);
      const int mny = ay < by ? (ay < qy ? ay : qy) : (by < qy ? by : qy);
      const int mxy = ay > by ? (ay > qy ? ay : qy) : (by > qy ? by : qy);
      if (mxx < x0 || mnx >= x1 || mxy < y0 || mny >= y1) return;  // cheap reject outside the dirty box
      if (sec && k != secK_) return;  // sector view: other sectors are outlines only
      d.fillTriangle(ax, ay, bx, by, qx, qy, C_TRACK);
    });
    // 0.6.2-circuit.5: no edge lines; the edges are stroked in orange so the stroke is thicker than the
    // real track. Sector view: other sectors stay thin faded outlines.
    auto edge = [&](const int16_t* p, const uint8_t* ks, int n) {
      for (int i = 0; i < n; ++i) {
        const int j = (i + 1) % n;
        const int ex0 = p[2 * i], ey0 = p[2 * i + 1], ex1 = p[2 * j], ey1 = p[2 * j + 1];
        if ((ex0 < x0 - 4 && ex1 < x0 - 4) || (ex0 > x1 + 4 && ex1 > x1 + 4) ||
            (ey0 < y0 - 4 && ey1 < y0 - 4) || (ey0 > y1 + 4 && ey1 > y1 + 4)) continue;
        const bool mine = !sec || ks[i] == secK_ || ks[j] == secK_;
        if (mine) d.drawWideLine(ex0, ey0, ex1, ey1, sec ? kStrokeSec : kStrokeMap, C_TRACK);
        else d.drawLine(ex0, ey0, ex1, ey1, cFaintE());
      }
    };
    edge(scr_, sec_, c_->nO);
    edge(scr_ + 2 * c_->nO, sec_ + c_->nO, c_->nI);
    d.clearClipRect();
  }
  void toPx(float x, float y, int16_t& px, int16_t& py) const {
    const float rx = cr_ * x - sr_ * y, ry = sr_ * x + cr_ * y;
    float fx = ax_ + k_ * rx, fy = ay_ - k_ * ry;
    fx = fx < -8000 ? -8000 : (fx > 8000 ? 8000 : fx);
    fy = fy < -8000 ? -8000 : (fy > 8000 ? 8000 : fy);
    px = (int16_t)lroundf(fx);
    py = (int16_t)lroundf(fy);
  }
  void toPxDm(const TP& p, int16_t& px, int16_t& py) const { toPx(p.x * 0.1f, p.y * 0.1f, px, py); }
  // 0.6.2-circuit.5: one white line per sector beside the orange stroke, alternating sides
  // (S1 outer, S2 inner, S3 outer, S4 inner); the side switch marks the sector change. No outline.
  void drawEdges(int cx, int cy, int cw, int ch) {
    auto& d = M5.Display;
    if (!clip(cx, cy, cw, ch)) return;  // never paints over header / profile / button bar
    const bool sec = mode_ == CircuitMode::Sector;
    const float u = c_->unit;
    const float off = ((sec ? kStrokeSec : kStrokeMap) + kMarkGap + 1.0f) / k_;  // metres beyond the edge
    const uint16_t col = cMark();
    for (int e = 0; e < 2; ++e) {
      const CPt* P = e == 0 ? c_->outer : c_->inner;
      const int n = e == 0 ? c_->nO : c_->nI, base = e == 0 ? 0 : c_->nO;
      int16_t lx = 0, ly = 0;
      bool have = false;
      for (int i = 0; i <= n; ++i) {
        const int ii = i % n, idx = base + ii;
        const int k = sec_[idx];
        const bool want = ((k & 1) == 0) == (e == 0) && (!sec || k == secK_);  // even sectors outer, odd inner
        if (!want) { have = false; continue; }
        int16_t px, py;
        toPx(P[ii].x * u + nrm_[2 * idx] / 127.f * off, P[ii].y * u + nrm_[2 * idx + 1] / 127.f * off, px, py);
        if (have) {
          const bool out = (px < bx0_ - 4 && lx < bx0_ - 4) || (px > bx1_ + 4 && lx > bx1_ + 4) ||
                           (py < by0_ - 4 && ly < by0_ - 4) || (py > by1_ + 4 && ly > by1_ + 4);
          if (!out) d.drawWideLine(lx, ly, px, py, 1.0f, col);
        }
        lx = px; ly = py; have = true;
      }
    }
    d.clearClipRect();
  }

  // sector view: centerline of the shown sector tinted by elevation (2 px)
  void drawCenterElev(int cx, int cy, int cw, int ch) {
    if (!elevOk_ || !clip(cx, cy, cw, ch)) { M5.Display.clearClipRect(); return; }
    auto& d = M5.Display;
    const float u = c_->unit, a = s0(), b = s1();
    for (int i = 0; i < c_->nC; ++i) {
      const int j = (i + 1) % c_->nC;
      const float sa = c_->cumS[i], sb = j ? c_->cumS[j] : c_->lenM;
      if (sb < a || sa > b) continue;
      int16_t px, py, qx, qy;
      toPx(c_->center[i].x * u, c_->center[i].y * u, px, py);
      toPx(c_->center[j].x * u, c_->center[j].y * u, qx, qy);
      if ((px < bx0_ - 3 && qx < bx0_ - 3) || (px > bx1_ + 3 && qx > bx1_ + 3) ||
          (py < by0_ - 3 && qy < by0_ - 3) || (py > by1_ + 3 && qy > by1_ + 3)) continue;
      d.drawLine(  // 1 px, no casing: keeps the orange visible in a narrow corridor
          px, py, qx, qy, elevColor(elevAt(0.5f * (sa + sb))));
    }
    d.clearClipRect();
  }
  void drawChevrons(int cx, int cy, int cw, int ch) {  // direction of travel (recording order of the mapping), every ~90 m (40 m zoomed)
    auto& d = M5.Display;
    const float u = c_->unit;
    const bool sec = mode_ == CircuitMode::Sector;
    const float every = sec ? 40.f : 90.f;
    if (!clip(cx, cy, cw, ch)) return;
    const int x0 = bx0_ - 8, y0 = by0_ - 8, x1 = bx1_ + 8, y1 = by1_ + 8;
    for (int i = 1; i < c_->nC; ++i) {
      if ((int)(c_->cumS[i] / every) == (int)(c_->cumS[i - 1] / every)) continue;
      if (sec && (c_->cumS[i] < s0() + 8 || c_->cumS[i] > s1() - 8)) continue;
      int16_t px, py, qx, qy;
      toPx(c_->center[i - 1].x * u, c_->center[i - 1].y * u, px, py);
      toPx(c_->center[i].x * u, c_->center[i].y * u, qx, qy);
      if (qx < x0 || qx > x1 || qy < y0 || qy > y1) continue;
      float dx = qx - px, dy = qy - py;
      const float l = sqrtf(dx * dx + dy * dy) + 1e-3f;
      dx /= l; dy /= l;
      const uint16_t g = (uint16_t)TFT_BLACK;  // 0.6.2-circuit.4: black arrows read on the orange track
      d.drawLine(qx - dx * 4 - dy * 3, qy - dy * 4 + dx * 3, qx + dx * 3, qy + dy * 3, g);
      d.drawLine(qx - dx * 4 + dy * 3, qy - dy * 4 - dx * 3, qx + dx * 3, qy + dy * 3, g);
    }
    d.clearClipRect();
  }
  // sector view corner info: gate coordinates (in/out) + north arrow (map may be rotated)
  // 0.6.2-circuit.4: put the gate-coordinate box in the corner with the least track / gate labels under it
  void chooseInfoPos() {
    const int cx[4] = {3, 3, W - 160, W - 190}, cy[4] = {HDR + 2, mapY1_ - 19, mapY1_ - 19, HDR + 2};
    int best = 1 << 30;
    for (int c = 0; c < 4; ++c) {
      int sc = c;  // tie-break: prefer top-left, then bottom-left ...
      for (int i = 0; i < c_->nO + c_->nI; ++i) {
        const int x = scr_[2 * i], y = scr_[2 * i + 1];
        if (x > cx[c] - 6 && x < cx[c] + 162 && y > cy[c] - 6 && y < cy[c] + 23) sc += sec_[i] == secK_ ? 40 : 4;
      }
      const float u = c_->unit;
      int ord = 0;
      for (int g = 0; g < c_->nG; ++g) {
        if (c_->gate[g].kind == 2) continue;
        if (ord == secK_ || ord == (secK_ + 1) % nShown()) {
          int16_t gx, gy;
          toPx(c_->gate[g].b.x * u, c_->gate[g].b.y * u, gx, gy);
          if (gx > cx[c] - 20 && gx < cx[c] + 176 && gy > cy[c] - 18 && gy < cy[c] + 35) sc += 200;
        }
        ++ord;
      }
      if (sc < best) { best = sc; infoX_ = cx[c]; infoY_ = cy[c]; }
    }
  }
  void drawSectorInfo() {
    auto& d = M5.Display;
    d.setFont(&fonts::Font0);
    d.setTextSize(1);
    d.setTextDatum(lgfx::textdatum_t::top_left);
    d.setTextColor(C_MUTED, C_BG);
    const float u = c_->unit;
    int ord = 0, line = 0;
    char buf[40];
    for (int g = 0; g < c_->nG && line < 2; ++g) {
      const CGate& G = c_->gate[g];
      if (G.kind == 2) continue;
      const bool in = ord == secK_, out = ord == (secK_ + 1) % nShown();
      if (in || out) {
        const float x = 0.5f * (G.a.x + G.b.x) * u, y = 0.5f * (G.a.y + G.b.y) * u;
        const double lat = c_->lat0 + y / c_->ky, lon = c_->lon0 + x / c_->kx;
        snprintf(buf, sizeof buf, "%s %.5f,%.5f", G.kind == 0 ? "S/F" : (in ? "IN " : "OUT"), lat, lon);
        d.drawString(buf, infoX_, infoY_ + 9 * (in ? 0 : 1));
        ++line;
      }
      ++ord;
    }
    // north arrow, top-right
    const int nx = W - 12, ny = HDR + 16;
    const float ux = -sr_, uy = -cr_;  // screen direction of world north (0,1)
    d.fillTriangle(nx + ux * 9, ny + uy * 9, nx - uy * 4 - ux * 4, ny + ux * 4 - uy * 4,
                   nx + uy * 4 - ux * 4, ny - ux * 4 - uy * 4, C_FG);
    d.setTextDatum(lgfx::textdatum_t::middle_center);
    d.setTextColor(C_FG, C_BG);
    d.drawString("N", nx - ux * 11, ny - uy * 11);
  }
  void drawGates(int cx = 0, int cy = HDR, int cw = W, int ch = Y1 - HDR) {
    auto& d = M5.Display;
    if (!clip(cx, cy, cw, ch)) return;
    const bool secv = mode_ == CircuitMode::Sector;
    const float u = c_->unit;
    int sec = 0;
    d.setFont(&fonts::Font0);
    d.setTextSize(1);
    d.setTextDatum(lgfx::textdatum_t::middle_center);
    for (int i = 0; i < c_->nG; ++i) {
      const CGate& G = c_->gate[i];
      if (G.kind == 2) continue;
      int16_t x0, y0, x1, y1;
      toPx(G.a.x * u, G.a.y * u, x0, y0);
      toPx(G.b.x * u, G.b.y * u, x1, y1);
      float dx = x1 - x0, dy = y1 - y0;
      const float l = sqrtf(dx * dx + dy * dy) + 1e-3f;
      // gates are only ~10 m long (2-4 px on the map): stretch the drawn line to >= 14 px so it is visible
      const float ext = l < 14 ? (14 - l) / 2 : 0;
      const int ax = x0 - dx / l * ext, ay = y0 - dy / l * ext, bx = x1 + dx / l * ext, by = y1 + dy / l * ext;
      // sector view: the two gates of the shown sector in its colour, the others faint
      const bool mine = !secv || sec == secK_ || sec == (secK_ + 1) % nShown();
      const uint16_t gc = secv ? (mine ? secColor(secK_) : cFaintE()) : secColor(sec);
      if (G.kind == 0) {  // start/finish (= anchor, first fix of the mapping): checkered + ring
        for (int t = 0; t < 6; ++t)
          d.drawWideLine(ax + (bx - ax) * t / 6, ay + (by - ay) * t / 6, ax + (bx - ax) * (t + 1) / 6,
                         ay + (by - ay) * (t + 1) / 6, 1.5f, (t & 1) ? TFT_WHITE : TFT_BLACK);
        int16_t sx, sy;
        toPx(0, 0, sx, sy);
        d.drawCircle(sx, sy, 5, gc);
      } else {
        d.drawWideLine(ax, ay, bx, by, secv && mine ? 2.6f : 2.5f, TFT_BLACK);  // casing
        d.drawWideLine(ax, ay, bx, by, secv && mine ? 2.0f : 1.5f, gc);  // gate opening sector sec+1
      }
      if (!mine) { ++sec; continue; }
      // label chip: filled in the sector colour, dark ink on light colours (readable on white, black & orange)
      char buf[6];
      snprintf(buf, sizeof buf, "S%d", sec + 1);
      int lx = bx + dx / l * 10, ly = by + dy / l * 10;
      if (lx < 9) lx = 9;
      if (lx > W - 9) lx = W - 9;
      if (ly < HDR + 6) ly = HDR + 6;
      if (ly > mapY1_ - 6) ly = mapY1_ - 6;
      d.fillRoundRect(lx - 8, ly - 5, 17, 11, 2, secColor(sec));
      d.drawRoundRect(lx - 8, ly - 5, 17, 11, 2, TFT_BLACK);
      d.setTextColor(secInk(sec), secColor(sec));
      d.drawString(buf, lx + 1, ly + 1);
      ++sec;
    }
    d.clearClipRect();
  }
  // ---- 0.6.1 elevation profile strip (sector view) -------------------------------------------
  int profY(float z) const {
    float lo = pMin_, hi = pMax_;
    if (hi - lo < 4.f) { const float m = 0.5f * (lo + hi); lo = m - 2.f; hi = m + 2.f; }  // flat: no exaggeration
    int y = PB - (int)lroundf((z - lo) / (hi - lo) * (PB - PT));
    return y < PT ? PT : (y > PB ? PB : y);
  }
  void drawProfileCol(int x, bool marker) {
    auto& d = M5.Display;
    const int i = x - PX0;
    if (i < 0 || i >= PW) return;
    const int y = profY_[i];
    if (marker) { d.drawFastVLine(x, PT, PB - PT + 1, cInk()); return; }
    if (y > PT) d.drawFastVLine(x, PT, y - PT, cPanel());
    if (PB > y) d.drawFastVLine(x, y + 1, PB - y, profFill_[i]);
    d.drawPixel(x, y, cInk());
  }
  void drawProfileStatic() {
    auto& d = M5.Display;
    d.fillRect(0, PY0, W, Y1 - PY0, cPanel());
    d.drawFastHLine(0, PY0, W, secColor(secK_));
    d.setFont(&fonts::Font0);
    d.setTextSize(1);
    char buf[48];
    if (!elevOk_) {
      d.setTextDatum(lgfx::textdatum_t::middle_center);
      d.setTextColor(cSub(), cPanel());
      d.drawString("sin datos de altura para este circuito", W / 2, (PY0 + Y1) / 2);
      return;
    }
    const float a = s0(), b = s1();
    pMin_ = 1e9f; pMax_ = -1e9f;
    float up = 0, dn = 0, ref = elevAt(a);
    for (float s = a; s <= b + 0.01f; s += 2.5f) {
      const float z = elevAt(s);
      pMin_ = fminf(pMin_, z); pMax_ = fmaxf(pMax_, z);
      if (z - ref >= 1.0f) { up += z - ref; ref = z; }       // 1 m hysteresis (GNSS noise)
      else if (ref - z >= 1.0f) { dn += ref - z; ref = z; }
    }
    for (int i = 0; i < PW; ++i) {
      const float z = elevAt(a + (b - a) * i / (PW - 1));
      profY_[i] = (uint8_t)profY(z);
      profFill_[i] = elevColor(z);
    }
    for (int x = PX0; x <= PX1; ++x) drawProfileCol(x, false);
    d.setTextDatum(lgfx::textdatum_t::top_left);
    snprintf(buf, sizeof buf, "S%d %.0fm", secK_ + 1, b - a);  // 0.6.2: chip, readable on both themes
    d.fillRoundRect(2, PY0 + 2, d.textWidth(buf) + 6, 11, 2, secColor(secK_));
    d.setTextColor(secInk(secK_), secColor(secK_));
    d.drawString(buf, 5, PY0 + 4);
    d.setTextColor(cInk(), cPanel());
    snprintf(buf, sizeof buf, "%.0f-%.0f m", kElevBaseM + pMin_, kElevBaseM + pMax_);
    d.drawString(buf, 76, PY0 + 3);
    snprintf(buf, sizeof buf, "+%.1f -%.1f m", up, dn);
    d.setTextColor((uint16_t)0x9FF3, cPanel());  // climb/descent
    d.drawString(buf, 160, PY0 + 3);
    d.setTextDatum(lgfx::textdatum_t::top_right);
    d.setTextColor(cSub(), cPanel());
    d.drawString(kElevSrc, W - 4, PY0 + 3);
    markX_ = -100;
  }
  void drawMarker(const LiveFix& f) {
    if (!elevOk_) return;
    int seg; float dist;
    const float s = c_->progress(f.x, f.y, seg, dist);
    const float a = s0(), b = s1();
    int x = -100;
    if (dist < 25.f && s >= a && s <= b) x = PX0 + (int)lroundf((s - a) / (b - a) * (PW - 1));
    if (x == markX_) return;
    auto& d = M5.Display;
    d.setClipRect(PX0, PT, PW, PB - PT + 1);
    if (markX_ > -50) for (int c = markX_ - 4; c <= markX_ + 4; ++c) drawProfileCol(c, false);
    if (x > -50) {
      drawProfileCol(x, true);
      d.fillCircle(x, profY_[x - PX0], 3, TFT_RED);
      d.drawCircle(x, profY_[x - PX0], 3, TFT_WHITE);
    }
    d.clearClipRect();
    markX_ = x;
  }
  void drawHeader(const LiveFix& f, const LapTimer& lt, const LiveDelta& ld, bool recording) {
    auto& g = *hdr_;
    g.fillSprite(cHdr());
    g.setTextColor(cInk());
    g.setFont(&fonts::Font4);
    g.setTextDatum(lgfx::textdatum_t::middle_left);
    char buf[28];
    snprintf(buf, sizeof buf, "%d", f.valid ? (int)lroundf(f.kmh) : 0);
    g.drawString(buf, 6, 18);
    const int sw = g.textWidth(buf);
    g.setFont(&fonts::Font0);
    g.drawString("km/h", 6 + sw + 3, 24);
    g.setFont(&fonts::Font4);
    const int s = lt.sector();
    if (s < 0 || !f.valid) snprintf(buf, sizeof buf, "--:--.-");
    else {
      double run = f.tS - lt.sectorStart();
      if (run < 0) run = 0;
      snprintf(buf, sizeof buf, "S%d %d:%04.1f", s + 1, (int)(run / 60), fmod(run, 60.0));
    }
    g.setTextDatum(lgfx::textdatum_t::middle_center);
    g.drawString(buf, 150, 18);  // 0.6.2-circuit.7-rastro: shifted left for the delta chip
    if (s >= 0 && f.valid) {     // live delta chip, same colour as the trace; "-.--" = no reference yet
      const uint16_t dc = ld.behind() ? kYel : kPur;
      char db[10];
      const float dl = ld.delta();
      if (!ld.hasRef()) snprintf(db, sizeof db, "-.--");
      else if (fabsf(dl) < 9.995f) snprintf(db, sizeof db, "%+.2f", dl);
      else snprintf(db, sizeof db, "%+.1f", dl > 99.9f ? 99.9f : (dl < -99.9f ? -99.9f : dl));
      g.setFont(&fonts::Font2);
      g.fillRoundRect(212, 9, 44, 18, 3, dc);
      g.setTextColor((uint16_t)TFT_BLACK);
      g.drawString(db, 234, 18);
      g.setTextColor(cInk());
      g.setFont(&fonts::Font4);
    }
    snprintf(buf, sizeof buf, "V%d", lt.lap());
    g.setTextDatum(lgfx::textdatum_t::middle_right);
    g.drawString(buf, 314, 18);
    if (recording) g.fillCircle(263, 17, 4, (uint16_t)TFT_RED);
    g.setFont(&fonts::Font0);
    g.setTextDatum(lgfx::textdatum_t::top_center);
    if (lt.wrongWay()) { g.setTextColor((uint16_t)C_ORANGE); g.drawString("SENTIDO CONTRARIO", 168, 1); }
    else if (!f.valid) { g.setTextColor(cSub()); g.drawString("sin fix GNSS", 168, 1); }
    if (autoTag && autoTag[0]) {  // 0.6.3-auto: subtle auto-session state
      g.setTextColor(cSub());
      g.setTextDatum(lgfx::textdatum_t::top_left);
      g.drawString(autoTag, 64, 1);  // short tag (<= 6 chars) between speed and sector clock
    }
    g.pushSprite(0, 0);
  }
  static void fmtT(char* b, size_t n, float t) {
    if (t <= 0) snprintf(b, n, "--.--");
    else if (t >= 60) snprintf(b, n, "%d:%05.2f", (int)(t / 60), fmodf(t, 60));
    else snprintf(b, n, "%.2f", t);
  }
  void drawSectorPanel(const LapTimer& lt) {
    // F1 colours: purple = best of this session, yellow = slower, grey = invalid/partial
    const uint16_t PUR = kPur, YEL = kYel,  // 0.6.2-circuit.7-rastro: same colours as the trace
                   GRY = 0x9492, BG = cPanel(), ROW = cRow();  // 0.6.2: per theme
    auto& d = M5.Display;
    const int n = c_->nSec > 4 ? 4 : c_->nSec;
    const int step = (Y1 - HDR - 4) / (n + 2), h = step - 4;
    d.startWrite();
    d.fillRect(0, HDR, W, Y1 - HDR, BG);
    d.setFont(&fonts::Font2);
    d.setTextDatum(lgfx::textdatum_t::middle_left);
    float bestSum = 0;
    bool allBest = n > 0;
    char buf[40], tb[16], bb[16];
    for (int k = 0; k < n; ++k) {
      const int y = HDR + 4 + k * step;
      float t = lt.current().t[k];
      bool ok = lt.current().valid[k];
      if (t <= 0) { t = lt.last().t[k]; ok = lt.last().valid[k]; }
      const float b = lt.best(k);
      if (b > 0) bestSum += b; else allBest = false;
      const uint16_t col = (!ok || t <= 0) ? GRY : (t <= b + 1e-3f ? PUR : YEL);
      d.fillRect(6, y, 308, h, ROW);
      d.fillRect(6, y, 8, h, col);
      d.fillRect(17, y + 3, 4, h - 6, secColor(k));  // 0.6.1: sector colour swatch
      d.setTextColor(cInk(), ROW);
      snprintf(buf, sizeof buf, "S%d", k + 1);
      d.drawString(buf, 26, y + h / 2);
      fmtT(tb, sizeof tb, t);
      d.setTextColor(col, ROW);
      d.drawString(tb, 70, y + h / 2);
      fmtT(bb, sizeof bb, b);
      snprintf(buf, sizeof buf, "mejor %s", bb);
      d.setTextColor(cSub(), ROW);
      d.drawString(buf, 170, y + h / 2);
    }
    int y = HDR + 4 + n * step;
    d.fillRect(6, y, 308, h, ROW);
    fmtT(tb, sizeof tb, lt.lastLap());
    snprintf(buf, sizeof buf, "VUELTA %s", tb);
    d.setTextColor(cInk(), ROW);
    d.drawString(buf, 22, y + h / 2);
    y += step;
    d.fillRect(6, y, 308, h, ROW);
    fmtT(tb, sizeof tb, allBest ? bestSum : 0);
    snprintf(buf, sizeof buf, "TEORICA %s", tb);
    d.setTextColor(PUR, ROW);
    d.drawString(buf, 22, y + h / 2);
    d.setFont(&fonts::Font0);
    d.endWrite();
  }

  const Circuit* c_ = nullptr;
  CircuitMode mode_ = CircuitMode::Map;
  int secK_ = 0, nb_ = 0, mapY1_ = Y1;
  float bnd_[5] = {};
  bool elevOk_ = false;
  float cr_ = 1, sr_ = 0;
  float zMin_ = 0, zMax_ = 1, pMin_ = 0, pMax_ = 1;
  uint8_t profY_[PW] = {};
  uint16_t profFill_[PW] = {};
  int16_t markX_ = -100;
  int infoX_ = 3, infoY_ = HDR + 2;
  int bx0_ = 0, by0_ = 0, bx1_ = 0, by1_ = 0;
  float k_ = 1, ax_ = 0, ay_ = 0;
  int16_t* scr_ = nullptr;
  uint16_t* sdm_ = nullptr;
  uint8_t* sec_ = nullptr;
  int8_t* nrm_ = nullptr;
  M5Canvas* hdr_ = nullptr;
  TP* trail_ = nullptr;
  uint16_t trailN_ = 0, trailHead_ = 0;
  int16_t dotX_ = -100, dotY_ = -100;
  bool sectorsDirty_ = true;
  TK ticks_[TICK_MAX] = {};
  uint8_t nTick_ = 0;
  int lapSeen_ = -1;
  uint32_t crossSeen_ = 0xFFFFFFFFUL;
};

}  // namespace riderlab
