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
- 상시 running 컨테이너 8개 = 위 표의 3개 앱 × (api+frontend) + postgres + caddy + pihole.
  합쳐서 CPU 0.7% 수준이라 체감 성능과는 무관 (2026-08-01 측정).
  - **`docker stats` MemUsage는 page cache를 포함하니 그대로 믿지 말 것.** media-platform-api가
    5.5GB로 보였지만 cgroup `memory.stat` 확인 결과 `rss=184MB`, `cache=11.4GB`였다
    (미디어 파일 읽기로 쌓인 reclaimable page cache). 누수 아님. 판별:
    `docker inspect -f '{{.Id}}'` → `/sys/fs/cgroup/memory/docker/<id>/memory.stat` 의 rss vs cache
  - **`caddy-files-s3` 컨테이너는 이름만 files-s3**이고 실제로는 media/browser/docs/files-s3
    4개 vhost를 전부 처리한다 (`~/docker/caddy/Caddyfile`). 지우면 안 됨.
    단 `files-s3` vhost만 `10.0.0.172:9000`(minio)을 보는데 minio가 4주째 정지 → 그 호스트만 죽은 프록시
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
- **2026-08-12 sshd 장애 (재부팅으로 해소)**: 08-12 17:00경부터 **모든 출발지**(bookone/minione/raspberrypi,
  LAN·tailnet 무관)에서 TCP accept 직후 배너 전에 연결이 끊겼다
  (`kex_exchange_identification: Connection reset`). 전 출발지가 동일했으니 **DSM 자동차단(IP별)이 아니다.**
  DSM 웹(:5000/:5001)·pihole DNS(:53)는 멀쩡해서 **이름 해석엔 영향이 없었고**, raspberrypi의
  `sync-secondary-dns.sh` cron(*/15)만 100회 연속 실패했다. 08-13 18:00 **재부팅으로 복구**.
  재부팅 후 `/` 67%, `/volume1` 40%, mem 13GB free로 **디스크·메모리 여유는 정상** — 근본 원인은 미상.
  같은 증상 재발 시 SSH가 막혀 원격 복구가 불가하므로 DSM 웹으로 직접 붙을 것
  (`http://100.101.180.8:5000`. `nas.paryoja.com`은 minitwo traefik 경유라 minitwo가 죽으면 같이 죽는다).
- **⚠️ tailnet에서 caddy vhost를 확인할 땐 `:8443` + 정확한 SNI**: 표의 "8443→443"은 공유기 포워딩 기준이라
  tailnet에서 `https://media.paryoja.com`(=:443)로 찌르면 아무것도 안 뜬다. `-H Host:`로 IP에 붙어도
  caddy에 IP용 인증서가 없어 `tlsv1 alert internal error`가 난다. 이 둘을 **caddy 다운으로 오진하기 쉽다**
  (2026-08-13 실제로 오진). 올바른 확인:
  `curl --resolve media.paryoja.com:8443:100.101.180.8 https://media.paryoja.com:8443/`
- **memo 주소 `10.0.0.144`는 죽었다**: node-agent와 memo-mcp config가 아직 이 주소를 쓰는데
  yozit에서 `No route to host`가 난다 (minione의 현재 주소는 `192.168.50.160`,
  tailnet `100.108.193.108`). **단 주소만 고쳐선 안 낫는다** — 아래 tun 항목이 함께 깨져 있으면
  tailnet outbound 자체가 막혀서 어떤 주소를 넣어도 실패한다. 순서는 tun 복구 → 주소 수정
  (`http://100.108.193.108:8100`) → `docker restart homelab-node-agent`.
- **🔴 재부팅 후 tun 모드 복구를 반드시 확인할 것** (2026-08-13 재부팅에서 실패 확인):
  부팅 트리거 태스크가 안 돌아 `/dev/net/tun` 없음 / `tun.ko` 미로드 / `tailscale0` 없음 상태였다.
  이때 tailscaled는 userspace-networking으로 뜨는데, **inbound(SSH·DNS·caddy)는 멀쩡하고
  outbound tailnet TCP만 전부 막히는** 헷갈리는 증상이 된다 (yozit → minione:8100/:22, memo.paryoja.com
  모두 실패). 그 결과 `/nodes` heartbeat가 조용히 끊긴다.
  - 점검: `ls -l /dev/net/tun; lsmod | grep -w tun; ifconfig tailscale0`
  - 복구(root 필요, sudo가 비번을 요구하므로 DSM 작업 스케줄러에서):
    `insmod /lib/modules/tun.ko && mkdir -p /dev/net && mknod /dev/net/tun c 10 200 && chmod 0666 /dev/net/tun && synopkg restart Tailscale`
