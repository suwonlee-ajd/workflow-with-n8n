# 아키텍처

| 항목 | 값 |
| --- | --- |
| 문서 버전 | 0.12.2 |
| 최종 수정 | 2026-11-25 |

이 프로젝트를 이루는 서비스와 그 연결 관계, 저장소 디렉터리 구조, n8n 위에서 도는 워크플로우의 구조, 각 서비스의 출처와 설치 방법을 정리한다.

## 시스템 구성도

현재는 PC 한 대에서 모든 서비스를 띄우는 단일 구성이다.

핵심은 n8n, PostgreSQL, n8n-mcp 다. n8n-admin 은 없어도 나머지가 그대로 동작하는 부가 도구라 점선으로 옆에 두었다.

```text
┌─────────────────────────────────── workflow-with-n8n ────────────────────────────────────┐
│                                                                                          │
│  브라우저 ───────────────────────────────────────┬ ─ ─ ─ :3000   ─ ─ ─ ─ ─ ┐             │
│                                                  │                         ▼             │
│  Claude Code                                     │              ┌─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┐  │
│       │ stdio                                    │              ╎      n8n-admin      ╎  │
│       ▼                                          │              ╎     (부가 도구)     ╎  │
│  ┌──────────┐           REST API                 │              └─ ─ ─ ─ ─ ┬ ─ ─ ─ ─ ─┘  │
│  │ n8n-mcp  │───────────────────────────────────▶│◀ ─ ─  REST API ─ ─ ─ ─ ─┘             │
│  └──────────┘                                    │                                       │
│                                                  │ :5678 (UI·웹훅·폼·API)                │
│                                                  ▼                                       │
│  ┌───────────── Docker (네트워크 n8n_default) ──────────────┐                            │
│  │                                                          │                            │
│  │  ┌──────────────────┐  postgres:5432   ┌──────────────┐  │                            │
│  │  │   n8n-postgres   │◀─────────────────│     n8n      │  │                            │
│  │  │ 호스트 포트 없음 │                  │ :5678 공개   │  │                            │
│  │  └──────────────────┘                  └──────────────┘  │                            │
│  │  볼륨 n8n_postgres_data          볼륨 n8n_data           │                            │
│  │  (워크플로우·실행 기록 등)       (암호화 키·이벤트 로그) │                            │
│  └──────────────────────────────────────────────────────────┘                            │
│                                                                                          │
│  bin/n8n.sh ─▶ 시작·중지·백업·로그 기록·내보내기 (data/backups, logs, n8n/workflows)     │
└──────────────────────────────────────────────────┬───────────────────────────────────────┘
                                                   │ 워크플로우가 호출
                                                   ▼
                                 외부 서비스 (Slack, 검색·시세 API 등)
```

## 서비스 목록

| 서비스 | 역할 | 실행 방식 | 포트 | 버전 |
|--------|------|-----------|------|------|
| n8n | 워크플로우 엔진, 화면, 웹훅 | Docker 컨테이너 `n8n` | 5678 | 2.49.5 (Node 26.13.1 로 교체) |
| PostgreSQL | n8n 데이터 저장 | Docker 컨테이너 `n8n-postgres` | 없음 (Docker 내부 5432) | 17.12 |
| n8n-mcp | Claude Code 가 n8n 을 다루는 MCP 서버 | Claude Code 가 필요할 때 실행 (stdio) | 없음 | 2.103.2 |
| n8n-mcp-skills | n8n-mcp 사용법 스킬 묶음 | Claude Code 플러그인 | 없음 | 1.37.1 |
| n8n-admin (부가) | 워크플로우·유저·크레덴셜 관리 대시보드 | 호스트에서 Next.js 실행 | 3000 | 1.2.0 |

- n8n 은 실행 모드 기본값(`regular`)으로 동작한다. 프로세스 하나가 화면, 웹훅, 워크플로우 실행을 모두 맡는다.
- 포트는 각 서비스의 기본값으로 적었다. 포트와 버전을 바꾸는 곳은 아래 각 서비스의 "설정"에 적었다.

