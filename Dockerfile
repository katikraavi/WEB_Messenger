FROM dart:stable

# Install runtime utilities
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app/backend

# Copy backend pubspec only (pubspec.lock is gitignored)
COPY backend/pubspec.yaml ./

# Install Dart dependencies
RUN dart pub get

# Copy entire backend source
COPY backend/ .

EXPOSE 8081

# Start the backend server
CMD ["dart", "run", "bin/server.dart"]
