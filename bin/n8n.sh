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
COMPOSE_FILE="services/n8n/docker-compose.yml"
BACKUP_DIR="data/backups"         # 백업: data/backups/<날짜 YYYYMMDD>/<서비스명>/
LOG_DIR="logs"                    # 로그: logs/<YYYY>/<YYYY.MM>/<서비스명>.<YYYY-MM-DD>.log
WORKFLOW_DIR="services/n8n/workflows"
WORKFLOW_TMP="/tmp/workflows"     # export/import 때 컨테이너 안에서 쓰는 임시 경로

# compose 파일의 ${VAR} 보간도 services/n8n/.env 를 따르도록 --env-file 로 함께 넘김
compose() {
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

# 백업 폴더(data/backups/<날짜>/<서비스명>/)를 만들고 경로를 출력. 서비스명은 컨테이너 이름: n8n, n8n-postgres
# 사용: dir="$(backup_dir <서비스명> <YYYYMMDD_HHMMSS>)"
backup_dir() {
  local dir="$BACKUP_DIR/${2%%_*}/$1"
  mkdir -p "$dir"
  echo "$dir"
}

# 컨테이너 로그(Docker 가 보관)를 파일로 기록: logs/<YYYY>/<YYYY.MM>/<서비스명>.<YYYY-MM-DD>.log (날짜는 기록한 날)
# 컨테이너를 지우면(compose down) Docker 로그도 함께 사라지므로 stop·restart 가 지우기 전에 호출
# (종료 과정의 로그까지 담기도록 compose stop 뒤에 호출). 실패해도 중지·재시작은 계속 진행
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
PORT="$(sed -n 's/^N8N_PORT=//p' "$ENV_FILE" 2>/dev/null)"
PORT="${PORT:-5678}"

case "$1" in
  start)
    echo "🚀 n8n 컨테이너를 시작합니다..."
    compose up -d
    echo "✅ n8n이 실행되었습니다. 브라우저에서 http://localhost:${PORT} 에 접속하세요."
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
    compose stop
    save_logs
    compose down && compose up -d
    echo "✅ n8n이 재시작되었습니다."
    ;;
  logs)
    compose logs -f n8n
    ;;
  status)
    compose ps
    ;;
  backup)
    STAMP="$(date +%Y%m%d_%H%M%S)"
    N8N_BACKUP_DIR="$(backup_dir n8n "$STAMP")"
    DB_BACKUP_DIR="$(backup_dir n8n-postgres "$STAMP")"
    BACKUP_FILE="n8n_backup_${STAMP}.tar.gz"
    DB_BACKUP_FILE="n8n_db_${STAMP}.sql.gz"
    echo "📦 n8n 데이터 볼륨(n8n_data: 암호화 키 등)을 백업합니다: $N8N_BACKUP_DIR/$BACKUP_FILE"
    docker run --rm -v n8n_data:/volume -v "$ROOT/$N8N_BACKUP_DIR":/backup alpine tar -czf "/backup/$BACKUP_FILE" -C /volume ./
    echo "📦 PostgreSQL(워크플로우·크레덴셜·실행 이력)을 덤프합니다: $DB_BACKUP_DIR/$DB_BACKUP_FILE"
    compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB"' | gzip > "$DB_BACKUP_DIR/$DB_BACKUP_FILE"
    echo "✅ 백업 완료: $ROOT/$BACKUP_DIR/${STAMP%%_*}/ (n8n/$BACKUP_FILE, n8n-postgres/$DB_BACKUP_FILE)"
    ;;
  export)
    echo "📤 워크플로우를 $WORKFLOW_DIR 로 내보냅니다 (크레덴셜 제외)..."
    compose exec -T -u root n8n rm -rf "$WORKFLOW_TMP"
    compose exec -T n8n n8n export:workflow --backup --output="$WORKFLOW_TMP/"
    # n8n 에서 지운 워크플로우가 남지 않도록 기존 JSON 을 비우고 통째로 교체
    rm -f "$WORKFLOW_DIR"/*.json
    compose cp n8n:"$WORKFLOW_TMP/." "$WORKFLOW_DIR/"
    echo "✅ 내보내기 완료: $(ls "$WORKFLOW_DIR"/*.json 2>/dev/null | wc -l | tr -d ' ')개"
    ;;
  import)
    echo "📥 $WORKFLOW_DIR 의 워크플로우를 n8n 으로 가져옵니다..."
    compose exec -T -u root n8n rm -rf "$WORKFLOW_TMP"
    compose cp "$WORKFLOW_DIR/." n8n:"$WORKFLOW_TMP"
    # 추가 옵션(--projectId 등)은 n8n 에 그대로 전달. 일반 모드에서는 가져온 워크플로우가 전부 비활성화됨
    compose exec -T n8n n8n import:workflow --separate --input="$WORKFLOW_TMP" "${@:2}"
    echo "✅ 가져오기 완료."
    ;;
  *)
    echo "사용법: bin/n8n.sh {start|stop|restart|logs|status|backup|export|import}"
    exit 1
    ;;
esac