## 연결 관계

| 출발 | 도착 | 방식 | 인증 |
|------|------|------|------|
| 브라우저 | n8n | HTTP `localhost:5678` | n8n 계정 로그인 |
| 브라우저 | n8n-admin | HTTP `localhost:3000` | `ADMIN_PASSWORD` |
| n8n-admin | n8n | n8n 공개 API (`/api/v1`) | n8n API 키 |
| Claude Code | n8n-mcp | stdio (프로세스 직접 실행) | 없음 |
| n8n-mcp | n8n | n8n 공개 API (`/api/v1`) | n8n API 키 |
| n8n | PostgreSQL | Docker 내부 네트워크 `postgres:5432` | `POSTGRES_*` |
| n8n | 외부 서비스 | 워크플로우 노드가 호출 | n8n 크레덴셜 |
| n8n-admin | Slack | Incoming Webhook | 웹훅 주소 |

- n8n-admin 과 n8n-mcp 는 같은 n8n API 키를 쓴다. 키는 `services/n8n/.env` 의 `N8N_API_KEY` 에 있고, n8n-admin 은 같은 값을 `services/n8n-admin/.env` 의 `SERVER_API_KEY` 에 둔다.
- PostgreSQL 은 호스트로 포트를 열지 않는다. 접속은 `docker exec` 로만 한다.

## 데이터가 저장되는 곳

| 데이터 | 위치 | 백업 |
|--------|------|------|
| 워크플로우, 크레덴셜, 실행 기록, 유저 | Docker 볼륨 `n8n_postgres_data` | `bin/n8n.sh backup` 의 DB 덤프 |
| 크레덴셜 암호화 키, 이벤트 로그 | Docker 볼륨 `n8n_data` | `bin/n8n.sh backup`, 백업 워크플로우의 볼륨 백업 |
| 워크플로우 JSON (git 이력용) | `services/n8n/workflows/` — 현재 저장소에는 없음 | 필요할 때 `bin/n8n.sh export` 로 만들어 커밋 |
| 컨테이너 로그 | Docker, 그리고 `logs/<YYYY>/<YYYY.MM>/<서비스명>.<YYYY-MM-DD>.log` | 백업 대상 아님. [logging.md](logging.md) 참고 |
| 비밀값 | `services/n8n/.env`, `services/n8n-admin/.env` | git 제외. 따로 보관 |

### 백업

`bin/n8n.sh backup` 과 백업 워크플로우 `[메인] 운영: n8n 데이터 백업` 이 같은 폴더 `<BACKUP_DIR>/<YYYYMMDDHHMM>/<서비스명>/` 에 저장한다.

- 주의
  - 암호화 키(`N8N_ENCRYPTION_KEY`)를 잃으면 DB 백업이 있어도 크레덴셜 복호화 불가. 볼륨 백업과 DB 백업을 함께 보관
  - 18:00 에 Mac 이 절전 중이면 그날 백업은 건너뜀. 스케줄러가 놓친 실행을 다시 돌리지 않음
  - 백업 파일은 자동으로 지워지지 않음
- 위치
  - `BACKUP_DIR`: `services/n8n/.env` 에서 지정. 비우면 `data/backups`, 다른 위치는 절대 경로
  - `bin/n8n.sh backup` 과 compose 의 폴더 연결이 같은 `BACKUP_DIR` 을 읽음
  - 서비스명: 컨테이너 이름 `n8n`, `n8n-postgres`
- `bin/n8n.sh backup` (수동 실행)
  - `n8n-postgres/n8n_db_<시각>.sql.gz`: DB 덤프
  - `n8n/n8n_backup_<시각>.tar.gz`: `n8n_data` 볼륨
  - `n8n/n8n_workflows_<시각>/<ID>.json`: 워크플로우 JSON
