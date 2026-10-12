#!/bin/bash
# Remove this widget's files and edits. Other widgets stay installed.
# The user config copy is deleted once nothing differs from the system config.
set -euo pipefail

src=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
system=/etc/xdg/quickshell/caelestia
conf=${XDG_CONFIG_HOME:-$HOME/.config}
target=$conf/quickshell/caelestia
shell_json=$conf/caelestia/shell.json

[[ -d $target ]] || { echo "Nothing to remove"; exit 0; }

python3 "$src/patch.py" revert "$target" "$shell_json"
(cd -- "$src/files" && find . -type f) | while read -r f; do rm -f -- "$target/$f"; done
(cd -- "$src/files" && find . -mindepth 1 -type d | sort -r) | while read -r d; do rmdir -- "$target/$d" 2>/dev/null || true; done

if diff -rq -- "$system" "$target" >/dev/null; then
  rm -rf -- "$target"
  echo "No widgets left; removed the user config copy."
fi

echo "Removed. Restart the shell: kill \$(pgrep -x qs); qs -c caelestia -n -d"
