# Mobile Messenger - Flutter + Serverpod + PostgreSQL

A full-stack mobile messaging application built with Flutter, Serverpod backend, and PostgreSQL database. Demonstrates a modern architecture for real-time communication applications with Docker orchestration for local development.

## Quick Start (5-10 minutes)

See [quickstart.md](specs/001-messenger-init/quickstart.md) for detailed setup instructions.
For production rollout guidance, see [DEPLOYMENT.md](DEPLOYMENT.md).

### Prerequisites

- **Git**: Any recent version
- **Docker Desktop**: v2.0+ (with Docker Compose v2)

That's it — no Flutter SDK, Dart, or any other tooling needed.

### Start Everything (one command)

```bash
# Clone and navigate to project
git clone <repository-url>
cd web-messenger

# Build and start all services
docker compose up --build
```

Wait for all containers to become healthy (roughly 2–5 minutes on first build), then open:

| Service | URL |
|---|---|
| **Web app** | http://localhost:5000 |
| **Backend API** | http://localhost:8081 |
| **Email catcher (MailHog)** | http://localhost:8025 |

> `--build` is only required the first time or after code changes. Subsequent runs can use plain `docker compose up`.

To stop all services:
```bash
docker compose down
```

### Real Email Smoke Test

If you want a single command that:
- starts the backend with Docker Compose
- waits for health
- runs the Flutter UI smoke test for registration and password reset email

use:

```bash
./scripts/manual-tests/run_gmail_email_smoke_test.sh
```

This expects either:
- your local ignored `.env` to already contain Gmail SMTP settings

The script then runs the frontend live integration test automatically.

To configure another machine, copy `.env.example` to `.env` and then choose one of these SMTP modes:
- MailHog for local capture only
- Gmail SMTP for real inbox delivery

## Project Structure

```
mobile-messenger/
├── frontend/              # Flutter mobile application
│   ├── lib/
│   │   ├── main.dart     # App entry point
│   │   ├── app.dart      # Root widget and routing
│   │   ├── core/         # Shared utilities, models, services
│   │   └── features/     # Feature modules (auth, profile, chat, invites)
│   └── pubspec.yaml
│
├── backend/              # Serverpod backend application
│   ├── lib/
│   │   ├── server.dart   # Server entry point
│   │   └── src/
│   │       ├── endpoints/   # HTTP/WebSocket handlers
│   │       ├── services/    # Business logic
│   │       └── models/      # Data models
│   ├── migrations/       # Database migrations
│   └── pubspec.yaml
│
├── scripts/              # Operational and manual test scripts
│   └── manual-tests/
│
├── docker-compose.yml    # Local development orchestration
└── .env.example          # Environment template
```

## Technology Stack

- **Frontend**: Flutter 3.10.0+, Dart 3.0+
- **Backend**: Serverpod 3.4.2+, Dart 3.0+
- **Database**: PostgreSQL 13+
- **Infrastructure**: Docker & Docker Compose 2.0+

## Features

### Phase 1: Developer Setup ✅
- [x] Flutter frontend project initialized
- [x] Serverpod backend project initialized
- [x] PostgreSQL database configured
- [x] Docker Compose orchestration
- [x] Health check endpoint (`GET /health`)
- [x] Flutter app with connection retry logic

### Phase 2: Authentication & User System ✅
- [x] User registration and login (JWT)
- [x] Password reset functionality
- [x] Email verification system
- [x] User profiles and search

### Phase 3: Chat Invite System ✅
- [x] User search and discovery
- [x] Send chat invitations to users
- [x] Accept/decline pending invitations
- [x] View sent and received invites
- [x] Invite status tracking
- [x] Mock API implementation for testing

### Phase 4+: Roadmap 📋
- [ ] Database integration for invites
- [ ] Real-time notifications
- [ ] Chat creation on invite acceptance
- [ ] Message encryption
- [ ] Media sharing in chats
- [ ] Push notifications
- [ ] Production deployment

## Commands

### Docker Compose

```bash
# Build images and start all services (first run / after code changes)
docker compose up --build

# Start in the background
docker compose up --build -d

# View logs
docker compose logs -f

# Stop services (keeps data volumes)
docker compose down

# Stop and wipe all data (fresh start)
docker compose down -v

# Restart a single service
docker compose restart serverpod

# Start with Gmail SMTP and run live email smoke test
./scripts/manual-tests/run_gmail_email_smoke_test.sh
```

If your local ignored `.env` is configured for Gmail SMTP, emails will be sent to real inboxes. If `.env` is configured for MailHog (the default), emails are captured at http://localhost:8025.

### Frontend Development

```bash
cd frontend

# Fetch dependencies
flutter pub get

# Run on emulator/device
flutter run

# Build APK (Android)
flutter build apk --split-per-abi

# Run tests
flutter test
```

### Backend Development

```bash
cd backend

# Fetch dependencies
dart pub get

# Run server
dart run lib/server.dart

# Run tests
dart test
```

### Testing Invite System

```bash
# Test invite endpoints via API
./scripts/manual-tests/test_invites.sh

# For comprehensive testing guide, see:
# - INVITE_TESTING_GUIDE.md (complete reference)
# - QUICK_START_TESTING.md (quick reference)
# - TESTING_INDEX.md (all testing documentation)
```

## Documentation

- [Quickstart Guide](specs/001-messenger-init/quickstart.md) - 5-minute setup guide
- [API Specification](specs/001-messenger-init/contracts/) - API contracts and specifications
- [Data Model](specs/001-messenger-init/data-model.md) - Database schema and models
- [Architecture Plan](specs/001-messenger-init/plan.md) - Technical architecture
- [Research & Decisions](specs/001-messenger-init/research.md) - Technology choices rationale
- [Invite System Testing](INVITE_TESTING_GUIDE.md) - Complete guide for testing the chat invite system
- [Quick Start Testing](QUICK_START_TESTING.md) - Quick testing reference
- [Testing Index](TESTING_INDEX.md) - Index of all testing documentation

## Troubleshooting

### Ports in Use
If Docker ports are already in use:
```bash
# Edit docker-compose.yml and change port mappings, or stop conflicting services
lsof -i :8081  # Find process on port 8081
```

### Database Connection Issues
- Verify PostgreSQL container is running: `docker ps`
- Check connection: `docker-compose exec postgres psql -U messenger_user -d messenger_db`

### Flutter Issues
- Clear cache: `flutter clean`
- Rebuild: `flutter pub get && flutter run`

## Contributing

1. Create a feature branch: `git checkout -b feature/feature-name`
2. Implement changes following code patterns in respective module documentation
3. Test thoroughly before committing
4. Submit pull request for review

## Development Setup

See individual module READMEs:
- [Frontend README](frontend/README.md)
- [Backend README](backend/README.md)

## License

Proprietary - All rights reserved

## Support

For questions or issues:
- Check [Troubleshooting](#troubleshooting) section
- Review [Quickstart Guide](specs/001-messenger-init/quickstart.md)
- Consult [Architecture Plan](specs/001-messenger-init/plan.md)
