#pragma once

// 0.5.3 — HTTPS upload in its own FreeRTOS task (core 0, prio 1, 12 KB stack).
//
// Ownership / thread-safety:
//  - The task owns ONLY: Wi-Fi join, the TLS socket, and its own fixed buffers.
//  - The SD card (shared SPI bus with the LCD) is touched ONLY by loop():
//    the task asks for a chunk (offset,len) and loop() fills chunk_[] in
//    serviceIo(), then gives a semaphore. The loop never waits on the task.
//  - The task never calls Serial / gDiag / gLog / String; loop() logs phases
//    and the result (queue of fixed-size UploadResult).
//  - cancel(): flag checked between every chunk and every 20-50 ms wait; the
//    socket is closed (client.stop()) on cancel.
//
// Payload is byte-identical to <=0.5.2 (POST JSON to logger-ingest):
//   {"device_id":<esc>,"session_id":<esc>,"manifest":<first JSON object of
//    manifest.json (<=2048 B)>,"gnss_ndjson":"<escaped gnss.ndjson>"}
// but streamed from the SD in 1536 B chunks with Content-Length computed up front.
//
// 0.5.5 FIX (truncated uploads): <=0.5.4 sent only the first 24000 B of
// gnss.ndjson (kGnssMax) and still got HTTP 200, so the ride was marked
// cloud=1 with ~130 lines in Azure. Now the WHOLE file is streamed (cut only
// at the last complete line); kGnssMax is a sanity ceiling, never a silent cut.

#include <Arduino.h>
#include <SD.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <esp_heap_caps.h>
#include <esp_wifi.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <freertos/semphr.h>
#include <freertos/task.h>
#include <cstring>

namespace riderlab {

// 0.5.4: byte-addressable heap (what mbedTLS/lwIP can use). ESP.getFreeHeap()
// also counts ~43 KB of 32-bit-only IRAM, so it overstates usable memory.
struct Mem8 {
  uint32_t free, big, min;
};
inline Mem8 mem8() {
  return {(uint32_t)heap_caps_get_free_size(MALLOC_CAP_8BIT),
          (uint32_t)heap_caps_get_largest_free_block(MALLOC_CAP_8BIT),
          (uint32_t)heap_caps_get_minimum_free_size(MALLOC_CAP_8BIT)};
}

struct UploadJob {
  char sid[48] = "";
  char gnssPath[96] = "";
  uint32_t gnssRaw = 0;   // bytes of gnss.ndjson to send (whole file, last full line)
  uint32_t gnssFile = 0;  // 0.5.5: gnss.ndjson size at prepare time (SD)
  uint32_t gnssEsc = 0;   // escaped length of those bytes
  uint32_t total = 0;     // Content-Length
  char prefix[2400] = ""; // {"device_id":..,"session_id":..,"manifest":{..},"gnss_ndjson":"
  uint16_t prefixLen = 0;
  // network (copied from WifiUploader; secrets never logged)
  char ssid[4][33] = {};
  char pass[4][65] = {};
  uint8_t nSsid = 0;
  char host[80] = "";
  char path[128] = "/";
  char key[96] = "";
  char devId[48] = "";
};

struct UploadResult {
  char sid[48] = "";
  int http = 0;           // HTTP status, <=0 transport error
  bool cancelled = false;
  bool joined = false;
  uint32_t ms = 0;        // whole job
  uint32_t joinMs = 0, tlsMs = 0, sendMs = 0, waitMs = 0;
  uint32_t sent = 0;      // body bytes actually written
  uint32_t total = 0;     // Content-Length
  uint32_t chunks = 0;
  uint32_t heapStart = 0, heapMin = 0, heapPreTls = 0, largestPreTls = 0;
  // 0.5.4 8-bit heap around the TLS handshake (min8 = boot-wide low-water mark;
  // if min8PostTls < min8PreTls the new low was reached DURING TLS).
  uint32_t free8PreTls = 0, min8PreTls = 0, free8PostTls = 0, largestPostTls = 0,
           min8PostTls = 0;
  bool tlsTried = false, tlsOk = false;
  bool lowMem = false;    // skipped: largest 8-bit block < kTlsNeedLargest
  uint32_t cancelAckMs = 0;  // cancel() -> task noticed and closed socket
  int8_t rssi = 0;
  char phaseAtEnd[12] = "";
  char status[48] = "";
  char resp[64] = "";     // first bytes of the response body (no secrets)
  char ip[16] = "";
};

class UploadTask {
 public:
  static constexpr uint32_t kChunk = 1536;
  // 0.5.5: was 24000 (silent cut => truncated blobs). Now only a sanity ceiling:
  // a file above it is NOT sent partially; the ride stays pending and is logged.
  static constexpr uint32_t kGnssMax = 16UL * 1024UL * 1024UL;
  // 0.5.4: mbedTLS (Arduino 2.0.16) needs 2 x ~16.7 KB record buffers + ~8-9 KB
  // for Azure's 3-cert chain. Below this largest block the handshake can't finish.
  static constexpr uint32_t kTlsNeedLargest = 40000;

