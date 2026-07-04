# Yozit NAS — 스토리지 & DNS

## 스펙
- **모델**: Synology DS220+
- **메모리**: 18GB
- **스토리지**: 10.9TB / 7.3TB HDD
- **OS**: DSM (Linux 기반)
- **Tailscale**: yozit.tail591527.ts.net

- **LAN IP**: 10.0.0.172

## 서비스
| 서비스 | 포트 | 도메인 |
|--------|------|--------|
| Synology DSM | 5000 | nas.paryoja.com |
| Pi-hole | 8080 (web), 53 (DNS) | pihole.paryoja.com |
| Caddy (리버스프록시) | 8443→443 | media/browser/docs/files-s3.paryoja.com |
| media-platform (api/frontend) | 8000 / 8082 | media.paryoja.com |
| media-browser | 8083 | browser.paryoja.com |
| docs-core (api/frontend) | 8020 / 8084 | docs.paryoja.com |

- 대부분 Docker(`~/docker/*`, `restart: unless-stopped`)로 운영 → 재부팅 자동 복구
- MEDIA_ROOT=`/volume1/sorted/library`, docs Backup=`/volume1/homes/paryoja/Backup`

## 참고
- Pi-hole은 `network_mode: host`로 실행 (클라이언트 IP 식별)
- Synology Drive로 Obsidian vault 동기화
- **tailscale userspace 모드** (`/dev/net/tun` 없음): 호스트발 tailnet TCP 불가
  (`tailscale ping`은 되지만 curl 등 TCP는 timeout). tailnet 서비스는 **LAN IP로 직접** 접근.
  예: memo-service는 `memo.paryoja.com`(minitwo 프록시) 대신 `http://10.0.0.144:8100`(minione LAN).
- 패키지매니저 없음(DSM 7.2, x86_64). CLI 도구는 static 바이너리로 설치.
- 유저 `crontab` 없음, sudo는 비번 필요 → 스케줄 작업은 Docker(restart 정책)로.

## 운영 메모
- **homelab-node-agent**: Docker `~/docker/homelab-node-agent`(python:3.12-slim, `network_mode: host`,
  `/volume1` ro 마운트), `--loop` 5분 heartbeat. 체크아웃 `~/homelab-node-agent`, config `node-agent.json`
  (`memo_service_url=http://10.0.0.144:8100` LAN 직접). 로그 `docker logs homelab-node-agent`.
- **tmux**: static 바이너리 `~/bin/tmux`(3.6b), PATH는 `~/.profile`에 추가.
- **docs-core**: repo `paryojavive/docs-core`, deploy key `~/.ssh/dc_deploy`(alias `github-dc`),
  갱신 `~/docker/docs-core/scripts/dc-update.sh`.
