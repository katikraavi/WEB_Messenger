# Mobile Messenger - Flutter + Serverpod + PostgreSQL

A full-stack mobile messaging application built with Flutter, Serverpod backend, and PostgreSQL database. Demonstrates a modern architecture for real-time communication applications with Docker orchestration for local development.

## Quick Start (5-10 minutes)

See [quickstart.md](specs/001-messenger-init/quickstart.md) for detailed setup instructions.

### Prerequisites

- **Git**: Any recent version
- **Docker Desktop**: v2.0+
- **Flutter SDK**: 3.10.0+
- **Android SDK** or **Xcode** (for mobile emulation)

### Start Development Environment

```bash
# Clone and navigate to project
git clone <repository-url>
cd mobile-messenger

# Start backend and database (Docker Compose)
docker-compose up

# In another terminal, start Flutter app
cd frontend
flutter pub get
flutter run
```

Expected result:
- Backend running on `http://localhost:8081`
- PostgreSQL running on `localhost:5432`
- Flutter app connected and displaying UI

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

### Phase 2+: Roadmap 📋
- [ ] User authentication (JWT)
- [ ] User profiles
- [ ] Real-time messaging (WebSockets)
- [ ] Invite system
- [ ] Production deployment

## Commands

### Docker Compose

```bash
# Start services (background)
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Clean data volumes
docker-compose down -v

# Restart service
docker-compose restart serverpod
```

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

## Documentation

- [Quickstart Guide](specs/001-messenger-init/quickstart.md) - 5-minute setup guide
- [API Specification](specs/001-messenger-init/contracts/) - API contracts and specifications
- [Data Model](specs/001-messenger-init/data-model.md) - Database schema and models
- [Architecture Plan](specs/001-messenger-init/plan.md) - Technical architecture
- [Research & Decisions](specs/001-messenger-init/research.md) - Technology choices rationale

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