  enum Phase : uint8_t { IDLE, JOIN, TLS, SEND, WAIT, DONE };
  static const char* phaseName(uint8_t p) {
    switch (p) {
      case IDLE: return "idle";
      case JOIN: return "join";
      case TLS: return "tls";
      case SEND: return "send";
      case WAIT: return "wait";
      default: return "done";
    }
  }

  bool begin() {
    if (task_) return true;
    results_ = xQueueCreate(2, sizeof(UploadResult));
    chunkReady_ = xSemaphoreCreateBinary();
    if (!results_ || !chunkReady_) return false;
    // core 0, priority 1, 12 KB stack. NOT added to the task WDT (TLS can take seconds).
    return xTaskCreatePinnedToCore(&UploadTask::entry, "uploader", 12288, this, 1, &task_, 0) ==
           pdPASS;
  }

  bool busy() const { return busy_; }
  uint8_t phase() const { return phase_; }
  // ESP-IDF FreeRTOS returns the high-water mark in BYTES (0.5.3 multiplied by 4).
  uint32_t stackHighWater() const { return task_ ? uxTaskGetStackHighWaterMark(task_) : 0; }

  // loop(): start a prepared job. false if busy.
  bool start(const UploadJob& j) {
    if (busy_ || !task_) return false;
    job_ = j;
    cancel_ = false;
    cancelAtMs_ = 0;
    chunkState_ = 0;
    xSemaphoreTake(chunkReady_, 0);  // drop any stale give
    busy_ = true;
    phase_ = JOIN;
    xTaskNotifyGive(task_);
    return true;
  }

  // Any context: request cancellation (non-blocking).
  void cancel() {
    if (!busy_ || cancel_) return;
    cancelAtMs_ = millis();
    cancel_ = true;
  }
  bool cancelRequested() const { return cancel_; }

  // loop(): pop a finished job result.
  bool takeResult(UploadResult& r) { return results_ && xQueueReceive(results_, &r, 0) == pdTRUE; }

  // loop() ONLY: serve a pending SD chunk request (the SD/SPI bus stays loop-owned).
  void serviceIo() {
    if (chunkState_ != 1) return;
    const uint32_t seq = reqSeq_, off = reqOff_, len = reqLen_;
    int32_t got = -1;
    File f = SD.open(job_.gnssPath, FILE_READ);
    if (f) {
      if (f.seek(off)) got = f.read(chunk_, len);
      f.close();
    }
    gotLen_ = got;
    gotSeq_ = seq;
    chunkState_ = 2;
    ioServed_++;
    xSemaphoreGive(chunkReady_);
  }
  uint32_t ioServed() const { return ioServed_; }

  // loop(): split https://host/path into the job.
  static bool parseUrl(const char* u, UploadJob& j) {
    const char* s = strstr(u, "://");
    s = s ? s + 3 : u;
    const char* slash = strchr(s, '/');
    const size_t hl = slash ? (size_t)(slash - s) : strlen(s);
    if (!hl || hl >= sizeof(j.host)) return false;
    memcpy(j.host, s, hl);
    j.host[hl] = 0;
    snprintf(j.path, sizeof(j.path), "%s", slash ? slash : "/");
    return true;
  }

  // ---- payload helpers (also used by loop() to prepare a job) ----
  static inline uint8_t escLen(uint8_t c) {
    if (c == '\\' || c == '"' || c == '\n' || c == '\r') return 2;
    return c >= 0x20 ? 1 : 0;
  }
  static size_t escape(const uint8_t* in, size_t n, char* out) {
    size_t o = 0;
    for (size_t i = 0; i < n; ++i) {
      const uint8_t c = in[i];
      if (c == '\\' || c == '"') {
        out[o++] = '\\';
        out[o++] = (char)c;
      } else if (c == '\n') {
        out[o++] = '\\';
        out[o++] = 'n';
      } else if (c == '\r') {
        out[o++] = '\\';
        out[o++] = 'r';
      } else if (c >= 0x20) {
        out[o++] = (char)c;
      }
    }
    return o;
  }

