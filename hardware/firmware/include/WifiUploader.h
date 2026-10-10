#pragma once

#include <Arduino.h>
#include <HTTPClient.h>
#include <SD.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <Preferences.h>
#include <esp_wifi.h>

#include "HardwareConfig.h"
#include "RideIndex.h"
#include "EventLog.h"
#include "UploadTask.h"

namespace riderlab {

// Post-session Wi‑Fi uploader. Does not run during recording.
class WifiUploader {
 public:
  void loadPrefs() {
    prefs_.begin("riderlab", true);
    ssid_ = prefs_.getString("wifi_ssid", "");
    ssid2_ = prefs_.getString("wifi_ssid2", "");
    pass_ = prefs_.getString("wifi_pass", "");
    ingestUrl_ = prefs_.getString("ingest_url", "");
    deviceId_ = prefs_.getString("device_id", "");
    deviceSecret_ = prefs_.getString("device_secret", "");
    // Two network slots (0.5.1): A = legacy keys (active), B = previous network
    // kept for reference but disabled. Missing flags keep legacy behaviour.
    aEn_ = prefs_.getBool("wifi_a_en", true);
    bSsid_ = prefs_.getString("wifi_b_ssid", "");
    bSsid2_ = prefs_.getString("wifi_b_ssid2", "");
    bPass_ = prefs_.getString("wifi_b_pass", "");
    bEn_ = prefs_.getBool("wifi_b_en", false);
    prefs_.end();
    if (ingestUrl_.isEmpty()) ingestUrl_ = AZURE_INGEST_URL;
  }

  void saveWifi(const String& ssid, const String& pass, const String& ssid2 = "") {
    String a = ssid, b = ssid2;
    // ESP32 Basic is 2.4 GHz only — keep the non-5G name first.
    if (a.indexOf("5G") >= 0 && b.length() && b.indexOf("5G") < 0) {
      const String tmp = a;
      a = b;
      b = tmp;
    }
    prefs_.begin("riderlab", false);
    prefs_.putString("wifi_ssid", a);
    prefs_.putString("wifi_ssid2", b);
    prefs_.putString("wifi_pass", pass);
    prefs_.end();
    ssid_ = a;
    ssid2_ = b;
    pass_ = pass;
  }

  // WIFISET: new network becomes the active slot A; the previous slot-A network
  // (if any) moves to slot B with enabled=false (kept, never used to connect).
  void setActiveKeepOld(const String& ssid, const String& pass) {
    prefs_.begin("riderlab", false);
    if (ssid_.length() && ssid_ != ssid) {
      bSsid_ = ssid_;
      bSsid2_ = ssid2_;
      bPass_ = pass_;
      bEn_ = false;
      prefs_.putString("wifi_b_ssid", bSsid_);
      prefs_.putString("wifi_b_ssid2", bSsid2_);
      prefs_.putString("wifi_b_pass", bPass_);
      prefs_.putBool("wifi_b_en", false);
    }
    ssid_ = ssid;
    ssid2_ = "";
    pass_ = pass;
    aEn_ = true;
    prefs_.putString("wifi_ssid", ssid_);
    prefs_.putString("wifi_ssid2", "");
    prefs_.putString("wifi_pass", pass_);
    prefs_.putBool("wifi_a_en", true);
    prefs_.end();
  }

