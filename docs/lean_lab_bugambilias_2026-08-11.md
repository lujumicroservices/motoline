# Bugambilias Lean Lab — rider report

**Date:** 11 August 2026 (Mexico City)  
**Circuit:** Bugambilias (`lean_lab_bugambilias_v2`)  
**Source:** RiderLab cloud telemetry (`camera_events` · `lean_lab_session`) + synced `rides`

> **Important:** Phones **Cesar Pulido** and **Juan Valdes** were used by the **same rider** (Rider A). **RT DobleU** is Rider B.

---

## Summary


|                             | Count                            |
| --------------------------- | -------------------------------- |
| Real riders                 | 2                                |
| Phone accounts              | 3                                |
| Lean Lab sessions           | 12                               |
| Sessions with corner labels | 11                               |
| Labeled corners             | 55                               |
| Still unlabeled             | 1 (Juan · return · right pocket) |


---

## Rider A — same person (Cesar + Juan phones)

Dual-phone / dual-pocket A/B experiment on the same motorcycle.

### Sessions


| Time  | Phone        | Direction | Mount        | Pose       | Dist    | GPS Hz | Line | Max L/R     | Corners |
| ----- | ------------ | --------- | ------------ | ---------- | ------- | ------ | ---- | ----------- | ------- |
| 19:58 | Juan Valdes  | outbound  | left pocket  | screen in  | 3.00 km | 0.84   | 71   | 35.4 / 50.3 | 5       |
| 19:59 | Cesar Pulido | outbound  | right pocket | screen in  | 3.03 km | 0.69   | 73   | 25.1 / 54.1 | 5       |
| 20:04 | Juan Valdes  | return    | right pocket | screen out | 2.88 km | 0.96   | 73   | 45.8 / 47.2 | **0**   |
| 20:05 | Cesar Pulido | return    | left pocket  | screen out | 2.88 km | 0.83   | 75   | 59.6 / 34.9 | 5       |
| 20:16 | Cesar Pulido | outbound  | right pocket | screen out | 3.05 km | 0.87   | 73   | 51.2 / 33.7 | 5       |
| 20:17 | Juan Valdes  | outbound  | left pocket  | screen out | 3.02 km | 0.67   | 74   | 44.3 / 65.7 | 5       |
| 20:23 | Cesar Pulido | return    | right pocket | screen out | 2.92 km | 0.84   | 70   | 34.8 / 48.0 | 5       |
| 20:23 | Juan Valdes  | return    | left pocket  | screen out | 2.89 km | 0.81   | 75   | 48.0 / 25.5 | 5       |


### Corner peaks (labeled)

**Juan · outbound · left pocket (19:58)**  
`R 44.1° · R 36.2° · R 19.4° · R 18.8° · R 18.4°` — all `unsure`

**Cesar · outbound · right pocket (19:59)**  
`L 64.6° · L 55.6° · L 55.0° · L 54.7° · L 54.7°` — all `unsure`

**Cesar · return · left pocket (20:05)** · title *Vistas del Sol - Bugambilias*  
`L 70.0° · L 23.4° · L 18.3° · L 18.3° · L 16.8°` — all `unsure`

**Cesar · outbound · right pocket (20:16)**  
`R 64.3° · R 64.3° · R 62.5° · R 62.1° · R 61.6°` — all `unsure`

**Juan · outbound · left pocket (20:17)**  
`L 55.7° · L 46.0° · L 46.0° · L 45.2° · L 44.3°` — all `unsure`

**Cesar · return · right pocket (20:23)**  
`R 46.9° · R 46.9° · R 46.6° · R 46.4° · R 46.4°` — all `unsure`

**Juan · return · left pocket (20:23)**  
`L 29.2° · L 29.1° · L 28.8° · L 27.9° · L 27.6°` — all `unsure`

### Rider A takeaways

- Matching **left-pocket return**: Cesar ≈ **29°** and Juan ≈ **29°** → phones agree.
- Different pockets on outbound: Cesar right ≈ **60°** vs Juan left ≈ **37°** → mount bias.
- Almost all bias labels are `unsure` — need felt high/ok/low next time.

---

## Rider B — RT DobleU

### Sessions


| Time  | Direction | Mount        | Pose      | Dist    | GPS Hz | Line | Max L/R     | Corners |
| ----- | --------- | ------------ | --------- | ------- | ------ | ---- | ----------- | ------- |
| 19:58 | outbound  | left pocket  | screen in | 3.01 km | 0.84   | 74   | 20.8 / 39.7 | 5       |
| 20:06 | return    | left pocket  | screen in | 2.85 km | 0.64   | 72   | 23.5 / 70.0 | 5       |
| 20:16 | outbound  | right pocket | screen in | 3.03 km | 0.84   | 74   | 63.3 / 24.2 | 5       |
| 20:22 | return+  | right pocket | screen in | 2.87 km | 0.66   | 72   | 42.4 / 37.1 | 5       |


### Corner peaks

**Outbound · left (19:58)**  
`R 46.1° ok · R 46.1° ok · R 44.6° · R 44.6° · R 39.9°`

**Return · left (20:06)**  
`R 59.1° ok · L 26.6° · L 26.6° · L 22.1° · L 21.6°`

**Outbound · right (20:16)**  
`L 54.4° ok · L 54.4° ok · L 54.4° ok · L 36.5° · L 31.6°`

**Return · right (20:22)**  
`L 35.8° · R 34.2° · L 33.8° · L 30.6° · L 29.0°` — all `unsure`

### Rider B takeaways

- Faster peaks (up to **115 km/h**).
- Only rider with confident **ok** labels (6×).
- Still shows mount-side lean asymmetry.

---

## Shared circuit metrics

- Coverage ≈ **100%** on all Lean Lab sessions  
- Outbound climb ≈ **160–200 m** · Return descent ≈ **160 m**  
- GPS rate ≈ **0.6–1.0 Hz** · line scores **70–75**

---

## Training note

Do **not** treat Cesar vs Juan as two riders in models. Merge as **Rider A**; treat phone + mount as experimental factors.