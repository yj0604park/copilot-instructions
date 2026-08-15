# Raspberry Pi — Instagram & AI

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

## 주요 작업
- Instagram Crawler
- 이미지 사람 감지 (현재: Groq API → YOLO 로컬 전환 예정)
- Copilot CLI 워크스페이스 (`~/.openclaw/workspace/`) — 에이전트 페르소나/메모리

## 프로젝트 경로
- `~/.openclaw/workspace/` — Copilot 에이전트 작업 디렉토리
- `~/.openclaw/workspace/copilot-instructions/` — dotfiles/instructions repo
- `~/.openclaw/workspace/projects/` — Instagram 등 서브 프로젝트

## GitHub 계정
- **활성: `diehardclaw99-creator`** (이 워크스페이스 repo 소유 — `clo-automations`)
- 추가 로그인: `yj0604park` (`copilot-instructions` 등 소유, Active account: false)
- **`gh auth switch`는 쓰지 말 것.** 전역 활성 계정이 바뀌어 `clo-automations` 쪽
  자동화가 깨진다. repo별로 계정을 고정하는 게 맞다 (아래).
- **private repo가 `Repository not found`(404)로 막히는 함정** (2026-08-05):
  `~/.gitconfig`에 **URL별** helper가 걸려 있다 —
  `credential.https://github.com.helper = !/usr/bin/gh auth git-credential`.
  이건 항상 *활성* 계정(diehardclaw99-creator) 토큰을 돌려주므로 yj0604park 소유
  private repo는 404가 된다. URL별 설정은 일반 `credential.helper`보다 우선하니
  `git -c credential.helper=...`도 `GIT_ASKPASS`도 **전부 무시된다** (토큰 자체는
  멀쩡한데 git이 안 쓰는 것이라 원인 찾기 까다롭다).
  해법은 해당 repo의 **로컬** config에 계정을 고정하는 것. 빈 값을 먼저 넣어
  앞선 helper 체인을 리셋해야 한다:
  ```bash
  git config --local --replace-all 'credential.https://github.com.helper' ''
  git config --local --add 'credential.https://github.com.helper' \
    '!f() { echo username=x-access-token; echo "password=$(/usr/bin/gh auth token -u yj0604park)"; }; f'
  ```
  `copilot-instructions`에는 이미 적용해뒀다.

## 접속
- **SSH 사용자는 `diehard`** (`ssh diehard@raspberrypi`). `paryoja`/`yoonjaepark`는
  publickey 거부됨. 홈은 `/home/diehard`, repo는
  `/home/diehard/.openclaw/workspace/copilot-instructions`.
- **🔑 tailnet이 죽었을 때의 유일한 우회로: `ssh -J minitwo diehard@192.168.50.192`**
  (2026-08-15 실증). minitwo(`192.168.50.84`)가 rpi와 **같은 물리 LAN**에 있다.
  - **`192.168.50.0/24`가 두 곳에 중복 존재한다는 게 함정.** bookone도 `192.168.50.195`를
    받지만 그건 *다른 장소의 동일 사설대역*이라 rpi가 안 보인다. bookone에서 LAN 스캔하면
    호스트 7개만 잡히고 rpi는 없어서 "rpi 다운"으로 오진하기 딱 좋다(실제로 오진함).
    minione/yozit은 `10.0.0.x`라 중첩 NAT로 아예 격리.
  - 판별: `ssh minitwo 'ping -c2 192.168.50.192'`가 1ms로 응답하면 rpi는 살아있는 것.
