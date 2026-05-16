# Copilot Instructions

개인 Copilot CLI 설정 및 hook, dotfiles 관리용 repo.

## 구조

```
├── instructions.md    # Copilot CLI 커스텀 지시사항
├── hooks/             # Copilot CLI hooks
│   └── post-task.sh   # 작업 완료 시 iTerm2 알림 전송
└── tmux.conf          # tmux 설정
```

## 설치

```bash
# tmux 설정 심볼릭 링크
ln -sf $(pwd)/tmux.conf ~/.tmux.conf

# Copilot hooks 심볼릭 링크
ln -sf $(pwd)/hooks ~/.copilot/hooks
```
