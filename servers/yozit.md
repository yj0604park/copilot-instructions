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
- **자동 스케줄은 systemd 타이머로 등록한다 (2026-08-15)**: `scripts/setup-status-report.sh`는 Synology에서
  GUI 안내 후 exit 1이라 못 쓴다. DSM 작업 스케줄러(`esynoscheduler.db`) 대신 systemd 유닛을 직접 깔았다.
  - `copilot-autopull.timer` (매시) → `scripts/auto-pull.sh`
  - `copilot-health.timer` (매일 23:00) → `scripts/system-health.py`
  - 두 서비스 모두 `User=paryoja` / `Group=users` / `Environment=HOME=/var/services/homes/paryoja`.
    HOME을 안 주면 `~/.config/system-health/env`(Slack 토큰)를 못 찾는다. python은 `/usr/bin/python3` (3.8.15).
  - 설치는 `yozit-tun.service`와 동일하게 `/tmp`에 쓴 뒤 docker chroot로 복사+enable.
    **DSM systemd는 구버전이라 `systemctl enable --now`가 없다** — `enable`과 `start`를 따로 호출할 것.
  - 확인: `systemctl list-timers | grep copilot`
- **2026-08-12 sshd 장애 = PID 고갈이었다 (원인 규명 완료, 08-13)**: 08-12 17:00경부터 **모든 출발지**
  (bookone/minione/raspberrypi, LAN·tailnet 무관)에서 TCP accept 직후 배너 전에 연결이 끊겼다
  (`kex_exchange_identification: Connection reset`). 전 출발지가 동일했으니 DSM 자동차단(IP별)이 아니다.
  디스크·메모리는 정상이라 당시엔 "원인 미상"으로 남겼는데, **커널 로그에 답이 있었다**:
  `run out of pids, pid_max = 32768`이 **08-12 14:57부터 08-13 17:49까지 110,319줄**.
  sshd는 접속마다 자식을 fork하므로 PID가 없으면 accept 직후 죽는다 = 위 증상 그대로.
  DSM 웹/DNS가 살아 보였던 건 이미 떠 있던 프로세스라 fork가 필요 없었기 때문.
  범인은 homelab-node-agent의 좀비 누적(아래 `init: true` 항목). 08-13 17:49 전원 하드 리셋으로 복구.
  - **교훈: "특정 서비스만 이상"할 때 `dmesg | grep -i "run out of pids"`와 `ps -eo stat | grep -c ^Z`를
    먼저 볼 것.** fork가 필요한 것(sshd·cron·docker exec)만 죽고 상주 데몬은 멀쩡해서
    개별 서비스 장애로 오진하기 쉽다.
  - 같은 증상 재발 시 SSH가 막혀 원격 복구가 불가하므로 DSM 웹으로 직접 붙을 것
    (`http://100.101.180.8:5000`. `nas.paryoja.com`은 minitwo traefik 경유라 minitwo가 죽으면 같이 죽는다).
- **⚠️ tailnet에서 caddy vhost를 확인할 땐 `:8443` + 정확한 SNI**: 표의 "8443→443"은 공유기 포워딩 기준이라
  tailnet에서 `https://media.paryoja.com`(=:443)로 찌르면 아무것도 안 뜬다. `-H Host:`로 IP에 붙어도
  caddy에 IP용 인증서가 없어 `tlsv1 alert internal error`가 난다. 이 둘을 **caddy 다운으로 오진하기 쉽다**
  (2026-08-13 실제로 오진). 올바른 확인:
  `curl --resolve media.paryoja.com:8443:100.101.180.8 https://media.paryoja.com:8443/`
- **memo 주소 `10.0.0.144`는 죽었다 → 2026-08-13 `http://100.108.193.108:8100`(minione tailnet)으로 수정 완료.**
  minione의 현재 주소는 LAN `192.168.50.160` / tailnet `100.108.193.108`이고, 10.0.0.144는
  `No route to host`가 난다. **주소만 고쳐선 안 낫는다** — 아래 tun 항목이 깨져 있으면 tailnet outbound
  자체가 막혀 어떤 주소를 넣어도 실패한다. 순서는 tun 복구 → 주소 수정 → `docker restart homelab-node-agent`.
  (백업 `~/homelab-node-agent/node-agent.json.bak-20260813`)
  - `~/.copilot/mcp-config.json`은 현재 **`{"mcpServers": {}}` 빈 상태** — 아래 memo-mcp 항목의 등록이
    실제로는 남아 있지 않다. 필요하면 재등록할 것.
