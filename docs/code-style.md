# 코드 스타일

| 항목 | 값 |
| --- | --- |
| 문서 버전 | 0.10.1 |
| 최종 수정 | 2026-11-19 |

이 저장소의 스크립트, 설정 파일, 문서, n8n 워크플로우, PR 메시지·버전 태그를 쓸 때 따르는 규칙이다. 현재 코드에서 실제로 쓰는 방식을 정리한 초안이며, 결정을 미룬 것은 마지막 '보류'에 모았다.

- 기준: 저장소 파일과 n8n 워크플로우(2026-11-18 백업, 예제 제외 12개)
- 제외: `services/n8n-admin` (외부 리포지토리라 원본 스타일을 따름)
- 다른 문서에 있는 규칙은 다시 쓰지 않고 링크만 함
  - 커밋·브랜치: [CLAUDE.md](../CLAUDE.md) 'Git Flow, Commit 규칙'
  - 워크플로우 이름·캔버스 그룹: [workflow-builder.md](../.claude/skills/n8n/references/workflow-builder.md) '네이밍 컨벤션'

## 1. 공통

| 항목 | 규칙 |
|------|------|
| 인코딩 | UTF-8, LF, 파일 끝 줄바꿈 1개 |
| 들여쓰기 | 스페이스 2칸 (Bash, YAML, JSON, JavaScript) |
| 언어 | 주석·출력 메시지·문서는 한국어. 변수·함수·파일 이름과 명령어·기술 용어는 영어 원어 |
| 파일 이름 | 영문 소문자, 단어는 하이픈으로 연결 (`n8n-admin.sh`, `code-style.md`) |
| 경로 | 프로젝트 루트 기준 상대 경로 (`services/n8n/.env`) |
| 비밀값 | `.env`(git 제외)에만 둠. 코드·문서·커밋·워크플로우 파라미터에는 쓰지 않음 |
| 버전 | 정확한 버전으로 고정 (`N8N_VERSION=2.44.7`, `"n8n-mcp": "2.103.1"`). `latest`, `^`, `~` 쓰지 않음 |

### 주석

모든 주석(Bash, YAML, `.env`, Code 노드 JavaScript)은 **두괄식**과 **명사형 종결**로 쓴다. 무엇보다 읽기 쉬운 것을 우선한다.

| 규칙 | 내용 |
|------|------|
| 두괄식 | 첫머리에 무엇을 하는지. 이유·조건·예외는 뒤에 |
| 명사형 종결 | `…함`, `…음`, `…따름`, `…하도록` 이나 명사로 끝냄. `…한다`, `…합니다` 쓰지 않음 |
| 한 줄에 한 내용 | 내용이 둘 이상이면 줄을 나누고 `- ` 목록으로 |
| 이유 위주 | 코드에 보이는 동작은 되풀이하지 않음. 코드만 봐서는 모르는 이유·조건·제약을 씀 |
| 괄호 최소 | 보충 설명 괄호는 한 줄에 하나까지 |

| 쓰지 않음 | 씀 |
|-----------|----|
| `# 경로를 잡는다` | `# 경로를 잡음` |
| `# 로그를 파일로 기록합니다` | `# 로그를 파일로 기록` |
| `// 결과를 화면 순서대로 정렬한다.` | `// 결과를 화면 순서대로 정렬` |

주석 위치:
- 파일 맨 위: `# ====` 블록에 제목, 그 아래에 사용법
- 함수·블록 위: 첫 줄에 한 줄 요약, 세부는 아래 `- ` 목록
- 줄끝 주석: 값의 형식·단위·경로 규칙만. 같은 블록 안에서는 `#` 위치를 맞춤

예: `bin/n8n.sh` 의 `save_logs` 주석

고치기 전 (한 줄에 여러 내용, 괄호가 겹침):

