#!/usr/bin/env bash
#
# Normalise WordPress folder/file permissions
# Inspired by https://codex.wordpress.org/Hardening_WordPress#File_permissions
# Aaron Fisher – updated 2025‑07‑07
#

set -euo pipefail

#######################################
# DEFAULTS (override with flags)
#######################################
WP_OWNER="www-data"           # WordPress/PHP‑FPM user
WP_GROUP="www-data"           # primary group of WP_OWNER
WS_GROUP="$WP_GROUP"          # group the web‑server runs as
DRY_RUN=false                 # if true, only print the commands

#######################################
# HELPERS
#######################################
usage() {
  cat <<EOF
Usage: sudo $(basename "$0") [--owner USER] [--group GROUP] [--dry-run] <WP_ROOT>

  --owner USER     File owner (default: ${WP_OWNER})
  --group GROUP    File group (default: ${WP_GROUP})
  --dry-run        Show actions without executing them
  WP_ROOT          Path to WordPress root directory
EOF
  exit 1
}

run() {
  # Print the command (for transparency); run it unless DRY_RUN
  echo "+ $*"
  $DRY_RUN || "$@"
}

#######################################
# ARG PARSING
#######################################
ARGS=$(getopt -o "" -l owner:,group:,dry-run -- "$@") || usage
eval set -- "$ARGS"
while true; do
  case "$1" in
    --owner)   WP_OWNER="$2"; shift 2 ;;
    --group)   WP_GROUP="$2"; WS_GROUP="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --)        shift; break ;;
    *)         usage ;;
  esac
done
[[ $# -eq 1 ]] || usage
WP_ROOT="$(realpath "$1")"

#######################################
# PRE‑CHECKS
#######################################
[[ $EUID -eq 0 ]] || { echo "❌ This script must be run as root (use sudo)"; exit 1; }
[[ -d "$WP_ROOT" ]] || { echo "❌ $WP_ROOT does not exist"; exit 1; }
[[ -f "$WP_ROOT/wp-config.php" ]] || {
  echo "❌ $WP_ROOT doesn't look like a WordPress install (wp-config.php missing)"; exit 1; }

echo "👉 Fixing permissions in $WP_ROOT (dry‑run: $DRY_RUN)"

#######################################
# 1. SAFE DEFAULTS
#######################################
#  – Everything owner:group = WP_OWNER:WP_GROUP
#  – Directories 0755, files 0644
#######################################
echo "🔧 Setting safe defaults…"
run find "$WP_ROOT" -exec chown "${WP_OWNER}:${WP_GROUP}" {} +
run find "$WP_ROOT" -type d -exec chmod 0755 {} +
run find "$WP_ROOT" -type f -exec chmod 0644 {} +

#######################################
# 2. WORDPRESS‑MANAGED AREAS
#######################################
# make WP root and wp‑content group‑writable, setgid so new
# files inherit the group
#######################################
echo "🔧 Preparing WordPress‑managed directories…"
run chmod 0775 "$WP_ROOT"
run chmod g+s "$WP_ROOT"
run chmod -R g+s "$WP_ROOT/wp-content"

#######################################
# 3. wp-config.php – allow WP to edit but keep world out
#######################################
echo "🔧 Adjusting wp-config.php…"
run chgrp "$WS_GROUP" "$WP_ROOT/wp-config.php"
run chmod 0660      "$WP_ROOT/wp-config.php"

#######################################
# 4. wp-content – WordPress writes here
#######################################
echo "🔧 Setting wp-content permissions…"
run find "$WP_ROOT/wp-content" -exec chgrp "$WS_GROUP" {} +
run find "$WP_ROOT/wp-content" -type d -exec chmod 0775 {} +
run find "$WP_ROOT/wp-content" -type f -exec chmod 0664 {} +

# Ensure cache directory exists & readable
CACHE_DIR="$WP_ROOT/wp-content/cache"
if [[ ! -d "$CACHE_DIR" ]]; then
  echo "🔧 Creating cache directory…"
  run mkdir -p "$CACHE_DIR"
fi
run find "$CACHE_DIR" -type d -exec chmod 0755 {} +

echo "✅ All done!"
$DRY_RUN && echo " (nothing actually changed – dry‑run mode)"