#include "PpsClock.h"

#include <esp_timer.h>

namespace riderlab {
namespace {

PpsClock* g_pps = nullptr;

void IRAM_ATTR ppsIsr() {
  if (g_pps) g_pps->onPulseFromIsr();
}

}  // namespace

void IRAM_ATTR PpsClock::onPulseFromIsr() {
  const int64_t now = esp_timer_get_time();
  const int64_t dt = now - lastUs_;
  if (lastUs_ > 0 && dt < 900000) {
    glitch_++;
    return;
  }
  if (lastUs_ > 0 && dt > 998000 && dt < 1002000) streak_++;
  else streak_ = 0;
  prevUs_ = lastUs_;
  lastUs_ = now;
  count_++;
  flag_ = true;
}

// 0.5.2: always a full re-arm (detach + pinMode + attach), so it is safe to call
// after every relink/hunt even on the same pin (a gpio_reset_pin() on the PPS
// pin silently drops its interrupt).
void PpsClock::begin(int pin) {
  if (attached_ && pin_ >= 0) detachInterrupt(digitalPinToInterrupt(pin_));
  attached_ = false;
  pin_ = pin;
  pinMode(pin_, INPUT);
  g_pps = this;
  noisy_ = false;
  lastGlitch_ = glitch_;
  attachInterrupt(digitalPinToInterrupt(pin_), ppsIsr, RISING);
  attached_ = true;
}

int64_t PpsClock::intervalUs() const {
  if (prevUs_ <= 0 || lastUs_ <= prevUs_) return -1;
  return lastUs_ - prevUs_;
}

bool PpsClock::consumeFlag() {
  noInterrupts();
  const bool f = flag_;
  flag_ = false;
  interrupts();
  return f;
}

bool PpsClock::good() const {
  if (!attached_ || noisy_) return false;
  if (streak_ < 3) return false;
  return (esp_timer_get_time() - lastUs_) < 1500000;
}

const char* PpsClock::state() const {
  if (noisy_) return "NOISE";
  if (good()) return "OK";
  if (count_ == 0) return "none";
  return "unlocked";
}

void PpsClock::service() {
  const uint32_t now = millis();
  if (now - lastServiceMs_ < 1000) return;
  lastServiceMs_ = now;
  const uint32_t g = glitch_;
  const uint32_t rate = g - lastGlitch_;
  lastGlitch_ = g;
  if (attached_ && rate > 200) {
    detachInterrupt(digitalPinToInterrupt(pin_));
    attached_ = false;
    noisy_ = true;
    streak_ = 0;
    detachedAtMs_ = now;
  } else if (!attached_ && noisy_ && now - detachedAtMs_ > 60000) {
    noisy_ = false;
    lastGlitch_ = glitch_;
    attachInterrupt(digitalPinToInterrupt(pin_), ppsIsr, RISING);
    attached_ = true;
  }
}

}  // namespace riderlab
