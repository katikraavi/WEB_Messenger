# Render Redeploy Runbook (Fast Path)

This project can run on Render as a single Docker web service that serves frontend and backend on the same domain.

## 1) Deploy with Blueprint (recommended)

1. In Render, click **New +** -> **Blueprint**.
2. Connect this repository.
3. Select the generated blueprint file: `render.yaml`.
4. Fill the SMTP secret values when prompted.
5. Click **Apply**.

Blueprint file:
- `render.yaml`

## 2) Required environment values

Set these values in the Render web service if not already present:

- `SERVERPOD_ENV=production`
- `SERVERPOD_PORT=8081`
- `DATABASE_URL=<render postgres connection string>`
- `DATABASE_SSL=true`
- `ENCRYPTION_MASTER_KEY=<64+ random hex>`
- `SMTP_HOST=<your smtp host>`
- `SMTP_PORT=587`
- `SMTP_FROM_EMAIL=<from address>`
- `SMTP_FROM_NAME=Mobile Messenger`
- `SMTP_USER=<smtp username>`
- `SMTP_PASSWORD=<smtp password>`
- `SMTP_SECURE=false` (for port 587 STARTTLS)
- `APP_BASE_URL=<your backend public url>`
- `FRONTEND_URL=<your frontend public url>`

Optional but useful:

- `VERBOSE_BACKEND_LOGS=false`

## 3) Build metadata (optional)

The frontend badge supports these Docker build args:

- `APP_ENV` (default `production`)
- `BUILD_SHA` (default `unknown`)
- `BUILD_TIME` (default `unknown`)
- `ENABLE_TEST_USERS` (default `false`)
- `BACKEND_URL` (default `/`)

For production, keep `ENABLE_TEST_USERS=false`.

`BACKEND_URL` safety rules:

- Never set `BACKEND_URL` to `https://api` or `http://api`.
- If frontend and backend are served by the same Render service/domain, set `BACKEND_URL=/`.
- If frontend and backend are separate services, set `BACKEND_URL` to the full backend origin, for example `https://web-messenger-backend.onrender.com`.

## 4) Post-deploy verification

Run:

```bash
./scripts/deploy/render_post_deploy_check.sh https://YOUR-RENDER-URL.onrender.com
```

The script verifies:

- health endpoint (`/health`)
- API routing for auth (`/api/auth/login` must reach backend)
- protected API route (`/api/chats` returns auth error)
- frontend shell is served at (`/`)

## 5) If frontend loads but login fails

This usually means API routing fallback is wrong. Confirm:

- `/api/auth/login` does **not** return HTML
- `/api/chats` returns JSON (not HTML)

Then redeploy the latest code from this branch.

Common browser console symptom for bad `BACKEND_URL`:

- `POST https://api/auth/login net::ERR_NAME_NOT_RESOLVED`

This means the frontend bundle was built with an invalid API host.

## 6) Cache and Service Worker reset (important)

After changing `BACKEND_URL`, clear stale web assets before retesting:

1. Open browser DevTools -> Application.
2. Unregister all Service Workers for the frontend domain.
3. Clear site data/storage for the frontend domain.
4. Hard refresh the page.

Then verify login request URL in Network tab:

- Same-service deployment: `/api/auth/login`
- Split-service deployment: `https://web-messenger-backend.onrender.com/api/auth/login`
