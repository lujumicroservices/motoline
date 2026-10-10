// 0.6.0-circuit: gate-crossing lap & sector timer (pure C++, no Arduino deps). Fed every PVT (10 Hz).
#pragma once
#include "CircuitFile.h"

namespace riderlab {

struct SectorTimes {
  static constexpr int kMax = 16;
  float t[kMax] = {};        // s, 0 = not yet
  bool valid[kMax] = {};     // false: standing start, missed gate, stop > 3 s
};

class LapTimer {
 public:
  explicit LapTimer(const Circuit& c) : c_(c) { reset(); }
  void reset() { lastGate_ = -1; havePrev_ = false; lap_ = 0; cur_ = {}; for (auto& b : best_) b = 0; stopS_ = 0; }

  // x,y: metres in anchor frame; tS: GNSS time (s, from UTC ms); v: m/s.  Returns gate index crossed or -1.
  int onFix(float x, float y, double tS, float v) {
    int hit = -1;
    if (havePrev_) {
      if (v < 3.0f / 3.6f) stopS_ += (float)(tS - pt_);
      for (int g = 0; g < c_.nG; ++g) {
        if (c_.gate[g].kind == 2 && !micro_) continue;
        float u;
        if (!cross(px_, py_, x, y, g, u)) continue;
        if (!forward(px_, py_, x, y, g)) { wrongWay_ = true; continue; }    // crossed backwards
        double tc = pt_ + u * (tS - pt_);                                    // interpolated crossing time
        if (tc - lastT_[g] < 10.0) continue;                                 // debounce
        lastT_[g] = tc; hit = g; onGate(g, tc);
      }
    }
    px_ = x; py_ = y; pt_ = tS; havePrev_ = true;
    return hit;
  }
  // 0.6.4: new session (auto/manual open or close): forget the partial lap, KEEP the session-day bests.
  void resetLap() { havePrev_ = false; lap_ = 0; curSec_ = -1; cur_ = {}; stopS_ = 0; secValid_ = false;
                    lapT0_ = 0; wrongWay_ = false; for (auto& t : lastT_) t = 0; }
  int lap() const { return lap_; }
  int sector() const { return curSec_; }                 // 0-based, -1 before first gate
  double sectorStart() const { return secT0_; }
  const SectorTimes& current() const { return cur_; }
  const SectorTimes& last() const { return last_; }
  float best(int k) const { return best_[k]; }
  float lastLap() const { return lastLapS_; }
  bool wrongWay() const { return wrongWay_; }
  void clearWrongWay() { wrongWay_ = false; }
  void enableMicro(bool on) { micro_ = on; }

 private:
  // gate index (kind<=1 only) -> sector number
  int secOf(int g) const { int k = -1; for (int i = 0; i <= g; ++i) if (c_.gate[i].kind <= 1) ++k; return k; }
  void onGate(int g, double tc) {
    if (c_.gate[g].kind == 2) return;                    // micro: hook for micro-sector deltas
    int k = secOf(g);
    if (curSec_ >= 0 && k == (curSec_ + 1) % c_.nSec) {  // consecutive gate: close sector
      float dt = (float)(tc - secT0_);
      bool ok = secValid_ && stopS_ < 3.0f;
      cur_.t[curSec_] = dt; cur_.valid[curSec_] = ok;
      if (ok && (best_[curSec_] == 0 || dt < best_[curSec_])) best_[curSec_] = dt;
    } else if (curSec_ >= 0) {
      for (auto& v : cur_.valid) v = false;              // missed a gate
    }
    if (k == 0) {                                        // start/finish
      if (lapT0_ > 0) { lastLapS_ = (float)(tc - lapT0_); last_ = cur_; }
      cur_ = {}; lapT0_ = tc; ++lap_;
    }
    secValid_ = curSec_ >= 0;                            // first sector after power-on = standing start
    curSec_ = k; secT0_ = tc; stopS_ = 0;
  }
  bool cross(float x0, float y0, float x1, float y1, int g, float& t) const {
    const CGate& G = c_.gate[g]; float s = c_.unit;
    float ax = G.a.x * s, ay = G.a.y * s, bx = G.b.x * s, by = G.b.y * s;
    float rx = x1 - x0, ry = y1 - y0, sx = bx - ax, sy = by - ay, den = rx * sy - ry * sx;
    if (fabsf(den) < 1e-9f) return false;
    float qx = ax - x0, qy = ay - y0, u = (qx * sy - qy * sx) / den, w = (qx * ry - qy * rx) / den;
    t = u; return u >= 0 && u <= 1 && w >= 0 && w <= 1;
  }
  // direction check: motion must agree with direction of travel (CCW/CW encoded by gate orientation:
  // gate a=inner -> b=outer; for CCW travel the forward normal is (by-ay, -(bx-ax)) rotated accordingly)
  bool forward(float x0, float y0, float x1, float y1, int g) const {
    const CGate& G = c_.gate[g];
    float gx = (float)(G.b.x - G.a.x), gy = (float)(G.b.y - G.a.y);
    float cr = gx * (y1 - y0) - gy * (x1 - x0);          // z of gate x motion
    return c_.ccw ? cr > 0 : cr < 0;   // CCW: inner on the left, so inner->outer points right of travel
  }
  const Circuit& c_;
  float px_ = 0, py_ = 0; double pt_ = 0; bool havePrev_ = false;
  double lastT_[Circuit::kMaxGates] = {};
  int lastGate_ = -1, lap_ = 0, curSec_ = -1; double secT0_ = 0, lapT0_ = 0;
  bool secValid_ = false, wrongWay_ = false, micro_ = false; float stopS_ = 0, lastLapS_ = 0;
  SectorTimes cur_, last_; float best_[SectorTimes::kMax] = {};
};

}  // namespace riderlab