  // 0.6.8-ble: RAM snapshot of every Wi-Fi slot key, taken before a BLE WIFI write (serial WIFIUNDO
  // puts it back). Lost on reboot; nothing is printed.
  struct WifiSnap {
    bool ok = false, aEn = true, bEn = false;
    String ssid, ssid2, pass, bSsid, bSsid2, bPass;
  };
  WifiSnap snapshotWifi() const {
    WifiSnap s;
    s.ok = true; s.aEn = aEn_; s.bEn = bEn_;
    s.ssid = ssid_; s.ssid2 = ssid2_; s.pass = pass_;
    s.bSsid = bSsid_; s.bSsid2 = bSsid2_; s.bPass = bPass_;
    return s;
  }
  void restoreWifi(const WifiSnap& s) {
    if (!s.ok) return;
    prefs_.begin("riderlab", false);
    prefs_.putString("wifi_ssid", s.ssid);
    prefs_.putString("wifi_ssid2", s.ssid2);
    prefs_.putString("wifi_pass", s.pass);
    prefs_.putBool("wifi_a_en", s.aEn);
    prefs_.putString("wifi_b_ssid", s.bSsid);
    prefs_.putString("wifi_b_ssid2", s.bSsid2);
    prefs_.putString("wifi_b_pass", s.bPass);
    prefs_.putBool("wifi_b_en", s.bEn);
    prefs_.end();
    ssid_ = s.ssid; ssid2_ = s.ssid2; pass_ = s.pass; aEn_ = s.aEn;
    bSsid_ = s.bSsid; bSsid2_ = s.bSsid2; bPass_ = s.bPass; bEn_ = s.bEn;
  }
  // paired = a real device id (not "unpaired") and a stored secret
  bool paired() const { return deviceId_.length() && deviceId_ != "unpaired" && deviceSecret_.length(); }
  String deviceIdMasked() const {
    if (!deviceId_.length()) return "";
    if (deviceId_.length() <= 6) return deviceId_;
    return deviceId_.substring(0, 4) + "..." + deviceId_.substring(deviceId_.length() - 2);
  }

  static String mask(const String& p) {
    return p.length() ? String("********(") + p.length() + ")" : String("(none)");
  }
  // Password is never printed (masked).
  void printSlots() const {
    Serial.printf("WIFI A ssid=%s ssid2=%s pass=%s enabled=%d %s\n", ssid_.c_str(),
                  ssid2_.c_str(), mask(pass_).c_str(), (int)aEn_,
                  (aEn_ && ssid_.length()) ? "ACTIVE" : "INACTIVE");
    Serial.printf("WIFI B ssid=%s ssid2=%s pass=%s enabled=%d %s\n",
                  bSsid_.length() ? bSsid_.c_str() : "(none)", bSsid2_.c_str(),
                  mask(bPass_).c_str(), (int)bEn_,
                  (bEn_ && bSsid_.length()) ? "ACTIVE" : "INACTIVE");
  }
  const String& oldSsid() const { return bSsid_; }
  bool slotAEnabled() const { return aEn_; }
  bool slotBEnabled() const { return bEn_; }

  void saveCredentials(const String& deviceId, const String& secret,
                       const String& ingestUrl) {
    prefs_.begin("riderlab", false);
    prefs_.putString("device_id", deviceId);
    prefs_.putString("device_secret", secret);
    prefs_.putString("ingest_url", ingestUrl);
    prefs_.end();
    deviceId_ = deviceId;
    deviceSecret_ = secret;
    ingestUrl_ = ingestUrl;
  }

  bool wifiReady() const {
    return (aEn_ && ssid_.length() > 0) || (bEn_ && bSsid_.length() > 0);
  }
  bool configured() const {
    return wifiReady() && ingestUrl_.length() > 0 && deviceSecret_.length() > 0;
  }

  const String& lastStatus() const { return status_; }
  const String& deviceId() const { return deviceId_; }
  const String& ssid() const { return ssid_; }
  void setIndex(RideIndex* idx) { index_ = idx; }

  int dumpScan() {
    prepareRadio();
    wdtFeed();
    const int n = WiFi.scanNetworks(false, true);
    Serial.printf("WIFI SCAN %d\n", n);
    for (int i = 0; i < n; ++i) {
      Serial.printf("  AP %s  ch=%d  rssi=%d\n", WiFi.SSID(i).c_str(),
                    WiFi.channel(i), WiFi.RSSI(i));
    }
    if (n <= 0) Serial.println("  (ninguna red 2.4 GHz)");
    WiFi.scanDelete();
    wdtFeed();
    return n;
  }