- 백업 워크플로우 (매일 18:00, 수동 실행 가능)
  - `n8n/n8n_backup_<시각>.tar.gz`: `n8n_data` 볼륨을 Code 노드가 tar 로 묶음
  - `n8n/n8n_workflows_<시각>/<ID>.json`: 워크플로우 JSON
  - `n8n/n8n_executions_<시각>.json`: 실행 기록
  - `n8n/n8n_datatables_<시각>.json`: 데이터 테이블
  - DB 덤프는 없음. n8n 컨테이너에 `pg_dump` 가 없음
  - Code 노드가 `fs`·`child_process` 를 쓰므로 `.env` 의 `NODE_FUNCTION_ALLOW_BUILTIN=*` 필요
- n8n 컨테이너 폴더 연결
  - `<BACKUP_DIR>` 전체를 `~/.n8n-files/backups` 로 연결. n8n 2.x 의 파일 노드는 `~/.n8n-files` 아래만 쓸 수 있음
  - 그래서 `bin/n8n.sh backup` 의 DB 덤프도 워크플로우에서 읽을 수 있음. `n8n_data` 볼륨은 Code 노드가 원래 `~/.n8n` 으로 읽을 수 있어, 새로 드러나는 것은 사실상 DB 덤프
- 동시 실행
  - 두 백업이 같은 분에 실행되면 한 폴더에 섞임. 파일 이름의 `<시각>`(초 단위)이 달라 덮어쓰지는 않음

## 애플리케이션 아키텍처

이 프로젝트의 애플리케이션은 n8n 에 올린 워크플로우다. 실제로 실행되는 것은 n8n DB 에 저장된 워크플로우이며, 현재 코드 저장소에는 워크플로우 JSON 이 없다. 필요할 때 `bin/n8n.sh export` 로 `services/n8n/workflows/` 에 내보낸다.

### 디렉터리 구조

저장소의 파일 구성이다. [README](../README.md) '디렉터리 구조'와 같게 유지하며, 괄호 안의 장·번호는 README 기준이다.

```text
root
├── .claude/                         # Claude Code 규칙·스킬·설정
├── bin/                             # 실행 스크립트
│   ├── n8n.sh
│   └── n8n-admin.sh
├── services/
│   ├── n8n                          # n8n (docker 배포 이미지 사용)
│   │   ├── .env                     # 환경변수 — 비밀값 포함.
│   │   ├── .env.example             # .env 템플릿 — bin/n8n.sh init 이 복사, ★ 는 비밀값
│   │   ├── docker-compose.yml       # docker 컨테이너 정의
│   │   ├── Dockerfile               # n8n 공식 이미지의 Node.js 만 보안 패치 버전으로 교체
│   │   ├── .dockerignore            # 빌드 컨텍스트 전부 제외
│   │   └── workflows/               # bin/n8n.sh export 결과 JSON
│   │
│   ├── n8n-mcp                      # n8n-mcp
│   └── n8n-admin/                   # n8n-admin (데이터팝콘 제작)
├── .gitmodules                      # 서브모듈 원격 주소
├── .mcp.json                        # Claude Code 프로젝트 MCP 등록 (6장)
├── data/                            # 데이터 계층
│   └── backups/                     # 백업 <YYYYMMDDHHMM>/<서비스명>/ (git 제외, 주요 설정 5번)
├── logs/                            # 컨테이너 로그 <YYYY>/<YYYY.MM>/<서비스명>.<YYYY-MM-DD>.log (git 제외)
├── docs/                            # 프로젝트 문서
│   ├── architecture.md              # 시스템 구성도, 연결 관계, 워크플로우 구조 등
│   ├── logging.md                   # 로깅 관련
│   └── code-style.md                # 코드 스타일
├── CHANGELOG.md                     # 버전별 변경 기록
├── CLAUDE.md                        # Claude Code 프로젝트 규칙
└── README.md
```

