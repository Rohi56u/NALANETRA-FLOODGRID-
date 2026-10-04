# REST contract

Prefix: `/api/v1`; schemas: `/docs`. Protected calls use `Authorization: Bearer <accessToken>`. Photos use original JPEG/PNG multipart bytes.

| Method / path | Inputs / access |
|---|---|
| POST `/auth/register` | Citizen `role`, `fullName`, `email`, `password`; optional phone; staff signup forbidden |
| POST `/auth/verify` | `role`, `challengeId`, `emailCode` |
| POST `/auth/login` | `role`, `email`, `password`; issued `staffId` for staff |
| POST `/auth/refresh` | `role`, `refreshToken`; rotates session |
| POST `/auth/resendByEmail` | `role`, `email`; cooldown applies |
| POST `/auth-logout` | Bearer; revokes current session |
| POST `/photos/screen` | Authenticated multipart photo; a cue, not truth/depth validation |
| POST `/incidents/report` | Citizen multipart: `client_id`, `location`, `lat`, `lon`, `depth_tag`, `captured_at`, `capture_source`, `photo`; optional notes/accuracy |
| POST `/incidents/{id}/review` | Officer: approved, severity, note; optional rainfall/ward/blockage/emergency context |
| POST `/incidents/{id}/merge` | Officer: `target_incident_id`, `note` |
| POST `/incidents/{id}/dispatch` | Officer: issued `crew_id` |
| POST `/jobs/{id}/status` | Assigned crew: status, lat/lon/accuracy/source |
| POST `/jobs/{id}/evidence` | Assigned crew: before/after kind, photo, fresh time, GPS/accuracy/source, note |
| POST `/incidents/{id}/closure` | Officer: approved/note; distinct pair and integrity checks |
| GET `/snapshot` | Role-scoped incidents, reports, proof, jobs, roster, updates and sources |
| GET `/evidence/{id}` | Protected ownership/assignment checks; no-store bytes |
| GET `/incidents/heatmap` | Officer GeoJSON incident points |
| GET `/incidents/{id}/audit` | Officer actor/action history |
| POST `/routes` | Officer/crew origin_lat/lon, dest_lat/lon; actual OSRM or explicit unavailable status |
| GET `/risk/demo` | Authenticated synthetic drainage result |
| POST `/devices` | Authenticated FCM token enrollment |
| GET `/health` | Configuration status; configuration does not imply validated delivery |

Access tokens last 30 minutes; refresh sessions last seven days and are revocable. Registration passwords need at least 12 characters.

Report acknowledgments carry canonical `report_id` and `incident_id` after database commit; incomplete acknowledgments stay queued. Commit conflicts return 409 and roll back records and new files. Retry keys are per-account; conflicting retries return 409. Uploads allow 6 MiB/16 million pixels. Citizen captures must be within 24 hours; crew proof within 15 minutes, after dispatch and within mission location checks. Client metadata is not device attestation; deployment rejects `demo-fixture`.

Surface 401/403, 409 and 422 failures rather than inventing a local success. Executable tests provide full examples.
