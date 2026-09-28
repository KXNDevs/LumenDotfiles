import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications

ShellRoot {
    id: shell

    // "" | "launcher" | "control"
    property string mode: ""
    property string themeName: "Material"
    property string query: ""
    property int selected: 0

    // Size & Scale Configuration
    property real pillScale: 1.2
    property int pillHeight: Math.round(32 * pillScale)
    property real launcherScale: 1.0
    property int launcherWidth: Math.round(560 * launcherScale)
    property real controlScale: 1.0
    property int controlWidth: Math.round(440 * controlScale)

    property string configDir: Quickshell.env("HOME") + "/.config/quickshell"
    property string themeFile: configDir + "/theme"

    property string wallpaperFolder: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property var wallpapers: []
    property string currentWallpaper: ""
    property string nextWallpaper: ""

    property var workspaces: [{ idx: 1, active: true }]
    property string focusedTitle: "Desktop"
    property string focusedApp: "Niri"
    property string networkText: "Wi-Fi"
    property string volumeText: "0%"
    property string clockText: Qt.formatTime(new Date(), "HH:mm")

    readonly property string mono: "JetBrains Mono"
    readonly property string icons: "JetBrainsMono Nerd Font"

    readonly property var themes: ({
        "Material": {
            primary: "#B8C7FF", onPrimary: "#0F2D6B",
            surface: "#0F141C", surfaceContainer: "#1B2028",
            surfaceContainerHigh: "#252A33", onSurface: "#E2E2E9",
            onSurfaceVariant: "#C3C6D0", outlineVariant: "#424750"
        },
        "Catppuccin": {
            primary: "#89B4FA", onPrimary: "#112A46",
            surface: "#11111B", surfaceContainer: "#181825",
            surfaceContainerHigh: "#1E1E2E", onSurface: "#CDD6F4",
            onSurfaceVariant: "#A6ADC8", outlineVariant: "#313244"
        },
        "Nord": {
            primary: "#88C0D0", onPrimary: "#12313A",
            surface: "#242933", surfaceContainer: "#2E3440",
            surfaceContainerHigh: "#3B4252", onSurface: "#ECEFF4",
            onSurfaceVariant: "#D8DEE9", outlineVariant: "#4C566A"
        },
        "Monochrome": {
            primary: "#FFFFFF", onPrimary: "#111111",
            surface: "#0B0B0B", surfaceContainer: "#151515",
            surfaceContainerHigh: "#202020", onSurface: "#F5F5F5",
            onSurfaceVariant: "#BDBDBD", outlineVariant: "#383838"
        },
        "Gruvbox": {
            primary: "#FABD2F", onPrimary: "#3C3836",
            surface: "#1D2021", surfaceContainer: "#282828",
            surfaceContainerHigh: "#3C3836", onSurface: "#EBDBB2",
            onSurfaceVariant: "#BDAE93", outlineVariant: "#504945"
        },
        "Tokyo Night": {
            primary: "#7AA2F7", onPrimary: "#18213A",
            surface: "#16161E", surfaceContainer: "#1F2335",
            surfaceContainerHigh: "#24283B", onSurface: "#C0CAF5",
            onSurfaceVariant: "#A9B1D6", outlineVariant: "#3B4261"
        },
        "Rose Pine": {
            primary: "#C4A7E7", onPrimary: "#261F2E",
            surface: "#191724", surfaceContainer: "#1F1D2E",
            surfaceContainerHigh: "#26233A", onSurface: "#E0DEF4",
            onSurfaceVariant: "#908CAA", outlineVariant: "#393552"
        }
    })

    readonly property var theme: themes[themeName]

    // ---------- launcher results ----------
    readonly property var results: {
        const q = shell.query.trim().toLowerCase()
        const all = DesktopEntries.applications.values
        const out = []
        for (let i = 0; i < all.length; i++) {
            const e = all[i]
            if (e.noDisplay)
                continue
            const n = (e.name || "").toLowerCase()
            const g = (e.genericName || "").toLowerCase()
            if (q === "" || n.indexOf(q) !== -1 || g.indexOf(q) !== -1)
                out.push(e)
        }
        out.sort(function(a, b) {
            const an = (a.name || "").toLowerCase()
            const bn = (b.name || "").toLowerCase()
            const ap = (q !== "" && an.indexOf(q) === 0) ? 0 : 1
            const bp = (q !== "" && bn.indexOf(q) === 0) ? 0 : 1
            return ap !== bp ? ap - bp : an.localeCompare(bn)
        })
        return out.slice(0, 7)
    }

    // ---------- helpers ----------
    function run(command) {
        Quickshell.execDetached(command)
    }

    function toggle(m) {
        shell.mode = (shell.mode === m) ? "" : m
    }

    function launch(entry) {
        if (!entry)
            return
        entry.execute()
        shell.mode = ""
    }

    function refreshWallpapers() {
        wallpaperProcess.running = false
        wallpaperProcess.running = true
    }

    function setWallpaper(path) {
        if (!path) return
        const newSource = "file://" + path
        if (shell.currentWallpaper === newSource) return

        // Set next wallpaper URL to start loading in target layer
        shell.nextWallpaper = newSource

        // Spawn swaybg in background
        run(["sh", "-c", "pkill swaybg; swaybg -i \"" + path + "\" -m fill &"])
    }

    function setTheme(name) {
        if (!themes[name]) return
        shell.themeName = name
        saveThemeProcess.command = ["sh", "-c", "mkdir -p \"" + shell.configDir + "\" && printf '%s' \"" + name + "\" > \"" + shell.themeFile + "\""]
        saveThemeProcess.running = true
    }

    onModeChanged: {
        if (mode === "control")
            refreshWallpapers()
    }

    // ---------- IPC ----------
    IpcHandler {
        target: "launcher"
        function toggle(): void { shell.toggle("launcher") }
    }

    IpcHandler {
        target: "control"
        function toggle(): void { shell.toggle("control") }
    }

    // ---------- persistence & data sources ----------
    Process {
        id: loadThemeProcess
        command: ["sh", "-c", "cat \"" + shell.themeFile + "\" 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const saved = text.trim()
                if (saved && shell.themes[saved]) {
                    shell.themeName = saved
                }
            }
        }
    }

    Process {
        id: saveThemeProcess
        running: false
    }

    Process {
        id: wallpaperProcess
        command: ["sh", "-c",
            "mkdir -p \"$HOME/Pictures/Wallpapers\"; " +
            "find \"$HOME/Pictures/Wallpapers\" -maxdepth 1 -type f " +
            "\\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\) " +
            "-print 2>/dev/null | sort | head -8"]
        stdout: StdioCollector {
            onStreamFinished: {
                shell.wallpapers = text.trim().split("\n").filter(function(x) {
                    return x.length > 0
                })
                if (shell.wallpapers.length > 0 && shell.currentWallpaper === "") {
                    shell.currentWallpaper = "file://" + shell.wallpapers[0]
                }
            }
        }
    }

    Process {
        id: focusedProcess
        command: ["sh", "-c", "niri msg -j focused-window 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    shell.focusedTitle = d.title || "Desktop"
                    shell.focusedApp = d.app_id || "Niri"
                } catch (e) {
                    shell.focusedTitle = "Desktop"
                    shell.focusedApp = "Niri"
                }
            }
        }
    }

    Process {
        id: workspaceProcess
        command: ["sh", "-c", "niri msg -j workspaces 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const all = JSON.parse(text)
                    const foc = all.find(function(w) { return w.is_focused })
                    const out = foc ? foc.output : null
                    const list = all.filter(function(w) {
                        return out === null || w.output === out
                    }).sort(function(a, b) { return a.idx - b.idx })
                    if (list.length > 0)
                        shell.workspaces = list.map(function(w) {
                            return { idx: w.idx, active: w.is_active }
                        })
                } catch (e) {}
            }
        }
    }

    Process {
        id: niriEvents
        command: ["niri", "msg", "-j", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: data => refreshDebounce.restart()
        }
    }

    Timer {
        id: refreshDebounce
        interval: 60
        onTriggered: {
            focusedProcess.running = true
            workspaceProcess.running = true
        }
    }

    Process {
        id: networkProcess
        command: ["sh", "-c", "nmcli -t -f WIFI g 2>/dev/null | head -1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: shell.networkText = text.trim() === "enabled" ? "On" : "Off"
        }
    }

    Process {
        id: volumeProcess
        command: ["sh", "-c",
            "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | " +
            "awk '{v=sprintf(\"%d%%\", $2*100); if ($3==\"[MUTED]\") v=\"Muted\"; printf \"%s\", v}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: shell.volumeText = text.trim() || "N/A"
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: shell.clockText = Qt.formatTime(new Date(), "HH:mm")
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            networkProcess.running = true
            volumeProcess.running = true
        }
    }

    // =====================================================================
    //  BACKGROUND WALLPAPER WINDOW (SMOOTH CROSSFADE)
    // =====================================================================
    PanelWindow {
        id: wallpaperWindow
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: -1
        color: "#000000"

        WlrLayershell.namespace: "m3-wallpaper"
        WlrLayershell.layer: WlrLayer.Background

        // Base Layer (Current Wallpaper)
        Image {
            id: currentImg
            anchors.fill: parent
            source: shell.currentWallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }

        // Top Transition Layer (Target Wallpaper)
        Image {
            id: targetImg
            anchors.fill: parent
            source: shell.nextWallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            opacity: 0

            onStatusChanged: {
                if (status === Image.Ready && shell.nextWallpaper !== "") {
                    fadeAnimation.restart()
                }
            }

            NumberAnimation on opacity {
                id: fadeAnimation
                running: false
                from: 0
                to: 1
                duration: 600
                easing.type: Easing.InOutQuad
                onFinished: {
                    shell.currentWallpaper = shell.nextWallpaper
                    shell.nextWallpaper = ""
                    targetImg.opacity = 0
                }
            }
        }
    }

    // =====================================================================
    //  NOTIFICATIONS DAEMON
    // =====================================================================
    Scope {
        id: notificationDaemon

        NotificationServer {
            id: notifServer
        }

        PanelWindow {
            id: notificationWindow

            anchors { top: true; right: true }
            margins { top: 12; right: 12 }
            implicitWidth: 360
            implicitHeight: notifColumn.implicitHeight
            exclusiveZone: 0
            color: "transparent"

            WlrLayershell.namespace: "m3-notifications"
            WlrLayershell.layer: WlrLayer.Overlay

            Column {
                id: notifColumn
                width: 360
                spacing: 8

                Repeater {
                    model: notifServer.trackedNotifications

                    Rectangle {
                        id: notifTile
                        required property var modelData

                        width: parent.width
                        implicitHeight: notifLayout.implicitHeight + 20
                        radius: 16
                        color: shell.theme.surfaceContainer
                        border.width: 1
                        border.color: shell.theme.outlineVariant
                        clip: true

                        ColumnLayout {
                            id: notifLayout
                            anchors { left: parent.left; right: parent.right; top: parent.top }
                            anchors.margins: 10
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Image {
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                    source: modelData.icon !== "" ? Quickshell.iconPath(modelData.icon, true) : ""
                                    visible: source != ""
                                    asynchronous: true
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.appName || "Notification"
                                    color: shell.theme.primary
                                    font.family: shell.mono
                                    font.pixelSize: 11
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "\uF00D"
                                    font.family: shell.icons
                                    font.pixelSize: 12
                                    color: closeMouse.containsMouse ? shell.theme.primary : shell.theme.onSurfaceVariant

                                    MouseArea {
                                        id: closeMouse
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: modelData.dismiss()
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.summary
                                color: shell.theme.onSurface
                                font.family: shell.mono
                                font.pixelSize: 12
                                font.bold: true
                                elide: Text.ElideRight
                                visible: text !== ""
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.body
                                color: shell.theme.onSurfaceVariant
                                font.family: shell.mono
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                visible: text !== ""
                            }

                            Row {
                                Layout.fillWidth: true
                                spacing: 6
                                visible: modelData.actions.length > 0

                                Repeater {
                                    model: modelData.actions

                                    Rectangle {
                                        required property var modelData
                                        width: actionText.implicitWidth + 16
                                        height: 24
                                        radius: 12
                                        color: shell.theme.surfaceContainerHigh
                                        border.width: 1
                                        border.color: shell.theme.outlineVariant

                                        Text {
                                            id: actionText
                                            anchors.centerIn: parent
                                            text: modelData.text
                                            color: shell.theme.onSurface
                                            font.pixelSize: 10
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: modelData.invoke()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // =====================================================================
    //  PILL
    // =====================================================================
    PanelWindow {
        id: panel

        anchors { top: true }
        implicitWidth: Math.max(720, pill.width + 40)
        implicitHeight: shell.pillHeight + 20
        exclusiveZone: 0
        color: "transparent"
        mask: Region { item: pill }

        WlrLayershell.namespace: "m3-pill"

        Rectangle {
            id: pill

            property bool shown: false

            anchors.horizontalCenter: parent.horizontalCenter
            y: shown ? 8 : -height - 6
            height: shell.pillHeight
            width: segments.implicitWidth + Math.round(30 * shell.pillScale)
            radius: height / 2
            color: Qt.alpha(shell.theme.surface, 0.94)
            border.width: 1
            border.color: Qt.alpha(shell.theme.outlineVariant, 0.8)

            Behavior on y { NumberAnimation { duration: 550; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Behavior on height { NumberAnimation { duration: 200 } }
            Behavior on width { NumberAnimation { duration: 200 } }
            Behavior on color { ColorAnimation { duration: 250 } }
            Behavior on border.color { ColorAnimation { duration: 250 } }

            Component.onCompleted: shown = true

            Row {
                id: segments
                anchors.centerIn: parent
                spacing: Math.round(16 * shell.pillScale)

                // ---- segment 1: launcher + workspaces ----
                Item {
                    width: leftRow.implicitWidth
                    height: pill.height

                    Row {
                        id: leftRow
                        height: parent.height
                        spacing: Math.round(10 * shell.pillScale)

                        Item {
                            width: Math.round(16 * shell.pillScale)
                            height: parent.height

                            Text {
                                id: launchGlyph
                                anchors.centerIn: parent
                                text: "\uF002"
                                font.family: shell.icons
                                font.pixelSize: Math.round(13 * shell.pillScale)
                                color: launchMouse.containsMouse || shell.mode === "launcher"
                                    ? shell.theme.primary
                                    : shell.theme.onSurfaceVariant
                                scale: launchMouse.containsMouse ? 1.2 : 1.0
                                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }

                            MouseArea {
                                id: launchMouse
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: shell.toggle("launcher")
                            }
                        }

                        Row {
                            height: parent.height
                            spacing: Math.round(5 * shell.pillScale)

                            Repeater {
                                model: shell.workspaces

                                Rectangle {
                                    required property var modelData

                                    anchors.verticalCenter: parent.verticalCenter
                                    width: modelData.active ? Math.round(18 * shell.pillScale) : Math.round(6 * shell.pillScale)
                                    height: Math.round(6 * shell.pillScale)
                                    radius: height / 2
                                    color: modelData.active
                                        ? shell.theme.primary
                                        : Qt.alpha(shell.theme.onSurfaceVariant, 0.45)

                                    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 220 } }

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -5
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: shell.run(["niri", "msg", "action", "focus-workspace", String(modelData.idx)])
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- segment 2: clock (hover reveals focused window) ----
                Item {
                    width: clockRow.implicitWidth
                    height: pill.height

                    Row {
                        id: clockRow
                        height: parent.height

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: shell.clockText
                            color: shell.theme.onSurface
                            font.family: shell.mono
                            font.pixelSize: Math.round(12 * shell.pillScale)
                            font.bold: true
                        }

                        Item {
                            id: titleClip
                            anchors.verticalCenter: parent.verticalCenter
                            height: Math.round(16 * shell.pillScale)
                            clip: true
                            width: clockMouse.containsMouse
                                ? Math.min(titleText.implicitWidth, Math.round(220 * shell.pillScale)) + Math.round(10 * shell.pillScale)
                                : 0
                            opacity: clockMouse.containsMouse ? 1 : 0

                            Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 200 } }

                            Text {
                                id: titleText
                                x: Math.round(10 * shell.pillScale)
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, Math.round(220 * shell.pillScale))
                                text: shell.focusedTitle
                                elide: Text.ElideRight
                                color: shell.theme.onSurfaceVariant
                                font.family: shell.mono
                                font.pixelSize: Math.round(11 * shell.pillScale)
                            }
                        }
                    }

                    MouseArea {
                        id: clockMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shell.toggle("control")
                    }
                }

                // ---- segment 3: status ----
                Item {
                    width: statusRow.implicitWidth
                    height: pill.height

                    Row {
                        id: statusRow
                        height: parent.height
                        spacing: Math.round(10 * shell.pillScale)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: shell.networkText === "On" ? "\uF1EB" : "\uF05E"
                            font.family: shell.icons
                            font.pixelSize: Math.round(12 * shell.pillScale)
                            color: statusMouse.containsMouse || shell.mode === "control"
                                ? shell.theme.primary
                                : shell.theme.onSurfaceVariant
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: shell.volumeText === "Muted" ? "\uF026" : "\uF028"
                            font.family: shell.icons
                            font.pixelSize: Math.round(12 * shell.pillScale)
                            color: statusMouse.containsMouse || shell.mode === "control"
                                ? shell.theme.primary
                                : shell.theme.onSurfaceVariant
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }
                    }

                    MouseArea {
                        id: statusMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shell.toggle("control")
                    }
                }
            }
        }
    }

    // =====================================================================
    //  OVERLAY (launcher + control center)
    // =====================================================================
    PanelWindow {
        id: overlay

        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        color: "transparent"
        visible: shell.mode !== "" || dim.opacity > 0.01

        WlrLayershell.namespace: "m3-overlay"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: shell.mode !== ""
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        Connections {
            target: shell
            function onModeChanged() {
                if (shell.mode === "launcher") {
                    shell.query = ""
                    shell.selected = 0
                    searchInput.text = ""
                    searchInput.forceActiveFocus()
                } else if (shell.mode === "control") {
                    keyCatcher.forceActiveFocus()
                }
            }
        }

        Item {
            id: keyCatcher
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: shell.mode = ""
        }

        Rectangle {
            id: dim
            anchors.fill: parent
            color: "#000000"
            opacity: shell.mode !== "" ? 0.30 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            MouseArea {
                anchors.fill: parent
                onClicked: shell.mode = ""
            }
        }

        // ------------------------- LAUNCHER -------------------------
        Rectangle {
            id: launcherCard

            readonly property bool open: shell.mode === "launcher"

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.20

            width: shell.launcherWidth
            height: Math.round(62 * shell.launcherScale) + (shell.results.length > 0 ? shell.results.length * Math.round(48 * shell.launcherScale) + Math.round(14 * shell.launcherScale) : 0)
            radius: Math.round(26 * shell.launcherScale)
            color: shell.theme.surfaceContainer
            border.width: 1
            border.color: shell.theme.outlineVariant
            clip: true

            opacity: open ? 1 : 0
            scale: open ? 1 : 0.94
            visible: opacity > 0.01
            transform: Translate { y: launcherCard.open ? 0 : -14; Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } } }

            Behavior on opacity { NumberAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 250 } }

            MouseArea { anchors.fill: parent }

            Text {
                x: Math.round(22 * shell.launcherScale)
                y: 0
                height: Math.round(62 * shell.launcherScale)
                verticalAlignment: Text.AlignVCenter
                text: "\uF002"
                font.family: shell.icons
                font.pixelSize: Math.round(16 * shell.launcherScale)
                color: shell.theme.primary
            }

            TextInput {
                id: searchInput
                x: Math.round(54 * shell.launcherScale)
                y: 0
                width: parent.width - Math.round(76 * shell.launcherScale)
                height: Math.round(62 * shell.launcherScale)
                verticalAlignment: TextInput.AlignVCenter
                color: shell.theme.onSurface
                selectionColor: shell.theme.primary
                selectedTextColor: shell.theme.onPrimary
                font.family: shell.mono
                font.pixelSize: Math.round(16 * shell.launcherScale)
                clip: true

                onTextChanged: {
                    shell.query = text
                    shell.selected = 0
                }

                Keys.onEscapePressed: shell.mode = ""
                Keys.onDownPressed: shell.selected = Math.min(shell.selected + 1, shell.results.length - 1)
                Keys.onUpPressed: shell.selected = Math.max(shell.selected - 1, 0)
                Keys.onTabPressed: shell.selected = Math.min(shell.selected + 1, shell.results.length - 1)
                Keys.onReturnPressed: shell.launch(shell.results[shell.selected])
                Keys.onEnterPressed: shell.launch(shell.results[shell.selected])

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: searchInput.text.length === 0
                    text: "Search applications"
                    color: shell.theme.onSurfaceVariant
                    font: searchInput.font
                    opacity: 0.7
                }
            }

            Rectangle {
                x: Math.round(20 * shell.launcherScale)
                y: Math.round(61 * shell.launcherScale)
                width: parent.width - Math.round(40 * shell.launcherScale)
                height: 1
                color: shell.theme.outlineVariant
                opacity: shell.results.length > 0 ? 0.7 : 0
            }

            Rectangle {
                x: Math.round(8 * shell.launcherScale)
                y: Math.round(68 * shell.launcherScale) + shell.selected * Math.round(48 * shell.launcherScale)
                width: parent.width - Math.round(16 * shell.launcherScale)
                height: Math.round(44 * shell.launcherScale)
                radius: Math.round(16 * shell.launcherScale)
                color: shell.theme.surfaceContainerHigh
                visible: shell.results.length > 0
                Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }

            Column {
                x: Math.round(8 * shell.launcherScale)
                y: Math.round(68 * shell.launcherScale)
                width: parent.width - Math.round(16 * shell.launcherScale)

                Repeater {
                    model: shell.results

                    Item {
                        required property var modelData
                        required property int index

                        width: parent.width
                        height: Math.round(48 * shell.launcherScale)

                        Image {
                            id: appIcon
                            x: Math.round(14 * shell.launcherScale)
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.round(28 * shell.launcherScale)
                            height: Math.round(28 * shell.launcherScale)
                            sourceSize.width: Math.round(56 * shell.launcherScale)
                            sourceSize.height: Math.round(56 * shell.launcherScale)
                            source: Quickshell.iconPath(modelData.icon, true)
                            asynchronous: true
                            visible: source != ""
                        }

                        Text {
                            x: Math.round(56 * shell.launcherScale)
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Math.round(72 * shell.launcherScale)
                            text: modelData.name
                            elide: Text.ElideRight
                            color: index === shell.selected ? shell.theme.onSurface : shell.theme.onSurfaceVariant
                            font.family: shell.mono
                            font.pixelSize: Math.round(13 * shell.launcherScale)
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: shell.selected = index
                            onClicked: shell.launch(modelData)
                        }
                    }
                }
            }
        }

        // ------------------------- CONTROL CENTER -------------------------
        Rectangle {
            id: controlCard

            readonly property bool open: shell.mode === "control"

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 56

            width: shell.controlWidth
            height: Math.min(parent.height - 100, Math.round(580 * shell.controlScale))
            radius: Math.round(26 * shell.controlScale)
            color: shell.theme.surfaceContainer
            border.width: 1
            border.color: shell.theme.outlineVariant
            clip: true

            opacity: open ? 1 : 0
            scale: open ? 1 : 0.94
            transformOrigin: Item.Top
            visible: opacity > 0.01

            Behavior on opacity { NumberAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 250 } }

            MouseArea { anchors.fill: parent }

            Flickable {
                anchors.fill: parent
                anchors.margins: Math.round(18 * shell.controlScale)
                contentWidth: width
                contentHeight: controlColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: controlColumn
                    width: parent.width
                    spacing: Math.round(12 * shell.controlScale)

                    Text {
                        text: "Control Center"
                        color: shell.theme.onSurface
                        font.family: shell.mono
                        font.pixelSize: Math.round(18 * shell.controlScale)
                        font.bold: true
                    }

                    // status tiles
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.round(56 * shell.controlScale)
                            radius: Math.round(18 * shell.controlScale)
                            color: shell.theme.surfaceContainerHigh

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Math.round(14 * shell.controlScale)
                                spacing: 10

                                Text {
                                    text: shell.networkText === "On" ? "\uF1EB" : "\uF05E"
                                    font.family: shell.icons
                                    font.pixelSize: Math.round(16 * shell.controlScale)
                                    color: shell.theme.primary
                                }

                                ColumnLayout {
                                    spacing: 0
                                    Text { text: "Wi-Fi"; color: shell.theme.onSurface; font.pixelSize: Math.round(12 * shell.controlScale); font.bold: true }
                                    Text { text: shell.networkText; color: shell.theme.onSurfaceVariant; font.pixelSize: Math.round(10 * shell.controlScale) }
                                }
                            }
                        }

                        Rectangle {
                            id: volTile
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.round(56 * shell.controlScale)
                            radius: Math.round(18 * shell.controlScale)
                            color: volMouse.containsMouse ? Qt.lighter(shell.theme.surfaceContainerHigh, 1.15) : shell.theme.surfaceContainerHigh
                            scale: volMouse.pressed ? 0.96 : 1
                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 140 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Math.round(14 * shell.controlScale)
                                spacing: 10

                                Text {
                                    text: shell.volumeText === "Muted" ? "\uF026" : "\uF028"
                                    font.family: shell.icons
                                    font.pixelSize: Math.round(16 * shell.controlScale)
                                    color: shell.theme.primary
                                }

                                ColumnLayout {
                                    spacing: 0
                                    Text { text: "Volume"; color: shell.theme.onSurface; font.pixelSize: Math.round(12 * shell.controlScale); font.bold: true }
                                    Text { text: shell.volumeText; color: shell.theme.onSurfaceVariant; font.pixelSize: Math.round(10 * shell.controlScale) }
                                }
                            }

                            MouseArea {
                                id: volMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    shell.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                                    volumeProcess.running = true
                                }
                            }
                        }
                    }

                    // sizing / scale configuration
                    Text {
                        text: "UI SIZE & SCALE"
                        color: shell.theme.primary
                        font.pixelSize: Math.round(10 * shell.controlScale)
                        font.bold: true
                        font.letterSpacing: 1.2
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        // Pill scale controller
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: "Pill Size (" + Math.round(shell.pillScale * 100) + "%)"
                                color: shell.theme.onSurface
                                font.pixelSize: Math.round(11 * shell.controlScale)
                            }
                            Rectangle {
                                width: 28; height: 24; radius: 6
                                color: shell.theme.surfaceContainerHigh
                                Text { anchors.centerIn: parent; text: "-"; color: shell.theme.onSurface }
                                MouseArea { anchors.fill: parent; onClicked: shell.pillScale = Math.max(0.7, shell.pillScale - 0.1) }
                            }
                            Rectangle {
                                width: 28; height: 24; radius: 6
                                color: shell.theme.surfaceContainerHigh
                                Text { anchors.centerIn: parent; text: "+"; color: shell.theme.onSurface }
                                MouseArea { anchors.fill: parent; onClicked: shell.pillScale = Math.min(2.0, shell.pillScale + 0.1) }
                            }
                        }

                        // Launcher width controller
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: "Launcher Width (" + shell.launcherWidth + "px)"
                                color: shell.theme.onSurface
                                font.pixelSize: Math.round(11 * shell.controlScale)
                            }
                            Rectangle {
                                width: 28; height: 24; radius: 6
                                color: shell.theme.surfaceContainerHigh
                                Text { anchors.centerIn: parent; text: "-"; color: shell.theme.onSurface }
                                MouseArea { anchors.fill: parent; onClicked: shell.launcherScale = Math.max(0.7, shell.launcherScale - 0.1) }
                            }
                            Rectangle {
                                width: 28; height: 24; radius: 6
                                color: shell.theme.surfaceContainerHigh
                                Text { anchors.centerIn: parent; text: "+"; color: shell.theme.onSurface }
                                MouseArea { anchors.fill: parent; onClicked: shell.launcherScale = Math.min(2.0, shell.launcherScale + 0.1) }
                            }
                        }

                        // Control Center scale controller
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: "Control Center Size (" + Math.round(shell.controlScale * 100) + "%)"
                                color: shell.theme.onSurface
                                font.pixelSize: Math.round(11 * shell.controlScale)
                            }
                            Rectangle {
                                width: 28; height: 24; radius: 6
                                color: shell.theme.surfaceContainerHigh
                                Text { anchors.centerIn: parent; text: "-"; color: shell.theme.onSurface }
                                MouseArea { anchors.fill: parent; onClicked: shell.controlScale = Math.max(0.7, shell.controlScale - 0.1) }
                            }
                            Rectangle {
                                width: 28; height: 24; radius: 6
                                color: shell.theme.surfaceContainerHigh
                                Text { anchors.centerIn: parent; text: "+"; color: shell.theme.onSurface }
                                MouseArea { anchors.fill: parent; onClicked: shell.controlScale = Math.min(2.0, shell.controlScale + 0.1) }
                            }
                        }
                    }

                    Text {
                        text: "THEME"
                        color: shell.theme.primary
                        font.pixelSize: Math.round(10 * shell.controlScale)
                        font.bold: true
                        font.letterSpacing: 1.2
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: Object.keys(shell.themes)

                            Rectangle {
                                required property string modelData
                                readonly property bool active: shell.themeName === modelData

                                width: chipText.implicitWidth + Math.round(26 * shell.controlScale)
                                height: Math.round(32 * shell.controlScale)
                                radius: height / 2
                                color: active ? shell.theme.primary : shell.theme.surfaceContainerHigh
                                border.width: 1
                                border.color: active ? shell.theme.primary : shell.theme.outlineVariant
                                scale: chipMouse.pressed ? 0.94 : 1

                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on scale { NumberAnimation { duration: 100 } }

                                Text {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: parent.active ? shell.theme.onPrimary : shell.theme.onSurface
                                    font.pixelSize: Math.round(10 * shell.controlScale)
                                }

                                MouseArea {
                                    id: chipMouse
                                    anchors.fill: parent
                                    onClicked: shell.setTheme(modelData)
                                }
                            }
                        }
                    }

                    Text {
                        text: "WALLPAPER"
                        color: shell.theme.primary
                        font.pixelSize: Math.round(10 * shell.controlScale)
                        font.bold: true
                        font.letterSpacing: 1.2
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 8
                        rowSpacing: 8

                        Repeater {
                            model: shell.wallpapers

                            Rectangle {
                                required property string modelData

                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.round(84 * shell.controlScale)
                                radius: Math.round(16 * shell.controlScale)
                                color: shell.theme.surfaceContainerHigh
                                clip: true
                                scale: wpMouse.containsMouse ? 1.03 : 1
                                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                                Image {
                                    anchors.fill: parent
                                    source: "file://" + modelData
                                    sourceSize.width: 400
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }

                                MouseArea {
                                    id: wpMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: shell.setWallpaper(modelData)
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: shell.wallpapers.length === 0
                        text: "No wallpapers. Add images to ~/Pictures/Wallpapers"
                        color: shell.theme.onSurfaceVariant
                        font.pixelSize: Math.round(10 * shell.controlScale)
                        wrapMode: Text.Wrap
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(38 * shell.controlScale)
                        radius: height / 2
                        color: folderMouse.containsMouse ? shell.theme.surfaceContainerHigh : "transparent"
                        border.width: 1
                        border.color: shell.theme.outlineVariant
                        Behavior on color { ColorAnimation { duration: 140 } }

                        Text {
                            anchors.centerIn: parent
                            text: "Open wallpaper folder"
                            color: shell.theme.onSurface
                            font.pixelSize: Math.round(10 * shell.controlScale)
                        }

                        MouseArea {
                            id: folderMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: shell.run(["xdg-open", shell.wallpaperFolder])
                        }
                    }
                }
            }
        }
    }
}
