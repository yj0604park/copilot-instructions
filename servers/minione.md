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
| my-dashboard | 3010 | news.paryoja.com |
| Focalboard | 8000 | focalboard.paryoja.com |
| Gitea | 3000 (+2222 ssh) | gitea.paryoja.com |
| Drone CI | — | — |
| pgAdmin4 | — | — |
| PostgreSQL (공용) | 5432 | — |

## 프로젝트 경로
- `~/homelab/` — 인프라 monorepo
- `~/projects/apps/finance-main/` — Finance (submodules: backend, frontend-v2)
- `~/projects/apps/my-dashboard/` — 개인 뉴스/메일 대시보드
- `~/projects/repos/` — bare git repo 호스팅 (GitHub 원격 없는 로컬 프로젝트 push 용)

## GitHub 계정
- `yj0604park` (finance-main, infra)
- repo 접근 불가 시 `gh auth switch` 시도

## 운영 메모
- status report: LaunchAgent `~/Library/LaunchAgents/com.paryoja.system-health.plist`, 매일 23:00, `scripts/system-health-macos.py` → Slack DM `C0AFD7AQ4QK`
  - `system-health-macos.py`는 이제 포터블 `scripts/system-health.py`로 넘기는 shim. 재배선하려면 `scripts/setup-status-report.sh`
  - 토큰: `~/.config/system-health/env` (chmod 600)
  - 로그: `/tmp/system-health.log`
  - 수동 테스트: `python3 scripts/system-health-macos.py --dry-run`
  - macOS는 cron에 Full Disk Access 권한 이슈가 있어 launchd 사용
- homelab-node-agent: user LaunchAgent `~/Library/LaunchAgents/com.paryoja.homelab-node-agent.plist`, 5분 loop → memo-service `/nodes` heartbeat
  - checkout: `~/projects/apps/homelab-node-agent`, config: `node-agent.json` (gitignore)
  - repo 기본 `install-launchd.sh`는 sudo LaunchDaemon이지만 minione은 user LaunchAgent로 설치(관례)
  - 로그: `/tmp/homelab-node-agent.err`
- my-dashboard (개인 뉴스 다이제스트): user LaunchAgent `~/Library/LaunchAgents/com.paryoja.my-dashboard.plist`, `npm run start` (PORT=3010, HOSTNAME=0.0.0.0)
  - 접근: `https://news.paryoja.com` (minitwo traefik → minione:3010). `*.paryoja.com` DNS는 minitwo의 tailscale IP를 가리켜서 tailnet 안에서만 열린다
  - traefik 라우팅은 `~/homelab/services.yaml`에 정의하고 `ruby scripts/render-services.rb` (minitwo)
  - 코드 전달: bookone에서 `git push minione master:main` → bare repo `~/projects/repos/my-dashboard.git`
  - 업데이트: `cd ~/projects/apps/my-dashboard && git pull && npm ci && npm run build && launchctl kickstart -k gui/$(id -u)/com.paryoja.my-dashboard`
  - DB는 `data/` (gitignore, 서버 로컬), 설정은 `config/config.json` (앱이 직접 수정하므로 pull 시 충돌 주의)
  - 로그: `/tmp/my-dashboard.log`, `/tmp/my-dashboard.err`
