import Foundation
import AppKit

class ClipboardHistoryManager {
    static let shared = ClipboardHistoryManager()
    
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var ignoreNextChange = false  // 防止死循环
    
    private init() {}
    
    func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkClipboard() {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        
        // 如果是我们自己写入的，跳过
        if ignoreNextChange {
            ignoreNextChange = false
            return
        }
        
        let pb = NSPasteboard.general
        
        // 图片优先
        if let image = pb.readObjects(forClasses: [NSImage.self])?.first as? NSImage {
            HistoryManager.shared.saveClipboardImage(image)
        } else if let text = pb.string(forType: .string), !text.isEmpty {
            HistoryManager.shared.saveClipboardText(text)
        }
    }
    
    func copyToClipboard(item: HistoryManager.HistoryItem) {
        ignoreNextChange = true  // 标记下一次变化是我们自己触发的
        
        let pb = NSPasteboard.general
        pb.clearContents()
        
        switch item.type {
        case .clipboardText, .screenshot:
            if let text = item.textContent {
                pb.setString(text, forType: .string)
            } else if let path = item.filePath, let image = NSImage(contentsOfFile: path) {
                pb.writeObjects([image])
            }
        case .clipboardImage:
            if let path = item.filePath, let image = NSImage(contentsOfFile: path) {
                pb.writeObjects([image])
            }
        }
        
        lastChangeCount = NSPasteboard.general.changeCount
    }
}
