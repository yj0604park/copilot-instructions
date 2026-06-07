# Minitwo — Mac mini M1 (인프라 전담)

## 스펙
- **모델**: Mac mini (M1)
- **CPU**: Apple M1
- **메모리**: 8GB
- **OS**: macOS
- **Tailscale**: minitwo.tail591527.ts.net

## Docker
- **런타임**: OrbStack
- **네트워크**: `traefik` (공용)
- **주의**: `host.docker.internal`로 호스트 서비스 접근 (localhost 아님)

## 서비스 (Docker)
| 서비스 | 포트 | 도메인 |
|--------|------|--------|
| Traefik | 80, 443, 8080 | traefik.paryoja.com |
| Portal | 8081 | portal.paryoja.com |
| Uptime Kuma | 3001 | uptime.paryoja.com |
| Grafana | 3000 | grafana.paryoja.com |

## 서비스 (호스트)
| 서비스 | 포트 | 도메인 |
|--------|------|--------|
| Home Dashboard Frontend | 5174 | dashboard.paryoja.com |
| Home Dashboard Backend | 8001 | — |

## 프로젝트 경로
- `~/homelab/` — 인프라 monorepo (yj0604park/infra)
- `~/workspace2/home-dashboard/` — 대시보드 서비스

## 운영 메모
- memo-service health report: cron `0 23`, `~/workspace2/memo-service/scripts/system-health.py` → Slack DM
