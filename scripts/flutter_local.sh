#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/flutter_local.sh <flutter args...>

Loads `scripts/dataviewer.local.env` and injects
`--dart-define=DATAVIEWER_BASE_URL=...` automatically.
EOF
}

if (($# == 0)); then
  usage >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${DATAVIEWER_LOCAL_ENV_FILE:-$repo_root/scripts/dataviewer.local.env}"

if [[ ! -f "$env_file" ]]; then
  echo "Missing local env file: $env_file" >&2
  echo "Copy scripts/dataviewer.local.env.example to scripts/dataviewer.local.env and edit it." >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "$env_file"
set +a

: "${DATAVIEWER_BASE_URL:?DATAVIEWER_BASE_URL must be set in $env_file}"

flutter_command=""
build_target=""
seen_build_command=false
for arg in "$@"; do
  if [[ "$arg" == -* ]]; then
    continue
  fi
  if [[ -z "$flutter_command" ]]; then
    flutter_command="$arg"
    if [[ "$flutter_command" == "build" ]]; then
      seen_build_command=true
      continue
    fi
    break
  fi
  if [[ "$seen_build_command" == true ]]; then
    build_target="$arg"
    break
  fi
done

for arg in "$@"; do
  if [[ "$arg" == --dart-define=DATAVIEWER_BASE_URL=* ]]; then
    cd "$repo_root/flutter_app"
    exec ../scripts/flutterw "$@"
  fi
done

cd "$repo_root/flutter_app"
if [[ "$flutter_command" == "run" || ( "$flutter_command" == "build" && -n "$build_target" ) ]]; then
  exec ../scripts/flutterw "$@" "--dart-define=DATAVIEWER_BASE_URL=$DATAVIEWER_BASE_URL"
fi

exec ../scripts/flutterw "$@"
