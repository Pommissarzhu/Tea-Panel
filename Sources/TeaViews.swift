import SwiftUI
import AppKit

enum TeaStyle {
    static let background = Color(red: 0.96, green: 0.97, blue: 0.93)
    static let forest = Color(red: 0.12, green: 0.27, blue: 0.22)
    static let green = Color(red: 0.24, green: 0.43, blue: 0.32)
    static let muted = Color(red: 0.43, green: 0.49, blue: 0.43)
    static let pale = Color(red: 0.88, green: 0.93, blue: 0.81)
    static let border = Color(red: 0.85, green: 0.88, blue: 0.81)

    static func statusImage(for symbol: String) -> NSImage? {
        guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) else { return nil }
        // Equal canvas sizes keep template changes from resizing the status button.
        let canvas = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { bounds in
            let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
            let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: NSRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                                 width: size.width, height: size.height))
            return true
        }
        canvas.isTemplate = true
        return canvas
    }
}

enum TeaTypography {
    static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static let heroValue = font(size: 58, weight: .light).monospacedDigit()
}

struct TeaHeroEyebrow: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .trailing) {
                Image(systemName: symbol)
                    .resizable().scaledToFit()
                    .frame(width: 14, height: 14, alignment: .trailing)
                    .id(symbol).transition(.opacity)
            }
            .frame(width: 16, height: 16, alignment: .trailing)
            .accessibilityHidden(true)
            Text(title)
                .modifier(TeaValueChange(value: title))
                .lineLimit(1)
        }
        .font(TeaTypography.font(size: 11, weight: .medium))
        .foregroundStyle(TeaStyle.muted)
    }
}

private struct TeaNumberField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool
    let label: String
    let suffix: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(TeaTypography.font(size: 10)).foregroundStyle(TeaStyle.muted)
            HStack(spacing: 4) {
                TextField(label, value: $value, format: .number.precision(.fractionLength(0...1)))
                    .textFieldStyle(.plain).font(TeaTypography.font(size: 19, weight: .medium))
                    .monospacedDigit()
                    .accessibilityLabel(label)
                    .focused($isFocused)
                    .onSubmit {
                        if let window = NSApp.keyWindow { window.makeFirstResponder(window.contentView) }
                    }
                Text(suffix).font(TeaTypography.font(size: 12)).foregroundStyle(TeaStyle.muted)
            }
            .frame(height: 26)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(TeaStyle.green.opacity(isFocused ? 0.45 : 0), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .animation(TeaMotion.animation(TeaMotion.feedback, reduceMotion: reduceMotion), value: isFocused)
    }
}

