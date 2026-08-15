FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG GODOT_VERSION=4.6.3

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl unzip libfontconfig1 libgl1 libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 \
    && curl -fsSL -o /tmp/godot.zip "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
    && unzip -q /tmp/godot.zip -d /usr/local/bin \
    && mv "/usr/local/bin/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm -rf /var/lib/apt/lists/* /tmp/godot.zip

WORKDIR /opt/nexora-deadfall
COPY . .

ENV DEADFALL_PORT=24560 \
    DEADFALL_DIRECTORY_PORT=24561 \
    DEADFALL_PUBLIC_HOST=127.0.0.1 \
    DEADFALL_ROOM_CODE=""

EXPOSE 24560/udp
EXPOSE 24561/tcp

CMD ["bash", "scripts/server/run_server.sh"]
