#!/bin/bash

# ==========================================
# n8n-admin 대시보드 실행 스크립트
# ==========================================

set -e

# 프로젝트 루트 (bin/ 의 상위) 기준으로 경로를 잡음
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
cd "$ROOT"

ENV_FILE="services/n8n-admin/.env"
ADMIN_DIR="services/n8n-admin/admin"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ $ENV_FILE 가 없습니다. 먼저 실행: cp services/n8n-admin/.env.example $ENV_FILE 후 값 입력"
  exit 1
fi

# 대시보드(Next.js)는 admin/ 아래 env 파일만 읽으므로, n8n-admin/.env 값을 프로세스 환경변수로 넘김
# (n8n-admin 의 scripts/_common.sh 와 같은 방식으로 로드)
set -a
source "$ENV_FILE"
set +a

# 접속 주소는 NEXTAUTH_URL 하나로 관리 (없으면 http://localhost:3000)
# NEXTAUTH_URL 은 허용 호스트·로그인 주소만 정하고 실제 listen 포트는 PORT 가 정하므로, 주소에서 포트를 뽑아 맞춤
export NEXTAUTH_URL="${NEXTAUTH_URL:-http://localhost:3000}"
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
    echo "🚀 n8n-admin 대시보드를 시작합니다: $NEXTAUTH_URL"
    cd "$ADMIN_DIR"
    exec pnpm dev
    ;;
  port)
    echo "$PORT"
    ;;
  *)
    echo "사용법: bin/n8n-admin.sh {start|port}"
    exit 1
    ;;
esac
