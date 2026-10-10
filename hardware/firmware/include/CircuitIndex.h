// 0.6.7-autocircuit: light index of every known circuit (embedded 8 Horas + /riderlab/circuit.rlc +
// /riderlab/circuits/*.rlc). Per entry ~120 B: name, source path, anchor, length, bounding box (m, anchor
// ENU, outer+inner edges). Built once at boot (each file parsed into ONE temporary heap Circuit, then
// freed); the full circuit is loaded only when it is opened. Distance to a circuit = distance from the
// fix to its bounding box (0 inside), so big tracks are detected from any side, not only the anchor.
#pragma once
#include <Arduino.h>
#include <SD.h>
#include <new>
#include "CircuitFile.h"

namespace riderlab {

struct CircEntry {
  char name[25] = {};
  char path[48] = {};  // "" = embedded
  double lat0 = 0, lon0 = 0;
  float lenM = 0, x0 = 0, x1 = 0, y0 = 0, y1 = 0;
  float distM = -1;    // last computed distance (m), -1 = unknown (no good fix yet)
  uint32_t fsize = 0, mtime = 0;  // 0.6.7 cache key (SD files only)
};

struct CircuitIndex {
  static constexpr int kMax = 12;
  static constexpr const char* kDir = "/riderlab/circuits";
  static constexpr const char* kLegacy = "/riderlab/circuit.rlc";
  CircEntry e[kMax];
  int n = 0;
  int legacyIdx = -1;
  char dbg[64] = "";  // last build / scan summary
 private:
  bool scanning_ = false, changed_ = false, dirOpen_ = false;
  File dir_;
  uint32_t seen_ = 0, scanT0_ = 0, scanMs_ = 0;
  int files_ = 0, parsed_ = 0;
 public:

