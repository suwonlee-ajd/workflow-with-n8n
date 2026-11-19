# check=skip=InvalidDefaultArgInFrom
# ==========================================
# n8n 이미지 — Node.js 만 보안 패치 버전으로 교체
# ==========================================
# 이 주석이 교체 이유·되돌릴 조건의 원본 (README·docs 는 여기를 가리킴)
# 이유: n8n 공식 이미지에 든 Node 가 보안 권고의 해결 버전보다 낮음
# - 권고: ASEC Node.js 보안 업데이트 권고 (2026-11-17, https://asec.ahnlab.com/ko/96589/)
# - 해결 버전: 22.23.5·24.22.3·26.13.1 이상
# - n8n 2.44.7 은 Node 26.12.1, 최신 2.48.5·2.49.1·nightly 도 26.13.0 (2026-11-19 확인)
# 되돌릴 조건: 공식 이미지의 Node 가 보안 권고의 해결 버전 이상이면 이 파일을 지우고 공식 이미지로 복귀
# - 같은 메이저에서 N8N_NODE_VERSION 이상이 되면 아래 확인 단계가 빌드를 멈춤
# - 방법: README '4. 버전 업그레이드'
# 버전: services/n8n/.env 의 N8N_VERSION·N8N_NODE_VERSION (compose 가 빌드 인자로 넘김)
# - 기본값이 없어 맨 위에서 InvalidDefaultArgInFrom 검사를 끔
# 스캐너 주의: 이미지의 apk 기록은 원래 버전 그대로라 취약으로 나올 수 있음
# - 실제 버전은 docker exec n8n node -v 로 확인

ARG N8N_VERSION
ARG N8N_NODE_VERSION

# Node 바이너리만 가져올 이미지
# - n8n 이미지와 같은 Alpine 3.24(musl)로 고정: 다른 Alpine 용 바이너리는 실행되지 않을 수 있음
# - n8n 이미지의 Alpine 이 바뀌면 이 값도 맞춤
FROM node:${N8N_NODE_VERSION}-alpine3.24 AS node

FROM docker.n8n.io/n8nio/n8n:${N8N_VERSION}
ARG N8N_NODE_VERSION

# 공식 이미지의 Node 를 확인해 아래 경우 빌드 중단
# - N8N_NODE_VERSION 이 x.y.z 형식이 아님
# - 메이저가 다름: n8n 의 네이티브 모듈(sqlite3·isolated-vm)과 맞지 않음
# - N8N_NODE_VERSION 이상: 덮어쓰면 Node 를 낮추게 됨
RUN node <<'EOF'
const cur = process.versions.node, want = process.env.N8N_NODE_VERSION;
const stop = (msg) => { console.error(`❌ 공식 이미지 Node ${cur}, N8N_NODE_VERSION ${want}: ${msg} (README '4. 버전 업그레이드')`); process.exit(1); };
if (!/^\d+\.\d+\.\d+$/.test(want)) stop('N8N_NODE_VERSION 은 x.y.z 형식이어야 합니다.');
const [c, w] = [cur, want].map((v) => v.split('.').map(Number));
if (c[0] !== w[0]) stop('메이저가 다릅니다. 공식 이미지의 Node 가 이미 해결 버전이면 공식 이미지로 되돌리고, 아니면 N8N_NODE_VERSION 을 같은 메이저의 해결 버전으로 바꾸세요.');
if ((c[1] - w[1] || c[2] - w[2]) >= 0) stop('공식 이미지의 Node 가 같거나 더 높습니다. Dockerfile 없이 공식 이미지로 되돌리세요.');
EOF

# node 를 덮어씀
# - 대상이 심볼릭 링크면 BuildKit 이 링크를 따라가 실제 파일을 덮어씀
# - 실제 파일이 /usr/bin/node 인 2.44.7, /usr/local/bin/node 인 nightly 모두 확인
# - 사용자(node)·진입점(tini)은 원본 이미지 그대로
COPY --from=node /usr/local/bin/node /usr/bin/node

# 교체 결과 확인: PATH 의 node 가 N8N_NODE_VERSION 이 아니면 빌드 중단
RUN [ "$(node -v)" = "v${N8N_NODE_VERSION}" ] || { echo "❌ 교체 뒤 node -v 가 $(node -v 2>&1) 입니다. 기대값: v${N8N_NODE_VERSION}"; exit 1; }

# 환경 변수 NODE_VERSION 을 실제 버전으로 맞춤
# - 공식 이미지 값은 교체 전 버전이라 점검할 때 헷갈림
ENV NODE_VERSION=${N8N_NODE_VERSION}
