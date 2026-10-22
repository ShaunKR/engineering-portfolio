# MQTT 브로커 전환 및 공유 구독

EMQX 기반 MQTT 환경에서 브로커 전환과 공유 구독을 다룬 작업입니다.

## 공개 내용

- [과거 수행 경험](experience.md): EMQX 5.0, HAProxy, Keepalived를 사용한 작업과 당시 확인 방법
- [macOS 재현 실습](lab/README.md): 독립 브로커 두 대와 HAProxy의 백업 전환 구성
- [재현 결과](lab/results.md): 실제 관찰 결과와 검증하지 않은 범위
- [실행 로그](lab/test-output.md)

## 코드와 설정

- [Docker Compose](lab/compose.yaml)
- [HAProxy 설정](lab/haproxy.cfg)
- [MQTT 클라이언트 실행 스크립트](lab/mqtt.sh)

과거 설정 원본은 남아 있지 않습니다. 재현 환경은 새로 작성했으며, Keepalived VIP 전환을 포함하지 않습니다. 재현 환경의 `backup` 지정은 과거 설정과 구분합니다.

[작업 목록으로](../README.md)
