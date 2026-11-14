import SwiftUI
import AppKit
import Combine

/// Widgets use the same theme library and readability engine as zones. Text colours come from
/// the palette, so every theme (and clear mode) stays legible. Sticky notes keep their own
/// note colour for the writing area.
public struct WidgetContainerView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var wallpaper = WallpaperSampler.shared
    let widgetID: UUID
    @State private var isHovered = false

    private var dragArea: some View {
        WindowDragArea(onDragEnded: { frame in
            WindowManager.shared.commitWidgetFrame(id: widgetID, frame: frame)
        })
    }

    public var body: some View {
        if let widget = appState.widgets.first(where: { $0.id == widgetID }) {
            let palette = ZonePalette.forWidget(widget)
            VStack(spacing: 0) {
                if widget.showHeader {
                    header(widget, palette: palette)
                }

                Group {
                    switch widget.type {
                    case .clock: ClockWidgetView(widget: widget)
                    case .calendar: CalendarWidgetView(widget: widget)
                    case .quickNote: QuickNoteWidgetView(widgetID: widget.id, initialText: widget.noteContent, colorHex: widget.noteColorHex)
                    case .systemGlance: SystemMonitorWidgetView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Display-only widgets can be dragged from anywhere; the note keeps its text editor.
                .allowsHitTesting(widget.type == .quickNote)
            }
            .overlay(alignment: .topTrailing) {
                if !widget.showHeader {
                    floatingControls(widget, palette: palette)
                        .opacity(isHovered ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.15), value: isHovered)
                }
            }
            .onHover { isHovered = $0 }
            .contextMenu {
                styleMenu(widget)
            }
            .background(
                ZStack {
                    ZoneBackgroundView(palette: palette).allowsHitTesting(false)
                    if widget.type != .quickNote { dragArea }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: CGFloat(palette.cornerRadius), style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CGFloat(palette.cornerRadius), style: .continuous)
                    .strokeBorder(palette.showBorder ? palette.border : Color.clear, lineWidth: CGFloat(palette.borderWidth))
                    .allowsHitTesting(false)
            )
            .modifier(ClearModeHalo(active: palette.isClear && widget.textColorHex == nil, lightGlow: palette.clearOnLight))
            .environment(\.zonePalette, palette)
            .environment(\.colorScheme, palette.colorScheme)
        }
    }

    private func header(_ widget: DesktopWidget, palette: ZonePalette) -> some View {
        HStack(spacing: 6) {
            Image(systemName: widget.type.iconName)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(palette.accent)
                .allowsHitTesting(false)
            Text(widget.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(palette.title)
                .lineLimit(1)
                .allowsHitTesting(false)
            Spacer()
            Menu {
                styleMenu(widget)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(palette.primary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .frame(width: 18, height: 18)
            .background(Circle().fill(palette.controlFill))
            .help("Theme, transparency and more")

            Button {
                appState.widgets.removeAll { $0.id == widgetID }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(palette.primary)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(palette.controlFill))
            }
            .buttonStyle(.plain)
            .help("Remove widget")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        // The drag area must be ABOVE the fill; a Color is hit-testable and swallows clicks.
        .background(
            ZStack {
                (palette.isClear ? Color.clear : palette.controlFill.opacity(0.6)).allowsHitTesting(false)
                dragArea
            }
        )
    }

    private func floatingControls(_ widget: DesktopWidget, palette: ZonePalette) -> some View {
        HStack(spacing: 6) {
            Menu {
                styleMenu(widget)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(palette.primary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .frame(width: 18, height: 18)
            .background(Circle().fill(palette.controlFill))
            .help("Theme, transparency and more")

            Button {
                appState.widgets.removeAll { $0.id == widgetID }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(palette.primary)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(palette.controlFill))
            }
            .buttonStyle(.plain)
            .help("Remove widget")
        }
        .padding(8)
    }

    @ViewBuilder
    private func styleMenu(_ widget: DesktopWidget) -> some View {
        Menu("Theme") {
            ForEach(ThemePresets.categoryOrder, id: \.self) { category in
                let themes = ThemePresets.allThemes.filter { $0.category == category }
                if !themes.isEmpty {
                    Section(category) {
                        ForEach(themes) { theme in
                            Button {
                                if theme.isPro && !appState.isPro { WindowManager.shared.showPaywall(); return }
                                update { $0.themeID = theme.id }
                            } label: {
                                if widget.themeID == theme.id {
                                    Label(theme.name, systemImage: "checkmark")
                                } else {
                                    Text(theme.name)
                                }
                            }
                        }
                    }
                }
            }
        }
        Menu("Transparency") {
            ForEach([(nil, "Theme Default"), (1.0, "Solid (100%)"), (0.75, "75%"), (0.5, "50%"), (0.35, "35%"), (0.15, "15%"), (0.0, "Clear (0%)")] as [(Double?, String)], id: \.1) { value, label in
                Button {
                    update { $0.backgroundOpacity = value }
                } label: {
                    if widget.backgroundOpacity == value {
                        Label(label, systemImage: "checkmark")
                    } else {
                        Text(label)
                    }
                }
            }
        }
        Menu("Font Color") {
            Button {
                update { $0.textColorHex = nil }
            } label: {
                if widget.textColorHex == nil {
                    Label("Theme Default", systemImage: "checkmark")
                } else {
                    Text("Theme Default")
                }
            }
            Divider()
            let presets: [(name: String, hex: String)] = [
                ("Red", "#FF3B30"),
                ("Orange", "#FF9500"),
                ("Yellow", "#FFCC00"),
                ("Green", "#34C759"),
                ("Mint", "#00C7BE"),
                ("Teal", "#30B0C7"),
                ("Blue", "#007AFF"),
                ("Indigo", "#5856D6"),
                ("Purple", "#AF52DE"),
                ("Pink", "#FF2D55"),
                ("White", "#FFFFFF"),
                ("Black", "#000000")
            ]
            ForEach(presets, id: \.hex) { preset in
                Button {
                    update { $0.textColorHex = preset.hex }
                } label: {
                    if widget.textColorHex?.uppercased() == preset.hex.uppercased() {
                        Label(preset.name, systemImage: "checkmark")
                    } else {
                        Text(preset.name)
                    }
                }
            }
            Divider()
            Button("Custom Color…") {
                ColorPanelDelegate.shared.show(for: widget.id, in: appState)
            }
        }
        Button(widget.showBorder ? "Hide Border" : "Show Border") {
            update { $0.showBorder.toggle() }
        }
        Button(widget.showHeader ? "Hide Title Bar" : "Show Title Bar") {
            update { $0.showHeader.toggle() }
        }
        Divider()
        Button("Reset Style") {
            update {
                $0.themeID = "dark_frost"
                $0.backgroundOpacity = nil
                $0.textColorHex = nil
                $0.showBorder = true
                $0.showHeader = ($0.type != .clock)
            }
        }
        Button("Remove Widget") {
            appState.widgets.removeAll { $0.id == widgetID }
        }
    }

    private func update(_ change: (inout DesktopWidget) -> Void) {
        guard let idx = appState.widgets.firstIndex(where: { $0.id == widgetID }) else { return }
        var copy = appState.widgets[idx]
        change(&copy)
        if copy != appState.widgets[idx] { appState.widgets[idx] = copy }
    }
}

// MARK: - Color Panel Delegate

public final class ColorPanelDelegate: NSObject {
    public static let shared = ColorPanelDelegate()
    public var currentWidgetID: UUID?
    public weak var appState: AppState?

    public func show(for widgetID: UUID, in state: AppState) {
        self.currentWidgetID = widgetID
        self.appState = state
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSColorPanel.shared
        if let widget = state.widgets.first(where: { $0.id == widgetID }),
           let hex = widget.textColorHex {
            panel.color = NSColor(Color(hex: hex))
        }
        panel.setTarget(self)
        panel.setAction(#selector(colorDidChange(_:)))
        panel.orderFront(nil)
    }

    @objc public func colorDidChange(_ sender: NSColorPanel) {
        guard let id = currentWidgetID, let state = appState else { return }
        let rgb = sender.color.usingColorSpace(.sRGB) ?? sender.color
        let hex = RGBAColor(r: Double(rgb.redComponent), g: Double(rgb.greenComponent), b: Double(rgb.blueComponent)).hexString
        if let idx = state.widgets.firstIndex(where: { $0.id == id }) {
            state.widgets[idx].textColorHex = hex
        }
    }
}

// MARK: - Clock

public struct ClockWidgetView: View {
    @Environment(\.zonePalette) private var palette
    public var widget: DesktopWidget?
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, tolerance: 0.2, on: .main, in: .common).autoconnect()

    public init(widget: DesktopWidget? = nil) {
        self.widget = widget
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .medium
        f.dateStyle = .none
        return f
    }()
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEEMMMMd")
        return f
    }()

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // Proportional font sizes based on widget dimensions
            let timeSize = max(20, min(h * 0.38, w * 0.24))
            let dateSize = max(11, min(h * 0.16, w * 0.09))
            let spacing = max(2, min(h * 0.05, 12))

            let clockColor: Color = {
                if let hex = widget?.textColorHex {
                    return Color(hex: hex)
                }
                return palette.title
            }()

            VStack(spacing: spacing) {
                Text(Self.timeFormatter.string(from: now))
                    .font(.system(size: timeSize, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundColor(clockColor)
                    .opacity(1.0)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Text(Self.dateFormatter.string(from: now))
                    .font(.system(size: dateSize, weight: .medium))
                    .foregroundColor(clockColor)
                    .opacity(1.0)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
            }
            .frame(width: w, height: h, alignment: .center)
        }
        .padding(8)
        .onReceive(timer) { now = $0 }
    }
}

// MARK: - Calendar

public struct CalendarWidgetView: View {
    @Environment(\.zonePalette) private var palette
    public var widget: DesktopWidget?
    @State private var today = Date()
    private let timer = Timer.publish(every: 600, tolerance: 60, on: .main, in: .common).autoconnect()

    public init(widget: DesktopWidget? = nil) {
        self.widget = widget
    }

    private var calendar: Calendar { Calendar.autoupdatingCurrent }

    private var dayCells: [Int?] {
        guard let range = calendar.range(of: .day, in: .month, for: today),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) else { return [] }
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var days = Array(repeating: nil as Int?, count: leading) + range.map { Optional($0) }
        let remainder = days.count % 7
        if remainder != 0 {
            days += Array(repeating: nil as Int?, count: 7 - remainder)
        }
        return days
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // Calculate responsive metrics
            let hPadding = max(8, min(w * 0.04, 28))
            let vPadding = max(6, min(h * 0.03, 24))
            let usableW = max(50, w - 2 * hPadding)
            let usableH = max(50, h - 2 * vPadding)

            // Number of rows: 1 weekday row + week rows (typically 5 or 6)
            let weekRowCount = CGFloat(dayCells.count / 7)
            let totalRowCount = max(6, 1 + weekRowCount)

            let titleH = max(16, min(usableH * 0.13, 50))
            let titleSpacing = max(4, min(usableH * 0.03, 16))

            let gridH = max(30, usableH - titleH - titleSpacing)
            let cellW = usableW / 7.0
            let rowH = gridH / totalRowCount
            let cellSize = min(cellW, rowH)

            let titleFontSize = max(11, min(titleH * 0.65, 34))
            let weekdayFontSize = max(8, min(cellSize * 0.35, 22))
            let dateFontSize = max(9, min(cellSize * 0.46, 30))
            let todayBadgeSize = max(16, min(cellSize * 0.85, 60))

            let todayNumber = calendar.component(.day, from: today)
            let badgeText = palette.isClear ? Color.black : palette.effectiveBackground.color
            let textColor = widget?.textColorHex.flatMap { Color(hex: $0) }

            VStack(spacing: titleSpacing) {
                // Month & Year Title
                Text(today.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: titleFontSize, weight: .bold))
                    .foregroundColor(textColor ?? palette.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(height: titleH)

                // Grid: Weekday Header + Date Rows
                VStack(spacing: max(1, min(gridH * 0.015, 8))) {
                    // Weekday Header Row
                    HStack(spacing: 0) {
                        ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                            Text(symbol)
                                .font(.system(size: weekdayFontSize, weight: .bold))
                                .foregroundColor(textColor?.opacity(0.85) ?? palette.secondary)
                                .frame(width: cellW, height: rowH)
                        }
                    }

                    // Date Rows
                    let weeks = stride(from: 0, to: dayCells.count, by: 7).map {
                        Array(dayCells[$0..<min($0 + 7, dayCells.count)])
                    }

                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        HStack(spacing: 0) {
                            ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                                ZStack {
                                    if let day = day {
                                        if day == todayNumber {
                                            Circle()
                                                .fill(palette.primary)
                                                .frame(width: todayBadgeSize, height: todayBadgeSize)
                                        }
                                        Text("\(day)")
                                            .font(.system(size: dateFontSize, weight: day == todayNumber ? .bold : .regular).monospacedDigit())
                                            .foregroundColor(day == todayNumber ? badgeText : (textColor ?? palette.primary))
                                    } else {
                                        Text("")
                                    }
                                }
                                .frame(width: cellW, height: rowH)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, hPadding)
            .padding(.vertical, vPadding)
            .frame(width: w, height: h, alignment: .center)
        }
        .onReceive(timer) { today = $0 }
    }
}

// MARK: - Sticky note

public struct QuickNoteWidgetView: View {
    @EnvironmentObject var appState: AppState
    let widgetID: UUID
    @State private var text: String
    let colorHex: String

    public init(widgetID: UUID, initialText: String, colorHex: String) {
        self.widgetID = widgetID
        self._text = State(initialValue: initialText)
        self.colorHex = colorHex
    }

    public var body: some View {
        let background = RGBAColor(hex: colorHex)
        let textColor: RGBAColor = RGBAColor.contrastRatio(.black, background) >= RGBAColor.contrastRatio(.white, background) ? RGBAColor(hex: "#1A1A1A") : .white
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Type a note…")
                    .font(.system(size: 12))
                    .foregroundColor(textColor.color.opacity(0.6))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .foregroundColor(textColor.color)
                .padding(8)
                .onChange(of: text) { newText in
                    if let idx = appState.widgets.firstIndex(where: { $0.id == widgetID }), appState.widgets[idx].noteContent != newText {
                        appState.widgets[idx].noteContent = newText
                    }
                }
        }
        .environment(\.colorScheme, textColor == .white ? .dark : .light)
        .background(background.color)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .clear, radius: 0) // the note body is never haloed
        .padding(8)
    }
}

// MARK: - System monitor (real values)

public final class SystemMonitorModel: ObservableObject {
    @Published var cpu: Double = 0
    @Published var memory: Double = 0
    private let stats = SystemStats()
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        _ = stats.cpuUsagePercent()
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.sample() }
        timer?.tolerance = 0.5
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        cpu = stats.cpuUsagePercent()
        memory = stats.memoryUsagePercent()
    }

    deinit { timer?.invalidate() }
}

public struct SystemMonitorWidgetView: View {
    @Environment(\.zonePalette) private var palette
    @StateObject private var model = SystemMonitorModel()

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            meter("CPU", value: model.cpu)
            meter("Memory", value: model.memory)
        }
        .padding(14)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private func meter(_ title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(palette.secondary)
                Spacer()
                Text("\(Int(value.rounded()))%")
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                    .foregroundColor(palette.primary)
            }
            ProgressView(value: min(max(value, 0), 100), total: 100)
                .tint(palette.accent)
        }
    }
}