```bash
# 컨테이너 로그(Docker 가 보관)를 파일로 기록: logs/<YYYY>/<YYYY.MM>/<서비스명>.<YYYY-MM-DD>.log (날짜는 기록한 날)
# 컨테이너를 지우면(compose down) Docker 로그도 함께 사라지므로 stop·restart 가 지우기 전에 호출
# (종료 과정의 로그까지 담기도록 compose stop 뒤에 호출). 실패해도 중지·재시작은 계속 진행
```

고친 후:

```bash
# 컨테이너 로그를 파일로 기록
# - 위치: logs/<YYYY>/<YYYY.MM>/<서비스명>.<YYYY-MM-DD>.log (날짜는 기록한 날)
# - compose stop 뒤에 호출: 종료 과정의 로그까지 담도록
# - compose down 앞에 호출: down 하면 Docker 로그도 함께 삭제
# - 실패해도 중지·재시작은 계속 진행
```

## 2. Bash 스크립트 (`bin/`)

스크립트 하나가 서비스 하나를 맡는다 (`bin/<서비스명>.sh`). 기본 골격:

```bash
#!/bin/bash

# ==========================================
# <서비스> 관리 스크립트
# ==========================================

set -e
set -o pipefail                   # 파이프 중간 명령이 실패해도 멈추도록

# 프로젝트 루트 (bin/ 의 상위) 기준으로 경로를 잡음
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
cd "$ROOT"

ENV_FILE="services/<서비스>/.env"

case "$1" in
  start)
    echo "🚀 <서비스>를 시작합니다..."
    # ...
    echo "✅ <서비스>가 실행되었습니다."
    ;;
  *)
    echo "사용법: bin/<서비스>.sh {start|...}"
    exit 1
    ;;
esac
```

### 이름과 구조

- 전역 상수는 대문자 스네이크 (`ENV_FILE`, `BACKUP_DIR`), 함수와 지역 변수는 소문자 스네이크 (`backup_dir`, `save_logs`)
- 함수 안 변수는 `local` 로 선언
- 함수 위에 하는 일을 주석으로 씀. 값을 출력하는 함수는 사용 예도 씀
  - 예: `# 사용: dir="$(backup_dir <서비스명> <YYYYMMDD_HHMMSS>)"`
- 같은 옵션을 매번 붙이는 명령은 함수로 감쌈 (`compose()` 가 `--env-file`·`-f` 를 항상 붙임)
- 첫 인자는 하위 명령(`case "$1"`), 나머지 인자는 `"${@:2}"` 로 그대로 넘김
- 하위 명령을 추가하거나 바꾸면 사용법 문구와 [README](../README.md) '2. 관리 명령어'도 함께 고침

### 작성 방식

- 변수는 항상 큰따옴표로 감싸고, 명령 치환은 `$(...)` 사용
- `.env` 읽기
  - 값 하나만 필요할 때: `sed -n 's/^KEY=//p' "$ENV_FILE"` (셸에 불러오지 않음)
  - 하위 프로세스에 전부 넘겨야 할 때만: `set -a; source "$ENV_FILE"; set +a`
- 실패 처리
  - 기본은 `set -e` 로 중단
  - 실패해도 계속할 단계는 `|| continue` 나 `if … else` 로 드러내고, ⚠️ 메시지에 "계속 진행합니다" 표시
  - 사전 조건이 안 맞으면 ❌ 메시지에 다음에 실행할 명령을 넣고 `exit 1`
    - 예: `❌ services/n8n-admin/.env 가 없습니다. 먼저 실행: cp … 후 값 입력`
- 오래 실행되는 전경 프로세스는 `exec` 로 넘김 (`exec pnpm dev`)
- 컨테이너 안 임시 경로는 쓰기 전에 비움 (`compose exec -T -u root n8n rm -rf "$WORKFLOW_TMP"`)

### 출력 메시지

메시지는 `…합니다` 체로 쓰고, 맨 앞에 상태 이모지를 붙인다. 진행 중 메시지는 `...` 로 끝내고, 완료 메시지에는 결과 경로나 개수를 넣는다.