  // ---- 0.5.3: copy network + endpoint into a fixed-buffer job for UploadTask.
  // Only ENABLED slots; same order/rules as connect()/trySsid(). Secrets stay in
  // the job buffers and are never logged.
  bool fillJobNet(UploadJob& j) const {
    j.nSsid = 0;
    auto add = [&](const String& ssid, const String& pass) {
      if (ssid.isEmpty() || ssid.indexOf("5G") >= 0 || j.nSsid >= 4) return;
      snprintf(j.ssid[j.nSsid], sizeof(j.ssid[0]), "%s", ssid.c_str());
      snprintf(j.pass[j.nSsid], sizeof(j.pass[0]), "%s", pass.c_str());
      j.nSsid++;
    };
    if (aEn_) {
      add(ssid_, pass_);
      add(ssid2_, pass_);
    }
    if (bEn_) {
      add(bSsid_, bPass_);
      add(bSsid2_, bPass_);
    }
    snprintf(j.key, sizeof(j.key), "%s", deviceSecret_.c_str());
    snprintf(j.devId, sizeof(j.devId), "%s", deviceId_.c_str());
    return j.nSsid > 0 && UploadTask::parseUrl(ingestUrl_.c_str(), j) && j.key[0];
  }
  bool keepLocal() const { return keepLocal_; }

  // ---- 0.5.2: non-blocking pre-join scan --------------------------------------
  // Start an async scan (returns immediately). Poll with scanPoll():
  // WIFI_SCAN_RUNNING (-1) while running, WIFI_SCAN_FAILED (-2) or count when done.
  bool startScan() {
    prepareRadio();
    WiFi.scanDelete();
    const int r = WiFi.scanNetworks(true, true, false, 120);
    return r == WIFI_SCAN_RUNNING || r >= 0;
  }
  int scanPoll() const { return WiFi.scanComplete(); }
  void scanDone() { WiFi.scanDelete(); }
  // True when an ENABLED slot SSID is in the last scan result (n entries).
  bool enabledSsidSeen(int n, String& which, int& rssi) const {
    for (int i = 0; i < n; ++i) {
      const String s = WiFi.SSID(i);
      if (!s.length()) continue;
      const bool hit = (aEn_ && (s == ssid_ || (ssid2_.length() && s == ssid2_))) ||
                       (bEn_ && (s == bSsid_ || (bSsid2_.length() && s == bSsid2_)));
      if (hit) {
        which = s;
        rssi = WiFi.RSSI(i);
        return true;
      }
    }
    return false;
  }
  // M5Stack Basic buttons A/B/C = GPIO39/38/37, active LOW. Read raw so a long
  // join can be abandoned as soon as the rider presses any button.
  static bool buttonDown() {
    return digitalRead(39) == LOW || digitalRead(38) == LOW || digitalRead(37) == LOW;
  }

  bool connect(uint32_t timeoutMs = 12000, bool scanFirst = false) {
    if (gotIp(200)) {
      status_ = "wifi ok";
      return true;
    }
    if (!wifiReady()) {
      status_ = "no wifi ssid";
      loge("wifi", "no enabled ssid");
      return false;
    }
    if (scanFirst) dumpScan();
    // Only enabled slots are ever joined.
    const bool ok = (aEn_ && (trySsid(ssid_, pass_, timeoutMs) || trySsid(ssid2_, pass_, timeoutMs))) ||
                    (bEn_ && (trySsid(bSsid_, bPass_, timeoutMs) || trySsid(bSsid2_, bPass_, timeoutMs)));
    if (ok) {
      WiFi.setAutoReconnect(true);
      status_ = "wifi ok";
      gLog.logf(LogLvl::Info, "wifi", "ok ip=%s rssi=%d",
                WiFi.localIP().toString().c_str(), WiFi.RSSI());
      return true;
    }
    status_ = aborted_ ? "wifi abort" : "wifi fail";
    gLog.logf(LogLvl::Error, "wifi", "join %s ssid=%s", aborted_ ? "aborted (button)" : "fail",
              ssid_.c_str());
    return false;
  }