- **🔴 재부팅 후 tun 모드 복구를 반드시 확인할 것** (2026-08-13 재부팅에서 실패 확인):
  부팅 트리거 태스크가 안 돌아 `/dev/net/tun` 없음 / `tun.ko` 미로드 / `tailscale0` 없음 상태였다.
  이때 tailscaled는 userspace-networking으로 뜨는데, **inbound(SSH·DNS·caddy)는 멀쩡하고
  outbound tailnet TCP만 전부 막히는** 헷갈리는 증상이 된다 (yozit → minione:8100/:22, memo.paryoja.com
  모두 실패). 그 결과 `/nodes` heartbeat가 조용히 끊긴다(08-05~08-13 offline이었다).
  - 점검: `ls -l /dev/net/tun; lsmod | grep -w tun; ifconfig tailscale0`
  - **✅ 영속화 완료 (2026-08-13): `yozit-tun.service`** — DSM 작업 스케줄러(GUI) 대신 systemd로 해결했다.
    DSM7엔 `/etc/rc.local`이 없고 `/usr/local/etc/rc.d`도 systemd에서 참조되지 않아 둘 다 안 먹는다.
    유닛 원본은 이 repo의 `servers/yozit-tun.service`. `Before=pkgctl-Tailscale.service`라서
    패키지가 뜨기 전에 `/dev/net/tun`이 만들어지고, 그래서 **`synopkg restart`가 필요 없다**
    (start-stop-status가 처음부터 `--tun=userspace-networking`을 생략).
    설치는 SSH에서 sudo 없이 docker로 root를 얻어서 한다(유닛을 `/tmp`에 쓴 뒤):
    ```
    docker run --rm --privileged --pid=host -v /:/host alpine sh -c \
      "cp /host/tmp/yozit-tun.service /host/etc/systemd/system/ && chmod 644 /host/etc/systemd/system/yozit-tun.service \
       && chroot /host systemctl daemon-reload && chroot /host systemctl enable yozit-tun.service"
    ```
    검증(디바이스를 지웠다 재생성 확인. tailscaled는 이미 연 fd를 쓰므로 영향 없음):
    `rm -f /dev/net/tun && systemctl restart yozit-tun.service && ls -l /dev/net/tun`
    - **DSM 업데이트로 시스템 파티션이 덮이면 유닛이 사라질 수 있다.** 업데이트 후엔
      `systemctl is-enabled yozit-tun.service`를 확인하고 없으면 위 명령으로 재설치.
  - 수동 복구(유닛이 없거나 이미 부팅이 끝난 상태에서):
    `insmod /lib/modules/tun.ko && mkdir -p /dev/net && mknod /dev/net/tun c 10 200 && chmod 0666 /dev/net/tun && synopkg restart Tailscale`
  - **`chmod 0666`이 핵심**이다. mknod만 하면 `crw-------`(root 전용)라 non-root로 도는 tailscaled가
    tun을 못 잡고 계속 userspace로 뜬다. 재부팅 시 `/dev/net/tun`이 이미 있으면 `mknod`는
    `File exists`로 실패하는데, 이때 chmod를 건너뛰기 쉬우니 주의.
  - **SSH에서 즉시 root가 필요할 땐 docker로 우회**(paryoja가 docker 그룹이라 가능). 2026-08-13 검증:
    `docker run --rm --privileged --pid=host --network=host -v /:/host alpine chroot /host /usr/syno/bin/synopkg start Tailscale`
    (non-root로 `synopkg start`하면 `failed to lock packages` code 275). 읽기 전용 조회에도 유용:
    `docker run --rm -v /var/log:/hl:ro alpine tail -c 8000 /hl/kern.log.1`
  - **userspace로 떨어졌는지 판별**: `grep -c netstack /var/packages/Tailscale/var/tailscaled.stdout.log`.
    userspace 모드에선 tailnet 클라의 :53 질의가 `netstack: UDP session between 127.0.0.1:x and
    127.0.0.1:53 timed out`으로 죽는다 = **tailnet DNS 전멸**. tun 모드면 netstack 로그가 아예 없다.
  - 실제로 `esynoscheduler.db`에 태스크가 **0개**라 부팅 트리거는 여태 미등록이었다(2026-08-13 확인).
    확인법: `docker run --rm -v /usr/syno/etc/esynoscheduler:/e:ro alpine strings /e/esynoscheduler.db`
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
  `auto-pull.sh`와 `sync-instructions.sh`는 이 경로를 자체 탐색하므로 그냥 실행하면 된다.