| 이모지 | 쓰임 |
|--------|------|
| 🚀 🛑 🔄 | 시작, 중지, 재시작 |
| 📦 📤 📥 | 백업, 내보내기, 가져오기 |
| 📝 | 파일 기록 |
| ✅ | 완료 |
| ⚠️ | 실패했지만 계속 진행 |
| ❌ | 실패, 종료 |

### 날짜와 파일 위치

| 용도 | 형식 |
|------|------|
| 실행 시각 스탬프 | `%Y%m%d_%H%M%S` (예: `20261118_151900`) |
| 백업 폴더 일시 | `%Y%m%d%H%M`, 실행 시각 스탬프의 앞 12자리 (예: `202611181519`) |
| 백업 | `<BACKUP_DIR>/<YYYYMMDDHHMM>/<서비스명>/` (`BACKUP_DIR` 기본값 `data/backups`) |
| 백업 워크플로우 | `<BACKUP_DIR>/<YYYYMMDDHHMM>/n8n/` 에 `n8n_backup_<YYYYMMDD_HHMMSS>.tar.gz`, `n8n_workflows_<YYYYMMDD_HHMMSS>/<워크플로우 ID>.json`, `n8n_{executions,datatables}_<YYYYMMDD_HHMMSS>.json` |
| 로그 | `logs/<YYYY>/<YYYY.MM>/<서비스명>.<YYYY-MM-DD>.log` |

서비스명은 컨테이너 이름(`n8n`, `n8n-postgres`)을 쓴다.

## 3. Docker Compose (`services/*/docker-compose.yml`)

- 이미지 태그는 `.env` 변수로 고정. 필수 변수는 `${VAR:?set VAR in .env}` 로 써서 비어 있으면 시작 거부
- 공식 이미지를 고쳐 써야 할 때만 `build`. 이미지 이름은 공식 이미지와 구분되는 로컬 이름, `pull_policy: never` 로 레지스트리에서 받지 않음 (예: `services/n8n/Dockerfile`)
- `container_name` 은 서비스 이름으로 고정. 스크립트가 이 이름(`n8n`, `n8n-postgres`)을 사용
- 모든 서비스에 `restart: unless-stopped` 와 `logging: *default-logging`. 로그 설정은 `x-logging` 앵커 하나로 공유
- 앱 설정은 `env_file: .env` 로 넘김
  - `${VAR}` 보간은 compose 가 직접 알아야 하는 값에만: 이미지 태그·빌드 인자, 포트, 컨테이너끼리 공유하는 DB 접속 정보, 백업 폴더 연결
  - 이유: 호스트 셸의 `LANG`·`TZ` 같은 값이 `.env` 를 덮어쓰지 않도록
- 컨테이너 안에서 확장할 변수는 `$$` 로 표기 (`pg_isready -U $${POSTGRES_USER}`)
- 볼륨 이름은 `name:` 으로 고정
- 다른 서비스에 의존하면 상대 서비스에 `healthcheck` 를 두고 `depends_on.condition: service_healthy` 로 대기
- DB 포트는 호스트에 열지 않음
- 키마다 위에 이유를 주석으로 씀 (버전 근거, 적용 시점 등)

## 4. 환경 변수 템플릿 (`.env.example`)

- `.env` 와 키 구성을 같게 유지. 키를 추가하거나 바꾸면 두 파일과 README 를 함께 고침
- 맨 위 블록: 용도, 사용 순서, 표기 규칙(`★` = 직접 입력할 비밀값)
- 구역: `# ====` 로 감싼 번호 제목 (`0. 기본 설정`, `1. n8n 설정`, `2. DB 설정`). 항목마다 위 줄에 `# 제목 — 요약` 설명
- 줄끝 주석은 compose 만 읽는 키에만 (`GENERIC_TIMEZONE`, `TZ`)
  - `bin/n8n.sh`·`.mcp.json` 이 직접 읽는 키(`N8N_PORT`, `BACKUP_DIR`, `N8N_API_KEY`)에는 쓰지 않음: 주석까지 값으로 읽힘
