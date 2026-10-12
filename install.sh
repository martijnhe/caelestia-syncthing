#!/bin/bash
# Install this widget into a user copy of the Caelestia shell config.
# Safe to re-run, and coexists with other widgets installed the same way.
# After a caelestia-shell update: rm -rf ~/.config/quickshell/caelestia, then re-run
# the install.sh of every widget you use.
set -euo pipefail

src=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
system=/etc/xdg/quickshell/caelestia
conf=${XDG_CONFIG_HOME:-$HOME/.config}
target=$conf/quickshell/caelestia
shell_json=$conf/caelestia/shell.json

[[ -d $system ]] || { echo "caelestia-shell not found at $system" >&2; exit 1; }

if [[ ! -e $target ]]; then
  echo "Creating user copy of the Caelestia config at $target"
  cp -r -- "$system" "$target"
fi
cp -r -- "$src/files/." "$target/"
[[ -e $shell_json.pre-plugins ]] || cp -- "$shell_json" "$shell_json.pre-plugins" 2>/dev/null || true
python3 "$src/patch.py" apply "$target" "$shell_json"

echo "Installed. Restart the shell: kill \$(pgrep -x qs); qs -c caelestia -n -d"