- **Copilot CLI 장시간 세션 금지**: yozit에서 tmux로 Copilot 세션을 계속 띄워두지 말 것.
  필요할 때 다른 머신에서 SSH로 붙는다. 근거: 2026-08-01에 먹통 세션 하나(`R` 상태 busy loop)가
  36시간 동안 CPU time 17시간을 태우며 2코어 중 절반을 상시 점유, `which <defunct>` 좀비도 누적.
  죽인 뒤 user CPU 30% → 4.4%. J4025 2코어라 프로세스 하나 꼬이면 머신 전체가 느려진다.
- **Copilot CLI 비활성화 (2026-09-02 수행 완료)**: yozit에서는 이제 Copilot CLI를 쓰지 않는다.
  DS220+는 2코어라 여유가 없고(위 "장시간 세션 금지" 항목), 실제로도 마지막 세션이 2026-08-01로
  한 달 넘게 미사용이었다. 비용만 내고 효용이 없었다.
  - 조치: `~/.local/bin/copilot`(176MB)과 `~/.copilot/hooks`를 `~/.copilot-disabled-20260902/`로 **이동**.
    `~/.local/state/copilot/memo-agent-not-a-tty-*.env` 유령 에이전트 잔해 삭제.
    삭제가 아니라 이동이므로 되돌릴 수 있다.
  - **복구**: `mv ~/.copilot-disabled-20260902/copilot ~/.local/bin/ && mv ~/.copilot-disabled-20260902/hooks ~/.copilot/`
  - **유지한 것**: `copilot-autopull.timer`(매시)와 `copilot-health.timer`(매일 23:00).
    이름에만 copilot이 들어갈 뿐 실제로는 bash/python 스크립트라 CLI와 무관하다. autopull은
    `servers/*.md`와 `scripts/system-health.py`를 최신으로 유지하는 데 여전히 필요하다.
    비활성화 후 `auto-pull.sh` 정상 동작 확인함.
  - **함정**: `scripts/sync-instructions.sh`는 yozit에서 원래부터 조용히 실패하고 있었다
    (git이 기본 PATH 밖 — 아래 항목). 이제 CLI를 안 쓰므로 실질 영향은 없고,
    repo 최신화는 autopull이 담당한다.
- **homelab-node-agent**: Docker `~/docker/homelab-node-agent`(python:3.12-slim, `network_mode: host`,
  `/volume1` ro 마운트), `--loop` 5분 heartbeat. 체크아웃 `~/homelab-node-agent`, config `node-agent.json`
  (`memo_service_url=http://10.0.0.144:8100` LAN 직접 — **이 주소는 죽었다**, 아래 참조). 로그 `docker logs homelab-node-agent`.
  git_repos fetch(cf4e008+): compose에 `gh`+`~/.config/gh` 마운트 & 각 repo `.git` rw 마운트.
  코드 갱신 `git pull` 후 **`docker restart homelab-node-agent`**(--loop이라 필수).
  - **`init: true` 필수** (2026-08-13 PID 고갈로 NAS 전체 먹통 → 하드 리셋 사고).
    git_repos fetch가 부르는 `git`이 손자 프로세스를 남기는데, 컨테이너 PID1이 python이라
    reap을 안 해 좀비가 영구 누적된다(15분에 30개). 좀비도 PID를 점유 →
    `run out of pids, pid_max = 32768` (커널 로그 110,319줄, 8/12 14:57 ~ 8/13 17:49) →
    fork 불가로 DSM/SSH/**Pi-hole까지 정지 → tailnet DNS(100.101.180.8) 전멸 = "인터넷이 끊긴" 증상**.
    복구는 전원 하드 리셋뿐이었고 btrfs `start tree-log replay`로 비정상 종료가 확인된다.
    compose에 `init: true` → `/sbin/docker-init`(tini)가 PID1이 되어 reap. 검증: `ps -eo stat | grep -c ^Z`.
  - **비정상 종료 판별법**: `dmesg | grep "tree-log replay"`,
    `syno-check-normal-shutdown.service` 소요시간(정상 ~95ms / 비정상 4s+),
    `/var/log/synopoweroff.log` mtime이 이번 부팅 전이면 graceful shutdown 아님.
    **크래시 직전 커널 로그는 `/var/log/kern.log.1`** (부팅 시 rotate). paryoja는 log 그룹이 아니라
    권한이 없으니 docker로 우회: `docker run --rm -v /var/log:/hl:ro alpine tail -c 8000 /hl/kern.log.1`.
    크래시 시각은 `docker exec pihole grep -n "started, version" /var/log/pihole/pihole.log`의
    앞줄(마지막 DNS 쿼리)로 초 단위 특정 가능.
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
