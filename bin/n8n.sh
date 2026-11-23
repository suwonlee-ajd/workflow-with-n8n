#!/bin/bash

# ==========================================
# n8n Docker 관리 스크립트
# ==========================================

set -e
set -o pipefail                   # 파이프 중간 명령(pg_dump 등)이 실패해도 멈추도록

# 프로젝트 루트 (bin/ 의 상위) 기준으로 경로를 잡음
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
cd "$ROOT"

ENV_FILE="services/n8n/.env"
ENV_EXAMPLE="services/n8n/.env.example"
MCP_DIR="services/n8n-mcp"        # Claude Code 가 쓰는 n8n-mcp 서버
DATA_VOLUME="n8n_data"            # 볼륨 이름은 docker-compose.yml 의 volumes 와 같아야 함
DB_VOLUME="n8n_postgres_data"
COMPOSE_FILE="services/n8n/docker-compose.yml"
LOG_DIR="logs"                    # 로그: logs/<YYYY>/<YYYY.MM>/<서비스명>.<YYYY-MM-DD>.log
WORKFLOW_DIR="services/n8n/workflows"
WORKFLOW_TMP="/tmp/workflows"     # 컨테이너 안 임시 경로 (export·import·backup 용)

# .env 가 없으면 init 을 안내하고 중단
require_env() {
  if [ ! -f "$ENV_FILE" ]; then
    echo "❌ $ENV_FILE 가 없습니다. 먼저 실행: bin/n8n.sh init"
    exit 1
  fi
}

