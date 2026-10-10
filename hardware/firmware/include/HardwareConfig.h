#pragma once

// RiderLab — single source of truth for M5Stack Basic + M135 + Battery 13.2
// Do not change pins without a physical DIP change and an update to DECISIONS.md.

#include <cstdint>
#include <esp_task_wdt.h>

namespace riderlab {

inline constexpr const char* FIRMWARE_NAME = "riderlab-logger";
inline constexpr const char* FIRMWARE_VERSION = "0.6.5-simpos";

// Azure Function in rg-riderlab / riderlabimusas. Key goes in NVS via serial AZURE.
inline constexpr const char* AZURE_INGEST_URL =
    "https://riderlabimusas.azurewebsites.net/api/logger-ingest";

// Arduino-ESP32 arms the loop-task WDT (~5 s) before setup() returns.
// Any longer block (GNSS hunt, SD retry) reboots into the splash forever.
inline void wdtFeed() {
  esp_task_wdt_reset();
  yield();
}

// HTTPS + Azure cold start bloquean más de 5 s; el WDT del loop reinicia el M5.
inline void wdtHold() { esp_task_wdt_delete(NULL); }
inline void wdtRelease() {
  esp_task_wdt_add(NULL);
  wdtFeed();
}

// Physical stack (top → bottom):
//   1. M5Stack Basic Core — USB-C
//   2. Module GNSS M135
//   3. Battery Module 13.2 (active)
//   4. Original black Bottom Base — cover only, switch MUST stay at 0

// Measured DIP on the M135 used as ANCHOR (COM8 / hw a057d0c92df4, 2026-10-08):
//   DIP bank labelled "RXD" (receiver UART out = NEO_TXD) → G16  (host RX)
//   DIP bank labelled "TXD" (receiver UART in  = NEO_RXD) → G12  (host TX)
//   DIP bank labelled "PPS"                               → G34
// The silkscreen names are from the receiver's side (inverted vs casual M5 docs).
// G12 is an ESP32 strapping pin; this unit boots fine with TXD→G12. If another
// unit won't boot, move the TXD bank off G12 to G17 or G15.
// Auto-hunt in GnssService remains the source of truth; these are preferred
// defaults / documentation for the known-good stacking.
struct DipConfig {
  static constexpr int TXD_SWITCH = 12;  // host TX → NEO_RXD  (DIP "TXD" → G12)
  static constexpr int RXD_SWITCH = 16;  // host RX ← NEO_TXD  (DIP "RXD" → G16)
  static constexpr int PPS_SWITCH = 34;  // PPS → G34
};

// ESP32 Serial2 defaults (hunt overrides). Factory UART = 38400; after cfg → 115200.
static constexpr int GNSS_RX_PIN = 16;
static constexpr int GNSS_TX_PIN = 12;
static constexpr int GNSS_PPS_PIN = 34;
static constexpr uint32_t GNSS_BAUD = 38400;

static constexpr int I2C_SDA_PIN = 21;
static constexpr int I2C_SCL_PIN = 22;

// M5Stack Basic TF slot — SPI CS is GPIO4 (shared SPI with LCD).
static constexpr int SD_CS_PIN = 4;
static constexpr uint32_t SD_SPI_HZ = 25000000;
// 0.5.4: max simultaneously open files for SD.begin(). esp_vfs_fat_register()
// reserves ONE block of ~6.2 KB + max_files x ~4.14 KB (4 KB per-file cache,
// FF_MAX_SS=4096) at boot; with 16 it was ~73 KB and left only ~38.9 KB
// contiguous for TLS. WARNING: a recording keeps 8 files open (rider) / 9
// (anchor) plus 1 transient (diag/events/manifest) -> needs >= 9 / 10.
#define SD_MAX_FILES 10  // rider peak 9 (8 + 1 transient) + 1 margin; anchor peak 10

static constexpr uint8_t ADDR_BMI270 = 0x69;
static constexpr uint8_t ADDR_BMP280 = 0x76;
static constexpr uint8_t ADDR_UBLOX_I2C = 0x42;  // NEO-M9N DDC port

// ---- Receiver profile: IDENTICAL in RIDER and ANCHOR (differential correction
// only cancels common error when both units run the same config). ----
// NEO-M9N datasheet (UBX-19014285): PVT up to 25 Hz with 4 concurrent GNSS.
// 10 Hz keeps UART/SD headroom (UBX + NMEA) and is plenty for mapping.
static constexpr uint32_t GNSS_TARGET_HZ = 10;
static constexpr uint32_t GNSS_FAST_BAUD = 115200;   // UBX PVT+SAT+DOP + NMEA
static constexpr uint8_t GNSS_DYNMODEL = 4;          // CFG-NAVSPG-DYNMODEL 4=automotive
static constexpr int8_t GNSS_MIN_ELEV_DEG = 10;      // CFG-NAVSPG-INFIL_MINELEV
static constexpr bool GNSS_USE_SBAS = true;          // WAAS en MX
static constexpr uint8_t GNSS_SAT_EVERY_N = GNSS_TARGET_HZ;  // NAV-SAT ~1 Hz
static constexpr uint8_t GNSS_DOP_EVERY_N = GNSS_TARGET_HZ;  // NAV-DOP ~1 Hz
static constexpr const char* GNSS_PROFILE_NAME = "m9n-gps+glo+gal+bds+qzss+sbas-10hz-auto-el10";

static constexpr uint32_t IMU_TARGET_HZ = 100;
// BMP280 normal mode "handheld dynamic" (datasheet table 7): P x4, T x1,
// IIR 16, standby 0.5 ms -> ~83 Hz ODR. Firmware reads at BARO_SAMPLE_HZ and
// writes the boxcar mean at BARO_LOG_HZ. Same in both roles (differential baro).
static constexpr uint32_t BARO_SAMPLE_HZ = 50;
static constexpr uint32_t BARO_LOG_HZ = 10;
static constexpr uint32_t BARO_TARGET_HZ = BARO_LOG_HZ;  // legacy name
static constexpr uint32_t HEALTH_UI_HZ = 5;   // live fields; no fillScreen on this tick
static constexpr uint32_t HEALTH_LOG_HZ = 1;

// ---- ANCHOR role ----
static constexpr float ANCHOR_MAX_HACC_M = 3.0f;      // good-fix gate for averaging
static constexpr int ANCHOR_MIN_SV = 6;
static constexpr uint32_t ANCHOR_STAB_S = 180;        // ignore first 3 min after fix
static constexpr float ANCHOR_READY_HACC_M = 2.0f;
static constexpr int ANCHOR_READY_SV = 10;
static constexpr float ANCHOR_READY_DRIFT_M = 1.0f;   // |median60 - mean| horiz.
static constexpr uint32_t ANCHOR_IMU_LOG_HZ = 10;     // anchor is static; detection runs at 100 Hz
static constexpr uint32_t ANCHOR_DIM_AFTER_MS = 180000;
static constexpr uint8_t ANCHOR_DIM_LEVEL = 12;
static constexpr uint32_t ANCHOR_SUMMARY_EVERY_MS = 30000;
static constexpr uint32_t FLUSH_EVERY_MS = 1000;      // power-loss resilience
static constexpr uint32_t MANIFEST_EVERY_MS = 30000;
// Disturbance (IMU): bump = |a| deviation, move = tilt change vs baseline.
static constexpr float DIST_BUMP_MS2 = 0.8f;
static constexpr float DIST_GYRO_DPS = 6.0f;
static constexpr float DIST_TILT_DEG = 1.5f;
static constexpr uint32_t DIST_GUARD_MS = 5000;       // invalid tail after last bump

}  // namespace riderlab
