//
//  FullScreenCaptureManager.swift
//  ScreenshotTool
//
//  Created by yakir on 2026/3/24.
//

import Cocoa

class FullScreenCaptureManager {

  static let shared = FullScreenCaptureManager()

  func capture() {
    Task { @MainActor in
      do {
        let image = try await ScreenCaptureService.shared.captureFullScreen()

        if PreferencesManager.shared.saveToHistory {
          HistoryManager.shared.save(image: image)
        }

        if PreferencesManager.shared.playSoundOnCapture {
          NSSound(named: "Tink")?.play()
        }

        SelectionCaptureManager.shared.performAction(for: image)

      } catch {
        showError(error.localizedDescription)
      }
    }
  }

  private func showError(_ message: String) {
    let alert = NSAlert()
    alert.messageText = "截图失败"
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.addButton(withTitle: "打开系统设置")
    alert.addButton(withTitle: "取消")

    if alert.runModal() == .alertFirstButtonReturn {
      ScreenCaptureService.shared.openPermissionSettings()
    }
  }
}
