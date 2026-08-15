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
- **traefik이 `*.paryoja.com` 전체의 SPOF**: `*.paryoja.com` DNS가 minitwo의 tailscale IP(100.110.176.76)를
  가리키므로 **minitwo가 오프라인이면 도메인 전부 죽는다** (실제 백엔드가 다른 노드에서 멀쩡히 돌아도).
  2026-08-13 minitwo가 tailnet에서 사라져 nas/memo/btc-carry 등 전부 다운. 이때 DSM 등 개별 서비스는
  **노드 IP:포트로 직접** 우회할 것 (예: `http://100.101.180.8:5000`).
  - traefik이 502를 주면 traefik은 살아있고 **백엔드가 없는 것** — 대상 노드의 컨테이너를 확인한다.
    (`ssh minitwo 'curl -sk -o /dev/null -w "%{http_code}" https://localhost/ -H "Host: <도메인>"'`으로
    프록시/백엔드 구분 가능)
- memo-service health report: cron `0 23`, `~/workspace2/memo-service/scripts/system-health.py` → Slack DM
- 2026-08-15 노드 헬스 리포트(`com.paryoja.system-health`) LaunchAgent 등록 (매일 23:00).
  `scripts/setup-status-report.sh`로 셋업. 위 memo-service 리포트와는 별개 (노드 헬스 vs 서비스 헬스).