  static void kxy(double lat, double& kx, double& ky) {
    const double r = lat * M_PI / 180;
    ky = 111132.92 - 559.82 * cos(2 * r) + 1.175 * cos(4 * r);
    kx = 111412.84 * cos(r) - 93.5 * cos(3 * r);
  }
  bool add(const Circuit& c, const char* path, const char* nameOverride) {
    if (n >= kMax) return false;
    CircEntry& x = e[n];
    x = CircEntry();
    snprintf(x.name, sizeof x.name, "%s", nameOverride ? nameOverride : c.name);
    snprintf(x.path, sizeof x.path, "%s", path ? path : "");
    x.lat0 = c.lat0; x.lon0 = c.lon0; x.lenM = c.lenM;
    float a = 1e9f, b = -1e9f, cc = 1e9f, d = -1e9f;
    for (int i = 0; i < c.nO + c.nI; ++i) {
      const CPt& p = i < c.nO ? c.outer[i] : c.inner[i - c.nO];
      const float px = p.x * c.unit, py = p.y * c.unit;
      a = fminf(a, px); b = fmaxf(b, px); cc = fminf(cc, py); d = fmaxf(d, py);
    }
    if (b < a) { a = b = cc = d = 0; }
    x.x0 = a; x.x1 = b; x.y0 = cc; x.y1 = d;
    ++n;
    return true;
  }
  static bool readFile(const char* path, Circuit& c) {
    File f = SD.open(path, FILE_READ);
    if (!f) return false;
    bool ok = false;
    const size_t sz = f.size();
    if (sz >= 72 && sz <= 8192) {
      uint8_t* b = (uint8_t*)malloc(sz);
      if (b) { ok = f.read(b, sz) == sz && c.parse(b, sz); free(b); }
    }
    f.close();
    return ok;
  }
  // 0.6.7 boot (fast): embedded + legacy file + cached directory entries (/riderlab/circuits.idx).
  // The directory itself is verified later by scanStep() from loop(), one entry per call.
  static constexpr const char* kCache = "/riderlab/circuits.idx";
  static constexpr uint32_t kCacheMagic = 0x31494352;  // "RCI1"
  static constexpr int kMaxFiles = 32;                 // directory entries looked at per scan
  static constexpr uint32_t kScanMaxMs = 4000;         // whole scan cap (spread over many loops)
  int nFixed = 0;  // embedded (+ legacy) entries, never touched by the scan
  void build(bool sdOk, const uint8_t* emb, size_t embLen, const char* embName) {
    n = 0; legacyIdx = -1; nFixed = 0; scanning_ = false;
    snprintf(dbg, sizeof dbg, "sd=%d", (int)sdOk);
    Circuit* c = new (std::nothrow) Circuit();
    if (!c) return;
    if (c->parse(emb, embLen)) add(*c, "", embName);
    if (sdOk && SD.exists(kLegacy) && readFile(kLegacy, *c)) { legacyIdx = n; add(*c, kLegacy, nullptr); }
    delete c;
    nFixed = n;
    int cached = 0;
    if (sdOk) {
      File f = SD.open(kCache, FILE_READ);
      if (f) {
        uint32_t mg = 0; uint8_t cnt = 0;
        if (f.read((uint8_t*)&mg, 4) == 4 && mg == kCacheMagic && f.read(&cnt, 1) == 1) {
          for (int k = 0; k < cnt && n < kMax; ++k) {
            CircEntry e2;
            if (f.read((uint8_t*)&e2, sizeof e2) != sizeof e2) break;
            e2.distM = -1;
            e[n++] = e2;
            ++cached;
          }
        }
        f.close();
      }
    }
    snprintf(dbg, sizeof dbg, "sd=%d cached=%d", (int)sdOk, cached);
  }
  // ---- incremental directory scan (loop) ----
  bool scanning() const { return scanning_; }
  void scanBegin() {
    scanning_ = true; changed_ = false; seen_ = 0; files_ = 0; parsed_ = 0; scanMs_ = 0;
    scanT0_ = millis();
    dirOpen_ = false;
  }
  // one directory entry per call (a .rlc that changed is parsed: <= 8 KB). true = finished now.
  bool scanStep(bool& changedOut) {
    if (!scanning_) return false;
    const uint32_t t0 = millis();
    if (!dirOpen_) {
      dir_ = SD.open(kDir);
      dirOpen_ = true;
      if (!dir_ || !dir_.isDirectory()) return scanEnd(changedOut, "nodir");
    }
    if (millis() - scanT0_ > kScanMaxMs) return scanEnd(changedOut, "time-cap");
    File f = dir_.openNextFile();
    if (!f) return scanEnd(changedOut, "ok");
    if (++files_ > kMaxFiles) { f.close(); return scanEnd(changedOut, "file-cap"); }
    const char* bn = f.name();
    const char* sl = bn ? strrchr(bn, '/') : nullptr;
    if (sl) bn = sl + 1;
    char p[48];
    snprintf(p, sizeof p, "%s/%s", kDir, bn ? bn : "");
    const bool isDir = f.isDirectory();
    const uint32_t sz = (uint32_t)f.size();
    const uint32_t mt = (uint32_t)f.getLastWrite();
    f.close();
    const size_t L = strlen(p);
    if (!isDir && L > 4 && strcasecmp(p + L - 4, ".rlc") == 0) {
      int at = -1;
      for (int i = nFixed; i < n; ++i) if (strcmp(e[i].path, p) == 0) { at = i; break; }
      if (at >= 0 && e[at].fsize == sz && e[at].mtime == mt) {
        seen_ |= 1u << at;
      } else {
        Circuit* c = new (std::nothrow) Circuit();
        const bool ok = c && readFile(p, *c);
        ++parsed_;
        if (ok) {
          if (at < 0 && n < kMax) { add(*c, p, nullptr); at = n - 1; }
          else if (at >= 0) { const int keep = n; n = at; add(*c, p, nullptr); n = keep; }
          if (at >= 0) { e[at].fsize = sz; e[at].mtime = mt; seen_ |= 1u << at; }
          changed_ = true;
        }
        delete c;
      }
    }
    scanMs_ += millis() - t0;
    return false;
  }
  bool scanEnd(bool& changedOut, const char* why) {
    if (dir_) dir_.close();
    dirOpen_ = false;
    scanning_ = false;
    // drop cached entries whose file is gone (only when the scan saw the whole directory)
    if (strcmp(why, "ok") == 0 || strcmp(why, "nodir") == 0) {
      int w = nFixed;
      for (int i = nFixed; i < n; ++i) {
        if (seen_ & (1u << i)) e[w++] = e[i];
        else changed_ = true;
      }
      n = w;
    }
    if (changed_) saveCache();
    snprintf(dbg, sizeof dbg, "%s files=%d parsed=%d sd_ms=%lu wall_ms=%lu", why, files_, parsed_,
             (unsigned long)scanMs_, (unsigned long)(millis() - scanT0_));
    changedOut = changed_;
    return true;
  }
  void saveCache() {
    const char* tmp = "/riderlab/circuits.id_";
    SD.remove(tmp);
    File f = SD.open(tmp, FILE_WRITE);
    if (!f) return;
    const uint32_t mg = kCacheMagic;
    const uint8_t cnt = (uint8_t)(n - nFixed);
    bool ok = f.write((const uint8_t*)&mg, 4) == 4 && f.write(&cnt, 1) == 1;
    for (int i = nFixed; i < n && ok; ++i) ok = f.write((const uint8_t*)&e[i], sizeof e[i]) == sizeof e[i];
    f.close();
    if (!ok) { SD.remove(tmp); return; }
    SD.remove(kCache);
    SD.rename(tmp, kCache);
  }
  float distTo(int i, double lat, double lon) const {
    double kx, ky;
    kxy(e[i].lat0, kx, ky);
    const float x = (float)((lon - e[i].lon0) * kx), y = (float)((lat - e[i].lat0) * ky);
    const float dx = x < e[i].x0 ? e[i].x0 - x : (x > e[i].x1 ? x - e[i].x1 : 0.f);
    const float dy = y < e[i].y0 ? e[i].y0 - y : (y > e[i].y1 ? y - e[i].y1 : 0.f);
    return sqrtf(dx * dx + dy * dy);
  }
  void updateDist(double lat, double lon) { for (int i = 0; i < n; ++i) e[i].distM = distTo(i, lat, lon); }
  int nearest(float maxM) const {
    int best = -1;
    for (int i = 0; i < n; ++i)
      if (e[i].distM >= 0 && e[i].distM <= maxM && (best < 0 || e[i].distM < e[best].distM)) best = i;
    return best;
  }
  // indices sorted nearest first (unknown distance last, index order)
  int sorted(int* out, int maxOut) const {
    int m = 0;
    for (int i = 0; i < n && m < maxOut; ++i) out[m++] = i;
    for (int a = 1; a < m; ++a)
      for (int b = a; b > 0; --b) {
        const float da = e[out[b - 1]].distM < 0 ? 1e12f : e[out[b - 1]].distM;
        const float db = e[out[b]].distM < 0 ? 1e12f : e[out[b]].distM;
        if (db < da) { const int t = out[b]; out[b] = out[b - 1]; out[b - 1] = t; } else break;
      }
    return m;
  }

