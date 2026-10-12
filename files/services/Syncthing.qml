pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.I18n

// Talks to the local Syncthing REST API using the GUI address and API key
// from Syncthing's own config.xml. Also holds the popout's UI state so it
// survives the popout being unloaded when the pointer leaves the bar.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || `${home}/.config`
    readonly property list<string> configPaths: {
        const state = Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`;
        return [`${state}/syncthing/config.xml`, `${configHome}/syncthing/config.xml`];
    }
    property int configIndex: 0
    readonly property string configPath: configPaths[configIndex]

    // Connection
    property string apiKey
    property string baseUrl: "http://127.0.0.1:8384"
    property bool online: false
    property bool installed: true
    property string serviceState: "unknown"
    readonly property bool externallyManaged: online && serviceState !== "active" && serviceState !== "activating"
    property bool busy: false
    property string version
    property string myId
    property string myName

    // Data
    property list<var> folders: []
    property list<var> devices: []
    property list<var> pendingDevices: []
    property list<var> pendingFolders: []
    property var folderErrors: ({})
    property list<var> activity: []
    property var uploadMap: ({})
    readonly property list<var> uploads: Object.keys(uploadMap).map(k => uploadMap[k]).filter(u => u.files.length > 0)
    property list<string> conflicts: []
    property bool conflictScanRunning: false
    property bool conflictScanDone: false

    readonly property int syncingCount: folders.filter(f => !f.paused && isBusyState(f.state)).length
    readonly property int problemCount: folders.filter(f => !f.paused && (f.state === "error" || f.errors > 0)).length
    readonly property int connectedCount: devices.filter(d => d.connected).length
    readonly property int pendingCount: pendingDevices.length + pendingFolders.length
    readonly property bool syncing: online && (syncingCount > 0 || uploads.length > 0)

    // UI state
    property string page: "folders" // folders | devices | activity | more | settings
    property string form: "" // addFolder | shareFolder | addDevice | deviceFolders
    property string formTarget
    property var confirm: null // { kind, id, extra, title, body, action }
    property string query
    property string filter: "all" // all | syncing | problems | paused
    property string lastError
    property var folderDraft: ({ id: "", label: "", path: "", devices: [] })
    property var deviceDraft: ({ id: "", name: "" })
    property list<string> shareDraft: []

    property alias settings: settingsAdapter

    // Logos from selfh.st/icons (CC BY 4.0)
    readonly property url logo: Qt.resolvedUrl("../assets/syncthing/syncthing.svg")
    readonly property url logoMono: Qt.resolvedUrl("../assets/syncthing/syncthing-dark.svg")

    // Events
    property int lastEventId: -1
    property var eventXhr: null
    readonly property string eventTypes: ["LocalChangeDetected", "ItemFinished", "RemoteDownloadProgress", "StateChanged", "FolderSummary", "FolderCompletion", "FolderErrors", "DeviceConnected", "DeviceDisconnected", "DevicePaused", "DeviceResumed", "FolderPaused", "FolderResumed", "ConfigSaved", "PendingDevicesChanged", "PendingFoldersChanged"].join(",")

    // ---------- Helpers ----------

    function isBusyState(state: string): bool {
        return ["scanning", "syncing", "sync-preparing", "cleaning"].includes(state);
    }

    function formatBytes(bytes: real): string {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (bytes >= 1024 && i < units.length - 1) {
            bytes /= 1024;
            i++;
        }
        return `${bytes.toFixed(i === 0 || bytes >= 10 ? 0 : 1)} ${units[i]}`;
    }

    function relativeTime(time: real): string {
        const s = Math.max(0, Math.round((Date.now() - time) / 1000));
        if (s < 60)
            return Tr.tr("now");
        if (s < 3600)
            return Tr.tr("%1m").arg(Math.floor(s / 60));
        if (s < 86400)
            return Tr.tr("%1h").arg(Math.floor(s / 3600));
        return Tr.tr("%1d").arg(Math.floor(s / 86400));
    }

    function expandPath(path: string): string {
        path = path.trim();
        if (path === "~")
            return home;
        if (path.startsWith("~/"))
            path = home + path.slice(1);
        while (path.length > 1 && path.endsWith("/"))
            path = path.slice(0, -1);
        return path;
    }

    function displayPath(path: string): string {
        return path.startsWith(home + "/") ? `~${path.slice(home.length)}` : path;
    }

    function deviceName(id: string): string {
        if (id === myId)
            return myName || Tr.tr("This device");
        return devices.find(d => d.id === id)?.name ?? id.slice(0, 7);
    }

    function folderLabel(id: string): string {
        return folders.find(f => f.id === id)?.label ?? id;
    }

    function generateFolderId(): string {
        const chars = "abcdefghijklmnopqrstuvwxyz0123456789";
        const part = () => Array.from({
                length: 5
            }, () => chars[Math.floor(Math.random() * chars.length)]).join("");
        return `${part()}-${part()}`;
    }

    function overlappingFolder(path: string): var {
        return folders.find(f => {
            const other = expandPath(f.path);
            return other === path || path.startsWith(other + "/") || other.startsWith(path + "/");
        }) ?? null;
    }

    function fail(message: string): void {
        lastError = message;
        if (settings.notifications)
            Toaster.toast(Tr.tr("Syncthing"), message, "sync_problem", Toast.Error);
    }

    function request(method: string, path: string, body: var, onSuccess: var, onError: var): var {
        if (!apiKey) {
            onError?.(Tr.tr("Syncthing API key not found"));
            return null;
        }

        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status >= 200 && xhr.status < 300) {
                let data = null;
                try {
                    data = xhr.responseText ? JSON.parse(xhr.responseText) : null;
                } catch (e) {}
                onSuccess?.(data);
            } else {
                onError?.(xhr.status === 0 ? Tr.tr("Syncthing is not reachable") : (xhr.responseText || `HTTP ${xhr.status}`).trim());
            }
        };
        xhr.open(method, baseUrl + path);
        xhr.setRequestHeader("X-API-Key", apiKey);
        if (body !== undefined && body !== null) {
            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.send(JSON.stringify(body));
        } else {
            xhr.send();
        }
        return xhr;
    }

    // Mutating request: report errors, refresh afterwards
    function mutate(method: string, path: string, body: var, onSuccess: var): void {
        request(method, path, body, data => {
            lastError = "";
            onSuccess?.(data);
            scheduleRefresh();
        }, err => {
            fail(err);
            scheduleRefresh();
        });
    }

    function scheduleRefresh(): void {
        refreshDebounce.restart();
    }

    // ---------- Polling ----------

    function refresh(): void {
        serviceCheck.running = true;

        request("GET", "/rest/config/folders", null, cfg => {
            if (!online) {
                online = true;
                startEvents();
            }
            const out = (cfg ?? []).map(f => ({
                        id: f.id,
                        label: f.label || f.id,
                        path: f.path,
                        type: f.type,
                        paused: f.paused,
                        devices: (f.devices ?? []).map(d => d.deviceID).filter(d => d !== myId),
                        state: f.paused ? "paused" : (folders.find(o => o.id === f.id)?.state ?? "unknown"),
                        globalBytes: 0,
                        needBytes: 0,
                        needFiles: 0,
                        errors: 0
                    }));
            let pending = out.length;
            if (pending === 0)
                folders = [];
            const done = () => {
                if (--pending === 0) {
                    folders = out;
                    refreshFolderErrors();
                }
            };
            out.forEach(f => request("GET", `/rest/db/status?folder=${encodeURIComponent(f.id)}`, null, st => {
                    if (!f.paused)
                        f.state = st.state || "unknown";
                    f.globalBytes = st.globalBytes ?? 0;
                    f.needBytes = st.needBytes ?? 0;
                    f.needFiles = (st.needFiles ?? 0) + (st.needDeletes ?? 0);
                    f.errors = (st.errors ?? 0) + (st.pullErrors ?? 0);
                    done();
                }, done));
        }, () => {
            if (online) {
                online = false;
                stopEvents();
            }
            folders = [];
            devices = [];
            pendingDevices = [];
            pendingFolders = [];
            uploadMap = {};
        });

        request("GET", "/rest/system/version", null, v => version = v?.version ?? "");

        request("GET", "/rest/system/status", null, st => {
            myId = st.myID ?? "";
            request("GET", "/rest/config/devices", null, cfg => {
                myName = (cfg ?? []).find(d => d.deviceID === myId)?.name ?? "";
                request("GET", "/rest/system/connections", null, conns => {
                    const c = conns?.connections ?? {};
                    const list = (cfg ?? []).filter(d => d.deviceID !== myId).map(d => ({
                                id: d.deviceID,
                                name: d.name || d.deviceID.slice(0, 7),
                                paused: d.paused,
                                connected: c[d.deviceID]?.connected ?? false,
                                address: c[d.deviceID]?.address ?? "",
                                completion: devices.find(o => o.id === d.deviceID)?.completion ?? -1
                            }));
                    devices = list;
                    list.filter(d => d.connected).forEach(d => request("GET", `/rest/db/completion?device=${encodeURIComponent(d.id)}`, null, comp => {
                            const updated = devices.map(o => o.id === d.id ? Object.assign({}, o, {
                                        completion: comp?.completion ?? -1
                                    }) : o);
                            devices = updated;
                        }));
                });
            });
        });

        request("GET", "/rest/cluster/pending/devices", null, pd => {
            pendingDevices = Object.keys(pd ?? {}).map(id => ({
                        id,
                        name: pd[id].name || id.slice(0, 7),
                        address: pd[id].address ?? "",
                        time: pd[id].time
                    }));
        });

        request("GET", "/rest/cluster/pending/folders", null, pf => {
            const out = [];
            for (const folderId of Object.keys(pf ?? {})) {
                const offeredBy = pf[folderId].offeredBy ?? {};
                for (const deviceId of Object.keys(offeredBy)) {
                    const o = offeredBy[deviceId];
                    out.push({
                        id: folderId,
                        label: o.label || folderId,
                        deviceId,
                        encrypted: o.receiveEncrypted || o.remoteEncrypted,
                        time: o.time
                    });
                }
            }
            pendingFolders = out;
        });
    }

    function refreshFolderErrors(): void {
        const errs = {};
        const withErrors = folders.filter(f => f.errors > 0);
        if (withErrors.length === 0) {
            folderErrors = {};
            return;
        }
        let pending = withErrors.length;
        withErrors.forEach(f => request("GET", `/rest/folder/errors?folder=${encodeURIComponent(f.id)}`, null, e => {
                errs[f.id] = (e?.errors ?? []).map(x => ({
                            path: x.path,
                            error: x.error
                        }));
                if (--pending === 0)
                    folderErrors = errs;
            }, () => {
                if (--pending === 0)
                    folderErrors = errs;
            }));
    }

    // ---------- Events (live activity) ----------

    function startEvents(): void {
        stopEvents();
        // Fetch only the latest event to learn the current id
        eventXhr = request("GET", "/rest/events?since=0&limit=1&timeout=0", null, evs => {
            lastEventId = evs?.length ? evs[evs.length - 1].id : 0;
            pollEvents();
        }, () => eventRetry.restart());
    }

    function stopEvents(): void {
        if (eventXhr) {
            eventXhr.onreadystatechange = null;
            eventXhr.abort();
            eventXhr = null;
        }
        lastEventId = -1;
    }

    function pollEvents(): void {
        if (!online || lastEventId < 0)
            return;
        eventXhr = request("GET", `/rest/events?since=${lastEventId}&timeout=60&events=${eventTypes}`, null, evs => {
            for (const ev of evs ?? []) {
                lastEventId = Math.max(lastEventId, ev.id);
                handleEvent(ev);
            }
            pollEvents();
        }, () => {
            lastEventId = -1;
            eventRetry.restart();
        });
    }

    function pushActivity(entry: var): void {
        entry.time = Date.now();
        entry.key = `${entry.time}-${Math.random()}`;
        // Collapse repeats of the same file and kind
        const rest = activity.filter(a => !(a.folder === entry.folder && a.path === entry.path && a.kind === entry.kind));
        activity = [entry, ...rest].slice(0, Math.max(5, settings.activityLimit));
    }

    function handleEvent(ev: var): void {
        const d = ev.data ?? {};
        switch (ev.type) {
        case "LocalChangeDetected":
            pushActivity({
                folder: d.folder,
                path: d.path,
                kind: d.action === "deleted" ? "delete" : "add",
                detail: d.action === "deleted" ? Tr.tr("Deleted locally") : d.action === "added" ? Tr.tr("Added locally") : Tr.tr("Changed locally")
            });
            break;
        case "ItemFinished":
            pushActivity({
                folder: d.folder,
                path: d.item,
                kind: d.error ? "error" : d.action === "delete" ? "delete" : "add",
                detail: d.error ? d.error : d.action === "delete" ? Tr.tr("Deleted by sync") : Tr.tr("Synced")
            });
            break;
        case "RemoteDownloadProgress":
            {
                const key = `${d.device}|${d.folder}`;
                const files = Object.keys(d.state ?? {});
                const map = Object.assign({}, uploadMap);
                const before = map[key]?.files ?? [];
                map[key] = {
                    device: d.device,
                    folder: d.folder,
                    files
                };
                uploadMap = map;
                for (const f of files.filter(f => !before.includes(f)))
                    pushActivity({
                        folder: d.folder,
                        path: f,
                        kind: "upload",
                        detail: Tr.tr("Uploading to %1").arg(deviceName(d.device))
                    });
            }
            break;
        case "StateChanged":
            folders = folders.map(f => f.id === d.folder ? Object.assign({}, f, {
                    state: d.to
                }) : f);
            if (d.to === "error" && settings.notifications)
                Toaster.toast(Tr.tr("Syncthing folder error"), Tr.tr("%1 stopped: %2").arg(folderLabel(d.folder)).arg(d.error ?? ""), "sync_problem", Toast.Error);
            break;
        case "PendingDevicesChanged":
            if (settings.notifications)
                for (const a of d.added ?? [])
                    Toaster.toast(Tr.tr("New Syncthing device"), Tr.tr("%1 wants to connect").arg(a.name || a.deviceID.slice(0, 7)), "devices", Toast.Info);
            scheduleRefresh();
            break;
        case "PendingFoldersChanged":
            if (settings.notifications)
                for (const a of d.added ?? [])
                    Toaster.toast(Tr.tr("Syncthing folder offered"), Tr.tr("%1 shares “%2”").arg(deviceName(a.deviceID)).arg(a.folderLabel || a.folderID), "create_new_folder", Toast.Info);
            scheduleRefresh();
            break;
        default:
            scheduleRefresh();
        }
    }

    // ---------- Folder actions ----------

    function rescan(id: string): void {
        mutate("POST", `/rest/db/scan?folder=${encodeURIComponent(id)}`, null);
    }

    function rescanAll(): void {
        if (online)
            mutate("POST", "/rest/db/scan", null);
    }

    function setFolderPaused(id: string, paused: bool): void {
        mutate("PATCH", `/rest/config/folders/${encodeURIComponent(id)}`, {
            paused
        });
    }

    function forgetFolder(id: string): void {
        mutate("DELETE", `/rest/config/folders/${encodeURIComponent(id)}`, null);
    }

    function setFolderDevices(id: string, deviceIds: var): void {
        const ids = [myId, ...deviceIds.filter(d => d !== myId)];
        mutate("PATCH", `/rest/config/folders/${encodeURIComponent(id)}`, {
            devices: ids.map(deviceID => ({
                        deviceID
                    }))
        }, () => closeForm());
    }

    function openFolder(path: string): void {
        Qt.openUrlExternally(`file://${expandPath(path)}`);
    }

    function startAddFolder(): void {
        folderDraft = {
            id: generateFolderId(),
            label: "",
            path: "",
            devices: [],
            fromOffer: false
        };
        openForm("addFolder", "");
    }

    // Validates the draft, asks to create a missing directory, then adds the folder
    function submitFolder(createMissing: bool): void {
        const draft = folderDraft;
        const path = expandPath(draft.path);
        const id = draft.id.trim();
        if (!path.startsWith("/"))
            return fail(Tr.tr("Enter an absolute path or one starting with ~/"));
        if (!id)
            return fail(Tr.tr("Folder ID cannot be empty"));
        if (folders.some(f => f.id === id))
            return fail(Tr.tr("A folder with ID %1 already exists").arg(id));
        const overlap = overlappingFolder(path);
        if (overlap)
            return fail(Tr.tr("Path overlaps with folder “%1” (%2)").arg(overlap.label).arg(displayPath(overlap.path)));

        dirCheck.path = path;
        dirCheck.createMissing = createMissing;
        dirCheck.command = createMissing ? ["mkdir", "-p", "--", path] : ["test", "-d", path];
        dirCheck.running = true;
    }

    function postFolder(): void {
        const draft = folderDraft;
        const path = expandPath(draft.path);
        const label = draft.label.trim() || path.split("/").pop();
        mutate("POST", "/rest/config/folders", {
            id: draft.id.trim(),
            label,
            path,
            type: "sendreceive",
            devices: [myId, ...draft.devices].map(deviceID => ({
                        deviceID
                    }))
        }, () => {
            dismissConfirm();
            closeForm();
            if (settings.notifications)
                Toaster.toast(Tr.tr("Folder added"), Tr.tr("%1 is now synced by Syncthing").arg(label), "create_new_folder", Toast.Success);
        });
    }

    function acceptPendingFolder(offer: var): void {
        folderDraft = {
            id: offer.id,
            label: offer.label,
            path: `~/${offer.label.replace(/[\/\\]/g, "_")}`,
            devices: [offer.deviceId],
            fromOffer: true
        };
        page = "folders";
        openForm("addFolder", "");
    }

    function dismissPendingFolder(folderId: string, deviceId: string): void {
        mutate("DELETE", `/rest/cluster/pending/folders?folder=${encodeURIComponent(folderId)}&device=${encodeURIComponent(deviceId)}`, null);
    }

    function browseFolder(): void {
        folderPicker.running = true;
    }

    function scanConflicts(): void {
        const paths = folders.map(f => expandPath(f.path));
        if (paths.length === 0)
            return;
        conflictScanRunning = true;
        conflictScan.command = ["sh", "-c", "find \"$@\" -name '*.sync-conflict-*' -not -path '*/.stversions/*' 2>/dev/null | head -n 200", "sh", ...paths];
        conflictScan.running = true;
    }

    // ---------- Device actions ----------

    function setDevicePaused(id: string, paused: bool): void {
        mutate("PATCH", `/rest/config/devices/${encodeURIComponent(id)}`, {
            paused
        });
    }

    function setAllPaused(paused: bool): void {
        mutate("POST", paused ? "/rest/system/pause" : "/rest/system/resume", null);
    }

    function removeDevice(id: string): void {
        mutate("DELETE", `/rest/config/devices/${encodeURIComponent(id)}`, null);
    }

    function startAddDevice(): void {
        deviceDraft = {
            id: "",
            name: ""
        };
        openForm("addDevice", "");
    }

    function acceptPendingDevice(pending: var): void {
        deviceDraft = {
            id: pending.id,
            name: pending.name
        };
        page = "devices";
        openForm("addDevice", "");
    }

    function submitDevice(): void {
        const raw = deviceDraft.id.trim();
        if (!raw)
            return fail(Tr.tr("Enter a device ID"));
        request("GET", `/rest/svc/deviceid?id=${encodeURIComponent(raw)}`, null, res => {
            if (!res?.id)
                return fail(res?.error ? Tr.tr("Invalid device ID: %1").arg(res.error) : Tr.tr("Invalid device ID"));
            if (res.id === myId)
                return fail(Tr.tr("That is this device's own ID"));
            if (devices.some(d => d.id === res.id))
                return fail(Tr.tr("This device is already added"));
            const name = deviceDraft.name.trim();
            mutate("POST", "/rest/config/devices", {
                deviceID: res.id,
                name,
                addresses: ["dynamic"],
                autoAcceptFolders: false
            }, () => {
                closeForm();
                if (settings.notifications)
                    Toaster.toast(Tr.tr("Device added"), Tr.tr("%1 can now connect").arg(name || res.id.slice(0, 7)), "devices", Toast.Success);
            });
        }, err => fail(err));
    }

    function dismissPendingDevice(id: string): void {
        mutate("DELETE", `/rest/cluster/pending/devices?device=${encodeURIComponent(id)}`, null);
    }

    // Shares or unshares folders with one device
    function setDeviceFolders(deviceId: string, folderIds: var): void {
        for (const f of folders) {
            const has = f.devices.includes(deviceId);
            const want = folderIds.includes(f.id);
            if (has !== want)
                setFolderDevices(f.id, want ? [...f.devices, deviceId] : f.devices.filter(d => d !== deviceId));
        }
        closeForm();
    }

    function copyId(id: string): void {
        Quickshell.clipboardText = id;
        if (settings.notifications)
            Toaster.toast(Tr.tr("Device ID copied"), id.slice(0, 15) + "…", "content_copy", Toast.Info);
    }

    // ---------- Service ----------

    function setRunning(running: bool): void {
        busy = true;
        serviceProc.command = ["systemctl", "--user", running ? "start" : "stop", "syncthing.service"];
        serviceProc.running = true;
    }

    function toggleRunning(): void {
        if (!busy && installed)
            setRunning(!online);
    }

    function install(): void {
        busy = true;
        serviceProc.command = ["sh", "-c", "pkexec pacman -S --needed --noconfirm syncthing && systemctl --user enable --now syncthing.service"];
        serviceProc.running = true;
    }

    function openWebUi(): void {
        if (online)
            Qt.openUrlExternally(baseUrl);
    }

    function openSettingsFile(): void {
        Qt.openUrlExternally(`file://${settingsFile.path}`);
    }

    // ---------- UI state ----------

    function openForm(name: string, target: string): void {
        lastError = "";
        form = name;
        formTarget = target;
        if (name === "shareFolder")
            shareDraft = folders.find(f => f.id === target)?.devices ?? [];
        else if (name === "deviceFolders")
            shareDraft = folders.filter(f => f.devices.includes(target)).map(f => f.id);
    }

    function closeForm(): void {
        form = "";
        formTarget = "";
    }

    function toggleShare(id: string): void {
        shareDraft = shareDraft.includes(id) ? shareDraft.filter(x => x !== id) : [...shareDraft, id];
    }

    function askConfirm(spec: var): void {
        confirm = spec;
    }

    function dismissConfirm(): void {
        confirm = null;
    }

    function runConfirm(): void {
        const c = confirm;
        confirm = null;
        c?.action?.();
    }

    function parseConfig(text: string): void {
        const gui = text.match(/<gui\b([^>]*)>([\s\S]*?)<\/gui>/);
        if (!gui)
            return;
        const tls = /tls="true"/.test(gui[1]);
        let address = gui[2].match(/<address>([^<]+)<\/address>/)?.[1] ?? "127.0.0.1:8384";
        address = address.replace(/^0\.0\.0\.0(?=:)/, "127.0.0.1").replace(/^\[::\](?=:)/, "[::1]");
        baseUrl = `${tls ? "https" : "http"}://${address}`;
        apiKey = gui[2].match(/<apikey>([^<]+)<\/apikey>/)?.[1] ?? "";
        refresh();
    }

    FileView {
        path: root.configPath
        watchChanges: true
        printErrors: false
        onLoaded: root.parseConfig(text())
        onFileChanged: reload()
        onLoadFailed: {
            if (root.configIndex < root.configPaths.length - 1)
                root.configIndex++;
        }
    }

    FileView {
        id: settingsFile

        path: `${root.configHome}/caelestia/syncthing.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: settingsAdapter

            property string iconStyle: "themed" // themed | branded
            property bool notifications: true
            property int activityLimit: 40
        }
    }

    Process {
        id: serviceProc

        onExited: {
            root.busy = false;
            installCheck.running = true;
            delayedRefresh.restart();
        }
    }

    Process {
        id: serviceCheck

        command: ["systemctl", "--user", "is-active", "syncthing.service"]
        stdout: StdioCollector {
            onStreamFinished: root.serviceState = text.trim() || "unknown"
        }
    }

    Process {
        id: installCheck

        running: true
        command: ["sh", "-c", "command -v syncthing"]
        onExited: code => root.installed = code === 0
    }

    Process {
        id: dirCheck

        property string path
        property bool createMissing

        onExited: code => {
            if (code === 0)
                root.postFolder();
            else if (createMissing)
                root.fail(Tr.tr("Could not create %1").arg(path));
            else
                root.askConfirm({
                    kind: "createDir",
                    title: Tr.tr("Create directory?"),
                    body: Tr.tr("%1 does not exist yet.").arg(root.displayPath(path)),
                    confirmText: Tr.tr("Create"),
                    action: () => root.submitFolder(true)
                });
        }
    }

    Process {
        id: folderPicker

        command: ["zenity", "--file-selection", "--directory", "--title=Select a folder to sync"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path)
                    root.folderDraft = Object.assign({}, root.folderDraft, {
                        path: root.displayPath(path),
                        label: root.folderDraft.label || path.split("/").pop()
                    });
            }
        }
    }

    Process {
        id: conflictScan

        stdout: StdioCollector {
            onStreamFinished: {
                root.conflicts = text.split("\n").filter(l => l);
                root.conflictScanRunning = false;
                root.conflictScanDone = true;
            }
        }
    }

    Timer {
        id: delayedRefresh

        interval: 1500
        onTriggered: root.refresh()
    }

    Timer {
        id: refreshDebounce

        interval: 400
        onTriggered: root.refresh()
    }

    Timer {
        id: eventRetry

        interval: 3000
        onTriggered: {
            if (root.online)
                root.startEvents();
        }
    }

    Timer {
        interval: root.online ? 15000 : 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
