#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  🌐  ngrok-host  —  Expose any local folder to the internet via ngrok
#  https://github.com/krainium
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ─── Colours ──────────────────────────────────────────────────────────────────
R="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"
RED="\033[31m"
GRN="\033[32m"
YLW="\033[33m"
BLU="\033[34m"
MAG="\033[35m"
CYN="\033[36m"
WHT="\033[97m"

# ─── Config dir ───────────────────────────────────────────────────────────────
CFG_DIR="${HOME}/.ngrok-host"
TOKEN_FILE="${CFG_DIR}/authtoken.txt"
mkdir -p "$CFG_DIR"

# ─── PIDs of background processes (for cleanup) ───────────────────────────────
HTTP_PID=""
NGROK_PID=""

# ─── Cleanup on exit / Ctrl+C ─────────────────────────────────────────────────
cleanup() {
    echo ""
    echo -e "${YLW}⏹  Shutting down…${R}"
    if [[ -n "$NGROK_PID" ]] && kill -0 "$NGROK_PID" 2>/dev/null; then
        kill "$NGROK_PID" 2>/dev/null && echo -e "${DIM}   ngrok stopped${R}"
    fi
    if [[ -n "$HTTP_PID" ]] && kill -0 "$HTTP_PID" 2>/dev/null; then
        kill "$HTTP_PID" 2>/dev/null && echo -e "${DIM}   HTTP server stopped${R}"
    fi
    echo -e "${GRN}✅  Done. Your tunnel is closed.${R}"
    exit 0
}
trap cleanup SIGINT SIGTERM

# ─── Helper: print a banner line ──────────────────────────────────────────────
banner() {
    echo ""
    echo -e "${BLU}${BOLD}══════════════════════════════════════════════════════════${R}"
    echo -e "${WHT}${BOLD}  🌐  ngrok-host  —  VPS → Internet in one command${R}"
    echo -e "${BLU}${BOLD}══════════════════════════════════════════════════════════${R}"
    echo ""
}

# ─── Helper: check a command exists ───────────────────────────────────────────
need() {
    if ! command -v "$1" &>/dev/null; then
        echo -e "${RED}✖  '$1' not found.${R}"
        return 1
    fi
    return 0
}

# ─── Check / install ngrok ────────────────────────────────────────────────────
check_ngrok() {
    if need ngrok; then
        echo -e "${GRN}✔  ngrok found: $(ngrok version 2>/dev/null | head -1)${R}"
        return
    fi

    echo -e "${YLW}ngrok is not installed. Install it now? [Y/n]${R} \c"
    read -r ans
    ans="${ans:-Y}"
    if [[ ! "$ans" =~ ^[Yy]$ ]]; then
        echo -e "${RED}✖  ngrok required. Exiting.${R}"
        exit 1
    fi

    echo -e "${CYN}⬇  Detecting system architecture…${R}"
    ARCH="$(uname -m)"
    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

    case "$ARCH" in
        x86_64)   ARCH_TAG="amd64"   ;;
        aarch64|arm64) ARCH_TAG="arm64" ;;
        armv7*)   ARCH_TAG="arm"     ;;
        *)        echo -e "${RED}✖  Unsupported arch: $ARCH${R}"; exit 1 ;;
    esac

    NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-${OS}-${ARCH_TAG}.tgz"
    TMPDIR_NGROK="$(mktemp -d)"

    echo -e "${CYN}⬇  Downloading ngrok (${OS}/${ARCH_TAG})…${R}"
    if command -v curl &>/dev/null; then
        curl -fsSL "$NGROK_URL" -o "${TMPDIR_NGROK}/ngrok.tgz"
    elif command -v wget &>/dev/null; then
        wget -q "$NGROK_URL" -O "${TMPDIR_NGROK}/ngrok.tgz"
    else
        echo -e "${RED}✖  Neither curl nor wget found. Install one and retry.${R}"
        exit 1
    fi

    tar -xzf "${TMPDIR_NGROK}/ngrok.tgz" -C "${TMPDIR_NGROK}"
    INSTALL_DIR="${HOME}/.local/bin"
    mkdir -p "$INSTALL_DIR"
    mv "${TMPDIR_NGROK}/ngrok" "${INSTALL_DIR}/ngrok"
    chmod +x "${INSTALL_DIR}/ngrok"
    rm -rf "$TMPDIR_NGROK"

    export PATH="${INSTALL_DIR}:${PATH}"

    if ! need ngrok; then
        # Try /usr/local/bin with sudo if local install didn't work in PATH
        echo -e "${YLW}  Adding ${INSTALL_DIR} to PATH for this session.${R}"
        echo -e "${YLW}  Add this to your ~/.bashrc or ~/.zshrc to make it permanent:${R}"
        echo -e "${DIM}  export PATH=\"${INSTALL_DIR}:\$PATH\"${R}"
    fi

    echo -e "${GRN}✔  ngrok installed: $(ngrok version 2>/dev/null | head -1)${R}"
}

