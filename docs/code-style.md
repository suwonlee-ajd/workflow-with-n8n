# 코드 스타일

이 저장소의 스크립트, 설정 파일, 문서, n8n 워크플로우를 쓸 때 따르는 규칙이다. 현재 코드에서 실제로 쓰는 방식을 정리한 초안이며, 결정을 미룬 것은 마지막 '보류'에 모았다.

- 기준: 저장소 파일과 n8n 워크플로우(2026-11-18 백업, 예제 제외 12개)
- 제외: `services/n8n-admin` (외부 리포지토리, 원본 스타일을 따른다)
- 다른 곳에 있는 규칙은 다시 쓰지 않는다.
  - 커밋·브랜치: [CLAUDE.md](../CLAUDE.md) 'Git Flow, Commit 규칙'
  - 워크플로우 이름·캔버스 그룹: [workflow-builder.md](../.claude/skills/n8n/references/workflow-builder.md) '네이밍 컨벤션'

## 1. 공통

| 항목 | 규칙 |
|------|------|
| 인코딩 | UTF-8, LF, 파일 끝 줄바꿈 1개 |
| 들여쓰기 | 스페이스 2칸 (Bash, YAML, JSON, JavaScript) |
| 언어 | 주석·출력 메시지·문서는 한국어. 변수·함수·파일 이름과 명령어·기술 용어는 영어 원어 |
| 파일 이름 | 영문 소문자, 단어는 하이픈으로 연결 (`n8n-admin.sh`, `n8n-ops-report-format.md`) |
| 경로 | 프로젝트 루트 기준 상대 경로 (`services/n8n/.env`) |
| 비밀값 | `.env`(git 제외)에만 둔다. 코드·문서·커밋·워크플로우 파라미터에 값을 쓰지 않는다 |
| 버전 | 정확한 버전으로 고정한다 (`N8N_VERSION=2.44.7`, `"n8n-mcp": "2.103.0"`). `latest`, `^`, `~` 를 쓰지 않는다 |

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
- 함수 안 변수는 `local` 로 선언한다.
- 함수 위에 하는 일을 주석으로 쓴다. 값을 출력하는 함수는 사용 예도 쓴다.
  - 예: `# 사용: dir="$(backup_dir <서비스명> <YYYYMMDD_HHMMSS>)"`
- 같은 옵션을 매번 붙이는 명령은 함수로 감싼다 (`compose()` 가 `--env-file`·`-f` 를 항상 붙임).
- 첫 인자는 하위 명령(`case "$1"`)이고, 나머지 인자는 `"${@:2}"` 로 그대로 넘긴다.
- 하위 명령을 추가하거나 바꾸면 사용법 문구와 README '2. 관리 명령어'를 함께 고친다.

### 작성 방식

- 변수는 항상 큰따옴표로 감싸고, 명령 치환은 `$(...)` 를 쓴다.
- `.env` 읽기
  - 값 하나만 필요하면 `sed -n 's/^KEY=//p' "$ENV_FILE"` 로 읽는다 (셸에 불러오지 않음).
  - 하위 프로세스에 전부 넘겨야 할 때만 `set -a; source "$ENV_FILE"; set +a` 를 쓴다.
- 실패 처리
  - 기본은 `set -e` 로 중단한다.
  - 실패해도 계속할 단계는 `|| continue` 나 `if … else` 로 드러내고, ⚠️ 메시지에 "계속 진행합니다"를 쓴다.
  - 사전 조건이 안 맞으면 ❌ 메시지에 다음에 실행할 명령을 넣고 `exit 1` 한다.
    - 예: `❌ services/n8n-admin/.env 가 없습니다. 먼저 실행: cp … 후 값 입력`
- 오래 실행되는 전경 프로세스는 `exec` 로 넘긴다 (`exec pnpm dev`).
- 컨테이너 안 임시 경로는 쓰기 전에 비운다 (`compose exec -T -u root n8n rm -rf "$WORKFLOW_TMP"`).

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
| 백업 | `data/backups/<YYYYMMDD>/<서비스명>/` |
| 로그 | `logs/<YYYY>/<YYYY.MM>/<서비스명>.<YYYY-MM-DD>.log` |

서비스명은 컨테이너 이름(`n8n`, `n8n-postgres`)을 쓴다.

## 3. Docker Compose (`services/*/docker-compose.yml`)

