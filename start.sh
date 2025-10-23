#!/usr/bin/env bash
set -euo pipefail

# valores padrao (pode sobrescrever com env vars)
: "${DISPLAY:=:0}"
: "${RESOLUTION:=1280x800x24}"
: "${POSTMAN_BIN:=/opt/Postman/Postman}"
: "${POSTMAN_CONFIG_DIR:=$HOME/.config/Postman}"
: "${POSTMAN_PARTITIONS_DIR:=${POSTMAN_CONFIG_DIR}/Partitions}"
: "${POSTMAN_DATA_DIR:=$HOME/data}"
: "${VNC_PORT:=5900}"
: "${NOVNC_PORT:=8080}"
: "${POSTMAN_FLAGS:=--disable-gpu --disable-dev-shm-usage --no-sandbox --disable-setuid-sandbox --disable-gpu-sandbox --disable-software-rasterizer --disable-features=VizDisplayCompositor --use-gl=swiftshader --in-process-gpu}"

# garante estrutura de dados e link simbolico quando o volume eh montado em $HOME/data
mkdir -p "${POSTMAN_CONFIG_DIR}" "${POSTMAN_DATA_DIR}"
if [ -d "${POSTMAN_DATA_DIR}" ] && [ ! -e "${POSTMAN_PARTITIONS_DIR}" ]; then
  ln -s "${POSTMAN_DATA_DIR}" "${POSTMAN_PARTITIONS_DIR}"
fi

# inicia dbus de sessao para evitar falhas do Electron
if command -v dbus-daemon >/dev/null 2>&1; then
  DBUS_ADDRESS_FILE=$(mktemp)
  if dbus-daemon --session --fork --print-address > "${DBUS_ADDRESS_FILE}"; then
    DBUS_SESSION_BUS_ADDRESS=$(cat "${DBUS_ADDRESS_FILE}")
    export DBUS_SESSION_BUS_ADDRESS
  fi
  rm -f "${DBUS_ADDRESS_FILE}"
fi

# inicia X virtual
Xvfb "${DISPLAY}" -screen 0 "${RESOLUTION}" -nolisten tcp &
sleep 0.5

# inicia gerenciador de janelas + explorador de arquivos
openbox &
pcmanfm "${POSTMAN_PARTITIONS_DIR}" &

# inicia servidor VNC ligado no Xvfb
x11vnc -display "${DISPLAY}" -rfbport "${VNC_PORT}" -forever -shared -nopw -quiet &

# inicia Postman apontando para o DISPLAY atual
if [ -x "${POSTMAN_BIN}" ]; then
  # Flags padrao reduzem dependencia de GPU/sandbox, util em ambientes ARM com emulacao
  "${POSTMAN_BIN}" ${POSTMAN_FLAGS} >/tmp/postman.log 2>&1 &
else
  echo "Postman nao encontrado em ${POSTMAN_BIN}" >&2
fi

# inicia noVNC servindo e tunelando para o servidor VNC
websockify --web /usr/share/novnc/ "${NOVNC_PORT}" "localhost:${VNC_PORT}"
