#pragma once

#include <Arduino.h>
#include <SD.h>

#include "HardwareConfig.h"
#include "EventLog.h"

namespace riderlab {

struct RideRec {
  char id[40] = {};
  uint32_t ms = 0;
  uint16_t gnss = 0;
  bool cloud = false;
};

class RideIndex {
 public:
  static constexpr int kMax = 24;
  static constexpr const char* kPath = "/riderlab/rides.ndjson";
  static constexpr const char* kTmp = "/riderlab/rides.tmp";

  void begin() {
    if (!SD.exists("/riderlab")) SD.mkdir("/riderlab");
    if (!SD.exists("/riderlab/sessions")) SD.mkdir("/riderlab/sessions");
    if (SD.exists(kPath)) {
      load(kPath);
    } else if (SD.exists(kTmp)) {
      load(kTmp);
    } else {
      n_ = 0;
    }
    // 0.6.7: session-folder recovery moved out of setup -> recoverStep() in loop (budgeted)
    recActive_ = true;
    recSeen_ = recAdded_ = recSkipFull_ = 0;
    recT0_ = millis();
    gLog.logf(LogLvl::Info, "index", "load n=%d pending=%d (recovery deferred to loop)", n_, pendingCount());
  }
  // 0.6.7: incremental recovery of session folders missing from the index. Runs from loop() with a
  // time budget per call (GNSS keeps draining between calls). Fixes vs <= 0.6.6:
  //  * never evicts indexed rides when the index is full (the old code shifted the oldest out, so with
  //    > kMax folders every boot re-counted the evicted ones byte by byte = minutes, and re-queued them
  //    as pending uploads, including sim_pos sessions);
  //  * counts lines with 1 KB block reads, not 1 byte per read();
  //  * sim_pos sessions (manifest "sim_pos":true) are recovered with gnss=0 (never pending, as 0.6.5).
  // Returns true when finished (or idle).
  bool recoverStep(uint32_t budgetMs) {
    if (!recActive_) return true;
    const uint32_t t0 = millis();
    if (!recRootOpen_) {
      recRoot_ = SD.open("/riderlab/sessions");
      recRootOpen_ = true;
      if (!recRoot_) return recFinish();
    }
    static uint8_t buf[1024];
    while (millis() - t0 < budgetMs) {
      if (recCnt_) {  // counting lines of one gnss.ndjson
        const int k = recCnt_.read(buf, sizeof buf);
        if (k > 0) {
          for (int i = 0; i < k; ++i) recLines_ += buf[i] == '\n';
          continue;
        }
        recCnt_.close();
        RideRec r;
        strncpy(r.id, recId_, sizeof(r.id) - 1);
        r.ms = millis();
        r.gnss = (uint16_t)(recLines_ > 65535 ? 65535 : recLines_);  // 0.6.9b: sim_pos sessions are pending too
        r.cloud = false;
        if (n_ < kMax) { recs_[n_++] = r; ++recAdded_; recDirty_ = true; }
        gLog.logf(LogLvl::Info, "index", "recovered %s gnss=%lu sim_pos=%d", recId_, (unsigned long)recLines_, (int)recSim_);
        continue;
      }
      File e = recRoot_.openNextFile();
      if (!e) return recFinish();
      ++recSeen_;
      const bool dir = e.isDirectory();
      const char* nm = e.name();
      const char* sl = nm ? strrchr(nm, '/') : nullptr;
      char id[40];
      snprintf(id, sizeof id, "%s", sl ? sl + 1 : (nm ? nm : ""));
      e.close();
      if (!dir || strlen(id) < 4 || find(id) >= 0) continue;
      if (n_ >= kMax) { ++recSkipFull_; continue; }  // full: keep the index as is (no eviction)
      snprintf(recId_, sizeof recId_, "%s", id);
      const String base = String("/riderlab/sessions/") + id;
      recSim_ = false;
      File m = SD.open(base + "/manifest.json", FILE_READ);
      if (m) {
        const String s = m.readString();
        m.close();
        recSim_ = s.indexOf("\"sim_pos\":true") >= 0;
      }
      recLines_ = 0;
      recCnt_ = SD.open(base + "/gnss.ndjson", FILE_READ);
      if (!recCnt_) {  // no gnss file: index it with 0 points (not pending)
        RideRec r;
        strncpy(r.id, id, sizeof(r.id) - 1);
        r.ms = millis();
        recs_[n_++] = r;
        ++recAdded_;
        recDirty_ = true;
      }
    }
    return false;
  }
  bool recovering() const { return recActive_; }