# docker compose 를 services/n8n 의 .env·compose 파일로 실행
# - --env-file: compose 파일의 ${VAR} 보간도 services/n8n/.env 를 따르도록
compose() {
  require_env
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

# .env 에서 키의 값을 읽음
# - 사용: env_value <키>
# - .env 가 없거나 키가 없으면 빈 값
# - 앞뒤 공백은 떼고, 값 자리에 주석만 있으면(KEY=  # 메모) 빈 값으로 봄
env_value() {
  [ -f "$ENV_FILE" ] || return 0
  sed -n "s/^$1=//p" "$ENV_FILE" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^#.*//'
}

# .env 에 "<키>=" 줄이 없으면 중단 (.env.example 보다 오래된 .env 등)
require_env_key() {
  if ! grep -q "^$1=" "$ENV_FILE"; then
    echo "❌ $ENV_FILE 에 '$1=' 줄이 없어 값을 채우지 못했습니다. $ENV_EXAMPLE 을 참고해 줄을 추가한 뒤 다시 실행하세요."
    exit 1
  fi
}

# 새 비밀값
new_secret() {
  openssl rand -hex 16
}

# .env 의 키에 비밀값을 써넣음 (init 용)
# - 사용: fill_secret <키> <값>
# - "<키>=" 줄을 통째로 바꾸므로, 비어 있는지는 호출하는 쪽이 env_value 로 먼저 확인
# - 같은 폴더의 임시 파일에 쓴 뒤 mv 로 교체: 쓰다가 끊겨도(Ctrl-C, 디스크 부족) 기존 .env 가 비지 않도록
#   - 임시 파일은 mktemp 가 권한 600 으로 만들고, 실패하면 지움
#   - 교체 뒤 .env 권한은 600 (심볼릭 링크였다면 일반 파일로 바뀜)
# - sed -i 는 macOS·Linux 옵션이 달라 쓰지 않음
fill_secret() {
  local tmp
  require_env_key "$1"
  if tmp="$(mktemp "$ENV_FILE.XXXXXX" 2>/dev/null)" && sed "s|^$1=.*\$|$1=$2|" "$ENV_FILE" > "$tmp" && [ -s "$tmp" ] && mv -f "$tmp" "$ENV_FILE"; then
    return 0
  fi
  [ -z "$tmp" ] || rm -f "$tmp"
  echo "❌ $1: $ENV_FILE 에 값을 쓰지 못했습니다 (디스크 공간·폴더 권한 확인). 기존 파일은 그대로입니다."
  exit 1
}

# 백업 경로를 .env 의 BACKUP_DIR 에서 읽음
# - 비어 있으면 프로젝트 루트의 data/backups
# - 절대 경로만 허용: compose 가 같은 값을 services/n8n 기준 상대 경로로 해석하므로
BACKUP_DIR="$(env_value BACKUP_DIR)"
if [ -n "$BACKUP_DIR" ] && [ "${BACKUP_DIR#/}" = "$BACKUP_DIR" ]; then
  echo "❌ $ENV_FILE 의 BACKUP_DIR 은 절대 경로여야 합니다: $BACKUP_DIR (비우면 data/backups 사용)"
  exit 1
fi
BACKUP_DIR="${BACKUP_DIR:-$ROOT/data/backups}"

# 백업 폴더를 만들고 경로를 출력
# - 경로: <BACKUP_DIR>/<일시>/<서비스명>/
# - 일시: 시각 스탬프에서 _ 를 뺀 앞 12자리 (YYYYMMDDHHMM)
# - 서비스명: 컨테이너 이름 (n8n, n8n-postgres)
# - 사용: dir="$(backup_dir <서비스명> <YYYYMMDD_HHMMSS>)"
backup_dir() {
  local stamp="${2/_/}"
  local dir="$BACKUP_DIR/${stamp:0:12}/$1"
  mkdir -p "$dir"
  echo "$dir"
}

# 컨테이너 로그를 파일로 기록
# - 위치: logs/<YYYY>/<YYYY.MM>/<서비스명>.<YYYY-MM-DD>.log (날짜는 기록한 날)
# - compose stop 뒤에 호출: 종료 과정의 로그까지 담도록
# - compose down 앞에 호출: down 하면 Docker 로그도 함께 삭제
# - 실패해도 중지·재시작은 계속 진행
save_logs() {
  local c dir
  dir="$LOG_DIR/$(date +%Y)/$(date +%Y.%m)"
  mkdir -p "$dir"
  for c in n8n n8n-postgres; do
    # 컨테이너가 없으면(이미 지워졌거나 처음 실행) 건너뜀
    docker inspect "$c" >/dev/null 2>&1 || continue
    if docker logs -t "$c" >> "$dir/$c.$(date +%Y-%m-%d).log" 2>&1; then
      echo "📝 로그 기록: $dir/$c.$(date +%Y-%m-%d).log"
    else
      echo "⚠️ $c 로그 기록에 실패했습니다. 계속 진행합니다."
    fi
  done
}

# 접속 포트는 services/n8n/.env 의 N8N_PORT 를 따름 (없으면 5678)
n8n_port() {
  local port
  port="$(env_value N8N_PORT)"
  echo "${port:-5678}"
}

# 컨테이너가 실행 중인지
# - 사용: container_running <컨테이너 이름>
container_running() {
  [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" = true ]
}

# n8n 컨테이너의 누적 재시작 횟수 (컨테이너가 없으면 0)
restart_count() {
  docker inspect -f '{{.RestartCount}}' n8n 2>/dev/null || echo 0
}

# n8n 이 실제로 응답할 때까지 대기 (/healthz/readiness 가 200)
# - compose up -d 는 컨테이너를 띄우기만 하고 n8n 기동 성공 여부는 알려 주지 않음
# - /healthz/readiness: DB 연결·마이그레이션까지 끝나야 200 (/healthz 는 서버가 뜨기만 하면 200)
# - 사용: wait_healthy <성공 메시지> (응답을 확인했을 때만 출력)
# - 최대 HEALTH_TIMEOUT 초 (기본 120) 대기
# - 실패(1): 기다리는 동안 컨테이너가 2회 이상 재시작(DB 접속 실패 등)하면 바로, 또는 시간이 지났는데 컨테이너가 꺼졌거나 재시작한 적이 있으면
#   - 재시작 횟수는 시작 시점과의 차이로 셈: RestartCount 는 컨테이너가 살아 있는 동안 누적
# - 경고만 하고 성공(0): 확인할 수 없거나 아직 뜨는 중일 때 (멀쩡한 기동을 실패로 알리지 않도록)
#   - curl 이 없을 때
#   - 시간이 지났지만 컨테이너가 재시작 없이 실행 중일 때 (첫 기동, 버전을 올린 뒤의 DB 마이그레이션)
# - --noproxy: 셸에 http_proxy 가 있어도 localhost 는 프록시를 거치지 않도록
wait_healthy() {
  local timeout="${HEALTH_TIMEOUT:-120}" port base deadline restarts=0
  local reason="${timeout}초 안에 n8n 이 응답하지 않았습니다."
  if ! command -v curl >/dev/null 2>&1; then
    echo "⚠️ curl 명령이 없어 n8n 응답을 확인하지 못했습니다. bin/n8n.sh status·logs 로 확인하세요."
    return 0
  fi
  port="$(n8n_port)"
  base="$(restart_count)"
  deadline=$((SECONDS + timeout))   # SECONDS: bash 내장 경과 시간 (curl 대기 시간까지 포함해 셈)
  echo "⏳ n8n 이 응답할 때까지 기다립니다 (최대 ${timeout}초)..."
  while [ "$SECONDS" -lt "$deadline" ]; do
    if curl -fs --noproxy '*' -o /dev/null -m 3 "http://localhost:$port/healthz/readiness"; then
      echo "$1"
      return 0
    fi
    restarts=$(( $(restart_count) - base ))
    if [ "$restarts" -ge 2 ]; then
      reason="n8n 컨테이너가 재시작을 반복하고 있습니다 (${restarts}회)."
      break
    fi
    sleep 2
  done
  if [ "$restarts" -eq 0 ] && container_running n8n; then
    echo "⚠️ ${timeout}초가 지났지만 n8n 이 아직 뜨는 중입니다 (컨테이너는 재시작 없이 실행 중). 중단하지 말고 bin/n8n.sh logs 로 진행을 확인하세요."
    return 0
  fi
  echo "❌ $reason 최근 로그:"
  compose logs --tail 30 n8n
  return 1
}

# Docker 볼륨이 있는지
volume_exists() {
  docker volume inspect "$1" >/dev/null 2>&1
}

# 이미 있는 DB 의 비밀번호를 새 값으로 바꿈 (init 용)
# - 사용: sync_db_password <새 비밀번호>
# - 필요한 이유: postgres 는 볼륨이 비어 있는 최초 기동 때만 POSTGRES_PASSWORD 를 적용
#   - .env 를 새로 만들면(다시 clone 등) 옛 볼륨의 비밀번호와 달라져 n8n 이 접속하지 못함
# - .env 에 쓰기 전에 호출: 실패해도 .env 가 비어 있어 init 을 다시 실행하면 재시도
#   - compose 는 빈 POSTGRES_PASSWORD 를 거부하므로 값을 환경변수로 넘김 (셸 환경변수가 .env 보다 우선)
# - 컨테이너 안에서 변경: 로컬 소켓 접속은 비밀번호를 묻지 않음
#   - postgres 컨테이너가 꺼져 있을 때만 띄움: 실행 중일 때 compose up 을 하면 환경변수가 달라져 컨테이너를 다시 만들고, n8n 의 DB 연결이 끊김
#   - 끝난 뒤에도 postgres 컨테이너는 떠 있음 (이어서 start 하면 n8n 이 함께 뜸)
# - SQL 은 표준 입력으로 전달: 비밀번호가 명령 인자에 남지 않도록
sync_db_password() {
  local out
  if ! container_running n8n-postgres &&
    ! out="$(POSTGRES_PASSWORD="$1" compose up -d --wait postgres 2>&1)"; then
    echo "❌ POSTGRES_PASSWORD: DB 비밀번호를 바꾸려고 postgres 컨테이너를 띄우다 실패했습니다. $ENV_FILE 은 그대로이니 원인을 해결한 뒤 다시 실행하세요."
    printf '%s\n' "$out" | tail -n 5
    exit 1
  fi
  if ! out="$(printf "ALTER USER CURRENT_USER PASSWORD '%s';\n" "$1" |
    docker exec -i n8n-postgres sh -c 'psql -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' 2>&1)"; then
    echo "❌ POSTGRES_PASSWORD: DB($DB_VOLUME 볼륨)의 비밀번호를 바꾸지 못했습니다. $ENV_FILE 은 그대로이니 아래 원인을 해결한 뒤 다시 실행하세요. (자세한 로그: docker logs n8n-postgres)"
    printf '%s\n' "$out" | tail -n 5
    exit 1
  fi
}

# 명령이 없으면 중단
# - 사용: require_cmd <명령> [안내] (안내를 생략하면 "설치한 뒤 다시 실행하세요.")
require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "❌ $1 명령을 찾을 수 없습니다. ${2:-설치한 뒤 다시 실행하세요.}"
    exit 1
  fi
}

