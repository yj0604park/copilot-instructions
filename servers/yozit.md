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
  - **`dns.listeningMode = ALL`** (기존 LOCAL). tailscale tun 모드 전환 후 tailnet 클라(100.x)가
    yozit tailnet IP:53으로 직접 질의하면 LOCAL 모드가 CGNAT 소스를 거부 → tailnet DNS 전멸.
    ALL로 풀어야 tailnet 클라가 응답받고 per-client 통계도 실제 IP로 찍힘. :53 인터넷 미노출이라 안전.
    변경: `docker exec pihole pihole-FTL --config dns.listeningMode ALL` 후 `docker restart pihole`.
- Synology Drive로 Obsidian vault 동기화
- **tailscale tun 모드** (2026-07 전환, 이전엔 userspace): DS220+에 `tun.ko` 존재 →
  `insmod /lib/modules/tun.ko` + `mknod /dev/net/tun c 10 200` + `chmod 0666` 하면
  DSM7 패키지 스크립트(`/var/packages/Tailscale/scripts/start-stop-status`)가 `/dev/net/tun` 있으면
  `--tun=userspace-networking` 플래그를 자동 생략 → 패키지 restart 시 tun 모드로 뜸(`tailscale0` iface).
  tailscaled는 CapEff에 CAP_NET_ADMIN/NET_RAW 있어 non-root(tailscale user)로도 tun 동작.
  - 효과: 호스트발 tailnet TCP 가능(전엔 timeout), subnet router/exit node 가능.
  - **영속화 필수**: 재부팅 시 tun.ko/dev node 날아가고 DSM7 스크립트는 재생성 안 함(early-return).
    DSM 작업 스케줄러 **부팅 트리거 root 태스크**로 insmod+mknod+chmod+`synopkg restart Tailscale`.
  - MagicDNS 이름(`*.ts.net`)은 시스템 resolver가 안 봄 → tailnet은 100.x IP 직접 접근이 확실.
- 패키지매니저 없음(DSM 7.2, x86_64). CLI 도구는 static 바이너리로 설치.
  - `install.sh`는 apt 없으면 `PM=none` core-only 모드(symlink+stamp만, 패키지설치 skip).
- 유저 `crontab` 없음, sudo는 비번 필요 → 스케줄 작업은 Docker(restart 정책)로.

## 운영 메모
- **homelab-node-agent**: Docker `~/docker/homelab-node-agent`(python:3.12-slim, `network_mode: host`,
  `/volume1` ro 마운트), `--loop` 5분 heartbeat. 체크아웃 `~/homelab-node-agent`, config `node-agent.json`
  (`memo_service_url=http://10.0.0.144:8100` LAN 직접). 로그 `docker logs homelab-node-agent`.
  git_repos fetch(cf4e008+): compose에 `gh`+`~/.config/gh` 마운트 & 각 repo `.git` rw 마운트.
  코드 갱신 `git pull` 후 **`docker restart homelab-node-agent`**(--loop이라 필수).
- **gh CLI**: `~/bin/gh`(v2.96) device-flow 인증, 계정 `yj0604park`+`paryojavive` 둘 다 로그인.
  config `~/.config/gh`(plain text). node-agent fetch가 owner-priority로 계정 자동 선택.
- **git remotes**: media-platform/media-browser/docs-core origin은 ssh alias→**https 전환**됨
  (컨테이너에 ssh 없어 gh 토큰 fetch 위함). host/컨테이너 pull 모두 gh 크레덴셜(paryojavive) 사용.
- **memo-mcp**: host python 3.8(<3.11 요구)라 Docker 래핑. 이미지 `memo-mcp:local`
  (`~/docker/memo-mcp-runner/Dockerfile`, python:3.12-slim + httpx/dotenv/mcp, `mcp_server.py`만).
  코드 원본 `~/docker/memo-mcp`(repo yj0604park/memo-service). copilot 등록:
  `~/.copilot/mcp-config.json` 서버 "memo" = `docker run -i --rm --network host memo-mcp:local`,
  env `MEMO_SERVICE_URL=http://10.0.0.144:8100`(LAN) + `MEMO_AGENT_NAME=yozit`. mcp_server 갱신 시
  `~/docker/memo-mcp` pull → `cp mcp_server.py ~/docker/memo-mcp-runner/ && docker build -t memo-mcp:local`.
- **tmux**: static 바이너리 `~/bin/tmux`(3.6b), PATH는 `~/.profile`에 추가.
- **docs-core**: repo `paryojavive/docs-core`, origin은 https(gh 토큰 pull; 구 deploy key
  `~/.ssh/dc_deploy`/alias `github-dc`는 잔존), 갱신 `~/docker/docs-core/scripts/dc-update.sh`.