# ─── Check HTTP server backend ────────────────────────────────────────────────
check_http_backend() {
    if need python3; then
        HTTP_BACKEND="python3"
        echo -e "${GRN}✔  HTTP backend: Python 3 $(python3 --version 2>&1 | awk '{print $2}')${R}"
    elif need python; then
        HTTP_BACKEND="python"
        echo -e "${GRN}✔  HTTP backend: Python $(python --version 2>&1 | awk '{print $2}')${R}"
    elif need npx; then
        HTTP_BACKEND="npx"
        echo -e "${GRN}✔  HTTP backend: Node.js / serve${R}"
    else
        echo -e "${RED}✖  No HTTP server backend found (python3 / python / node).${R}"
        echo -e "${YLW}  Install Python 3:  sudo apt install python3${R}"
        exit 1
    fi
}

# ─── Manage ngrok auth token ──────────────────────────────────────────────────
setup_token() {
    if [[ -f "$TOKEN_FILE" ]]; then
        SAVED_TOKEN="$(cat "$TOKEN_FILE")"
        echo ""
        echo -e "${CYN}🔑  Saved ngrok auth token found.${R}"
        echo -e "    ${DIM}${SAVED_TOKEN:0:12}…${R}"
        echo -e "${CYN}    Use saved token? [Y/n]:${R} \c"
        read -r use_saved
        use_saved="${use_saved:-Y}"
        if [[ "$use_saved" =~ ^[Yy]$ ]]; then
            NGROK_TOKEN="$SAVED_TOKEN"
            echo -e "${GRN}    ✔  Using saved token.${R}"
            return
        fi
    fi

    echo ""
    echo -e "${YLW}🔑  Enter your ngrok auth token.${R}"
    echo -e "${DIM}    Get one free at: https://dashboard.ngrok.com/authtokens${R}"
    echo -e "${CYN}    Token:${R} \c"
    read -r NGROK_TOKEN
    NGROK_TOKEN="${NGROK_TOKEN// /}"

    if [[ -z "$NGROK_TOKEN" ]]; then
        echo -e "${RED}✖  No token entered. Exiting.${R}"
        exit 1
    fi

    echo "$NGROK_TOKEN" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    echo -e "${GRN}    ✔  Token saved to ${TOKEN_FILE}${R}"
}

# ─── Apply ngrok auth token ────────────────────────────────────────────────────
apply_token() {
    ngrok config add-authtoken "$NGROK_TOKEN" &>/dev/null || true
}

# ─── Pick folder to serve ─────────────────────────────────────────────────────
pick_folder() {
    echo ""
    echo -e "${MAG}📁  Path to the folder you want to host:${R}"
    echo -e "${DIM}    (press Enter to use current directory: $(pwd))${R}"
    echo -e "${CYN}    Folder path:${R} \c"
    read -r FOLDER
    FOLDER="${FOLDER:-$(pwd)}"

    # Expand ~ manually
    FOLDER="${FOLDER/#\~/$HOME}"

    if [[ ! -d "$FOLDER" ]]; then
        echo -e "${RED}✖  Directory not found: ${FOLDER}${R}"
        exit 1
    fi

    FOLDER="$(cd "$FOLDER" && pwd)"   # Absolute path
    echo -e "${GRN}    ✔  Serving: ${BOLD}${FOLDER}${R}"
}

# ─── Pick port ────────────────────────────────────────────────────────────────
pick_port() {
    echo ""
    echo -e "${MAG}🔌  Local port to bind the HTTP server on:${R}"
    echo -e "${DIM}    (press Enter for default: 8080)${R}"
    echo -e "${CYN}    Port:${R} \c"
    read -r PORT
    PORT="${PORT:-8080}"

    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
        echo -e "${RED}✖  Invalid port: ${PORT}${R}"
        exit 1
    fi

    # Check port is free
    if command -v ss &>/dev/null; then
        if ss -tlnp 2>/dev/null | grep -q ":${PORT} "; then
            echo -e "${YLW}⚠  Port ${PORT} is already in use. Pick a different port? [Y/n]:${R} \c"
            read -r try_another
            if [[ "${try_another:-Y}" =~ ^[Yy]$ ]]; then
                pick_port
                return
            fi
        fi
    fi

    echo -e "${GRN}    ✔  Port: ${PORT}${R}"
}

# ─── Optional: custom subdomain / region ─────────────────────────────────────
pick_ngrok_options() {
    echo ""
    echo -e "${MAG}🌍  ngrok region  (us / eu / ap / au / sa / jp / in):${R}"
    echo -e "${DIM}    (press Enter to skip — ngrok picks automatically)${R}"
    echo -e "${CYN}    Region:${R} \c"
    read -r NGROK_REGION

    NGROK_REGION_FLAG=""
    if [[ -n "$NGROK_REGION" ]]; then
        NGROK_REGION_FLAG="--region=${NGROK_REGION}"
        echo -e "${GRN}    ✔  Region: ${NGROK_REGION}${R}"
    else
        echo -e "${DIM}    Region: auto${R}"
    fi
}