  void wipeSessionTree() {
    File root = SD.open("/riderlab/sessions");
    if (root) {
      for (File e = root.openNextFile(); e; e = root.openNextFile()) {
        const String name = e.name();
        const bool dir = e.isDirectory();
        e.close();
        wdtFeed();
        if (dir) removeDir(String("/riderlab/sessions/") + name);
        else SD.remove(String("/riderlab/sessions/") + name);
      }
      root.close();
    }
    n_ = 0;
  }

  void addLocal(const String& id, uint16_t gnss) {
    RideRec r;
    strncpy(r.id, id.c_str(), sizeof(r.id) - 1);
    r.ms = millis();
    r.gnss = gnss;
    r.cloud = false;
    int i = find(id.c_str());
    if (i < 0) {
      if (n_ >= kMax) {
        for (int j = 1; j < n_; ++j) recs_[j - 1] = recs_[j];
        i = n_ - 1;
      } else {
        i = n_++;
      }
    }
    recs_[i] = r;
    save();
  }

  void updateGnss(const String& id, uint16_t gnss) {
    const int i = find(id.c_str());
    if (i < 0) {
      addLocal(id, gnss);
      return;
    }
    recs_[i].gnss = gnss;
    save();
  }

  void markCloudAndDelete(const String& id, const String& dir) {
    const int i = find(id.c_str());
    if (i >= 0) recs_[i].cloud = true;
    save();
    removeDir(dir);
  }

  void markCloudKeep(const String& id) {
    const int i = find(id.c_str());
    if (i >= 0) recs_[i].cloud = true;
    save();
  }

  int count() const { return n_; }
  const RideRec& at(int i) const { return recs_[i]; }

  // Newest first for the UI.
  const RideRec& newest(int i) const { return recs_[n_ - 1 - i]; }

  bool hasLocalPending() const { return pendingCount() > 0; }

  int pendingCount() const {
    int n = 0;
    for (int i = 0; i < n_; ++i) {
      if (!recs_[i].cloud && recs_[i].gnss > 0) n++;
    }
    return n;
  }

  String pendingId() const {
    for (int i = 0; i < n_; ++i) {
      if (!recs_[i].cloud && recs_[i].gnss > 0) return String(recs_[i].id);
    }
    return "";
  }

  // 0.5.5: id or "ALL". cloud=1 -> 0 for rides whose gnss.ndjson is still on the
  // SD (KEEPSD ON). Never touches files. Returns how many were re-queued.
  int requeueCloud(const String& which) {
    int n = 0;
    for (int i = 0; i < n_; ++i) {
      if (!recs_[i].cloud || recs_[i].gnss == 0) continue;
      if (which != "ALL" && which != recs_[i].id) continue;
      if (!SD.exists(String("/riderlab/sessions/") + recs_[i].id + "/gnss.ndjson")) continue;
      recs_[i].cloud = false;
      n++;
    }
    if (n) save();
    return n;
  }

  void markNoUpload(const String& id) {
    const int i = find(id.c_str());
    if (i < 0) return;
    recs_[i].gnss = 0;
    save();
  }

  // Drop index rows + session folders with gnss==0 (empty / aborted recordings).
  // Returns how many were removed. Does not touch rides that have points.
  int purgeZero() {
    int removed = 0;
    int w = 0;
    for (int i = 0; i < n_; ++i) {
      if (recs_[i].gnss > 0) {
        if (w != i) recs_[w] = recs_[i];
        ++w;
        continue;
      }
      if (recs_[i].id[0]) {
        removeDir(String("/riderlab/sessions/") + recs_[i].id);
        ++removed;
      }
      wdtFeed();
    }
    if (removed) {
      n_ = w;
      save();
    }
    return removed;
  }

 private:
  int find(const char* id) const {
    for (int i = 0; i < n_; ++i) {
      if (strcmp(recs_[i].id, id) == 0) return i;
    }
    return -1;
  }

