# CornerIQ — product requirements

Living requirements for features beyond the current MVP. Status: **Planned** unless noted.

Related shipped MVP: GPS ride recorder, Ride Lab (map + scrubber + charts), in-app GitHub APK updates. See root [README](../README.md).

---

## 1. Unified speed color scale

**Goal:** Every speed visualization uses one shared color mapping so riders can read speed at a glance across map and charts.

### Scale

| Speed (km/h) | Color |
|---|---|
| **0 (slow)** | Pale / clear red |
| **0 → 300** | Continuous **red intensity** ramp (clear → mid → dark) |
| **300+ (fast)** | Darkest red |

- Cap for darkest red: **300 km/h** (hard product constant unless we later make it configurable).
- Interpolation must be continuous (one red family — not blue bands).
- Same mapping function for **all** speed representations:
  - Pilot-line map polyline segments
  - Speed profile chart (line and/or gradient fill)
  - Any future HUD, legend, or comparison overlays that encode speed by color
- Show a small **legend** on Ride Lab (slow · pale → dark · fast) wherever the map uses speed color.

### Out of scope (for this requirement)

- Recoloring non-speed charts (GPS accuracy, etc.).
- Changing brand UI chrome (buttons, banners) to match the speed blues.

### Acceptance criteria

- [ ] One shared helper (e.g. `speedColor(kmh)`) used by map + speed chart.
- [ ] At 0 km/h → pale/clear red; at 300 km/h → dark red.
- [ ] Intermediate speeds are a smooth red intensity gradient (slow = light, fast = dark).
- [ ] Legend visible on the pilot-line map screen.

---

## 2. Lean / inclination color language (L vs R)

**Goal:** Left and right lean always use a fixed, distinct pair of colors that are **not green and not red** (red is reserved for over-300 speed; green is easy to confuse with “good” and with older map bands).

### Locked meaning

| Side | Meaning | Color role |
|---|---|---|
| **L / Left** | Negative lean (current convention) | **Cyan / sky** (`leanLeft`) |
| **R / Right** | Positive lean | **Amber / gold** (`leanRight`) |
| Upright (~0°) | Neutral | Mist / steel (no strong side tint) |

Suggested tokens (implement in `AppTheme` or a viz palette):

- `leanLeft` ≈ `#4CC9F0` (cyan)
- `leanRight` ≈ `#F4A261` (amber)

Avoid for lean: traffic green, and the speed red ramp (so speed vs lean stay distinguishable).

### Apply everywhere inclination is shown

- Motorcycle lean gauge (needle, peak L/R labels)
- Lean left/right profile chart (split color by sign, or dual-tone fill)
- Any future corner cards or comparison views that call out max lean L/R

### Acceptance criteria

- [ ] Gauge, chart, and peaks share the same L/R tokens.
- [ ] No green or red used to mean lean side.
- [ ] Speed red (>300) never appears as “right lean.”

---

## 3. Loop mode (auto lap recording)

**Goal:** Rider defines a closed circuit once; the app then records **each lap** automatically while they keep riding.

### Rider flow

1. Rider enters **Loop mode** (from home or active-ride entry).
2. **Loop init** — mark the start of the reference segment (GPS + time).
3. Rider rides the circuit once (or as needed) to teach the path.
4. **Loop end** — mark the end of the reference loop (closes the geometric / path definition).
5. App arms **auto lap detection**: each time the rider re-enters the init zone with a plausible loop completion, start a new lap segment (and close the previous one).
6. Rider stops loop session when done → review per-lap metrics.

### Product rules

- Loop definition is tied to a **route/circuit** (see also §4).
- Init/end markers should be forgiving (geofence / corridor radius), not a single GPS point.
- Manual **force lap** optional later; MVP is auto after init+end.
- Safety: no interactive map required while moving; marking init/end can be large buttons on the active HUD.
- Persist: loop session → many lap rides (or one ride with lap segments) in SQLite.

### Metrics per lap (minimum)

- Lap time, distance, max/avg speed, max lean L/R, GPS quality summary.

### Acceptance criteria

- [ ] User can set Loop init and Loop end.
- [ ] After both are set, subsequent passes create new lap records without tapping start each time.
- [ ] Session end stops auto recording.
- [ ] Rider can open a lap and see Ride Lab for that lap.

---

## 4. Compare rides on the same route

**Goal:** Compare metrics across different rides (or laps) that share the **same route**.

### Route identity (MVP approach)

- Prefer **explicit**: rides/laps tagged to a named route / loop definition from §3.
- Fallback later: spatial similarity (polyline match) — not required for first ship.

### Compare experience

- Pick a **baseline** ride/lap and one or more **challengers** on the same route.
- Side-by-side (or overlay) metrics:
  - Total / sector time (full lap first; sectors later)
  - Max / avg speed
  - Max lean L / R
  - Line quality score (existing Ride Lab score when available)
- Optional map overlay: two polylines with shared playhead time-normalized or distance-normalized.
- Use §1 speed colors and §2 lean colors so overlays stay consistent.

### Acceptance criteria

- [ ] User can select ≥2 rides/laps that share a route and open Compare.
- [ ] Key metrics shown in one comparison view.
- [ ] Clear empty states when no same-route peers exist.

---

## Implementation order (suggested)

1. **Speed + lean color systems** — shared viz palette; retrofit map + charts + gauge (small, high polish).
2. **Loop mode** — recording model + HUD markers + lap list.
3. **Same-route compare** — builds on loop/route identity; then generalize to any tagged route.

---

## Open decisions

| Topic | Default for now | Revisit when |
|---|---|---|
| Blue ramp exact stops (hue/lightness) | One blue family, document hex in theme when implemented | User feedback outdoors |
| Behavior exactly at 300.0 | Blue end inclusive; `> 300` → red | Edge cases |
| Lap storage model | Segments under one session vs separate rides | Loop mode design spike |
| Route matching without loops | Deferred | After loop tagging ships |

---

## Traceability

| ID | Title | Status |
|---|---|---|
| REQ-SPEED-COLOR | Unified speed color scale (pale→dark red by speed) | In progress (map + speed chart + legend) |
| REQ-LEAN-COLOR | Lean L/R colors (not green/red) | In progress (gauge + lean chart) |
| REQ-LOOP | Loop mode init/end + auto laps | Planned |
| REQ-COMPARE | Compare metrics on same route | Planned |

### Brand typography

- Wordmark: `CornerIqMark` — **Syne** lockup, `Corner` + `IQ` with distinct tracking; `IQ` tinted cyan (lean accent, not speed red).
- UI chrome remains Outfit + Space Grotesk.
