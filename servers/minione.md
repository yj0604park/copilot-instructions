# Minione — Mac mini Intel (앱 전담)

## 스펙
- **모델**: Mac mini (Macmini8,1)
- **CPU**: Intel 6코어
- **메모리**: 32GB
- **OS**: macOS 15.7.7 (Sequoia)
- **Tailscale**: minione.tail591527.ts.net

## Docker
- **런타임**: Docker Desktop

## 서비스 (Docker)
| 서비스 | 포트 | 도메인 |
|--------|------|--------|
| Finance Frontend (Vite) | 58080 | finance.paryoja.com |
| Finance Backend (Django) | 58000 | finance-api.paryoja.com |
| Finance Adminer | 58001 | — |
| Finance Flower | 5555 | — |
| Finance Docs | 9000 | — |
| memo-service | 8100 | memo.paryoja.com |
| People App | 3001 | — |
| Focalboard | 8000 | focalboard.paryoja.com |
| Gitea | 3000 (+2222 ssh) | gitea.paryoja.com |
| Drone CI | — | — |
| pgAdmin4 | — | — |
| PostgreSQL (공용) | 5432 | — |

## 프로젝트 경로
- `~/homelab/` — 인프라 monorepo
- `~/projects/apps/finance-main/` — Finance (submodules: backend, frontend-v2)

## GitHub 계정
- `yj0604park` (finance-main, infra)
- repo 접근 불가 시 `gh auth switch` 시도

## 운영 메모
- status report: LaunchAgent `~/Library/LaunchAgents/com.paryoja.system-health.plist`, 매일 23:00, `scripts/system-health-macos.py` → Slack DM `C0AFD7AQ4QK`
  - 토큰: `~/.config/system-health/env` (chmod 600)
  - 로그: `/tmp/system-health.log`
  - 수동 테스트: `python3 scripts/system-health-macos.py --dry-run`
  - macOS는 cron에 Full Disk Access 권한 이슈가 있어 launchd 사용
- homelab-node-agent: user LaunchAgent `~/Library/LaunchAgents/com.paryoja.homelab-node-agent.plist`, 5분 loop → memo-service `/nodes` heartbeat
  - checkout: `~/projects/apps/homelab-node-agent`, config: `node-agent.json` (gitignore)
  - repo 기본 `install-launchd.sh`는 sudo LaunchDaemon이지만 minione은 user LaunchAgent로 설치(관례)
  - 로그: `/tmp/homelab-node-agent.err`
