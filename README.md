# Dotfiles & Copilot Instructions

개인 dotfiles + Copilot CLI 커스텀 설정 / hooks 관리 repo.
**macOS / Debian (Raspberry Pi 포함)** 양쪽에서 동일하게 동작.

## 구조

```
├── install.sh                 # 새 환경 한 방 셋업 스크립트
├── Brewfile                   # macOS brew 패키지 + cask 앱 목록
├── check-symlinks.sh          # symlink 상태 점검
├── instructions.md            # Copilot CLI 커스텀 지시사항
├── hooks/
│   ├── notification.json      # agentStop hook 설정
│   └── scripts/
│       ├── notify.sh          # tmux/iTerm2 알림 스크립트
│       └── notify-event.sh
├── tmux.conf                  # tmux 설정
├── vimrc                      # vim 설정
├── zshrc                      # zsh 설정 (cross-platform fallback 포함)
└── starship.toml              # starship 프롬프트 설정
```

## 새 환경 셋업 (한 방)

```bash
git clone https://github.com/yj0604park/copilot-instructions.git ~/copilot-instructions
cd ~/copilot-instructions
./install.sh
exec zsh
```

`install.sh`가 자동으로:

1. OS 감지 (macOS=brew / Debian=apt)
2. **macOS:** `Brewfile`로 CLI 도구 + GUI 앱 + 폰트 일괄 설치
   - **Linux:** apt로 CLI 도구 설치 (GUI 앱은 수동)
3. **oh-my-zsh** 설치 + 외부 plugin clone (`zsh-autosuggestions`, `zsh-syntax-highlighting`)
   - `--unattended --keep-zshrc` 옵션으로 셸 변경/zshrc 덮어쓰기 안 함
4. 모든 dotfile symlink 생성 (기존 파일은 `.bak` 으로 백업)
5. `check-symlinks.sh`로 검증

## 셸 구성

- **Prompt:** starship (oh-my-zsh `ZSH_THEME=""`로 끄고 starship이 담당)
- **Plugins:** `git`, `zsh-autosuggestions`, `zsh-syntax-highlighting`
- **History/completion/dir 옵션:** oh-my-zsh lib 기본값 사용
- **Smart cd:** `zoxide` — `z foo`, `zi` (interactive)
- **Fuzzy finder:** `fzf` (cross-platform 로더)

## 설치 후 할 일

1. **새 zsh 세션:** `exec zsh` 또는 재로그인
2. **기본 셸을 zsh로 변경 (선택):**
   ```bash
   chsh -s $(command -v zsh)
   ```
3. **Copilot CLI 재시작** — hooks 적용
4. **터미널 폰트를 Nerd Font 로** — starship 아이콘(  ➜) 깨짐 방지
   - 추천: `MesloLGS NF`, `JetBrainsMono Nerd Font`, `FiraCode Nerd Font`
   - 다운로드: https://www.nerdfonts.com/
   - iTerm2 → Settings → Profiles → Text → Font 에서 변경

## 검증

```bash
./check-symlinks.sh
```

8개 symlink 모두 `✅` 면 정상.

## Hook 동작 방식

`agentStop` hook이 Copilot CLI 응답 끝날 때마다 실행:

1. `sessionId`로 `~/.copilot/session-state/{id}/events.jsonl` 찾음
2. 마지막 assistant 메시지 파싱 (최대 80자)
3. tmux passthrough로 iTerm2 알림 전송

**요구사항:** `jq`, `tmux`, tmux `allow-passthrough` (tmux.conf에 포함).
SSH + tmux 환경에서 iTerm2 알림 받으려면 클라이언트(mac) iTerm2 알림 권한도 필요.

## 업데이트

```bash
cd ~/copilot-instructions
git pull
# symlink는 그대로, 파일 내용만 갱신됨
# 새 hook이나 dotfile이 추가됐으면 install.sh 다시 실행
```

## 참고

- tmux 설정 즉시 적용: `tmux source ~/.tmux.conf`
- starship 설정 즉시 적용: 새 프롬프트가 표시되는 순간 자동 반영
- zsh 설정 즉시 적용: `source ~/.zshrc`
