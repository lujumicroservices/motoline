// 0.6.8-ble: Bluetooth LE pairing mode (NimBLE). Off by default; started only from Menu > EMPAREJAR (or
// serial BLE PAIR on the bench), never while recording or with Wi-Fi in use. Stops by itself after 3 min,
// after 5 wrong PINs, or after a successful PAIR, with a full NimBLE deinit (heap returned).
//
// GATT service 6f8a0001-5c3e-4b8e-9a51-4d4554524943 ("METRIC"):
//   ...0002 INFO   read    {"hw","fw","role","paired","device_id"(masked),"mtu","authed"}
//   ...0003 AUTH   write   6-digit PIN shown on the device screen (must come first)
//   ...0004 PAIR   write   {"device_id","secret"|"device_secret","ingest_url"} -> same store as serial PAIR
//   ...0005 WIFI   write   {"ssid","pass"} -> same as serial WIFISET
//   ...0006 STATUS notify  {"ok":true|false,"msg"|"err":...}
// Long payloads: a value may be sent whole (ATT long write is fine) or in fragments
// [0x1E][index][total][bytes...] (index 0..total-1, reassembled up to 600 bytes).
// Callbacks run in the NimBLE host task: they only copy bytes; all logic runs in loop() via take().
#pragma once
#include <Arduino.h>
#include <NimBLEDevice.h>

namespace riderlab {

class BlePair {
 public:
  static constexpr const char* kSvc = "6f8a0001-5c3e-4b8e-9a51-4d4554524943";
  static constexpr const char* kInfo = "6f8a0002-5c3e-4b8e-9a51-4d4554524943";
  static constexpr const char* kAuth = "6f8a0003-5c3e-4b8e-9a51-4d4554524943";
  static constexpr const char* kPair = "6f8a0004-5c3e-4b8e-9a51-4d4554524943";
  static constexpr const char* kWifi = "6f8a0005-5c3e-4b8e-9a51-4d4554524943";
  static constexpr const char* kStatus = "6f8a0006-5c3e-4b8e-9a51-4d4554524943";
  static constexpr uint32_t kTimeoutMs = 180000;
  static constexpr int kMaxBadPin = 5;
  static constexpr size_t kMaxPayload = 600;
  enum Kind : uint8_t { K_NONE = 0, K_AUTH, K_PAIR, K_WIFI };
  struct Msg {
    uint8_t kind = K_NONE;
    uint16_t len = 0;
    char data[kMaxPayload + 1] = {};
  };

  bool on() const { return on_; }
  bool connected() const { return conn_; }
  uint16_t mtu() const { return mtu_; }
  uint32_t connects() const { return nConn_; }

  bool begin(const char* name) {
    if (on_) return true;
    if (!buf_) buf_ = (Bufs*)calloc(1, sizeof(Bufs));  // 0.6.8: heap only while pairing
    if (!buf_) return false;
    self_ = this;
    NimBLEDevice::init(name);
    NimBLEDevice::setPower(ESP_PWR_LVL_P3);
    NimBLEDevice::setMTU(247);
    srv_ = NimBLEDevice::createServer();
    if (!srv_) { NimBLEDevice::deinit(true); freeBufs(); return false; }
    srv_->setCallbacks(&srvCb_, false);
    srv_->advertiseOnDisconnect(false);  // restarted by onDisconnect unless stopping
    stopping_ = false;
    NimBLEService* s = srv_->createService(kSvc);
    info_ = s->createCharacteristic(kInfo, NIMBLE_PROPERTY::READ);
    auto* a = s->createCharacteristic(kAuth, NIMBLE_PROPERTY::WRITE);
    auto* p = s->createCharacteristic(kPair, NIMBLE_PROPERTY::WRITE, kMaxPayload);
    auto* w = s->createCharacteristic(kWifi, NIMBLE_PROPERTY::WRITE, kMaxPayload);
    status_ = s->createCharacteristic(kStatus, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);
    cbA_.kind = K_AUTH; cbP_.kind = K_PAIR; cbW_.kind = K_WIFI;
    a->setCallbacks(&cbA_); p->setCallbacks(&cbP_); w->setCallbacks(&cbW_);
    status_->setValue(std::string("{\"ok\":true,\"msg\":\"ready\"}"));
    s->start();
    NimBLEAdvertising* adv = NimBLEDevice::getAdvertising();
    adv->addServiceUUID(kSvc);
    adv->setScanResponse(true);
    adv->setName(name);
    on_ = adv->start();
    if (!on_) { NimBLEDevice::deinit(true); srv_ = nullptr; freeBufs(); return false; }
    conn_ = false; mtu_ = 23; nConn_ = 0;
    return true;
  }
  void end() {
    if (!on_) return;
    on_ = false;
    stopping_ = true;
    NimBLEDevice::getAdvertising()->stop();
    // a connected central must be gone before the host is torn down (deinit with a live link panicked)
    if (srv_) for (uint16_t h : srv_->getPeerDevices()) srv_->disconnect(h);
    const uint32_t t0 = millis();
    while (conn_ && millis() - t0 < 1500) delay(10);
    delay(50);
    self_ = nullptr;  // callbacks become no-ops from here
    NimBLEDevice::deinit(true);  // controller + host off, all GATT objects freed
    srv_ = nullptr; info_ = status_ = nullptr; conn_ = false;
    freeBufs();
  }
  void setInfo(const String& json) { if (info_) info_->setValue(std::string(json.c_str())); }
  void notify(const String& json) {
    if (!status_) return;
    status_->setValue(std::string(json.c_str()));
    status_->notify();
  }
  void disconnectAll() {
    if (!srv_) return;
    for (uint16_t h : srv_->getPeerDevices()) srv_->disconnect(h);
  }
  bool take(Msg& out) {
    bool got = false;
    if (!buf_) return false;
    portENTER_CRITICAL(&mux_);
    if (buf_->pend.kind != K_NONE) { out = buf_->pend; buf_->pend.kind = K_NONE; got = true; }
    portEXIT_CRITICAL(&mux_);
    return got;
  }
  bool takeDisconnect() { const bool d = discEv_; discEv_ = false; return d; }

