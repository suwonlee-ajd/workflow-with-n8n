# ==========================================
# n8n 이미지 — Node.js 만 보안 패치 버전으로 교체
# ==========================================
# 이유: n8n 공식 이미지에 든 Node 가 보안 권고의 해결 버전보다 낮음
# - 권고: ASEC Node.js 보안 업데이트 권고 (2026-11-17), 26.x 는 26.13.1 이상에서 해결
# - n8n 2.44.7 은 Node 26.12.1, 최신 2.48.5·2.49.1 도 26.13.0 (2026-11-19 확인)
# 되돌릴 조건: n8n 공식 이미지가 Node 26.13.1 이상을 담으면 이 파일을 지우고 공식 이미지로 복귀
# - 방법: README '4. 버전 업그레이드'
# 버전: services/n8n/.env 의 N8N_VERSION·N8N_NODE_VERSION (compose 가 빌드 인자로 넘김)

ARG N8N_VERSION
ARG N8N_NODE_VERSION

# Node 바이너리만 가져올 이미지
# - n8n 이미지와 같은 Alpine 3.24(musl) 기반이라 그대로 실행됨
FROM node:${N8N_NODE_VERSION}-alpine AS node

FROM docker.n8n.io/n8nio/n8n:${N8N_VERSION}
ARG N8N_NODE_VERSION

# 공식 이미지의 Node 를 확인해 아래 경우 빌드 중단
# - N8N_NODE_VERSION 이상: 덮어쓰면 Node 를 낮추게 됨. 공식 이미지로 되돌릴 때
# - 메이저가 다름: n8n 의 네이티브 모듈(sqlite3·isolated-vm)과 맞지 않음
RUN node <<'EOF'
const cur = process.versions.node.split('.').map(Number);
const want = process.env.N8N_NODE_VERSION.split('.').map(Number);
if (cur[0] !== want[0]) {
  console.error(`❌ 공식 이미지 Node ${cur.join('.')} 와 N8N_NODE_VERSION ${want.join('.')} 의 메이저가 다릅니다.`);
  process.exit(1);
}
if (cur[1] > want[1] || (cur[1] === want[1] && cur[2] >= want[2])) {
  console.error(`❌ 공식 이미지 Node ${cur.join('.')} 가 N8N_NODE_VERSION ${want.join('.')} 이상입니다. Dockerfile 없이 공식 이미지로 되돌리세요 (README '4. 버전 업그레이드').`);
  process.exit(1);
}
EOF

# 실제 파일인 /usr/bin/node 를 덮어씀
# - n8n 이미지의 /usr/local/bin/node 는 /usr/bin/node 로 가는 심볼릭 링크
# - 사용자(node)·진입점(tini)은 원본 이미지 그대로
COPY --from=node /usr/local/bin/node /usr/bin/node