- 비밀값은 빈 값으로 두고 `★` 와 생성 방법 표시 (`openssl rand -hex 16`)
- 값은 따옴표 없이. 키 이름은 n8n·PostgreSQL 이 정한 이름 그대로

## 5. JSON 설정 (`.mcp.json`, `.claude/settings.json`, `package.json`)

- JSON 에는 주석을 쓸 수 없으므로 설명은 README 나 `package.json` 의 `description` 에 씀
- 비밀값을 넣지 않음. `.mcp.json` 은 실행할 때 `services/n8n/.env` 에서 `N8N_API_KEY` 를 읽어 넘김
- 의존성은 정확한 버전으로 적고 `package-lock.json` 을 커밋. 설치는 `npm ci`
- 개인 설정(도구 권한 허용 등)은 `.claude/settings.local.json`(git 제외)에 둠. `.claude/settings.json` 에는 함께 쓸 설정만

## 6. 문서 (`README.md`, `docs/`, `.claude/`)

### 문서 머리 (`docs/`)

`docs/` 아래 md 문서는 아래 틀로 시작한다. `README.md`, `CLAUDE.md`, `CHANGELOG.md`, `.claude/` 아래 문서에는 버전 표를 넣지 않는다.

```markdown
# {문서 제목}

| 항목 | 값 |
| --- | --- |
| 문서 버전 | {작성 당시 태그 버전, 예: 0.7.0} |
| 최종 수정 | {YYYY-MM-DD} |

{이 문서가 다루는 범위 한두 문장}

## {장 제목}
```

- 순서: `#` 제목 → 버전 표 → 범위 문장 → 본문
- 문서 버전: 문서를 쓰거나 고칠 때 이미 붙어 있는 최신 프로젝트 태그(8장 '버전 태그')를 `v` 없이 적음
  - 확인: `git describe --tags --abbrev=0` (예: `v0.7.0` → `0.7.0`)
  - 버전업 준비 PR 에서는 `docs/` 문서 전체의 문서 버전을 새 버전으로 함께 올림
- 최종 수정: 내용을 바꾼 날짜 (KST). 문서 버전과 함께 고침

### frontmatter 가 필요한 파일

`SKILL.md` 는 첫 줄부터 YAML frontmatter 로 시작한다. Claude Code 가 첫 줄의 `---` 로 frontmatter 를 찾으므로, 그 앞에 빈 줄이나 제목 등 아무것도 두지 않는다.

- 필수 키
  - `name`: 스킬 폴더 이름과 같게. 영문 소문자, 단어는 하이픈으로 연결
  - `description`: 하는 일과 트리거할 요청 예시
- `#` 제목은 frontmatter 다음에 둠
- `references/` 아래 모듈 문서는 frontmatter 없이 일반 문서처럼 `#` 제목으로 시작
- 다른 md 에 frontmatter 를 쓸 때도 같은 규칙으로 맨 앞에 둠

```markdown
---
name: n8n
description: "n8n 워크플로우 자동화. … 다음 키워드에 트리거. 예: 'n8n', '워크플로우 만들어줘'."
---

# n8n 워크플로우 자동화 스킬

n8n-mcp-skills 등 n8n 도구를 활용하여 워크플로우를 생성하고, 운영하는 스킬.
```

### 문체와 형식

- `#` 제목은 파일마다 하나
- 문체
  - `docs/`·`.claude/`·`CLAUDE.md` 의 본문은 `…다` 체
  - README 의 본문은 `…습니다` 체
  - 표와 목록 항목은 명사형으로 짧게