- 이미지 태그는 `.env` 변수로 고정한다. 필수 변수는 `${VAR:?set VAR in .env}` 로 써서, 비어 있으면 시작을 거부하게 한다.
- `container_name` 은 서비스 이름으로 고정한다. 스크립트가 이 이름(`n8n`, `n8n-postgres`)을 쓴다.
- 모든 서비스에 `restart: unless-stopped` 와 `logging: *default-logging` 을 넣는다. 로그 설정은 `x-logging` 앵커 하나로 공유한다.
- 앱 설정은 `env_file: .env` 로 넘긴다.
  - `${VAR}` 보간은 compose 가 직접 알아야 하는 값에만 쓴다: 이미지 태그, 포트, 컨테이너끼리 공유하는 DB 접속 정보.
  - 이유: 호스트 셸의 `LANG`·`TZ` 같은 값이 `.env` 를 덮어쓰지 않게 하려는 것이다.
- 컨테이너 안에서 확장할 변수는 `$$` 로 쓴다 (`pg_isready -U $${POSTGRES_USER}`).
- 볼륨 이름은 `name:` 으로 고정한다.
- 다른 서비스에 의존하면 상대 서비스에 `healthcheck` 를 두고 `depends_on.condition: service_healthy` 로 기다린다.
- DB 포트는 호스트에 열지 않는다.
- 키마다 위에 이유를 주석으로 쓴다 (버전 근거, 적용 시점 등).

## 4. 환경 변수 템플릿 (`.env.example`)

- `.env` 와 키 구성을 같게 유지한다. 키를 추가하거나 바꾸면 두 파일과 README 를 함께 고친다.
- 맨 위 블록에 용도, 사용 순서, 표기 규칙(`★` = 직접 입력할 비밀값)을 쓴다.
- 구역마다 번호 주석 `# N. 제목 — 요약` 을 달고, 키마다 위 줄에 설명을 쓴다.
- 비밀값은 빈 값으로 두고 `★` 와 생성 방법을 적는다 (`openssl rand -hex 16`).
- 값은 따옴표 없이 쓴다. 키 이름은 n8n·PostgreSQL 이 정한 이름을 그대로 쓴다.

## 5. JSON 설정 (`.mcp.json`, `.claude/settings.json`, `package.json`)

- JSON 에는 주석을 쓸 수 없으므로 설명은 README 나 `package.json` 의 `description` 에 쓴다.
- 비밀값을 넣지 않는다. `.mcp.json` 은 실행할 때 `services/n8n/.env` 에서 `N8N_API_KEY` 를 읽어 넘긴다.
- 의존성은 정확한 버전으로 적고 `package-lock.json` 을 커밋한다. 설치는 `npm ci` 로 한다.
- 개인 설정(도구 권한 허용 등)은 `.claude/settings.local.json`(git 제외)에 둔다. `.claude/settings.json` 에는 함께 쓸 설정만 넣는다.

## 6. 문서 (`README.md`, `docs/`, `.claude/`)

- 파일마다 `#` 제목은 하나이고, 바로 아래 한두 문장으로 문서 범위를 쓴다.
- 문체
  - `docs/`·`.claude/`·`CLAUDE.md` 의 본문은 `…다` 체로 쓴다.
  - README 의 본문은 `…습니다` 체로 쓴다.
  - 표와 목록 항목은 명사형으로 짧게 쓴다.
- 비교와 목록은 표로 쓴다. 구성도와 디렉터리 트리는 ```` ```text ````, 명령은 ```` ```bash ```` 블록에 넣는다.
- 코드, 경로, 명령, 키, 노드 이름은 백틱으로 감싼다.
- 다른 문서는 상대 경로로 링크한다. 같은 규칙을 두 곳에 쓰지 않고 원본 문서에 링크한다.
- 버전에 따라 달라지는 내용에는 기준 버전을 적는다 (`n8n-mcp 2.103.0 기준`).
- 새 문서를 만들면 CLAUDE.md '개요' 표와 README '디렉터리 구조'에 등록한다.
- 예시에는 실제 비밀값이나 개인 정보를 쓰지 않고 가짜 값을 쓴다 (`admin@co.kr`).

## 7. n8n 워크플로우

워크플로우 이름과 캔버스 그룹은 workflow-builder.md '네이밍 컨벤션'을 따른다. 여기서는 노드와 설정을 다룬다.

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

- 실행마다 바꿀 수 있는 값(기간, 개수, 기준값)은 트리거 다음 `실행 설정` Set 노드에 모은다. 뒤 노드는 `$('실행 설정').first().json.<키>` 로 읽는다.
- 인증은 크리덴셜로만 한다 (`httpHeaderAuth`, `httpCustomAuth`, `slackApi`, `openAiApi`, `n8nApi`). 토큰을 URL 이나 헤더 파라미터에 직접 쓰지 않는다.
- 계정마다 다른 값(Slack 채널, 크리덴셜 선택)은 비워 두고 n8n 화면에서 고르도록 안내한다. `$env` 는 쓰지 않는다.

