# Bookone — MacBook Pro M4 Pro (개발 메인)

## 스펙
- **모델**: MacBook Pro (Mac16,8)
- **CPU**: Apple M4 Pro, 12코어 (8P + 4E)
- **메모리**: 24GB
- **OS**: macOS 26.5
- **Tailscale**: bookone.tail591527.ts.net

## 역할
- 개발 메인 머신
- Copilot CLI 주로 여기서 실행
- SSH로 다른 서버 원격 작업

## 주요 도구
- OrbStack (Docker)
- VS Code
- iTerm2
- Obsidian (Synology Drive 동기화)

## 프로젝트 경로
- `~/Workspace/` — 작업 디렉토리
- `~/Workspace/copilot-instructions/` — dotfiles/instructions repo

## 운영 메모
- copilot-supervisor: user LaunchAgent 2개 — `com.paryoja.copilot-supervisor-server`(control plane, FastAPI+SQLite), `com.paryoja.copilot-supervisor-runner`(polling runner → Copilot CLI 실행). 둘 다 `RunAtLoad`+`KeepAlive` 상시. repo `~/Workspace/copilot-supervisor`, 실행 스크립트 `scripts/svc-{server,runner}.sh`, 로그 `~/Library/Logs/com.paryoja.copilot-supervisor-{server,runner}.log`
- auto-pull: user LaunchAgent `com.paryoja.copilot-autopull`, `StartInterval 3600`, `scripts/auto-pull.sh` (install.sh가 자동 배선). 로그 `~/.local/state/copilot/auto-pull.log`. clean+behind+ahead=0 인 repo만 ff-merge
- status report: **미셋업**. `setup-status-report.md` 참고해서 `scripts/system-health-macos.py` + LaunchAgent 23:00 으로 붙이면 됨 (minione 구성이 레퍼런스)
- homelab-node-agent: user LaunchAgent `com.paryoja.homelab-node-agent` (gui domain, sudo 불필요), config `~/homelab-node-agent/node-agent.json`, interval 300s, Memo `/nodes` heartbeat. 로그 `~/Library/Logs/homelab-node-agent.{log,err}`
  - **실행 방식: `--once` + `StartInterval 300` (주기 실행)**. launchd가 5분마다 fresh 프로세스 spawn → 코드/config 변경 자동 반영, 재시작 불필요. (구: `--loop`+`KeepAlive` 장기 프로세스였는데 코드 바뀔 때마다 수동 재시작 필요해서 전환)
  - plist `EnvironmentVariables.PATH`에 `/Applications/Tailscale.app/Contents/MacOS`(tailscale CLI=GUI앱 바이너리) 등 포함해야 tailscale_name FQDN 수집됨. docker는 미설치.
  - plist 수정 후엔 `kickstart -k`가 아니라 `launchctl bootout gui/$(id -u)/com.paryoja.homelab-node-agent && launchctl bootstrap gui/$(id -u) <plist>`로 재로드해야 반영됨 (kickstart는 캐시된 정의 사용).
  - git 리포트: config `git_repos_scan: ["~/Workspace"]`(하위 자동스캔) + `git_repos: ["~/homelab-node-agent"]`(스캔 밖이라 명시). install stamp(`.git/installed-commit`)로 install_pending 판정.
  - service_checks는 비움(bookone은 memo-service 비호스팅). tailscale_name=bookone.tail591527.ts.net
