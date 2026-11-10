# n8n 한국 서비스 및 한글 환경 Docker 설정

이 프로젝트는 [EddyGlen n8n 한글 설정 가이드](https://eddyglen.com/n8n-korean-language-setup/)에 맞춰 한국 표준시(KST) 및 UTF-8 한글 문자 인코딩을 최적화한 Docker Compose 환경입니다.

---

## 📁 디렉터리 구조

```text
root
├── bin/n8n.sh                       # n8n 시작·중지·로그·백업 제어 스크립트
├── services/n8n/
│   ├── .env                         # 환경변수 (버전·포트·타임존·로케일·DB 계정·암호화 키·API 키) — 비밀값 포함
│   ├── docker-compose.yml           # n8n + PostgreSQL 컨테이너 정의
│   └── workflows/                   # 워크플로우 JSON (bin/n8n.sh export/import, git 관리 대상)
├── data/backups/                    # bin/n8n.sh backup 결과물 (볼륨 *.tar.gz, DB 덤프 *.sql.gz)
├── docs/                            # 프로젝트 관련 문서
└── README.md
```

---

## 📌 주요 설정 포인트 요약

> 모든 설정은 `services/n8n/.env` 한 곳에서 관리합니다. n8n 컨테이너는 `env_file` 로 이 파일을 그대로 읽습니다
> (`LANG`·`TZ` 처럼 호스트 셸에도 흔히 있는 값이 `.env` 를 덮어쓰지 않도록 compose `${VAR}` 보간은 쓰지 않음).
> 예외로 DB 접속 정보만 postgres·n8n 두 컨테이너가 공유해야 해서 `${POSTGRES_*}` 보간으로 연결합니다.

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

# 중지
bin/n8n.sh stop

# 재시작 (환경변수 갱신 시 컨테이너 완전 재생성)
bin/n8n.sh restart

# 실시간 로그 확인
bin/n8n.sh logs

# 컨테이너 상태 확인
bin/n8n.sh status

# 백업: n8n_data 볼륨(*.tar.gz) + PostgreSQL 덤프(*.sql.gz) → data/backups/
bin/n8n.sh backup

# 워크플로우 내보내기 / 가져오기 (services/n8n/workflows/*.json)
bin/n8n.sh export
bin/n8n.sh import
```

*(docker compose 를 직접 쓸 때는 compose 파일 경로를 지정하면 같은 폴더의 `.env` 를 자동으로 읽습니다: `docker compose -f services/n8n/docker-compose.yml up -d`)*

### 3. 워크플로우 형상관리 (export / import)
워크플로우는 DB(PostgreSQL)에 저장되므로, git 으로 이력을 남기려면 JSON 으로 내보내야 합니다. 두 명령 모두 n8n 이 실행 중이어야 합니다.

- `export`: 워크플로우 1개당 `<워크플로우 ID>.json` 1개. 폴더의 기존 JSON 을 비우고 통째로 교체하므로 n8n 에서 지운 워크플로우는 파일에서도 사라짐
  (단, 워크플로우가 0개면 n8n 이 오류를 내고 기존 파일은 그대로 둠)
- `import`: 같은 ID 는 덮어쓰고 없는 ID 는 새로 생성. **가져온 워크플로우는 모두 비활성 상태**가 되므로 UI 에서 다시 활성화해야 함
- 크레덴셜 값은 JSON 에 들어가지 않습니다 (크레덴셜 ID·이름만 참조). 다른 n8n 으로 옮길 때는 크레덴셜을 따로 만들어 연결해야 합니다
- 노드 파라미터에 직접 넣은 토큰·URL 과 `pinData`(고정 테스트 데이터)는 그대로 들어가므로 커밋 전에 확인하세요

### 4. 버전 업그레이드
1. `bin/n8n.sh backup` — 볼륨(암호화 키)과 DB(워크플로우·크레덴셜) 백업
2. `services/n8n/.env` 의 `N8N_VERSION` 을 새 stable 버전으로 변경
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
- 덤프 복원: `gunzip -c data/backups/n8n_db_<시각>.sql.gz | docker exec -i n8n-postgres psql -U n8n -d n8n`
- `N8N_BASIC_AUTH_*` 는 n8n 1.0 에서 사용자 계정 방식으로 바뀌면서 없어진 설정이라 쓰지 않습니다

---

## 💡 한글 관련 실무 팁 (가이드 핵심 내용)

### 1. UI 언어와 시스템 설정의 차이
- n8n 공식 웹 UI는 기본적으로 영문으로 제공됩니다.
- 가이드에서 다루는 "한글 설정"은 **시간(타임존)과 데이터 문자열(인코딩)이 깨지지 않도록 시스템 환경을 한국화**하는 것입니다.
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
