# 워크플로우 + n8n 프로젝트 - Claude Code 규칙

## 개요

로컬 PC에서 Docker로 n8n을 띄우고, Claude Code가 n8n-mcp로 워크플로우를 만들고 운영하는 프로젝트다.

| 문서 | 내용 |
|------|------|
| [README.md](README.md) | 설치, 실행, 설정, 디렉터리 구조 |
| [docs/architecture.md](docs/architecture.md) | 시스템 구성도, 연결 관계, 워크플로우 구조, 서비스별 출처와 설치 방법 |
| [docs/logging.md](docs/logging.md) | 로그가 남는 곳, 로그 파일 기록, 강제 종료 확인 |
| [docs/code-style.md](docs/code-style.md) | 코드 스타일 (작성 전) |
| [.claude/rules/n8n/common.md](.claude/rules/n8n/common.md) | n8n 작업에 항상 적용하는 규칙 |
| [.claude/skills/n8n/SKILL.md](.claude/skills/n8n/SKILL.md) | n8n 워크플로우 생성·운영·교육 스킬 (주간 운영 리포트 포함) |

## HARD RULES

- n8n 작업의 HARD RULE(삭제 규칙)은 [.claude/rules/n8n/common.md](.claude/rules/n8n/common.md)에 있다.

## 환경

| 항목 | 값 |
|------|----|
| 실행 위치 | 로컬 PC (macOS, Docker Desktop) |
| n8n | Docker Compose, `http://localhost:50990` — 설정은 `services/n8n/.env` |
| DB | PostgreSQL 17 (`n8n-postgres` 컨테이너, 호스트 포트 미개방) |
| n8n-mcp | Claude Code가 `.mcp.json`으로 실행 (stdio, 포트 없음) |
| n8n-admin | 관리 대시보드, `http://localhost:50999` — git 서브모듈, 설정은 `services/n8n-admin/.env` |

버전은 `services/n8n/.env.example`의 `N8N_VERSION`과 `services/n8n-mcp/package.json`에 고정한다.

## 표준 아키텍처 (디렉터리 구조)

```text
root
├── bin/                # 쉘, 바이너리 등 전체 제어 스크립트
├── config/**           # DB, 앱 등 yaml, properties, toml 등 설정 파일
├── data/**             # 백업 등 실행 결과물 (git 제외)
├── deploy/*            # 서버 기준 systemctl 등 서비스 등록 파일
├── docs/**             # 프로젝트 관련 문서
├── logs/**             # 로그 파일 (git 제외)
├── services/**         # 서비스별 앱 Layer
├── tests/**            # 단위/통합 테스트 Layer
└── README.md           # 프로젝트 개요 및 설명
```

- 표준 구조이며 `config/`, `deploy/`, `tests/`는 아직 쓰지 않는다. 필요할 때 만든다.
- 현재 서비스: `services/n8n`, `services/n8n-mcp`, `services/n8n-admin`(서브모듈). 실제 파일 구성은 README의 디렉터리 구조를 따른다.
- `services/n8n-admin`은 외부 리포지토리다. 내부 파일을 수정하지 않고, 리뷰 대상에서도 제외한다.

## 표준 워크플로우

## 기술 스택

- 워크플로우 엔진: n8n (Docker Compose), PostgreSQL
- 제어 스크립트: Bash (`bin/n8n.sh`, `bin/n8n-admin.sh`)
- Claude Code 연동: n8n-mcp (Node.js, npm), `n8n-mcp-skills` 플러그인
- 관리 대시보드: n8n-admin (Next.js, pnpm)

## 코드 스타일

## I/O 관리

## Git Flow, Commit 규칙 (형상관리)

### 브랜치

- `main`: 프로덕션 배포 브랜치
- `develop`: 개발 통합 브랜치 (아직 없음 — 만들기 전까지 feature 브랜치는 main에서 분기하고 main으로 병합)
- `feature/{서비스명}/{작업명}`: 기능 개발 브랜치 (develop에서 분기)
  - 서비스명: `services/` 아래 디렉터리 이름 (예: `n8n`, `n8n-mcp`, `n8n-admin`)
  - 작업명: 작업 내용을 나타내는 영문 소문자 이름, 단어는 하이픈으로 연결 (예: `rules`, `stock-screener`)
  - 예시: `feature/n8n/rules`, `feature/n8n/stock-screener`
- 병합은 병합 커밋을 남긴다 (`git merge --no-ff`)
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
