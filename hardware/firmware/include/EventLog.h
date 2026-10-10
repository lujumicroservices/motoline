#pragma once

#include <Arduino.h>
#include <SD.h>
#include <cstdarg>
#include <cstring>
#include <esp_system.h>

#include "HardwareConfig.h"

namespace riderlab {

enum class LogLvl : uint8_t { Debug = 0, Info = 1, Warn = 2, Error = 3 };

// Production event log: Serial always, SD after mount. GNSS 1 Hz stays off this file.
class EventLog {
 public:
  static constexpr const char* kPath = "/riderlab/events.ndjson";
  static constexpr const char* kBak = "/riderlab/events.bak.ndjson";
  static constexpr size_t kRotateBytes = 120000;
  static constexpr int kRing = 20;

  void beginSd() {
    sd_ = true;
    if (!SD.exists("/riderlab")) SD.mkdir("/riderlab");
    flushRing();
    rotateIfNeeded();
  }

  bool sdReady() const { return sd_; }
  const char* lastError() const { return lastErr_; }

  void log(LogLvl lvl, const char* tag, const char* msg) {
    sanitize(msg);
    const char* lv = lvlStr(lvl);
    char line[200];
    snprintf(line, sizeof(line),
             "{\"t\":%lu,\"lvl\":\"%s\",\"tag\":\"%s\",\"msg\":\"%s\",\"heap\":%u}",
             (unsigned long)millis(), lv, tag, msg_, ESP.getFreeHeap());
    Serial.println(line);
    if (lvl == LogLvl::Error) {
      strncpy(lastErr_, msg_, sizeof(lastErr_) - 1);
      lastErr_[sizeof(lastErr_) - 1] = 0;
    }
    const bool dup = sameAsLast(tag, msg_) && (millis() - lastWriteMs_ < 20000);
    strncpy(lastTag_, tag, sizeof(lastTag_) - 1);
    strncpy(lastMsg_, msg_, sizeof(lastMsg_) - 1);
    if (dup) return;
    lastWriteMs_ = millis();
    if (sd_) writeLine(line);
    else pushRing(line);
  }

  void logf(LogLvl lvl, const char* tag, const char* fmt, ...) {
    char msg[140];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(msg, sizeof(msg), fmt, ap);
    va_end(ap);
    log(lvl, tag, msg);
  }

  void dumpTail() {
    Serial.println("LOG BEGIN");
    if (!sd_ || !SD.exists(kPath)) {
      Serial.println("LOG empty");
      Serial.println("LOG END");
      return;
    }
    File f = SD.open(kPath, FILE_READ);
    if (!f) {
      Serial.println("LOG open fail");
      Serial.println("LOG END");
      return;
    }
    const size_t sz = f.size();
    if (sz > 12000) f.seek(sz - 12000);
    while (f.available()) {
      Serial.write((char)f.read());
      wdtFeed();
    }
    f.close();
    Serial.println();
    Serial.println("LOG END");
  }

  void clear() {
    if (SD.exists(kBak)) SD.remove(kBak);
    if (SD.exists(kPath)) SD.remove(kPath);
    nRing_ = 0;
    lastErr_[0] = 0;
    log(LogLvl::Info, "log", "cleared");
  }

  static const char* resetName(esp_reset_reason_t r) {
    switch (r) {
      case ESP_RST_POWERON:
        return "poweron";
      case ESP_RST_SW:
        return "software";
      case ESP_RST_PANIC:
        return "panic";
      case ESP_RST_INT_WDT:
        return "int_wdt";
      case ESP_RST_TASK_WDT:
        return "task_wdt";
      case ESP_RST_WDT:
        return "wdt";
      case ESP_RST_BROWNOUT:
        return "brownout";
      case ESP_RST_SDIO:
        return "sdio";
      default:
        return "other";
    }
  }

 private:
  static const char* lvlStr(LogLvl l) {
    if (l == LogLvl::Error) return "E";
    if (l == LogLvl::Warn) return "W";
    if (l == LogLvl::Debug) return "D";
    return "I";
  }

  void sanitize(const char* msg) {
    size_t o = 0;
    for (size_t i = 0; msg && msg[i] && o + 1 < sizeof(msg_); ++i) {
      const char c = msg[i];
      if (c == '"' || c == '\\') msg_[o++] = '\'';
      else if ((uint8_t)c >= 0x20 && (uint8_t)c < 0x7f)
        msg_[o++] = c;
      else if (c == '\n') msg_[o++] = ' ';
    }
    msg_[o] = 0;
  }

  bool sameAsLast(const char* tag, const char* msg) const {
    return strcmp(lastTag_, tag) == 0 && strcmp(lastMsg_, msg) == 0;
  }

  void pushRing(const char* line) {
    strncpy(ring_[ringHead_], line, sizeof(ring_[0]) - 1);
    ring_[ringHead_][sizeof(ring_[0]) - 1] = 0;
    ringHead_ = (ringHead_ + 1) % kRing;
    if (nRing_ < kRing) nRing_++;
  }

  void flushRing() {
    if (!nRing_) return;
    const int start = (ringHead_ + kRing - nRing_) % kRing;
    for (int i = 0; i < nRing_; ++i) writeLine(ring_[(start + i) % kRing]);
    nRing_ = 0;
  }

  void writeLine(const char* line) {
    rotateIfNeeded();
    File f = SD.open(kPath, FILE_APPEND);
    if (!f) return;
    f.println(line);
    f.flush();
    f.close();
  }

  void rotateIfNeeded() {
    File f = SD.open(kPath, FILE_READ);
    if (!f) return;
    const size_t sz = f.size();
    f.close();
    if (sz < kRotateBytes) return;
    if (SD.exists(kBak)) SD.remove(kBak);
    SD.rename(kPath, kBak);
  }

  bool sd_ = false;
  int nRing_ = 0;
  int ringHead_ = 0;
  uint32_t lastWriteMs_ = 0;
  char ring_[kRing][200] = {};
  char msg_[140] = {};
  char lastTag_[16] = {};
  char lastMsg_[140] = {};
  char lastErr_[80] = {};
};

inline EventLog gLog;

inline void logi(const char* tag, const char* msg) { gLog.log(LogLvl::Info, tag, msg); }
inline void logw(const char* tag, const char* msg) { gLog.log(LogLvl::Warn, tag, msg); }
inline void loge(const char* tag, const char* msg) { gLog.log(LogLvl::Error, tag, msg); }

}  // namespace riderlab
