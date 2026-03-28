FROM dart:stable AS base

# Install runtime utilities used by docker health checks.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app/backend

# Cache dependencies first for faster rebuilds.
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get

# Copy source after deps are resolved.
COPY . .

EXPOSE 8081

# Start the backend server used by docker-compose.
CMD ["dart", "run", "bin/server.dart"]