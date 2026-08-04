# Beta ride engine labels

After each completed ride, RiderLab asks a short questionnaire so we can train
lean / curve / brake models before public release.

## Questions

1. **Where was the phone?** `center_mount` | `left_pocket` | `right_pocket` | `other`
2. **Did lean feel right?** `good` | `left_high` | `right_high` | `both_off` | `unsure`
3. **Did brakes look right?** `good` | `too_many` | `too_few` | `unsure`
4. **What kind of ride?** `street` | `mountain` | `track` | `commute` | `other`

Skip is allowed (stored as skipped so we don’t re-ask).

## Storage

| Layer | Where |
|-------|--------|
| Local | SQLite `ride_engine_labels` |
| Cloud mirror | `camera_events` category `engine_label` (existing sync) |
| Cloud table | `ride_engine_labels` (migration) |

Payload includes neutral lean, curve count, distance for offline training joins.
