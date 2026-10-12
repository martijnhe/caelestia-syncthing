#!/usr/bin/env python3
"""Add or remove this widget's edits in a user copy of the Caelestia shell config.

Widgets live in a shared "plugins" group on the bar, placed above the clock.
The first widget installed creates that group (modules/bar/components/PluginIcons.qml)
and the bar entry for it; each widget adds its icon to its own slot; the last one
removed takes the group away again.

Every inserted line ends with a `// plugin:<name>` marker and every replaced line
keeps the original in a `// plugin:<name> was:` comment, so widgets can coexist and
each can be reverted without touching the others.

usage: patch.py apply|revert CONFIG_DIR SHELL_JSON
"""
import base64
import json
import os
import shutil
import sys
from pathlib import Path

# ---- this widget ----
NAME = "syncthing"
STATUS = "SyncthingStatus"
POPOUT = "SyncthingPopout"
SERVICE = "Syncthing"
# (file, exact stripped line, replacement keeping indentation)
REPLACES = [
    # Let the popout take keyboard focus (text fields, shortcuts)
    ("modules/bar/popouts/Wrapper.qml",
     'when: root.isDetached || (root.hasCurrent && root.currentName === "wirelesspassword")',
     'when: root.isDetached || (root.hasCurrent && ["wirelesspassword", "syncthing"].includes(root.currentName))'),
]
# ---------------------

SLOTS = ["syncthing", "sony", "tailscale", "webcam", "screens"]
HOST_FILE = "modules/bar/components/PluginIcons.qml"
HOST = "host"
SYSTEM = Path(os.environ.get("CAELESTIA_SYSTEM_DIR", "/etc/xdg/quickshell/caelestia"))

HOST_QML = """pragma ComponentBehavior: Bound

// Bar group for the caelestia-* widgets, shown above the clock. Created by the
// first widget installer and removed with the last one. Each widget adds its
// icon after its slot line.

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.bar.components.status

StyledRect {
    id: root

    property color colour: Colours.palette.m3secondary
    readonly property alias items: iconColumn

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    clip: true
    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: iconColumn.implicitHeight + Tokens.padding.medium * 2

    ColumnLayout {
        id: iconColumn

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.medium

%SLOTS%
    }

    component Entry: Item {
        required property string name
        default property Item item

        Layout.alignment: Qt.AlignHCenter
        // Widgets can opt out of the bar with a `hidden` property (e.g. Sony when disconnected)
        visible: !(item?.hidden ?? false)
        implicitWidth: item?.implicitWidth ?? 0
        implicitHeight: item?.implicitHeight ?? 0

        children: item
    }
}
""".replace("%SLOTS%", "\n".join(f"        // slot:{s}" for s in SLOTS + ["end"]))

ENTRY = f"""\
        Entry {{
            name: "{NAME}"

            {STATUS} {{
                colour: root.colour
            }}
        }}"""

POPOUT_QML = f"""\
        Popout {{
            name: "{NAME}"
            sourceComponent: {POPOUT} {{
                popouts: root.popouts
            }}
        }}
"""

HOST_DELEGATE = """\
            DelegateChoice {
                roleValue: "plugins"
                delegate: EntryWrapper {
                    PluginIcons {
                        objectName: "taskbarPlugins"
                    }
                }
            }"""

# (file, anchor line (stripped prefix), offset from anchor, text to insert)
INSERTS = [
    ("modules/ServiceLoader.qml", "Weather.reload();", 1, f"        {SERVICE};"),
    ("modules/bar/popouts/Content.qml", 'name: "kblayout"', -1, POPOUT_QML),
    (HOST_FILE, f"// slot:{NAME if NAME in SLOTS else 'end'}", 1, ENTRY),
]

HOST_INSERTS = [
    ("modules/bar/Bar.qml", 'roleValue: "statusIcons"', -1, HOST_DELEGATE),
]

HOST_REPLACES = [
    ("modules/bar/Bar.qml",
     'if (id === "statusIcons" && Config.bar.popouts.statusIcons) {',
     'if ((id === "statusIcons" || id === "plugins") && Config.bar.popouts.statusIcons) {'),
    ("modules/bar/Bar.qml",
     "const items = (ch.item as StatusIcons).items;",
     'const items = id === "plugins" ? (ch.item as PluginIcons).items : (ch.item as StatusIcons).items;'),
]

