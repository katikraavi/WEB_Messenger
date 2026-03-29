# Mobile Messenger Frontend

Flutter client for Mobile Messenger.

This app provides:
- Authentication (register, login, verification, password reset)
- Chat and messaging UX
- Invitations flow
- Media capture and upload
- Real-time updates via WebSocket
- Push notification integration (when Firebase is configured)

## Table of Contents

- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Run Commands](#run-commands)
- [Quality and Testing](#quality-and-testing)
- [Live Email Smoke Test](#live-email-smoke-test)
- [Code Generation](#code-generation)
- [Configuration Notes](#configuration-notes)
- [Email Delivery Notes](#email-delivery-notes)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)
- [Contributing](#contributing)

## Architecture

The frontend follows a feature-first layout under lib/features, with Riverpod and Provider used for state management where already adopted.

Guiding principles:
- Keep API logic in services, not widgets
- Keep UI stateless where possible
- Keep feature boundaries clear (auth, chats, profile, invitations, recovery)
- Prefer explicit error states over silent failures
- Keep user-facing messages actionable

## Tech Stack

- Flutter (Dart SDK 3.11+)
- Riverpod and Provider
- HTTP for REST calls
- WebSocket for real-time messaging
- Flutter Secure Storage for sensitive tokens
- Firebase Core and Messaging (optional in local runs)

## Prerequisites

- Flutter SDK installed and available on PATH
- A working Linux desktop setup or Android emulator/device
- Docker and Docker Compose for backend services
- Android SDK and adb if running on Android

Verify setup:

```bash
flutter doctor -v
```

## Quick Start

1. Start backend services from repository root:

```bash
docker compose up -d
```

2. Install frontend dependencies:

```bash
cd frontend
flutter pub get
```

3. Run the app:

```bash
flutter run -d linux
```

Default backend URL is localhost port 8081.

## Run Commands

### Linux

```bash
flutter run -d linux
```

If your Linux graphics stack causes rendering issues:

```bash
./run_linux_safe.sh
```

### Android

```bash
flutter run
```

If needed, use the workaround script:

```bash
./flutter_run_workaround.sh
```

## Quality and Testing

Run static analysis:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

Recommended pre-merge checks:
- flutter analyze
- flutter test
- smoke run of core auth flow

## Live Email Smoke Test

Use this when you want to verify the real Flutter UI path for:
- registration email
- password reset email

Prerequisites:
- backend running on `http://localhost:8081`
- SMTP configured through the repository root `.env`

Run it with:

```bash
./run_live_email_smoke_test.sh
```

What it does:
- checks backend health first
- runs the live Flutter integration test at `integration_test/live_email_ui_flow_test.dart`
- creates a unique test account
- triggers registration email
- triggers password reset email

If you need real inbox delivery, make sure the repository root `.env` is configured for Gmail SMTP (or another provider), then start the backend from the repository root with:

```bash
docker compose up -d --build
```

If you only want the raw test command:

```bash
RUN_LIVE_EMAIL_UI_TESTS=true flutter test integration_test/live_email_ui_flow_test.dart
```

## Code Generation

The project uses code generation for immutable models and JSON support.

One-time generation:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Watch mode during development:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

## Configuration Notes

- Backend base URL is currently configured for localhost.
- Firebase is optional in local development; app can run with push disabled.
- Keep environment-specific behavior documented and explicit.
- SMTP mode is controlled by the repository-root `.env` file used by Docker Compose.
- If `SMTP_HOST`/`SMTP_PORT` are empty, auth emails are skipped locally.
- If root `.env` uses Gmail SMTP, auth emails are delivered to real inboxes.

## Email Delivery Notes

Registration and password reset are backend-driven email flows.

If emails do not arrive:
- Confirm backend is reachable and healthy
- Check backend logs for SMTP send result
- Check spam folder
- Verify sender identity at your SMTP provider

For SendGrid specifically:
- Use a verified sender or domain-authenticated from address
- Avoid unverified personal inbox from addresses

For real delivery to a mailbox visible to testers, configure Gmail SMTP in the repository-root `.env` and start the backend with Docker Compose:

```bash
docker compose up -d --build
```

## Troubleshooting

### Flutter run interactive commands

- r: hot reload
- R: hot restart
- h: list interactive commands
- d: detach
- c: clear screen
- q: quit

### Linux keyring warning

If you see a libsecret keyring unlock warning, secure storage may not persist properly for that session. Ensure your desktop keyring is unlocked and available.

### Firebase not initialized

Message like remote push disabled for this run is expected when Firebase is not configured locally.

### Backend connectivity issues

Check service health:

```bash
docker compose ps
curl http://localhost:8081/health
```

## Security Best Practices

- Never commit secrets, tokens, or provider API keys
- Keep auth tokens in secure storage only
- Avoid logging sensitive user data
- Rotate compromised credentials immediately
- Validate all user input on both frontend and backend

## Contributing

1. Create a focused branch per change
2. Keep commits small and descriptive
3. Add tests for behavior changes
4. Keep user-visible errors clear and actionable
5. Run analyze and tests before opening a PR

## Useful References

- Flutter docs: https://docs.flutter.dev
- Dart language and tooling: https://dart.dev