  // 0.5.2: with a ride index, the index is the single source of truth (the
  // upload queue only walks the index; a SD-dir scan that disagreed made the
  // loop retry forever, and it ran an SD directory walk on every loop()).
  bool hasPending() const {
    if (index_) return index_->hasLocalPending();
    File root = SD.open("/riderlab/sessions");
    if (!root) return false;
    bool found = false;
    for (File e = root.openNextFile(); e; e = root.openNextFile()) {
      if (!e.isDirectory()) {
        e.close();
        continue;
      }
      const String dir = String("/riderlab/sessions/") + e.name();
      e.close();
      if (fileHasData(dir + "/gnss.ndjson") && !SD.exists(dir + "/uploaded.ok")) {
        found = true;
        break;
      }
    }
    root.close();
    return found;
  }

  int uploadAllPending() {
    if (!configured()) {
      status_ = "missing creds";
      loge("azure", "missing creds");
      return 0;
    }
    if (!hasPending()) {
      status_ = "nothing pending";
      return 0;
    }
    gLog.logf(LogLvl::Info, "azure", "queue start pending=%d",
              index_ ? index_->pendingCount() : -1);
    if (!connect(12000, false)) return 0;
    int n = 0;
    if (index_) {
      const int total = index_->count();
      for (int i = 0; i < total; ++i) {
        const RideRec r = index_->at(i);
        if (r.cloud || r.gnss == 0 || !r.id[0]) continue;
        const String dir = String("/riderlab/sessions/") + r.id;
        if (!fileHasData(dir + "/gnss.ndjson")) {
          gLog.logf(LogLvl::Warn, "azure", "skip no gnss %s", r.id);
          index_->markNoUpload(r.id);
          continue;
        }
        if (buttonDown()) {  // 0.5.2: rider wants the buttons back
          gLog.logf(LogLvl::Warn, "azure", "queue stopped by button");
          break;
        }
        status_ = String("up ") + (n + 1);
        wdtFeed();
        if (uploadSession(dir, String(r.id))) n++;
      }
    } else {
      while (hasPending()) {
        if (!uploadNextPending()) break;
        n++;
        wdtFeed();
        if (n >= 24) break;
      }
    }
    if (n > 0) {
      status_ = String("Azure ") + n;
      gLog.logf(LogLvl::Info, "azure", "done ok=%d", n);
    } else if (status_ == "wifi ok" || status_.startsWith("up ")) {
      status_ = "upload fail";
      loge("azure", "queue empty result");
    }
    return n;
  }

  // LEGACY (<=0.5.2, not called since 0.5.3; uploads go through UploadTask).
  // NOTE: this path still caps gnss at 24000 B — do not re-enable it.
  // Reads NDJSON files from sessionDir and POSTs JSON payload to ingest URL.
  bool uploadSession(const String& sessionDir, const String& sessionId) {
    if (!configured()) {
      status_ = "missing creds";
      return false;
    }
    if (!connect(12000, false)) return false;

    String manifest = firstJsonObject(readFile(sessionDir + "/manifest.json", 2048));
    String gnss = readFile(sessionDir + "/gnss.ndjson", 24000);
    if (gnss.length() >= 24000) {
      const int cut = gnss.lastIndexOf('\n');
      if (cut > 16) gnss.remove(cut + 1);
    }
    if (gnss.length() < 16) {
      if (index_) index_->markNoUpload(sessionId);
      else markDone(sessionDir, "skip empty gnss");
      status_ = "skip empty";
      gLog.logf(LogLvl::Warn, "azure", "empty gnss %s", sessionId.c_str());
      return false;
    }
    if (manifest.length() < 2) {
      manifest = "{\"schema\":\"riderlab_logger.v1\",\"session_id\":\"";
      manifest += sessionId;
      manifest += "\"}";
    }

    String body;
    const String did = deviceId_.length() ? deviceId_ : "unpaired";
    if (!body.reserve(gnss.length() + manifest.length() + 96)) {
      status_ = "json oom";
      loge("azure", "json oom");
      return false;
    }
    body += "{\"device_id\":";
    appendEscaped(body, did);
    body += ",\"session_id\":";
    appendEscaped(body, sessionId);
    body += ",\"manifest\":";
    body += manifest;
    body += ",\"gnss_ndjson\":";
    appendEscaped(body, gnss);
    body += "}";

    int code = 0;
    String resp;
    for (int attempt = 0; attempt < 3; ++attempt) {
      if (attempt) {
        wdtFeed();
        delay(400);
        connect(8000, false);
      }
      if (attempt == 0) warmHttps();
      code = postJson(body, resp);
      if (code >= 200 && code < 300) break;
      if (code > 0) break;  // server answered (400/401) — retry won't help
      status_ = httpMeaning(code);
    }
    if (code < 200 || code >= 300) {
      status_ = httpMeaning(code);
      if (resp.length()) {
        status_ += " ";
        status_ += resp.substring(0, 40);
      }
      gLog.logf(LogLvl::Error, "https", "%s id=%s", status_.c_str(),
                sessionId.c_str());
      return false;
    }
    gLog.logf(LogLvl::Info, "https", "200 id=%s bytes=%u", sessionId.c_str(),
              (unsigned)body.length());
    status_ = "uploaded";
    // KEEPSD ON (always in anchor role): keep pvt/sat/baro/anchor files on SD
    // for post-processing; only gnss.ndjson (<=24 KB) goes to the cloud.
    if (index_ && keepLocal_) {
      index_->markCloudKeep(sessionId);
      markDone(sessionDir, "uploaded-kept");
    } else if (index_) {
      index_->markCloudAndDelete(sessionId, sessionDir);
    } else {
      markDone(sessionDir, "uploaded");
    }
    return true;
  }

