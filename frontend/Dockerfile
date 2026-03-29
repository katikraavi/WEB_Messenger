# Stage 1 — compile Flutter web
FROM ghcr.io/cirruslabs/flutter:stable AS builder

ARG BACKEND_URL
ENV BACKEND_URL=${BACKEND_URL:-https://web-messenger-backend.onrender.com}

WORKDIR /app

# Resolve deps before copying source so layer is cached on pubspec changes only.
COPY pubspec.yaml ./
RUN flutter pub get

COPY . .
RUN flutter build web --release --dart-define=BACKEND_URL=${BACKEND_URL}

# Stage 2 — serve with nginx
FROM nginx:alpine AS runner

COPY --from=builder /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
