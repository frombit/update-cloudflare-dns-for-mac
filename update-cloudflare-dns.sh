#!/usr/bin/env bash
set -euo pipefail

# ---------- 기본 설정 ----------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/update-cloudflare-dns.log"
CONFIG_FILE="$SCRIPT_DIR/update-cloudflare-dns_conf.sh"

DATE="$(date '+%Y/%m/%d %H:%M:%S')"
echo "==> $DATE" | tee "$LOG_FILE"

# ---------- 설정 파일 로드 ----------
if [[ ! -f $CONFIG_FILE ]]; then
  echo "==> Error! Missing $CONFIG_FILE" | tee -a "$LOG_FILE"; exit 1
fi
# shellcheck source=/dev/null
. "$CONFIG_FILE"

# ---------- 파라미터 검증 ----------
if ! [[ "$ttl" =~ ^[0-9]+$ ]] || { (( ttl < 120 || ttl > 7200 )) && (( ttl != 1 )); }; then
  echo "Error! ttl out of range (120-7200) or not 1" | tee -a "$LOG_FILE"; exit 1
fi

if [[ "$proxied" != "true" && "$proxied" != "false" ]]; then
  echo 'Error! proxied must be "true" or "false"' | tee -a "$LOG_FILE"; exit 1
fi

if [[ "$what_ip" != "external" && "$what_ip" != "internal" ]]; then
  echo 'Error! what_ip must be "external" or "internal"' | tee -a "$LOG_FILE"; exit 1
fi

if [[ "$what_ip" == "internal" && "$proxied" == "true" ]]; then
  echo "Error! Internal IP cannot be proxied" | tee -a "$LOG_FILE"; exit 1
fi

# ---------- IP 확보 ----------
if [[ "$what_ip" == "external" ]]; then
  ip="$(curl -fs --max-time 10 https://checkip.amazonaws.com | tr -d '\n')"
  [[ -n "$ip" ]] || { echo "Error! Can't get external IP" | tee -a "$LOG_FILE"; exit 1; }
  echo "==> External IP is: $ip" | tee -a "$LOG_FILE"
else
  default_if="$(route -n get 1.1.1.1 2>/dev/null | awk '/interface:/{print $2; exit}')"
  ip="$(ipconfig getifaddr "$default_if" 2>/dev/null || true)"
  [[ -n "$ip" && "$ip" != "127.0.0.1" ]] || { echo "Error! Can't get internal IP" | tee -a "$LOG_FILE"; exit 1; }
  echo "==> Internal IP is: $ip" | tee -a "$LOG_FILE"
fi

# ---------- 현재 DNS 레코드 상태 ----------
if [[ "$proxied" == "false" ]]; then
  dns_record_ip="$(dig +short @1.1.1.1 "$dns_record" A | head -n1 | tr -d '\n')"
  [[ -n "$dns_record_ip" ]] || { echo "Error! Can't resolve $dns_record via 1.1.1.1" | tee -a "$LOG_FILE"; exit 1; }
  is_proxied="$proxied"
else
  record_info="$(curl -s -H "Authorization: Bearer $cloudflare_zone_api_token" \
                       -H "Content-Type: application/json" \
                       "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?name=$dns_record")"

  if ! echo "$record_info" | grep -q '"success":true'; then
    echo "Error! Can't get DNS record info from Cloudflare API" | tee -a "$LOG_FILE"; exit 1
  fi

  dns_record_ip="$(echo "$record_info" | jq -r '.result[0].content')"
  is_proxied="$(echo "$record_info"   | jq -r '.result[0].proxied')"
  dns_record_id="$(echo "$record_info" | jq -r '.result[0].id')"
fi

# ---------- 변경 필요 여부 확인 ----------
if [[ "$dns_record_ip" == "$ip" && "$is_proxied" == "$proxied" ]]; then
  echo "==> DNS record IP is $dns_record_ip, no changes needed. Exiting..." | tee -a "$LOG_FILE"
  exit 0
fi

echo "==> DNS record of $dns_record is: $dns_record_ip. Trying to update..." | tee -a "$LOG_FILE"

# ---------- Cloudflare 레코드 ID (proxied=false 인 경우 추가 조회) ----------
if [[ -z "${dns_record_id:-}" ]]; then
  record_info="$(curl -s -H "Authorization: Bearer $cloudflare_zone_api_token" \
                       -H "Content-Type: application/json" \
                       "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?name=$dns_record")"
  dns_record_id="$(echo "$record_info" | jq -r '.result[0].id')"
fi

# ---------- 레코드 업데이트 ----------
update_payload=$(cat <<EOF
{
  "type": "A",
  "name": "$dns_record",
  "content": "$ip",
  "ttl": $ttl,
  "proxied": $proxied
}
EOF
)
update_response="$(curl -s -X PUT \
  -H "Authorization: Bearer $cloudflare_zone_api_token" \
  -H "Content-Type: application/json" \
  -d "$update_payload" \
  "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$dns_record_id")"

if ! echo "$update_response" | grep -q '"success":true'; then
  echo "Error! Update failed" | tee -a "$LOG_FILE"; exit 1
fi

echo "==> Success!" | tee -a "$LOG_FILE"
echo "==> $dns_record DNS Record Updated To: $ip, ttl: $ttl, proxied: $proxied" | tee -a "$LOG_FILE"

# ---------- 알림 ----------
if [[ "$notify_me_telegram" == "yes" ]]; then
  curl -s --get \
    --data-urlencode "chat_id=$telegram_chat_id" \
    --data-urlencode "text=$dns_record DNS Record Updated To: $ip" \
    "https://api.telegram.org/bot${telegram_bot_API_Token}/sendMessage" > /dev/null || \
    echo "Error! Telegram notification failed" | tee -a "$LOG_FILE"
fi

if [[ "$notify_me_discord" == "yes" ]]; then
  discord_payload=$(printf '{"content":"%s"}' "$dns_record DNS Record Updated To: $ip (was $dns_record_ip)")
  curl -s -H "Content-Type: application/json" -d "$discord_payload" "$discord_webhook_URL" > /dev/null || \
    echo "Error! Discord notification failed" | tee -a "$LOG_FILE"
fi
