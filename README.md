# n8n + claude code 환경 Docker 설정

![License](https://img.shields.io/github/license/suwonlee-ajd/workflow-with-n8n)
![Stars](https://img.shields.io/github/stars/suwonlee-ajd/workflow-with-n8n)
![Docker Compose](https://img.shields.io/badge/Docker%20Compose-required-2496ED?logo=docker&logoColor=white)
![n8n](https://img.shields.io/badge/n8n-2.44.7-EA4B71?logo=n8n&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17-4169E1?logo=postgresql&logoColor=white)
![Claude Code](https://img.shields.io/badge/Claude%20Code-n8n--mcp%202.103.0-D97757?logo=claude&logoColor=white)
![Node](https://img.shields.io/badge/node-%5E22.23%20%7C%20%5E24.22%20%7C%20%3E%3D26.12-brightgreen?logo=nodedotjs&logoColor=white)
![pnpm](https://img.shields.io/badge/pnpm-required%20%28n8n--admin%29-orange?logo=pnpm&logoColor=white)

Docker Compose로 n8n과 PostgreSQL을 띄우고, Claude Code가 n8n-mcp로 워크플로우를 만들고 운영하는 프로젝트입니다.

---

## 📁 디렉터리 구조

```text
root
├── bin/n8n.sh                       # n8n 시작·중지·로그·백업 제어 스크립트
├── bin/n8n-admin.sh                 # n8n-admin 대시보드 실행 스크립트 (7장 참고)
├── services/n8n/
│   ├── .env                         # 환경변수 (버전·포트·타임존·로케일·DB 계정·암호화 키·API 키) — 비밀값 포함, git 제외
│   ├── .env.example                 # .env 템플릿 (비밀값은 비워 둠) — cp .env.example .env 후 ★ 항목 채우기
│   ├── docker-compose.yml           # n8n + PostgreSQL 컨테이너 정의
│   └── workflows/                   # bin/n8n.sh export 가 만드는 워크플로우 JSON 폴더 (현재 저장소에는 없음, 3장 참고)
├── services/n8n-mcp/                # Claude Code 용 n8n MCP 서버 (6장 참고)
├── services/n8n-admin/              # n8n 관리 대시보드 — 외부 리포지토리를 git 서브모듈로 연결 (7장 참고)
├── .gitmodules                      # 서브모듈 등록 정보 (n8n-admin 원격 주소)
├── .mcp.json                        # Claude Code 프로젝트 MCP 등록 (6장 참고)
├── .claude/                         # Claude Code 규칙(rules/n8n)·스킬(skills/n8n)·플러그인 설정(settings.json)·개인 권한 설정(settings.local.json, 커밋 안 함)
├── data/backups/<날짜>/<서비스명>/  # 백업 (git 제외). 날짜는 YYYYMMDD, 서비스명은 n8n·n8n-postgres
│                                    #   n8n/           볼륨 백업 *.tar.gz, 워크플로우 JSON n8n_workflows_<시각>/, workflows/ 단일 워크플로우 백업
│                                    #   n8n-postgres/  DB 덤프 *.sql.gz
├── logs/<YYYY>/<YYYY.MM>/           # 컨테이너 로그 파일 <서비스명>.<YYYY-MM-DD>.log (git 제외)
├── docs/                            # 프로젝트 관련 문서
│   ├── architecture.md              # 시스템 구성도, 연결 관계, 워크플로우 구조, 서비스별 출처와 설치 방법
│   ├── logging.md                   # 로그가 남는 곳, 로그 파일 기록, 강제 종료 확인
│   └── code-style.md                # 코드 스타일 (초안)
├── CLAUDE.md                        # Claude Code 프로젝트 규칙
└── README.md
```

---

## 📌 주요 설정 포인트 요약

> 모든 설정은 `services/n8n/.env` 한 곳에서 관리합니다. n8n 컨테이너는 `env_file` 로 이 파일을 그대로 읽습니다
> (`LANG`·`TZ` 처럼 호스트 셸에도 흔히 있는 값이 `.env` 를 덮어쓰지 않도록 n8n 설정값에는 compose `${VAR}` 보간을 쓰지 않음).
> 예외로 compose 파일 자체가 알아야 하는 값만 `${VAR}` 보간으로 받습니다: 이미지 태그(`N8N_VERSION`), 포트 매핑(`N8N_PORT`),
> postgres·n8n 두 컨테이너가 공유하는 DB 접속 정보(`POSTGRES_*`).

0. **버전 고정 (`N8N_VERSION=2.44.7`)**
   - 이미지 태그를 `latest` 대신 stable 버전으로 고정 — 컨테이너 재생성 시 의도치 않은 업그레이드·DB 마이그레이션 방지
   - stable 확인: [n8n releases](https://github.com/n8n-io/n8n/releases)
1. **타임존 (한국 표준시 UTC+9)**
   - `GENERIC_TIMEZONE=Asia/Seoul`: n8n 스케줄 트리거, Cron 노드, 날짜 함수의 기본 시간대
   - `TZ=Asia/Seoul`: 컨테이너 OS 및 Node.js 라이브러리의 시스템 시간대 (로그 및 시스템 시간 일치)
2. **로케일 및 문자 인코딩 (UTF-8)**
   - `LANG=ko_KR.UTF-8`, `LC_ALL=ko_KR.UTF-8`: 한글 파일명 및 텍스트 데이터 파싱 시 깨짐 방지
   - `N8N_DEFAULT_LOCALE=ko`: 공식 이미지에는 영어(en) 번역만 들어 있어 **UI 는 영어로 표시됨** (번역 빌드를 마운트할 때만 효과)
3. **데이터 영속성 (Docker Volume)**
   - `n8n_postgres_data`: PostgreSQL 데이터 (워크플로우·크레덴셜·실행 이력·사용자)
   - `n8n_data:/home/node/.n8n`: 암호화 키(`config`)·커뮤니티 노드 등
   - 컨테이너를 재시작하거나 버전을 업그레이드해도 두 볼륨의 데이터는 보존됨
4. **한국 레거시 인코딩(EUC-KR / CP949) 처리 지원**
   - `NODE_FUNCTION_ALLOW_BUILTIN=*`: Code 노드에서 Node.js 내장 `TextDecoder` 사용 가능

---

## 🚀 빠른 시작

### 1. 접속 정보
- **URL**: [http://localhost:50990](http://localhost:50990) — 포트는 `services/n8n/.env` 의 `N8N_PORT` (변경 시 `N8N_WEBHOOK_URL` 도 함께 수정 후 `bin/n8n.sh restart`)
- 처음 접속 시 관리자 계정(이메일, 비밀번호)을 생성하고 즉시 사용하실 수 있습니다.

### 2. 관리 명령어 (`bin/n8n.sh`)
편리한 실행 및 관리를 위해 헬퍼 스크립트가 준비되어 있습니다 (어느 위치에서 실행해도 프로젝트 루트 기준으로 동작):

```bash
# 실행 (백그라운드)
bin/n8n.sh start

# 중지 (컨테이너를 지우기 전에 로그를 logs/ 에 기록)
bin/n8n.sh stop

# 재시작 (환경변수 갱신 시 컨테이너 완전 재생성, 로그 기록은 stop 과 동일)
bin/n8n.sh restart

# 실시간 로그 확인
bin/n8n.sh logs

# 컨테이너 상태 확인
bin/n8n.sh status

# 백업 → data/backups/<날짜>/ (n8n 이 실행 중이어야 함)
#   n8n/           n8n_data 볼륨(*.tar.gz), 워크플로우 JSON(n8n_workflows_<시각>/)
#   n8n-postgres/  PostgreSQL 덤프(*.sql.gz)
bin/n8n.sh backup

# 워크플로우 내보내기 / 가져오기 (services/n8n/workflows/*.json)
bin/n8n.sh export
bin/n8n.sh import
```

*(docker compose 를 직접 쓸 때는 compose 파일 경로를 지정하면 같은 폴더의 `.env` 를 자동으로 읽습니다: `docker compose -f services/n8n/docker-compose.yml up -d`)*

**컨테이너 로그**
- 컨테이너 로그는 Docker `json-file` 드라이버에 쌓이며 파일당 10MB·최대 5개로 제한합니다 (`docker-compose.yml` 의 `x-logging`). Docker 에는 일수 기준 롤링이 없습니다.
- 컨테이너를 지우면 Docker 로그도 사라지므로 `stop`·`restart` 는 지우기 직전에 로그 파일로 기록합니다. 경로는 `logs/<YYYY>/<YYYY.MM>/<서비스명>.<YYYY-MM-DD>.log` 이고 날짜는 기록한 날입니다 (타임스탬프는 UTC, 자동 삭제 없음). 백업(`data/backups/`)과는 별개입니다.
- 프로세스가 죽어 Docker 가 같은 컨테이너를 다시 띄운 경우에는 로그가 그대로 이어집니다. `docker compose down`·`docker rm` 을 직접 실행하면 기록 없이 사라집니다.
- 자세한 내용(강제 종료 확인 방법, n8n 로그 설정 변수 등): [docs/logging.md](docs/logging.md)

### 3. 워크플로우 형상관리 (export / import)
워크플로우는 DB(PostgreSQL)에 저장되므로, git 으로 이력을 남기려면 JSON 으로 내보내야 합니다. 두 명령 모두 n8n 이 실행 중이어야 합니다.

> 현재 저장소에는 내보낸 워크플로우 JSON 이 없습니다 (`services/n8n/workflows/` 폴더 없음). 워크플로우 원본은 n8n DB 에만 있으므로 보존은 `bin/n8n.sh backup` 으로 합니다.
> `backup` 은 DB 덤프와 함께 워크플로우 전체를 JSON 으로도 남깁니다 (`data/backups/<날짜>/n8n/n8n_workflows_<시각>/<워크플로우 ID>.json`).
> 백업한 JSON 하나를 되돌릴 때는 아래 '파일 하나만 가져올 때' 명령에 그 파일 경로를 넣습니다.
> git 으로 이력을 남기려면 `bin/n8n.sh export` 를 실행합니다. 폴더는 이때 자동으로 만들어집니다.

- `export`: 워크플로우 1개당 `<워크플로우 ID>.json` 1개. 폴더의 기존 JSON 을 비우고 통째로 교체하므로 n8n 에서 지운 워크플로우는 파일에서도 사라짐
  (단, 워크플로우가 0개면 n8n 이 오류를 내고 기존 파일은 그대로 둠)
- `import`: 폴더의 JSON 을 **전부** 가져옴 (폴더가 없으면 실패하므로 먼저 `export` 한 JSON 이 있어야 함). 같은 ID 는 덮어쓰고 없는 ID 는 새로 생성. **가져온 워크플로우는 (이미 켜져 있던 것도) 모두 비활성 상태**가 되므로 UI 에서 다시 활성화해야 함.
  파일 하나만 가져올 때:
  ```bash
  docker cp services/n8n/workflows/<ID>.json n8n:/tmp/<ID>.json
  docker exec n8n n8n import:workflow --input=/tmp/<ID>.json
  ```
- 크레덴셜 값은 JSON 에 들어가지 않습니다 (크레덴셜 ID·이름만 참조). 다른 n8n 으로 옮길 때는 크레덴셜을 따로 만들어 연결해야 합니다
- 노드 파라미터에 직접 넣은 토큰·URL, `pinData`(고정 테스트 데이터), `shared`(소유 계정 정보 — 이메일 포함)는 그대로 들어가므로 커밋 전에 확인하고 지우세요

### 4. 버전 업그레이드
1. `bin/n8n.sh backup` — 볼륨(암호화 키), DB(워크플로우·크레덴셜), 워크플로우 JSON 백업
2. `services/n8n/.env` 의 `N8N_VERSION` 을 새 stable 버전으로 변경 (git 에 남도록 `.env.example` 과 README 의 버전 표기·뱃지도 함께)
3. `bin/n8n.sh restart` — 새 버전 이미지는 자동으로 pull 됨

> **n8n 3.0 주의** (stable 2026-12 초 예정): npm 설치 지원 종료(Docker 필수), Function·Item Lists·Cron 등 레거시 노드 삭제, 암호화 키 로테이션 기본 활성화 등 breaking change 가 있습니다.
> 올리기 전에 n8n 화면의 **Settings > Migration Report** 를 확인하고 백업하세요. 참고: [v3.0 breaking changes](https://docs.n8n.io/changelog/v30-breaking-changes)

### 5. DB (PostgreSQL) 설정
n8n 은 DB 설정이 없으면 SQLite 를 쓰지만, 이 프로젝트는 `postgres` 컨테이너(PostgreSQL 17 — n8n 2.44.7 지원 범위)를 함께 띄워 사용합니다. 설정은 모두 `services/n8n/.env` 에서 합니다.

| 변수 | 용도 |
|---|---|
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | postgres 컨테이너의 계정·비밀번호·DB 이름. n8n 은 같은 값으로 접속 (compose 가 `DB_POSTGRESDB_*` 로 연결) |
| `N8N_ENCRYPTION_KEY` | 크레덴셜 암호화 키. `n8n_data` 볼륨의 `config` 파일과 같아야 하며, 다르면 n8n 이 시작되지 않음 |

- 비밀번호·암호화 키 생성: `openssl rand -hex 16`
- `POSTGRES_*` 는 **DB 볼륨이 비어 있는 최초 기동 때만** 적용됩니다. 이후 비밀번호를 바꾸려면 DB 안에서도 바꿔야 합니다
  (`docker exec -it n8n-postgres psql -U n8n -c "ALTER USER n8n PASSWORD '<새 비밀번호>'"` → `.env` 수정 → `bin/n8n.sh restart`)
- DB 접속: `docker exec -it n8n-postgres psql -U n8n -d n8n` (호스트 포트는 열지 않음)
- 덤프 복원: `gunzip -c data/backups/<날짜>/n8n-postgres/n8n_db_<시각>.sql.gz | docker exec -i n8n-postgres psql -U n8n -d n8n`
- `N8N_BASIC_AUTH_*` 는 n8n 1.0 에서 사용자 계정 방식으로 바뀌면서 없어진 설정이라 쓰지 않습니다

### 6. Claude Code 연동 (n8n-mcp)
Claude Code 가 [n8n-mcp](https://github.com/czlonkowski/n8n-mcp) 로 로컬 n8n 의 워크플로우를 만들고·조회·검증합니다. 서버는 프로젝트 안(`services/n8n-mcp/`)에 설치하고 `.mcp.json` 으로 등록합니다.

1. **설치** (clone 직후 1회 — `node_modules` 는 커밋하지 않음)
   ```bash
   cd services/n8n-mcp && npm ci
   ```
   버전은 `package.json` 에 고정. 올릴 때는 버전을 바꾸고 `npm install` 후 Claude Code 세션을 새로 시작합니다.
   README 맨 위 뱃지의 n8n-mcp 버전과 Node 요구 버전(`node_modules/n8n-mcp/package.json` 의 `engines`)도 함께 고칩니다.
2. **API 키**: n8n 화면 **Settings > n8n API** 에서 키를 만들어 `services/n8n/.env` 의 `N8N_API_KEY` 에 넣습니다.
   `.mcp.json` 은 서버를 띄울 때 이 값을 `.env` 에서 읽으므로 `.mcp.json` 에는 비밀값이 없습니다.
3. **연결 확인**: `.mcp.json` 은 세션 시작 때만 읽힙니다. Claude Code 를 새로 열고 프로젝트 MCP 서버(`n8n-mcp`) 사용을 승인한 뒤 `/mcp` 로 연결 상태를 확인합니다.

`.mcp.json` 의 `env` 설정:

| 변수 | 값 | 이유 |
|---|---|---|
| `N8N_API_URL` | `http://localhost:50990` | 로컬 n8n 주소. **`N8N_PORT` 를 바꾸면 여기도 같이 수정** |
| `WEBHOOK_SECURITY_MODE` | `moderate` | 기본값 `strict` 는 localhost 호출을 막아 로컬 웹훅·폼 테스트가 안 됨. `moderate` 는 localhost 허용, 사설 IP·클라우드 메타데이터 주소는 계속 차단 |
| `N8N_MCP_TELEMETRY_DISABLED` | `true` | n8n-mcp 의 사용 통계 전송 끔 (기본값은 켜짐) |

- `N8N_MCP_ACCESS_TOKEN`(n8n **Settings > Instance-level MCP** 키)은 설정하지 않았습니다. 그래서 아래 표의 🔒 도구는 쓸 수 없고, 다음 기능도 막혀 있습니다.
  - `n8n_test_workflow` 의 `prepare`·`pinned`·`direct` 방식 → 테스트는 webhook·form·chat 트리거 워크플로우를 **활성화한 뒤** 호출하는 방식만 됩니다
  - `n8n_workflow_versions` 의 `source: "native"`(n8n 자체 이력) → n8n-mcp 가 수정 직전에 저장한 스냅샷만 조회·롤백할 수 있습니다
  - `n8n_manage_datatable` 의 컬럼 추가·삭제·이름 변경
- `.claude/settings.json` 은 n8n-mcp 도구 사용법 스킬 묶음인 `n8n-mcp-skills` 플러그인을 켭니다.
- n8n 작업 규칙: [.claude/rules/n8n/common.md](.claude/rules/n8n/common.md)

#### n8n-mcp 도구 (2.103.0 기준 29개)

| 그룹 | 도구 |
|---|---|
| 워크플로우 생명주기 (11) | `n8n_health_check` ✅, `n8n_list_workflows` ✅, `n8n_get_workflow` ✅, `n8n_create_workflow` ✅, `n8n_update_partial_workflow` ✅, `n8n_update_full_workflow`, `n8n_delete_workflow`, `n8n_workflow_versions`, `n8n_manage_folders`, `n8n_list_catalog` ✅, `n8n_manage_agents` 🔒 |
| 검증 및 테스트 (7) | `validate_workflow` ✅, `n8n_validate_workflow` ✅, `validate_node` ✅, `n8n_autofix_workflow`, `n8n_test_workflow`, `n8n_evaluations`, `n8n_audit_instance` ✅ |
| 실행 및 데이터 (4) | `n8n_executions`, `n8n_manage_datatable`, `n8n_manage_credentials`, `n8n_manage_variables` |
| 노드 및 템플릿 (6) | `search_nodes` ✅, `get_node` ✅, `search_templates` ✅, `get_template` ✅, `n8n_deploy_template`, `n8n_explore_node_resources` 🔒 |
| 참조 (1) | `tools_documentation` ✅ |

- ✅ 확인 창 없이 실행: `.claude/settings.local.json` 의 `permissions.allow` 에 `mcp__n8n-mcp__<도구 이름>` 으로 등록한 도구. 읽기 전용 도구(🔒 제외)와 `n8n_create_workflow`·`n8n_update_partial_workflow` 만 등록합니다. 이 파일은 커밋하지 않는 개인 설정이라 각자 등록해야 합니다
- 표시 없음: 실행할 때마다 확인. 삭제 동작이 있는 도구(`n8n_delete_workflow`·`n8n_executions`·`n8n_workflow_versions`·`n8n_manage_*`), 전체 교체(`n8n_update_full_workflow`), 실제 실행(`n8n_test_workflow`·`n8n_evaluations`)은 allow 에 넣지 않습니다
- 🔒 `N8N_MCP_ACCESS_TOKEN` 이 있어야 쓸 수 있음 (현재 사용 불가)
- `n8n_manage_variables`(2.103.0 추가)는 `$vars` 변수를 관리하는 도구로, 변수 기능이 포함된 n8n 유료 라이선스에서만 동작합니다 (무료 Community 에디션 불가)
- 도구 목록은 `tools_documentation` 으로 확인합니다. `n8n_health_check` 진단 모드에 나오는 도구 수(21개)는 실제 등록 수(29개)와 다릅니다

### 7. 관리 대시보드 (n8n-admin)
[n8n-admin](https://github.com/team-datapopcorn/n8n-admin) 은 워크플로우·유저·크레덴셜을 웹 화면에서 관리하는 외부 도구입니다. 코드를 복사하지 않고 git 서브모듈(`services/n8n-admin/`)로 연결하므로, 이 리포지토리에는 원격 주소와 고정한 커밋만 기록됩니다.

1. **받기** (clone 직후 1회 — `git clone --recurse-submodules` 로 받았다면 생략)
   ```bash
   git submodule update --init
   ```
2. **의존성 설치** (Node.js 20 이상, pnpm 필요)
   ```bash
   cd services/n8n-admin/admin && pnpm install
   ```
3. **설정**: `cp services/n8n-admin/.env.example services/n8n-admin/.env` 후 아래 값을 채웁니다. 이 파일은 서브모듈 쪽 `.gitignore` 로 커밋에서 제외됩니다.

   | 변수 | 값 |
   |---|---|
   | `SERVER_URL` | `http://localhost:50990` (로컬 n8n 주소) |
   | `SERVER_API_KEY` | `services/n8n/.env` 의 `N8N_API_KEY` 와 같은 값 |
   | `ADMIN_PASSWORD` | 대시보드 로그인 비밀번호 |
   | `NEXTAUTH_SECRET` | `openssl rand -base64 32` 로 생성 |
   | `NEXTAUTH_URL` | `http://localhost:50999` — **대시보드 접속 주소이자 포트 설정** |
   | `SLACK_WEBHOOK_URL` | (선택) Slack 앱의 Incoming Webhook 주소. 자동 정리 결과·오류 알림용 |
4. **실행**: `bin/n8n-admin.sh start` → [http://localhost:50999](http://localhost:50999)

- 포트를 바꾸려면 `NEXTAUTH_URL` 의 포트만 고칩니다. `bin/n8n-admin.sh` 가 이 주소에서 포트를 읽어 서버를 띄웁니다 (`bin/n8n-admin.sh port` 로 확인).
  `NEXTAUTH_URL` 자체는 허용 주소만 정하고 서버 포트는 바꾸지 못하므로, `pnpm dev` 를 직접 실행하면 3000번에 뜨고 모든 요청이 404 가 됩니다.
- 대시보드는 `NEXTAUTH_URL` 과 다른 주소로 온 요청을 막습니다. `http://127.0.0.1:50999` 로 열면 404 이므로 `localhost` 로 접속합니다.
- `bin/n8n-admin.sh` 가 `services/n8n-admin/.env` 를 읽어 환경변수로 넘기므로 `admin/.env.local` 은 만들지 않습니다.
- 업데이트 확인·반영:
  ```bash
  git -C services/n8n-admin fetch
  git -C services/n8n-admin log --oneline HEAD..origin/main   # 새 커밋 확인
  git submodule update --remote services/n8n-admin            # 최신으로 올리기
  git add services/n8n-admin                                  # 올린 버전을 이 리포지토리에 기록
  ```
- 서브모듈 안의 파일은 수정하지 않습니다 (원본과 달라지면 업데이트 때 충돌).

---

## 💡 한글 관련 실무 팁 (가이드 핵심 내용)

[참조](#-참조)의 EddyGlen n8n 한글 설정 가이드에서 실무에 필요한 내용만 정리했습니다.

### 1. UI 언어와 시스템 설정의 차이
- n8n 공식 웹 UI는 기본적으로 영문으로 제공됩니다.
- 가이드에서 다루는 "한글 설정"은 **시간(타임존)과 데이터 문자열(인코딩)이 깨지지 않도록 시스템 환경을 한국어화**하는 것입니다.
- UI 자체를 한글로 보고 싶으신 경우, 크롬/웨일/엣지 브라우저의 **'한국어로 번역'** 기능을 활용하는 것이 가장 간편하고 호환성이 좋습니다.
- 2026-10 기준 관리되는 한국어 UI 번역 커뮤니티 프로젝트는 없습니다 (n8n 본 저장소의 한국어 번역 PR #14552·#14626·#17018 은 모두 미병합 종료, 마지막 번역은 2.44.7 UI 문구의 약 32% 만 커버).

### 2. 외부 API에서 EUC-KR / CP949 응답 처리
국내 레거시 기관이나 ERP에서 EUC-KR로 응답을 주는 경우, **HTTP Request** 노드에서 응답을 `Binary`로 수신한 뒤 **Code** 노드에서 아래와 같이 변환할 수 있습니다:

```javascript
// Code 노드 (Run Once for Each Item)
const binaryData = $input.item.binary.data;
const buffer = Buffer.from(binaryData.data, 'base64');
const decoder = new TextDecoder('euc-kr');
const decodedText = decoder.decode(buffer);

return {
  json: {
    text: decodedText
  }
};
```

### 3. 한국식 날짜 포맷팅 (Date & Time 노드 또는 Code 노드)
슬랙, 카카오톡 알림 전송 시 한국식 표기:
```javascript
const now = $now.setZone('Asia/Seoul');
const formatted = now.toFormat('yyyy년 MM월 dd일 HH:mm');
```

---

## 📚 참조

| 자료 | 내용 |
|---|---|
| [EddyGlen n8n 한글 설정 가이드](https://eddyglen.com/n8n-korean-language-setup/) | 한국 표준시(KST)·UTF-8 한글 문자 인코딩 설정의 기준. '💡 한글 관련 실무 팁'의 출처 |
| [n8n](https://github.com/n8n-io/n8n) · [문서](https://docs.n8n.io) · [릴리스](https://github.com/n8n-io/n8n/releases) | 워크플로우 엔진. stable 릴리스 버전으로 고정 |
| [n8n v3.0 breaking changes](https://docs.n8n.io/changelog/v30-breaking-changes) | 3.0 업그레이드 전 확인 사항 (4장) |
| [postgres 공식 이미지](https://hub.docker.com/_/postgres) · [PostgreSQL 17 문서](https://www.postgresql.org/docs/17/) | n8n DB (5장) |
| [czlonkowski/n8n-mcp](https://github.com/czlonkowski/n8n-mcp) | Claude Code 용 n8n MCP 서버 (6장) |
| [czlonkowski/n8n-skills](https://github.com/czlonkowski/n8n-skills) | `n8n-mcp-skills` 플러그인 (6장) |
| [team-datapopcorn/n8n-admin](https://github.com/team-datapopcorn/n8n-admin) | 관리 대시보드, git 서브모듈 (7장) |

서비스별 설치 방법은 [docs/architecture.md](docs/architecture.md) '서비스별 출처와 설치'를 참고합니다.
