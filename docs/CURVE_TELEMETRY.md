# Curve telemetry engine

Differentiator analytics for RiderLab corners. Lives under
`apps/mobile/lib/core/telemetry/curves/` — separate from UI and from the legacy
`RoadStretch` labels (which remain for existing Ride Lab panels).

## Taxonomy (v1)

| Geometry | Meaning |
|----------|---------|
| `sweep` | Open / fast arc |
| `standard` | Classic mid corner |
| `hairpin` | Tight U |
| `sCurve` | Linked opposite turns **as one event** |
| `chicane` | Short opposite pair |
| `doubleApex` | Same-side two-apex corner |

**Kink is not a type** — weak bends are dropped.

Optional profiles: `CurveRadiusProfile`, `CurveSpeedProfile`.

## Pipeline (extensible)

```text
samples
  → ArcSegmenterStage        (single-arc candidates)
  → CompoundMergerStage      (S / chicane / double-apex merge)
  → GeometryClassifierStage  (sweep / standard / hairpin)
  → SpeedProfilerStage       (hook)
  → RadiusProfilerStage      (hook)
  → materialize CurveEvent   (phases + profiles)
```

Add a new `CurvePipelineStage` and pass it into `CurveEngine(stages: …)`.

## Config

- `CurveEngineConfig.standard` — street + track balanced  
- `CurveEngineConfig.track` — tighter compound gaps  

## Usage

```dart
final events = CurveEngine().analyze(samples, neutralLeanDegrees: neutral);
```

Also exposed on `RideAnalytics.curveEvents`.