- 비교와 목록은 표로. 구성도와 디렉터리 트리는 ```` ```text ````, 명령은 ```` ```bash ```` 블록
- 코드, 경로, 명령, 키, 노드 이름은 백틱으로 감쌈
- 다른 문서는 상대 경로로 링크. 같은 규칙을 두 곳에 쓰지 않고 원본 문서에 링크
- 버전에 따라 달라지는 내용에는 기준 버전 표시 (`n8n-mcp 2.103.1 기준`)
- 새 문서를 만들면 [CLAUDE.md](../CLAUDE.md) '개요' 표와 [README](../README.md) '디렉터리 구조'에 등록
- 예시에는 실제 비밀값이나 개인 정보 대신 가짜 값 사용 (`admin@co.kr`)

## 7. n8n 워크플로우

워크플로우 이름과 캔버스 그룹은 [workflow-builder.md](../.claude/skills/n8n/references/workflow-builder.md) '네이밍 컨벤션'을 따른다. 여기서는 노드와 설정을 다룬다.

### 노드 이름

| 노드 | 이름 | 예 |
|------|------|----|
| Schedule Trigger | 실행 주기·시각 | `매일 오전 9시`, `평일 오전 8시 10분`, `5분마다 확인` |
| Execute Workflow Trigger | 고정 | `다른 워크플로우에서 호출` |
| Manual Trigger (메인) | 고정 | `수동 실행` |
| Manual Trigger (서브, 호출 없이 직접 돌릴 때) | 고정 | `직접 실행` |
| Error Trigger | 고정 | `워크플로우 실패 시` |
| 트리거 다음 설정용 Set | 고정 | `실행 설정` |
| 조회 (HTTP Request, 서비스 노드) | `<대상> 조회` | `유가증권 시세 조회`, `환율 조회` |
| Split Out | `<대상> 펼치기` | `기사 펼치기` |
| 필드 정리용 Set | `<대상> 정리` | `웹사이트 정리` |
| Aggregate, Merge | `<대상> 합치기` | `뉴스 목록 합치기` |
| IF | `<조건> 확인` | `선정 종목이 있는지 확인`, `Slack으로 보낼지 확인` |
| Slack 전송 | `Slack <내용> 전송` | `Slack 실패 알림 전송` |
| 서브 워크플로우의 마지막 Set | 고정 | `결과 반환` |

### 설정값과 크리덴셜

- 실행마다 바꿀 수 있는 값(기간, 개수, 기준값)은 트리거 다음 `실행 설정` Set 노드에 모음. 뒤 노드는 `$('실행 설정').first().json.<키>` 로 읽음
- 인증은 크리덴셜로만 (`httpHeaderAuth`, `httpCustomAuth`, `slackApi`, `openAiApi`, `n8nApi`). 토큰을 URL 이나 헤더 파라미터에 직접 쓰지 않음
- 계정마다 다른 값(Slack 채널, 크리덴셜 선택)은 비워 두고 n8n 화면에서 고르도록 안내. `$env` 는 쓰지 않음

### 워크플로우 설정

| 설정 | 값 |
|------|----|
| `timezone` | `Asia/Seoul` |
| `executionOrder` | `v1` |
| `errorWorkflow` | `[에러] 공통: 실패 알림` (에러 워크플로우 자신은 제외) |
| `availableInMCP` | `true` |

### 노드 버전

- 노드 `typeVersion` 은 실행 중인 n8n(`N8N_VERSION`, 현재 2.44.7)이 지원하는 값으로 씀
  - 이유: n8n-mcp 가 더 새 버전을 알려 줄 수 있음
  - 예: Convert to File 은 2.44.7 에서 1.1 까지인데 1.2 로 만들자, 화면에서 저장할 때 설정이 비워져 CSV 로 바뀜
- 확인: 컨테이너 안 노드 정의의 `version`

```bash
# 예: Convert to File (2.44.7 기준 [1, 1.1])
docker exec n8n sh -c 'grep -o "version: \[[^]]*\]" $(find /usr/local/lib/node_modules/n8n -path "*n8n-nodes-base/dist/nodes/Files/ConvertToFile/ConvertToFile.node.js" | head -1)'
```