  void load(const char* path) {
    n_ = 0;
    File f = SD.open(path, FILE_READ);
    if (!f) return;
    while (f.available() && n_ < kMax) {
      String line = f.readStringUntil('\n');
      line.trim();
      if (!line.startsWith("{")) continue;
      RideRec r;
      const int id0 = line.indexOf("\"id\":\"");
      if (id0 < 0) continue;
      const int id1 = line.indexOf('"', id0 + 6);
      if (id1 < 0) continue;
      line.substring(id0 + 6, id1).toCharArray(r.id, sizeof(r.id));
      const int ms0 = line.indexOf("\"ms\":");
      if (ms0 >= 0) r.ms = (uint32_t)line.substring(ms0 + 5).toInt();
      const int g0 = line.indexOf("\"gnss\":");
      if (g0 >= 0) r.gnss = (uint16_t)line.substring(g0 + 7).toInt();
      r.cloud = line.indexOf("\"cloud\":1") >= 0;
      recs_[n_++] = r;
    }
    f.close();
  }

  void recoverSessions() {
    File root = SD.open("/riderlab/sessions");
    if (!root) return;
    for (File e = root.openNextFile(); e; e = root.openNextFile()) {
      if (!e.isDirectory()) {
        e.close();
        continue;
      }
      const String id = e.name();
      e.close();
      if (id.length() < 4) continue;
      if (find(id.c_str()) >= 0) continue;
      RideRec r;
      strncpy(r.id, id.c_str(), sizeof(r.id) - 1);
      r.ms = millis();
      r.gnss = countGnssLines(String("/riderlab/sessions/") + id + "/gnss.ndjson");
      r.cloud = false;
      if (n_ >= kMax) {
        for (int j = 1; j < n_; ++j) recs_[j - 1] = recs_[j];
        recs_[n_ - 1] = r;
      } else {
        recs_[n_++] = r;
      }
      wdtFeed();
    }
    root.close();
  }

  static uint16_t countGnssLines(const String& path) {
    File f = SD.open(path, FILE_READ);
    if (!f) return 0;
    uint16_t n = 0;
    while (f.available()) {
      const char c = (char)f.read();
      if (c == '\n') n++;
      if ((n & 0x3F) == 0) wdtFeed();
    }
    f.close();
    return n;
  }

  void save() {
    SD.remove(kTmp);
    File f = SD.open(kTmp, FILE_WRITE);
    if (!f) {
      loge("index", "save open fail");
      return;
    }
    for (int i = 0; i < n_; ++i) {
      f.printf("{\"id\":\"%s\",\"ms\":%lu,\"gnss\":%u,\"cloud\":%d}\n", recs_[i].id,
               (unsigned long)recs_[i].ms, (unsigned)recs_[i].gnss,
               recs_[i].cloud ? 1 : 0);
    }
    f.flush();
    f.close();
    if (SD.exists(kPath)) SD.remove(kPath);
    if (!SD.rename(kTmp, kPath)) {
      // Some FAT stacks refuse rename; keep the tmp as fallback on next boot.
    }
  }

  static void removeDir(const String& path) {
    File dir = SD.open(path);
    if (!dir) {
      SD.remove(path);
      return;
    }
    if (!dir.isDirectory()) {
      dir.close();
      SD.remove(path);
      return;
    }
    for (File f = dir.openNextFile(); f; f = dir.openNextFile()) {
      const String child = path + "/" + f.name();
      const bool isDir = f.isDirectory();
      f.close();
      wdtFeed();
      if (isDir) removeDir(child);
      else SD.remove(child);
    }
    dir.close();
    SD.rmdir(path);
  }

  bool recFinish() {
    if (recCnt_) recCnt_.close();
    if (recRoot_) recRoot_.close();
    recRootOpen_ = false;
    recActive_ = false;
    if (recDirty_) save();
    recDirty_ = false;
    gLog.logf(LogLvl::Info, "index", "recovery done folders=%lu added=%lu skipped_full=%lu ms=%lu n=%d pending=%d",
              (unsigned long)recSeen_, (unsigned long)recAdded_, (unsigned long)recSkipFull_,
              (unsigned long)(millis() - recT0_), n_, pendingCount());
    return true;
  }
  RideRec recs_[kMax];
  int n_ = 0;
  // 0.6.7 incremental recovery state
  bool recActive_ = false, recRootOpen_ = false, recDirty_ = false, recSim_ = false;
  File recRoot_, recCnt_;
  char recId_[40] = {};
  uint32_t recLines_ = 0, recSeen_ = 0, recAdded_ = 0, recSkipFull_ = 0, recT0_ = 0;
};

}  // namespace riderlab
