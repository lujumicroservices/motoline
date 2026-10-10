#pragma once

#include <Arduino.h>
#include <Wire.h>

namespace riderlab {

extern const uint8_t kBmi270Config[];
extern const size_t kBmi270ConfigLen;

// BMI270 over host I2C (M135 module, 0x69), datasheet init sequence:
// soft reset -> adv. power save off -> upload the 8 KB config image -> INIT_CTRL=1 ->
// INTERNAL_STATUS==init_ok -> enable acc/gyr. Without the config image the BMI270
// leaves the data registers at 0 (what 0.4.9 did: |a| = 0).
// Output: accel m/s^2 (±8 g, 4096 LSB/g), gyro rad/s (±1000 dps, 32.768 LSB/dps).
class ImuService {
 public:
  bool begin(TwoWire& wire, uint8_t addr) {
    wire_ = &wire;
    addr_ = addr;
    ready_ = false;
    chipId_ = read8(0x00);
    if (chipId_ != 0x24) chipId_ = read8(0x00);  // first access after power-up may fail
    if (chipId_ != 0x24) {
      snprintf(status_, sizeof(status_), "chip_id=0x%02X (want 0x24)", chipId_);
      return false;
    }
    write8(0x7E, 0xB6);  // CMD: soft reset
    delay(5);
    read8(0x00);         // dummy read after reset
    write8(0x7C, 0x00);  // PWR_CONF: advanced power save off
    delayMicroseconds(1000);
    write8(0x59, 0x00);  // INIT_CTRL: prepare config load
    const bool up = uploadConfig();
    write8(0x59, 0x01);  // INIT_CTRL: start
    uint8_t st = 0;
    for (int i = 0; i < 30; i++) {  // datasheet: <= 20 ms
      delay(2);
      st = read8(0x21) & 0x0F;      // INTERNAL_STATUS.message
      if (st == 0x01) break;
    }
    internal_ = st;
    if (!up || st != 0x01) {
      snprintf(status_, sizeof(status_), "config %s, internal_status=0x%02X", up ? "sent" : "i2c-fail", st);
      return false;
    }
    write8(0x40, 0xA8);  // ACC_CONF: filter_perf, normal avg, ODR 100 Hz
    write8(0x41, 0x02);  // ACC_RANGE: ±8 g (bike impacts exceed 4 g)
    write8(0x42, 0xA9);  // GYR_CONF: filter_perf, normal, ODR 200 Hz
    write8(0x43, 0x01);  // GYR_RANGE: ±1000 dps
    write8(0x7D, 0x0E);  // PWR_CTRL: acc + gyr + temp on
    write8(0x7C, 0x02);  // PWR_CONF: adv power save off, fifo self-wake on
    delay(50);           // first samples (gyro start-up ~45 ms)
    const uint8_t err = read8(0x02);
    snprintf(status_, sizeof(status_), "config ok, err=0x%02X", err);
    ready_ = true;
    return true;
  }

  bool ready() const { return ready_; }
  const char* status() const { return status_; }
  uint8_t chipId() const { return chipId_; }

  bool read(float& ax, float& ay, float& az, float& gx, float& gy, float& gz) {
    if (!ready_ || !wire_) return false;
    uint8_t buf[12];
    if (!readBytes(0x0C, buf, 12)) return false;  // DATA_8..DATA_19: acc xyz, gyr xyz
    const int16_t rax = (int16_t)((buf[1] << 8) | buf[0]);
    const int16_t ray = (int16_t)((buf[3] << 8) | buf[2]);
    const int16_t raz = (int16_t)((buf[5] << 8) | buf[4]);
    const int16_t rgx = (int16_t)((buf[7] << 8) | buf[6]);
    const int16_t rgy = (int16_t)((buf[9] << 8) | buf[8]);
    const int16_t rgz = (int16_t)((buf[11] << 8) | buf[10]);
    constexpr float G = 9.80665f;
    constexpr float DEG2RAD = 0.01745329252f;
    ax = (rax / 4096.0f) * G;
    ay = (ray / 4096.0f) * G;
    az = (raz / 4096.0f) * G;
    gx = (rgx / 32.768f) * DEG2RAD;
    gy = (rgy / 32.768f) * DEG2RAD;
    gz = (rgz / 32.768f) * DEG2RAD;
    return true;
  }

 private:
  bool uploadConfig() {
    // Arduino-ESP32 Wire buffer is 128 B: send in 64 B bursts, each preceded by the
    // word address (INIT_ADDR_0 = (idx/2)&0x0F, INIT_ADDR_1 = (idx/2)>>4).
    constexpr size_t kChunk = 64;
    for (size_t idx = 0; idx < kBmi270ConfigLen; idx += kChunk) {
      const size_t n = (kBmi270ConfigLen - idx) < kChunk ? (kBmi270ConfigLen - idx) : kChunk;
      const uint16_t w = idx / 2;
      wire_->beginTransmission(addr_);
      wire_->write(0x5B);
      wire_->write((uint8_t)(w & 0x0F));
      wire_->write((uint8_t)(w >> 4));
      if (wire_->endTransmission() != 0) return false;
      wire_->beginTransmission(addr_);
      wire_->write(0x5E);
      wire_->write(kBmi270Config + idx, n);
      if (wire_->endTransmission() != 0) return false;
    }
    return true;
  }

  uint8_t read8(uint8_t reg) {
    uint8_t v = 0;
    return readBytes(reg, &v, 1) ? v : 0;
  }

  bool write8(uint8_t reg, uint8_t val) {
    wire_->beginTransmission(addr_);
    wire_->write(reg);
    wire_->write(val);
    const bool ok = wire_->endTransmission() == 0;
    delayMicroseconds(500);  // >= 450 us between writes while power save may be active
    return ok;
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
  uint8_t addr_ = 0x69;
  bool ready_ = false;
  uint8_t chipId_ = 0;
  uint8_t internal_ = 0;
  char status_[64] = "not started";
};

}  // namespace riderlab
