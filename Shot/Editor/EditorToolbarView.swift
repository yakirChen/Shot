//
//  EditorToolbarView.swift
//  ScreenshotTool
//
//  Created by yakir on 2026/3/25.
//

import Cocoa

class EditorToolbarView: NSView {

  weak var delegate: EditorToolbarDelegate?

  var currentTool: AnnotationTool = .select {
    didSet { updateToolButtons() }
  }
  var currentColor: NSColor = .systemRed {
    didSet {
      colorWell?.color = currentColor
      colorHexLabel?.stringValue = currentColor.hexString
    }
  }
  var imageSize: NSSize = .zero {
    didSet { updateInfoLabels() }
  }
  var zoomLevel: CGFloat = 1.0 {
    didSet { updateInfoLabels() }
  }

  // 宽度阈值（降低阈值，延迟收拢）
  private let fullWidth: CGFloat = 750   // 原来是 900
  private let compactWidth: CGFloat = 350  // 原来是 450

  private enum LayoutMode: Equatable {
    case full, compact, collapsed
  }
  private var currentLayout: LayoutMode = .full

  // 容器
  private var mainContainer: NSStackView!  // ✅ 左侧 + 中间合并
  private var rightContainer: NSStackView!
  private var expandButton: NSButton!

  // 控件引用
  private var toolButtons: [AnnotationTool: NSButton] = [:]
  private var colorWell: PickerColorWell?
  private var colorHexLabel: NSTextField?
  private var sizeLabel: NSTextField?
  private var zoomLabel: NSTextField?

  private let allTools: [AnnotationTool] = [
    .select, .arrow, .text, .number,
    .rectangle, .ellipse, .line,
    .pen, .highlight, .blur, .measure,
  ]

  private let coreTools: [AnnotationTool] = [
    .select, .arrow, .rectangle, .text,
  ]

  override init(frame: NSRect) {
    super.init(frame: frame)
    setupUI()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupUI()
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    // Preserve the native traffic-light buttons even though the toolbar spans the titlebar.
    if point.x < 78 {
      return nil
    }
    return super.hitTest(point)
  }

  func updateLayout() {
    let width = bounds.width
    let newLayout: LayoutMode

    if width >= fullWidth {
      newLayout = .full
    } else if width >= compactWidth {
      newLayout = .compact
    } else {
      newLayout = .collapsed
    }

    if newLayout != currentLayout {
      currentLayout = newLayout
      rebuildLayout()
    }
  }

  override func layout() {
    super.layout()
    updateLayout()
  }

  // MARK: - UI

  private func setupUI() {
    // 左+中 容器
    mainContainer = NSStackView()
    mainContainer.orientation = .horizontal
    mainContainer.spacing = 2
    mainContainer.alignment = .centerY
    mainContainer.translatesAutoresizingMaskIntoConstraints = false
    addSubview(mainContainer)

    // 右侧容器
    rightContainer = NSStackView()
    rightContainer.orientation = .horizontal
    rightContainer.spacing = 6
    rightContainer.alignment = .centerY
    rightContainer.translatesAutoresizingMaskIntoConstraints = false
    addSubview(rightContainer)

    // 展开按钮
    expandButton = NSButton(frame: .zero)
    expandButton.bezelStyle = .recessed
    expandButton.isBordered = false
    expandButton.title = "»"
    expandButton.font = .systemFont(ofSize: 14, weight: .medium)
    expandButton.contentTintColor = .secondaryLabelColor
    expandButton.target = self
    expandButton.action = #selector(expandClicked)
    expandButton.toolTip = "展开工具栏"
    expandButton.translatesAutoresizingMaskIntoConstraints = false
    expandButton.isHidden = true
    addSubview(expandButton)

    NSLayoutConstraint.activate([
      // ✅ 垂直居中
      mainContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 78),
      mainContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
      mainContainer.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor, constant: -4),

      rightContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
      rightContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
      rightContainer.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor, constant: -4),

      // 防止重叠
      mainContainer.trailingAnchor.constraint(
        lessThanOrEqualTo: rightContainer.leadingAnchor, constant: -12),

      expandButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
      expandButton.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])

    rebuildLayout()
  }

  // MARK: - 重建

  private func rebuildLayout() {
    mainContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
    rightContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
    toolButtons.removeAll()
    colorWell = nil
    colorHexLabel = nil
    sizeLabel = nil
    zoomLabel = nil

    switch currentLayout {
    case .full:
      buildFullLayout()
      expandButton.isHidden = true
      mainContainer.isHidden = false
      rightContainer.isHidden = false

    case .compact:
      buildCompactLayout()
      expandButton.isHidden = true
      mainContainer.isHidden = false
      rightContainer.isHidden = false

    case .collapsed:
      expandButton.isHidden = false
      mainContainer.isHidden = true
      rightContainer.isHidden = true
    }

    updateToolButtons()
    updateInfoLabels()
  }

  // MARK: - 完整布局

  private func buildFullLayout() {
    // ✅ 操作按钮
    mainContainer.addArrangedSubview(
      createIconButton(
        icon: "doc.on.doc", action: #selector(copyClicked), tooltip: "复制 ⌘C"))
    mainContainer.addArrangedSubview(
      createIconButton(
        icon: "square.and.arrow.down", action: #selector(quickSaveClicked), tooltip: "快速保存 ⌘⇧S"))
    mainContainer.addArrangedSubview(
      createIconButton(
        icon: "folder", action: #selector(saveClicked), tooltip: "另存为... ⌘S"))
    mainContainer.addArrangedSubview(
      createIconButton(
        icon: "pin", action: #selector(pinClicked), tooltip: "钉到桌面"))

    mainContainer.addArrangedSubview(createDivider())

    mainContainer.addArrangedSubview(
      createIconButton(
        icon: "text.viewfinder", action: #selector(ocrClicked), tooltip: "OCR"))

    mainContainer.addArrangedSubview(createDivider())

    // ✅ 撤销/重做
    mainContainer.addArrangedSubview(
      createIconButton(
        icon: "arrow.uturn.backward", action: #selector(undoClicked), tooltip: "撤销 ⌘Z"))
    mainContainer.addArrangedSubview(
      createIconButton(
        icon: "arrow.uturn.forward", action: #selector(redoClicked), tooltip: "重做 ⌘⇧Z"))

    mainContainer.addArrangedSubview(createDivider())

    // ✅ 所有绘图工具
    for tool in allTools {
      let btn = createToolButton(tool: tool)
      toolButtons[tool] = btn
      mainContainer.addArrangedSubview(btn)
    }

    // 右侧信息
    buildRightInfo()
  }

  // MARK: - 紧凑布局

  private func buildCompactLayout() {
    // 操作按钮（精简）
    mainContainer.addArrangedSubview(
      createIconButton(
        icon: "doc.on.doc", action: #selector(copyClicked), tooltip: "复制"))
    mainContainer.addArrangedSubview(
      createIconButton(
        icon: "square.and.arrow.down", action: #selector(saveClicked), tooltip: "保存"))

    mainContainer.addArrangedSubview(createDivider())

    // ✅ 撤销/重做
    mainContainer.addArrangedSubview(
      createIconButton(
        icon: "arrow.uturn.backward", action: #selector(undoClicked), tooltip: "撤销"))
    mainContainer.addArrangedSubview(
      createIconButton(
        icon: "arrow.uturn.forward", action: #selector(redoClicked), tooltip: "重做"))

    mainContainer.addArrangedSubview(createDivider())

    // 核心工具
    for tool in coreTools {
      let btn = createToolButton(tool: tool)
      toolButtons[tool] = btn
      mainContainer.addArrangedSubview(btn)
    }

    // ...更多
    mainContainer.addArrangedSubview(
      createIconButton(
        icon: "ellipsis", action: #selector(moreToolsClicked), tooltip: "更多工具"))

    // 右侧信息
    buildRightInfo()
  }

  // MARK: - 右侧信息

  private func buildRightInfo() {
    // 颜色
    let cw = PickerColorWell(frame: NSRect(x: 0, y: 0, width: 18, height: 18))
    cw.color = currentColor
    cw.target = self
    cw.action = #selector(colorPickerClicked(_:))
    if #available(macOS 13.0, *) {
      cw.colorWellStyle = .minimal
    }
    cw.translatesAutoresizingMaskIntoConstraints = false
    cw.widthAnchor.constraint(equalToConstant: 18).isActive = true
    cw.heightAnchor.constraint(equalToConstant: 18).isActive = true
    colorWell = cw
    rightContainer.addArrangedSubview(cw)

    // HEX + 提示（垂直排列）
    let hexStack = NSStackView()
    hexStack.orientation = .vertical
    hexStack.spacing = 0
    hexStack.alignment = .leading

    let hexLabel = NSTextField(labelWithString: currentColor.hexString)
    hexLabel.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
    hexLabel.textColor = .labelColor
    hexLabel.toolTip = "点击复制颜色值"
    let hexClick = NSClickGestureRecognizer(target: self, action: #selector(copyColorHex))
    hexLabel.addGestureRecognizer(hexClick)
    colorHexLabel = hexLabel
    hexStack.addArrangedSubview(hexLabel)

    let tabHint = NSTextField(labelWithString: "Tab to copy")
    tabHint.font = .systemFont(ofSize: 8)
    tabHint.textColor = .tertiaryLabelColor
    hexStack.addArrangedSubview(tabHint)

    rightContainer.addArrangedSubview(hexStack)

    rightContainer.addArrangedSubview(createDivider())

    // 尺寸（垂直排列）
    let sizeStack = NSStackView()
    sizeStack.orientation = .vertical
    sizeStack.spacing = 0
    sizeStack.alignment = .leading

    let sl = NSTextField(labelWithString: "0×0pt")
    sl.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
    sl.textColor = .labelColor
    sizeLabel = sl
    sizeStack.addArrangedSubview(sl)

    let sizeHint = NSTextField(labelWithString: "Image size")
    sizeHint.font = .systemFont(ofSize: 8)
    sizeHint.textColor = .tertiaryLabelColor
    sizeStack.addArrangedSubview(sizeHint)

    rightContainer.addArrangedSubview(sizeStack)

    rightContainer.addArrangedSubview(createDivider())

    // 缩放按钮（垂直排列，保留 Zoom 提示）
    let zoomStack = NSStackView()
    zoomStack.orientation = .vertical
    zoomStack.spacing = 0
    zoomStack.alignment = .centerX

    let zl = NSButton(frame: .zero)
    zl.bezelStyle = .recessed
    zl.isBordered = false
    zl.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
    zl.title = "\(Int(zoomLevel * 100))%"
    zl.target = self
    zl.action = #selector(zoomButtonClicked(_:))
    zl.toolTip = "点击选择缩放比例"
    zl.tag = 9001
    zl.translatesAutoresizingMaskIntoConstraints = false
    zl.widthAnchor.constraint(equalToConstant: 48).isActive = true
    zoomStack.addArrangedSubview(zl)

    let zoomHint = NSTextField(labelWithString: "Zoom")
    zoomHint.font = .systemFont(ofSize: 8)
    zoomHint.textColor = .tertiaryLabelColor
    zoomStack.addArrangedSubview(zoomHint)

    rightContainer.addArrangedSubview(zoomStack)

    updateInfoLabels()
  }

  // MARK: - 控件创建

  private func createToolButton(tool: AnnotationTool) -> NSButton {
    let btn = NSButton(frame: .zero)
    btn.bezelStyle = .recessed
    btn.isBordered = false
    btn.image = NSImage(systemSymbolName: tool.icon, accessibilityDescription: tool.rawValue)?
      .withSymbolConfiguration(.init(pointSize: 12, weight: .medium))
    btn.contentTintColor = .secondaryLabelColor
    btn.toolTip = tool.rawValue
    btn.target = self
    btn.action = #selector(toolClicked(_:))
    btn.tag = AnnotationTool.allCases.firstIndex(of: tool) ?? 0
    btn.setButtonType(.toggle)
    btn.translatesAutoresizingMaskIntoConstraints = false
    btn.widthAnchor.constraint(equalToConstant: 26).isActive = true
    btn.heightAnchor.constraint(equalToConstant: 22).isActive = true
    btn.wantsLayer = true
    btn.layer?.cornerRadius = 4
    return btn
  }

  private func createIconButton(icon: String, action: Selector, tooltip: String) -> NSButton {
    let btn = NSButton(frame: .zero)
    btn.bezelStyle = .recessed
    btn.isBordered = false
    btn.image = NSImage(systemSymbolName: icon, accessibilityDescription: tooltip)?
      .withSymbolConfiguration(.init(pointSize: 11, weight: .regular))
    btn.contentTintColor = .secondaryLabelColor
    btn.toolTip = tooltip
    btn.target = self
    btn.action = action
    btn.translatesAutoresizingMaskIntoConstraints = false
    btn.widthAnchor.constraint(equalToConstant: 24).isActive = true
    btn.heightAnchor.constraint(equalToConstant: 22).isActive = true
    return btn
  }

  private func createDivider() -> NSView {
    let v = NSView()
    v.wantsLayer = true
    v.layer?.backgroundColor = NSColor.separatorColor.cgColor
    v.translatesAutoresizingMaskIntoConstraints = false
    v.widthAnchor.constraint(equalToConstant: 1).isActive = true
    v.heightAnchor.constraint(equalToConstant: 14).isActive = true
    return v
  }

  // MARK: - 更新

  private func updateToolButtons() {
    for (tool, button) in toolButtons {
      let isActive = (tool == currentTool)
      button.state = isActive ? .on : .off
      button.contentTintColor = isActive ? .controlAccentColor : .secondaryLabelColor
      button.layer?.backgroundColor =
        isActive
        ? NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
        : NSColor.clear.cgColor
    }
  }

  private func updateInfoLabels() {
    sizeLabel?.stringValue = "\(Int(imageSize.width))×\(Int(imageSize.height))pt"
    zoomLabel?.stringValue = "\(Int(zoomLevel * 100))%"
    (viewWithTag(9001) as? NSButton)?.title = "\(Int(zoomLevel * 100))%"
  }

  // MARK: - Actions

  @objc private func toolClicked(_ sender: NSButton) {
    let allCases = AnnotationTool.allCases
    guard sender.tag < allCases.count else { return }
    currentTool = allCases[sender.tag]
    delegate?.toolDidChange(currentTool)
  }

  @objc private func colorPickerClicked(_ sender: PickerColorWell) {
    copyCurrentColorHex()
  }

  func applySampledImageColor(_ color: NSColor) {
    currentColor = color
  }

  @objc private func copyColorHex() {
    copyCurrentColorHex()
  }

  func copyCurrentColorHex() {
    let hex = currentColor.hexString
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(hex, forType: .string)

    let original = colorHexLabel?.textColor
    colorHexLabel?.textColor = .systemGreen
    colorHexLabel?.stringValue = "Copied!"
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
      self.colorHexLabel?.textColor = original
      self.colorHexLabel?.stringValue = hex
    }
  }

  @objc private func zoomButtonClicked(_ sender: NSButton) {
    let menu = NSMenu()
    for level in [25, 50, 75, 100, 150, 200] {
      let item = NSMenuItem(title: "\(level)%", action: #selector(zoomMenuSelected(_:)), keyEquivalent: "")
      item.tag = level
      item.target = self
      if Int(zoomLevel * 100) == level { item.state = .on }
      menu.addItem(item)
    }
    menu.addItem(NSMenuItem.separator())

    // 行内输入框 item
    let inputContainer = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 28))

    let field = NSTextField(frame: NSRect(x: 12, y: 3, width: 60, height: 22))
    field.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    field.stringValue = "\(Int(zoomLevel * 100))"
    field.alignment = .right
    field.bezelStyle = .roundedBezel
    field.tag = 9002
    field.delegate = self
    inputContainer.addSubview(field)

    let pct = NSTextField(labelWithString: "%")
    pct.font = .systemFont(ofSize: 12)
    pct.frame = NSRect(x: 76, y: 5, width: 20, height: 18)
    inputContainer.addSubview(pct)

    let inputItem = NSMenuItem()
    inputItem.view = inputContainer
    menu.addItem(inputItem)

    menu.addItem(NSMenuItem.separator())
    let fitItem = NSMenuItem(title: "适应窗口", action: #selector(zoomToFit), keyEquivalent: "")
    fitItem.target = self
    menu.addItem(fitItem)

    menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
  }

  @objc private func zoomMenuSelected(_ sender: NSMenuItem) {
    applyZoom(CGFloat(sender.tag) / 100.0)
  }

  @objc private func zoomToFit() {
    delegate?.zoomDidChange(0)
  }

  private func applyZoom(_ level: CGFloat) {
    zoomLevel = level
    delegate?.zoomDidChange(level)
  }

  @objc private func expandClicked() {
    if let window = self.window {
      var frame = window.frame
      frame.size.width = max(frame.size.width, compactWidth + 50)
      window.setFrame(frame, display: true, animate: true)
    }
  }

  @objc private func moreToolsClicked(_ sender: NSButton) {
    let menu = NSMenu()

    let extraTools = allTools.filter { !coreTools.contains($0) }
    for tool in extraTools {
      let item = NSMenuItem(
        title: tool.rawValue, action: #selector(menuToolSelected(_:)), keyEquivalent: "")
      item.target = self
      item.tag = AnnotationTool.allCases.firstIndex(of: tool) ?? 0
      item.image = NSImage(systemSymbolName: tool.icon, accessibilityDescription: nil)
      if tool == currentTool { item.state = .on }
      menu.addItem(item)
    }

    menu.addItem(NSMenuItem.separator())

    let lineWidthItem = NSMenuItem(title: "线宽", action: nil, keyEquivalent: "")
    let lineWidthMenu = NSMenu()
    for w in [1, 2, 3, 4, 6, 8, 10] {
      let item = NSMenuItem(
        title: "\(w) px", action: #selector(lineWidthSelected(_:)), keyEquivalent: "")
      item.target = self
      item.tag = w
      lineWidthMenu.addItem(item)
    }
    lineWidthItem.submenu = lineWidthMenu
    menu.addItem(lineWidthItem)

    menu.addItem(NSMenuItem.separator())

    let ocrItem = NSMenuItem(
      title: "文字识别 OCR", action: #selector(ocrClicked), keyEquivalent: "")
    ocrItem.target = self
    ocrItem.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: nil)
    menu.addItem(ocrItem)

    let pinItem = NSMenuItem(title: "钉到桌面", action: #selector(pinClicked), keyEquivalent: "")
    pinItem.target = self
    pinItem.image = NSImage(systemSymbolName: "pin", accessibilityDescription: nil)
    menu.addItem(pinItem)

    menu.addItem(NSMenuItem.separator())

    let undoItem = NSMenuItem(title: "撤销", action: #selector(undoClicked), keyEquivalent: "z")
    undoItem.target = self
    menu.addItem(undoItem)

    let redoItem = NSMenuItem(title: "重做", action: #selector(redoClicked), keyEquivalent: "Z")
    redoItem.target = self
    menu.addItem(redoItem)

    menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
  }

  @objc private func menuToolSelected(_ sender: NSMenuItem) {
    let allCases = AnnotationTool.allCases
    guard sender.tag < allCases.count else { return }
    currentTool = allCases[sender.tag]
    delegate?.toolDidChange(currentTool)
  }

  @objc private func lineWidthSelected(_ sender: NSMenuItem) {
    delegate?.lineWidthDidChange(CGFloat(sender.tag))
  }

  @objc private func undoClicked() { delegate?.undoAction() }
  @objc private func redoClicked() { delegate?.redoAction() }
  @objc private func saveClicked() { delegate?.saveAction() }
  @objc private func quickSaveClicked() { delegate?.quickSaveAction() }
  @objc private func copyClicked() { delegate?.copyAction() }
  @objc private func ocrClicked() { delegate?.ocrAction() }
  @objc private func pinClicked() { delegate?.pinAction() }

  // MARK: - 窗口拖动支持

  private var isDraggingWindow = false

  override func mouseDown(with event: NSEvent) {
    // 检查是否点击在按钮/控件上
    let point = convert(event.locationInWindow, from: nil)
    let hitView = hitTest(point)

    // 如果点击在子控件（按钮等）上，让子控件处理
    if hitView != nil && hitView !== self {
      super.mouseDown(with: event)
      return
    }

    // 点击在空白区域，开始拖动窗口
    isDraggingWindow = true
    window?.performDrag(with: event)
  }

  override func mouseDragged(with event: NSEvent) {
    if isDraggingWindow {
      window?.performDrag(with: event)
    } else {
      super.mouseDragged(with: event)
    }
  }

  override func mouseUp(with event: NSEvent) {
    isDraggingWindow = false
    super.mouseUp(with: event)
  }
}

extension EditorToolbarView: NSTextFieldDelegate {
  func controlTextDidChange(_ obj: Notification) {
    guard let field = obj.object as? NSTextField, field.tag == 9002 else { return }
    let raw = field.stringValue.replacingOccurrences(of: "%", with: "")
    if let value = Int(raw), value >= 10, value <= 500 {
      applyZoom(CGFloat(value) / 100.0)
    }
  }

  func controlTextDidEndEditing(_ obj: Notification) {
    guard let field = obj.object as? NSTextField, field.tag == 9002 else { return }
    let raw = field.stringValue.replacingOccurrences(of: "%", with: "")
    if let value = Int(raw), value >= 10, value <= 500 {
      applyZoom(CGFloat(value) / 100.0)
    }
  }
}

private final class PickerColorWell: NSColorWell {
  override var acceptsFirstResponder: Bool { true }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }

  override func mouseDown(with event: NSEvent) {
    sendAction(action, to: target)
  }

  override func activate(_ exclusive: Bool) {
    // Keep the toolbar color picker in Shottr-style eyedropper mode instead of Color Panel mode.
  }
}