# ─── Start HTTP file server ───────────────────────────────────────────────────
start_http_server() {
    echo ""
    echo -e "${CYN}🚀  Starting local HTTP server on port ${PORT}…${R}"

    case "$HTTP_BACKEND" in
        python3)
            python3 -m http.server "$PORT" --directory "$FOLDER" \
                >"${CFG_DIR}/http.log" 2>&1 &
            HTTP_PID=$!
            ;;
        python)
            # Python 2 doesn't support --directory; cd first
            ( cd "$FOLDER" && python -m SimpleHTTPServer "$PORT" ) \
                >"${CFG_DIR}/http.log" 2>&1 &
            HTTP_PID=$!
            ;;
        npx)
            npx --yes serve "$FOLDER" -l "$PORT" \
                >"${CFG_DIR}/http.log" 2>&1 &
            HTTP_PID=$!
            ;;
    esac

    sleep 1
    if ! kill -0 "$HTTP_PID" 2>/dev/null; then
        echo -e "${RED}✖  HTTP server failed to start. Check ${CFG_DIR}/http.log${R}"
        exit 1
    fi
    echo -e "${GRN}    ✔  HTTP server running (PID ${HTTP_PID})${R}"
}

# ─── Start ngrok tunnel ───────────────────────────────────────────────────────
start_ngrok() {
    echo -e "${CYN}🌐  Starting ngrok tunnel…${R}"

    ngrok http "$PORT" \
        ${NGROK_REGION_FLAG:+"$NGROK_REGION_FLAG"} \
        --log=stdout \
        >"${CFG_DIR}/ngrok.log" 2>&1 &
    NGROK_PID=$!

    # Wait up to 10s for ngrok API to become available
    MAX_WAIT=10
    WAITED=0
    while (( WAITED < MAX_WAIT )); do
        if curl -sf http://127.0.0.1:4040/api/tunnels &>/dev/null; then
            break
        fi
        sleep 1
        (( WAITED++ ))
    done

    if (( WAITED >= MAX_WAIT )); then
        echo -e "${RED}✖  ngrok did not start in time. Check ${CFG_DIR}/ngrok.log${R}"
        cat "${CFG_DIR}/ngrok.log" | tail -20
        exit 1
    fi
}

# ─── Get and display the public URL ───────────────────────────────────────────
show_url() {
    TUNNEL_JSON="$(curl -sf http://127.0.0.1:4040/api/tunnels)"
    PUBLIC_URL="$(echo "$TUNNEL_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin)
tunnels=d.get('tunnels',[])
https=[t for t in tunnels if t.get('proto')=='https']
http_=[t for t in tunnels if t.get('proto')=='http']
best=https if https else http_
print(best[0]['public_url'] if best else 'unknown')
" 2>/dev/null)"

    echo ""
    echo -e "${BLU}${BOLD}══════════════════════════════════════════════════════════${R}"
    echo -e "${GRN}${BOLD}  ✅  Your site is LIVE on the internet!${R}"
    echo -e "${BLU}${BOLD}══════════════════════════════════════════════════════════${R}"
    echo ""
    echo -e "  ${WHT}${BOLD}Public URL  →  ${GRN}${BOLD}${PUBLIC_URL}${R}"
    echo ""
    echo -e "  ${DIM}Serving folder :  ${FOLDER}${R}"
    echo -e "  ${DIM}Local port     :  ${PORT}${R}"
    echo -e "  ${DIM}ngrok inspect  :  http://127.0.0.1:4040${R}"
    echo ""
    echo -e "${BLU}${BOLD}══════════════════════════════════════════════════════════${R}"
    echo ""
    echo -e "${YLW}  Anyone with that URL can now access your files.${R}"
    echo -e "${YLW}  Press ${BOLD}Ctrl+C${R}${YLW} to stop and close the tunnel.${R}"
    echo ""
}

# ─── Live request log ─────────────────────────────────────────────────────────
watch_logs() {
    echo -e "${DIM}─── Live requests ──────────────────────────────────────────${R}"
    echo ""
    # Tail ngrok's own log for request lines
    # ngrok writes structured JSON — extract the url field
    tail -f "${CFG_DIR}/http.log" 2>/dev/null | while IFS= read -r line; do
        echo -e "  ${DIM}$(date '+%H:%M:%S')${R}  $line"
    done
}

# ──────────────────────────────────────────────────────────────────────────────
#  MAIN
# ──────────────────────────────────────────────────────────────────────────────
banner

echo -e "${CYN}${BOLD}Checking dependencies…${R}"
check_ngrok
check_http_backend

setup_token
apply_token

pick_folder
pick_port
pick_ngrok_options

echo ""
echo -e "${DIM}─────────────────────────────────────────────────────────${R}"

start_http_server
start_ngrok
show_url
watch_logs
