# GitHub 계정 / 인증

> `yj0604park` repo가 404로 안 보이거나, clone·fetch·push·세션 생성이 권한
> 문제로 실패할 때 읽는다.

GitHub 계정이 둘(`paryoja`, `yj0604park`)이라 `yj0604park` 전용 private repo가
`Repository not found` (404)로 막힐 수 있다. 인증 오류가 아니라 404라서
"repo 이름 오타"로 오진하기 쉬움. **`gh auth switch`는 해법이 아니다** —
`GH_TOKEN`이 설정돼 있으면 무시된다.

## 근본 해법: collaborator 추가 (2026-08-01 검증)

해당 repo에 `paryoja`를 collaborator로 추가한다.

앱은 `gh` 자격증명이 아니라 자체 installation token(`x-access-token:...`)으로
clone하는데, 그 토큰은 앱에 로그인된 계정(`paryoja`)의 user-to-server 토큰이라
**paryoja 본인이 볼 수 있는 repo만** 보인다. 앱 쪽 repository access 설정만
만져서는 안 풀린다. 권한 없으면 `create_session`/`create_project`의 workspace
초기화부터 실패하므로 사용자에게 collaborator 추가를 요청할 것.

## 폴백 (권한 부여가 어려울 때)

`GH_TOKEN=` 빈 값 대입은 안 먹히니 `env -u`:

```bash
env -u GH_TOKEN gh repo view yj0604park/<repo>
env -u GIT_CONFIG_PARAMETERS -u GH_TOKEN git fetch   # push/clone도 동일
```

(`GIT_CONFIG_PARAMETERS`로 Copilot 세션이 `credential.helper=copilot`을 강제
주입하므로 이것도 같이 빼야 keyring의 `yj0604park`가 잡힘)

폴백으로 CLI는 뚫려도 세션 위임은 여전히 안 되니, 그땐 직접 처리할 것.
