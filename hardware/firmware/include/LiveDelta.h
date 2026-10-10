// 0.6.2-circuit.7-rastro: live sector delta for the track trace ("rastro"). Pure C++ (no Arduino deps),
// so the same code runs on the host replay (host/rastro_sim.cpp). Fed every PVT (10 Hz) right after
// LapTimer::onFix(), lives in CircuitRt (heap, allocated with the circuit data, freed before Wi-Fi).
//
// Model: for each sector the BEST valid pass is stored as elapsed time (centiseconds, uint16) sampled
// every kStepM = 5 m of distance along the centerline from the sector's entry gate. While riding, the
// current pass is sampled the same way; delta(d) = elapsed_now - best(d) (best linearly interpolated).
//   purple  (on pace / best)  : no reference yet (first pass counts as best from metre one) or delta <= 0
//   yellow  (behind best)     : delta > 0
// Hysteresis: purple -> yellow only when delta > +kHystS (0.05 s); yellow -> purple when delta <= 0.
// Every sector starts purple (delta = 0 at the gate). When a sector closes and LapTimer accepts it as
// the new best (valid pass, faster), the current profile replaces that sector's reference.
// Memory: 2 x kMaxBins x 2 B = 2 KB (best + current) + ~80 B. No heap of its own.
#pragma once
#include <cstdint>
#include <cmath>
#include "CircuitFile.h"
#include "LapTimer.h"

namespace riderlab {

class LiveDelta {
 public:
  static constexpr int kMaxSec = 4, kMaxBins = 512;   // 512 x 5 m = 2.5 km of lap
  static constexpr float kStepM = 5.f, kHystS = 0.05f, kMaxJumpM = 40.f, kMaxOffM = 25.f;

  void reset(const Circuit& c) {
    nb_ = 0;
    for (int g = 0; g < c.nG && nb_ < kMaxSec; ++g) if (c.gate[g].kind <= 1) bnd_[nb_++] = c.gate[g].s_dm / 10.f;
    if (nb_ == 0) bnd_[nb_++] = 0;
    bnd_[nb_] = c.lenM;
    int o = 0;
    for (int k = 0; k < nb_; ++k) {
      off_[k] = o;
      int n = (int)(secLen(k) / kStepM) + 2;           // bin 0 = gate, last bin = sector end
      if (o + n > kMaxBins) n = kMaxBins - o;
      nBin_[k] = n < 0 ? 0 : n;
      o += nBin_[k];
      bestT_[k] = 0;
    }
    lenM_ = c.lenM;
    sec_ = -1; next_ = 0; havePrev_ = false; behind_ = false; delta_ = 0; hasRef_ = false;
    crossN_ = 0; crossX_ = crossY_ = 0; crossSec_ = -1;
  }

  // 0.6.4: session edge: drop the current pass, KEEP the best profiles (same day, same circuit)
  void resetLap() { sec_ = -1; next_ = 0; havePrev_ = false; behind_ = false; delta_ = 0; hasRef_ = false; }

  // call after lt.onFix(x, y, tS, v) for every accepted fix
  void onFix(const Circuit& c, const LapTimer& lt, float x, float y, double tS) {
    const int k = lt.sector();
    if (k != sec_) {                                     // sector change (or first gate)
      if (sec_ >= 0 && sec_ < nb_) closeSector(lt);
      if (k >= 0) { ++crossN_; crossX_ = x; crossY_ = y; crossSec_ = k; }
      sec_ = k; next_ = 0; havePrev_ = false; behind_ = false; delta_ = 0;
    }
    if (k < 0 || k >= nb_ || nBin_[k] < 2) { hasRef_ = false; return; }
    int seg; float dist;
    const float s = c.progress(x, y, seg, dist);
    if (dist > kMaxOffM) return;                         // off the map: hold colour, no sample
    float d = s - bnd_[k];
    const float L = secLen(k);
    if (d < -0.5f * lenM_) d += lenM_;                   // S/F seam
    else if (d > L + 0.5f * (lenM_ - L)) d -= lenM_;
    if (d < 0) d = 0;
    if (d > L) d = L;
    double e = tS - lt.sectorStart();
    if (e < 0) e = 0;
    // sample the current pass at every 5 m bin crossed since the previous fix (linear in time)
    if (!havePrev_) { pd_ = 0; pe_ = 0; havePrev_ = true; }
    if (d > pd_ && d - pd_ < kMaxJumpM) {
      const int last = (int)(d / kStepM);
      for (; next_ <= last && next_ < nBin_[k]; ++next_) {
        const float db = next_ * kStepM;
        const float f = d > pd_ ? (db - pd_) / (d - pd_) : 1.f;
        const double eb = pe_ + (e - pe_) * (f < 0 ? 0 : (f > 1 ? 1 : f));
        cur_[off_[k] + next_] = cs(eb);
      }
      pd_ = d; pe_ = e;
    } else if (d > pd_) { pd_ = d; pe_ = e; }            // big jump (GNSS glitch): re-anchor, no samples
    // live delta vs the best profile of this sector
    hasRef_ = bestT_[k] > 0;
    if (!hasRef_) { delta_ = 0; behind_ = false; return; }
    delta_ = (float)(e - refAt(k, d));
    if (!behind_ && delta_ > kHystS) behind_ = true;
    else if (behind_ && delta_ <= 0) behind_ = false;
  }

