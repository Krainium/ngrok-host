# 🌐 ngrok-host

A single shell script that puts any folder on the internet via ngrok in under 30 seconds. Works on a VPS, your local Linux machine, or your Mac. No config files to write. No web server to manage. Just run, paste your folder path, and share the public URL.

---

## 🎯 What It Does

- 📁 Serves **any local folder** over HTTP on a port you pick
- 🌐 Opens a public **ngrok HTTPS tunnel** to that port in seconds
- 🔑 Saves your ngrok auth token so you only enter it once
- 🔄 Auto-detects system arch and **installs ngrok** if it's missing
- 🛡️ Three-layer URL detection — never hangs, always shows your link
- ✅ Works on VPS, local Linux, and Mac — same script, same commands
- 🛑 `Ctrl+C` cleanly kills both the tunnel and the HTTP server
- 📊 Live request log in the terminal so you see every hit
- 🌍 Optional region picker — US, EU, AP, AU, SA, JP, IN

---

## 💻 Platform Setup

### 🐧 Linux (VPS or local machine)

Nothing extra needed. Bash and Python 3 are already on any modern Linux. Just run:

```bash
chmod +x ngrok-host.sh
./ngrok-host.sh
```

### 🍎 Mac

Bash and Python 3 come pre-installed on macOS. Run it the same way:

```bash
chmod +x ngrok-host.sh
./ngrok-host.sh
```

If Python 3 is missing on a fresh Mac install:
```bash
brew install python3
```

### 🪟 Windows

The script is a bash file — Windows can't run it directly. You need a bash environment first. The easiest option is **Git Bash**, which most developers already have:

