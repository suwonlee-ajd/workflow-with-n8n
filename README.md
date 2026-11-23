# n8n + claude code 환경 Docker 설정

![License](https://img.shields.io/github/license/suwonlee-ajd/workflow-with-n8n)
![Stars](https://img.shields.io/github/stars/suwonlee-ajd/workflow-with-n8n)
![Docker Compose](https://img.shields.io/badge/Docker%20Compose-required-2496ED?logo=docker&logoColor=white)
![n8n](https://img.shields.io/badge/n8n-2.44.7-EA4B71?logo=n8n&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17-4169E1?logo=postgresql&logoColor=white)
![Claude Code](https://img.shields.io/badge/Claude%20Code-n8n--mcp%202.103.1-D97757?logo=claude&logoColor=white)
![Node](https://img.shields.io/badge/node-%5E22.23%20%7C%20%5E24.22%20%7C%20%3E%3D26.12-brightgreen?logo=nodedotjs&logoColor=white)
![pnpm](https://img.shields.io/badge/pnpm-required%20%28n8n--admin%29-orange?logo=pnpm&logoColor=white)

Docker Compose로 n8n과 PostgreSQL을 띄우고, Claude Code가 n8n-mcp로 워크플로우를 만들고 운영하는 프로젝트입니다.

---

## 📁 디렉터리 구조

```text
root
├── .claude/                         # Claude Code 규칙·스킬·설정
├── bin/                             # 실행 스크립트
│   ├── n8n.sh                       
│   └── n8n-admin.sh                 
├── services/
│   ├── n8n                          # n8n (docker 배포 이미지 사용)
│   │   ├── .env                     # 환경변수 — 비밀값 포함.
│   │   ├── .env.example             # .env 템플릿 — 복사 후 ★ 항목 입력
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

---

## 📌 주요 설정 포인트 요약

> 설정은 모두 `services/n8n/.env` 에서 합니다. n8n 컨테이너는 `env_file` 로 이 파일을 그대로 읽습니다.
> compose `${VAR}` 보간은 compose 가 직접 알아야 하는 값(이미지 태그·빌드 인자, 포트, DB 접속 정보, 백업 폴더)에만 씁니다. 호스트 셸의 `LANG`·`TZ` 가 `.env` 를 덮어쓰지 않도록 하기 위해서입니다.

0. **버전 고정 (`N8N_VERSION=2.44.7`, `N8N_NODE_VERSION=26.13.1`)**
   - stable 버전으로 고정: 컨테이너를 다시 만들 때 의도치 않은 업그레이드·DB 마이그레이션 방지 ([n8n releases](https://github.com/n8n-io/n8n/releases))
   - n8n 은 Node.js 만 교체한 로컬 이미지 `n8n-local:<N8N_VERSION>-node<N8N_NODE_VERSION>` 로 실행. 이유·되돌릴 조건은 `services/n8n/Dockerfile` 맨 위 주석
1. **타임존 (Asia/Seoul)**
   - `GENERIC_TIMEZONE`: n8n 스케줄 트리거·날짜 함수의 기본 시간대
   - `TZ`: 컨테이너 OS·로그 시간
2. **로케일·인코딩 (UTF-8)**
   - `LANG`·`LC_ALL=ko_KR.UTF-8`: 한글 파일명·텍스트 깨짐 방지
   - `N8N_DEFAULT_LOCALE=ko`: 공식 이미지에 한국어 번역이 없어 UI 는 영어로 표시
3. **데이터 영속성 (Docker 볼륨, 재시작·업그레이드해도 보존)**
   - `n8n_postgres_data`: 워크플로우·크레덴셜·실행 이력·사용자
   - `n8n_data`(`/home/node/.n8n`): 암호화 키(`config`)·커뮤니티 노드
4. **Code 노드 내장 모듈 허용 (`NODE_FUNCTION_ALLOW_BUILTIN=*`)**
   - Code 노드에서 `require('fs')` 같은 Node.js 내장 모듈을 쓸 수 있게 함. 백업 워크플로우가 `fs`·`child_process` 사용
   - `Buffer`·`TextDecoder` 는 이 설정 없이도 사용 가능. 외부 API 의 EUC-KR 응답 변환은 '💡 한글 관련 실무 팁' 2번
5. **백업 경로 (`BACKUP_DIR`)**
   - 비우면 `data/backups`, 다른 위치는 절대 경로
   - `bin/n8n.sh backup` 과 백업 워크플로우(매일 18:00)가 같은 경로에 저장. 자세한 내용은 [docs/architecture.md](docs/architecture.md) '데이터가 저장되는 곳'

---

## 🚀 빠른 시작

### 1. 접속 정보
- **URL**: [http://localhost:5678](http://localhost:5678) — 포트는 `.env` 의 `N8N_PORT` (바꾸면 `N8N_WEBHOOK_URL` 도 수정 후 `bin/n8n.sh restart`)
- 처음 접속하면 관리자 계정을 만듭니다.

### 2. 관리 명령어 (`bin/n8n.sh`)
어느 위치에서 실행해도 프로젝트 루트 기준으로 동작합니다.

```bash
bin/n8n.sh start     # 실행 (백그라운드)
bin/n8n.sh stop      # 중지. 컨테이너를 지우기 전에 로그를 logs/ 에 기록
bin/n8n.sh restart   # 이미지 빌드 → 컨테이너 재생성 (.env 반영). 빌드가 실패하면 기존 컨테이너 유지
bin/n8n.sh logs      # 실시간 로그
bin/n8n.sh status    # 컨테이너 상태
bin/n8n.sh backup    # 볼륨·DB 덤프·워크플로우 JSON → <BACKUP_DIR>/<YYYYMMDDHHMM>/ (n8n 실행 중이어야 함)
bin/n8n.sh export    # 워크플로우 → services/n8n/workflows/*.json (3장)
bin/n8n.sh import    # services/n8n/workflows/*.json → n8n (3장)
```

- compose 를 직접 쓸 때: `docker compose -f services/n8n/docker-compose.yml up -d` (같은 폴더의 `.env` 를 자동으로 읽음)
- 컨테이너 로그: Docker 에는 컨테이너당 10MB×5개까지 남고, 컨테이너를 지우면 사라집니다. 그래서 `stop`·`restart` 가 지우기 직전에 `logs/` 로 기록합니다. `docker compose down` 을 직접 실행하면 기록 없이 사라집니다. 자세한 내용: [docs/logging.md](docs/logging.md)

### 3. 워크플로우 형상관리 (export / import)
워크플로우는 DB 에 저장되므로, git 으로 이력을 남기려면 JSON 으로 내보냅니다. 두 명령 모두 n8n 이 실행 중이어야 합니다.

| 명령 | 동작 |
|---|---|
| `bin/n8n.sh export` | 워크플로우마다 `services/n8n/workflows/<ID>.json` 으로 저장. 폴더의 기존 JSON 을 비우고 통째로 교체 |
| `bin/n8n.sh import` | 폴더의 JSON 을 **전부** 가져옴. 같은 ID 는 덮어씀. 가져온 워크플로우는 **모두 비활성**이 되어 다시 게시해야 함 |

- 파일 하나만 가져올 때 (백업한 JSON 하나를 되돌릴 때도 사용):
  ```bash
  docker cp <파일>.json n8n:/tmp/wf.json && docker exec n8n n8n import:workflow --input=/tmp/wf.json
  ```
- 커밋 전에 지울 것: 노드 파라미터의 토큰·URL, `pinData`(고정 테스트 데이터), `shared`(계정 이메일). 크레덴셜 값은 JSON 에 없어 다른 n8n 으로 옮기면 다시 연결해야 함
- 현재 저장소에는 내보낸 JSON 이 없습니다. 워크플로우는 `bin/n8n.sh backup` 과 백업 워크플로우(매일 18:00)로 보존합니다. 저장 위치와 내용은 [docs/architecture.md](docs/architecture.md) '데이터가 저장되는 곳'

### 4. 버전 업그레이드
1. `bin/n8n.sh backup`
2. `.env` 의 `N8N_VERSION` 을 새 stable 버전으로 변경. `.env.example`, README 뱃지·버전 표기, `docs/architecture.md` 서비스 표도 함께
3. `bin/n8n.sh restart`: 새 공식 이미지를 받아 로컬 이미지를 빌드한 뒤 재시작 (빌드가 실패하면 기존 컨테이너 유지)

> **공식 이미지로 되돌리기**: 3단계 빌드가 ❌ 로 멈추면 메시지를 따릅니다. 공식 이미지의 Node 가 이미 보안 권고의 해결 버전이면 아래를 고치고 다시 `bin/n8n.sh restart` 합니다.
> - 지움: `services/n8n/Dockerfile`·`.dockerignore`, `.env`·`.env.example` 의 `N8N_NODE_VERSION`
> - compose: n8n `image:` 를 `docker.n8n.io/n8nio/n8n:${N8N_VERSION:?set N8N_VERSION in .env}` 로 바꾸고 `pull_policy`·`build` 삭제
> - 문서·주석: `git grep -n -E 'N8N_NODE_VERSION|Dockerfile|n8n-local|빌드'` 로 찾은 곳. 남은 이미지는 `docker images n8n-local` 로 확인 후 삭제

> **n8n 3.0 주의** (stable 2026-12 초 예정): 레거시 노드 삭제·암호화 키 로테이션 등 호환이 깨지는 변경이 있습니다. 올리기 전에 **Settings > Migration Report** 를 확인하고 백업합니다. 참고: [v3.0 breaking changes](https://docs.n8n.io/changelog/v30-breaking-changes)

### 5. DB (PostgreSQL) 설정
n8n DB 는 함께 뜨는 `postgres` 컨테이너(PostgreSQL 17)입니다. 설정은 `services/n8n/.env` 의 아래 값입니다.

| 변수 | 용도 |
|---|---|
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | postgres 계정·비밀번호·DB 이름. n8n 도 같은 값으로 접속 |
| `N8N_ENCRYPTION_KEY` | 크레덴셜 암호화 키. `n8n_data` 볼륨의 `config` 와 다르면 n8n 이 시작되지 않음 |

- 비밀번호·암호화 키 생성: `openssl rand -hex 16`
- `POSTGRES_*` 는 DB 볼륨이 비어 있는 최초 기동 때만 적용. 나중에 비밀번호를 바꾸려면 DB 에서도 변경
  (`docker exec -it n8n-postgres psql -U n8n -c "ALTER USER n8n PASSWORD '<새 비밀번호>'"` → `.env` 수정 → `bin/n8n.sh restart`)
- 접속: `docker exec -it n8n-postgres psql -U n8n -d n8n` (호스트 포트 없음)
- 덤프 복원: `gunzip -c data/backups/<YYYYMMDDHHMM>/n8n-postgres/n8n_db_<시각>.sql.gz | docker exec -i n8n-postgres psql -U n8n -d n8n`

### 6. Claude Code 연동 (n8n-mcp)
Claude Code 가 [n8n-mcp](https://github.com/czlonkowski/n8n-mcp) 로 로컬 n8n 의 워크플로우를 만들고 조회·검증합니다. 서버는 `services/n8n-mcp/` 에 설치하고 `.mcp.json` 으로 등록합니다.

1. **설치** (clone 직후 1회): `cd services/n8n-mcp && npm ci`
   - 버전은 `package.json` 에 고정. 올릴 때: 버전 변경 → `npm install` → README 뱃지(n8n-mcp, Node `engines`) 수정 → Claude Code 세션 새로 시작
   - 호스트 Node 는 `engines` 범위 안에서 보안 권고의 해결 버전 이상 (2026-11 기준 22.23.5·24.22.3·26.13.1, 근거는 `services/n8n/Dockerfile` 주석)
2. **API 키**: n8n **Settings > n8n API** 에서 만들어 `.env` 의 `N8N_API_KEY` 에 넣습니다. `.mcp.json` 은 실행할 때 이 값을 읽으므로 비밀값이 없습니다.
3. **연결 확인**: Claude Code 를 새로 열고 `n8n-mcp` 사용을 승인한 뒤 `/mcp` 로 확인합니다 (`.mcp.json` 은 세션 시작 때만 읽힘).

`.mcp.json` 의 `env`:

| 변수 | 값 | 이유 |
|---|---|---|
| `N8N_API_URL` | `http://localhost:5678` | 로컬 n8n 주소. `N8N_PORT` 를 바꾸면 함께 수정 |
| `WEBHOOK_SECURITY_MODE` | `moderate` | 로컬 웹훅·폼 테스트 허용 (기본값 `strict` 는 localhost 차단). 사설 IP·메타데이터 주소는 계속 차단 |
| `N8N_MCP_TELEMETRY_DISABLED` | `true` | 사용 통계 전송 끔 |

- `N8N_MCP_ACCESS_TOKEN`(Instance-level MCP 키)은 설정하지 않아 🔒 도구를 쓸 수 없습니다. 같은 이유로 `n8n_test_workflow` 는 webhook·form·chat 트리거 워크플로우를 활성화한 뒤 호출하는 방식만 되고, 버전 이력은 n8n-mcp 스냅샷만, 데이터 테이블 컬럼은 바꿀 수 없습니다.
- `.claude/settings.json` 은 `n8n-mcp-skills` 플러그인을 켭니다. n8n 작업 규칙: [.claude/rules/n8n/common.md](.claude/rules/n8n/common.md)

#### n8n-mcp 도구 (2.103.1 기준 29개)

| 그룹 | 도구 |
|---|---|
| 워크플로우 생명주기 (11) | `n8n_health_check` ✅, `n8n_list_workflows` ✅, `n8n_get_workflow` ✅, `n8n_create_workflow` ✅, `n8n_update_partial_workflow` ✅, `n8n_update_full_workflow`, `n8n_delete_workflow`, `n8n_workflow_versions`, `n8n_manage_folders`, `n8n_list_catalog` ✅, `n8n_manage_agents` 🔒 |
| 검증 및 테스트 (7) | `validate_workflow` ✅, `n8n_validate_workflow` ✅, `validate_node` ✅, `n8n_autofix_workflow`, `n8n_test_workflow`, `n8n_evaluations`, `n8n_audit_instance` ✅ |
| 실행 및 데이터 (4) | `n8n_executions`, `n8n_manage_datatable`, `n8n_manage_credentials`, `n8n_manage_variables` |
| 노드 및 템플릿 (6) | `search_nodes` ✅, `get_node` ✅, `search_templates` ✅, `get_template` ✅, `n8n_deploy_template`, `n8n_explore_node_resources` 🔒 |
| 참조 (1) | `tools_documentation` ✅ |

- ✅ 확인 없이 실행: 개인 설정 `.claude/settings.local.json`(커밋 안 함)의 `permissions.allow` 에 `mcp__n8n-mcp__<도구 이름>` 으로 등록한 도구. 읽기 전용 도구와 `n8n_create_workflow`·`n8n_update_partial_workflow` 만 등록
- 표시 없음: 실행할 때마다 확인. 삭제·전체 교체·실제 실행 도구는 allow 에 넣지 않음
- 🔒 `N8N_MCP_ACCESS_TOKEN` 필요 (현재 사용 불가)
- `n8n_manage_variables` 는 n8n 유료 라이선스 전용 (Community 에디션 불가)

### 7. 관리 대시보드 (n8n-admin)
[n8n-admin](https://github.com/team-datapopcorn/n8n-admin) 은 워크플로우·유저·크레덴셜을 웹 화면에서 관리하는 외부 도구입니다. git 서브모듈(`services/n8n-admin/`)로 연결해 이 저장소에는 원격 주소와 커밋만 기록합니다.

1. **받기**: `git submodule update --init` (`git clone --recurse-submodules` 로 받았으면 생략)
2. **의존성 설치** (Node.js 20 이상, pnpm): `cd services/n8n-admin/admin && pnpm install`
3. **설정**: `cp services/n8n-admin/.env.example services/n8n-admin/.env` 후 아래 값 입력 (서브모듈 `.gitignore` 로 커밋 제외)

   | 변수 | 값 |
   |---|---|
   | `SERVER_URL` | `http://localhost:5678` (로컬 n8n 주소) |
   | `SERVER_API_KEY` | `services/n8n/.env` 의 `N8N_API_KEY` 와 같은 값 |
   | `ADMIN_PASSWORD` | 대시보드 로그인 비밀번호 |
   | `NEXTAUTH_SECRET` | `openssl rand -base64 32` 로 생성 |
   | `NEXTAUTH_URL` | `http://localhost:3000` — **대시보드 접속 주소이자 포트 설정** |
   | `SLACK_WEBHOOK_URL` | (선택) 자동 정리 결과·오류 알림용 Incoming Webhook 주소 |
4. **실행**: `bin/n8n-admin.sh start` → [http://localhost:3000](http://localhost:3000)

- 포트는 `NEXTAUTH_URL` 의 포트만 고칩니다. `bin/n8n-admin.sh` 가 여기서 포트를 읽어 띄웁니다 (`pnpm dev` 를 직접 실행하면 3000번에 떠서 모든 요청이 404).
- `localhost` 로 접속합니다. `NEXTAUTH_URL` 과 다른 주소(`127.0.0.1` 등)는 404 입니다.
- `admin/.env.local` 은 만들지 않습니다. `bin/n8n-admin.sh` 가 `services/n8n-admin/.env` 를 넘깁니다.
- 업데이트 확인·반영:
  ```bash
  git -C services/n8n-admin fetch
  git -C services/n8n-admin log --oneline HEAD..origin/main   # 새 커밋 확인
  git submodule update --remote services/n8n-admin            # 최신으로 올리기
  git add services/n8n-admin                                  # 올린 버전을 이 리포지토리에 기록
  ```
- 서브모듈 안의 파일은 수정하지 않습니다 (업데이트 때 충돌).

---

## 💡 한글 관련 실무 팁

[참조](#-참조)의 EddyGlen n8n 한글 설정 가이드에서 실무에 필요한 것만 정리했습니다.

### 1. UI 언어
- n8n UI 는 영어만 제공됩니다. 한국어 번역은 n8n 본 저장소에 병합되지 않았습니다 (2026-10 기준). 필요하면 브라우저의 '한국어로 번역'을 씁니다.
- 가이드의 '한글 설정'은 UI 가 아니라 시간·인코딩 설정입니다 (주요 설정 1·2번).

### 2. 외부 API의 EUC-KR / CP949 응답 변환
국내 레거시 기관·ERP 가 EUC-KR 로 응답하면, **HTTP Request** 노드에서 `Binary` 로 받은 뒤 **Code** 노드에서 변환합니다.
별도 설정은 필요 없습니다 (`Buffer`·`TextDecoder` 는 Code 노드에 기본으로 있고, n8n 컨테이너의 Node.js 가 EUC-KR 을 지원).

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

### 3. 한국식 날짜 표기 (Date & Time 노드 또는 Code 노드)
알림 메시지의 한국식 날짜 표기:
```javascript
const now = $now.setZone('Asia/Seoul');
const formatted = now.toFormat('yyyy년 MM월 dd일 HH:mm');
```

---

## 📚 참조

본 리포지토리는 인프런 강의 [Claude Code로 만드는 n8n 자동화 실전](https://www.inflearn.com/course/practical-n8n-automa)을 듣고 실습한 내용을 바탕으로 작성한 것입니다.

<a href="https://www.inflearn.com/course/practical-n8n-automa"><img src="https://cdn.inflearn.com/public/files/courses/341282/cover/01kpmbfazrpptyqghx5b3cmb1g.gif" alt="인프런 강의 「Claude Code로 만드는 n8n 자동화 실전」" width="400"></a>

| 자료 | 내용 |
|---|---|
| [EddyGlen n8n 한글 설정 가이드](https://eddyglen.com/n8n-korean-language-setup/) | 한국 표준시(KST)·UTF-8 한글 문자 인코딩 설정의 기준. '💡 한글 관련 실무 팁'의 출처 |
| [n8n](https://github.com/n8n-io/n8n) · [문서](https://docs.n8n.io) · [릴리스](https://github.com/n8n-io/n8n/releases) | 워크플로우 엔진. stable 릴리스 버전으로 고정 |
| [n8n v3.0 breaking changes](https://docs.n8n.io/changelog/v30-breaking-changes) | 3.0 업그레이드 전 확인 사항 (4장) |
| [node 공식 이미지](https://hub.docker.com/_/node) · [ASEC Node.js 보안 업데이트 권고](https://asec.ahnlab.com/ko/96589/) | n8n 이미지에 넣는 Node.js 와 교체 이유 (주요 설정 0번) |
| [postgres 공식 이미지](https://hub.docker.com/_/postgres) · [PostgreSQL 17 문서](https://www.postgresql.org/docs/17/) | n8n DB (5장) |
| [czlonkowski/n8n-mcp](https://github.com/czlonkowski/n8n-mcp) | Claude Code 용 n8n MCP 서버 (6장) |
| [czlonkowski/n8n-skills](https://github.com/czlonkowski/n8n-skills) | `n8n-mcp-skills` 플러그인 (6장) |
| [team-datapopcorn/n8n-admin](https://github.com/team-datapopcorn/n8n-admin) | 관리 대시보드, git 서브모듈 (7장) |

서비스별 설치 방법은 [docs/architecture.md](docs/architecture.md) '서비스별 출처와 설치'를 참고합니다.

---

## 📄 라이선스

[MIT](LICENSE). 단, 아래는 MIT 적용 대상이 아닙니다.

- 이전 커밋의 로고 이미지(`assets/ajd-logo.png`, `assets/ajd-auto-logo.png`): 아정당 로고를 포함한 이미지. 지금은 저장소에서 삭제됨
- 함께 쓰는 n8n·n8n-mcp·n8n-admin 등: 각 프로젝트의 라이선스를 따름 ([참조](#-참조))
