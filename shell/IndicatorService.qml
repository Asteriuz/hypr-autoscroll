pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Windows-style autoscroll indicator. The Hyprland plugin publishes the live
// session state (anchor point, scroll direction) to
// $XDG_RUNTIME_DIR/hypr-autoscroll/state; this service mirrors it as a small
// visual marker pinned to the activation point.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string statePath: Quickshell.env("XDG_RUNTIME_DIR") + "/hypr-autoscroll/state"

  // Parsed session state.
  property bool sessionActive: false
  property real anchorX: 0
  property real anchorY: 0
  property string dirV: "none"
  property string dirH: "none"
  property bool horizontal: true
  property bool vertical: true

  readonly property int bubbleSize: Style.space(60)
  readonly property real arrowSize: Style.space(17)

  readonly property var targetScreen: {
    var monitors = Hyprland.monitors.values
    for (var i = 0; i < monitors.length; i++) {
      var m = monitors[i]
      if (root.anchorX >= m.x && root.anchorX < m.x + m.width && root.anchorY >= m.y && root.anchorY < m.y + m.height) {
        for (var j = 0; j < Quickshell.screens.length; j++) {
          if (Quickshell.screens[j].name === m.name) return Quickshell.screens[j]
        }
      }
    }
    return null
  }

  function monitorFor(screen) {
    var monitors = Hyprland.monitors.values
    for (var i = 0; i < monitors.length; i++) {
      if (monitors[i].name === screen.name) return monitors[i]
    }
    return null
  }

  // Window position: center the bubble on the anchor, clamped on-screen.
  readonly property real bubbleX: {
    var screen = root.targetScreen
    if (!screen) return 0
    var m = root.monitorFor(screen)
    if (!m) return 0
    return Math.max(0, Math.min(root.anchorX - m.x - root.bubbleSize / 2, screen.width - root.bubbleSize))
  }
  readonly property real bubbleY: {
    var screen = root.targetScreen
    if (!screen) return 0
    var m = root.monitorFor(screen)
    if (!m) return 0
    return Math.max(0, Math.min(root.anchorY - m.y - root.bubbleSize / 2, screen.height - root.bubbleSize))
  }

  function parse(raw) {
    var state = null
    try {
      state = JSON.parse(raw)
    } catch (e) {
      state = null
    }
    if (!state || state.active !== true) {
      root.sessionActive = false
      root.dirV = "none"
      root.dirH = "none"
      return
    }
    root.sessionActive = true
    root.anchorX = Number(state.anchor && state.anchor.length > 0 ? state.anchor[0] : 0)
    root.anchorY = Number(state.anchor && state.anchor.length > 1 ? state.anchor[1] : 0)
    root.dirV = String(state.dirV || "none")
    root.dirH = String(state.dirH || "none")
    root.horizontal = state.horizontal !== false
    root.vertical = state.vertical !== false
  }

  function clear() {
    root.sessionActive = false
    root.dirV = "none"
    root.dirH = "none"
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parse(text())
    onLoadFailed: root.clear()
  }

  // Safety net: watches can go quiet after the state file is replaced, so
  // re-check on a slow timer as well.
  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: stateFile.reload()
  }

  PanelWindow {
    id: window

    visible: root.sessionActive && root.targetScreen !== null
    screen: root.targetScreen
    color: "transparent"

    anchors {
      left: true
      top: true
    }
    margins {
      left: root.bubbleX
      top: root.bubbleY
    }
    implicitWidth: root.bubbleSize
    implicitHeight: root.bubbleSize

    // Visual-only surface: empty input region so the indicator never blocks
    // the click that ends the session.
    mask: Region {}
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "hypr-autoscroll-indicator"

    Rectangle {
      id: bubble
      width: root.bubbleSize
      height: root.bubbleSize
      radius: width / 2
      color: Util.alpha(Commons.Color.popups.background, 0.93)
      border.width: 1
      border.color: Util.alpha(Commons.Color.popups.border, 0.65)
      opacity: window.visible ? 1 : 0
      Behavior on opacity {
        NumberAnimation {
          duration: 120
        }
      }

      Text {
        visible: root.vertical
        text: "↑"
        textFormat: Text.PlainText
        font.family: Style.font.family
        font.pixelSize: root.arrowSize
        font.bold: true
        color: root.dirV === "up" ? Commons.Color.popups.text : Util.alpha(Commons.Color.popups.text, 0.25)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Style.space(2)
      }

      Text {
        visible: root.vertical
        text: "↓"
        textFormat: Text.PlainText
        font.family: Style.font.family
        font.pixelSize: root.arrowSize
        font.bold: true
        color: root.dirV === "down" ? Commons.Color.popups.text : Util.alpha(Commons.Color.popups.text, 0.25)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(2)
      }

      Text {
        visible: root.horizontal
        text: "←"
        textFormat: Text.PlainText
        font.family: Style.font.family
        font.pixelSize: root.arrowSize
        font.bold: true
        color: root.dirH === "left" ? Commons.Color.popups.text : Util.alpha(Commons.Color.popups.text, 0.25)
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Style.space(4)
      }

      Text {
        visible: root.horizontal
        text: "→"
        textFormat: Text.PlainText
        font.family: Style.font.family
        font.pixelSize: root.arrowSize
        font.bold: true
        color: root.dirH === "right" ? Commons.Color.popups.text : Util.alpha(Commons.Color.popups.text, 0.25)
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: Style.space(4)
      }
    }
  }
}
