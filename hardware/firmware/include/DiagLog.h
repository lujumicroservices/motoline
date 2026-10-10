#pragma once

// 0.5.1-diag — field diagnostics for "second recording won't start" and
// "GNSS link lost -> RXnn hunt never re-locks".
// Call sites only format into a RAM queue (+ Serial echo); service() appends
// the queue to /riderlab/diag.log from loop() at most every kFlushMs (one
// open/append/close per batch). Size-capped: diag.log -> diag.1.log at kRotateBytes.
// Line format:  D <millis> <tag> <message> heap=<free>
// Serial: DIAG (tail 24 KB) · DIAG ALL · DIAGCLR

#include <Arduino.h>
#include <SD.h>
#include <cstdarg>
#include <cstring>

#include "HardwareConfig.h"

namespace riderlab {

class DiagLog {
 public:
  static constexpr const char* kPath = "/riderlab/diag.log";
  static constexpr const char* kOld = "/riderlab/diag.1.log";
  static constexpr size_t kRotateBytes = 512 * 1024;
  static constexpr size_t kQueue = 8192;
  static constexpr uint32_t kFlushMs = 2000;

  void logf(const char* tag, const char* fmt, ...) {
    char msg[440];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(msg, sizeof(msg), fmt, ap);
    va_end(ap);
    char line[500];
    int n = snprintf(line, sizeof(line), "D %lu %s %s heap=%u\n", (unsigned long)millis(), tag,
                     msg, (unsigned)ESP.getFreeHeap());
    if (n <= 0) return;
    if (n >= (int)sizeof(line)) {
      n = sizeof(line) - 1;
      line[n - 1] = '\n';
      line[n] = 0;
    }
    Serial.print(line);
    lines_++;
    if (qLen_ + (size_t)n > kQueue) {
      dropped_++;
      return;
    }
    memcpy(q_ + qLen_, line, n);
    qLen_ += n;
  }

  // From loop(): batched append. Returns ms spent on SD (0 when nothing done).
  uint32_t service(uint32_t nowMs, bool sdOk, bool force = false) {
    if (!sdOk || (qLen_ == 0 && dropped_ == 0)) return 0;
    if (!force && nowMs - lastFlushMs_ < kFlushMs && qLen_ < kQueue / 2) return 0;
    const uint32_t t0 = millis();
    lastFlushMs_ = nowMs;
    if (!sizeKnown_) {  // once per boot; then tracked (append-mode size() is unreliable)
      fileBytes_ = fileSize(true);
      sizeKnown_ = true;
    }
    if (fileBytes_ > kRotateBytes) {
      SD.remove(kOld);
      SD.rename(kPath, kOld);
      fileBytes_ = 0;
      rotations_++;
    }
    File f = SD.open(kPath, FILE_APPEND);
    if (!f) {
      writeFails_++;
      if (qLen_ > kQueue * 3 / 4) {  // never let the queue wedge
        dropped_ += 1;
        qLen_ = 0;
      }
      return millis() - t0;
    }
    if (dropped_) {
      fileBytes_ += f.printf("D %lu diag dropped=%lu (queue full)\n", (unsigned long)nowMs,
                             (unsigned long)dropped_);
      dropped_ = 0;
    }
    if (qLen_) f.write((const uint8_t*)q_, qLen_);
    f.close();
    fileBytes_ += qLen_;
    written_ += qLen_;
    qLen_ = 0;
    lastWriteMs_ = millis() - t0;
    return lastWriteMs_;
  }

  void dump(bool sdOk, bool all) {
    service(millis(), sdOk, true);
    Serial.println("DIAG BEGIN");
    Serial.printf("DIAG lines=%lu written=%lu fails=%lu rot=%lu queued=%u last_write_ms=%lu\n",
                  (unsigned long)lines_, (unsigned long)written_, (unsigned long)writeFails_,
                  (unsigned long)rotations_, (unsigned)qLen_, (unsigned long)lastWriteMs_);
    if (!sdOk) {
      Serial.println("DIAG no SD");
    } else {
      if (all) dumpFile(kOld, 0);
      dumpFile(kPath, all ? 0 : 24000);
    }
    Serial.println("DIAG END");
  }

  void clear(bool sdOk) {
    qLen_ = 0;
    dropped_ = 0;
    if (sdOk) {
      SD.remove(kOld);
      SD.remove(kPath);
    }
    fileBytes_ = 0;
    sizeKnown_ = true;
    logf("diag", "cleared");
  }

  uint32_t fileSize(bool sdOk) {
    if (!sdOk || !SD.exists(kPath)) return 0;
    File f = SD.open(kPath, FILE_READ);
    if (!f) return 0;
    const uint32_t s = f.size();
    f.close();
    return s;
  }

 private:
  static void dumpFile(const char* path, size_t tail) {
    if (!SD.exists(path)) {
      Serial.printf("DIAG (%s missing)\n", path);
      return;
    }
    File f = SD.open(path, FILE_READ);
    if (!f) {
      Serial.printf("DIAG (%s missing)\n", path);
      return;
    }
    const size_t sz = f.size();
    Serial.printf("DIAG file %s size=%u\n", path, (unsigned)sz);
    if (tail && sz > tail) f.seek(sz - tail);
    uint8_t buf[256];
    while (f.available()) {
      const int n = f.read(buf, sizeof(buf));
      if (n <= 0) break;
      Serial.write(buf, n);
      wdtFeed();
    }
    f.close();
  }

  char q_[kQueue];
  size_t qLen_ = 0;
  uint32_t fileBytes_ = 0;
  bool sizeKnown_ = false;
  uint32_t lastFlushMs_ = 0, lastWriteMs_ = 0;
  uint32_t lines_ = 0, written_ = 0, dropped_ = 0, writeFails_ = 0, rotations_ = 0;
};

inline DiagLog gDiag;

}  // namespace riderlab
