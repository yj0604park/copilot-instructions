# Copilot CLI Instructions

## 언어
- 한국어로 응답

## 작업 완료 알림
- 작업 완료 시 iTerm2 커스텀 알림을 전송할 것
- 방법: `printf '\ePtmux;\e\e]9;메시지\a\e\\' > /dev/ttys005`
- 형식: "Copilot: {작업 내용} 완료!"