  // One pending session per call (has gnss.ndjson, no uploaded.ok).
  bool uploadNextPending() {
    if (!configured()) {
      status_ = "missing creds";
      return false;
    }
    if (index_) {
      const String sid = index_->pendingId();
      if (sid.length()) {
        return uploadSession(String("/riderlab/sessions/") + sid, sid);
      }
    }
    File root = SD.open("/riderlab/sessions");
    if (!root) {
      status_ = "no sessions";
      return false;
    }
    bool ok = false;
    for (File e = root.openNextFile(); e; e = root.openNextFile()) {
      if (!e.isDirectory()) {
        e.close();
        continue;
      }
      const String sid = String(e.name());
      const String dir = String("/riderlab/sessions/") + sid;
      e.close();
      if (SD.exists(dir + "/uploaded.ok")) continue;
      if (!fileHasData(dir + "/gnss.ndjson")) {
        markDone(dir, "skip empty gnss");
        continue;
      }
      ok = uploadSession(dir, sid);
      break;
    }
    root.close();
    if (!ok && status_ == "idle") status_ = "nothing pending";
    return ok;
  }

 private:
  void prepareRadio() {
    WiFi.persistent(false);
    WiFi.mode(WIFI_STA);
    WiFi.setSleep(false);
    wifi_country_t mx = {"MX", 1, 13, 20, WIFI_COUNTRY_POLICY_MANUAL};
    esp_wifi_set_country(&mx);
  }

  bool gotIp(uint32_t waitMs) {
    const uint32_t t0 = millis();
    aborted_ = false;
    while (millis() - t0 < waitMs) {
      if (WiFi.status() == WL_CONNECTED && WiFi.localIP()[0]) return true;
      if (waitMs > 1000 && buttonDown()) {  // 0.5.2: don't hold the buttons hostage
        aborted_ = true;
        return false;
      }
      wdtFeed();
      delay(80);
    }
    return WiFi.status() == WL_CONNECTED && WiFi.localIP()[0];
  }

  bool trySsid(const String& ssid, const String& pass, uint32_t timeoutMs) {
    if (ssid.isEmpty() || ssid.indexOf("5G") >= 0 || aborted_) return false;
    if (WiFi.status() == WL_CONNECTED && WiFi.SSID() == ssid && WiFi.localIP()[0]) {
      return true;
    }
    prepareRadio();
    WiFi.disconnect(true, false);
    delay(80);
    wdtFeed();
    WiFi.begin(ssid.c_str(), pass.c_str());
    return gotIp(timeoutMs);
  }

