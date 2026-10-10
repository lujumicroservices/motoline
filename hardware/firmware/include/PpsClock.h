#pragma once

#include <Arduino.h>
#include <cstdint>

namespace riderlab {

// PPS on GPIO34 (input-only, no pull). A floating pin (DIP not routed, module
// absent) produces thousands of edges/s, so the ISR rejects edges < 900 ms
// after the last accepted one, and main() detaches it when the glitch rate is
// absurd. good() = 3+ consecutive 1 s ±2 ms intervals and recent.
class PpsClock {
 public:
  void begin(int pin);
  uint32_t count() const { return count_; }
  int64_t lastUs() const { return lastUs_; }
  int64_t intervalUs() const;
  bool consumeFlag();
  uint32_t seq() const { return count_; }
  uint32_t glitches() const { return glitch_; }
  bool good() const;
  bool attached() const { return attached_; }
  int pin() const { return pin_; }
  const char* state() const;
  // Call ~1 Hz from loop(): detach on noise, retry every 60 s.
  void service();

  void onPulseFromIsr();

 private:
  int pin_ = -1;
  volatile uint32_t count_ = 0;
  volatile uint32_t glitch_ = 0;
  volatile uint32_t streak_ = 0;
  volatile int64_t lastUs_ = 0;
  volatile int64_t prevUs_ = 0;
  volatile bool flag_ = false;
  bool attached_ = false;
  bool noisy_ = false;
  uint32_t lastGlitch_ = 0;
  uint32_t lastServiceMs_ = 0;
  uint32_t detachedAtMs_ = 0;
};

}  // namespace riderlab
