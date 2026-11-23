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
# - 키가 없거나 값 자리에 주석만 있으면 빈 값
env_value() {
  [ -f "$ENV_FILE" ] || return 0
  sed -n "s/^$1=//p" "$ENV_FILE" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^#.*//'
}

# .env 에 "<키>=" 줄이 없으면 중단
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

# .env 의 키에 비밀값을 써넣음
# - 사용: fill_secret <키> <값>
# - 임시 파일에 쓴 뒤 mv 로 교체: 쓰다가 끊겨도 기존 .env 가 비지 않도록
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
# - 경로: <BACKUP_DIR>/<YYYYMMDDHHMM>/<서비스명>/
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
container_running() {
  [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" = true ]
}

# n8n 컨테이너의 누적 재시작 횟수 (컨테이너가 없으면 0)
restart_count() {
  docker inspect -f '{{.RestartCount}}' n8n 2>/dev/null || echo 0
}

# n8n 이 응답할 때까지 대기
# - 사용: wait_healthy <성공 메시지>
# - /healthz/readiness: DB 연결·마이그레이션까지 끝나야 200
# - 최대 HEALTH_TIMEOUT 초 대기 (기본 120)
# - 실패: 대기 중 2회 이상 재시작했거나, 시간이 지났는데 꺼졌거나 재시작한 적이 있을 때
# - 경고만: curl 이 없거나, 시간이 지났어도 재시작 없이 실행 중일 때 (첫 기동 등)
wait_healthy() {
  local timeout="${HEALTH_TIMEOUT:-120}" port base deadline restarts=0
  local reason="${timeout}초 안에 n8n 이 응답하지 않았습니다."
  if ! command -v curl >/dev/null 2>&1; then
    echo "⚠️ curl 명령이 없어 n8n 응답을 확인하지 못했습니다. bin/n8n.sh status·logs 로 확인하세요."
    return 0
  fi
  port="$(n8n_port)"
  base="$(restart_count)"           # RestartCount 는 누적값이라 시작 시점과의 차이로 셈
  deadline=$((SECONDS + timeout))   # SECONDS: bash 내장 경과 시간
  echo "⏳ n8n 이 응답할 때까지 기다립니다 (최대 ${timeout}초)..."
  while [ "$SECONDS" -lt "$deadline" ]; do
    # --noproxy: 셸에 http_proxy 가 있어도 프록시를 거치지 않도록
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

# 명령이 없으면 중단
# - 사용: require_cmd <명령> [안내]
require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "❌ $1 명령을 찾을 수 없습니다. ${2:-설치한 뒤 다시 실행하세요.}"
    exit 1
  fi
}

# Docker 가 떠 있지 않으면 중단
# - 이유: 꺼져 있으면 볼륨이 없다고 잘못 보고 새 비밀값을 만듦
require_docker() {
  require_cmd docker
  if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker 가 실행 중이 아닙니다. Docker Desktop 을 켠 뒤 다시 실행하세요."
    exit 1
  fi
}

# DB 컨테이너를 띄운 폴더 (compose 라벨)
# - 컨테이너가 없으면 빈 값: 볼륨에는 이 라벨이 없음
db_volume_owner_dir() {
  docker inspect -f '{{index .Config.Labels "com.docker.compose.project.working_dir"}}' n8n-postgres 2>/dev/null || true
}

# DB 볼륨이 이미 있어 비밀번호를 만들지 않았을 때의 안내
# - 다른 폴더의 .env 는 경로만 알림
db_password_guide() {
  local owner
  owner="$(db_volume_owner_dir)"
  echo "❌ POSTGRES_PASSWORD: DB 볼륨($DB_VOLUME)이 이미 있어 새 비밀번호를 만들지 않았습니다."
  echo "   이 볼륨은 폴더와 상관없이 이 PC 에 하나뿐이라, 비밀번호를 바꾸면 이 볼륨을 쓰던 다른 폴더의 .env 와 맞지 않게 됩니다."
  echo "   - 쓰던 .env 가 있으면: 그 파일의 POSTGRES_PASSWORD 값을 $ENV_FILE 에 넣고 다시 실행"
  if [ -n "$owner" ] && [ "$owner" != "$ROOT/services/n8n" ]; then
    echo "     (지금 이 볼륨의 컨테이너를 띄운 폴더: $owner)"
  fi
  echo "   - 쓰던 .env 가 없으면: README '5. DB (PostgreSQL) 설정' 의 '쓰던 .env 를 잃었을 때' 순서로 DB 비밀번호를 직접 변경"
}

# 초기 설정
# - .env 가 없으면 .env.example 복사, 있으면 빈 비밀값만 채움
# - 볼륨이 이미 있을 때
#   - N8N_ENCRYPTION_KEY: 비워 둠 (n8n 이 볼륨의 키를 사용)
#   - POSTGRES_PASSWORD: 만들지 않고 안내 후 실패. 모든 clone 이 같은 DB 볼륨을 쓰므로
# - Docker·openssl 은 비밀값을 채울 때만 요구
# - n8n-mcp 의존성 설치: 실행 파일이 없거나 package.json 과 다를 때
init() {
  local stored_key db_password_pending=no
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
    # 볼륨의 config 에 키가 있는지 확인
    # - 확인에 실패하면 중단: 새로 만들면 볼륨의 키와 달라짐
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
    require_env_key POSTGRES_PASSWORD
    if ! volume_exists "$DB_VOLUME"; then
      require_cmd openssl
      fill_secret POSTGRES_PASSWORD "$(new_secret)"
      echo "🔑 POSTGRES_PASSWORD: 새로 만들었습니다."
    else
      db_password_pending=yes
      echo "⏸️ POSTGRES_PASSWORD: DB 볼륨($DB_VOLUME)이 이미 있어 비워 둡니다. 맨 아래 안내를 따르세요."
    fi
  fi

  # npm ls: 설치된 내용이 package.json 과 다르면 실패
  require_cmd npm "Node.js 를 설치한 뒤 다시 실행하세요. ($ENV_FILE 설정은 끝났습니다)"
  if [ -x "$MCP_DIR/node_modules/.bin/n8n-mcp" ] && (cd "$MCP_DIR" && npm ls >/dev/null 2>&1); then
    echo "✔ n8n-mcp: 의존성이 이미 설치되어 있습니다."
  else
    echo "📦 n8n-mcp 의존성을 설치합니다 ($MCP_DIR, npm ci)..."
    (cd "$MCP_DIR" && npm ci)
  fi

  if [ "$db_password_pending" = yes ]; then
    db_password_guide
    exit 1
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
    # 워크플로우를 JSON 으로도 백업
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
    # 기존 JSON 을 비우고 통째로 교체
    rm -f "$WORKFLOW_DIR"/*.json
    compose cp n8n:"$WORKFLOW_TMP/." "$WORKFLOW_DIR/"
    echo "✅ 내보내기 완료: $(ls "$WORKFLOW_DIR"/*.json 2>/dev/null | wc -l | tr -d ' ')개"
    ;;
  import)
    echo "📥 $WORKFLOW_DIR 의 워크플로우를 n8n 으로 가져옵니다..."
    compose exec -T -u root n8n rm -rf "$WORKFLOW_TMP"
    compose cp "$WORKFLOW_DIR/." n8n:"$WORKFLOW_TMP"
    # 추가 옵션(--projectId 등)은 n8n 에 그대로 전달
    compose exec -T n8n n8n import:workflow --separate --input="$WORKFLOW_TMP" "${@:2}"
    echo "✅ 가져오기 완료."
    ;;
  *)
    echo "사용법: bin/n8n.sh {init|start|stop|restart|logs|status|backup|export|import}"
    exit 1
    ;;
esac