 private:
  struct ChrCb : public NimBLECharacteristicCallbacks {
    uint8_t kind = K_NONE;
    void onWrite(NimBLECharacteristic* c) override {
      if (self_) self_->onRaw(kind, c->getValue());
    }
  };
  struct SrvCb : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer*, ble_gap_conn_desc*) override {
      if (!self_) return;
      self_->conn_ = true; ++self_->nConn_;
    }
    void onDisconnect(NimBLEServer*) override {
      if (!self_) return;
      self_->conn_ = false; self_->discEv_ = true;
      if (!self_->stopping_) NimBLEDevice::startAdvertising();
    }
    void onMTUChange(uint16_t m, ble_gap_conn_desc*) override { if (self_) self_->mtu_ = m; }
  };
  void freeBufs() {
    portENTER_CRITICAL(&mux_);
    Bufs* p = buf_; buf_ = nullptr;
    portEXIT_CRITICAL(&mux_);
    free(p);
  }
  void onRaw(uint8_t kind, const std::string& v) {
    if (!buf_) return;
    uint8_t* frag_ = buf_->frag;
    const uint8_t* b = (const uint8_t*)v.data();
    size_t n = v.size();
    if (n >= 3 && b[0] == 0x1E) {  // fragment
      const uint8_t idx = b[1], tot = b[2];
      if (idx == 0 || kind != fragKind_) { fragLen_ = 0; fragKind_ = kind; fragNext_ = 0; }
      if (idx != fragNext_ || tot == 0) { fragLen_ = 0; fragNext_ = 0; return; }  // out of order: drop
      const size_t k = n - 3;
      if (fragLen_ + k > kMaxPayload) { fragLen_ = 0; fragNext_ = 0; return; }
      memcpy(frag_ + fragLen_, b + 3, k);
      fragLen_ += k;
      ++fragNext_;
      if (idx + 1 < tot) return;
      b = frag_; n = fragLen_;
      fragNext_ = 0;
    }
    if (n > kMaxPayload) n = kMaxPayload;
    portENTER_CRITICAL(&mux_);
    if (buf_) {
      buf_->pend.kind = kind;
      buf_->pend.len = (uint16_t)n;
      memcpy(buf_->pend.data, b, n);
      buf_->pend.data[n] = 0;
    }
    portEXIT_CRITICAL(&mux_);
  }
  static inline BlePair* self_ = nullptr;
  bool on_ = false;
  volatile bool conn_ = false, discEv_ = false, stopping_ = false;
  volatile uint16_t mtu_ = 23;
  volatile uint32_t nConn_ = 0;
  NimBLEServer* srv_ = nullptr;
  NimBLECharacteristic* info_ = nullptr;
  NimBLECharacteristic* status_ = nullptr;
  ChrCb cbA_, cbP_, cbW_;
  SrvCb srvCb_;
  struct Bufs { Msg pend; uint8_t frag[kMaxPayload]; };
  Bufs* buf_ = nullptr;
  portMUX_TYPE mux_ = portMUX_INITIALIZER_UNLOCKED;
  size_t fragLen_ = 0;
  uint8_t fragKind_ = K_NONE, fragNext_ = 0;
};

}  // namespace riderlab