# Docker 가 떠 있지 않으면 중단 (볼륨 확인용)
# - 꺼져 있으면 볼륨이 없다고 잘못 보고 새 비밀값을 만들게 됨
require_docker() {
  require_cmd docker
  if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker 가 실행 중이 아닙니다. Docker Desktop 을 켠 뒤 다시 실행하세요."
    exit 1
  fi
}

# 초기 설정 (clone 직후 1회, 다시 실행해도 안전)
# - .env 가 없으면 .env.example 을 복사 (권한 600), 있으면 그대로 두고 빈 비밀값만 채움
# - 볼륨이 이미 있을 때 (다시 clone 해 .env 만 사라진 경우 등)
#   - N8N_ENCRYPTION_KEY: 볼륨의 config 에 키가 있으면 .env 는 비워 둠 (n8n 이 볼륨의 키를 씀, 바꾸면 크레덴셜 복호화 불가)
#   - POSTGRES_PASSWORD: 옛 값을 알 수 없으므로 새로 만들어 DB 에도 반영 (sync_db_password)
#     - n8n 이 실행 중이었으면 새 비밀번호로 다시 띄움 (옛 비밀번호로는 DB 에 새로 접속하지 못함)
# - 이미 채워진 값이 볼륨과 맞는지는 확인하지 않음 (틀리면 start 의 wait_healthy 가 알림)
# - Docker·openssl 은 비밀값을 채워야 할 때만 요구: 값이 다 있으면 Docker 가 꺼져 있어도 의존성 설치까지 진행
# - n8n-mcp 의존성 설치 (npm ci): 실행 파일이 없거나 설치된 내용이 package.json 과 다를 때
init() {
  local stored_key secret
  echo "🧰 n8n 초기 설정을 시작합니다..."

  if [ -f "$ENV_FILE" ]; then
    echo "✔ $ENV_FILE 이 이미 있습니다. 그대로 두고 빈 비밀값만 채웁니다."
  else
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    echo "📄 $ENV_FILE 을 만들었습니다 ($ENV_EXAMPLE 복사)."
  fi

  if [ -n "$(env_value N8N_ENCRYPTION_KEY)" ]; then
    echo "✔ N8N_ENCRYPTION_KEY: 이미 설정되어 있습니다."
  else
    require_docker
    # 볼륨의 config 에 키가 있는지: yes / no (볼륨이 없으면 no)
    # - 확인 자체가 실패하면 중단: 키가 없다고 잘못 보고 새로 만들면 볼륨의 키와 달라짐
    stored_key=no
    if volume_exists "$DATA_VOLUME" &&
      ! stored_key="$(docker run --rm -v "$DATA_VOLUME":/volume:ro alpine sh -c 'grep -q encryptionKey /volume/config 2>/dev/null && echo yes || echo no')"; then
      echo "❌ N8N_ENCRYPTION_KEY: $DATA_VOLUME 볼륨에 키가 있는지 확인하지 못했습니다 (alpine 이미지를 받을 수 없는 등). 해결한 뒤 다시 실행하세요."
      exit 1
    fi
    if [ "$stored_key" = yes ]; then
      echo "✔ N8N_ENCRYPTION_KEY: 비워 둡니다. $DATA_VOLUME 볼륨에 저장된 키를 그대로 씁니다."
    else
      require_cmd openssl
      fill_secret N8N_ENCRYPTION_KEY "$(new_secret)"
      echo "🔑 N8N_ENCRYPTION_KEY: 새로 만들었습니다. 잃으면 크레덴셜을 복호화할 수 없으니 따로 보관하세요."
    fi
  fi

  if [ -n "$(env_value POSTGRES_PASSWORD)" ]; then
    echo "✔ POSTGRES_PASSWORD: 이미 설정되어 있습니다."
  else
    require_docker
    require_cmd openssl
    require_env_key POSTGRES_PASSWORD
    secret="$(new_secret)"
    if volume_exists "$DB_VOLUME"; then
      sync_db_password "$secret"
      fill_secret POSTGRES_PASSWORD "$secret"
      echo "🔑 POSTGRES_PASSWORD: 새로 만들었습니다. DB 볼륨($DB_VOLUME)이 이미 있어 DB 안의 비밀번호도 새 값으로 바꿨습니다."
      if container_running n8n; then
        echo "🔄 실행 중인 n8n 을 새 비밀번호로 다시 띄웁니다..."
        compose up -d
        wait_healthy "✔ n8n 이 새 비밀번호로 다시 떴습니다."
      fi
    else
      fill_secret POSTGRES_PASSWORD "$secret"
      echo "🔑 POSTGRES_PASSWORD: 새로 만들었습니다."
    fi
  fi

  # npm ls: 설치된 내용이 package.json 과 맞지 않으면(버전 변경, 설치 중단) 실패
  require_cmd npm "Node.js 를 설치한 뒤 다시 실행하세요. ($ENV_FILE 설정은 끝났습니다)"
  if [ -x "$MCP_DIR/node_modules/.bin/n8n-mcp" ] && (cd "$MCP_DIR" && npm ls >/dev/null 2>&1); then
    echo "✔ n8n-mcp: 의존성이 이미 설치되어 있습니다."
  else
    echo "📦 n8n-mcp 의존성을 설치합니다 ($MCP_DIR, npm ci)..."
    (cd "$MCP_DIR" && npm ci)
  fi

  echo "✅ 초기 설정 완료. 다음 순서:"
  echo "   1. bin/n8n.sh start → http://localhost:$(n8n_port) 에서 관리자 계정 생성"
  echo "   2. n8n Settings > n8n API 에서 키 발급 → $ENV_FILE 의 N8N_API_KEY 에 입력 (n8n-mcp 용)"
}

