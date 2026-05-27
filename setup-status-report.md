# Daily Status Report — 셋업 가이드

> 각 머신이 매일 23:00 (로컬 시간) 자기 헬스 리포트를 Slack DM(`C0AFD7AQ4QK`)에 보내도록 셋업.
> raspberrypi엔 이미 `scripts/system-health.py` + cron으로 운영 중. 다른 머신은 이 가이드 따라 셋업.

## 보낼 정보 (공통 섹션)

| 섹션 | 값 | 임계값 (warn / crit) |
|------|------|-----------|
| **copilot-instructions** | `<short-hash>@<branch>` (+ dirty / ahead / behind) | — |
| Disk (`/`) | 사용률 % | 80 / 90 |
| Memory | 사용률 % | 85 / 95 |
| Load avg | load1 / ncpu | 1.0× / 2.0× |
| CPU temp | °C (있으면) | 70 / 80 |
| Uptime | 사람이 읽기 좋게 | — |
| Failed services | systemd / launchd 실패 유닛 | — |
| 주요 서비스 | 머신별 서비스 active 여부 | — |

🟢 / 🟠 / 🔴 임계값 태그. 한 메시지로 묶어 발송.

**copilot-instructions 해시는 반드시 포함** — 어느 머신이 어떤 버전의 instructions으로 도는지 한눈에. 오래된 hash로 도는 머신을 즉시 발견하려는 목적.
구현 패턴 (`scripts/system-health.py`의 `copilot_instructions_info()` 참고):
```python
link = Path.home() / ".copilot" / "copilot-instructions.md"
repo = Path(os.path.realpath(link)).parent
hash = git("-C", repo, "rev-parse", "--short", "HEAD")
branch = git("-C", repo, "rev-parse", "--abbrev-ref", "HEAD")
dirty = bool(git("-C", repo, "status", "--porcelain"))
behind, ahead = git("-C", repo, "rev-list", "--left-right", "--count", "@{u}...HEAD").split()
```

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

## Secret 전달 (중요)

**원칙: agent 컨텍스트에 토큰을 노출하지 말 것**
- 토큰을 채팅창에 paste하면 conversation history / session store에 평문이 남음
- agent는 *경로/명령*만 다루고, *값*은 사용자가 직접 옮긴다
- 옮긴 직후 토큰이 출력된 터미널 스크롤백/`/tmp` 확인

### 권장 흐름 (SSH 가능할 때)

raspberrypi에 SSH 가능한 머신은 한 줄로:
```bash
ssh raspberrypi 'cat ~/.config/system-health/env' \
  | (umask 077 && mkdir -p ~/.config/system-health \
     && cat > ~/.config/system-health/env)
chmod 600 ~/.config/system-health/env
```

또는 raspberrypi 안에서 push:
```bash
scp ~/.config/system-health/env <new-host>:~/.config/system-health/env
ssh <new-host> 'chmod 600 ~/.config/system-health/env'
```

SSH key가 없으면 먼저 `ssh-copy-id` 또는 Tailscale SSH 활성화.

### Fallback (SSH 안 됨)

- raspberrypi에서 `cat` 으로 토큰 확인
- 새 머신에서 직접 `nano ~/.config/system-health/env` 입력 (절대 agent에게 paste 금지)
- 끝나면 raspberrypi 터미널 `clear` + scrollback 비우기

### agent의 역할

- 토큰 부재 감지 (`test -s ~/.config/system-health/env`)
- 위 명령을 안내만 하고 사용자가 실행
- 셋업 후엔 `python3 -c "import os; print(bool(open(...).read()))"` 정도로 *존재만* 확인 (값 출력 금지)
- 토큰 회전 필요 시도 동일 흐름

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
4. **토큰 파일 생성** ([[Secret 전달]] 섹션 참고 — agent에게 paste 금지)
   ```bash
   mkdir -p ~/.config/system-health && chmod 700 ~/.config/system-health
   # raspberrypi에서 SCP 또는 직접 nano로 입력
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