1. Download and install [Git for Windows](https://git-scm.com/download/win) — Git Bash is included
2. Open **Git Bash** (not Command Prompt or PowerShell)
3. Navigate to the folder with the script:
   ```bash
   cd /c/Users/YourName/Downloads/ngrok-host
   ```
4. Run it:
   ```bash
   chmod +x ngrok-host.sh
   ./ngrok-host.sh
   ```

**Windows options compared:**

| Option | Best for |
|--------|----------|
| **Git Bash** | Easiest — lightweight, most devs have it already |
| **WSL (Windows Subsystem for Linux)** | Full Linux inside Windows — best for heavy use |
| **Cygwin** | Older option, works but harder to set up |

> Python does **not** need to be installed separately on Windows when using Git Bash or WSL — it is available inside those environments already.

---

## 🚀 Usage

The script walks you through four questions, then prints your public link:

```
🔑  Enter your ngrok auth token:  <paste once, saved for next time>

📁  Path to the folder you want to host:  /var/www/myproject
                                         (Enter = current directory)

🔌  Local port:   8080    (Enter = default)

🌍  Region:       eu      (Enter = auto)
```

Output:

```
══════════════════════════════════════════════════════════
  ✅  Your site is LIVE on the internet!
══════════════════════════════════════════════════════════

  Public URL  →  https://a3f8-12-34-56-78.ngrok-free.app

  Serving folder :  /var/www/myproject
  Local port     :  8080
  ngrok inspect  :  http://127.0.0.1:4040

══════════════════════════════════════════════════════════

  Anyone with that URL can now access your files.
  Press Ctrl+C to stop and close the tunnel.
```

---

## 🔑 Getting Your ngrok Auth Token

1. Go to [dashboard.ngrok.com/authtokens](https://dashboard.ngrok.com/authtokens)
2. Sign up (free)
3. Copy the token — paste it when the script asks
4. It gets saved to `~/.ngrok-host/authtoken.txt` — you only do this once

---

## 📋 Requirements

| Requirement | Linux / VPS | Mac | Windows (Git Bash / WSL) |
|-------------|-------------|-----|--------------------------|
| **Bash** | ✅ built-in | ✅ built-in | ✅ Git Bash or WSL |
| **Python 3** | ✅ pre-installed | ✅ pre-installed | ✅ inside Git Bash / WSL |
| **curl** | ✅ pre-installed | ✅ pre-installed | ✅ inside Git Bash / WSL |
| **ngrok** | auto-installed by script | auto-installed | auto-installed |
| **ngrok account** | free at [dashboard.ngrok.com](https://dashboard.ngrok.com) | same | same |

---

## 📁 What Gets Served

Everything in the folder you point to — exactly like a static web server.

| Folder contents | What visitors see |
|----------------|-------------------|
| `index.html` | That page loads at the root URL |
| `photo.jpg` | Direct download at `/photo.jpg` |
| `docs/report.pdf` | Accessible at `/docs/report.pdf` |
| No `index.html` | Directory listing — all files browsable |

This is ideal for:
- Sharing a build output or static site from your machine or VPS
- Letting someone preview your local project without deploying
- Exposing a locally running API or web app to the internet
- Sending someone a file without using cloud storage
- Testing webhooks from services like Stripe, GitHub, or Shopify

---

## ⚙️ How It Works

```
┌──────────────────┐       HTTP        ┌──────────────────┐      HTTPS      ┌─────────────────┐
│  Your machine    │  ──────────────▶  │  python3         │  ─────────────▶  │  Public URL     │
│  (any folder)    │  localhost:PORT   │  -m http.server  │  ngrok tunnel    │  (anyone)       │
└──────────────────┘                   └──────────────────┘                  └─────────────────┘
```

1. Python's built-in `http.server` serves the folder over localhost
2. ngrok opens a secure tunnel from their edge to your local port
3. Visitors hit the public ngrok URL → traffic forwards to Python → files served

---

## 🛡️ URL Detection — Three Layers

ngrok's API comes up before the tunnel entry is fully registered. The script handles this with three fallback stages so it never silently hangs or exits:

| Stage | Method | Notes |
|-------|--------|-------|
| **1** | Poll ngrok API `/api/tunnels` for a live `public_url` | Retries every second for up to 10s |
| **2** | Grep ngrok's log file for `url=https://...` | Works even if the API response is slow |
| **3** | Print a clear message pointing to `http://127.0.0.1:4040` | Last resort — never a silent failure |

---

## 🔄 Saved Settings

| File | What's stored |
|------|---------------|
| `~/.ngrok-host/authtoken.txt` | Your ngrok auth token (chmod 600) |
| `~/.ngrok-host/http.log` | HTTP server output (last session) |
| `~/.ngrok-host/ngrok.log` | ngrok output (last session) |

On the next run the script asks: `Use saved token? [Y/n]` — hit Enter to skip re-typing it.

---

## 🛑 Stopping

Press `Ctrl+C`. The script catches the signal and kills both the HTTP server and the ngrok process before exiting. The public URL goes dead immediately.

---

## 🔧 Advanced: Running in the Background

If you want to keep the tunnel running after closing your terminal or SSH session, wrap it with `tmux` or `screen`:

```bash
tmux new -s host
./ngrok-host.sh
# Ctrl+B then D to detach — tunnel stays alive
```

To reconnect:
```bash
tmux attach -t host
```

---

## 🌍 Supported Architectures

| CPU | Supported |
|-----|-----------|
| x86_64 (most VPS and desktops) | ✅ |
| ARM64 (Raspberry Pi, AWS Graviton, Apple Silicon) | ✅ |
| ARMv7 (older Pi) | ✅ |

---

## ✅ Live Smoke Test — Verified

Tested live on April 24, 2026. A folder with a single `index.html` was served via the script, tunneled through ngrok, and loaded in a browser over the public internet.

**Terminal output:**
```
══════════════════════════════════════════════
  ✅  LIVE: https://55b8-34-58-106-177.ngrok-free.app
══════════════════════════════════════════════
```

**Browser confirmation:**

![Live smoke test — "yo its me" loaded in browser over ngrok HTTPS tunnel](test-proof.png)

URL in the address bar: `https://55b8-34-58-106-177.ngrok-free.app`  
Page content: served from a local folder, live on the internet in under 4 seconds.