### 워크플로우 설정

| 설정 | 값 |
|------|----|
| `timezone` | `Asia/Seoul` |
| `executionOrder` | `v1` |
| `errorWorkflow` | `[에러] 공통: 실패 알림` (에러 워크플로우 자신은 제외) |
| `availableInMCP` | `true` |

### 외부 호출과 오류

- 외부 API·Slack·LLM 노드는 `retryOnFail` 을 켠다. `maxTries`·`waitBetweenTries` 는 대상 서비스에 맞춰 노드마다 정한다 (현재 2~3회, 1~5초).
- 일부 소스가 실패해도 결과를 보낼 수 있으면 `onError: continueRegularOutput` 으로 둔다. 다음 노드에서 오류 필드를 확인해 `errors` 에 모으고 결과와 함께 넘긴다.
- 더 진행할 수 없으면 멈춘다. 오류 메시지는 원인과 확인할 것을 한국어로 쓴다.
  - 예: `throw new Error('최근 5거래일의 국내 시세가 없습니다. KRX 크리덴셜과 서비스 승인 상태를 확인하세요.')`

### Code 노드 (JavaScript)

- 기본 노드(Set, Filter, IF, Split Out, Aggregate, Merge 등)로 할 수 없을 때만 쓴다. `notes` 는 `Why Code:` 로 시작해 이유를 쓴다.
- 모드는 `Run Once for All Items` (`runOnceForAllItems`).
- 형식
  - 작은따옴표와 세미콜론을 쓴다.
  - 변수는 `const` 가 기본이고, 다시 대입할 때만 `let` 을 쓴다.
  - 짧은 헬퍼는 화살표 함수로, 이름 붙은 계산(예: `rsi`)은 `function` 으로 쓴다.
- 맨 위 주석 한 줄로 노드가 하는 일을 쓴다. 주석 문체는 1장 '주석'을 따른다.
- 앞 노드 값은 `$('노드 이름').first().json` 이나 `.all()` 로 읽는다.
- 입력은 비어 있거나 형식이 다를 수 있다고 보고 막는다: `Array.isArray(x) ? x : []`, `?? []`, `|| {}`, 숫자는 `Number.isFinite`.
- 외부 호출을 반복할 때는 `this.helpers.httpRequest` 에 `timeout` 을 주고, 요청 사이에 간격(1.5초)을 두며, 실패하면 한 번 다시 시도한다.
- 날짜는 Luxon 으로 다룬다 (`DateTime.now().setZone('Asia/Seoul')`).
- 반환 형식은 `[{ json: { ... } }]` 이다.

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

- `bin/n8n.sh export` 결과를 커밋할 때는 다음을 지운다: `shared`(소유 계정 이메일), `pinData`(고정 테스트 데이터), 파라미터에 직접 넣은 토큰.
- 나머지는 n8n 이 내보낸 형식(2칸 들여쓰기, 한글 그대로)을 유지한다.

## 8. 작성 후 확인

| 대상 | 명령 |
|------|------|
| Bash | `bash -n bin/<스크립트>.sh`, `shellcheck bin/<스크립트>.sh` |
| Compose | `docker compose --env-file services/n8n/.env -f services/n8n/docker-compose.yml config -q` |
| JSON | `jq empty <파일>` |
| n8n 워크플로우 | `n8n_validate_workflow` (ID 기준) |

- Compose 검사는 `-q` 를 꼭 붙인다. 빼면 `.env` 의 비밀값이 화면에 그대로 출력된다.

## 9. 보류

결정을 미룬 것이다. 나머지는 위 규칙에 반영했다.

| 항목 | 현재 (2026-11-18) |
|------|------|
| 필드 이름 언어 | Set·Code 노드에서 정의한 필드 이름 144개 중 영문 camelCase 135개(94%), 한글 9개(6%). 한글은 모두 `[메인] 검색: 네이버 통합검색` (`목록`, `구분`, `제목` 등) |
| `errorWorkflow` 미지정 | 6개. 이 중 게시(활성)된 것은 주식 4개 |
| shellcheck 결과 | `bin/n8n-admin.sh` 의 `source` 경고(SC1090) 1건. `bin/n8n.sh` 는 의도한 작은따옴표(SC2016)와 `ls` 로 개수 세기(SC2012) 안내 3건 |
