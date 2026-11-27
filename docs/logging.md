# 로깅

| 항목 | 값 |
| --- | --- |
| 문서 버전 | 0.13.0 |
| 최종 수정 | 2026-11-25 |

이 프로젝트에서 로그가 어디에 남고, 언제 사라지며, 어떻게 확인하는지 정리한다.

## 한눈에 보기

| 대상 | 남는 곳 | 재시작 후 | 보는 방법 |
|------|---------|-----------|-----------|
| n8n 프로세스 로그 | Docker `json-file` 드라이버 (컨테이너 표준 출력) | 컨테이너를 지우면 사라짐 | `bin/n8n.sh logs`, `docker logs n8n` |
| PostgreSQL 로그 | Docker `json-file` 드라이버 | 컨테이너를 지우면 사라짐 | `docker logs n8n-postgres` |
| 로그 파일 (중지·재시작 때 기록) | `logs/<YYYY>/<YYYY.MM>/<서비스명>.<YYYY-MM-DD>.log` | 남음 | 파일 열람 |
| n8n 이벤트 로그 | `n8n_data` 볼륨의 `n8nEventLog*.log` | 남음 | 컨테이너 안에서 열람 |
| 워크플로우 실행 기록 | PostgreSQL | 남음 | n8n 화면의 Executions |
| n8n-admin 대시보드 | 실행한 터미널의 표준 출력 | 남지 않음 | 실행한 터미널 |
| n8n-mcp | 없음 (stdio 방식) | — | — |

별도의 로그 수집 도구는 쓰지 않는다. n8n 의 로그 관련 환경변수도 설정하지 않아 기본값(`info` 레벨, 콘솔 출력)으로 동작한다.

## 컨테이너 로그 (Docker)

`n8n`, `n8n-postgres` 두 컨테이너의 표준 출력을 Docker 가 `json-file` 드라이버로 보관한다.

### 크기 제한

`services/n8n/docker-compose.yml` 의 `x-logging` 에서 두 컨테이너에 같은 제한을 건다.

| 옵션 | 값 | 의미 |
|------|----|------|
| `max-size` | `10m` | 로그 파일 하나의 최대 크기 |
| `max-file` | `5` | 보관할 파일 수. 넘으면 오래된 파일부터 삭제 |

- 컨테이너당 최대 약 50MB 다.
- 이 설정은 컨테이너를 만들 때 정해진다. 값을 바꾼 뒤에는 `bin/n8n.sh restart` 로 컨테이너를 다시 만들어야 적용된다.
- 2026-11 기준 하루에 쌓이는 양은 n8n 약 8.5KB, PostgreSQL 약 45KB 다. 50MB 를 채우려면 몇 년이 걸린다.

### Docker 에는 일수 기준 롤링이 없다

Docker 의 `json-file`·`local` 드라이버는 크기와 파일 수로만 로그를 돌린다. 날짜별로 파일을 나누거나 며칠 지난 로그를 지우는 옵션은 없다. 파일로 남기는 방법은 아래 '로그 파일 기록'에 있다.

n8n 의 파일 로그(`N8N_LOG_OUTPUT=file`)도 크기와 파일 수 기준이라 사정이 같다.

### 로그 보기

```bash
bin/n8n.sh logs                                   # n8n 실시간 로그
docker logs --tail 100 n8n                        # 최근 100줄
docker logs -t --since 24h n8n                    # 최근 24시간, 타임스탬프 포함
docker logs -t --since 2026-11-17T00:00:00 --until 2026-11-18T00:00:00 n8n   # 특정 기간
docker logs n8n-postgres                          # PostgreSQL
```

`-t` 로 붙는 타임스탬프는 UTC 다. KST 는 9시간을 더한다.

## 로그 파일 기록

로깅은 Docker 가 맡는다. `bin/n8n.sh` 는 컨테이너를 지우기 전에 Docker 가 보관하던 로그를 파일로 옮겨 적기만 한다. 백업(`data/backups/`)과는 별개이며, 로그는 `logs/` 아래에만 둔다.

```text
logs/
└── 2026/                              # 연도
    └── 2026.11/                       # 연.월
        ├── n8n.2026-11-18.log         # <서비스명>.<기록한 날짜>.log
        └── n8n-postgres.2026-11-18.log
```

- 경로: `logs/<YYYY>/<YYYY.MM>/<서비스명>.<YYYY-MM-DD>.log`. 서비스명은 컨테이너 이름(`n8n`, `n8n-postgres`)이다.
- 기록되는 때: `bin/n8n.sh stop`·`restart`. 컨테이너를 멈추고(`compose stop`) 로그를 기록한 뒤 컨테이너를 지운다(`compose down`). 종료 과정의 로그까지 담긴다.
- 파일 이름의 날짜는 **기록한 날**이다. 파일에는 그 컨테이너가 만들어진 뒤부터 쌓인 로그가 모두 들어가므로, 며칠 떠 있던 컨테이너라면 이전 날짜의 로그도 같은 파일에 있다.
- 같은 날 다시 기록하면 같은 파일 뒤에 이어 쓴다.
- 줄마다 Docker 가 붙인 타임스탬프(UTC)가 있다. KST 는 9시간을 더한다.
- 컨테이너가 없거나 기록에 실패해도 중지·재시작은 계속 진행한다.
- 로그 파일은 자동으로 지우지 않는다. 오래된 것은 연·월 폴더 단위로 직접 정리한다.
- `logs/` 는 `.gitignore` 대상이라 커밋되지 않는다. 저장 위치는 `bin/n8n.sh` 의 `LOG_DIR` 로 바꾼다.

## 로그가 남는 경우와 사라지는 경우

