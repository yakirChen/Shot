//
//  SelectionCaptureManager.swift
//  ScreenshotTool
//
//  Created by yakir on 2026/3/24.
//

import Cocoa

class SelectionCaptureManager {

  static let shared = SelectionCaptureManager()

  private var overlayWindows: [SelectionOverlayWindow] = []
  private var countdownWindow: NSWindow?
  private var countdownTimer: Timer?

  // MARK: - 倒计时 HUD

  private func showCountdownHUD(seconds: Int, completion: @escaping () -> Void) {
    countdownTimer?.invalidate()
    countdownWindow?.close()

    let size = CGSize(width: 120, height: 120)
    let screen = NSScreen.main ?? NSScreen.screens[0]
    let origin = CGPoint(
      x: screen.frame.midX - size.width / 2,
      y: screen.frame.midY - size.height / 2
    )

    let window = NSWindow(
      contentRect: CGRect(origin: origin, size: size),
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    window.level = .statusBar + 2
    window.isOpaque = false
    window.backgroundColor = .clear
    window.ignoresMouseEvents = true

    let effect = NSVisualEffectView(frame: CGRect(origin: .zero, size: size))
    effect.material = .hudWindow
    effect.blendingMode = .behindWindow
    effect.state = .active
    effect.wantsLayer = true
    effect.layer?.cornerRadius = 20

    let label = NSTextField(labelWithString: "\(seconds)")
    label.font = .systemFont(ofSize: 56, weight: .bold)
    label.textColor = .white
    label.alignment = .center
    label.frame = CGRect(origin: .zero, size: size)
    effect.addSubview(label)

    window.contentView = effect
    window.orderFrontRegardless()
    countdownWindow = window

    var remaining = seconds
    countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self, weak label] timer in
      remaining -= 1
      if remaining <= 0 {
        timer.invalidate()
        self?.countdownTimer = nil
        self?.countdownWindow?.close()
        self?.countdownWindow = nil
        completion()
      } else {
        label?.stringValue = "\(remaining)"
      }
    }
  }

  func startCapture(detectWindows: Bool = false, delay: TimeInterval = 0) {
    if delay > 0 {
      showCountdownHUD(seconds: Int(delay)) { [weak self] in
        self?.startCapture(detectWindows: detectWindows, delay: 0)
      }
      return
    }

    Task { @MainActor in
      let hasPermission = await ScreenCaptureService.shared.checkPermission()
      if !hasPermission {
        ScreenCaptureService.shared.requestPermission()
        return
      }

      print("========== 屏幕信息 ==========")
      for (i, screen) in NSScreen.screens.enumerated() {
        let number =
          screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
          as? CGDirectDisplayID ?? 0
        print(
          "屏幕\(i): \(screen.localizedName) displayID=\(number) frame=\(screen.frame) scale=\(screen.backingScaleFactor)"
        )
      }
      print("主屏幕: \(NSScreen.main?.localizedName ?? "nil")")
      print("================================")

      // 为每个屏幕单独截冻结背景
      var frozenImages: [CGDirectDisplayID: NSImage] = [:]
      for screen in NSScreen.screens {
        let displayID =
          screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
          as? CGDirectDisplayID ?? 0
        do {
          let image = try await ScreenCaptureService.shared.captureFullScreen(
            screen: screen)
          frozenImages[displayID] = image
          print("✅ 冻结背景 屏幕\(screen.localizedName): \(image.size)")
        } catch {
          print("⚠️ 冻结背景失败 屏幕\(screen.localizedName): \(error)")
        }
      }

      // 为每个屏幕创建覆盖窗口
      for screen in NSScreen.screens {
        let displayID =
          screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
          as? CGDirectDisplayID ?? 0

        let window = SelectionOverlayWindow(screen: screen, detectWindows: detectWindows)

        if let view = window.contentView as? SelectionOverlayView {
          view.frozenBackground = frozenImages[displayID]
        }

        window.onComplete = { [weak self] rect, captureScreen in
          self?.finishCapture(selectionRect: rect, screen: captureScreen)
        }
        window.onCancel = { [weak self] in
          self?.cancelCapture()
        }

        overlayWindows.append(window)

        print("📌 创建覆盖窗口: screen=\(screen.localizedName) windowFrame=\(window.frame)")
      }

      // 显示所有窗口
      for window in overlayWindows {
        window.orderFrontRegardless()
      }

      // 让鼠标所在屏幕的窗口成为 key window
      let mouseLocation = NSEvent.mouseLocation
      let activeWindow =
        overlayWindows.first { $0.associatedScreen.frame.contains(mouseLocation) }
        ?? overlayWindows.first
      activeWindow?.makeKeyAndOrderFront(nil)

      NSApp.activate(ignoringOtherApps: true)

      print("🖱️ 鼠标位置: \(mouseLocation)")
      print("🔑 key window screen: \(activeWindow?.associatedScreen.localizedName ?? "nil")")
    }
  }

  private func finishCapture(selectionRect: CGRect, screen: NSScreen) {
    closeOverlays()

    guard selectionRect.width > 1 && selectionRect.height > 1 else { return }

    print("📐 finishCapture:")
    print("  selectionRect: \(selectionRect)")
    print(
      "  screen: \(screen.localizedName) frame=\(screen.frame) scale=\(screen.backingScaleFactor)"
    )

    Task { @MainActor in
      try? await Task.sleep(nanoseconds: 200_000_000)

      do {
        let image = try await ScreenCaptureService.shared.captureArea(
          rect: selectionRect,
          screen: screen
        )

        print("✅ 截图成功: \(image.size)")

        if PreferencesManager.shared.saveToHistory {
          HistoryManager.shared.save(image: image)
        }

        if PreferencesManager.shared.playSoundOnCapture {
          NSSound(named: "Tink")?.play()
        }

        self.performCaptureAction(for: image)

      } catch {
        print("❌ 截图失败: \(error)")
        let alert = NSAlert()
        alert.messageText = "截图失败"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
      }
    }
  }

  @MainActor
  func performAction(for image: NSImage) {
    performCaptureAction(for: image)
  }

  @MainActor
  private func performCaptureAction(for image: NSImage) {
    switch PreferencesManager.shared.captureAction {
    case .copy:
      NSPasteboard.general.clearContents()
      NSPasteboard.general.writeObjects([image])

    case .save:
      let prefs = PreferencesManager.shared
      let format = prefs.saveFormat
      let ext = format == "jpeg" ? "jpg" : format
      let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
      let fileName = "Shot_\(f.string(from: Date())).\(ext)"
      let url = URL(fileURLWithPath: prefs.defaultSaveLocation).appendingPathComponent(fileName)
      try? FileManager.default.createDirectory(
        at: URL(fileURLWithPath: prefs.defaultSaveLocation), withIntermediateDirectories: true)
      if let tiff = image.tiffRepresentation,
         let rep = NSBitmapImageRep(data: tiff) {
        let fileType: NSBitmapImageRep.FileType = format == "jpeg" ? .jpeg : (format == "tiff" ? .tiff : .png)
        try? rep.representation(using: fileType, properties: [:])?.write(to: url)
      }

    case .edit:
      EditorWindowController.show(with: image)

    case .ask:
      showActionMenu(for: image)
    }
  }

  @MainActor
  private func showActionMenu(for image: NSImage) {
    let alert = NSAlert()
    alert.messageText = "截图完成"
    alert.informativeText = "请选择截图后的操作："
    alert.addButton(withTitle: "编辑标注")
    alert.addButton(withTitle: "复制到剪贴板")
    alert.addButton(withTitle: "保存到文件")
    alert.addButton(withTitle: "取消")

    switch alert.runModal() {
    case .alertFirstButtonReturn:
      EditorWindowController.show(with: image)
    case .alertSecondButtonReturn:
      NSPasteboard.general.clearContents()
      NSPasteboard.general.writeObjects([image])
    case .alertThirdButtonReturn:
      let prefs = PreferencesManager.shared
      let format = prefs.saveFormat
      let ext = format == "jpeg" ? "jpg" : format
      let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
      let fileName = "Shot_\(f.string(from: Date())).\(ext)"
      let savePanel = NSSavePanel()
      savePanel.nameFieldStringValue = fileName
      if savePanel.runModal() == .OK, let url = savePanel.url {
        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff) {
          let fileType: NSBitmapImageRep.FileType = format == "jpeg" ? .jpeg : (format == "tiff" ? .tiff : .png)
          try? rep.representation(using: fileType, properties: [:])?.write(to: url)
        }
      }
    default:
      break
    }
  }

  func cancelCapture() {
    closeOverlays()
  }

  private func closeOverlays() {
    for window in overlayWindows {
      window.orderOut(nil)
    }
    overlayWindows.removeAll()
  }
}
