#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REMOTE_USER="${REMOTE_USER:-sentenac}"
REMOTE_HOST="${REMOTE_HOST:-olserver134.virgo.infn.it}"
REMOTE_TARGET="${REMOTE_USER}@${REMOTE_HOST}"
REMOTE_DEPLOY_DIR="${REMOTE_DEPLOY_DIR:-/users/${REMOTE_USER}/dataviewer-deploy}"
CATALINA_BASE="${CATALINA_BASE:-/virgoDev/TomcatApp/v0r1p3/3}"
REMOTE_JDK_HOME="${REMOTE_JDK_HOME:-/virgoApp/Tomcat/v0r1p3/jdk1.8.0_73}"
REMOTE_HTTP_PORT="${REMOTE_HTTP_PORT:-8081}"
REMOTE_HTTP_HOST_HEADER="${REMOTE_HTTP_HOST_HEADER:-olserver134.virgo.infn.it}"
FRAME_DIR="${FRAME_DIR:-/home/sentenac/TOMCAT/Fr}"
SERVLET_API_JAR="${SERVLET_API_JAR:-/tmp/javax.servlet-api-3.1.0.jar}"
REMOTE_JCHV_JAR="${REMOTE_JCHV_JAR:-$CATALINA_BASE/webapps/jchv/WEB-INF/lib/jchv.jar}"
REMOTE_JNI_LIB="${REMOTE_JNI_LIB:-$CATALINA_BASE/lib/libvirgo_frame_jni.so}"
CONTEXT_XML="${CONTEXT_XML:-$ROOT_DIR/tomcat-json-adapter/deploy/dataviewer-context.olserver134.xml}"
WAR_PATH="$ROOT_DIR/tomcat-json-adapter/build/distributions/dataviewer-tomcat-json-adapter.war"
TMP_ROOT="$(mktemp -d /tmp/dataviewer-olserver134.XXXXXX)"
REMOTE_BUILD_TGZ="$TMP_ROOT/dataviewer-remote-build.tgz"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
Deploy DataViewer backend to olserver134.

Environment overrides:
  REMOTE_USER=sentenac
  REMOTE_HOST=olserver134.virgo.infn.it
  CATALINA_BASE=/virgoDev/TomcatApp/v0r1p3/3
  REMOTE_JDK_HOME=/virgoApp/Tomcat/v0r1p3/jdk1.8.0_73
  FRAME_DIR=/home/sentenac/TOMCAT/Fr
  SERVLET_API_JAR=/tmp/javax.servlet-api-3.1.0.jar
  CONTEXT_XML=tomcat-json-adapter/deploy/dataviewer-context.olserver134.xml
  SSHPASS=<password>    Optional. If set and sshpass is installed, password auth is used.

This script:
  1. Packages the WAR with embedded META-INF/context.xml.
  2. Ships Frame sources and JNI build inputs to the remote host.
  3. Builds libvirgo_frame_jni.so on the remote host.
  4. Patches the deployed WAR with the existing jchv.jar to provide org.zeromq.ZMQ.
  5. Verifies /api/v1/diagnostics/live-catalog on the remote Tomcat.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ ! -d "$FRAME_DIR" ]]; then
  echo "Frame source directory not found: $FRAME_DIR" >&2
  exit 1
fi

if [[ ! -f "$SERVLET_API_JAR" ]]; then
  echo "Servlet API jar not found: $SERVLET_API_JAR" >&2
  exit 1
fi

if [[ ! -f "$CONTEXT_XML" ]]; then
  echo "Context XML not found: $CONTEXT_XML" >&2
  exit 1
fi

SSH_OPTS=(-o StrictHostKeyChecking=accept-new)
if [[ -n "${SSHPASS:-}" ]] && command -v sshpass >/dev/null 2>&1; then
  SSH_CMD=(sshpass -e ssh "${SSH_OPTS[@]}")
  SCP_CMD=(sshpass -e scp "${SSH_OPTS[@]}")
else
  SSH_CMD=(ssh "${SSH_OPTS[@]}")
  SCP_CMD=(scp "${SSH_OPTS[@]}")
fi

"$ROOT_DIR/scripts/package_tomcat_json_adapter.sh" \
  --context "$CONTEXT_XML" \
  "$SERVLET_API_JAR" \
  "$WAR_PATH"

REMOTE_SRC_ROOT="$TMP_ROOT/dataviewer-deploy-src"
mkdir -p "$REMOTE_SRC_ROOT/scripts" "$REMOTE_SRC_ROOT/tomcat-json-adapter/src/main/native"
cp -R "$FRAME_DIR" "$REMOTE_SRC_ROOT/Fr"
cp "$ROOT_DIR/scripts/build_virgo_frame_jni.sh" "$REMOTE_SRC_ROOT/scripts/build_virgo_frame_jni.sh"
cp "$ROOT_DIR/tomcat-json-adapter/src/main/native/virgo_frame_jni.c" \
  "$REMOTE_SRC_ROOT/tomcat-json-adapter/src/main/native/virgo_frame_jni.c"
tar -C "$TMP_ROOT" -czf "$REMOTE_BUILD_TGZ" dataviewer-deploy-src

"${SSH_CMD[@]}" "$REMOTE_TARGET" "mkdir -p '$REMOTE_DEPLOY_DIR'"
"${SCP_CMD[@]}" "$WAR_PATH" "$REMOTE_BUILD_TGZ" \
  "${REMOTE_TARGET}:${REMOTE_DEPLOY_DIR}/"

"${SSH_CMD[@]}" "$REMOTE_TARGET" "bash -lc '
set -euo pipefail
cd \"$REMOTE_DEPLOY_DIR\"
rm -rf dataviewer-deploy-src war-overlay
tar -xzf \"$(basename "$REMOTE_BUILD_TGZ")\"
JAVA_HOME=\"$REMOTE_JDK_HOME\" \
  ./dataviewer-deploy-src/scripts/build_virgo_frame_jni.sh \
  ./dataviewer-deploy-src/Fr \
  \"$CATALINA_BASE/lib\" \
  \"$REMOTE_JNI_LIB\"
mkdir -p war-overlay/WEB-INF/lib
cp \"$REMOTE_JCHV_JAR\" war-overlay/WEB-INF/lib/jchv.jar
cp dataviewer-tomcat-json-adapter.war \"$CATALINA_BASE/webapps/dataviewer.war\"
\"$REMOTE_JDK_HOME/bin/jar\" uf \"$CATALINA_BASE/webapps/dataviewer.war\" \
  -C war-overlay WEB-INF/lib/jchv.jar
for _ in 1 2 3 4 5 6 7 8 9 10; do
  sleep 2
  if curl -fsS -m 10 \
    -H \"Host: $REMOTE_HTTP_HOST_HEADER\" \
    \"http://127.0.0.1:$REMOTE_HTTP_PORT/dataviewer/api/v1/diagnostics/live-catalog\"; then
    exit 0
  fi
done
exit 1
'"

echo "Deployment completed: http://${REMOTE_HTTP_HOST_HEADER}:${REMOTE_HTTP_PORT}/dataviewer/api/v1/diagnostics/live-catalog"
