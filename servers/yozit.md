# Yozit NAS — 스토리지 & DNS

## 스펙
- **모델**: Synology DS220+
- **메모리**: 18GB
- **스토리지**: 10.9TB / 7.3TB HDD
- **OS**: DSM (Linux 기반)
- **Tailscale**: yozit.tail591527.ts.net

## 서비스
| 서비스 | 포트 | 도메인 |
|--------|------|--------|
| Synology DSM | 5000 | nas.paryoja.com |
| Pi-hole | 8080 (web), 53 (DNS) | pihole.paryoja.com |
| MinIO Console | 9001 | minio.paryoja.com |
| MinIO S3 API | 9000 | s3.paryoja.com |

## 참고
- Pi-hole은 `network_mode: host`로 실행 (클라이언트 IP 식별)
- Synology Drive로 Obsidian vault 동기화