 private:
  static void entry(void* arg) {
    UploadTask* self = static_cast<UploadTask*>(arg);
    for (;;) {
      ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
      UploadResult r;
      self->run(r);
      self->phase_ = DONE;
      xQueueSend(self->results_, &r, 0);
      self->busy_ = false;
      self->phase_ = IDLE;
    }
  }

  void heapTick(UploadResult& r) {
    const uint32_t h = ESP.getFreeHeap();
    if (!r.heapMin || h < r.heapMin) r.heapMin = h;
  }

  bool cancelled(UploadResult& r) {
    if (!cancel_) return false;
    r.cancelled = true;
    return true;
  }

  void finishCancel(UploadResult& r, WiFiClientSecure* cli) {
    if (cli) cli->stop();  // close the socket on cancel
    r.cancelled = true;
    if (!r.cancelAckMs) r.cancelAckMs = cancelAtMs_ ? millis() - cancelAtMs_ : 1;
    strncpy(r.status, "cancelled", sizeof(r.status) - 1);
  }

  bool waitMs(UploadResult& r, uint32_t ms) {
    const uint32_t t0 = millis();
    while (millis() - t0 < ms) {
      if (cancelled(r)) return false;
      vTaskDelay(pdMS_TO_TICKS(20));
    }
    return !cancelled(r);
  }

  bool linkUp() const { return WiFi.status() == WL_CONNECTED && WiFi.localIP()[0] != 0; }

  bool join(UploadResult& r) {
    phase_ = JOIN;
    const uint32_t t0 = millis();
    if (linkUp()) {
      r.joined = true;
      return true;
    }
    WiFi.persistent(false);
    WiFi.mode(WIFI_STA);
    WiFi.setSleep(false);
    wifi_country_t mx = {"MX", 1, 13, 20, WIFI_COUNTRY_POLICY_MANUAL};
    esp_wifi_set_country(&mx);
    for (uint8_t i = 0; i < job_.nSsid && !r.joined; ++i) {
      if (cancelled(r)) return false;
      WiFi.disconnect(true, false);
      if (!waitMs(r, 80)) return false;
      WiFi.begin(job_.ssid[i], job_.pass[i]);
      const uint32_t tj = millis();
      while (millis() - tj < 12000) {
        if (linkUp()) {
          r.joined = true;
          break;
        }
        if (!waitMs(r, 50)) return false;
      }
    }
    r.joinMs = millis() - t0;
    return r.joined;
  }

  // Ask loop() for a chunk; wait (cancellable) for it.
  int32_t fetch(UploadResult& r, uint32_t off, uint32_t len) {
    reqOff_ = off;
    reqLen_ = len;
    reqSeq_ = reqSeq_ + 1;
    chunkState_ = 1;
    const uint32_t t0 = millis();
    for (;;) {
      if (cancelled(r)) {
        chunkState_ = 0;
        return -2;
      }
      if (xSemaphoreTake(chunkReady_, pdMS_TO_TICKS(25)) == pdTRUE) {
        if (gotSeq_ == reqSeq_) {
          chunkState_ = 0;
          return gotLen_;
        }
      }
      if (millis() - t0 > 10000) {  // loop busy (e.g. long serial DUMP)
        chunkState_ = 0;
        return -1;
      }
    }
  }

  bool writeAll(WiFiClientSecure& cli, UploadResult& r, const uint8_t* p, size_t n) {
    size_t o = 0;
    while (o < n) {
      if (cancelled(r)) return false;
      const size_t w = cli.write(p + o, n - o);
      if (w == 0 || w > n - o) return false;  // socket error / bogus count
      o += w;
    }
    r.sent += n;
    return true;
  }


