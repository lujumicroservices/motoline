#pragma once

// Persistent device role + anchor metadata (NVS namespace "riderlab", shared
// with WifiUploader; keys are <= 15 chars).
#include <Arduino.h>
#include <Preferences.h>

namespace riderlab {

enum class Role : uint8_t { Rider = 0, Anchor = 1 };

struct RefPoint {
  bool set = false;
  double lat = 0, lon = 0, h = 0;  // ground mark (NOT antenna)
  bool hMsl = false;               // false: ellipsoidal (CSRS-PPP), true: MSL
  char source[16] = "";            // ppp | survey | avg | phone | ...
  float sigma = -1;                // 1-sigma horizontal (m), -1 unknown
  char id[24] = "";
};

class RoleConfig {
 public:
  void load() {
    Preferences p;
    if (!p.begin("riderlab", true)) return;  // first boot: namespace absent
    role_ = (Role)p.getUChar("role", 0);
    antH_ = p.isKey("ant_h") ? p.getFloat("ant_h", 0.0f) : 0.0f;
    keepSd_ = p.getBool("keep_sd", false);
    lastSess_ = p.isKey("last_sess") ? p.getString("last_sess", "") : String();
    gnssRx_ = p.getChar("gnss_rx", -1);
    gnssBaud_ = p.getULong("gnss_baud", 0);
    gnssTx_ = p.getChar("gnss_tx", -1);
    ref_.set = p.getBool("ref_set", false);
    ref_.lat = p.isKey("ref_lat") ? p.getDouble("ref_lat", 0) : 0;
    ref_.lon = p.isKey("ref_lon") ? p.getDouble("ref_lon", 0) : 0;
    ref_.h = p.isKey("ref_h") ? p.getDouble("ref_h", 0) : 0;
    ref_.hMsl = p.getBool("ref_msl", false);
    ref_.sigma = p.isKey("ref_sig") ? p.getFloat("ref_sig", -1) : -1;
    if (p.isKey("ref_src")) p.getString("ref_src", ref_.source, sizeof(ref_.source));
    if (p.isKey("ref_id")) p.getString("ref_id", ref_.id, sizeof(ref_.id));
    p.end();
  }

  Role role() const { return role_; }
  bool anchor() const { return role_ == Role::Anchor; }
  const char* roleName() const { return anchor() ? "anchor" : "rider"; }
  void setRole(Role r) {
    role_ = r;
    put([&](Preferences& p) { p.putUChar("role", (uint8_t)r); });
  }

  float antH() const { return antH_; }
  void setAntH(float m) {
    antH_ = m;
    put([&](Preferences& p) { p.putFloat("ant_h", m); });
  }

  bool keepSd() const { return keepSd_ || anchor(); }
  bool keepSdPref() const { return keepSd_; }
  void setKeepSd(bool v) {
    keepSd_ = v;
    put([&](Preferences& p) { p.putBool("keep_sd", v); });
  }

  const String& lastSession() const { return lastSess_; }
  void setLastSession(const String& id) {
    lastSess_ = id;
    put([&](Preferences& p) { p.putString("last_sess", id); });
  }

  int gnssRx() const { return gnssRx_; }
  uint32_t gnssBaud() const { return gnssBaud_; }
  int gnssTx() const { return gnssTx_; }
  void setGnssLink(int rx, uint32_t baud, int tx) {
    if (rx == gnssRx_ && baud == gnssBaud_ && tx == gnssTx_) return;
    gnssRx_ = rx;
    gnssBaud_ = baud;
    gnssTx_ = tx;
    put([&](Preferences& p) {
      p.putChar("gnss_rx", (int8_t)rx);
      p.putULong("gnss_baud", baud);
      p.putChar("gnss_tx", (int8_t)tx);
    });
  }

  const RefPoint& ref() const { return ref_; }
  void setRef(const RefPoint& r) {
    ref_ = r;
    ref_.set = true;
    put([&](Preferences& p) {
      p.putBool("ref_set", true);
      p.putDouble("ref_lat", r.lat);
      p.putDouble("ref_lon", r.lon);
      p.putDouble("ref_h", r.h);
      p.putBool("ref_msl", r.hMsl);
      p.putFloat("ref_sig", r.sigma);
      p.putString("ref_src", r.source);
      p.putString("ref_id", r.id);
    });
  }
  void clearRef() {
    ref_ = RefPoint();
    put([&](Preferences& p) { p.putBool("ref_set", false); });
  }

 private:
  template <typename F>
  void put(F f) {
    Preferences p;
    if (!p.begin("riderlab", false)) return;
    f(p);
    p.end();
  }

  Role role_ = Role::Rider;
  float antH_ = 0;
  bool keepSd_ = false;
  String lastSess_;
  int gnssRx_ = -1;
  uint32_t gnssBaud_ = 0;
  int gnssTx_ = -1;
  RefPoint ref_;
};

}  // namespace riderlab
