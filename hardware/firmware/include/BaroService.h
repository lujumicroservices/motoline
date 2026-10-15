#pragma once

// BMP280 (M135, 0x76) — own driver: one 6-byte burst per sample + Bosch
// integer compensation (datasheet BST-BMP280-DS001 §3.11.3, 64-bit pressure).
// Normal mode "handheld dynamic" (table 7): osrs_p x4, osrs_t x1, IIR 16,
// t_sb 0.5 ms → ~83 Hz ODR. Same settings in RIDER and ANCHOR so the
// differential barometry (rider vs anchor) cancels sensor dynamics.
#include <Arduino.h>
#include <Wire.h>
#include <cmath>
#include <esp_timer.h>

namespace riderlab {

struct BaroSample {
  double pa = 0;      // mean pressure over the window (Pa)
  float tempC = 0;    // die temperature (°C) — NOT air temperature
  float altM = 0;     // ISA altitude (p0 = 101325 Pa)
  uint16_t n = 0;     // raw reads averaged
  int64_t midUs = 0;  // esp_timer at the window midpoint
};

class BaroService {
 public:
  static constexpr uint8_t kCtrlMeas = (1 << 5) | (3 << 2) | 3;  // T x1, P x4, normal
  static constexpr uint8_t kConfig = (0 << 5) | (4 << 2);        // t_sb 0.5 ms, IIR 16

  bool begin(TwoWire& wire, uint8_t addr) {
    wire_ = &wire;
    addr_ = addr;
    uint8_t id = 0;
    if (!readBytes(0xD0, &id, 1) || id != 0x58) {
      ready_ = false;
      return false;
    }
    write8(0xE0, 0xB6);  // soft reset
    delay(10);
    uint8_t c[24];
    if (!readBytes(0x88, c, 24)) return false;
    T1 = (uint16_t)(c[1] << 8 | c[0]);
    T2 = (int16_t)(c[3] << 8 | c[2]);
    T3 = (int16_t)(c[5] << 8 | c[4]);
    P1 = (uint16_t)(c[7] << 8 | c[6]);
    P2 = (int16_t)(c[9] << 8 | c[8]);
    P3 = (int16_t)(c[11] << 8 | c[10]);
    P4 = (int16_t)(c[13] << 8 | c[12]);
    P5 = (int16_t)(c[15] << 8 | c[14]);
    P6 = (int16_t)(c[17] << 8 | c[16]);
    P7 = (int16_t)(c[19] << 8 | c[18]);
    P8 = (int16_t)(c[21] << 8 | c[20]);
    P9 = (int16_t)(c[23] << 8 | c[22]);
    write8(0xF4, kCtrlMeas & ~0x03);  // sleep while writing config
    write8(0xF5, kConfig);
    write8(0xF4, kCtrlMeas);
    delay(60);
    ready_ = P1 != 0;
    return ready_;
  }

  bool ready() const { return ready_; }

  // 0.6.9g DORMIR: sleep mode (~0.1 uA); begin() resets and reconfigures on boot.
  void suspend() {
    if (!ready_) return;
    write8(0xF4, kCtrlMeas & ~0x03);
    ready_ = false;
  }

  // One raw read; accumulates into the current window. Call at BARO_SAMPLE_HZ.
  bool sample() {
    if (!ready_) return false;
    uint8_t b[6];
    if (!readBytes(0xF7, b, 6)) {
      errors_++;
      return false;
    }
    const int32_t adcP = ((int32_t)b[0] << 12) | ((int32_t)b[1] << 4) | (b[2] >> 4);
    const int32_t adcT = ((int32_t)b[3] << 12) | ((int32_t)b[4] << 4) | (b[5] >> 4);
    if (adcP == 0x80000 || adcT == 0x80000) {  // measurement skipped
      errors_++;
      return false;
    }
    int32_t tFine;
    const float t = compT(adcT, tFine);
    const double p = compP(adcP, tFine);
    if (p < 30000 || p > 110000) {
      errors_++;
      return false;
    }
    const int64_t now = esp_timer_get_time();
    if (n_ == 0) firstUs_ = now;
    lastUs_ = now;
    sumP_ += p;
    sumT_ += t;
    n_++;
    lastPa_ = p;
    lastT_ = t;
    return true;
  }