### 워크플로우 계층

워크플로우는 실행 역할에 따라 세 유형으로 나누고, 이름 앞에 유형을 붙인다 (`[유형] 도메인: 기능`).

```text
            트리거
 (스케줄 · 폼 · 웹훅 · 수동)
              │
              ▼
  ┌────────────────────────┐                          ┌──────────────────────────┐
  │         [메인]         │     Execute Workflow     │          [서브]          │
  │    업무 흐름 하나를    │─────────────────────────▶│     여러 곳에서 쓰는     │
  │  처음부터 끝까지 실행  │        결과 반환         │        공통 로직         │
  └────────────────────────┘                          └──────────────────────────┘
        │ 실행 실패 시  │                                           │
        │               │                                           │
        │               └─────────────────────┬─────────────────────┘
        │                                     ▼
        │                  외부 서비스 (Slack, 시세·검색·뉴스 API)
        ▼
  ┌────────────────────────┐
  │         [에러]         │─────────────▶ Slack
  │       실패 알림        │
  └────────────────────────┘
```

| 유형 | 시작 방식 | 역할 |
|------|-----------|------|
| `[메인]` | 스케줄, 폼, 웹훅, 수동 실행 | 업무 흐름 하나를 처음부터 끝까지 실행한다. 필요하면 서브를 호출한다 |
| `[서브]` | 다른 워크플로우의 Execute Workflow 노드 | 여러 곳에서 쓰는 공통 로직. 입력을 받아 처리하고 결과를 돌려준다 |
| `[에러]` | Error Trigger | 다른 워크플로우가 실패했을 때 n8n 이 대신 실행한다. 실패 내용을 알린다 |

이름 규칙, 캔버스 그룹 규칙, 설명 스티키 노트(⚙️·제목·요약) 규칙은 [.claude/skills/n8n/references/workflow-builder.md](../.claude/skills/n8n/references/workflow-builder.md) 의 '네이밍 컨벤션'에 있다.

### 워크플로우 예시

유형별로 하나씩만 든다. 전체 목록은 n8n 화면이나 `n8n_list_workflows` 로 확인한다.

| 유형 | 예시 | 시작 방식 | 하는 일 |
|------|------|-----------|---------|
| 메인 | `[메인] 주식: 국내 종목 선별` | 스케줄, 폼 | 서브 워크플로우를 차례로 불러 종목을 선별한다 |
| 서브 | `[서브] 주식: 일별 시세 가져오기` | 메인이 호출 | 시세를 가져와 메인에 돌려준다 |
| 메인 | `[메인] 운영: 주간 실행 리포트` | 스케줄 | 서브 없이 실행 현황을 모아 Slack 으로 보낸다 |
| 에러 | `[에러] 공통: 실패 알림` | Error Trigger | 실패한 워크플로우와 원인을 Slack 으로 알린다 |

### 에러 처리

n8n 은 워크플로우가 실패하면 그 워크플로우 설정의 `errorWorkflow` 에 지정된 워크플로우를 실행한다. 여기서는 `[에러] 공통: 실패 알림` 하나를 공용으로 쓴다.

- `errorWorkflow` 를 지정하지 않은 워크플로우는 실패해도 알림이 가지 않는다.
- 에러 워크플로우는 게시(활성)되어 있어야 동작하고, 편집 화면에서 수동으로 실행한 실패에는 호출되지 않는다.

### 개발과 반영 흐름

```text
Claude Code ──▶ n8n-mcp ──▶ n8n (DB) ─ ─▶ bin/n8n.sh export ─ ─▶ services/n8n/workflows/*.json ─ ─▶ git
 (스킬·규칙)    (검증·생성·수정)  (게시·실행)   (선택: git 으로 이력을 남길 때)
```

