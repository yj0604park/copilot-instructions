# Minione — Mac mini Intel (앱 전담)

## 스펙
- **모델**: Mac mini (Macmini8,1)
- **CPU**: Intel 6코어
- **메모리**: 32GB
- **OS**: macOS 15.7.7 (Sequoia)
- **Tailscale**: minione.tail591527.ts.net

## Docker
- **런타임**: Docker Desktop. 아래 표의 서비스는 **전부 `desktop-linux` 컨텍스트**에 있다.
- **⚠️ 도커 런타임이 두 개 깔려 있다 (OrbStack + Docker Desktop)** — 2026-08-13 오진의 원인.
  `docker context ls`의 기본값이 **`orbstack`**이라 그냥 `docker ps` 하면 **실서비스가 하나도 안 보이고**
  "컨테이너·볼륨·DB가 통째로 사라진" 것처럼 보인다. 실제로 memo-service를 "데이터 유실"로 오판했다가
  `docker --context desktop-linux ps`에서 멀쩡히 발견. **minione에서 컨테이너를 찾을 땐 반드시
  `--context desktop-linux`를 붙이거나 `docker context use desktop-linux` 먼저 할 것.**
  - 판별 팁: `docker volume ls`에 `database_pg_data`·`monitoring_*`만 보이고 `memo-service_*`가 없으면
    OrbStack 쪽을 보고 있는 것이다.
  - OrbStack 쪽은 minitwo 이전(2026-05) 전의 **잔재**다. 마지막 실행 5/24(`~/.orbstack/log/vmgr.1.log`),
    compose 원본 `~/projects/infra/*`는 이미 비어 있고, monitoring/uptime-kuma/service-portal/traefik은
    minitwo로 이관됨. gitea/drone/postgres-db/focalboard는 Docker Desktop과 **이름·포트가 겹치는 구버전**이라
    OrbStack을 켜면 중복 기동으로 포트를 뺏는다. → **OrbStack 삭제 예정**(정리되면 이 항목도 지울 것).
- **VM이 멈추면 전 서비스가 조용히 죽는다**: 2026-08-11 23:13 Docker Desktop VM 정지 → memo-service 포함
  전부 다운, 8/13까지 아무도 몰랐다. 증상은 memo.paryoja.com **502**(traefik은 정상, 백엔드 부재).
  복구는 `ssh minione 'open -a Docker'` 후 1분 대기. 정지 원인은 미상.

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
| 마주침 (Encounters) | 3002 | encounters.paryoja.com |
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
- **의도적으로 꺼둔 컨테이너** (헬스 리포트에 "Exited"로 뜨지만 정상): `file-organizer-*`는 프로젝트 종료로
  영구 중단. `people-*`(`~/projects/apps/people`)는 필요할 때만 켜는 온디맨드 — restart policy를 일부러
  안 넣어서 재부팅하면 꺼진 채로 남는다. 켤 땐 `cd ~/projects/apps/people && docker compose up -d`
  (app은 :3001).
- 마주침: `~/projects/apps/encounters`, LaunchAgent `com.paryoja.encounters`가 `0.0.0.0:3002`에서 실행.
  minitwo Traefik이 `http://minione.tail591527.ts.net:3002`로 연결하고
  `https://encounters.paryoja.com`으로 제공한다.
  - **배포는 수동**이다 (CI/자동 pull 없음). main 머지 후:
    ```bash
    ssh minione 'export PATH=/usr/local/bin:$PATH; cd ~/projects/apps/encounters \
      && git pull --ff-only origin main && npm ci && npm run build'
    ssh minione 'launchctl kickstart -k "gui/$(id -u)/com.paryoja.encounters"'
    ```
  - **`export PATH=/usr/local/bin:$PATH`를 빼면 `npm: command not found`가 난다.** ssh 비로그인 zsh가
    PATH를 좁게 잡는다. plist는 EnvironmentVariables에 PATH를 박아둬서 서비스 자체는 멀쩡한데
    ssh로 수동 빌드할 때만 걸린다. 오진하기 쉬우니 주의.
  - 빌드 산출물(`.next/`)이 워킹트리에 있으므로 `git pull` 전 `git status`로 로컬 변경이 없는지 볼 것.
  - 확인: `curl -s -o /dev/null -w '%{http_code}' https://encounters.paryoja.com/`
- status report: LaunchAgent `~/Library/LaunchAgents/com.paryoja.system-health.plist`, 매일 23:00, `scripts/system-health-macos.py` → Slack DM `C0AFWQ4CV08`
  - `system-health-macos.py`는 이제 포터블 `scripts/system-health.py`로 넘기는 shim. 재배선하려면 `scripts/setup-status-report.sh`
  - 토큰: `~/.config/system-health/env` (chmod 600)
  - 로그: `/tmp/system-health.log`
  - 수동 테스트: `python3 scripts/system-health-macos.py --dry-run`
  - macOS는 cron에 Full Disk Access 권한 이슈가 있어 launchd 사용
- **postgres 백업은 배선돼 있지 않다**: `~/homelab/minione/database/`에 `backup.sh`(pg_dumpall)/`run-backup.sh`/
  `sync-backup.sh`가 있지만 `pg-backup`은 compose profile로만 걸려 있어 스케줄이 없고, `backups/` 디렉터리는
  비어 있으며 `sync-backup.sh`도 `SYNC_METHOD=none`이다. 공용 postgres에 memo/gitea/drone/focalboard가
  전부 얹혀 있으므로 **실질 무백업 상태**. (2026-08-13 확인)
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