struct TeaMenuView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @TeaViewState private var configurationFeedbackID = 0
    @ObservedObject var store: TeaStore
    let onPrimary: () -> Void
    let onSkipCooling: () -> Void
    let onEnd: () -> Void
    let onPreview: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    teaPicker
                    modePicker
                    if let message = store.configurationMessage {
                        Text(message).font(TeaTypography.font(size: 11)).foregroundStyle(TeaStyle.green)
                            .id(configurationFeedbackID)
                            .transition(TeaMotion.transition(reduceMotion: reduceMotion))
                    }
                    if store.showsSettings {
                        VStack(spacing: 14) {
                            cupSettings
                            settings
                        }
                        .transition(TeaMotion.transition(reduceMotion: reduceMotion))
                    } else {
                        VStack(spacing: 14) {
                            hero
                            if store.isActive {
                                batchInfo.transition(.opacity)
                            } else {
                                brewFields.transition(.opacity)
                            }
                            recipeSummary
                            actions
                        }
                        .animation(TeaMotion.animation(TeaMotion.content, reduceMotion: reduceMotion), value: store.phase)
                        .transition(TeaMotion.transition(reduceMotion: reduceMotion))
                    }
                }
                .padding(22)
                .animation(TeaMotion.animation(TeaMotion.content, reduceMotion: reduceMotion), value: store.showsSettings)
                .animation(TeaMotion.animation(TeaMotion.content, reduceMotion: reduceMotion), value: store.configurationMessage)
                .animation(TeaMotion.animation(TeaMotion.selection, reduceMotion: reduceMotion), value: configurationFeedbackID)
            }
            footer
        }
        .frame(width: 384, height: 668)
        .background(TeaStyle.background)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22).strokeBorder(TeaStyle.border, lineWidth: 1)
        }
        .foregroundStyle(TeaStyle.forest)
        .font(TeaTypography.font(size: 13))
        .environment(\.colorScheme, .light)
        .tint(TeaStyle.green)
    }

    private var header: some View {
        HStack(spacing: 11) {
            Image(systemName: "cup.and.saucer.fill")
                .font(TeaTypography.font(size: 21, weight: .medium))
                .frame(width: 43, height: 43)
                .background(TeaStyle.pale, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text("茶伴").font(TeaTypography.font(size: 21, weight: .semibold))
                Text("TEA PANEL").font(TeaTypography.font(size: 9, weight: .semibold)).tracking(2.5).foregroundStyle(TeaStyle.muted)
            }
            Spacer()
            Button {
                act { store.showsSettings.toggle() }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(TeaTypography.font(size: 16)).frame(width: 32, height: 32)
                    .background(store.showsSettings ? TeaStyle.pale : Color.clear, in: Circle())
            }
            .buttonStyle(TeaButtonStyle())
            .accessibilityLabel("调整泡茶参数")
            .help("调整容量、时间和比例")
            .animation(TeaMotion.animation(TeaMotion.selection, reduceMotion: reduceMotion), value: store.showsSettings)
        }
    }

    private var teaPicker: some View {
        HStack(spacing: 7) {
            ForEach(TeaKind.allCases) { tea in
                let selected = !store.isCustomMode && store.tea == tea
                Button { act { store.selectTea(tea) } } label: {
                    VStack(spacing: 7) {
                        Image(systemName: tea.symbol).font(TeaTypography.font(size: 18, weight: .medium))
                        Text(tea.name).font(TeaTypography.font(size: 12, weight: selected ? .semibold : .regular))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(selected ? TeaStyle.forest : Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 15))
                    .foregroundStyle(selected ? TeaStyle.background : TeaStyle.muted)
                    .animation(TeaMotion.animation(TeaMotion.selection, reduceMotion: reduceMotion), value: selected)
                }
                .buttonStyle(TeaButtonStyle())
                .disabled(store.isActive)
                .accessibilityLabel("选择\(tea.name)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var modePicker: some View {
        HStack(spacing: 8) {
            Button {
                act {
                    store.enterCustomMode()
                    store.showsSettings = true
                }
            } label: {
                Label(store.isCustomMode && store.hasUnsavedChanges ? "自定义 · 未保存" : "自定义",
                      systemImage: store.isCustomMode ? store.configuration.icon.rawValue : "slider.horizontal.3")
                    .font(TeaTypography.font(size: 11, weight: .medium))
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(store.isCustomMode ? TeaStyle.forest : Color.white.opacity(0.7), in: Capsule())
                    .foregroundStyle(store.isCustomMode ? TeaStyle.background : TeaStyle.green)
                    .modifier(TeaValueChange(value: store.hasUnsavedChanges.description))
                    .animation(TeaMotion.animation(TeaMotion.selection, reduceMotion: reduceMotion), value: store.isCustomMode)
            }.buttonStyle(TeaButtonStyle()).disabled(store.isActive && !store.isCustomMode)
            if store.isCustomMode {
                Button(store.savedConfiguration == nil ? "保存" : "更新") { saveConfiguration() }
                    .buttonStyle(TeaButtonStyle()).font(TeaTypography.font(size: 11, weight: .semibold))
                    .disabled(store.savedConfiguration == nil && !store.canSaveAsNew)
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
            Menu {
                if store.customConfigurations.isEmpty {
                    Text("还没有保存的配置")
                }
                ForEach(store.customConfigurations) { configuration in
                    Button {
                        act {
                            store.selectCustomConfiguration(id: configuration.id)
                            store.showsSettings = false
                        }
                    } label: {
                        Label(configuration.name, systemImage: configuration.icon.rawValue)
                    }
                }
            } label: {
                Text("已存 \(store.customConfigurations.count)/10").font(TeaTypography.font(size: 11))
                    .modifier(TeaValueChange(value: String(store.customConfigurations.count), numeric: true))
            }
            .menuStyle(.borderlessButton).fixedSize().disabled(store.isActive)
            .modifier(TeaHoverFeedback(color: TeaStyle.green))
        }
        .animation(TeaMotion.animation(TeaMotion.selection, reduceMotion: reduceMotion), value: store.isCustomMode)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                TeaHeroEyebrow(title: heroEyebrow, symbol: heroSymbol)
                Spacer()
                Text("第 \(store.displayedInfusion) 泡")
                    .font(TeaTypography.font(size: 11, weight: .semibold))
                    .modifier(TeaValueChange(value: String(store.displayedInfusion), numeric: true))
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(TeaStyle.pale, in: Capsule())
            }
            HStack(alignment: .center, spacing: 12) {
                ZStack(alignment: .leading) {
                    heroReadout
                        .id(heroReadoutKind)
                        .transition(TeaMotion.readoutTransition(reduceMotion: reduceMotion))
                }
                // The fixed-width menu reserves 223 pt for values and 65 pt for the ring.
                .frame(width: 223, height: 89, alignment: .leading)
                .clipped()
                .animation(TeaMotion.animation(TeaMotion.readout, reduceMotion: reduceMotion), value: heroReadoutKind)
                ZStack {
                    Circle().stroke(TeaStyle.pale, lineWidth: 3)
                    if store.phase == .cooling || store.phase == .brewing {
                        Circle().trim(from: 0, to: store.progress)
                            .stroke(TeaStyle.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(reduceMotion ? nil : .linear(duration: 1), value: store.progress)
                            .id(store.phase).transition(.opacity)
                    }
                    Image(systemName: heroSymbol)
                        .font(TeaTypography.font(size: 28, weight: .light)).foregroundStyle(TeaStyle.green)
                        .id(heroSymbol).transition(.opacity)
                }
                .frame(width: 65, height: 65)
                .padding(.trailing, 2)
                .accessibilityHidden(true)
            }
            if store.isActive {
                HStack(spacing: 5) {
                    stagePill("晾水", active: store.phase == .cooling)
                    Image(systemName: "chevron.right").font(TeaTypography.font(size: 8))
                    stagePill("投茶", active: store.phase == .waitingForLeaves)
                    Image(systemName: "chevron.right").font(TeaTypography.font(size: 8))
                    stagePill("泡茶", active: store.phase == .brewing || store.phase == .ready)
                }
                .foregroundStyle(TeaStyle.muted)
                .transition(.opacity)
            }
        }
        .padding(19)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(TeaStyle.border.opacity(0.6), lineWidth: 0.5))
        .animation(TeaMotion.animation(TeaMotion.content, reduceMotion: reduceMotion), value: store.displayedInfusion)
        .animation(TeaMotion.animation(TeaMotion.selection, reduceMotion: reduceMotion), value: heroSymbol)
    }

    private enum HeroReadoutKind: Hashable {
        case dose, duration, cooling, brewing, waitingForLeaves, ready, preparingRefill
    }

    private var heroReadoutKind: HeroReadoutKind {
        switch store.phase {
        case .idle: return store.displayedInfusion > 1 ? .duration : .dose
        case .cooling: return .cooling
        case .brewing: return .brewing
        case .waitingForLeaves: return .waitingForLeaves
        case .ready: return .ready
        case .preparingRefill: return .preparingRefill
        }
    }

    private var heroReadout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                switch heroReadoutKind {
                case .dose:
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(teaGrams(store.recommendedGrams))
                            .font(TeaTypography.heroValue)
                            .lineLimit(1).minimumScaleFactor(0.5)
                            .modifier(TeaValueChange(value: teaGrams(store.recommendedGrams), numeric: true))
                        Text("克").font(TeaTypography.font(size: 17, weight: .medium)).foregroundStyle(TeaStyle.muted)
                    }
                case .duration:
                    Text(teaClock(store.currentBrewSeconds))
                        .font(TeaTypography.heroValue)
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .modifier(TeaValueChange(value: String(store.currentBrewSeconds), numeric: true))
                        .accessibilityLabel("本泡浸泡 \(teaDuration(store.currentBrewSeconds))")
                case .cooling, .brewing:
                    Text(teaClock(store.remainingSeconds))
                        .font(TeaTypography.heroValue)
                        .lineLimit(1).minimumScaleFactor(0.75)
                        .transaction { $0.animation = nil }
                default:
                    Text(heroTitle).font(TeaTypography.font(size: 31, weight: .medium))
                }
            }
            .frame(height: 69, alignment: .leading)
            Text(heroReadoutSubtitle)
                .font(TeaTypography.font(size: 11)).foregroundStyle(TeaStyle.muted)
                .lineLimit(1).minimumScaleFactor(0.9)
                .frame(height: 14, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroReadoutSubtitle: String {
        switch heroReadoutKind {
        case .dose: return "\(store.isCustomMode ? "自定义" : "建议干茶") · \(store.tea.detail)"
        case .duration: return "本泡浸泡 · 沿用原茶叶，不再加干茶"
        case .cooling: return "先等水凉一点，再放茶叶"
        case .brewing: return "让茶香慢慢释放"
        default: return heroSubtitle
        }
    }

    private func stagePill(_ label: String, active: Bool) -> some View {
        Text(label).font(TeaTypography.font(size: 10, weight: active ? .semibold : .regular))
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(active ? TeaStyle.pale : Color.clear, in: Capsule())
            .foregroundStyle(active ? TeaStyle.forest : TeaStyle.muted)
            .animation(TeaMotion.animation(TeaMotion.selection, reduceMotion: reduceMotion), value: active)
    }

    private var brewFields: some View {
        HStack(spacing: 11) {
            numberField("本次注水", suffix: "mL", value: Binding(
                get: { store.preferences.waterML }, set: { store.setWaterML($0) }))
            VStack(alignment: .leading, spacing: 7) {
                Text("当前泡次").font(TeaTypography.font(size: 10)).foregroundStyle(TeaStyle.muted)
                HStack(spacing: 8) {
                    infusionButton("minus", label: "减少泡次", enabled: store.startingInfusion > 1) {
                        store.setStartingInfusion(store.startingInfusion - 1)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(store.startingInfusion)")
                            .font(TeaTypography.font(size: 19, weight: .medium)).monospacedDigit()
                            .modifier(TeaValueChange(value: String(store.startingInfusion), numeric: true))
                        Text("泡").font(TeaTypography.font(size: 11)).foregroundStyle(TeaStyle.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("当前第 \(store.startingInfusion) 泡")
                    infusionButton("plus", label: "增加泡次", enabled: store.startingInfusion < 99) {
                        store.setStartingInfusion(store.startingInfusion + 1)
                    }
                }
                .frame(height: 26)
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func infusionButton(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button { act(action) } label: {
            Image(systemName: symbol).font(TeaTypography.font(size: 10, weight: .semibold))
                .frame(width: 26, height: 26)
                .foregroundStyle(symbol == "plus" ? TeaStyle.background : TeaStyle.forest)
                .background(symbol == "plus" ? TeaStyle.forest : TeaStyle.pale, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(TeaButtonStyle()).disabled(!enabled).opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label).help(label)
    }

    private func numberField(_ label: String, suffix: String, value: Binding<Double>) -> some View {
        TeaNumberField(label: label, suffix: suffix, value: Binding(
            get: { value.wrappedValue },
            set: { newValue in change { value.wrappedValue = newValue } }
        ))
    }

    private var ratioBinding: Binding<Double> {
        Binding(get: { store.recipe.waterPerGram },
                set: { value in store.updateRecipe(for: store.tea) { $0.waterPerGram = value } })
    }

    private var batchInfo: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let round = store.round {
                HStack(spacing: 7) {
                    Label("\(teaNumber(round.waterML)) mL", systemImage: "drop")
                    Text("·")
                    Text(store.displayedInfusion > 1 ? "沿用原茶叶" : "干茶 \(teaGrams(round.grams)) 克")
                    Spacer()
                    Text("\(teaNumber(round.waterPerGram)) : 1")
                }.font(TeaTypography.font(size: 11)).foregroundStyle(TeaStyle.muted)
                if store.displayedInfusion >= 4 {
                    Text("茶味可能已经淡了，可以换新茶叶。")
                        .font(TeaTypography.font(size: 11)).foregroundStyle(TeaStyle.green)
                } else if round.startedInfusions > 0 && store.phase == .preparingRefill {
                    Text("沿用原茶叶，不用再加干茶。")
                        .font(TeaTypography.font(size: 11)).foregroundStyle(TeaStyle.green)
                }
            }
        }.padding(.horizontal, 3)
    }

    private var recipeSummary: some View {
        HStack(spacing: 0) {
            recipeCell("晾水", value: teaDuration(store.recipe.coolingSeconds))
            Rectangle().fill(TeaStyle.border).frame(width: 1, height: 26)
            recipeCell("本泡浸泡", value: teaDuration(store.currentBrewSeconds))
            Rectangle().fill(TeaStyle.border).frame(width: 1, height: 26)
            recipeCell("续泡增加", value: store.recipe.incrementSeconds == 0 ? "不加时" : "+\(teaDuration(store.recipe.incrementSeconds))")
        }.padding(.vertical, 4)
    }

    private func recipeCell(_ label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(label).font(TeaTypography.font(size: 10)).foregroundStyle(TeaStyle.muted)
            Text(value).font(TeaTypography.font(size: 12, weight: .medium))
                .modifier(TeaValueChange(value: value, numeric: true))
        }.frame(maxWidth: .infinity)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if !store.isActive, let error = store.validationMessage {
                Text(error).font(TeaTypography.font(size: 11)).foregroundStyle(.red)
                    .transition(TeaMotion.transition(reduceMotion: reduceMotion))
            }
            Button { act(onPrimary) } label: {
                HStack(spacing: 8) {
                    Text(primaryTitle)
                        .id(primaryTitle).transition(.opacity)
                    if store.phase != .cooling && store.phase != .brewing {
                        Image(systemName: "arrow.right").font(TeaTypography.font(size: 11, weight: .semibold))
                    }
                }
                .font(TeaTypography.font(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity).frame(height: 45)
                .foregroundStyle(TeaStyle.background)
                .background(TeaStyle.forest, in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(TeaButtonStyle())
            .disabled(store.phase == .brewing || (!store.isActive && store.validationMessage != nil))
            .opacity(store.phase == .brewing ? 0.72 : 1)
            if store.isActive {
                if store.phase == .preparingRefill && store.canSkipCooling { skipCoolingButton }
                HStack {
                    Button("换新茶叶") { act(onEnd) }
                    Spacer()
                    Button("结束本轮") { act(onEnd) }
                }.buttonStyle(TeaButtonStyle()).font(TeaTypography.font(size: 11)).foregroundStyle(TeaStyle.muted)
            } else if store.canSkipCooling {
                HStack {
                    skipCoolingButton
                    Spacer(minLength: 8)
                    Text(store.temperatureText)
                        .font(TeaTypography.font(size: 10)).foregroundStyle(TeaStyle.muted)
                        .help("晾水计时不等于测温")
                }
            } else {
                Text("\(store.temperatureText) · 晾水计时不等于测温")
                    .font(TeaTypography.font(size: 10)).foregroundStyle(TeaStyle.muted)
            }
        }
        .animation(TeaMotion.animation(TeaMotion.content, reduceMotion: reduceMotion), value: store.validationMessage)
    }

    private var skipCoolingButton: some View {
        Button { act(onSkipCooling) } label: {
            Label("跳过晾水，直接泡茶", systemImage: "forward.end.fill")
                .font(TeaTypography.font(size: 11, weight: .medium))
        }
        .buttonStyle(TeaButtonStyle()).foregroundStyle(TeaStyle.green)
        .disabled(!store.isActive && store.validationMessage != nil)
        .accessibilityLabel("跳过晾水，直接泡茶")
        .help("水已凉好或茶叶已放入时使用，从现在开始本泡浸泡计时")
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(store.isCustomMode ? "自定义配置" : "内置模板参数").font(TeaTypography.font(size: 14, weight: .semibold))
                Spacer()
                Text(store.tea.name).font(TeaTypography.font(size: 11)).foregroundStyle(TeaStyle.muted)
            }
            TextField("配置名称", text: Binding(get: { store.configuration.name }, set: { name in
                change { store.setConfigurationName(name) }
            }))
                .textFieldStyle(.roundedBorder).font(TeaTypography.font(size: 13)).accessibilityLabel("自定义配置名称")
            iconPicker
            numberField("水 : 干茶（重量比）", suffix: ": 1", value: ratioBinding)
            temperatureSetting
            timeSetting("晾水时间", keyPath: \.coolingSeconds, range: 0...900, step: 30, zeroText: "跳过晾水")
            timeSetting("首泡时间", keyPath: \.firstBrewSeconds, range: 15...1800, step: 15)
            timeSetting("每次续泡增加", keyPath: \.incrementSeconds, range: 0...600, step: 15, zeroText: "不额外加时")
            Text(store.isActive ? "本轮用量和名称保持不变；时间修改用于下一泡，其余修改用于下一轮。" : "修改任意参数即进入自定义模式。草稿自动保留，点击保存后加入配置列表。")
                .font(TeaTypography.font(size: 10)).foregroundStyle(TeaStyle.muted).fixedSize(horizontal: false, vertical: true)
            if store.isCustomMode {
                configurationControls.transition(TeaMotion.transition(reduceMotion: reduceMotion))
            }
            Button {
                act { store.showsSettings = false }
            } label: {
                Text("返回泡茶").font(TeaTypography.font(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(TeaStyle.pale, in: RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(TeaButtonStyle())
        }
        .padding(15).background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 15))
    }

    private var cupSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("我的杯子").font(TeaTypography.font(size: 14, weight: .semibold))
            HStack(spacing: 11) {
                numberField("杯子容积", suffix: "mL", value: Binding(
                    get: { store.preferences.cupCapacityML }, set: { store.setCapacity($0) }))
                numberField("本次注水", suffix: "mL", value: Binding(
                    get: { store.preferences.waterML }, set: { store.setWaterML($0) }))
            }
            Text("所有茶共用，切换配置时保留；修改不进入自定义模式。")
                .font(TeaTypography.font(size: 10)).foregroundStyle(TeaStyle.muted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(15).background(TeaStyle.pale.opacity(0.5), in: RoundedRectangle(cornerRadius: 15))
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("配置图标").font(TeaTypography.font(size: 10)).foregroundStyle(TeaStyle.muted)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                ForEach(TeaIcon.allCases) { icon in
                    let selected = store.configuration.icon == icon
                    Button { act { store.setConfigurationIcon(icon) } } label: {
                        Image(systemName: icon.rawValue).font(TeaTypography.font(size: 17))
                            .frame(maxWidth: .infinity).frame(height: 34)
                            .background(selected ? TeaStyle.forest : TeaStyle.pale.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(selected ? TeaStyle.background : TeaStyle.green)
                            .animation(TeaMotion.animation(TeaMotion.selection, reduceMotion: reduceMotion), value: selected)
                    }.buttonStyle(TeaButtonStyle()).help(icon.name).accessibilityLabel("图标：\(icon.name)")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private var configurationControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !store.canSaveAsNew {
                Text("已保存 10 条，可更新或删除已有配置。")
                    .font(TeaTypography.font(size: 10)).foregroundStyle(TeaStyle.muted)
            }
            HStack {
                Button(store.savedConfiguration == nil ? "保存配置" : "更新配置") { saveConfiguration() }
                    .disabled(store.savedConfiguration == nil && !store.canSaveAsNew)
                if store.savedConfiguration != nil {
                    Button("另存为新配置") { saveConfiguration(asNew: true) }.disabled(!store.canSaveAsNew)
                    Spacer(minLength: 0)
                    Button("删除") {
                        act {
                            store.deleteSelectedConfiguration()
                            configurationFeedbackID += 1
                        }
                    }
                        .foregroundStyle(.red).disabled(store.isActive)
                }
            }.buttonStyle(TeaButtonStyle()).font(TeaTypography.font(size: 11, weight: .medium))
        }
    }

    private var temperatureSetting: some View {
        VStack(spacing: 9) {
            HStack {
                Text("参考水温").font(TeaTypography.font(size: 12))
                Spacer()
                Text("\(store.configuration.waterTemperatureC)°C")
                    .font(TeaTypography.font(size: 16, weight: .medium)).monospacedDigit()
                    .modifier(TeaValueChange(value: String(store.configuration.waterTemperatureC), numeric: true))
            }
            Slider(value: Binding(get: { Double(store.configuration.waterTemperatureC) },
                                  set: { temperature in act { store.setTemperature(Int(temperature.rounded())) } }), in: 50...100, step: 5)
                .accessibilityLabel("参考水温")
            HStack(spacing: 5) {
                ForEach([70, 80, 85, 90, 95, 100], id: \.self) { temperature in
                    let selected = store.configuration.waterTemperatureC == temperature
                    Button { act { store.setTemperature(temperature) } } label: {
                        Text("\(temperature)°")
                            .font(TeaTypography.font(size: 10, weight: .medium)).monospacedDigit()
                            .frame(maxWidth: .infinity).padding(.vertical, 5)
                            .foregroundStyle(selected ? TeaStyle.background : TeaStyle.green)
                            .background(selected ? TeaStyle.forest : TeaStyle.pale.opacity(0.6), in: Capsule())
                            .animation(TeaMotion.animation(TeaMotion.selection, reduceMotion: reduceMotion), value: selected)
                    }
                    .buttonStyle(TeaButtonStyle()).accessibilityLabel("水温 \(temperature)°C")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .padding(12).background(TeaStyle.pale.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
    }

    private func timeSetting(_ title: String, keyPath: WritableKeyPath<TeaRecipe, Int>, range: ClosedRange<Int>, step: Int, zeroText: String? = nil) -> some View {
        let value = Binding(get: { store.recipe[keyPath: keyPath] },
                            set: { newValue in act {
                                store.updateRecipe(for: store.tea) { $0[keyPath: keyPath] = newValue }
                            } })
        let minutes = Binding(get: { value.wrappedValue / 60 }, set: { minutes in
            guard minutes != value.wrappedValue / 60 else { return }
            value.wrappedValue = min(range.upperBound, max(range.lowerBound, minutes * 60 + value.wrappedValue % 60))
        })
        let seconds = Binding(get: { value.wrappedValue % 60 }, set: { seconds in
            guard seconds != value.wrappedValue % 60 else { return }
            value.wrappedValue = min(range.upperBound, max(range.lowerBound, value.wrappedValue / 60 * 60 + seconds))
        })
        let minuteOptions = Array(Set(Array(0...(range.upperBound / 60)) + [minutes.wrappedValue])).sorted()
        let secondOptions = Array(Set(Array(stride(from: 0, to: 60, by: step)) + [seconds.wrappedValue]))
            .filter { range.contains(minutes.wrappedValue * 60 + $0) }.sorted()
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(TeaTypography.font(size: 12))
                if value.wrappedValue == 0, let zeroText {
                    Text(zeroText).font(TeaTypography.font(size: 10)).foregroundStyle(TeaStyle.muted)
                }
            }
            Spacer(minLength: 4)
            timeMenu("\(title) · 分钟", unit: "分", selection: minutes, options: minuteOptions)
            timeMenu("\(title) · 秒", unit: "秒", selection: seconds, options: secondOptions)
        }
    }

    private func timeMenu(_ label: String, unit: String, selection: Binding<Int>, options: [Int]) -> some View {
        Menu {
            Picker(label, selection: selection) {
                ForEach(options, id: \.self) { number in
                    Text("\(number) \(unit)").tag(number)
                }
            }.pickerStyle(.inline).labelsHidden()
        } label: {
            Text("\(String(format: "%02d", selection.wrappedValue)) \(unit)")
                .modifier(TeaValueChange(value: String(selection.wrappedValue), numeric: true))
        }
        .menuStyle(.borderlessButton).menuIndicator(.visible)
        .font(TeaTypography.font(size: 13, weight: .medium)).monospacedDigit()
        .frame(width: 72, height: 34)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9).strokeBorder(TeaStyle.border, lineWidth: 0.7)
                .allowsHitTesting(false)
        }
        .accessibilityLabel(label).accessibilityValue("\(selection.wrappedValue) \(unit)")
        .help(label)
        .disabled(options.count < 2)
        .modifier(TeaHoverFeedback(color: TeaStyle.green))
    }

    private var footer: some View {
        HStack {
            Label("静音也看得见", systemImage: "speaker.slash")
                .font(TeaTypography.font(size: 10)).foregroundStyle(TeaStyle.muted)
            Spacer()
            Button("预览提醒") { act(onPreview) }
                .disabled(store.reminder != nil)
                .accessibilityLabel("预览泡茶提醒")
            Text("·").foregroundStyle(TeaStyle.border)
            Button("退出") { act(onQuit) }
        }
        .buttonStyle(TeaButtonStyle()).font(TeaTypography.font(size: 11)).foregroundStyle(TeaStyle.green)
        .padding(.horizontal, 22).padding(.vertical, 15)
        .background(TeaStyle.background)
        .overlay(alignment: .top) { Rectangle().fill(TeaStyle.border.opacity(0.6)).frame(height: 0.5) }
    }

    private func change(_ action: () -> Void) {
        withAnimation(TeaMotion.animation(TeaMotion.content, reduceMotion: reduceMotion), action)
    }

    private func act(_ action: () -> Void) {
        if let window = NSApp.keyWindow,
           window.firstResponder is NSTextView || window.firstResponder is NSTextField {
            window.makeFirstResponder(window.contentView)
        }
        change(action)
    }

    private func saveConfiguration(asNew: Bool = false) {
        act {
            store.saveConfiguration(asNew: asNew)
            configurationFeedbackID += 1
        }
    }

    private var heroEyebrow: String {
        switch store.phase {
        case .idle: return store.isCustomMode ? store.configuration.name : (store.displayedInfusion > 1 ? "接着泡这一杯" : "这一杯，刚刚好")
        case .cooling: return "正在晾水"
        case .waitingForLeaves: return "晾水计时结束"
        case .brewing: return "正在泡茶"
        case .ready: return "茶香已经就绪"
        case .preparingRefill: return "准备续一杯"
        }
    }
    private var heroSymbol: String {
        switch store.phase {
        case .idle: return store.displaySymbol
        case .cooling: return "drop"
        case .waitingForLeaves: return "leaf.arrow.triangle.circlepath"
        case .brewing: return "cup.and.saucer"
        case .ready: return "checkmark"
        case .preparingRefill: return "arrow.clockwise"
        }
    }
    private var heroTitle: String {
        switch store.phase {
        case .waitingForLeaves: return store.displayedInfusion == 1 ? "该放茶叶了" : "放回原茶叶"
        case .ready: return "泡好了"
        case .preparingRefill: return "再续一杯"
        default: return ""
        }
    }
    private var heroSubtitle: String {
        switch store.phase {
        case .waitingForLeaves:
            return store.displayedInfusion == 1 ? "投茶 \(teaGrams(store.round?.grams ?? 0)) 克后，确认开始" : "沿用原茶叶，放回后再开始计时"
        case .ready: return "取出茶滤或倒出茶汤，慢慢享用"
        case .preparingRefill: return "新水准备好后，再开始计时"
        default: return ""
        }
    }
    private var primaryTitle: String {
        switch store.phase {
        case .idle:
            if store.displayedInfusion > 1 {
                return store.recipe.coolingSeconds > 0 ? "已接新水，开始晾水" : "已注水，开始第 \(store.displayedInfusion) 泡"
            }
            return store.recipe.coolingSeconds > 0 ? "已接水，开始晾水" : "已注水，开始泡茶"
        case .cooling: return "跳过晾水，直接泡茶"
        case .waitingForLeaves: return store.displayedInfusion == 1 ? "已投茶，开始泡茶" : "已放回，开始第 \(store.displayedInfusion) 泡"
        case .brewing: return "泡茶中，到点提醒你"
        case .ready: return "续泡 · 第 \(store.displayedInfusion + 1) 泡"
        case .preparingRefill: return store.recipe.coolingSeconds > 0 ? "已接新水，开始晾水" : "已注水，开始第 \(store.displayedInfusion) 泡"
        }
    }
}

struct TeaReminderView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @TeaViewState private var hasAppeared = false
    let reminder: TeaReminder
    let onConfirm: () -> Void
    let onEnd: () -> Void

    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Text(reminder.isPreview ? "提醒预览" : "TEA PANEL")
                    .font(TeaTypography.font(size: 10, weight: .medium)).tracking(2)
                Spacer()
                Text("\(reminder.name) · 第 \(reminder.infusion) 泡")
                    .font(TeaTypography.font(size: 11, weight: .medium)).lineLimit(1)
            }.foregroundStyle(TeaStyle.pale.opacity(0.8))

            Image(systemName: reminder.symbol)
                .font(TeaTypography.font(size: 31, weight: .light)).foregroundStyle(TeaStyle.pale)
                .padding(.top, 4)
                .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.88)
                .offset(y: hasAppeared || reduceMotion ? 0 : 3)
                .opacity(hasAppeared ? 1 : 0)
                .animation(reduceMotion ? .easeOut(duration: 0.1) : .easeOut(duration: 0.4).delay(0.04), value: hasAppeared)
            Text(reminder.kind == .addLeaves ? "晾水计时结束" : "你的茶，泡好了")
                .font(TeaTypography.font(size: 28, weight: .medium)).foregroundStyle(.white)
            Text(subtitle)
                .font(TeaTypography.font(size: 13)).foregroundStyle(TeaStyle.pale.opacity(0.85))
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)

            Button(action: onConfirm) {
                Text(buttonTitle).font(TeaTypography.font(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity).frame(height: 43)
                    .foregroundStyle(TeaStyle.forest)
                    .background(TeaStyle.pale, in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(TeaButtonStyle()).padding(.top, 3)

            if reminder.kind == .addLeaves && !reminder.isPreview {
                Button("结束本轮", action: onEnd)
                    .buttonStyle(TeaButtonStyle()).font(TeaTypography.font(size: 11)).foregroundStyle(TeaStyle.pale.opacity(0.7))
            } else {
                Text(reminder.isPreview ? "实际到点后也会这样提醒，直到你点击处理" : "静音提醒 · 等你处理后再收起")
                    .font(TeaTypography.font(size: 10)).foregroundStyle(TeaStyle.pale.opacity(0.6))
            }
        }
        .padding(25).frame(width: 440)
        .background(TeaStyle.forest.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 23))
        .overlay(RoundedRectangle(cornerRadius: 23).stroke(Color.white.opacity(0.16), lineWidth: 1))
        .environment(\.colorScheme, .light)
        .onAppear { hasAppeared = true }
    }

    private var subtitle: String {
        if reminder.kind == .teaReady { return "取出茶滤或倒出茶汤，留一点时间慢慢喝。" }
        return reminder.infusion == 1
            ? "请放入 \(teaGrams(reminder.grams)) 克干茶，投茶后再开始计时。"
            : "请放回原茶叶，不用再加干茶。"
    }
    private var buttonTitle: String {
        if reminder.isPreview { return "看到了" }
        if reminder.kind == .teaReady { return "知道了，去喝茶" }
        return reminder.infusion == 1 ? "已投茶，开始泡茶" : "已放回，开始第 \(reminder.infusion) 泡"
    }
}
