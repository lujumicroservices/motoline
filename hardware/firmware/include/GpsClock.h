#pragma once

// Maps esp_timer (t_us) to GPS time-of-week (ms) so baro/IMU samples from two
// units can be aligned to the same GPS instant.
//  - "pps": PPS rising edge is the top of a GPS second; the NAV-PVT with
//    iTOW%1000==0 that arrives 0..700 ms later names that second.
//  - "rx":  no good PPS: PVT arrival time (UART latency of a few tens of ms).
#include <Arduino.h>
#include <esp_timer.h>

#include "PpsClock.h"
#include "UbxParser.h"

namespace riderlab {

class GpsClock {
 public:
  static constexpr double kWeekMs = 604800000.0;

  void onPvt(const UbxPvt& p, const PpsClock& pps) {
    if (!p.timeOk()) return;
    rxUs_ = p.rxUs;
    rxTow_ = p.iTOW;
    haveRx_ = true;
    if (pps.good() && (p.iTOW % 1000) == 0) {
      const int64_t edge = pps.lastUs();
      const int64_t lag = p.rxUs - edge;
      if (lag >= 0 && lag < 700000) {
        ppsUs_ = edge;
        ppsTow_ = p.iTOW;
        havePps_ = true;
        lastLagUs_ = (int32_t)lag;
      }
    }
  }

  // Returns tow in ms (or -1) and the source tag.
  double towAt(int64_t tUs, const char** src) const {
    if (havePps_ && llabs(tUs - ppsUs_) < 3000000LL) {
      *src = "pps";
      return wrap(ppsTow_ + (tUs - ppsUs_) / 1000.0);
    }
    if (haveRx_ && llabs(tUs - rxUs_) < 5000000LL) {
      *src = "rx";
      return wrap(rxTow_ + (tUs - rxUs_) / 1000.0);
    }
    *src = "none";
    return -1;
  }

  int32_t lastLagUs() const { return lastLagUs_; }
  bool ppsLocked() const { return havePps_; }

 private:
  static double wrap(double t) {
    if (t < 0) t += kWeekMs;
    if (t >= kWeekMs) t -= kWeekMs;
    return t;
  }
  int64_t ppsUs_ = 0, rxUs_ = 0;
  uint32_t ppsTow_ = 0, rxTow_ = 0;
  bool havePps_ = false, haveRx_ = false;
  int32_t lastLagUs_ = -1;
};

}  // namespace riderlab
