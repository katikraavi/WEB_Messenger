# Stage 1: Build frontend with relative API path for nginx reverse proxy
FROM ghcr.io/cirruslabs/flutter:stable AS frontend-builder

ARG BACKEND_URL=/
ARG APP_ENV=production
ARG ENABLE_TEST_USERS=false
ARG BUILD_SHA=unknown
ARG BUILD_TIME=unknown

WORKDIR /app

COPY frontend/pubspec.yaml ./
RUN flutter pub get

COPY frontend/ .

# Build frontend pointing to relative API path (will use same domain via nginx proxy)
RUN flutter build web --release \
    --dart-define=BACKEND_URL=${BACKEND_URL} \
    --dart-define=APP_ENV=${APP_ENV} \
    --dart-define=ENABLE_TEST_USERS=${ENABLE_TEST_USERS} \
    --dart-define=BUILD_SHA=${BUILD_SHA} \
    --dart-define=BUILD_TIME=${BUILD_TIME}

# Stage 2: Build backend
FROM dart:stable AS backend-builder

WORKDIR /app

COPY backend/pubspec.yaml ./
RUN dart pub get

COPY backend/ .

# Generate pubspec.lock for the runtime
RUN dart pub get --offline || dart pub get

# Stage 3: Runtime - Dart image with nginx
FROM dart:stable

# Install security updates and runtime dependencies
RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y --no-install-recommends nginx ca-certificates tini \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/nginx/sites-enabled/default /etc/nginx/conf.d/default.conf

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built frontend to nginx
COPY --from=frontend-builder /app/build/web /usr/share/nginx/html

# Copy backend
COPY --from=backend-builder /app /app/backend
COPY --from=backend-builder /root/.pub-cache /root/.pub-cache

WORKDIR /app/backend

# Ensure dependencies are available
RUN dart pub get || true

# Create startup script
RUN printf '%s\n' \
    '#!/bin/sh' \
    'set -e' \
    '' \
    '# Start backend in background with all environment variables passed through' \
    'echo "[INFO] Starting Dart backend on :8081..."' \
    'dart run bin/server.dart &' \
    'BACKEND_PID=$!' \
    '' \
    '# Give backend time to start' \
    'sleep 3' \
    '' \
    '# Start nginx in foreground' \
    'echo "[INFO] Starting nginx reverse proxy on :8080..."' \
    'nginx -g "daemon off;"' \
    '' \
    '# Cleanup if nginx stops' \
    'kill $BACKEND_PID 2>/dev/null || true' \
    > /start.sh \
    && chmod +x /start.sh

EXPOSE 8080

STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/start.sh"]