  // ---- bench helper: synthetic test circuit around Ciudad Bugambilias (20.600,-103.437) ----
  // Rounded rectangle 280 x 180 m (corner R 30 m), 8 m wide, CCW, S/F mid bottom straight, 3 sectors.
  static constexpr const char* kTestPath = "/riderlab/circuits/test_bugambilias.rlc";
  static void rrect(float s, float a, float b, float r, float& x, float& y, float& tx, float& ty) {
    // arc-length parameter s from (0,-b) heading east, CCW; a,b = half sizes, r = corner radius
    const float sx = 2 * (a - r), sy = 2 * (b - r), q = (float)M_PI / 2 * r;
    const float L = 2 * sx + 2 * sy + 4 * q;
    s = fmodf(s, L); if (s < 0) s += L;
    const float segs[9] = {sx / 2, q, sy, q, sx, q, sy, q, sx / 2};
    int k = 0; while (k < 8 && s > segs[k]) { s -= segs[k]; ++k; }
    auto arc = [&](float cx, float cy, float a0) {
      const float ang = a0 + s / r; x = cx + r * cosf(ang); y = cy + r * sinf(ang); tx = -sinf(ang); ty = cosf(ang); };
    switch (k) {
      case 0: x = s; y = -b; tx = 1; ty = 0; break;
      case 1: arc(a - r, -b + r, -(float)M_PI / 2); break;
      case 2: x = a; y = -b + r + s; tx = 0; ty = 1; break;
      case 3: arc(a - r, b - r, 0); break;
      case 4: x = a - r - s; y = b; tx = -1; ty = 0; break;
      case 5: arc(-a + r, b - r, (float)M_PI / 2); break;
      case 6: x = -a; y = b - r - s; tx = 0; ty = -1; break;
      case 7: arc(-a + r, -b + r, (float)M_PI); break;
      default: x = -a + r + s; y = -b; tx = 1; ty = 0; break;
    }
  }
  static float rrectLen(float a, float b, float r) { return 4 * (a - r) + 4 * (b - r) + 2 * (float)M_PI * r; }
  // returns bytes written (0 = refused/failed). Never overwrites.
  static size_t writeTest(String& why) {
    if (SD.exists(kTestPath)) { why = "exists"; return 0; }
    if (!SD.exists(kDir) && !SD.mkdir(kDir)) { why = "mkdir"; return 0; }
    const float A = 140, B = 90, R = 30, W2 = 4;
    const int nC = 150, nO = 140, nI = 130, nG = 3;
    const size_t sz = 68 + 4 * (nO + nI + nC) + 11 * nG + 4;
    uint8_t* b = (uint8_t*)calloc(1, sz);
    if (!b) { why = "heap"; return 0; }
    const double latC = 20.600, lonC = -103.437;
    double kx, ky; kxy(latC, kx, ky);
    // anchor = outer edge abreast S/F = (0, -B - W2) relative to the centre
    const float axm = 0, aym = -B - W2;
    const double lat0 = latC + aym / ky, lon0 = lonC + axm / kx;
    auto w16 = [&](size_t o, int v) { const int16_t t = (int16_t)v; memcpy(b + o, &t, 2); };
    memcpy(b, "RLC1", 4); b[4] = 1; b[5] = 1;
    const uint16_t unit = 100; memcpy(b + 6, &unit, 2);
    memcpy(b + 8, &lat0, 8); memcpy(b + 16, &lon0, 8);
    const float alt0 = 1620.f, lenM = rrectLen(A, B, R), head0 = 90.f;
    memcpy(b + 24, &alt0, 4); memcpy(b + 28, &lenM, 4); memcpy(b + 32, &head0, 4);
    const uint16_t nn[3] = {(uint16_t)nO, (uint16_t)nI, (uint16_t)nC};
    memcpy(b + 36, nn, 6); b[42] = nG; b[43] = 3;
    snprintf((char*)b + 44, 24, "Bugambilias prueba");
    size_t o = 68;
    auto pts = [&](float a, float bb, float r, int m) {
      const float L = rrectLen(a, bb, r);
      for (int i = 0; i < m; ++i, o += 4) {
        float x, y, tx, ty; rrect(L * i / m, a, bb, r, x, y, tx, ty);
        w16(o, (int)lroundf((x - axm) * 10)); w16(o + 2, (int)lroundf((y - aym) * 10));
      }
    };
    pts(A + W2, B + W2, R + W2, nO);
    pts(A - W2, B - W2, R - W2, nI);
    pts(A, B, R, nC);
    for (int g = 0; g < nG; ++g, o += 11) {
      const float s = lenM * g / nG;
      float x, y, tx, ty; rrect(s, A, B, R, x, y, tx, ty);
      const float nx = -ty, ny = tx;  // left normal = towards the centre (CCW)
      w16(o, (int)lroundf((x + nx * 5 - axm) * 10)); w16(o + 2, (int)lroundf((y + ny * 5 - aym) * 10));
      w16(o + 4, (int)lroundf((x - nx * 5 - axm) * 10)); w16(o + 6, (int)lroundf((y - ny * 5 - aym) * 10));
      const uint16_t sdm = (uint16_t)lroundf(s * 10); memcpy(b + o + 8, &sdm, 2);
      b[o + 10] = g == 0 ? 0 : 1;
    }
    const uint32_t crc = Circuit::crc32(b, sz - 4);
    memcpy(b + sz - 4, &crc, 4);
    Circuit* chk = new (std::nothrow) Circuit();
    const bool valid = chk && chk->parse(b, sz);
    delete chk;
    if (!valid) { free(b); why = "self-check"; return 0; }
    File f = SD.open(kTestPath, FILE_WRITE);
    if (!f) { free(b); why = "open"; return 0; }
    const size_t w = f.write(b, sz);
    f.close();
    free(b);
    if (w != sz) { SD.remove(kTestPath); why = "write"; return 0; }
    why = "ok";
    return sz;
  }
  static bool deleteTest() { return SD.exists(kTestPath) && SD.remove(kTestPath); }  // ONLY this file
};

}  // namespace riderlab
