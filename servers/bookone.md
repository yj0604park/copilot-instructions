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
- homelab-node-agent: user LaunchAgent `com.paryoja.homelab-node-agent` (gui domain, sudo 불필요), config `~/homelab-node-agent/node-agent.json`, interval 300s, Memo `/nodes` heartbeat. 로그 `~/Library/Logs/homelab-node-agent.{log,err}`
  - plist `EnvironmentVariables.PATH`에 `/Applications/Tailscale.app/Contents/MacOS`(tailscale CLI=GUI앱 바이너리) 등 포함해야 tailscale_name FQDN 수집됨. docker는 미설치.
  - plist 수정 후엔 `kickstart -k`가 아니라 `launchctl bootout gui/$(id -u)/com.paryoja.homelab-node-agent && launchctl bootstrap gui/$(id -u) <plist>`로 재로드해야 반영됨 (kickstart는 캐시된 정의 사용).
  - service_checks는 비움(bookone은 memo-service 비호스팅). tailscale_name=bookone.tail591527.ts.net
