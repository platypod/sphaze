# --- Web build ---
FROM haxe:4.3.7-alpine AS builder
WORKDIR /app
RUN haxelib install heaps --always
COPY src/ ./src/
COPY res/ ./res/
COPY build.hxml index.html ./
RUN haxe build.hxml && cp index.html bin/index.html

# --- Static server ---
FROM nginx:alpine

LABEL org.opencontainers.image.source=https://github.com/platypod/sphaze

COPY --from=builder /app/bin /usr/share/nginx/html

EXPOSE 80