  // Close the window and return the mean (false if empty).
  bool take(BaroSample& out) {
    if (n_ == 0) return false;
    out.pa = sumP_ / n_;
    out.tempC = (float)(sumT_ / n_);
    out.altM = isaAlt(out.pa);
    out.n = n_;
    out.midUs = firstUs_ + (lastUs_ - firstUs_) / 2;
    sumP_ = sumT_ = 0;
    n_ = 0;
    return true;
  }

  // Back-compat for callers that want hPa only.
  bool readHpa(float& hpa) {
    if (!sample()) return false;
    hpa = (float)(lastPa_ / 100.0);
    return true;
  }

  double lastPa() const { return lastPa_; }
  float lastTempC() const { return lastT_; }
  uint32_t errors() const { return errors_; }

  static float isaAlt(double pa) {
    return (float)(44330.77 * (1.0 - pow(pa / 101325.0, 0.190263)));
  }

 private:
  float compT(int32_t adc, int32_t& tFine) const {
    int32_t v1 = ((((adc >> 3) - ((int32_t)T1 << 1))) * ((int32_t)T2)) >> 11;
    int32_t v2 = (((((adc >> 4) - ((int32_t)T1)) * ((adc >> 4) - ((int32_t)T1))) >> 12) *
                  ((int32_t)T3)) >> 14;
    tFine = v1 + v2;
    return ((tFine * 5 + 128) >> 8) / 100.0f;
  }

  double compP(int32_t adc, int32_t tFine) const {
    int64_t v1 = ((int64_t)tFine) - 128000;
    int64_t v2 = v1 * v1 * (int64_t)P6;
    v2 = v2 + ((v1 * (int64_t)P5) << 17);
    v2 = v2 + (((int64_t)P4) << 35);
    v1 = ((v1 * v1 * (int64_t)P3) >> 8) + ((v1 * (int64_t)P2) << 12);
    v1 = (((((int64_t)1) << 47) + v1)) * ((int64_t)P1) >> 33;
    if (v1 == 0) return 0;
    int64_t p = 1048576 - adc;
    p = (((p << 31) - v2) * 3125) / v1;
    v1 = (((int64_t)P9) * (p >> 13) * (p >> 13)) >> 25;
    v2 = (((int64_t)P8) * p) >> 19;
    p = ((p + v1 + v2) >> 8) + (((int64_t)P7) << 4);
    return p / 256.0;
  }

  bool write8(uint8_t reg, uint8_t val) {
    wire_->beginTransmission(addr_);
    wire_->write(reg);
    wire_->write(val);
    return wire_->endTransmission() == 0;
  }

  bool readBytes(uint8_t reg, uint8_t* out, size_t n) {
    wire_->beginTransmission(addr_);
    wire_->write(reg);
    if (wire_->endTransmission(false) != 0) return false;
    if (wire_->requestFrom(addr_, (uint8_t)n) != n) return false;
    for (size_t i = 0; i < n; i++) out[i] = wire_->read();
    return true;
  }

  TwoWire* wire_ = nullptr;
  uint8_t addr_ = 0x76;
  bool ready_ = false;
  uint16_t T1 = 0, P1 = 0;
  int16_t T2 = 0, T3 = 0, P2 = 0, P3 = 0, P4 = 0, P5 = 0, P6 = 0, P7 = 0, P8 = 0, P9 = 0;
  double sumP_ = 0, sumT_ = 0;
  uint16_t n_ = 0;
  int64_t firstUs_ = 0, lastUs_ = 0;
  double lastPa_ = 0;
  float lastT_ = 0;
  uint32_t errors_ = 0;
};

}  // namespace riderlab
