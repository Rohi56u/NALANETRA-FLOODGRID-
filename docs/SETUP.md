# Run NalaNetra FloodGrid

## Local service

Use Python 3.12 and the [README quickstart](../README.md#run-locally). On Windows activate with `.venv\Scripts\Activate.ps1`. Run service commands from the repository root.

`python -m scripts.bootstrap_demo` issues only three fictional local accounts. It is repeatable without overwriting existing accounts and does not create incidents or operational asset data. The review console is `http://127.0.0.1:8000`; API schemas are `/docs`. Keep the fixture server on loopback.

Ignored `var/` holds SQLite, private evidence, session signing material and development verification messages. Stop the service before moving/replacing state.

## Registration and issued staff

Citizen signup requires email verification. Local mode writes the OTP message under the private development mail directory in `var/`; the local operator reads it. Expiry, attempt limits and resend cooldown are enforced. Phone verification is not claimed.

Staff issuance uses a private password prompt:

```bash
python -m scripts.provision_staff --role officer --staff-id MCG-OF-002 \
  --email officer2@example.test --name "Local officer exercise"
```

Use `--role crew` for crew staff. Verify operational authority outside the application; public registration cannot grant staff access.

## Flutter / Android

Use Flutter 3.47.5 / Dart 3.13 and the committed lockfile:

```bash
cd mobile
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter run -d chrome --web-port 8080 \
  --dart-define=NALANETRA_BACKEND_BASE_URL=http://127.0.0.1:8000
```

Default API CORS permits localhost and 127.0.0.1 on port 8080. Supply trusted origins for other ports. `mobile/defines.example.json` documents the URL without credentials.

The account-owned queue retains original bytes/time/retry ID. Its limit is three pending reports and 2 MiB total raw photo bytes. Refresh/reopen retries the same account's queue; OS background synchronization is not implemented. Expired photos may need recapture. Storage/acknowledgment failures are surfaced.

Android camera/GPS permissions must be granted. For an emulator use:

```bash
flutter run -d YOUR_ANDROID_DEVICE \
  --dart-define=NALANETRA_BACKEND_BASE_URL=http://10.0.2.2:8000
```

For USB phones, `adb reverse tcp:8000 tcp:8000` allows a debug build targeting `http://127.0.0.1:8000`. Otherwise use a reachable operator-managed endpoint. Citizen manually entered coordinates are labelled `selected-map`; crew arrival/proof requires claimed accuracy ≤50 m and distance ≤50 m.

Debug HTTP is enabled only in the Android debug manifest. Use HTTPS for release use. Automatic Android backup is disabled to avoid restoring encrypted sessions without their original keys. CI APKs use development signing and an emulator API URL. Release signing, physical camera/GPS and permission validation are separate work. An iOS project is not included.

## PostgreSQL and deployment

Apply `database/schema.sql` once to an empty PostGIS-capable database. It matches workflow ORM tables and adds spatial indexes, an incident geometry view and a source/time-labelled polygon table. It is not an upgrade migration for older databases.

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f database/schema.sql
```

The service accepts `postgresql://` or `postgresql+psycopg://`. CI uses a disposable database named `nalanetra_test`. Structured migrations and surveyed polygon import remain deployment work.

The service reads process environment variables, not `.env` files automatically. `backend/.env.example` documents:

| Variable | Purpose |
|---|---|
| `NALA_MODE` | local, test or deployment |
| `NALA_DATA_DIR` | Private durable runtime storage |
| `DATABASE_URL` | PostgreSQL connection |
| `NALA_JWT_SECRET` | Private random secret, at least 32 characters |
| `NALA_CORS_ORIGINS` | Comma-separated trusted origins |
| `NALA_MAIL_MODE` | file locally; smtp for deployment |
| `NALA_SMTP_HOST`, `NALA_SMTP_USER`, `NALA_SMTP_PASSWORD`, `NALA_SMTP_FROM` | Required SMTP verification settings; STARTTLS is used |
| `NALA_OSRM_URL` | Operator-managed road-routing service |
| `NALA_YOLO_WEIGHTS` | Optional evaluated local weights |
| `GOOGLE_APPLICATION_CREDENTIALS` | Optional private Firebase service-account path |

Deployment mode rejects missing SMTP, short JWT secrets and non-PostgreSQL connections. Operators must provide HTTPS, access controls, backups, retention, verified staff and monitored feed refresh. IMD and municipal data need authorized access arrangements.

Optional FCM: install `backend/requirements-fcm.txt`, configure credentials, enroll tokens through `/api/v1/devices`, then `python -m scripts.send_notifications`. Provider acceptance does not establish device receipt; automatic Flutter token enrollment remains pending.

Optional YOLO: independently install compatible `ultralytics` and provide evaluated local weights. Default installation uses OpenCV cues and does not download weights.

## Verification

```bash
python -m pytest
python -m ruff check backend intelligence routing security scripts tests --select F
python -m scripts.verify_presentation
python -m scripts.build_evidence
python -m scripts.build_diagrams
```

For browser automation install `playwright==1.63.0`, run `python -m playwright install chromium`, then `python -m scripts.browser_check`. It starts a temporary loopback service, exercises three roles, records synthetic evidence and shuts down. `NALA_BROWSER_BINARY` can select an installed Chromium-compatible binary.
