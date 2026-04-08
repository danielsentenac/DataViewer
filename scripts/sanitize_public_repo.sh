#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/sanitize_public_repo.sh [--check|--apply|--restore]

Checks the repository for internal host references and optionally rewrites
known deployment examples to public placeholders.

Restore mode reads private values from `scripts/dataviewer.local.env` by
default. Override with `DATAVIEWER_LOCAL_ENV_FILE=/path/to/file`.
EOF
}

mode="${1:---check}"
case "$mode" in
  --check|--apply|--restore)
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

pattern='olserver[0-9]+([.]virgo[.]infn[.]it(:[0-9]+)?)?'
placeholder_pattern='your-tomcat-host|your-zcm-host|your-host-name|your-internal-host[.]example[.]org'
rg_args=(
  -I
  --glob '!**/.git/**'
  --glob '!**/build/**'
  --glob '!**/.tooling/**'
  --glob '!**/.dart_tool/**'
  --glob '!**/*.apk'
  --glob '!**/*.so'
  --glob '!**/*.jar'
)

mapfile -t matches < <(rg -l -e "$pattern" "${rg_args[@]}" . || true)
restore_targets=(
  "./docs/build_android_apk.md"
  "./flutter_app/README.md"
  "./tomcat-json-adapter/README.md"
  "./tomcat-json-adapter/deploy/dataviewer-context.xml.example"
  "./tomcat-json-adapter/src/main/webapp/WEB-INF/web.xml"
)

if [[ "$mode" == "--restore" ]]; then
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
  : "${DATAVIEWER_ZCM_SUB_ENDPOINT:?DATAVIEWER_ZCM_SUB_ENDPOINT must be set in $env_file}"
  : "${DATAVIEWER_PRIVATE_HOST_ALIAS:?DATAVIEWER_PRIVATE_HOST_ALIAS must be set in $env_file}"
  : "${DATAVIEWER_PRIVATE_HOST_FQDN:?DATAVIEWER_PRIVATE_HOST_FQDN must be set in $env_file}"

  mapfile -t placeholder_matches < <(rg -l -e "$placeholder_pattern" "${rg_args[@]}" "${restore_targets[@]}" || true)
  if ((${#placeholder_matches[@]} == 0)); then
    echo "No public placeholders found in restore targets."
    exit 0
  fi

  restore_expr='
s{http://your-tomcat-host:8081/dataviewer}{$ENV{DATAVIEWER_BASE_URL}}g;
s{tcp://your-zcm-host:3333}{$ENV{DATAVIEWER_ZCM_SUB_ENDPOINT}}g;
s{\byour-internal-host[.]example[.]org\b}{$ENV{DATAVIEWER_PRIVATE_HOST_FQDN}}g;
s{\byour-host-name\b}{$ENV{DATAVIEWER_PRIVATE_HOST_ALIAS}}g;
'

  echo "Restoring ${#placeholder_matches[@]} file(s) from $env_file..."
  for file in "${placeholder_matches[@]}"; do
    perl -0pi -e "$restore_expr" "$file"
  done

  echo
  echo "Post-restore placeholder check:"
  if rg -n -e "$placeholder_pattern" "${rg_args[@]}" "${restore_targets[@]}"; then
    exit 1
  fi

  echo "Repository placeholders restored from local env."
  exit 0
fi

if [[ "$mode" == "--check" ]]; then
  if ((${#matches[@]} == 0)); then
    echo "No internal host references found."
    exit 0
  fi

  echo "Internal host references found in:"
  printf '  %s\n' "${matches[@]}"
  echo
  rg -n -e "$pattern" "${rg_args[@]}" .
  exit 1
fi

if ((${#matches[@]} == 0)); then
  echo "No internal host references found."
  exit 0
fi

perl_expr='
s{http://olserver[0-9]+[.]virgo[.]infn[.]it:8081/dataviewer}{http://your-tomcat-host:8081/dataviewer}g;
s{tcp://olserver[0-9]+[.]virgo[.]infn[.]it:3333}{tcp://your-zcm-host:3333}g;
s{\bolserver[0-9]+[.]virgo[.]infn[.]it\b}{your-internal-host.example.org}g;
s{\bolserver[0-9]+\b}{your-host-name}g;
'

echo "Sanitizing ${#matches[@]} file(s)..."
for file in "${matches[@]}"; do
  perl -0pi -e "$perl_expr" "$file"
done

echo
echo "Post-sanitization check:"
if rg -n -e "$pattern" "${rg_args[@]}" .; then
  exit 1
fi

echo "Repository is sanitized."
