# 개발 작업과 기술 기록

직접 수행한 작업 중 공개 가능한 코드, 설정 파일과 테스트 결과를 정리합니다. 각 작업은 목적, 구현 내용, 실행 방법, 확인한 결과와 한계를 함께 기록합니다.

## 공개 작업

| 작업 | 주요 기술 | 공개 내용 | 확인 상태 |
| --- | --- | --- | --- |
| [messaging] [MQTT 브로커 전환 및 공유 구독](projects/mqtt-ha/README.md) | EMQX 5.0, HAProxy, Docker Compose, Keepalived | 과거 작업 기록, macOS 재현 구성, 실행 로그 | 공유 구독·재연결 검증. VIP 전환은 이번 재현에서 제외 |
| [network] [NIC Active-Backup 본딩](projects/nic-bonding/README.md) | Bash, Netplan, NetworkManager | Y사 실제 서버의 스위치 이중화 연계 NIC 본딩 작업과 스크립트 | 고객사 서버 적용. 공개본 구문 확인, 장애 전환 재시험은 미수행 |

## 협업·설계 자료

[doc] [개발 PL 협업·설계 가이드](projects/개발협업가이드/README.md)

PMP 보유 개발 PL의 스쿼드·애자일 경험을 바탕으로 공개용으로 재작성한 자료입니다. 코드 컨벤션, 커밋·리뷰, 완료 기준, 스쿼드 운영, MSA 설계 판단과 릴리스 양식을 담았습니다. 세부 규칙은 제안 기준이며 과거 적용 실적과 구분합니다.

## 저장소 구조

```text
engineering-portfolio/
├── README.md
├── CONTRIBUTING.md
├── projects/                 # 공개 가능한 작업과 결과물
│   ├── README.md
│   ├── 개발협업가이드/  # 협업·애자일·설계 가이드와 양식
│   ├── mqtt-ha/
│   │   ├── README.md
│   │   ├── experience.md     # 과거 수행 경험
│   │   └── lab/              # 새로 만든 재현 환경
│   │       ├── README.md
│   │       ├── compose.yaml
│   │       ├── haproxy.cfg
│   │       ├── mqtt.sh
│   │       ├── results.md
│   │       └── test-output.md
│   └── nic-bonding/
│       ├── README.md
│       └── setup-bond_v4.sh
└── assets/                   # 공통 이미지와 다이어그램
```

## 문서 탐색

- [작업 목록과 추가 방법](projects/README.md)
- [doc] [개발 PL 협업·설계 가이드](projects/개발협업가이드/README.md)
- [공통 자료](assets/README.md)

## 기록 기준

- 코드는 실행 조건과 사용 방법을 함께 기록합니다.
- 테스트 결과에는 환경, 관찰 내용과 검증 범위를 명시합니다.
- 과거 수행 경험과 이번에 재현한 결과를 구분합니다.
- 미확인 결과나 성과를 추가하지 않습니다.
- 회사 내부 정보, 고객사 기밀, 인증 정보는 제외합니다.
- 문서는 Markdown, 내부 링크는 상대경로, 구성도는 Mermaid를 사용합니다.

자세한 기준은 [작성 가이드](CONTRIBUTING.md)를 참고합니다.
