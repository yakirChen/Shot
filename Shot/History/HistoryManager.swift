//
//  HistoryManager.swift
//  ScreenshotTool
//
//  Created by yakir on 2026/3/25.
//

import Cocoa

class HistoryManager {

  static let shared = HistoryManager()

  enum ItemType: String, Codable {
    case screenshot
    case clipboardText
    case clipboardImage
  }

  struct HistoryItem: Codable {
    let id: String
    let date: Date
    let type: ItemType
    let width: Int?
    let height: Int?
    let filePath: String?
    let textContent: String?

    var displayName: String {
      let formatter = DateFormatter()
      formatter.dateFormat = "HH:mm:ss"
      let time = formatter.string(from: date)
      
      switch type {
      case .screenshot:
        return "\(time) - 截图 \(width ?? 0)×\(height ?? 0)"
      case .clipboardImage:
        return "\(time) - 剪贴板图片 \(width ?? 0)×\(height ?? 0)"
      case .clipboardText:
        let preview = textContent?.prefix(30).replacingOccurrences(of: "\n", with: " ") ?? ""
        return "\(time) - \(preview)"
      }
    }
  }

  private(set) var items: [HistoryItem] = []
  private let maxItems = 50
  private let historyDirectory: URL
  private let indexFile: URL

  private init() {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    historyDirectory = appSupport.appendingPathComponent("Shot/History", isDirectory: true)
    indexFile = historyDirectory.appendingPathComponent("index.json")

    // 创建目录
    try? FileManager.default.createDirectory(
      at: historyDirectory, withIntermediateDirectories: true)

    // 加载历史
    loadIndex()
  }

  // MARK: - 保存截图到历史

  func save(image: NSImage) {
    let id = UUID().uuidString
    let fileName = "\(id).png"
    let filePath = historyDirectory.appendingPathComponent(fileName)

    // 保存图片
    guard let tiffData = image.tiffRepresentation,
      let bitmapRep = NSBitmapImageRep(data: tiffData),
      let pngData = bitmapRep.representation(using: .png, properties: [:])
    else {
      return
    }

    do {
      try pngData.write(to: filePath)
    } catch {
      print("历史保存失败: \(error)")
      return
    }

    let item = HistoryItem(
      id: id,
      date: Date(),
      type: .screenshot,
      width: Int(image.size.width),
      height: Int(image.size.height),
      filePath: filePath.path,
      textContent: nil
    )

    items.insert(item, at: 0)

    // 限制数量
    while items.count > maxItems {
      let removed = items.removeLast()
      if let path = removed.filePath {
        try? FileManager.default.removeItem(atPath: path)
      }
    }

    saveIndex()

    // 发送变更通知
    NotificationCenter.default.post(name: .historyDidChange, object: nil)
  }
  
  // MARK: - 保存剪贴板到历史
  
  func saveClipboardText(_ text: String) {
    let item = HistoryItem(
      id: UUID().uuidString,
      date: Date(),
      type: .clipboardText,
      width: nil,
      height: nil,
      filePath: nil,
      textContent: text
    )
    
    items.insert(item, at: 0)
    
    while items.count > maxItems {
      let removed = items.removeLast()
      if let path = removed.filePath {
        try? FileManager.default.removeItem(atPath: path)
      }
    }
    
    saveIndex()
    NotificationCenter.default.post(name: .historyDidChange, object: nil)
  }
  
  func saveClipboardImage(_ image: NSImage) {
    let id = UUID().uuidString
    let fileName = "\(id).png"
    let filePath = historyDirectory.appendingPathComponent(fileName)
    
    guard let tiffData = image.tiffRepresentation,
          let bitmapRep = NSBitmapImageRep(data: tiffData),
          let pngData = bitmapRep.representation(using: .png, properties: [:])
    else { return }
    
    try? pngData.write(to: filePath)
    
    let item = HistoryItem(
      id: id,
      date: Date(),
      type: .clipboardImage,
      width: Int(image.size.width),
      height: Int(image.size.height),
      filePath: filePath.path,
      textContent: nil
    )
    
    items.insert(item, at: 0)
    
    while items.count > maxItems {
      let removed = items.removeLast()
      if let path = removed.filePath {
        try? FileManager.default.removeItem(atPath: path)
      }
    }
    
    saveIndex()
    NotificationCenter.default.post(name: .historyDidChange, object: nil)
  }

  // MARK: - 获取历史图片

  func getImage(for item: HistoryItem) -> NSImage? {
    guard let path = item.filePath else { return nil }
    return NSImage(contentsOfFile: path)
  }

  // MARK: - 删除

  func delete(item: HistoryItem) {
    items.removeAll { $0.id == item.id }
    if let path = item.filePath {
      try? FileManager.default.removeItem(atPath: path)
    }
    saveIndex()

    // 发送变更通知
    NotificationCenter.default.post(name: .historyDidChange, object: nil)
  }

  func clearAll() {
    for item in items {
      if let path = item.filePath {
        try? FileManager.default.removeItem(atPath: path)
      }
    }
    items.removeAll()
    saveIndex()

    // 发送变更通知
    NotificationCenter.default.post(name: .historyDidChange, object: nil)
  }

  // MARK: - 持久化

  private func loadIndex() {
    guard let data = try? Data(contentsOf: indexFile) else { return }
    items = (try? JSONDecoder().decode([HistoryItem].self, from: data)) ?? []

    // 清理不存在的文件（只检查有文件路径的项）
    items = items.filter { item in
      guard let path = item.filePath else { return true }
      return FileManager.default.fileExists(atPath: path)
    }
  }

  private func saveIndex() {
    guard let data = try? JSONEncoder().encode(items) else { return }
    try? data.write(to: indexFile)
  }
}
