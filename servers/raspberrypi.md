# Raspberry Pi — Gallery & AI

## 스펙
- **모델**: Raspberry Pi 5 Model B Rev 1.0
- **CPU**: ARM Cortex-A76, 4코어, aarch64
- **메모리**: 8GB
- **디스크**: 117GB (mmcblk0p2)
- **OS**: Debian bookworm (Linux 6.12, aarch64)
- **Tailscale**: `raspberrypi.tail591527.ts.net` (100.79.4.18)
- **LAN IP**: 192.168.50.192

## 런타임
- **Python**: 3.11.2 (시스템)
- **Node**: v22.x
- **Docker**: 미설치 (서비스는 systemd로 직접 운영)

## 서비스
| 서비스 | 포트 | 도메인 | 실행 방식 |
|--------|------|--------|-----------|
| Gallery Server (Flask) | 8000 | gallery.paryoja.com | `systemd: gallery.service` |
| Reverse Proxy | 80 | - | (nginx 추정) |

## 주요 작업
- Instagram Crawler
- 이미지 사람 감지 (현재: Groq API → YOLO 로컬 전환 예정)

## 운영 메모
- `systemctl status gallery` 로 Flask 상태 확인
- Docker 도입 시 `docker-ce` apt 설치 필요