  bool behind() const { return behind_; }                // false = purple, true = yellow
  bool hasRef() const { return hasRef_; }
  float delta() const { return delta_; }                 // s, + = slower than best
  int sector() const { return sec_; }
  uint32_t crossings() const { return crossN_; }          // sector-boundary crossings so far
  float crossX() const { return crossX_; }
  float crossY() const { return crossY_; }
  int crossSector() const { return crossSec_; }           // sector entered at the last crossing
  float bestOf(int k) const { return k >= 0 && k < nb_ ? bestT_[k] : 0; }
  static constexpr uint32_t bytes() { return sizeof(LiveDelta); }

 private:
  float secLen(int k) const { return bnd_[k + 1] - bnd_[k]; }
  static uint16_t cs(double t) { const double v = t * 100.0 + 0.5; return (uint16_t)(v < 0 ? 0 : (v > 65535 ? 65535 : v)); }
  float refAt(int k, float d) const {
    const float q = d / kStepM;
    int i = (int)q;
    if (i >= nBin_[k] - 1) i = nBin_[k] - 2;
    const float t = q - i;
    const uint16_t* b = best_ + off_[k];
    const float a = b[i] * 0.01f, z = b[i + 1] * 0.01f;
    return a + (z - a) * (t > 1 ? 1 : t);
  }
  void closeSector(const LapTimer& lt) {
    const int k = sec_;
    const float bt = lt.best(k);
    // LapTimer just accepted this pass as the new best (valid & faster): adopt its profile
    if (bt > 0 && (bestT_[k] == 0 || bt < bestT_[k] - 1e-4f) && next_ > 1) {
      const int n = nBin_[k];
      // fill the bins not reached (last <5 m, fixes lost) linearly up to (L, sector time)
      const float L = secLen(k);
      const int i0 = next_ - 1;
      const float d0 = i0 * kStepM, t0 = cur_[off_[k] + i0] * 0.01f;
      for (int i = next_; i < n; ++i) {
        float db = i * kStepM; if (db > L) db = L;
        const float f = L > d0 ? (db - d0) / (L - d0) : 1.f;
        cur_[off_[k] + i] = cs(t0 + (bt - t0) * f);
      }
      for (int i = 0; i < n; ++i) best_[off_[k] + i] = cur_[off_[k] + i];
      bestT_[k] = bt;
    }
  }

  float bnd_[kMaxSec + 1] = {};
  int nb_ = 0;
  int16_t off_[kMaxSec] = {}, nBin_[kMaxSec] = {};
  float bestT_[kMaxSec] = {};
  float lenM_ = 0;
  uint16_t best_[kMaxBins] = {}, cur_[kMaxBins] = {};
  int sec_ = -1, next_ = 0;
  float pd_ = 0; double pe_ = 0; bool havePrev_ = false;
  bool behind_ = false, hasRef_ = false;
  float delta_ = 0;
  uint32_t crossN_ = 0; float crossX_ = 0, crossY_ = 0; int crossSec_ = -1;
};

}  // namespace riderlab
