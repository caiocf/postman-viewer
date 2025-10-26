# syntax=docker/dockerfile:1

ARG TARGETPLATFORM


FROM --platform=$TARGETPLATFORM debian:bookworm-slim


ARG TARGETARCH

ARG POSTMAN_VERSION=latest
# Se quiser forçar uma URL específica, passe via --build-arg POSTMAN_DOWNLOAD_URL=...
ARG POSTMAN_DOWNLOAD_URL=

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=pt_BR.UTF-8 \
    LANGUAGE=pt_BR:pt:en \
    LC_ALL=pt_BR.UTF-8 \
    DISPLAY=:0 \
    RESOLUTION=1280x800x24 \
    APP_USER=app \
    APP_HOME=/home/app \
    POSTMAN_BIN=/opt/Postman/Postman \
    POSTMAN_CONFIG_DIR=/home/app/.config/Postman \
    ELECTRON_OZONE_PLATFORM_HINT=x11

# Pacotes básicos + noVNC + dependências do Postman (Electron)
RUN apt-get update && apt-get install -y \
    locales \
    xvfb x11vnc websockify novnc \
    openbox pcmanfm xterm unzip \
    ca-certificates curl tini \
    libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 libasound2 libgbm1 libgdk-pixbuf2.0-0 \
    libdrm2 libxshmfence1 libgl1 libglu1-mesa dbus-x11 \
 && sed -i 's/# pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen \
 && locale-gen \
 && useradd -m -s /bin/bash ${APP_USER} \
 && mkdir -p ${APP_HOME}/data ${POSTMAN_CONFIG_DIR}

# Baixa o Postman correto para a arquitetura (amd64 -> linux64, arm64 -> linux_arm64)
# Mantém a possibilidade de passar uma URL customizada via POSTMAN_DOWNLOAD_URL.
# syntax=docker/dockerfile:1.4

# na hora de baixar o Postman, escolha pela arquitetura:
RUN set -eux; \
  case "$TARGETARCH" in \
    amd64) url="https://dl.pstmn.io/download/version/9.31.30/linux64" ;; \
    arm64) url="https://dl.pstmn.io/download/latest/linux_arm64" ;; \
    *) echo "Arquitetura não suportada: $TARGETARCH"; exit 1 ;; \
  esac; \
  curl -fsSL "$url" -o /tmp/postman.tgz; \
  tar -xzf /tmp/postman.tgz -C /opt; \
  ln -sf /opt/Postman/Postman /usr/local/bin/postman; \
  rm -f /tmp/postman.tgz


RUN mkdir -p /home/app/.config/Postman && chown -R app:app /home/app/.config
USER ${APP_USER}
WORKDIR ${APP_HOME}

# script de entrada
COPY --chown=app:app start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Porta web do noVNC
EXPOSE 8080

# Healthcheck simples
HEALTHCHECK --interval=30s --timeout=5s --retries=5 \
  CMD curl -fsS http://localhost:8080/ || exit 1

ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/usr/local/bin/start.sh"]
