#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE_DIR="$ROOT_DIR/tomcat-json-adapter"
WEBAPP_DIR="$MODULE_DIR/src/main/webapp"
JAVA_SRC_DIR="$MODULE_DIR/src/main/java"
BUILD_DIR="$MODULE_DIR/build"
STAGING_DIR="$BUILD_DIR/war-staging"
CLASSES_DIR="$STAGING_DIR/WEB-INF/classes"
DIST_DIR="$BUILD_DIR/distributions"
CONTEXT_XML=""
RUNTIME_LIBS=()
POSITIONAL_ARGS=()

usage() {
  cat <<'EOF'
Usage: package_tomcat_json_adapter.sh [--context <path>] [--runtime-lib <path>]... <path-to-servlet-api.jar> [output-war-path]

Options:
  --context <path>      Copy the given Tomcat context XML into META-INF/context.xml inside the WAR.
  --runtime-lib <path>  Copy an extra runtime jar into WEB-INF/lib inside the WAR. Repeat as needed.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context)
      if [[ $# -lt 2 ]]; then
        usage >&2
        exit 1
      fi
      CONTEXT_XML="$2"
      shift 2
      ;;
    --runtime-lib)
      if [[ $# -lt 2 ]]; then
        usage >&2
        exit 1
      fi
      RUNTIME_LIBS+=("$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      POSITIONAL_ARGS+=("$@")
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#POSITIONAL_ARGS[@]} -gt 2 ]]; then
  usage >&2
  exit 1
fi

WAR_PATH="${POSITIONAL_ARGS[1]:-$DIST_DIR/dataviewer-tomcat-json-adapter.war}"

SERVLET_API_JAR="${POSITIONAL_ARGS[0]:-}"
if [[ -z "$SERVLET_API_JAR" ]]; then
  if [[ -n "${CATALINA_HOME:-}" && -f "$CATALINA_HOME/lib/servlet-api.jar" ]]; then
    SERVLET_API_JAR="$CATALINA_HOME/lib/servlet-api.jar"
  elif [[ -n "${CATALINA_BASE:-}" && -f "$CATALINA_BASE/lib/servlet-api.jar" ]]; then
    SERVLET_API_JAR="$CATALINA_BASE/lib/servlet-api.jar"
  elif [[ -f "/tmp/javax.servlet-api-3.1.0.jar" ]]; then
    SERVLET_API_JAR="/tmp/javax.servlet-api-3.1.0.jar"
  fi
fi

if [[ -z "$SERVLET_API_JAR" || ! -f "$SERVLET_API_JAR" ]]; then
  usage >&2
  echo "Tip: pass $CATALINA_HOME/lib/servlet-api.jar from the target Tomcat." >&2
  exit 1
fi

if [[ -n "$CONTEXT_XML" && ! -f "$CONTEXT_XML" ]]; then
  echo "Context XML not found: $CONTEXT_XML" >&2
  exit 1
fi

for runtime_lib in "${RUNTIME_LIBS[@]}"; do
  if [[ ! -f "$runtime_lib" ]]; then
    echo "Runtime library not found: $runtime_lib" >&2
    exit 1
  fi
done

rm -rf "$STAGING_DIR"
mkdir -p "$CLASSES_DIR" "$DIST_DIR"
cp -R "$WEBAPP_DIR"/. "$STAGING_DIR"/

if [[ -n "$CONTEXT_XML" ]]; then
  mkdir -p "$STAGING_DIR/META-INF"
  cp "$CONTEXT_XML" "$STAGING_DIR/META-INF/context.xml"
fi

if [[ ${#RUNTIME_LIBS[@]} -gt 0 ]]; then
  mkdir -p "$STAGING_DIR/WEB-INF/lib"
  for runtime_lib in "${RUNTIME_LIBS[@]}"; do
    cp "$runtime_lib" "$STAGING_DIR/WEB-INF/lib/"
  done
fi

mapfile -t JAVA_SOURCES < <(find "$JAVA_SRC_DIR" -type f -name '*.java' | sort)
if [[ ${#JAVA_SOURCES[@]} -eq 0 ]]; then
  echo "No Java sources found under $JAVA_SRC_DIR" >&2
  exit 1
fi

javac \
  -source 1.8 \
  -target 1.8 \
  -encoding UTF-8 \
  -cp "$SERVLET_API_JAR" \
  -d "$CLASSES_DIR" \
  "${JAVA_SOURCES[@]}"

jar cf "$WAR_PATH" -C "$STAGING_DIR" .

echo "$WAR_PATH"