- **스케줄링은 DSM GUI에서만 가능**: DSM에는 `crontab(1)` 바이너리가 없고, `/etc/crontab`은
  root 소유 + DSM이 덮어쓰며, `sudo`는 비밀번호를 요구해서 SSH 비대화형으로는 배선할 수 없다.
  제어판 → 작업 스케줄러 → 생성 → 예약된 작업 → 사용자 정의 스크립트 (사용자 `paryoja`).
  그래서 다른 노드에는 있는 아래 둘이 yozit에만 없다 (2026-08-04 기준 **미등록, 수동 등록 필요**):
  - auto-pull (매시 정각):
    `/bin/bash /volume1/homes/paryoja/copilot-instructions/scripts/auto-pull.sh`
  - status report (매일 23:00):
    `/usr/bin/python3 /volume1/homes/paryoja/copilot-instructions/scripts/system-health.py >> /tmp/system-health.log 2>&1`
  - 둘 다 수동 실행은 검증됨(auto-pull 실제 pull 성공, health는 `--dry-run` OK).
    Slack 토큰 `~/.config/system-health/env`도 복사 완료 — **Synology ACL이 umask를 무시하므로
    복사 후 반드시 `chmod 600`** (그냥 두면 777로 생긴다).
- **git이 기본 PATH 밖**: `/usr/local/bin/git`. SSH 비대화형에서 `git`은 command not found.
  `auto-pull.sh`는 이 경로를 자체 탐색하므로 그냥 실행하면 된다.
- **Copilot CLI 장시간 세션 금지**: yozit에서 tmux로 Copilot 세션을 계속 띄워두지 말 것.
  필요할 때 다른 머신에서 SSH로 붙는다. 근거: 2026-08-01에 먹통 세션 하나(`R` 상태 busy loop)가
  36시간 동안 CPU time 17시간을 태우며 2코어 중 절반을 상시 점유, `which <defunct>` 좀비도 누적.
  죽인 뒤 user CPU 30% → 4.4%. J4025 2코어라 프로세스 하나 꼬이면 머신 전체가 느려진다.
- **homelab-node-agent**: Docker `~/docker/homelab-node-agent`(python:3.12-slim, `network_mode: host`,
  `/volume1` ro 마운트), `--loop` 5분 heartbeat. 체크아웃 `~/homelab-node-agent`, config `node-agent.json`
  (`memo_service_url=http://10.0.0.144:8100` LAN 직접 — **이 주소는 죽었다**, 아래 참조). 로그 `docker logs homelab-node-agent`.
  git_repos fetch(cf4e008+): compose에 `gh`+`~/.config/gh` 마운트 & 각 repo `.git` rw 마운트.
  코드 갱신 `git pull` 후 **`docker restart homelab-node-agent`**(--loop이라 필수).
  - **`unless-stopped`는 재부팅으로 부활하지 않는다** (2026-08-01 3주 무음 정지 원인).
    2026-07-10 재부팅 5분 전 컨테이너가 명시적으로 stop됐고(exit 137, `OOMKilled=false`,
    로그에 에러 한 줄 없음), docker는 "수동 정지"를 재부팅 후에도 존중해서 영영 안 올라왔다.
    같은 정책의 caddy/pihole은 부팅 직후 11:03에 정상 복귀 → **정책 문제가 아니라 상태 문제**.
    진단은 `docker inspect -f '{{.State.StartedAt}} {{.State.FinishedAt}}'`로 다른 컨테이너와
    비교하는 게 가장 빠르다. 부팅 시각에 안 올라온 놈만 보면 됨. 복구는 `docker start`.
- **gh CLI**: `~/bin/gh`(v2.96) device-flow 인증, 계정 `yj0604park`+`paryojavive` 둘 다 로그인.
  config `~/.config/gh`(plain text). node-agent fetch가 owner-priority로 계정 자동 선택.
- **git remotes**: media-platform/media-browser/docs-core origin은 ssh alias→**https 전환**됨
  (컨테이너에 ssh 없어 gh 토큰 fetch 위함). host/컨테이너 pull 모두 gh 크레덴셜(paryojavive) 사용.
- **memo-mcp**: host python 3.8(<3.11 요구)라 Docker 래핑. 이미지 `memo-mcp:local`
  (`~/docker/memo-mcp-runner/Dockerfile`, python:3.12-slim + httpx/dotenv/mcp, `mcp_server.py`만).
  코드 원본 `~/docker/memo-mcp`(repo yj0604park/memo-service). copilot 등록:
  `~/.copilot/mcp-config.json` 서버 "memo" = `docker run -i --rm --network host memo-mcp:local`,
  env `MEMO_SERVICE_URL=http://10.0.0.144:8100`(LAN — **죽은 주소**, 아래 참조) + `MEMO_AGENT_NAME=yozit`. mcp_server 갱신 시
  `~/docker/memo-mcp` pull → `cp mcp_server.py ~/docker/memo-mcp-runner/ && docker build -t memo-mcp:local`.
- **tmux**: static 바이너리 `~/bin/tmux`(3.6b), PATH는 `~/.profile`에 추가.
- **docs-core**: repo `paryojavive/docs-core`, origin은 https(gh 토큰 pull; 구 deploy key
  `~/.ssh/dc_deploy`/alias `github-dc`는 잔존), 갱신 `~/docker/docs-core/scripts/dc-update.sh`.