  void run(UploadResult& r) {
    const uint32_t t0 = millis();
    strncpy(r.sid, job_.sid, sizeof(r.sid) - 1);
    r.total = job_.total;
    r.heapStart = ESP.getFreeHeap();
    heapTick(r);
    if (!join(r)) {
      if (r.cancelled) {
        finishCancel(r, nullptr);
      } else {
        strncpy(r.status, "wifi fail", sizeof(r.status) - 1);
      }
      snprintf(r.phaseAtEnd, sizeof(r.phaseAtEnd), "%s", phaseName(phase_));
      r.ms = millis() - t0;
      return;
    }
    r.rssi = (int8_t)WiFi.RSSI();
    {
      const IPAddress ip = WiFi.localIP();
      snprintf(r.ip, sizeof(r.ip), "%u.%u.%u.%u", ip[0], ip[1], ip[2], ip[3]);
    }
    heapTick(r);
    for (int attempt = 0; attempt < 2; ++attempt) {
      if (attempt && !waitMs(r, 400)) break;
      r.sent = 0;
      r.chunks = 0;
      r.http = post(r);
      if (r.cancelled || r.http > 0 || r.lowMem) break;  // answered, cancelled or low memory
    }
    if (r.cancelled) {
      finishCancel(r, nullptr);
    } else if (r.http >= 200 && r.http < 300 && r.sent == r.total) {
      strncpy(r.status, "uploaded", sizeof(r.status) - 1);
    } else if (r.http >= 200 && r.http < 300) {  // 0.5.5: 2xx but body short => NOT uploaded
      snprintf(r.status, sizeof(r.status), "short %lu/%lu", (unsigned long)r.sent,
               (unsigned long)r.total);
      r.http = -5;
    } else if (!r.status[0]) {
      snprintf(r.status, sizeof(r.status), r.http > 0 ? "HTTP %d" : "HTTPS %d", r.http);
    }
    snprintf(r.phaseAtEnd, sizeof(r.phaseAtEnd), "%s", phaseName(phase_));
    r.ms = millis() - t0;
  }

