//
//  PreferencesManager.swift
//  ScreenshotTool
//
//  Created by yakir on 2026/3/25.
//

import Cocoa

/// 截图完成后的行为
enum CaptureAction: String {
  case copy = "copy"      // 仅复制到剪贴板
  case save = "save"      // 仅保存到文件
  case edit = "edit"      // 打开编辑器
  case ask = "ask"        // 弹出询问菜单
}

class PreferencesManager {

  static let shared = PreferencesManager()

  private let defaults = UserDefaults.standard

  // MARK: - Keys

  private enum Key: String {
    case saveFormat = "saveFormat"
    case defaultSaveLocation = "defaultSaveLocation"
    case playSoundOnCapture = "playSoundOnCapture"
    case copyToClipboardOnCapture = "copyToClipboardOnCapture"
    case showInMenuBar = "showInMenuBar"
    case defaultAnnotationColor = "defaultAnnotationColor"
    case defaultLineWidth = "defaultLineWidth"
    case saveToHistory = "saveToHistory"
    case maxHistoryCount = "maxHistoryCount"
    case captureMouseCursor = "captureMouseCursor"
    case captureAction = "captureAction"
  }

  // MARK: - Properties

  var saveFormat: String {
    get { defaults.string(forKey: Key.saveFormat.rawValue) ?? "png" }
    set { defaults.set(newValue, forKey: Key.saveFormat.rawValue) }
  }

  var defaultSaveLocation: String {
    get {
      defaults.string(forKey: Key.defaultSaveLocation.rawValue) ?? NSHomeDirectory()
        + "/Desktop"
    }
    set { defaults.set(newValue, forKey: Key.defaultSaveLocation.rawValue) }
  }

  var playSoundOnCapture: Bool {
    get { defaults.object(forKey: Key.playSoundOnCapture.rawValue) as? Bool ?? true }
    set { defaults.set(newValue, forKey: Key.playSoundOnCapture.rawValue) }
  }

  var copyToClipboardOnCapture: Bool {
    get { defaults.object(forKey: Key.copyToClipboardOnCapture.rawValue) as? Bool ?? true }
    set { defaults.set(newValue, forKey: Key.copyToClipboardOnCapture.rawValue) }
  }

  var saveToHistory: Bool {
    get { defaults.object(forKey: Key.saveToHistory.rawValue) as? Bool ?? true }
    set { defaults.set(newValue, forKey: Key.saveToHistory.rawValue) }
  }

  var defaultLineWidth: CGFloat {
    get {
      CGFloat(
        defaults.double(forKey: Key.defaultLineWidth.rawValue) != 0
          ? defaults.double(forKey: Key.defaultLineWidth.rawValue) : 2)
    }
    set { defaults.set(Double(newValue), forKey: Key.defaultLineWidth.rawValue) }
  }

  var captureMouseCursor: Bool {
    get { defaults.object(forKey: Key.captureMouseCursor.rawValue) as? Bool ?? false }
    set { defaults.set(newValue, forKey: Key.captureMouseCursor.rawValue) }
  }

  var captureAction: CaptureAction {
    get {
      let raw = defaults.string(forKey: Key.captureAction.rawValue) ?? CaptureAction.edit.rawValue
      return CaptureAction(rawValue: raw) ?? .edit
    }
    set { defaults.set(newValue.rawValue, forKey: Key.captureAction.rawValue) }
  }

  var maxHistoryCount: Int {
    get {
      let v = defaults.integer(forKey: Key.maxHistoryCount.rawValue)
      return v > 0 ? v : 50
    }
    set { defaults.set(newValue, forKey: Key.maxHistoryCount.rawValue) }
  }

  // MARK: - 默认标注颜色

  var defaultAnnotationColor: NSColor {
    get {
      if let data = defaults.data(forKey: Key.defaultAnnotationColor.rawValue),
        let color = try? NSKeyedUnarchiver.unarchivedObject(
          ofClass: NSColor.self, from: data)
      {
        return color
      }
      return .systemRed
    }
    set {
      if let data = try? NSKeyedArchiver.archivedData(
        withRootObject: newValue, requiringSecureCoding: true)
      {
        defaults.set(data, forKey: Key.defaultAnnotationColor.rawValue)
      }
    }
  }
}
