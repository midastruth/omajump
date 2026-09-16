import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property bool loading: false
  property string typed: ""
  property string focusedMonitorName: ""
  property var monitors: []
  property var hints: []

  readonly property string pluginId: (manifest && manifest.id) || "io.github.midastruth.omajump"

  function open(payload) {
    if (loading) return
    opened = false
    typed = ""
    hints = []
    monitors = []
    loading = true
    monitorQuery.running = true
  }

  function close() {
    prefixTimer.stop()
    typed = ""
    opened = false
  }

  function dismiss() {
    close()
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
  }

  function parseJson(text, fallback) {
    try { return JSON.parse(String(text || "")) } catch (error) {
      console.warn("omajump: could not parse hyprctl output:", error)
      return fallback
    }
  }

  function finishMonitorQuery(text) {
    var rows = parseJson(text, [])
    if (!Array.isArray(rows) || rows.length === 0) {
      loading = false
      return
    }

    monitors = rows
    focusedMonitorName = ""
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].focused === true) {
        focusedMonitorName = String(rows[i].name || "")
        break
      }
    }
    if (!focusedMonitorName) focusedMonitorName = String(rows[0].name || "")
    clientQuery.running = true
  }

  function finishClientQuery(text) {
    var clients = parseJson(text, [])
    var monitorById = ({})
    for (var i = 0; i < monitors.length; i++)
      monitorById[String(monitors[i].id)] = monitors[i]

    var visible = []
    if (Array.isArray(clients)) {
      for (var j = 0; j < clients.length; j++) {
        var client = clients[j]
        var monitor = monitorById[String(client.monitor)]
        if (!monitor || client.mapped === false || client.hidden === true) continue

        var workspaceId = Number(client.workspace && client.workspace.id)
        var activeId = Number(monitor.activeWorkspace && monitor.activeWorkspace.id)
        var specialId = Number(monitor.specialWorkspace && monitor.specialWorkspace.id)
        if (workspaceId !== activeId && !(specialId !== 0 && workspaceId === specialId)) continue

        var at = client.at || [0, 0]
        var size = client.size || [1, 1]
        var localX = Number(at[0] || 0) - Number(monitor.x || 0)
        var localY = Number(at[1] || 0) - Number(monitor.y || 0)
        var windowWidth = Math.max(1, Number(size[0] || 1))
        var windowHeight = Math.max(1, Number(size[1] || 1))
        var monitorScale = Math.max(0.1, Number(monitor.scale || 1))
        var monitorWidth = Number(monitor.width || 0) / monitorScale
        var monitorHeight = Number(monitor.height || 0) / monitorScale
        var transform = Number(monitor.transform || 0)
        if (transform === 1 || transform === 3 || transform === 5 || transform === 7) {
          var swapped = monitorWidth
          monitorWidth = monitorHeight
          monitorHeight = swapped
        }

        // Scrolling layouts keep off-screen clients on the active workspace.
        // A window is hintable only while its center is actually on the output.
        var centerX = localX + windowWidth / 2
        var centerY = localY + windowHeight / 2
        if (centerX < 0 || centerX > monitorWidth || centerY < 0 || centerY > monitorHeight) continue

        visible.push({
          address: String(client.address || ""),
          title: String(client.title || client.class || "Window"),
          className: String(client.class || ""),
          monitorName: String(monitor.name || ""),
          globalX: Number(at[0] || 0),
          globalY: Number(at[1] || 0),
          x: localX,
          y: localY,
          width: windowWidth,
          height: windowHeight
        })
      }
    }

    visible.sort(function(a, b) {
      var ay = a.globalY + a.height / 2
      var by = b.globalY + b.height / 2
      if (Math.abs(ay - by) > 24) return ay - by
      var ax = a.globalX + a.width / 2
      var bx = b.globalX + b.width / 2
      if (Math.abs(ax - bx) > 1) return ax - bx
      return a.address < b.address ? -1 : 1
    })

    for (var k = 0; k < visible.length; k++) {
      visible[k].number = k + 1
      visible[k].label = String(k + 1)
    }

    hints = visible
    loading = false
    opened = true
  }

  function hintsForScreen(name) {
    var result = []
    for (var i = 0; i < hints.length; i++)
      if (hints[i].monitorName === name) result.push(hints[i])
    return result
  }

  function hintForNumber(number) {
    for (var i = 0; i < hints.length; i++)
      if (hints[i].number === number) return hints[i]
    return null
  }

  function choose(hint) {
    if (!hint || !hint.address) return
    dismiss()
    var dispatcher = "hl.dsp.focus({ window = \"address:" + hint.address + "\" })"
    Quickshell.execDetached(["hyprctl", "dispatch", dispatcher])
  }

  function appendDigit(digit) {
    var next = typed + String(digit)
    var exact = null
    var longer = false
    var matches = false

    for (var i = 0; i < hints.length; i++) {
      var label = hints[i].label
      if (label.indexOf(next) !== 0) continue
      matches = true
      if (label === next) exact = hints[i]
      else longer = true
    }

    if (!matches) {
      typed = ""
      prefixTimer.stop()
      return
    }

    typed = next
    if (exact && !longer) {
      prefixTimer.stop()
      choose(exact)
    } else {
      prefixTimer.restart()
    }
  }

  function acceptTyped() {
    var hint = hintForNumber(Number(typed))
    if (hint) choose(hint)
    else typed = ""
  }

  function handleKey(event) {
    if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
      appendDigit(event.key - Qt.Key_0)
      event.accepted = true
    } else if (event.key === Qt.Key_Escape) {
      dismiss()
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      acceptTyped()
      event.accepted = true
    } else if (event.key === Qt.Key_Backspace) {
      typed = typed.length > 0 ? typed.slice(0, -1) : ""
      if (typed) prefixTimer.restart()
      else prefixTimer.stop()
      event.accepted = true
    }
  }

  Timer {
    id: prefixTimer
    interval: 500
    repeat: false
    onTriggered: root.acceptTyped()
  }

  Process {
    id: monitorQuery
    command: ["hyprctl", "monitors", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.finishMonitorQuery(text)
    }
  }

  Process {
    id: clientQuery
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.finishClientQuery(text)
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      visible: root.opened
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      anchors { top: true; bottom: true; left: true; right: true }

      readonly property string screenName: String(modelData.name || "")
      readonly property bool keyboardOwner: screenName === root.focusedMonitorName

      WlrLayershell.namespace: "omajump"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: panel.keyboardOwner && root.opened
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.18)
      }

      MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
      }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: panel.keyboardOwner && root.opened
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) { root.handleKey(event) }

        onFocusChanged: {
          if (panel.keyboardOwner && root.opened && !focus) forceActiveFocus()
        }
      }

      Rectangle {
        visible: panel.keyboardOwner
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Style.space(18)
        width: instruction.implicitWidth + Style.space(28)
        height: instruction.implicitHeight + Style.space(14)
        radius: height / 2
        color: Color.background
        border.width: Math.max(1, Style.space(1))
        border.color: Color.accent

        Text {
          id: instruction
          anchors.centerIn: parent
          text: root.typed
            ? "Window " + root.typed + "…  ·  Enter to select  ·  Esc to cancel"
            : "Type a window number  ·  Esc to cancel"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }
      }

      Repeater {
        model: root.hintsForScreen(panel.screenName)

        delegate: Rectangle {
          id: badge
          required property var modelData

          readonly property real centerX: modelData.x + modelData.width / 2
          readonly property real centerY: modelData.y + modelData.height / 2

          x: Math.max(8, Math.min(panel.width - width - 8, centerX - width / 2))
          y: Math.max(8, Math.min(panel.height - height - 8, centerY - height / 2))
          width: Math.max(Style.space(52), numberText.implicitWidth + Style.space(28))
          height: Style.space(52)
          radius: height / 2
          color: Color.accent
          border.width: Math.max(2, Style.space(2))
          border.color: Color.foreground
          scale: root.typed && modelData.label.indexOf(root.typed) !== 0 ? 0.82 : 1
          opacity: root.typed && modelData.label.indexOf(root.typed) !== 0 ? 0.35 : 1

          Behavior on scale { NumberAnimation { duration: 100 } }
          Behavior on opacity { NumberAnimation { duration: 100 } }

          Text {
            id: numberText
            anchors.centerIn: parent
            text: badge.modelData.label
            color: Color.background
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
          }

          MouseArea {
            anchors.fill: parent
            onClicked: root.choose(badge.modelData)
          }
        }
      }

      Text {
        visible: root.hints.length === 0 && panel.keyboardOwner
        anchors.centerIn: parent
        text: "No visible windows"
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.bold: true
      }
    }
  }
}