  int post(UploadResult& r) {
    phase_ = TLS;
    const uint32_t tt = millis();
    r.heapPreTls = ESP.getFreeHeap();
    {
      const Mem8 m = mem8();
      r.largestPreTls = m.big;
      r.free8PreTls = m.free;
      r.min8PreTls = m.min;
    }
    // 0.5.4: no handshake that can only fail (and fragment the heap further).
    // Ride stays pending; loop() logs "upload SKIP lowmem" and backs off.
    if (r.largestPreTls < kTlsNeedLargest) {
      r.lowMem = true;
      r.tlsMs = millis() - tt;
      snprintf(r.status, sizeof(r.status), "memoria baja");
      return -20;
    }
    WiFiClientSecure cli;
    cli.setInsecure();
    cli.setHandshakeTimeout(15);
    cli.setTimeout(20);  // seconds (socket send/recv)
    if (cancelled(r)) return -100;
    r.tlsTried = true;
    const bool tlsUp = cli.connect(job_.host, 443, 12000);
    {
      const Mem8 m = mem8();
      r.free8PostTls = m.free;
      r.largestPostTls = m.big;
      r.min8PostTls = m.min;
      r.tlsOk = tlsUp;
    }
    if (!tlsUp) {
      r.tlsMs = millis() - tt;
      heapTick(r);
      if (cancelled(r)) {
        finishCancel(r, &cli);
        return -100;
      }
      snprintf(r.status, sizeof(r.status), "HTTPS no enlace");
      return -1;
    }
    r.tlsMs = millis() - tt;
    heapTick(r);
    if (cancelled(r)) {
      finishCancel(r, &cli);
      return -100;
    }
    // ---- headers + body ----
    phase_ = SEND;
    const uint32_t ts = millis();
    int hl = snprintf(hdr_, sizeof(hdr_),
                      "POST %s HTTP/1.1\r\nHost: %s\r\nUser-Agent: riderlab-logger\r\n"
                      "Content-Type: application/json\r\nConnection: close\r\n"
                      "Content-Length: %lu\r\n",
                      job_.path, job_.host, (unsigned long)job_.total);
    if (job_.key[0]) hl += snprintf(hdr_ + hl, sizeof(hdr_) - hl, "X-Logger-Key: %s\r\n", job_.key);
    if (job_.devId[0])
      hl += snprintf(hdr_ + hl, sizeof(hdr_) - hl, "X-Device-Id: %s\r\n", job_.devId);
    hl += snprintf(hdr_ + hl, sizeof(hdr_) - hl, "\r\n");
    bool ok = hl > 0 && hl < (int)sizeof(hdr_) &&
              cli.write((const uint8_t*)hdr_, hl) == (size_t)hl;
    memset(hdr_, 0, sizeof(hdr_));  // header held the key
    if (ok) ok = writeAll(cli, r, (const uint8_t*)job_.prefix, job_.prefixLen);
    uint32_t off = 0;
    while (ok && off < job_.gnssRaw) {
      const uint32_t want = (job_.gnssRaw - off) > kChunk ? kChunk : (job_.gnssRaw - off);
      const int32_t got = fetch(r, off, want);
      if (got == -2) {
        ok = false;
        break;
      }
      if (got != (int32_t)want) {
        snprintf(r.status, sizeof(r.status), "sd chunk fail off=%lu got=%ld", (unsigned long)off,
                 (long)got);
        ok = false;
        break;
      }
      const size_t n = escape(chunk_, (size_t)got, esc_);
      ok = writeAll(cli, r, (const uint8_t*)esc_, n);
      off += (uint32_t)got;
      r.chunks++;
      heapTick(r);
      vTaskDelay(1);  // let IDLE0 run (task WDT)
    }
    if (ok && off != job_.gnssRaw) {  // 0.5.5: every gnss byte must have been sent
      snprintf(r.status, sizeof(r.status), "gnss short %lu/%lu", (unsigned long)off,
               (unsigned long)job_.gnssRaw);
      ok = false;
    }
    if (ok) ok = writeAll(cli, r, (const uint8_t*)"\"}", 2);
    r.sendMs = millis() - ts;
    if (r.cancelled) {
      finishCancel(r, &cli);
      return -100;
    }
    if (!ok) {
      cli.stop();
      if (!r.status[0]) snprintf(r.status, sizeof(r.status), "HTTPS cortado");
      return -4;
    }
    if (r.sent != job_.total) {  // must never happen: Content-Length bug guard
      cli.stop();
      snprintf(r.status, sizeof(r.status), "len mismatch %lu/%lu", (unsigned long)r.sent,
               (unsigned long)job_.total);
      return -3;
    }
    // ---- response ----
    phase_ = WAIT;
    const uint32_t tw = millis();
    size_t rl = 0;
    resp_[0] = 0;  // no stale response from a previous attempt/job
    int code = -11;
    bool gotStatus = false;
    uint32_t lastData = millis();
    while (millis() - tw < 30000) {
      if (cancelled(r)) {
        finishCancel(r, &cli);
        return -100;
      }
      int a = cli.available();
      if (a > 0) {
        while (a-- > 0 && rl < sizeof(resp_) - 1) {
          const int c = cli.read();
          if (c < 0) break;
          resp_[rl++] = (char)c;
        }
        resp_[rl] = 0;
        lastData = millis();
        if (!gotStatus && strstr(resp_, "\r\n")) {
          int maj = 0, mnr = 0, st = 0;
          if (sscanf(resp_, "HTTP/%d.%d %d", &maj, &mnr, &st) == 3) {
            code = st;
            gotStatus = true;
          }
        }
        if (rl >= sizeof(resp_) - 1) break;
      } else {
        if (!cli.connected()) break;
        if (gotStatus && millis() - lastData > 1500) break;
        vTaskDelay(pdMS_TO_TICKS(20));
      }
    }
    r.waitMs = millis() - tw;
    const char* body = strstr(resp_, "\r\n\r\n");
    if (body) snprintf(r.resp, sizeof(r.resp), "%s", body + 4);
    for (char* p = r.resp; *p; ++p)
      if (*p == '\r' || *p == '\n') *p = ' ';
    cli.stop();
    heapTick(r);
    if (!gotStatus) {
      snprintf(r.status, sizeof(r.status), "HTTPS timeout");
      return -11;
    }
    return code;
  }

 private:
  TaskHandle_t task_ = nullptr;
  QueueHandle_t results_ = nullptr;
  SemaphoreHandle_t chunkReady_ = nullptr;
  UploadJob job_;
  volatile bool busy_ = false;
  volatile bool cancel_ = false;
  volatile uint32_t cancelAtMs_ = 0;
  volatile uint8_t phase_ = IDLE;
  volatile uint8_t chunkState_ = 0;  // 0 idle, 1 requested (task), 2 served (loop)
  volatile uint32_t reqOff_ = 0, reqLen_ = 0, reqSeq_ = 0, gotSeq_ = 0;
  volatile int32_t gotLen_ = 0;
  uint32_t ioServed_ = 0;
  uint8_t chunk_[kChunk];
  char esc_[kChunk * 2];
  char hdr_[512];
  char resp_[512];
};

}  // namespace riderlab