case "$1" in
  init)
    init
    ;;
  start)
    echo "🚀 n8n 컨테이너를 시작합니다..."
    compose up -d
    wait_healthy "✅ n8n이 실행되었습니다. 브라우저에서 http://localhost:$(n8n_port) 에 접속하세요."
    ;;
  stop)
    echo "🛑 n8n 컨테이너를 중지합니다..."
    compose stop
    save_logs
    compose down
    echo "✅ n8n이 중지되었습니다."
    ;;
  restart)
    echo "🔄 n8n 컨테이너를 완전히 재생성하여 재시작합니다 (services/n8n/.env 환경변수 갱신)..."
    # 빌드하는 이미지가 있으면 먼저 빌드 (없으면 아무것도 안 함)
    # - 실패하면 실행 중인 컨테이너를 내리지 않고 중단
    # - Dockerfile 을 고친 내용도 여기서 반영
    compose build
    compose stop
    save_logs
    compose down && compose up -d
    wait_healthy "✅ n8n이 재시작되었습니다."
    ;;
  logs)
    compose logs -f n8n
    ;;
  status)
    compose ps
    ;;
  backup)
    require_env
    STAMP="$(date +%Y%m%d_%H%M%S)"
    N8N_BACKUP_DIR="$(backup_dir n8n "$STAMP")"
    DB_BACKUP_DIR="$(backup_dir n8n-postgres "$STAMP")"
    BACKUP_FILE="n8n_backup_${STAMP}.tar.gz"
    DB_BACKUP_FILE="n8n_db_${STAMP}.sql.gz"
    WF_BACKUP_DIR="$N8N_BACKUP_DIR/n8n_workflows_${STAMP}"
    echo "📦 n8n 데이터 볼륨($DATA_VOLUME: 암호화 키 등)을 백업합니다: $N8N_BACKUP_DIR/$BACKUP_FILE"
    docker run --rm -v "$DATA_VOLUME":/volume -v "$N8N_BACKUP_DIR":/backup alpine tar -czf "/backup/$BACKUP_FILE" -C /volume ./
    echo "📦 PostgreSQL(워크플로우·크레덴셜·실행 이력)을 덤프합니다: $DB_BACKUP_DIR/$DB_BACKUP_FILE"
    compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB"' | gzip > "$DB_BACKUP_DIR/$DB_BACKUP_FILE"
    # 워크플로우를 JSON 으로도 백업 (n8n 이 실행 중이어야 함)
    # - DB 덤프에도 있지만, 하나씩 열어 보거나 골라서 되돌릴 수 있도록
    echo "📦 워크플로우를 JSON 으로 내보냅니다 (크레덴셜 제외): $WF_BACKUP_DIR/"
    compose exec -T -u root n8n rm -rf "$WORKFLOW_TMP"
    compose exec -T n8n n8n export:workflow --backup --output="$WORKFLOW_TMP/"
    compose cp n8n:"$WORKFLOW_TMP/." "$WF_BACKUP_DIR/"
    echo "✅ 백업 완료: ${N8N_BACKUP_DIR%/*}/ (n8n/$BACKUP_FILE, n8n/n8n_workflows_${STAMP}/ $(ls "$WF_BACKUP_DIR"/*.json 2>/dev/null | wc -l | tr -d ' ')개, n8n-postgres/$DB_BACKUP_FILE)"
    ;;
  export)
    echo "📤 워크플로우를 $WORKFLOW_DIR 로 내보냅니다 (크레덴셜 제외)..."
    compose exec -T -u root n8n rm -rf "$WORKFLOW_TMP"
    compose exec -T n8n n8n export:workflow --backup --output="$WORKFLOW_TMP/"
    # 기존 JSON 을 비우고 통째로 교체 (n8n 에서 지운 워크플로우가 남지 않도록)
    rm -f "$WORKFLOW_DIR"/*.json
    compose cp n8n:"$WORKFLOW_TMP/." "$WORKFLOW_DIR/"
    echo "✅ 내보내기 완료: $(ls "$WORKFLOW_DIR"/*.json 2>/dev/null | wc -l | tr -d ' ')개"
    ;;
  import)
    echo "📥 $WORKFLOW_DIR 의 워크플로우를 n8n 으로 가져옵니다..."
    compose exec -T -u root n8n rm -rf "$WORKFLOW_TMP"
    compose cp "$WORKFLOW_DIR/." n8n:"$WORKFLOW_TMP"
    # 추가 옵션(--projectId 등)은 n8n 에 그대로 전달
    # - 일반 모드에서는 가져온 워크플로우가 전부 비활성화됨
    compose exec -T n8n n8n import:workflow --separate --input="$WORKFLOW_TMP" "${@:2}"
    echo "✅ 가져오기 완료."
    ;;
  *)
    echo "사용법: bin/n8n.sh {init|start|stop|restart|logs|status|backup|export|import}"
    exit 1
    ;;
esac