# Files earlier versions of these installers edited; cleaned on every run
LEGACY = [
    "modules/bar/components/StatusIcons.qml",
    "modules/nexus/pages/panels/taskbar/BarStatusIcons.qml",
]

DEFAULT_ENTRIES = ["logo", "workspaces", "spacer", "activeWindow", "spacer", "tray", "clock", "statusIcons", "power"]
DEFAULT_ICONS = [("lockStatus", True), ("audio", False), ("microphone", False), ("kbLayout", False),
                 ("network", True), ("bluetooth", True), ("battery", True)]


def marker(name):
    return f"// plugin:{name}"


def revert_file(path: Path, name: str):
    if not path.exists():
        return
    out = []
    for line in path.read_text().split("\n"):
        if f"{marker(name)} was:" in line:
            indent = line[: len(line) - len(line.lstrip())]
            original = base64.b64decode(line.split(f"{marker(name)} was:", 1)[1].strip()).decode()
            out.append(indent + original)
        elif line.rstrip().endswith(marker(name)):
            continue
        else:
            out.append(line)
    path.write_text("\n".join(out))


def find_line(lines, anchor, path):
    hits = [i for i, l in enumerate(lines) if l.strip().startswith(anchor)]
    if len(hits) != 1:
        sys.exit(f"patch failed: {path}: anchor {anchor!r} found {len(hits)} times (Caelestia changed?)")
    return hits[0]


def insert(root, name, rel, anchor, offset, text):
    path = root / rel
    lines = path.read_text().split("\n")
    at = find_line(lines, anchor, rel) + offset
    new = [f"{l} {marker(name)}" if l.strip() else f"{' ' * 8}{marker(name)}" for l in text.rstrip("\n").split("\n")]
    if text.endswith("\n"):
        new.append(marker(name))
    lines[at:at] = new
    path.write_text("\n".join(lines))


def replace(root, name, rel, old, new):
    path = root / rel
    lines = path.read_text().split("\n")
    i = find_line(lines, old, rel)
    indent = lines[i][: len(lines[i]) - len(lines[i].lstrip())]
    encoded = base64.b64encode(lines[i].strip().encode()).decode()
    lines[i] = f"{indent}{new} {marker(name)} was:{encoded}"
    path.write_text("\n".join(lines))


def own_files():
    return {f for f, *_ in INSERTS} | {f for f, *_ in REPLACES} | set(LEGACY)


def host_in_use(root):
    host = root / HOST_FILE
    return host.exists() and any(
        "// plugin:" in l and marker(HOST) not in l for l in host.read_text().split("\n"))


def host_blocks(text):
    """Each widget's lines in the group file, by widget name, in order."""
    blocks = {}
    for line in text.split("\n"):
        if "// plugin:" in line and marker(HOST) not in line:
            name = line.rsplit("// plugin:", 1)[1].split()[0]
            blocks.setdefault(name, []).append(line)
    return blocks


def build_host(blocks):
    lines = []
    for line in HOST_QML.split("\n"):
        lines.append(line)
        slot = line.strip().removeprefix("// slot:") if line.strip().startswith("// slot:") else None
        if slot in SLOTS:
            lines.extend(blocks.get(slot, []))
        elif slot == "end":
            for name, block in blocks.items():
                if name not in SLOTS:
                    lines.extend(block)
    return "\n".join(lines)


