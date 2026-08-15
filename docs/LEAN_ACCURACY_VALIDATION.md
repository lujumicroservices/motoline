# Lean accuracy — 3-phone validation protocol

Run this **before** bumping `apps/mobile/pubspec.yaml` version for a lean release.

Success targets (from advanced lean plan):

1. Wall / clinometer, any pose: `|vector − clinometer| ≤ ~3°`
2. Rigid tank mount, steady curve, `v > 40 km/h`: median `|IMU − GPS kin| ≤ ~8°`
3. Dual pocket A/B: pose banners correct; confidence drops when L/R diverge (do **not** require absolute ° equality)

## A. Wall tip (3 phones)

1. Open **IMU Lean Lab** on each phone.
2. Freeze upright (hold 4 s) with phone in the pose under test:
   - Vertical portrait (tank)
   - Flat screen-up
   - Landscape on side
3. Tip against a wall to a known clinometer angle (~27°).
4. Record: vector lean, bike lean, pose banner, clinometer reading.
5. Pass if all three phones’ **vector** within ~3° of clinometer.

## B. Tank mount ride

1. Mount phone rigidly on tank (portrait or flat — freeze in that pose).
2. Ride one constant-radius canyon / roundabout above 40 km/h.
3. In IMU lab / Ride Lab, compare IMU lean vs GPS lean on the banner (or lean_samples).
4. Pass if median absolute disagreement ≤ ~8° on that stretch.

## C. Pocket A/B (same rider, two phones)

1. Left pocket + right pocket, same bike, same lap (Bugambilias-style).
2. Use **Guardar en el bolsillo** freeze (never freeze in hand).
3. Pass if:
   - Pose class = Vertical
   - Lean confidence lower when peaks L/R are heavily asymmetric
   - Absolute max lean may still disagree — that is expected; do not “fix” with a global scale factor

## Ship gate

- [ ] A pass on 3 phones × vertical + flat
- [ ] B pass on at least one tank mount session
- [ ] C pass (pose + confidence behavior)
- [ ] Unit tests green (`lean_imu_math`, `lean_neutral`)
- [ ] Then bump version and publish

Until then keep `1.29.x` (or current) — code is ready; validation is empirical.