- **🔴 tailscale 노드 키 만료 (2026-08-13 20:17 발생, 08-15 복구)**: 키가 만료되면
  `tailscale status`에 **`Online: True`로 보이는데** ping·SSH·DNS가 전부 timeout이다
  (`CurAddr` 빈 값, `LastHandshake` 없음 = 컨트롤 플레인만 붙어 있고 데이터플레인은 차단).
  rpi 자체는 멀쩡해서 cron·Slack 알람은 계속 돌기 때문에 **"살아있는데 안 닿는" 모순**으로 보인다.
  - 증상: `dns-sync` 알람이 15분마다 `ERROR: failed to read primary pihole.toml via
    paryoja@100.101.180.8`로 도배(24h에 95건). yozit `auth.log`에 **rpi의 SSH 세션이 아예 없다**
    (접속 실패가 아니라 시도조차 도달 못 함)는 게 결정적 단서.
  - 확인: `tailscale status --json`의 해당 피어 `KeyExpiry`. 전 노드 만료일 일괄 확인 권장.
  - 복구 ①(rpi 접근 없이): admin console → 노드 → **Disable key expiry**.
    ②(위 ProxyJump로 붙어서): `sudo tailscale up --hostname=raspberrypi` → 출력된
    `https://login.tailscale.com/a/...` URL을 브라우저에서 승인. `nohup ... &` 후
    `/tmp/ts-up.log`를 읽으면 비대화형 SSH에서도 URL을 뽑을 수 있다.
  - 복구 후 검증: `bash scripts/sync-secondary-dns.sh` → `no change`.
    bookone의 `known_hosts`에 옛 키가 남아 `Host key verification failed`가 날 수 있으니
    `ssh-keygen -R 100.79.4.18`.

## 도메인 패턴
- `*.tail591527.ts.net` — Tailscale 내부 (`raspberrypi.tail591527.ts.net`)

## 운영 메모
- Docker 도입 시 `docker-ce` apt 설치 필요
- `~/.profile` L29가 없는 `~/.atuin/bin/env`를 source해서 로그인 셸마다 에러를 뱉는다
  (`bash -lc` 쓸 때 stderr에 섞임). 동작엔 지장 없지만 출력 파싱 시 방해됨. atuin
  미설치 상태이므로 해당 줄 제거 또는 존재 확인 가드 필요.
- SSH 원격 작업 시 PATH: `/usr/local/bin:/usr/bin` (기본으로 충분)
- status report: cron `0 23`, `scripts/system-health.py` → Slack `C0AFWQ4CV08` (이미 셋업).
  **다른 머신과 달리 `~/.config/system-health/env`가 없다** — openclaw workspace의 자체 사본
  (`~/.openclaw/workspace/scripts/system-health.py`)을 쓰고 채널 기본값이 하드코딩돼 있어서,
  crontab 라인 앞에 `HEALTH_CHANNEL=...`을 붙여 덮어쓴다 (repo 파일을 고치면 그쪽 git과 드리프트).
  또 직접 post 하지 않고 `~/.openclaw/workspace/pending-alerts/`에 큐잉 → flusher가 전송한다.
  스크립트는 repo의 포터블 버전으로 통합됨 (배선 갱신: `scripts/setup-status-report.sh`)
