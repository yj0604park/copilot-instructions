# Daily Status Report — 셋업 가이드

> 각 머신이 매일 23:00 (로컬 시간) 자기 헬스 리포트를 Slack DM(`C0AFD7AQ4QK`)에 보내도록 셋업.
> raspberrypi엔 이미 `scripts/system-health.py` + cron으로 운영 중. 다른 머신은 이 가이드 따라 셋업.

## 보낼 정보 (공통 섹션)

| 섹션 | 값 | 임계값 (warn / crit) |
|------|------|-----------|
| Disk (`/`) | 사용률 % | 80 / 90 |
| Memory | 사용률 % | 85 / 95 |
| Load avg | load1 / ncpu | 1.0× / 2.0× |
| CPU temp | °C (있으면) | 70 / 80 |
| Uptime | 사람이 읽기 좋게 | — |
| Failed services | systemd / launchd 실패 유닛 | — |
| 주요 서비스 | 머신별 서비스 active 여부 | — |

🟢 / 🟠 / 🔴 임계값 태그. 한 메시지로 묶어 발송.

## 머신별 OS 차이

| 항목 | Linux (Debian/Synology) | macOS |
|------|------------------------|-------|
| Disk | `psutil.disk_usage('/')` | 동일 |
| Memory | `psutil.virtual_memory()` | 동일 |
| Load | `os.getloadavg()` | 동일 |
| CPU temp | `/sys/class/thermal/thermal_zone0/temp` 또는 `sensors` | `osx-cpu-temp` (brew) 또는 skip |
| Failed units | `systemctl --failed --plain` | `launchctl list \| awk '$2 != "0" && $2 != "-"'` |
| Uptime | `uptime` 또는 `/proc/uptime` | `uptime` |

Synology(yozit) 추가:
- 디스크 SMART: `synodisksmart`
- HW 온도: `synohw` 또는 `/sys/class/hwmon/`
- 서비스: `synosystemctl status`

## 발송 방식 (Slack)

`flush-pending-alerts.py`가 쓰는 bot token을 재사용 (`xoxb-...`).

```python
import urllib.request, json
def post(token, channel, text):
    req = urllib.request.Request(
        "https://slack.com/api/chat.postMessage",
        data=json.dumps({"channel": channel, "text": text, "mrkdwn": True}).encode(),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=10).read())
```

토큰 위치: `~/.config/system-health/env` (`chmod 600`)
```
SLACK_BOT_TOKEN=xoxb-...
HEALTH_CHANNEL=C0AFD7AQ4QK
```

> 같은 bot 토큰을 여러 머신에서 공유. 일반 가정 셋업에선 OK. 토큰 분리는 추후.

## 셋업 단계 (체크리스트)

새 머신에서 copilot이 첫 세션에 다음을 수행:

1. **셋업 여부 확인**
   ```bash
   crontab -l | grep -iE "system-health|status-report" || echo "NOT_SETUP"
   ```
2. 미셋업이면 사용자에게 셋업 동의 요청
3. **레퍼런스 복사**
   - raspberrypi의 `scripts/system-health.py`를 새 머신 환경에 맞게 포팅
   - 또는 단일 portable script 작성 (`scripts/system-health-portable.py` — 향후 작업)
4. **토큰 파일 생성**
   ```bash
   mkdir -p ~/.config/system-health
   touch ~/.config/system-health/env && chmod 600 ~/.config/system-health/env
   # 사용자에게 SLACK_BOT_TOKEN 받아서 적음 (또는 raspberrypi에서 SCP)
   ```
5. **수동 테스트**
   ```bash
   python3 scripts/system-health.py --dry-run  # 메시지 출력만
   python3 scripts/system-health.py            # 실제 발송
   ```
6. **cron 등록 (로컬 23:00)**
   ```cron
   0 23 * * * /usr/bin/python3 /path/to/scripts/system-health.py >> /tmp/system-health.log 2>&1
   ```
7. **운영 기록**
   - `copilot-instructions/servers/{hostname}.md`의 운영 메모 섹션에 한 줄 추가:
     ```
     - status report: cron 0 23, scripts/system-health.py → Slack DM
     ```
8. commit + push

## 잠재 follow-up

- `scripts/system-health-portable.py` — OS 자동 감지로 한 스크립트가 Linux/macOS/Synology 다 지원
- 발송 채널을 `flush-pending-alerts` 패턴으로 통일 (각 머신이 SSH로 raspberrypi의 `pending-alerts/`에 drop)
  - 장점: 토큰을 raspberrypi 한 곳에만
  - 단점: SSH key + Tailscale 의존
- inbox API에 `type=health` 추가해서 raspberrypi heartbeat가 forward
