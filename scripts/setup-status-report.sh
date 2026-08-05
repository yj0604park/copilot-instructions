#!/usr/bin/env bash
# Wire up the daily system health report (23:00 local) on this machine.
#
#   macOS : user LaunchAgent com.paryoja.system-health (StartCalendarInterval)
#   Linux : crontab entry tagged "# copilot-status-report"
#
# Synology (DSM) has no crontab(1) — the script prints GUI Task Scheduler
# instructions and exits 1 rather than half-wiring anything.
#
# Idempotent. Requires the Slack token at ~/.config/system-health/env
# (SLACK_BOT_TOKEN + HEALTH_CHANNEL) — see setup-status-report.md for how to
# copy it from an already-configured machine.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_DIR/scripts/system-health.py"
ENV_FILE="$HOME/.config/system-health/env"
HOUR="${HEALTH_HOUR:-23}"
MINUTE="${HEALTH_MINUTE:-0}"

log()  { printf "\033[1;34m▶\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m✗\033[0m %s\n" "$*" >&2; }

[[ -f "$SCRIPT" ]] || { err "$SCRIPT 없음"; exit 1; }

if [[ ! -s "$ENV_FILE" ]]; then
  err "$ENV_FILE 없음 (SLACK_BOT_TOKEN / HEALTH_CHANNEL 필요)"
  echo "    설정된 머신에서 복사:" >&2
  echo "    ssh <host> 'cat ~/.config/system-health/env' | (umask 077 && mkdir -p ~/.config/system-health && cat > ~/.config/system-health/env)" >&2
  exit 1
fi
chmod 700 "$(dirname "$ENV_FILE")" 2>/dev/null || true
chmod 600 "$ENV_FILE" 2>/dev/null || true

PY="$(command -v python3 || true)"
[[ -n "$PY" ]] || { err "python3 없음"; exit 1; }

log "dry-run 검증..."
"$PY" "$SCRIPT" --dry-run >/dev/null || { err "dry-run 실패"; exit 1; }
ok "dry-run OK"

case "$(uname -s)" in
  Darwin)
    LABEL="com.paryoja.system-health"
    PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
    mkdir -p "$HOME/Library/LaunchAgents"
    cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$PY</string>
    <string>$SCRIPT</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>$HOUR</integer>
    <key>Minute</key><integer>$MINUTE</integer>
  </dict>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>RunAtLoad</key><false/>
  <key>StandardOutPath</key><string>/tmp/system-health.log</string>
  <key>StandardErrorPath</key><string>/tmp/system-health.log</string>
</dict>
</plist>
PLISTEOF
    # bootout/bootstrap (kickstart는 캐시된 정의를 써서 plist 변경이 안 먹는다)
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$PLIST"
    ok "LaunchAgent 등록: $LABEL (매일 $HOUR:$(printf '%02d' "$MINUTE"))"
    ;;
  Linux)
    LINE="$MINUTE $HOUR * * * $PY $SCRIPT >> /tmp/system-health.log 2>&1 # copilot-status-report"
    if ! command -v crontab >/dev/null 2>&1; then
      # Synology DSM ships no crontab(1): /etc/crontab is root-owned and DSM
      # rewrites it, so the supported path is the GUI Task Scheduler.
      err "crontab 없음 — Synology(DSM)로 보임. GUI로 등록해야 한다:"
      err "  제어판 → 작업 스케줄러 → 생성 → 예약된 작업 → 사용자 정의 스크립트"
      err "  사용자: $(id -un) / 매일 $HOUR:$(printf '%02d' "$MINUTE")"
      err "  명령: $PY $SCRIPT >> /tmp/system-health.log 2>&1"
      exit 1
    fi
    CUR="$(crontab -l 2>/dev/null || true)"
    if printf '%s\n' "$CUR" | grep -qF "copilot-status-report"; then
      NEW="$(printf '%s\n' "$CUR" | grep -vF "copilot-status-report")"
      printf '%s\n%s\n' "$NEW" "$LINE" | grep -v '^$' | crontab -
      ok "cron 갱신 (매일 $HOUR:$(printf '%02d' "$MINUTE"))"
    else
      { printf '%s\n' "$CUR"; printf '%s\n' "$LINE"; } | grep -v '^$' | crontab -
      ok "cron 등록 (매일 $HOUR:$(printf '%02d' "$MINUTE"))"
    fi
    ;;
  *)
    err "지원되지 않는 OS: $(uname -s)"
    exit 1
    ;;
esac

warn "servers/\$(hostname).md 의 '운영 메모'에 한 줄 기록하는 것 잊지 말 것"
