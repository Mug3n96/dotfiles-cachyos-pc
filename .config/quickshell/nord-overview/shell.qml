//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

// Nord-Overview · Übersicht der belegten Workspaces mit Live-Vorschau
//
// Öffnen:  der aktuelle Bildschirm schrumpft in seine Kachel, die anderen gleiten
//          leicht versetzt dazu; der ganze Desktop samt Leiste verschwimmt dahinter.
// Klick:   die Kachel wächst wieder auf Vollbild, Hyprland wechselt darunter.
//          Ein Klick auf ein bestimmtes Fenster fokussiert zusätzlich dieses Fenster.
// Tasten:  Pfeile/HJKL wählen, Enter springt, 1–9 springt direkt, Esc schließt.
//
// Design wie der Rest (hypr/lua/theme.lua, waybar/style.css): ein Raster, eine
// Rundung, ein Akzent. Auswahl = massiv + Glanzlicht oben im Akzent, Rest mattes Glas.
// Keine Schatten.
//
// Steuerung: qs ipc -p ~/.config/quickshell/nord-overview call overview toggle
// Braucht: quickshell, imagemagick (Hintergrund), hypr/scripts/wallpaper (Pfad des Standbilds)

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: shell

    // ── Nord ──────────────────────────────────────────────────────────────
    readonly property color cBase:    "#2e3440"
    readonly property color cSurface: "#3b4252"
    readonly property color cText:    "#d8dee9"
    readonly property color cBright:  "#eceff4"
    readonly property color cAccent:  "#88c0d0"
    readonly property color cAccent2: "#81a1c1"
    readonly property string uiFont: "Adwaita Sans"
    // Standbild aus hypr/scripts/wallpaper ("wallpaper path"), so bleibt die Datei auf allen Rechnern gleich
    property string wallpaperPath: ""
    readonly property string wallpaper: "file://" + wallpaperPath
    // Hintergrund einmal vorab weichzeichnen statt in jedem Frame (schont die iGPU)
    readonly property string blurPath: Quickshell.env("HOME") + "/.cache/nord-overview/backdrop.png"
    property string backdrop: ""

    // ── Maße ──────────────────────────────────────────────────────────────
    readonly property int radius: 10
    readonly property int gap: 30          // zwischen Kacheln
    readonly property int labelSpace: 38   // Platz für das Schild unter der Kachel
    readonly property int openMs: 360
    readonly property int closeMs: 300

    // Symbole wie in der Waybar (hyprland/workspaces → format-icons)
    readonly property var wsIcons: ({ 1: "", 2: "", 3: "", 4: "", 5: "󰺷", 6: "", 7: "", 8: "" })
    readonly property string scratchIcon: "󰌨"

    // ── Zustand ───────────────────────────────────────────────────────────
    property bool shown: false
    property bool closing: false
    property bool pendingOpen: false
    property string heroKey: ""        // Kachel, die zum/aus dem Vollbild zoomt
    property string heroSpecial: ""    // Scratchpad, das zusätzlich darüber zoomt (z. B. "special:scratch")
    property string restoreSpecial: "" // beim Öffnen sichtbares Scratchpad (für Abbrechen)
    property string selectedKey: ""
    property var clients: []
    property var monitors: []
    property int pendingLoads: 0
    property real progress: 0          // 0 = Vollbild, 1 = Übersicht

    NumberAnimation {
        id: anim
        target: shell
        property: "progress"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1]   // schnell los, weich aus
        onFinished: {
            if (shell.closing) {
                shell.shown = false;
                shell.closing = false;
            }
        }
    }

    function animateTo(value, ms) {
        anim.stop();
        anim.duration = ms;
        anim.from = progress;
        anim.to = value;
        anim.start();
    }

    // ── Daten (laufend aktuell, damit das Öffnen ohne Verzögerung geht) ──
    function load() {
        pendingLoads = 2;
        getClients.running = true;
        getMonitors.running = true;
    }

    function loaded() {
        if (--pendingLoads > 0 || !pendingOpen || (shown && !closing))
            return;
        pendingOpen = false;
        const mon = focusedMonitorData();
        heroKey = "ws:" + (mon?.activeWorkspace?.id ?? 1);
        heroSpecial = restoreSpecial;
        selectedKey = heroSpecial || heroKey;
        closing = false;
        progress = 0;
        shown = true;
        animateTo(1, openMs);
        // Scratchpad erst ausblenden, wenn die Übersicht schon darüber liegt:
        // seine Kachel übernimmt nahtlos, Hyprlands eigene Animation bleibt verdeckt.
        if (restoreSpecial)
            hideSpecialTimer.restart();
    }

    Timer {
        id: hideSpecialTimer
        interval: 40
        onTriggered: shell.toggleSpecial(shell.restoreSpecial)
    }

    function toggleSpecial(name) {
        Hyprland.dispatch(`hl.dsp.workspace.toggle_special("${name.replace(/^special:/, "")}")`);
    }

    function openOverview() {
        if (shown && !closing)
            return;
        const mon = focusedMonitorData();
        restoreSpecial = mon?.specialWorkspace?.name ?? "";
        pendingOpen = true;
        if (clients.length > 0 && monitors.length > 0) {
            pendingLoads = 1;
            loaded();
        }
        load();
    }

    // entry == null: abbrechen, zurück zum aktuellen Workspace
    function closeOverview(entry, windowAddress) {
        if (!shown || closing)
            return;
        const mon = focusedMonitorData();
        const currentKey = "ws:" + (mon?.activeWorkspace?.id ?? 1);
        hideSpecialTimer.stop();
        closing = true;
        if (entry?.special) {
            // Scratchpad: der aktuelle Workspace zoomt auf, das Scratchpad legt sich
            // abgedunkelt darüber – genau so, wie Hyprland es danach zeigt.
            heroKey = currentKey;
            heroSpecial = entry.name;
            toggleSpecial(entry.name);
        } else if (entry) {
            heroKey = entry.key;
            heroSpecial = "";
            if (entry.key !== currentKey)
                Hyprland.dispatch(`hl.dsp.focus({ workspace = ${entry.id} })`);
        } else {
            // Abbrechen: alles wie vorher, ein vorher offenes Scratchpad kommt zurück
            heroKey = currentKey;
            heroSpecial = restoreSpecial;
            if (restoreSpecial)
                toggleSpecial(restoreSpecial);
        }
        if (windowAddress)
            Hyprland.dispatch(`hl.dsp.focus({ window = 'address:${windowAddress}' })`);
        animateTo(0, closeMs);
    }

    function toggle() {
        if (shown && !closing)
            closeOverview(null);
        else
            openOverview();
    }

    function focusedMonitorData() {
        const name = Hyprland.focusedMonitor?.name;
        return monitors.find(m => m.name === name) ?? monitors[0];
    }

    // Kacheln eines Monitors: belegte Workspaces (+ der aktive), danach Spezial-Workspaces
    function entriesFor(mon) {
        if (!mon)
            return [];
        const normal = new Map(), special = new Map();
        for (const c of clients) {
            if (c.monitor !== mon.id || c.mapped === false || c.hidden)
                continue;
            const ws = c.workspace;
            if (ws?.id > 0)
                normal.set(ws.id, (normal.get(ws.id) ?? 0) + 1);
            else if (ws?.name?.startsWith("special:"))
                special.set(ws.name, (special.get(ws.name) ?? 0) + 1);
        }
        const active = mon.activeWorkspace?.id;
        if (active > 0 && !normal.has(active))
            normal.set(active, 0);
        const list = Array.from(normal.keys()).sort((a, b) => a - b)
            .map(id => ({ key: "ws:" + id, id: id, name: String(id), special: false, count: normal.get(id) }));
        for (const [name, count] of special)
            list.push({ key: name, id: -1, name: name, special: true, count: count });
        return list;
    }

    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { shell.clients = JSON.parse(text); } catch (e) { console.warn("nord-overview: clients", e); }
                shell.loaded();
            }
        }
    }

    Process {
        id: getMonitors
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { shell.monitors = JSON.parse(text); } catch (e) { console.warn("nord-overview: monitors", e); }
                shell.loaded();
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event?.name ?? "";
            if (["openwindow", "closewindow", "movewindowv2", "workspacev2", "focusedmonv2",
                 "activespecialv2", "changefloatingmode", "fullscreen", "monitoraddedv2", "monitorremovedv2"].includes(n))
                refreshTimer.restart();
        }
    }
    Timer {
        id: refreshTimer
        interval: 80
        onTriggered: shell.load()
    }
    Component.onCompleted: {
        load();
        wallpaperQuery.running = true;
    }

    Process {
        id: wallpaperQuery
        command: ["sh", "-c", "\"$HOME/.config/hypr/scripts/wallpaper\" path"]
        stdout: StdioCollector {
            onStreamFinished: {
                shell.wallpaperPath = text.trim();
                if (shell.wallpaperPath !== "") makeBackdrop.running = true;
            }
        }
    }

    // Weichgezeichnetes, abgedunkeltes Wallpaper erzeugen (nur wenn neuer als die Vorlage nötig)
    Process {
        id: makeBackdrop
        command: ["sh", "-c",
            `mkdir -p "$(dirname '${shell.blurPath}')" && ` +
            `{ [ '${shell.blurPath}' -nt '${shell.wallpaperPath}' ] || ` +
            `magick '${shell.wallpaperPath}' -resize 960x -blur 0x22 -modulate 72,75 '${shell.blurPath}'; }`]
        onExited: (code) => shell.backdrop = code === 0 ? "file://" + shell.blurPath : shell.wallpaper
    }

    IpcHandler {
        target: "overview"
        function toggle(): void { shell.toggle(); }
        function open(): void { shell.openOverview(); }
        function close(): void { shell.closeOverview(null); }
        // Ziel wählen wie per Klick: "2" oder "special:scratch" (zum Testen und für Skripte)
        function go(target: string): void {
            const special = target.startsWith("special:");
            const id = special ? -1 : parseInt(target);
            shell.closeOverview({ key: special ? target : "ws:" + id, id: id, name: special ? target : String(id), special: special });
        }
    }

    // ── Eine Oberfläche pro Bildschirm, über allem, auch über der Leiste ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: shell.shown
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.namespace: "nord-overview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: shell.shown && isFocused ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            readonly property var mon: shell.monitors.find(m => m.name === modelData.name)
            readonly property bool isFocused: Hyprland.focusedMonitor?.name === modelData.name
            readonly property var entries: shell.entriesFor(mon)
            readonly property int nNormal: entries.filter(e => !e.special).length
            readonly property int nSpecial: entries.length - nNormal

            // Arbeitsfläche (ohne Leiste): dort liegen die Fenster, dorthin zoomt die Kachel
            readonly property real resL: mon?.reserved?.[0] ?? 0
            readonly property real resT: mon?.reserved?.[1] ?? 0
            readonly property real areaW: width - resL - (mon?.reserved?.[2] ?? 0)
            readonly property real areaH: height - resT - (mon?.reserved?.[3] ?? 0)
            readonly property real offX: (mon?.x ?? 0) + resL
            readonly property real offY: (mon?.y ?? 0) + resT
            readonly property real aspect: areaW / Math.max(1, areaH)

            // Raster: Spaltenzahl so wählen, dass die Kacheln am größten werden.
            // Spezial-Workspaces bekommen darunter eine eigene, kleinere Reihe.
            readonly property var layout: {
                const n = Math.max(1, nNormal);
                const specialScale = 0.5;
                const availW = width * 0.84;
                const availH = height * 0.80;
                let best = null;
                for (let c = 1; c <= n; c++) {
                    const r = Math.ceil(n / c);
                    // Höhe pro Kachel inkl. Schild; die Spezialreihe hängt an der Kachelhöhe
                    const hFromH = (availH - r * shell.labelSpace - (r - 1) * shell.gap
                                    - (nSpecial > 0 ? shell.gap + shell.labelSpace : 0))
                                   / (r + (nSpecial > 0 ? specialScale : 0));
                    const w = Math.min((availW - (c - 1) * shell.gap) / c, hFromH * aspect);
                    if (!best || w > best.w)
                        best = { cols: c, rows: r, w: w };
                }
                best.w = Math.min(best.w, width * 0.44);   // einzelne Kachel nicht riesig
                best.h = best.w / aspect;
                best.sw = best.w * specialScale;
                best.sh = best.h * specialScale;
                const mainH = best.rows * (best.h + shell.labelSpace) + (best.rows - 1) * shell.gap;
                const specialH = nSpecial > 0 ? shell.gap + best.sh + shell.labelSpace : 0;
                best.top = (height - mainH - specialH) / 2;
                return best;
            }

            function rectFor(index) {
                const L = layout, e = entries[index];
                if (!e)
                    return { x: 0, y: 0, w: 0, h: 0 };
                if (e.special) {
                    const i = index - nNormal;
                    const rowW = nSpecial * L.sw + (nSpecial - 1) * shell.gap;
                    return {
                        x: (width - rowW) / 2 + i * (L.sw + shell.gap),
                        y: L.top + L.rows * (L.h + shell.labelSpace) + (L.rows - 1) * shell.gap + shell.gap,
                        w: L.sw, h: L.sh
                    };
                }
                const row = Math.floor(index / L.cols);
                const inRow = Math.min(L.cols, nNormal - row * L.cols);   // letzte Reihe zentriert
                const col = index % L.cols;
                const rowW = inRow * L.w + (inRow - 1) * shell.gap;
                return {
                    x: (width - rowW) / 2 + col * (L.w + shell.gap),
                    y: L.top + row * (L.h + shell.labelSpace + shell.gap),
                    w: L.w, h: L.h
                };
            }

            function moveSelection(dx, dy) {
                const n = entries.length;
                if (n === 0) return;
                let i = Math.max(0, entries.findIndex(e => e.key === shell.selectedKey));
                if (dx !== 0)
                    i = (i + dx + n) % n;
                if (dy !== 0) {
                    const j = i + dy * layout.cols;
                    i = j >= n ? n - 1 : (j < 0 ? i : j);
                }
                shell.selectedKey = entries[i].key;
            }

            function entryByKey(key) {
                return entries.find(e => e.key === key) ?? null;
            }

            // ── Hintergrund: der ganze Bildschirm verschwimmt, auch die Leiste ──
            Item {
                anchors.fill: parent
                opacity: shell.progress

                Image {
                    anchors.fill: parent
                    source: shell.backdrop
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                }
                // Nord-Tönung, oben und unten etwas dunkler: lenkt den Blick zur Mitte
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0.18, 0.20, 0.25, 0.62) }
                        GradientStop { position: 0.5; color: Qt.rgba(0.18, 0.20, 0.25, 0.38) }
                        GradientStop { position: 1.0; color: Qt.rgba(0.18, 0.20, 0.25, 0.66) }
                    }
                }
            }

            // Klick daneben = schließen
            MouseArea {
                anchors.fill: parent
                onClicked: shell.closeOverview(null)
            }

            Item {
                anchors.fill: parent
                focus: shell.shown
                Keys.onPressed: event => {
                    const k = event.key;
                    if (k === Qt.Key_Escape) shell.closeOverview(null);
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) shell.closeOverview(win.entryByKey(shell.selectedKey));
                    else if (k === Qt.Key_Left || k === Qt.Key_H) win.moveSelection(-1, 0);
                    else if (k === Qt.Key_Right || k === Qt.Key_L) win.moveSelection(1, 0);
                    else if (k === Qt.Key_Up || k === Qt.Key_K) win.moveSelection(0, -1);
                    else if (k === Qt.Key_Down || k === Qt.Key_J) win.moveSelection(0, 1);
                    else if (k >= Qt.Key_1 && k <= Qt.Key_9) {
                        const id = k - Qt.Key_0;
                        shell.closeOverview(win.entryByKey("ws:" + id) ?? { key: "ws:" + id, id: id, special: false });
                    } else return;
                    event.accepted = true;
                }
            }

            // ── Kacheln ───────────────────────────────────────────────────
            Repeater {
                model: win.entries

                Item {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property var entry: modelData
                    readonly property bool hero: (entry.key === shell.heroKey || entry.key === shell.heroSpecial) && win.isFocused
                    readonly property bool selected: entry.key === shell.selectedKey
                    readonly property bool hovered: hover.containsMouse
                    readonly property var target: win.rectFor(index)

                    // Held-Kachel folgt dem Gesamtfortschritt. Die anderen kommen leicht
                    // versetzt nacheinander (je 45 ms) und wachsen aus 92 % auf.
                    readonly property real delay: Math.min(index, 6) * 0.06
                    readonly property real q: hero ? shell.progress
                        : Math.max(0, Math.min(1, (shell.progress - delay) / (1 - delay)))
                    readonly property real s0: hero ? 1 : 0.92
                    readonly property real fromW: hero ? win.areaW : target.w * s0
                    readonly property real fromH: hero ? win.areaH : target.h * s0
                    readonly property real fromX: hero ? win.resL : target.x + (target.w - fromW) / 2
                    readonly property real fromY: hero ? win.resT : target.y + (target.h - fromH) / 2

                    x: fromX + (target.x - fromX) * q
                    y: fromY + (target.y - fromY) * q
                    width: fromW + (target.w - fromW) * q
                    height: fromH + (target.h - fromH) * q
                    z: hero ? (entry.special ? 4 : 3) : (selected ? 2 : 1)
                    opacity: hero ? 1 : q
                    // Maus darüber: hebt sich minimal an
                    scale: hovered && shell.progress === 1 && !shell.closing ? 1.015 : 1
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    readonly property real s: width / Math.max(1, win.areaW)   // Maßstab der Vorschau
                    readonly property real r: shell.radius * Math.min(1, q * 2.5)
                    // nicht gewählte Kacheln: mattes Glas (wie inaktive Fenster)
                    property real veil: (selected ? 0 : 0.22) * q
                    Behavior on veil { NumberAnimation { duration: 180 } }

                    // Inhalt: Wallpaper-Ausschnitt + Fenster, mit runden Ecken maskiert
                    Item {
                        id: content
                        anchors.fill: parent
                        layer.enabled: true
                        layer.smooth: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: mask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1.0
                        }

                        Image {
                            x: -win.resL * tile.s
                            y: -win.resT * tile.s
                            width: win.width * tile.s
                            height: win.height * tile.s
                            source: shell.wallpaper
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 1280
                            // Scratchpad im Vollbild: kein eigenes Wallpaper, der Workspace scheint durch
                            opacity: tile.entry.special && tile.hero ? tile.q : 1
                        }

                        // Spezial-Workspace: abgedunkelt wie decoration.dim_special (look.lua)
                        Rectangle {
                            anchors.fill: parent
                            visible: tile.entry.special
                            color: "black"
                            opacity: 0.4
                        }

                        Repeater {
                            model: shell.clients.filter(c => c.workspace?.name === (tile.entry.special ? tile.entry.name : String(tile.entry.id))
                                                             && c.monitor === win.mon?.id && c.mapped !== false && !c.hidden)

                            Item {
                                id: wnd
                                required property var modelData
                                readonly property var toplevel: ToplevelManager.toplevels.values.find(
                                    t => `0x${t.HyprlandToplevel?.address}` === modelData.address)
                                x: ((modelData.at?.[0] ?? 0) - win.offX) * tile.s
                                y: ((modelData.at?.[1] ?? 0) - win.offY) * tile.s
                                width: (modelData.size?.[0] ?? 0) * tile.s
                                height: (modelData.size?.[1] ?? 0) * tile.s
                                z: modelData.floating ? 2 : 1

                                Rectangle {
                                    anchors.fill: parent
                                    radius: shell.radius * tile.s
                                    color: shell.cSurface
                                }
                                ScreencopyView {
                                    anchors.fill: parent
                                    captureSource: shell.shown ? wnd.toplevel : null
                                    // Während der Animation ein Standbild, danach live: weniger GPU-Last beim Zoomen
                                    live: shell.progress === 1 && !shell.closing
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: shell.closeOverview(tile.entry, wnd.modelData.address)
                                }
                            }
                        }

                        // Leerer Workspace: dezenter Hinweis
                        Text {
                            anchors.centerIn: parent
                            visible: tile.entry.count === 0
                            opacity: 0.55 * tile.q
                            text: "leer"
                            color: shell.cText
                            font.family: shell.uiFont
                            font.pixelSize: 14
                        }

                        // Mattes Glas über nicht gewählten Kacheln
                        Rectangle {
                            anchors.fill: parent
                            color: shell.cBase
                            opacity: tile.veil
                        }
                    }

                    Item {
                        id: mask
                        anchors.fill: parent
                        layer.enabled: true
                        visible: false
                        Rectangle { anchors.fill: parent; radius: tile.r; color: "black" }
                    }

                    // Feine Kante wie bei den Waybar-Inseln
                    Rectangle {
                        anchors.fill: parent
                        radius: tile.r
                        color: "transparent"
                        opacity: tile.q
                        border.width: 1
                        border.color: Qt.rgba(0.85, 0.87, 0.91, tile.selected ? 0.16 : 0.08)
                    }

                    // Glanzlicht oben im Akzent, läuft zu den Seiten aus (wie das aktive Fenster)
                    Item {
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        height: 2
                        clip: true
                        opacity: tile.selected ? tile.q : 0
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                        Rectangle {
                            x: tile.r * 0.6
                            width: parent.width - 2 * x
                            height: 2
                            radius: 1
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Qt.rgba(0.53, 0.75, 0.82, 0.0) }
                                GradientStop { position: 0.5; color: shell.cAccent }
                                GradientStop { position: 1.0; color: Qt.rgba(0.53, 0.75, 0.82, 0.0) }
                            }
                        }
                    }

                    // Schild unter der Kachel: Symbol + Nummer wie in der Waybar
                    Rectangle {
                        id: badge
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: 10 }
                        height: 26
                        width: badgeRow.implicitWidth + 20
                        radius: 6
                        opacity: tile.q
                        color: tile.selected ? Qt.rgba(0.53, 0.75, 0.82, 0.16) : Qt.rgba(0.18, 0.20, 0.25, 0.35)
                        border.width: 1
                        border.color: Qt.rgba(0.85, 0.87, 0.91, 0.08)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            id: badgeRow
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tile.entry.special ? (tile.entry.name === "special:mail" ? "\udb80\uddee" : shell.scratchIcon) : (shell.wsIcons[tile.entry.id] ?? "")
                                color: tile.selected ? shell.cAccent : Qt.rgba(0.85, 0.87, 0.91, 0.88)
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tile.entry.special
                                    ? (tile.entry.name === "special:mail" ? "Mail" : "Scratchpad" + (tile.entry.count > 0 ? "  " + tile.entry.count : ""))
                                    : tile.entry.name
                                color: tile.selected ? shell.cAccent : shell.cText
                                font.family: shell.uiFont
                                font.pixelSize: 13
                                font.weight: tile.selected ? Font.DemiBold : Font.Medium
                                font.features: { "tnum": 1 }
                            }
                        }
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        z: -1
                        hoverEnabled: true
                        onEntered: shell.selectedKey = tile.entry.key
                        onClicked: shell.closeOverview(tile.entry)
                    }
                }
            }
        }
    }
}