### 외부 호출과 오류

- 외부 API·Slack·LLM 노드는 `retryOnFail` 을 켬. `maxTries`·`waitBetweenTries` 는 대상 서비스에 맞춰 노드마다 정함 (현재 2~3회, 1~5초)
- 일부 소스가 실패해도 결과를 보낼 수 있으면 `onError: continueRegularOutput`. 다음 노드에서 오류 필드를 확인해 `errors` 에 모으고 결과와 함께 넘김
- 더 진행할 수 없으면 멈춤. 오류 메시지에는 원인과 확인할 것을 한국어로 씀
  - 예: `throw new Error('최근 5거래일의 국내 시세가 없습니다. KRX 크리덴셜과 서비스 승인 상태를 확인하세요.')`

### Code 노드 (JavaScript)

- 기본 노드(Set, Filter, IF, Split Out, Aggregate, Merge 등)로 할 수 없을 때만 사용. `notes` 는 `Why Code:` 로 시작해 이유를 씀
- 모드는 `Run Once for All Items` (`runOnceForAllItems`)
- 형식
  - 작은따옴표와 세미콜론 사용
  - 변수는 `const` 가 기본, 다시 대입할 때만 `let`
  - 짧은 헬퍼는 화살표 함수, 이름 붙은 계산(예: `rsi`)은 `function`
- 맨 위 주석 한 줄로 노드가 하는 일을 씀. 주석 문체는 1장 '주석'을 따름
- 앞 노드 값은 `$('노드 이름').first().json` 이나 `.all()` 로 읽음
- 입력은 비어 있거나 형식이 다를 수 있다고 보고 막음: `Array.isArray(x) ? x : []`, `?? []`, `|| {}`, 숫자는 `Number.isFinite`
- 외부 호출을 반복할 때는 `this.helpers.httpRequest` 에 `timeout` 을 주고, 요청 사이에 간격(1.5초)을 두며, 실패하면 한 번 다시 시도
- 날짜는 Luxon 으로 다룸 (`DateTime.now().setZone('Asia/Seoul')`)
- 반환 형식은 `[{ json: { ... } }]`

```javascript
// 기간 안의 실행만 골라 워크플로우별 횟수를 셈
const { periodDays } = $('실행 설정').first().json;
const items = $input.all().map((i) => i.json).filter((e) => e.workflowId);
if (!items.length) {
  throw new Error('실행 기록이 없습니다. n8n API 크리덴셜을 확인하세요.');
}
const errors = [];
// ...
return [{ json: { rows, errors } }];
```

### 저장소에 넣는 워크플로우 JSON

- `bin/n8n.sh export` 결과를 커밋할 때 지울 것: `shared`(소유 계정 이메일), `pinData`(고정 테스트 데이터), 파라미터에 직접 넣은 토큰
- 나머지는 n8n 이 내보낸 형식(2칸 들여쓰기, 한글 그대로) 유지

## 8. PR과 버전 태그

### PR 메시지

- 제목은 커밋 메시지와 같은 `<type>: <subject>` 형식 (50자 이내). 커밋이 여럿이면 PR 전체를 한 줄로 요약
  - type 은 버전 태그를 올리는 기준 (아래 '버전 태그')
- base 는 `main` (`develop` 을 만들기 전까지). 병합은 병합 커밋을 남기는 방식
- 본문은 아래 틀 사용. 목록 항목은 명사형으로 짧게

```markdown
## 요약
- 무엇을 왜 바꿨는지 1~3줄

## 변경 내용
- `경로`: 바뀐 내용 (동작이 그대로면 "동작 변경 없음")

## 확인
- 실행한 검증과 결과 (명령, 실행 번호 등)

## 호환성
- (호환이 깨질 때만) 사용자가 할 일: .env 키 변경, 재설치, 데이터 이전 등

## 참고
- (선택) 동작 방식, 주의할 점, 후속 작업
```

