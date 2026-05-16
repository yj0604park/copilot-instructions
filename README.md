# Dotfiles & Copilot Instructions

개인 Copilot CLI 설정, hooks, dotfiles 관리용 repo.

## 구조

```
├── README.md
├── instructions.md            # Copilot CLI 커스텀 지시사항
├── hooks/
│   ├── notification.json      # agentStop hook 설정
│   └── scripts/
│       └── notify.sh          # 알림 스크립트 (마지막 응답 내용 표시)
├── tmux.conf                  # tmux 설정
└── vimrc                      # vim 설정
```

## 설치 (새 환경 셋업)

```bash
# 1. repo 클론
git clone https://github.com/yj0604park/copilot-instructions.git
cd copilot-instructions

# 2. tmux 설정
ln -sf $(pwd)/tmux.conf ~/.tmux.conf

# 3. vim 설정
ln -sf $(pwd)/vimrc ~/.vimrc

# 4. Copilot CLI instructions
mkdir -p ~/.copilot
ln -sf $(pwd)/instructions.md ~/.copilot/copilot-instructions.md

# 5. Copilot CLI hooks
mkdir -p ~/.copilot/hooks/scripts
ln -sf $(pwd)/hooks/notification.json ~/.copilot/hooks/notification.json
ln -sf $(pwd)/hooks/scripts/notify.sh ~/.copilot/hooks/scripts/notify.sh
```

## 설치 확인

```bash
# symlink 확인
ls -la ~/.tmux.conf \
       ~/.vimrc \
       ~/.copilot/copilot-instructions.md \
       ~/.copilot/hooks/notification.json \
       ~/.copilot/hooks/scripts/notify.sh
```

## Hook 동작 방식

`agentStop` hook이 Copilot CLI 응답이 끝날 때마다 실행:

1. `sessionId`로 `~/.copilot/session-state/{id}/events.jsonl`을 찾음
2. 마지막 assistant 메시지를 파싱 (최대 80자)
3. tmux passthrough로 iTerm2 알림 전송

**요구사항:** `jq`, `tmux`, tmux `allow-passthrough` 설정 (tmux.conf에 포함됨)

## 참고

- tmux 설정 적용: `tmux source ~/.tmux.conf` 또는 새 세션 시작
- Copilot hooks 적용: CLI 재시작 필요
- SSH + tmux 환경에서 iTerm2 알림을 받으려면 tmux `allow-passthrough` 설정 필요 (tmux.conf에 포함됨)