기준은 하나다. **컨테이너가 지워지지 않으면 로그는 남는다.**

| 상황 | 컨테이너 | 로그 | 이후 |
|------|----------|------|------|
| `bin/n8n.sh stop`·`restart` | 삭제 | `logs/` 에 기록됨 | — |
| n8n 프로세스가 죽음 (오류, 메모리 부족) | 남음 | 유지 | Docker 가 같은 컨테이너를 자동으로 다시 띄움 |
| `docker stop`·`docker kill` 로 직접 멈춤 | 남음 | 유지 | 자동으로 다시 뜨지 않음. `bin/n8n.sh start` 로 재개 |
| Docker Desktop 종료, Mac 재부팅 | 남음 | 유지 | Docker 가 켜지면 다시 뜸 |
| 전원 차단 | 남음 | 마지막 몇 줄이 빠질 수 있음 | Docker 가 켜지면 다시 뜸 |
| `bin/n8n.sh stop` 도중 중단 (Ctrl+C) | 멈춘 채 남음 | 유지 | `stop` 을 다시 실행하면 기록됨 |
| 설정을 바꾼 뒤 `bin/n8n.sh start` | 새로 만들어짐 | **기록 없이 사라짐** | 설정 변경 후에는 `restart` 를 쓴다 |
| `docker compose down`·`docker rm -f` 직접 실행 | 삭제 | **기록 없이 사라짐** | 복구 불가 |
| Docker Desktop 데이터 초기화 | 삭제 | **기록 없이 사라짐** | 복구 불가 |

Docker 에 남아 있던 로그는 다음 `stop`·`restart` 때 이전 날짜분까지 한꺼번에 기록된다.

## 강제 종료 확인

강제 종료되면 로그 기록 단계는 실행되지 않지만, 컨테이너가 남아 있으므로 흔적을 확인할 수 있다.

```bash
docker inspect -f '재시작={{.RestartCount}} 메모리부족={{.State.OOMKilled}} 종료코드={{.State.ExitCode}} 직전종료={{.State.FinishedAt}}' n8n
docker logs -t n8n | grep -n "Initializing n8n process"    # 프로세스가 시작된 시각 목록
```

- **재시작 횟수**: 0 이 아니면 Docker 가 컨테이너를 자동으로 다시 띄운 적이 있다.
- **종료 코드 137**: 강제 종료(SIGKILL)다. `메모리부족=true` 면 메모리 부족으로 죽은 것이다.
- **로그의 끊긴 지점**: 강제 종료 순간에는 프로세스가 마지막 로그를 쓰지 못한다. 종료 로그 없이 바로 `Initializing n8n process` 가 이어지면 그 사이에서 죽은 것이다.
- **실행 중이던 워크플로우**: n8n 이 다음 시작 때 비정상 종료를 감지해 중단된 실행으로 정리한다. n8n 화면의 Executions 에서 확인한다.

## n8n 이벤트 로그

n8n 이 워크플로우 실행 등의 내부 이벤트를 `n8n_data` 볼륨의 `/home/node/.n8n/n8nEventLog*.log` 에 자동으로 쓴다. 비정상 종료 뒤 실행 상태를 복구하는 데 쓰이는 파일이다.

- 볼륨에 있어 컨테이너를 지워도 남는다.
- 볼륨 안의 파일이라 `logs/` 에는 기록되지 않는다. 대신 `bin/n8n.sh backup` 의 볼륨 백업에 포함된다.
- n8n 이 파일을 돌려 가며 보관하므로 따로 정리하지 않는다.

## n8n 로그 설정 변수 (현재 미사용)

`services/n8n/.env` 에 넣으면 적용되는 변수다. 지금은 하나도 설정하지 않았다. 기본값은 n8n 2.49.5 기준이다.

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `N8N_LOG_LEVEL` | `info` | `error`, `warn`, `info`, `debug`, `silent` 중 하나 |
| `N8N_LOG_OUTPUT` | `console` | 출력 대상. `console`, `file` 을 쉼표로 나열 |
| `N8N_LOG_FORMAT` | `text` | `text` 또는 `json` |
| `N8N_LOG_FILE_LOCATION` | `logs/n8n.log` | 파일 로그 경로. 상대 경로는 `/home/node/.n8n` 기준 |
| `N8N_LOG_FILE_SIZE_MAX` | `16` | 파일당 최대 크기(MB) |
| `N8N_LOG_FILE_COUNT_MAX` | `100` | 보관할 파일 수 |

- `N8N_LOG_OUTPUT` 은 폴더 이름이 아니다. `logs` 처럼 `console`·`file` 이 아닌 값을 넣으면 오류 없이 로그가 아무 데도 남지 않는다.
- 파일 로그를 켤 때는 `console,file` 로 둔다. `console` 을 빼면 `bin/n8n.sh logs` 와 `logs/` 의 로그 파일에 n8n 로그가 나오지 않는다.
- 파일 로그는 `n8n_data` 볼륨에 쌓인다. 호스트 폴더에서 보려면 compose 에 볼륨 연결을 추가해야 한다.

## n8n-admin, n8n-mcp

- **n8n-admin 대시보드**: `bin/n8n-admin.sh start` 를 실행한 터미널에만 출력된다. 파일로 남기려면 같은 규칙의 경로로 직접 넘긴다. 예: `bin/n8n-admin.sh start > logs/2026/2026.11/n8n-admin.2026-11-18.log 2>&1` (폴더는 먼저 만든다).
- **n8n-mcp**: Claude Code 가 stdio 로 실행하는 프로세스라 로그 파일이 없다. 연결 상태는 Claude Code 의 `/mcp` 와 `n8n_health_check` 도구로 확인한다.
