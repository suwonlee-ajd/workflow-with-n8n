# 워크플로우 + n8n 프로젝트 - Claude Code 규칙

## 개요

## HARD RULES

## 환경

## 표준 아키텍처 (디렉터리 구조)

```text
root
├── bin/                # 쉘, 바이너리 등 전체 제어 스크립트
├── config/**           # DB, 앱 등 yaml, properties, toml 등 설정 파일
├── deploy/*            # 서버 기준 systemcctl 등 서비스 등록 파일
├── docs/**             # 프로젝트 관련 문서
├── services/**         # 서비스별 앱 Layer
├── tests/**            # 단위/통합 테스트 Layer
└── README.md           # 프로젝트 개요 및 설명
```

## 표준 워크플로우

## 기술 스택

## 코드 스타일

## I/O 관리

## Git Flow, Commit 규칙 (형상관리)

### 브랜치

- `main`: 프로덕션 배포 브랜치
- `develop`: 개발 통합 브랜치
- `feature/{서비스명}/{작업명}`: 기능 개발 브랜치 (develop에서 분기)
  - 서비스명: `services/` 아래 디렉터리 이름 (예: `n8n`)
  - 작업명: 작업 내용을 나타내는 영문 소문자 이름, 단어는 하이픈으로 연결 (예: `rules`, `stock-screener`)
  - 예시: `feature/n8n/rules`, `feature/n8n/stock-screener`
- `bugfix/*`: 긴급 수정 (main에서 분기)
- `hotfix/*`: 긴급 수정 (main에서 분기)

### 커밋 메시지 규칙

```text
<type>: <subject>

type: feat, fix, bugfix, hotfix, refactor, test, docs, chore
subject: 한글 또는 영문, 50자 이내
```

예시: `feat: 이메일 발송 자동화 추가`, `fix: 스케줄러 타임존 오류 수정`

## 출력 언어

모든 출력은 한국어로 작성한다. 워크플로우 이름, 노드 설명 등도 한국어로 지정한다. 단, 노드 타입명이나 기술 용어는 원어 그대로 사용한다.