def ensure_host(root):
    """Create or repair the shared bar group: the group file (refreshed to the current
    template, keeping every widget's icon) and the bar's two edits."""
    host = root / HOST_FILE
    current = host.read_text() if host.exists() else ""
    wanted = build_host(host_blocks(current))
    if wanted != current:
        host.write_text(wanted)
    # Re-apply the bar edits from scratch so a partial or stale set gets repaired.
    # If an anchor line was mangled beyond restoring, start from Caelestia's own copy
    # (only the plugins section edits these files).
    for rel in {f for f, *_ in HOST_INSERTS} | {f for f, *_ in HOST_REPLACES}:
        revert_file(root / rel, HOST)
        text = (root / rel).read_text()
        anchors = [a for f, a, *_ in HOST_INSERTS if f == rel] + [o for f, o, _ in HOST_REPLACES if f == rel]
        if any(sum(l.strip().startswith(a) for l in text.split("\n")) != 1 for a in anchors) and (SYSTEM / rel).exists():
            shutil.copy2(SYSTEM / rel, root / rel)
            print(f"Repaired {rel} from {SYSTEM}")
    for rel, anchor, offset, text in HOST_INSERTS:
        insert(root, HOST, rel, anchor, offset, text)
    for rel, old, new in HOST_REPLACES:
        replace(root, HOST, rel, old, new)


def check(root, shell_json):
    """Confirm the plugins bar section and this widget's icon are in place."""
    problems = []
    host = root / HOST_FILE
    if not host.exists():
        problems.append(f"{HOST_FILE} missing")
    elif f'name: "{NAME}"' not in host.read_text():
        problems.append(f"{NAME} icon missing from {HOST_FILE}")
    bar = (root / "modules/bar/Bar.qml").read_text()
    if 'roleValue: "plugins"' not in bar:
        problems.append("Bar.qml has no plugins section")
    if 'id === "plugins"' not in bar:
        problems.append("Bar.qml doesn't open popouts for the plugins section")
    entries = json.loads(shell_json.read_text()).get("bar", {}).get("entries", []) if shell_json.exists() else []
    plugins = [e for e in entries if e.get("id") == "plugins"]
    if not plugins:
        problems.append("shell.json bar.entries has no plugins entry")
    elif not plugins[0].get("enabled", True):
        problems.append("plugins entry is disabled in shell.json")
    if problems:
        sys.exit("Plugins bar section check failed:\n  " + "\n  ".join(problems))
    print("Plugins bar section: OK (above the clock, with the " + NAME + " icon)")


def remove_host_if_unused(root):
    if host_in_use(root):
        return False
    for rel in {f for f, *_ in HOST_INSERTS} | {f for f, *_ in HOST_REPLACES}:
        revert_file(root / rel, HOST)
    (root / HOST_FILE).unlink(missing_ok=True)
    return True


def apply(root: Path):
    # Repair the shared section first, so a failure here leaves this widget untouched
    ensure_host(root)
    for rel in own_files():
        revert_file(root / rel, NAME)
    for rel, anchor, offset, text in INSERTS:
        insert(root, NAME, rel, anchor, offset, text)
    for rel, old, new in REPLACES:
        replace(root, NAME, rel, old, new)


def update_shell_json(path: Path, add: bool, host_removed: bool):
    data = json.loads(path.read_text()) if path.exists() else {}
    bar = data.setdefault("bar", {})

    # Older versions put the icon among the status icons
    icons = bar.get("statusIcons")
    if icons:
        bar["statusIcons"] = [e for e in icons if e.get("id") not in SLOTS]

    entries = bar.get("entries") or [{"id": i, "enabled": True} for i in DEFAULT_ENTRIES]
    has_plugins = any(e.get("id") == "plugins" for e in entries)
    if add and not has_plugins:
        ids = [e.get("id") for e in entries]
        at = ids.index("clock") if "clock" in ids else len(entries)
        entries.insert(at, {"id": "plugins", "enabled": True})
    elif add:
        # Present but switched off: switch it back on
        for e in entries:
            if e.get("id") == "plugins":
                e["enabled"] = True
    elif host_removed and has_plugins:
        entries = [e for e in entries if e.get("id") != "plugins"]
    bar["entries"] = entries
    path.write_text(json.dumps(data, indent=4))


if __name__ == "__main__":
    if len(sys.argv) != 4 or sys.argv[1] not in ("apply", "revert"):
        sys.exit(__doc__)
    root, shell_json = Path(sys.argv[2]), Path(sys.argv[3])
    if sys.argv[1] == "apply":
        apply(root)
        update_shell_json(shell_json, True, False)
        check(root, shell_json)
    else:
        for rel in own_files():
            revert_file(root / rel, NAME)
        removed = remove_host_if_unused(root)
        update_shell_json(shell_json, False, removed)