1. Claude Code 가 `.claude/skills/n8n` 스킬과 `.claude/rules/n8n` 규칙에 따라 n8n-mcp 로 워크플로우를 검증하고 만들거나 고친다. n8n 화면에서 직접 고쳐도 된다.
2. 변경은 n8n DB 에 바로 저장된다. 스케줄·웹훅·폼 트리거는 워크플로우를 게시(활성화)해야 동작한다.
3. git 으로 이력을 남기려면 `bin/n8n.sh export` 로 JSON 을 내보내 커밋한다. 현재는 내보낸 JSON 을 저장소에 두지 않으므로, 워크플로우 원본은 n8n DB 와 `bin/n8n.sh backup` 백업(DB 덤프와 워크플로우 JSON)에만 있다.
4. 다른 n8n 으로 옮길 때는 먼저 `export` 한 JSON 을 `bin/n8n.sh import` 로 가져온다. 크레덴셜 값은 JSON 에 없으므로 다시 만들어 연결한다.

## 서비스별 출처와 설치

사전 준비: git, Docker(Compose 포함), Node.js(보안 권고의 해결 버전 이상, README 6장)와 npm, openssl, curl. pnpm 은 n8n-admin 을 쓸 때만 필요하다.

### n8n

- 출처: [n8n-io/n8n](https://github.com/n8n-io/n8n) · [문서](https://docs.n8n.io) · [릴리스](https://github.com/n8n-io/n8n/releases)
- 이미지: 로컬 빌드 `n8n-local:<N8N_VERSION>-node<N8N_NODE_VERSION>`
  - 공식 이미지 `docker.n8n.io/n8nio/n8n:<N8N_VERSION>` 에 [node 공식 이미지](https://hub.docker.com/_/node) `node:<N8N_NODE_VERSION>-alpine3.24` 의 Node 바이너리만 덮어쓴다.
  - 이유와 되돌릴 조건은 `services/n8n/Dockerfile` 맨 위 주석, 되돌리는 방법은 [README](../README.md) '4. 버전 업그레이드' 에 있다.
- 한글 환경 설정 참고: [EddyGlen n8n 한글 설정 가이드](https://eddyglen.com/n8n-korean-language-setup/)
- 설정: `services/n8n/.env` (버전 `N8N_VERSION`·`N8N_NODE_VERSION`, 포트 `N8N_PORT`), `services/n8n/docker-compose.yml`, `services/n8n/Dockerfile`

```bash
bin/n8n.sh init    # .env 생성, DB 비밀번호·암호화 키 자동 생성, n8n-mcp 의존성 설치
bin/n8n.sh start   # http://localhost:5678
```

처음 접속하면 관리자 계정을 만든다. 이어서 **Settings > n8n API** 에서 API 키를 만들어 `.env` 의 `N8N_API_KEY` 에 넣는다.

볼륨(`n8n_data`, `n8n_postgres_data`)과 컨테이너 이름이 고정이라 한 PC 에서는 n8n 을 하나만 띄운다. 같은 PC 의 다른 폴더에 clone 해도 같은 DB 를 쓰므로, `init` 은 DB 볼륨이 이미 있으면 비밀번호를 새로 만들지 않고 안내 후 멈춘다 ([README](../README.md) 5장).

### PostgreSQL

- 출처: [Docker 공식 이미지 postgres](https://hub.docker.com/_/postgres) · [문서](https://www.postgresql.org/docs/17/)
- 이미지: `postgres:17.12-alpine`
- 설정: `services/n8n/.env` 의 `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`

따로 설치하지 않는다. `bin/n8n.sh start` 가 n8n 과 함께 띄운다. 계정과 DB 는 볼륨이 비어 있는 최초 기동 때만 만들어진다. 그 뒤에는 `.env` 의 `POSTGRES_PASSWORD` 만 바꿔도 DB 에 반영되지 않아 n8n 이 접속하지 못한다.

### n8n-mcp

- 출처: [czlonkowski/n8n-mcp](https://github.com/czlonkowski/n8n-mcp) · [npm](https://www.npmjs.com/package/n8n-mcp)
- 설치 형태: npm 패키지. 버전은 `services/n8n-mcp/package.json` 에 고정
- 설정: `.mcp.json` (n8n 주소 `N8N_API_URL`, 웹훅 보안 모드, 통계 전송 끔). API 키는 실행할 때 `services/n8n/.env` 에서 읽는다

```bash
bin/n8n.sh init                   # n8n 설치 때 이미 실행했으면 생략
cd services/n8n-mcp && npm ci     # 직접 설치할 때
```

설치 후 Claude Code 를 새로 열어 프로젝트 MCP 서버 `n8n-mcp` 를 승인하고 `/mcp` 로 연결을 확인한다. 버전을 올릴 때는 `package.json` 의 버전을 바꾸고 `npm install` 한 뒤 Claude Code 를 다시 시작한다.

### n8n-mcp-skills

- 출처: [czlonkowski/n8n-skills](https://github.com/czlonkowski/n8n-skills)
- 설치 형태: Claude Code 플러그인. `.claude/settings.json` 의 `enabledPlugins` 로 이 프로젝트에서 켠다

Claude Code 안에서 실행한다.

```text
/plugin marketplace add czlonkowski/n8n-skills
/plugin install n8n-mcp-skills@n8n-mcp-skills
```

### n8n-admin (부가 도구)

- 출처: [team-datapopcorn/n8n-admin](https://github.com/team-datapopcorn/n8n-admin)
- 설치 형태: git 서브모듈 (`services/n8n-admin/`). 이 리포지토리에는 원격 주소와 고정한 커밋만 기록된다
- 설정: `services/n8n-admin/.env` (접속 주소와 포트 `NEXTAUTH_URL`, n8n 주소 `SERVER_URL`, API 키 `SERVER_API_KEY`)

```bash
git submodule update --init                                  # 서브모듈 받기
cd services/n8n-admin/admin && pnpm install && cd -          # 의존성 설치
cp services/n8n-admin/.env.example services/n8n-admin/.env   # 값 입력
bin/n8n-admin.sh start                                       # http://localhost:3000
```

외부 리포지토리이므로 내부 파일은 수정하지 않는다. 업데이트 확인과 반영 방법은 README 7장에 있다.

## 설치 순서

새 PC 에 처음 구성할 때의 순서다. 자세한 설명은 README 의 각 장을 따른다.

1. 리포지토리 받기: `git clone --recurse-submodules <주소>`
2. n8n 과 PostgreSQL 실행: `bin/n8n.sh init` 으로 `.env` 를 만들고 n8n-mcp 의존성을 설치한 뒤 `bin/n8n.sh start` (README 1~2장, 5장)
   - 이 PC 에서 n8n 을 띄운 적이 있으면(DB 볼륨이 남아 있으면) `init` 이 비밀번호 안내 후 멈춘다. README 5장을 따른다
3. n8n 관리자 계정과 API 키 만들기: 키는 `.env` 의 `N8N_API_KEY` 에 입력
4. Claude Code 연결: 새로 열어 `n8n-mcp` 승인 (README 6장)
5. n8n-mcp-skills 플러그인 설치
6. (선택) n8n-admin 설치와 실행 (README 7장)
7. 워크플로우 옮기기: 저장소에는 워크플로우 JSON 이 없으므로, 기존 n8n 의 백업(`bin/n8n.sh backup`)에서 DB 덤프를 복원하거나, 백업에 든 워크플로우 JSON 을 `services/n8n/workflows/` 에 넣고 `bin/n8n.sh import` 한다 (README 3장, 5장). `import` 로 가져온 워크플로우는 모두 비활성 상태이고, 크레덴셜은 다시 연결해야 한다

## 클러스터링

현재는 단일 PC, 단일 n8n 프로세스 구성이다. 여러 서버로 나누는 클러스터링 방법은 확인 중이며, 정해지면 이 절에 서버 구성도를 추가한다.
