# API Minuto a Minuto - Desplegable como Node.js en Railway, Render, Fly.io, etc.
FROM dart:stable AS build
WORKDIR /app
COPY pubspec.yaml ./
RUN dart pub get
COPY bin/ bin/
RUN dart compile exe bin/server.dart -o bin/server

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/bin/server ./
EXPOSE 8080
# Render inyecta PORT dinámicamente; sin eso usa 8080
CMD ["./server"]