- 비밀값과 개인 정보(이메일, API 키 등)는 본문에 쓰지 않음
- Claude Code 가 PR 본문 끝에 붙이는 `🤖 Generated with [Claude Code](https://claude.com/claude-code)` 문구는 지움

### 버전 태그

`main` 에 병합될 때마다 그 병합 커밋에 버전 태그를 하나 붙인다.

- 형식: `v<MAJOR>.<MINOR>.<PATCH>` ([SemVer](https://semver.org/lang/ko/)), annotated 태그
- 메시지: PR 제목과 번호 (예: `docs: README 뱃지·참조 섹션 추가 (#4)`)
- 기준: `v0.7.0` (PR #4 병합, `e469645`). 이후 병합부터 아래 표대로 올림

| 올리는 자리 | 언제 | PR 제목 type |
|-------------|------|--------------|
| MAJOR | 큰 변경이 있을 때<br>- 이전 버전과 호환이 깨짐 (설치·실행 방법 변경 등)<br>- 구조가 크게 바뀜<br>- 메인 기능 추가 | 없음. |
| MINOR | 그 밖의 기능 추가 | `feat` |
| PATCH | 그 밖의 변경 | `fix`, `bugfix`, `hotfix`, `docs`, `refactor`, `chore`, `test` |

- `1.0.0` 전에는 MAJOR 에 해당하는 변경도 MINOR 를 올림. `1.0.0` 은 안정판으로 정할 때 올림
- 프로젝트 버전은 n8n·n8n-mcp 버전과 별개
- 버전을 올리는 PR 에서 [CHANGELOG.md](../CHANGELOG.md) 에 그 버전 항목을 추가 (호환성·추가·변경·수정·삭제 중 해당하는 것)
- `docs/` 문서 머리의 '문서 버전'은 이 태그를 따름 (6장 '문서 머리')
- 올린 태그는 옮기거나 지우지 않음. 잘못 붙였으면 다음 PATCH 로 바로잡음

```bash
git switch main && git pull --ff-only
git describe --tags --abbrev=0                                # 직전 버전 확인
git tag -a v0.8.0 -m "docs: 문서·버전 규칙 정리, 기본 포트로 변경 (#5)"   # 병합 커밋(main 최신)에 태그
git push origin v0.8.0
```

## 9. 작성 후 확인

| 대상 | 명령 |
|------|------|
| Bash | `bash -n bin/<스크립트>.sh`, `shellcheck bin/<스크립트>.sh` |
| Compose | `docker compose --env-file services/n8n/.env -f services/n8n/docker-compose.yml config -q` |
| Dockerfile | `docker compose --env-file services/n8n/.env -f services/n8n/docker-compose.yml build --check n8n` (빌드하지 않고 검사만) |
| JSON | `jq empty <파일>` |
| n8n 워크플로우 | `n8n_validate_workflow` (ID 기준) |

- Compose 검사는 `-q` 필수. 빼면 `.env` 의 비밀값이 화면에 그대로 출력됨

## 10. 보류

결정을 미룬 것이다. 나머지는 위 규칙에 반영했다.

| 항목 | 현재 (2026-11-18) |
|------|------|
| 필드 이름 언어 | Set·Code 노드에서 정의한 필드 이름 144개 중 영문 camelCase 135개(94%), 한글 9개(6%). 한글은 모두 `[메인] 검색: 네이버 통합검색` (`목록`, `구분`, `제목` 등) |
| `errorWorkflow` 미지정 | 6개. 이 중 게시(활성)된 것은 주식 4개 |
| shellcheck 결과 | `bin/n8n-admin.sh` 의 `source` 경고(SC1090) 1건. `bin/n8n.sh` 는 의도한 작은따옴표(SC2016)와 `ls` 로 개수 세기(SC2012) 안내 3건 |