  static String httpMeaning(int code) {
    if (code == -1) return "HTTPS no enlace";
    if (code == -2) return "HTTPS header";
    if (code == -3) return "HTTPS payload";
    if (code == -4 || code == -5) return "HTTPS cortado";
    if (code == -8) return "HTTPS RAM";
    if (code == -11) return "HTTPS timeout";
    if (code == 401) return "clave Azure";
    if (code == 400) return "JSON Azure";
    if (code == 404) return "Azure 404";
    if (code <= 0) return String("HTTPS ") + code;
    return String("HTTP ") + code;
  }

  void attachHeaders(HTTPClient& http) {
    http.addHeader("Content-Type", "application/json");
    if (deviceSecret_.length()) http.addHeader("X-Logger-Key", deviceSecret_);
    if (deviceId_.length()) http.addHeader("X-Device-Id", deviceId_);
  }

  bool warmHttps() {
    WiFiClientSecure cli;
    cli.setInsecure();
    cli.setTimeout(15000);
    HTTPClient http;
    http.setTimeout(12000);
    http.setReuse(false);
    if (!http.begin(cli, ingestUrl_)) return false;
    attachHeaders(http);
    wdtHold();
    const int code = http.GET();
    wdtRelease();
    http.end();
    gLog.logf(code == -1 ? LogLvl::Error : LogLvl::Info, "https", "warm %d",
              code);
    return code != -1;
  }

  int postJson(const String& body, String& resp) {
    WiFiClientSecure cli;
    cli.setInsecure();
    cli.setTimeout(25000);
    HTTPClient http;
    http.setTimeout(25000);
    http.setReuse(false);
    if (!http.begin(cli, ingestUrl_)) {
      resp = "";
      return -1;
    }
    attachHeaders(http);
    wdtHold();
    const int code = http.POST(body);
    resp = http.getString();
    http.end();
    wdtRelease();
    Serial.printf("HTTPS POST %d bytes=%u\n", code, (unsigned)body.length());
    return code;
  }

  static bool fileHasData(const String& path) {
    File f = SD.open(path, FILE_READ);
    if (!f) return false;
    const size_t n = f.size();
    f.close();
    return n > 16;
  }

  static void markDone(const String& dir, const char* note) {
    File ok = SD.open(dir + "/uploaded.ok", FILE_WRITE);
    if (ok) {
      ok.println(note);
      ok.close();
    }
  }

  static String readFile(const String& path, size_t maxBytes = 32768) {
    File f = SD.open(path, FILE_READ);
    if (!f) return "";
    String out;
    const size_t n = f.size() < maxBytes ? (size_t)f.size() : maxBytes;
    out.reserve(n + 8);
    while (f.available() && (size_t)out.length() < maxBytes) {
      out += (char)f.read();
      if ((out.length() & 0x1FF) == 0) wdtFeed();
    }
    f.close();
    return out;
  }

  static String firstJsonObject(String s) {
    s.trim();
    const int a = s.indexOf('{');
    if (a < 0) return "{}";
    int depth = 0;
    for (int i = a; i < (int)s.length(); ++i) {
      const char c = s[i];
      if (c == '{') depth++;
      else if (c == '}') {
        depth--;
        if (depth == 0) return s.substring(a, i + 1);
      }
    }
    return "{}";
  }

  static void appendEscaped(String& out, const String& raw) {
    out += '"';
    for (size_t i = 0; i < raw.length(); i++) {
      const char c = raw[i];
      if (c == '\\' || c == '"') {
        out += '\\';
        out += c;
      } else if (c == '\n') {
        out += "\\n";
      } else if (c == '\r') {
        out += "\\r";
      } else if ((uint8_t)c >= 0x20) {
        out += c;
      }
      if ((i & 0x1FF) == 0) wdtFeed();
    }
    out += '"';
  }

  Preferences prefs_;
  bool keepLocal_ = false;

 public:
  void setKeepLocal(bool v) { keepLocal_ = v; }

 private:
  RideIndex* index_ = nullptr;
  bool aEn_ = true, bEn_ = false;
  bool aborted_ = false;
  String bSsid_, bSsid2_, bPass_;
  String ssid_, ssid2_, pass_, ingestUrl_, deviceId_, deviceSecret_, status_ = "idle";
};

}  // namespace riderlab
