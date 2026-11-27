#!/bin/bash

# ==========================================
# n8n-admin 대시보드 관리 스크립트
# ==========================================

set -e
set -o pipefail                          # 파이프 중간 명령(sed 등)이 실패해도 멈추도록

# 프로젝트 루트 (bin/ 의 상위) 기준으로 경로를 잡음
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
cd "$ROOT"

ENV_FILE="services/n8n-admin/.env"
ADMIN_DIR="services/n8n-admin/admin"     # 대시보드(Next.js) 폴더
DEFAULT_URL="http://localhost:3000"      # NEXTAUTH_URL 이 없을 때의 접속 주소
SELF_CMD="${CALLED_AS:-bin/n8n-admin.sh}" # 안내 문구의 실행 명령 (.bat 으로 실행하면 그 .bat)

# 대시보드(Next.js)는 admin/ 아래 env 파일만 읽으므로, n8n-admin/.env 값을 프로세스 환경변수로 넘김
load_env() {
  local env_text
  if [ ! -f "$ENV_FILE" ]; then
    echo "❌ $ENV_FILE 가 없습니다. 먼저 실행: cp services/n8n-admin/.env.example $ENV_FILE 후 값 입력"
    exit 1
  fi
  # CR 을 지운 내용을 변수에 먼저 담음
  # - CRLF 로 저장한 .env 대비: 값 끝에 CR 이 붙으면 NEXTAUTH_URL 불일치로 404
  # - 파일을 못 읽으면 이 대입에서 set -e 로 중단
  env_text="$(tr -d '\r' < "$ENV_FILE")"
  set -a
  # macOS 기본 bash 3.2 는 source <(...) 를 읽지 못해 /dev/stdin 사용
  source /dev/stdin <<< "$env_text"
  set +a
}

load_env

# 접속 주소는 services/n8n-admin/.env 의 NEXTAUTH_URL 하나로 관리 (없으면 DEFAULT_URL)
# NEXTAUTH_URL 은 허용 호스트·로그인 주소만 정하고 실제 listen 포트는 PORT 가 정하므로, 주소에서 포트를 뽑아 맞춤
export NEXTAUTH_URL="${NEXTAUTH_URL:-$DEFAULT_URL}"
PORT="$(printf '%s' "$NEXTAUTH_URL" | sed -nE 's#^[a-z]+://[^:/]+:([0-9]+).*#\1#p')"
if [ -z "$PORT" ]; then
  echo "❌ NEXTAUTH_URL 에 포트가 없습니다: $NEXTAUTH_URL (예: http://localhost:50999)"
  exit 1
fi
export PORT

case "$1" in
  start)
    if [ ! -d "$ADMIN_DIR/node_modules" ]; then
      echo "❌ 의존성이 설치되지 않았습니다. 먼저 실행: (cd $ADMIN_DIR && pnpm install)"
      exit 1
    fi
    echo "🚀 n8n-admin 대시보드를 시작합니다..."
    echo "✅ 브라우저에서 $NEXTAUTH_URL 에 접속하세요. (종료: Ctrl+C)"
    cd "$ADMIN_DIR"
    exec pnpm dev
    ;;
  port)
    echo "$PORT"
    ;;
  *)
    echo "사용법: $SELF_CMD {start|port}"
    exit 1
    ;;
esac
