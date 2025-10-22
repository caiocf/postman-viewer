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

# garante estrutura de dados e link simbolico quando o volume eh montado em $HOME/data
mkdir -p "${POSTMAN_CONFIG_DIR}" "${POSTMAN_DATA_DIR}"
if [ -d "${POSTMAN_DATA_DIR}" ] && [ ! -e "${POSTMAN_PARTITIONS_DIR}" ]; then
  ln -s "${POSTMAN_DATA_DIR}" "${POSTMAN_PARTITIONS_DIR}"
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
  "${POSTMAN_BIN}" --disable-gpu >/tmp/postman.log 2>&1 &
else
  echo "Postman nao encontrado em ${POSTMAN_BIN}" >&2
fi

# inicia noVNC servindo e tunelando para o servidor VNC
websockify --web /usr/share/novnc/ "${NOVNC_PORT}" "localhost:${VNC_PORT}"
