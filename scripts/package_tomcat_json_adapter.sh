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
WAR_PATH="${2:-$DIST_DIR/dataviewer-tomcat-json-adapter.war}"

SERVLET_API_JAR="${1:-}"
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
  echo "Usage: $0 <path-to-servlet-api.jar> [output-war-path]" >&2
  echo "Tip: pass $CATALINA_HOME/lib/servlet-api.jar from the target Tomcat." >&2
  exit 1
fi

rm -rf "$STAGING_DIR"
mkdir -p "$CLASSES_DIR" "$DIST_DIR"
cp -R "$WEBAPP_DIR"/. "$STAGING_DIR"/

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
