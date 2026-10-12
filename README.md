# Caelestia Syncthing widget

A Syncthing status icon and popout for the [Caelestia shell](https://github.com/caelestia-dots/shell) bar,
a port of the Omarchy [syncshell](https://github.com/omarchy-QOL/syncshell) plugin's features. Pure QML: it
talks to Syncthing's local REST API (address and API key from Syncthing's `config.xml`) and its event
stream. No extra binaries.

Built against `caelestia-shell` 2.5.0 and `quickshell-git` 0.3.1.

## Features

**Bar icon**: the Syncthing logo. Spins while syncing, scanning or uploading; a red dot on folder
errors, an accent dot when a device or folder offer is waiting; dimmed when Syncthing is off.
Branded (full-colour logo) or themed (logo tinted to the bar colour). The popout header shows the logo too.

**Header**: start/stop the `syncthing` user service, device and problem summary, settings.

**Folders**
- search and filter (all, syncing, problems, unlinked)
- status per folder: up to date with size and share count, syncing with bytes left, errors
- open the directory (click its name), rescan, link/unlink (pause/resume)
- **forget** an unlinked folder (removes config, keeps files), with confirmation
- **+** add a folder: path (or browse), label, generated folder ID, devices to share with;
  missing directories need confirmation, overlapping paths are rejected
- **share** icon: choose which devices share a folder
- incoming folder offers: accept (fills the add form with the same folder ID) or ignore

**Devices**
- this device's name and ID with copy button
- devices asking to connect: accept (fills the add form) or ignore, with confirmation
- remote devices: connection state, sync completion, shared folder count
- per device: manage shared folders, pause/resume, copy ID, remove (with confirmation)
- pause/resume all, **+** add a device by ID (validated by Syncthing)

**Activity**: live file changes. Blue = synced or added, red = deleted or failed,
green = a remote device downloading from this one. Click a file to open its folder.

**More**: per-file folder errors, on-demand search for `.sync-conflict` files,
installation details (version, service state, API address, config path), and an
**Install Syncthing** button when it's missing (`pkexec pacman`, then enables the user service).

**Notifications**: toasts for folder errors, new device requests, folder offers and failed actions.

**Keys** (click the popout first to give it focus): `r` rescan all, `w` web UI, `p` start/stop,
`s` settings, `q`/`esc` back or close.

**Settings** (in the popout, stored in `~/.config/caelestia/syncthing.json`): icon style,
notifications, number of activity entries.

Not ported: syncshell's bundled redesigned Web UI and its Omarchy theme sync. The **Web UI**
button opens Syncthing's own interface.

## Install

```bash
./install.sh
kill $(pgrep -x qs); qs -c caelestia -n -d
```

This adds the widget to the user copy of the Caelestia config at `~/.config/quickshell/caelestia`
(created from `/etc/xdg/quickshell/caelestia` if missing), patches five existing files with marked
lines (see `patch.py`) and adds its icon to a shared widget group above the clock (bar entry `plugins` in
`~/.config/caelestia/shell.json`).
It coexists with other widgets installed the same way (like [caelestia-sony](../caelestia-sony)).

After a `caelestia-shell` update, rebuild the copy so it picks up the new version:

```bash
rm -rf ~/.config/quickshell/caelestia
~/Projects/caelestia-syncthing/install.sh
~/Projects/caelestia-sony/install.sh
~/Projects/caelestia-tailscale/install.sh
~/Projects/caelestia-webcam/install.sh
~/Projects/caelestia-screens/install.sh
```

Every install checks the shared **plugins** bar section (the widget group above the clock) and
creates or repairs it if any part is missing: the group file, the two edits in `Bar.qml` (restored
from Caelestia's own copy if they were mangled), and an enabled `plugins` entry in `bar.entries`.
It ends with `Plugins bar section: OK`, or stops and says what's wrong.

## Uninstall

```bash
./uninstall.sh
```

Removes this widget's files, its marked edits and its bar entry. Other widgets stay; the user
config copy is deleted once nothing differs from the system config.

## Files

| File | Purpose |
| --- | --- |
| `files/services/Syncthing.qml` | Singleton: API client, event stream, actions, settings, popout UI state |
| `files/modules/bar/components/status/SyncthingStatus.qml` | Bar icon |
| `files/modules/bar/popouts/SyncthingPopout.qml` | Popout shell: header, tabs, keys, footer |
| `files/modules/bar/popouts/syncthing/` | Pages, forms and small components |
| `files/assets/syncthing/` | Syncthing logos (colour and mono) |
| `patch.py` | Adds/removes the marked edits to Caelestia files |

## Credits

Syncthing logo SVGs from [selfh.st/icons](https://selfh.st/icons/) (CC BY 4.0).
Syncthing and its logo belong to the Syncthing Foundation.