- node heartbeat: `homelab-node-agent.service` (systemd, **User=diehard**, enabled) → Memo `/nodes` 5분 주기. repo `~/homelab-node-agent`, config `node-agent.json`. git_repos 리포트(workspace/copilot-instructions/homelab-node-agent 절대경로). root로 돌리면 `~`가 /root라 git_repos 깨짐 → 반드시 User=diehard
- cron 자동화 리포팅: node-agent `cron_jobs` 콜렉터(minione 구현)로 metadata.cron_jobs에 잡별 신선도(log mtime)+ok+last_error 표시. config에 10개 등록(flush/slack-inbox/youtube/disk-cookie/daily5/weekly). `cron_error_log`=memory/cron-errors.jsonl. ※ market 잡은 weekday+TZ 가드라 로그 MISSING 시 오탐 → 제외
- gallery: yozit media server로 기능 마이그레이션 완료 (`gallery.service`는 6/30 중지+disable, 이 머신에선 미운영)
- secondary DNS: **Pi-hole (docker)** — 인프라 SPOF 완화용 failover resolver (이전 dnsmasq에서 마이그레이션, 2026-07-04). adblock(StevenBlack gravity)까지 failover됨. compose `/opt/pihole/docker-compose.yml` (`pihole/pihole:latest`, `network_mode: host`), data `/opt/pihole/etc-pihole`. standalone upstream 1.1.1.1/1.0.0.1/8.8.8.8 (`FTLCONF_dns_upstreams`)이라 primary(yozit pihole 10.0.0.172) 다운 시에도 동작. `FTLCONF_dns_listeningMode: all`로 lo/eth0(192.168.50.192)/tailscale0(100.79.4.18) 전부 응답. web `http://<rpi>/admin/`, 비번 `/root/.pihole-web-pw` (또는 compose의 `FTLCONF_webserver_api_password`). 구 dnsmasq.service는 stop+disable, config는 `/opt/pihole/legacy-dnsmasq-backup/`로 백업 이동(`/etc/dnsmasq.d`는 정리됨). 로컬레코드 sync = `scripts/sync-secondary-dns.sh` (pihole→pihole mirror: yozit `/etc/pihole/pihole.toml`의 `dns.hosts`+`dns.cnameRecords`를 `pihole-FTL --config`로 rpi에 반영, idempotent). SSH `paryoja@100.101.180.8` (yozit docker 경로 `/usr/local/bin/docker`), cron `*/15 * * * *` (`cron-error-wrap.sh dns-sync`, 로그 `/tmp/dns-sync.log`). gravity/blocklist은 각자 유지(sync 안 함) — adblock은 이미 각 pihole이 독립적으로 함. **네트워크 주의**: rpi(192.168.50.0/24)와 yozit LAN(10.0.0.0/24)이 중첩 NAT라 10.0.0.x 클라이언트는 rpi LAN IP로 직접 도달 불가 → secondary는 tailnet(100.79.4.18) 기준 또는 라우터 포트포워드 필요
  - **dns-sync 알람 트리아지**: `ERROR: failed to read primary pihole.toml via paryoja@...`는 대부분
    **rpi 문제가 아니라 yozit 문제**다. 먼저 아무 머신에서나 `ssh paryoja@100.101.180.8 echo ok`를 쳐 보고,
    여러 출발지에서 똑같이 배너 전에 끊기면 yozit sshd 이슈로 확정(→ `servers/yozit.md`).
    실패해도 **DNS 서비스 자체는 안 죽는다** — secondary가 마지막 성공 시점 레코드로 고정될 뿐이라 긴급도는 낮다.
    마지막 성공 시각은 `grep -n "no change\|updated" /tmp/dns-sync.log | tail -1`.
  - **tailnet DNS는 yozit 단독 SPOF였다 → 2026-08-13 다중 nameserver로 해소.**
    Tailscale의 global nameserver가 `100.101.180.8`(yozit) 하나뿐이라, secondary pihole이 멀쩡히
    떠 있어도 **아무도 그걸 안 쓰는** 구조였다. 실제로 yozit tailscale을 끄자 rpi 자신도
    `Temporary failure in name resolution`으로 cron이 줄줄이 죽었다(`/etc/resolv.conf`가
    `100.100.100.100` MagicDNS → yozit). 현재는 admin console에 `100.101.180.8` → `100.79.4.18`
    → `8.8.8.8` → `8.8.4.4` 순으로 등록돼 failover가 실제로 동작한다.
    - 확인: `tailscale dns status`의 `Resolvers (in preference order)`
    - nameserver는 **한 번에 하나씩** 추가하는 UI라 하나만 되는 것처럼 보이지만 여러 개 등록된다.
    - 긴급 우회(노드 단위): `sudo tailscale set --accept-dns=false` 후 `/etc/resolv.conf`에
      `nameserver 127.0.0.1`(자기 pihole). 복구되면 `--accept-dns=true`로 원복할 것.
- btc-carry (페이퍼 트레이딩): `~/btc-carry-poc`, systemd 2개 (**User=diehard**, enabled)
  - `btc-carry-paper.service` — OKX public 시세로 델타뉴트럴 캐리 **가상매매**. 60초 폴링, SQLite `data/paper.db`
  - `btc-carry-web.service` — 읽기전용 대시보드 **https://btc-carry.paryoja.com** (minitwo traefik → raspberrypi:8787). 직접 접근은 `http://raspberrypi.tail591527.ts.net:8787` (0.0.0.0 바인딩, 인증 없음, 민감정보 없음)
    - traefik 라우팅은 minitwo `~/homelab/services.yaml` 에 정의하고 `ruby scripts/render-services.rb`. `*.paryoja.com` 와일드카드 인증서라 새 서브도메인도 바로 뜬다
  - **API key 없음 / public 엔드포인트만 사용 → 실주문 경로 자체가 없음.** 의존성 0 (stdlib)
  - 리소스 약 49MB / CPU 1% 미만. 검증: `python3 tests/stress.py` (네트워크 불필요)
  - 로그 `journalctl -u btc-carry-paper -f`. 상태 `PYTHONPATH=src python3 -m btc_carry.cli paper-status`
