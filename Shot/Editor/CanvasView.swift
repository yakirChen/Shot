//
//  CanvasView.swift
//  ScreenshotTool
//
//  Created by yakir on 2026/3/25.
//

import Cocoa

/// 画布视图：承载 EditorView，支持拖拽平移和居中显示
class CanvasView: NSView {

  var editorView: EditorView?

  private var isPanning = false
  private var panStartPoint: NSPoint = .zero
  private var panOffset: CGPoint = .zero
  private var forwardingTarget: NSView?
  
  // 缩放相关
  private var zoomLevel: CGFloat = 1.0
  private let minZoom: CGFloat = 0.1
  private let maxZoom: CGFloat = 5.0
  private let fitPadding: CGFloat = 24

  var topContentInset: CGFloat = 0 {
    didSet {
      if isFitMode { zoomToFit() }
    }
  }

  override init(frame: NSRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  private func setup() {
    wantsLayer = true
    // 禁用隐式动画确保窗口移动时无延迟
    layer?.actions = ["": NSNull()]
    // 启用异步绘制提升性能
    layer?.drawsAsynchronously = true
  }

  override func updateLayer() {
    layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
  }

  override var acceptsFirstResponder: Bool { true }

  private var isFitMode = false

  override func layout() {
    super.layout()
    if isFitMode { zoomToFit() } else { applyPanOffset() }
  }

  // MARK: - 居中

  func centerEditor() {
    panOffset = .zero
    isFitMode = false
    applyPanOffset()
  }

  private func applyPanOffset() {
    guard let editor = editorView else { return }
    let baseSize = editor.bounds.size == .zero ? editor.frame.size : editor.bounds.size
    let scaledSize = CGSize(width: baseSize.width * zoomLevel, height: baseSize.height * zoomLevel)
    let origin = CGPoint(
      x: (bounds.width - scaledSize.width) / 2 + panOffset.x,
      y: (bounds.height - scaledSize.height) / 2 + panOffset.y
    )

    editor.frame = CGRect(origin: origin, size: scaledSize)
    editor.bounds = CGRect(origin: .zero, size: baseSize)

    let zoom = zoomLevel
    DispatchQueue.main.async { [weak self] in
      (self?.window?.windowController as? EditorWindowController)?.updateToolbarZoomLevel(zoom)
    }
  }

  /// 设置缩放级别（由工具栏调用）
  func setZoomLevel(_ level: CGFloat) {
    zoomLevel = max(minZoom, min(maxZoom, level))
    isFitMode = false
    applyPanOffset()
  }

  func zoomToFit() {
    guard let editor = editorView else { return }

    let baseSize = editor.bounds.size == .zero ? editor.frame.size : editor.bounds.size
    let availableWidth = max(1, bounds.width - fitPadding * 2)
    let availableHeight = max(1, bounds.height - topContentInset - fitPadding * 2)
    let scaleX = availableWidth / baseSize.width
    let scaleY = availableHeight / baseSize.height
    zoomLevel = max(minZoom, min(maxZoom, min(scaleX, scaleY)))
    panOffset = CGPoint(x: 0, y: -topContentInset / 2)
    isFitMode = true
    applyPanOffset()
  }
  
  /// 以指定点为中心缩放
  private func zoomAtPoint(point: NSPoint, delta: CGFloat) {
    guard let editor = editorView else { return }
    
    // 计算新的缩放级别
    let zoomFactor: CGFloat = 0.1
    let newZoom = max(minZoom, min(maxZoom, zoomLevel + (delta > 0 ? zoomFactor : -zoomFactor)))
    
    // 如果缩放没变，不做任何事
    guard newZoom != zoomLevel else { return }
    
    let editorPoint = editor.convert(point, from: self)
    let baseSize = editor.bounds.size
    guard baseSize.width > 0, baseSize.height > 0 else { return }
    
    // 计算新的偏移，使该点保持在屏幕上的同一位置
    let newScaledSize = CGSize(width: baseSize.width * newZoom, height: baseSize.height * newZoom)
    let localRatio = CGPoint(x: editorPoint.x / baseSize.width, y: editorPoint.y / baseSize.height)
    let desiredOrigin = CGPoint(
      x: point.x - localRatio.x * newScaledSize.width,
      y: point.y - localRatio.y * newScaledSize.height
    )
    panOffset.x = desiredOrigin.x - (bounds.width - newScaledSize.width) / 2
    panOffset.y = desiredOrigin.y - (bounds.height - newScaledSize.height) / 2
    
    zoomLevel = newZoom
    isFitMode = false
    applyPanOffset()
  }

  // MARK: - 平移

  func beginPanning(with event: NSEvent) {
    startPanning(at: convert(event.locationInWindow, from: nil))
  }

  func continuePanning(with event: NSEvent) {
    panTo(event: event)
  }

  func endPanning() {
    if isPanning { stopPanning() }
  }

  private func startPanning(at point: NSPoint) {
    isPanning = true
    panStartPoint = point
    NSCursor.closedHand.push()
  }

  private func panTo(event: NSEvent) {
    guard isPanning else { return }
    let point = convert(event.locationInWindow, from: nil)
    panOffset.x += point.x - panStartPoint.x
    panOffset.y += point.y - panStartPoint.y
    panStartPoint = point
    isFitMode = false
    applyPanOffset()
  }

  private func stopPanning() {
    isPanning = false
    NSCursor.pop()
  }

  // MARK: - 鼠标事件

  override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    guard let editor = editorView else { return }
    forwardingTarget = nil

    // 命中了 overlay 内的控件，记录并转发
    if let contentView = window?.contentView {
      let contentPoint = contentView.convert(event.locationInWindow, from: nil)
      if let hit = contentView.hitTest(contentPoint),
         hit !== self, !hit.isDescendant(of: editor) {
        forwardingTarget = hit
        hit.mouseDown(with: event)
        return
      }
    }

    if editor.frame.contains(point) {
      if editor.currentTool == .select && !editor.hitTestAnnotation(at: convert(point, to: editor)) {
        editor.deselectAll()
        startPanning(at: point)
      } else {
        editor.mouseDown(with: event)
      }
    } else {
      editor.deselectAll()
      editor.currentTool = .select
      if let wc = window?.windowController as? EditorWindowController {
        wc.syncToolbarTool(.select)
      }
      startPanning(at: point)
    }
  }

  override func mouseDragged(with event: NSEvent) {
    if let target = forwardingTarget { target.mouseDragged(with: event); return }
    if isPanning { panTo(event: event) } else { editorView?.mouseDragged(with: event) }
  }

  override func mouseUp(with event: NSEvent) {
    if let target = forwardingTarget { target.mouseUp(with: event); forwardingTarget = nil; return }
    if isPanning { stopPanning() } else { editorView?.mouseUp(with: event) }
  }

  override func rightMouseDown(with event: NSEvent) {
    startPanning(at: convert(event.locationInWindow, from: nil))
  }

  override func rightMouseDragged(with event: NSEvent) {
    if isPanning { panTo(event: event) }
  }

  override func rightMouseUp(with event: NSEvent) {
    if isPanning { stopPanning() }
  }

  override func scrollWheel(with event: NSEvent) {
    // 滚轮缩放（以鼠标位置为中心）
    let point = convert(event.locationInWindow, from: nil)
    let delta = event.scrollingDeltaY
    zoomAtPoint(point: point, delta: delta)
  }

  // MARK: - 键盘传递

  override func keyDown(with event: NSEvent) {
    editorView?.keyDown(with: event)
  }

  override func keyUp(with event: NSEvent) {
    // 空实现
  }
}
