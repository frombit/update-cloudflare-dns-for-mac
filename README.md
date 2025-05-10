# Cloudflare Dynamic DNS Updater for macOS 🚀

[![Shell](https://img.shields.io/badge/shell-bash-blue?logo=gnu-bash)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/license-MIT-green)](#license)

A lightweight **Bash‑only** script that keeps a Cloudflare **A** record in sync with your Mac’s current IP address (external *or* internal). It also supports optional Telegram / Discord notifications.

---

## ✨ Features

* **Pure Bash** – no Python, PHP, or Node required; only `curl`, `jq`, and `dig`.
* **External / Internal IP** modes.
* **Cloudflare proxy (orange cloud) toggle**.
* Minimal dependencies & easy cron / launchd scheduling.
* Clear log file for every run.

---

## 📦 Prerequisites

| Tool                     | Install instruction                |
| ------------------------ | ---------------------------------- |
| **Homebrew**             | [https://brew.sh](https://brew.sh) |
| **jq**                   | `brew install jq`                  |
| Cloudflare **API Token** | “Edit zone DNS” permission         |

*macOS already ships with `curl`, `dig`, and `cron` / `launchd`.*

---

## ⚡ Quick start

```bash
# 1. Clone the repo
$ git clone https://github.com/<YOUR_ID>/cloudflare-ip-updater-mac.git
$ cd cloudflare-ip-updater-mac

# 2. Copy the sample config and fill in the blanks
$ cp update-cloudflare-dns_conf.sh.example update-cloudflare-dns_conf.sh
$ nano update-cloudflare-dns_conf.sh   # or use your editor of choice

# 3. Make the main script executable
$ chmod +x update-cloudflare-dns.sh

# 4. Test‑run
$ ./update-cloudflare-dns.sh
```

Successful output ends with something like:

```
==> Success!
==> sub.example.com DNS Record Updated To: 203.0.113.42, ttl: 300, proxied: true
```

---

## 🛠️ Configuration (`update-cloudflare-dns_conf.sh`)

```bash
# Cloudflare
zoneid="YOUR_ZONE_ID"
cloudflare_zone_api_token="YOUR_API_TOKEN"
dns_record="sub.example.com"

# Basic behaviour
ttl=300           # 120–7200 or 1 (auto)
proxied=true      # true / false
what_ip="external"  # external / internal

# Optional notifications
notify_me_telegram="no"   # yes / no
telegram_bot_API_Token=""
telegram_chat_id=""

notify_me_discord="no"    # yes / no
discord_webhook_URL=""
```

> **Tip:** keep the real config file **untracked** by Git. The sample file is safe to commit.

---

## 🔄 Automate it

### Cron (every 5 minutes)

```bash
*/5 * * * * /path/to/update-cloudflare-dns.sh >> /path/to/ddns.log 2>&1
```

### launchd (macOS LaunchAgent)

Save as `~/Library/LaunchAgents/com.user.cloudflare-ddns.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.user.cloudflare-ddns</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/Users/$USER/cloudflare-ip-updater-mac/update-cloudflare-dns.sh</string>
  </array>
  <key>StartInterval</key><integer>300</integer> <!-- 5 minutes -->
  <key>StandardOutPath</key><string>/tmp/cloudflare-ddns.out</string>
  <key>StandardErrorPath</key><string>/tmp/cloudflare-ddns.err</string>
</dict>
</plist>
```

```bash
launchctl load -w ~/Library/LaunchAgents/com.user.cloudflare-ddns.plist
```

---

## 📜 Logs

A timestamped log is written next to the script: `update-cloudflare-dns.log`. Tail it live:

```bash
tail -f update-cloudflare-dns.log
```

---

## 🩺 Troubleshooting

| Symptom                  | Fix                                                                     |
| ------------------------ | ----------------------------------------------------------------------- |
| `zsh: permission denied` | `chmod +x update-cloudflare-dns.sh`                                     |
| `Error! 'jq' not found`  | `brew install jq`                                                       |
| `Error! Update failed`   | Check API token scope, Zone ID, record name, and Cloudflare rate limits |
| "No changes needed"      | IP and proxy status haven’t changed – normal                            |

For deeper inspection run:

```bash
bash -x ./update-cloudflare-dns.sh 2>&1 | tee debug.log
```

---

## 🙏 Acknowledgements

* **Cloudflare** – free, powerful DNS with a great API.
* **Homebrew** and **jq** maintainers.

---

## 📄 License

MIT © 2025 Frombit
