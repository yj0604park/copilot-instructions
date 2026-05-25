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
| File Organizer Frontend | 58101 | files.paryoja.com |
| File Organizer Backend | 58100 | files-api.paryoja.com |
| Focalboard | 8000 | focalboard.paryoja.com |
| Gitea | 3000 | gitea.paryoja.com |
| PostgreSQL (공용) | 5432 | — |

## 프로젝트 경로
- `~/homelab/` — 인프라 monorepo
- `~/projects/apps/finance-main/` — Finance (submodules: backend, frontend-v2)
- `~/projects/apps/file-organizer/` — File Organizer

## GitHub 계정
- `yj0604park` (finance-main, infra)
- `paryojavive` (file-organizer — private repo)
- repo 접근 불가 시 `gh auth switch` 시도
