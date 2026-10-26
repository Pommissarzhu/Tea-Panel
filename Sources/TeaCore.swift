import Foundation
import Combine

enum TeaKind: String, CaseIterable, Codable, Identifiable {
    case gardenia, tieguanyin, jasmine

    var id: String { rawValue }
    var name: String {
        switch self {
        case .gardenia: return "栀子花茶"
        case .tieguanyin: return "铁观音"
        case .jasmine: return "茉莉花茶"
        }
    }
    var detail: String {
        switch self {
        case .gardenia: return "栀子 + 绿茶"
        case .tieguanyin: return "乌龙茶"
        case .jasmine: return "茉莉 + 绿茶"
        }
    }
    var symbol: String {
        switch self {
        case .gardenia: return "leaf.fill"
        case .tieguanyin: return "cup.and.saucer.fill"
        case .jasmine: return "camera.macro"
        }
    }
    var recommendedWaterTemperatureC: Int {
        switch self {
        case .gardenia: return 80
        case .tieguanyin: return 100
        case .jasmine: return 85
        }
    }
    var temperature: String { "参考水温约 \(recommendedWaterTemperatureC)°C" }
    var defaultRecipe: TeaRecipe {
        // User-confirmed cup recipes; gardenia updated 2026-10-26. Each refill adds 30 seconds.
        switch self {
        case .gardenia:
            return TeaRecipe(coolingSeconds: 120, firstBrewSeconds: 120, incrementSeconds: 30, waterPerGram: 165)
        case .tieguanyin:
            return TeaRecipe(coolingSeconds: 0, firstBrewSeconds: 60, incrementSeconds: 30, waterPerGram: 40)
        case .jasmine:
            return TeaRecipe(coolingSeconds: 120, firstBrewSeconds: 180, incrementSeconds: 30, waterPerGram: 50)
        }
    }
}

struct TeaRecipe: Codable, Equatable {
    var coolingSeconds: Int
    var firstBrewSeconds: Int
    var incrementSeconds: Int
    var waterPerGram: Double

    func brewSeconds(for infusion: Int) -> Int {
        firstBrewSeconds + max(0, infusion - 1) * incrementSeconds
    }
}

enum TeaIcon: String, CaseIterable, Codable, Identifiable {
    case leaf = "leaf.fill"
    case flower = "camera.macro"
    case cup = "cup.and.saucer.fill"
    case mug = "mug.fill"
    case drop = "drop.fill"
    case sun = "sun.max.fill"
    case moon = "moon.fill"
    case sparkle = "sparkles"
    case flame = "flame.fill"
    case heart = "heart.fill"

    var id: String { rawValue }
    var name: String {
        switch self {
        case .leaf: return "茶叶"
        case .flower: return "花朵"
        case .cup: return "茶杯"
        case .mug: return "马克杯"
        case .drop: return "水滴"
        case .sun: return "太阳"
        case .moon: return "月亮"
        case .sparkle: return "星光"
        case .flame: return "火焰"
        case .heart: return "爱心"
        }
    }
}

struct TeaConfiguration: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var icon: TeaIcon
    var baseTea: TeaKind
    var waterTemperatureC: Int
    var recipe: TeaRecipe

    static func template(for tea: TeaKind) -> TeaConfiguration {
        TeaConfiguration(id: "builtin:\(tea.rawValue)", name: tea.name,
                         icon: TeaIcon(rawValue: tea.symbol) ?? .leaf, baseTea: tea,
                         waterTemperatureC: tea.recommendedWaterTemperatureC, recipe: tea.defaultRecipe)
    }

    func customCopy() -> TeaConfiguration {
        var copy = self
        copy.id = UUID().uuidString
        copy.name = "\(baseTea.name) · 自定义"
        return copy
    }
}

struct TeaPreferences: Codable {
    static let currentTemplateRevision = 2
    var cupCapacityML: Double = 330
    var waterML: Double = 330
    var selectedTea: TeaKind = .gardenia
    var recipes: [String: TeaRecipe] = [:]
    var templateRevision: Int? = currentTemplateRevision
    var customModeRevision: Int? = 1
    var customConfigurations: [TeaConfiguration]? = []
    var customDraft: TeaConfiguration?
    var usesCustomMode: Bool? = false
    var independentBrewRevision: Int? = 1

    func recipe(for tea: TeaKind) -> TeaRecipe {
        recipes[tea.rawValue] ?? tea.defaultRecipe
    }

    mutating func upgradeTemplateDefaults() -> Bool {
        guard (templateRevision ?? 1) < Self.currentTemplateRevision else { return false }
        for tea in TeaKind.allCases {
            guard var saved = recipes[tea.rawValue] else { continue }
            let updated = tea.defaultRecipe
            // Replace only values that still match v1; keep individually customized fields.
            let oldCooling = tea == .tieguanyin ? 0 : 120
            let oldBrew = tea == .tieguanyin ? 180 : 120
            let oldIncrement = tea == .tieguanyin ? 60 : 30
            if saved.coolingSeconds == oldCooling { saved.coolingSeconds = updated.coolingSeconds }
            if saved.firstBrewSeconds == oldBrew { saved.firstBrewSeconds = updated.firstBrewSeconds }
            if saved.incrementSeconds == oldIncrement { saved.incrementSeconds = updated.incrementSeconds }
            if saved.waterPerGram == 110 { saved.waterPerGram = updated.waterPerGram }
            recipes[tea.rawValue] = saved
        }
        templateRevision = Self.currentTemplateRevision
        return true
    }

    mutating func upgradeCustomMode() -> Bool {
        guard (customModeRevision ?? 0) < 1 else { return false }
        var imported: [TeaConfiguration] = []
        for tea in TeaKind.allCases {
            let oldRecipe = recipe(for: tea)
            guard oldRecipe != tea.defaultRecipe else { continue }
            var configuration = TeaConfiguration.template(for: tea).customCopy()
            configuration.recipe = oldRecipe
            imported.append(configuration)
            if tea == selectedTea {
                customDraft = configuration
                usesCustomMode = true
            }
        }
        customConfigurations = imported
        recipes = [:]
        customModeRevision = 1
        return true
    }

    mutating func upgradeIndependentBrewSettings(from data: Data) -> Bool {
        guard (independentBrewRevision ?? 0) < 1 else { return false }
        // Earlier versions stored water in each profile. Keep the active draft's water once.
        if usesCustomMode == true,
           let legacy = try? JSONDecoder().decode(LegacyBrewSettings.self, from: data),
           let draft = legacy.customDraft {
            cupCapacityML = draft.cupCapacityML ?? cupCapacityML
            waterML = draft.waterML ?? waterML
        }
        independentBrewRevision = 1
        return true
    }

    private struct LegacyBrewSettings: Decodable {
        struct Draft: Decodable {
            var cupCapacityML: Double?
            var waterML: Double?
        }
        var customDraft: Draft?
    }
}

enum TeaPhase {
    case idle, cooling, waitingForLeaves, brewing, ready, preparingRefill
}

struct TeaRound {
    let configuration: TeaConfiguration
    let waterML: Double
    var startedInfusions: Int = 0
    var tea: TeaKind { configuration.baseTea }
    var waterPerGram: Double { configuration.recipe.waterPerGram }
    var grams: Double { waterML / waterPerGram }
}

struct TeaReminder: Identifiable {
    enum Kind { case addLeaves, teaReady }
    let id = UUID()
    let kind: Kind
    let configuration: TeaConfiguration
    let infusion: Int
    let grams: Double
    let isPreview: Bool
    var name: String { configuration.name }
    var symbol: String { configuration.icon.rawValue }
}

func teaNumber(_ value: Double) -> String {
    value.formatted(.number.locale(Locale(identifier: "en_US_POSIX")).precision(.fractionLength(0...1)))
}

func teaGrams(_ value: Double) -> String { String(format: "%.1f", (value * 10).rounded() / 10) }

func teaClock(_ seconds: Int) -> String {
    String(format: "%02d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
}

func teaDuration(_ seconds: Int) -> String {
    if seconds == 0 { return "跳过" }
    if seconds < 60 { return "\(seconds) 秒" }
    if seconds % 60 == 0 { return "\(seconds / 60) 分钟" }
    return "\(seconds / 60) 分 \(seconds % 60) 秒"
}

@MainActor
final class TeaStore: ObservableObject {
    @Published var showsSettings = false
    @Published private(set) var configurationMessage: String?
    @Published var preferences: TeaPreferences {
        didSet {
            if let data = try? JSONEncoder().encode(preferences) {
                defaults.set(data, forKey: Self.preferencesKey)
            }
        }
    }
    @Published private(set) var phase: TeaPhase = .idle
    @Published private(set) var round: TeaRound?
    @Published private(set) var deadline: Date?
    @Published private(set) var clockDate: Date
    @Published private(set) var phaseDuration: Int = 0
    @Published private(set) var plannedBrewSeconds: Int = 120
    @Published private(set) var reminder: TeaReminder?
    @Published private(set) var startingInfusion: Int = 1

    private let defaults: UserDefaults
    private let now: () -> Date
    static let preferencesKey = "TeaPanel.preferences.v1"
    static let templateBackupKey = "TeaPanel.preferences.beforeTemplateV2"
    static let customModeBackupKey = "TeaPanel.preferences.beforeCustomModeV1"
    static let independentBrewBackupKey = "TeaPanel.preferences.beforeIndependentBrewV1"
    static let maximumConfigurations = 10

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        self.clockDate = now()
        if let data = defaults.data(forKey: Self.preferencesKey),
           var saved = try? JSONDecoder().decode(TeaPreferences.self, from: data) {
            let upgraded = saved.upgradeTemplateDefaults()
            let customUpgraded = saved.upgradeCustomMode()
            let brewUpgraded = saved.upgradeIndependentBrewSettings(from: data)
            preferences = saved
            if upgraded || customUpgraded || brewUpgraded, let updated = try? JSONEncoder().encode(saved) {
                if upgraded, defaults.data(forKey: Self.templateBackupKey) == nil {
                    defaults.set(data, forKey: Self.templateBackupKey)
                }
                if customUpgraded, defaults.data(forKey: Self.customModeBackupKey) == nil {
                    defaults.set(data, forKey: Self.customModeBackupKey)
                }
                if brewUpgraded, defaults.data(forKey: Self.independentBrewBackupKey) == nil {
                    defaults.set(data, forKey: Self.independentBrewBackupKey)
                }
                defaults.set(updated, forKey: Self.preferencesKey)
            }
        } else {
            preferences = TeaPreferences()
        }
    }

    var isCustomMode: Bool { preferences.usesCustomMode == true && preferences.customDraft != nil }
    var customConfigurations: [TeaConfiguration] { preferences.customConfigurations ?? [] }
    var configuration: TeaConfiguration {
        if isCustomMode, let draft = preferences.customDraft { return draft }
        return .template(for: preferences.selectedTea)
    }
    var savedConfiguration: TeaConfiguration? { customConfigurations.first { $0.id == configuration.id } }
    var hasUnsavedChanges: Bool { isCustomMode && savedConfiguration != configuration }
    var canSaveAsNew: Bool { customConfigurations.count < Self.maximumConfigurations }
    var displayName: String { round?.configuration.name ?? configuration.name }
    var displaySymbol: String { round?.configuration.icon.rawValue ?? configuration.icon.rawValue }
    var tea: TeaKind { round?.tea ?? configuration.baseTea }
    var recipe: TeaRecipe { configuration.recipe }
    var temperatureText: String { "参考水温约 \(configuration.waterTemperatureC)°C" }
    var isActive: Bool { phase != .idle }
    var canSkipCooling: Bool {
        phase == .cooling || ((phase == .idle || phase == .preparingRefill) && recipe.coolingSeconds > 0)
    }
    var remainingSeconds: Int {
        guard let deadline else { return 0 }
        return max(0, Int(ceil(deadline.timeIntervalSince(clockDate))))
    }
    var progress: Double {
        guard phaseDuration > 0 else { return 1 }
        return min(1, max(0, 1 - Double(remainingSeconds) / Double(phaseDuration)))
    }
    var displayedInfusion: Int {
        guard let round else { return startingInfusion }
        return round.startedInfusions + ((phase == .brewing || phase == .ready) ? 0 : 1)
    }
    var currentBrewSeconds: Int {
        phase == .idle || phase == .preparingRefill
            ? recipe.brewSeconds(for: displayedInfusion) : plannedBrewSeconds
    }
    var recommendedGrams: Double {
        let ratio = configuration.recipe.waterPerGram
        guard ratio.isFinite, ratio > 0 else { return 0 }
        return preferences.waterML / ratio
    }
    private var configurationValidationMessage: String? {
        guard recipe.waterPerGram.isFinite, recipe.waterPerGram > 0 else { return "水与干茶的比例要大于 0" }
        guard (50...100).contains(configuration.waterTemperatureC) else { return "参考水温应在 50–100°C 之间" }
        guard recipe.coolingSeconds >= 0, recipe.firstBrewSeconds > 0, recipe.incrementSeconds >= 0 else { return "请设置有效的计时时间" }
        return nil
    }
    var validationMessage: String? {
        let values = [preferences.cupCapacityML, preferences.waterML]
        guard values.allSatisfy({ $0.isFinite && $0 > 0 }) else { return "水量和容量都要大于 0" }
        guard preferences.waterML <= preferences.cupCapacityML else { return "注水量不能超过杯子容量" }
        return configurationValidationMessage
    }
    var statusText: String {
        switch phase {
        case .idle: return ""
        case .cooling: return "晾 \(teaClock(remainingSeconds))"
        case .waitingForLeaves: return "待投茶"
        case .brewing: return "泡 \(teaClock(remainingSeconds))"
        case .ready: return "已泡好"
        case .preparingRefill: return "第 \(displayedInfusion) 泡"
        }
    }

    func selectTea(_ tea: TeaKind) {
        guard !isActive else { return }
        preferences.selectedTea = tea
        preferences.usesCustomMode = false
        configurationMessage = nil
    }

    func setCapacity(_ value: Double) {
        preferences.cupCapacityML = value
        if value > 0, preferences.waterML > value { preferences.waterML = value }
    }

    func setWaterML(_ value: Double) { preferences.waterML = value }
    func setStartingInfusion(_ value: Int) {
        guard !isActive else { return }
        startingInfusion = min(99, max(1, value))
    }
    func setTemperature(_ value: Int) { editConfiguration { $0.waterTemperatureC = value } }
    func setConfigurationName(_ value: String) { editConfiguration { $0.name = value } }
    func setConfigurationIcon(_ value: TeaIcon) { editConfiguration { $0.icon = value } }

    func updateRecipe(for tea: TeaKind, _ update: (inout TeaRecipe) -> Void) {
        guard tea == configuration.baseTea else { return }
        editConfiguration { update(&$0.recipe) }
    }

    private func editConfiguration(_ update: (inout TeaConfiguration) -> Void) {
        var edited = configuration
        let original = edited
        update(&edited)
        guard edited != original else { return }
        if !isCustomMode {
            edited.id = UUID().uuidString
            if edited.name == original.name { edited.name = "\(edited.baseTea.name) · 自定义" }
        }
        preferences.customDraft = edited
        preferences.usesCustomMode = true
        configurationMessage = nil
    }

    func enterCustomMode() {
        guard !isActive else { return }
        if preferences.customDraft == nil { preferences.customDraft = configuration.customCopy() }
        preferences.usesCustomMode = true
        configurationMessage = nil
    }

    func selectCustomConfiguration(id: String) {
        guard !isActive, let saved = customConfigurations.first(where: { $0.id == id }) else { return }
        preferences.customDraft = saved
        preferences.selectedTea = saved.baseTea
        preferences.usesCustomMode = true
        configurationMessage = nil
    }

    @discardableResult
    func saveConfiguration(asNew: Bool = false) -> Bool {
        guard isCustomMode else { return false }
        if let error = configurationValidationMessage { configurationMessage = error; return false }
        var edited = configuration
        edited.name = edited.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !edited.name.isEmpty else { configurationMessage = "请给配置起个名字"; return false }
        var saved = customConfigurations
        if !asNew, let index = saved.firstIndex(where: { $0.id == edited.id }) {
            saved[index] = edited
        } else {
            guard canSaveAsNew else { configurationMessage = "最多保存 10 条，请更新或删除已有配置"; return false }
            if asNew { edited.id = UUID().uuidString }
            saved.append(edited)
        }
        preferences.customConfigurations = saved
        preferences.customDraft = edited
        configurationMessage = "已保存"
        return true
    }

    func deleteSelectedConfiguration() {
        guard !isActive, savedConfiguration != nil else { return }
        let removedID = configuration.id
        preferences.customConfigurations = customConfigurations.filter { $0.id != removedID }
        var draft = configuration
        draft.id = UUID().uuidString
        preferences.customDraft = draft
        configurationMessage = "已删除，当前参数保留为未保存草稿"
    }

    func startNewRound(skipCooling: Bool = false) {
        guard phase == .idle, validationMessage == nil else { return }
        reminder = nil
        round = TeaRound(configuration: configuration, waterML: preferences.waterML,
                         startedInfusions: startingInfusion - 1)
        beginPour(skipCooling: skipCooling)
    }

    private func beginPour(skipCooling: Bool = false) {
        guard let round else { return }
        let recipe = self.recipe
        plannedBrewSeconds = recipe.brewSeconds(for: round.startedInfusions + 1)
        if recipe.coolingSeconds > 0 && !skipCooling {
            beginTimer(phase: .cooling, seconds: recipe.coolingSeconds)
        } else {
            beginBrewing()
        }
    }

    func confirmLeaves() {
        guard phase == .waitingForLeaves else { return }
        reminder = nil
        beginBrewing()
    }

    func skipCooling() {
        switch phase {
        case .idle: startNewRound(skipCooling: true)
        case .preparingRefill: startRefill(skipCooling: true)
        case .cooling:
            reminder = nil
            beginBrewing()
        case .waitingForLeaves, .brewing, .ready: break
        }
    }

    private func beginBrewing() {
        guard var activeRound = round else { return }
        activeRound.startedInfusions += 1
        round = activeRound
        beginTimer(phase: .brewing, seconds: plannedBrewSeconds)
    }

    private func beginTimer(phase: TeaPhase, seconds: Int) {
        clockDate = now()
        phaseDuration = seconds
        deadline = clockDate.addingTimeInterval(Double(seconds))
        self.phase = phase
    }

    func prepareRefill() {
        guard phase == .ready else { return }
        reminder = nil
        phase = .preparingRefill
    }

    func startRefill(skipCooling: Bool = false) {
        guard phase == .preparingRefill else { return }
        beginPour(skipCooling: skipCooling)
    }

    func endRound() {
        reminder = nil
        deadline = nil
        round = nil
        phase = .idle
        startingInfusion = 1
    }

    func tick() {
        clockDate = now()
        guard let deadline, clockDate >= deadline, let round else { return }
        switch phase {
        case .cooling:
            self.deadline = nil
            phase = .waitingForLeaves
            reminder = TeaReminder(kind: .addLeaves, configuration: round.configuration,
                                   infusion: round.startedInfusions + 1, grams: round.grams, isPreview: false)
        case .brewing:
            self.deadline = nil
            phase = .ready
            reminder = TeaReminder(kind: .teaReady, configuration: round.configuration,
                                   infusion: round.startedInfusions, grams: round.grams, isPreview: false)
        default: break
        }
    }

    func dismissReminder() { reminder = nil }

    func previewReminder() {
        // A preview never replaces an outstanding real reminder or changes a timer.
        guard reminder == nil else { return }
        reminder = TeaReminder(kind: .teaReady, configuration: round?.configuration ?? configuration, infusion: max(1, displayedInfusion),
                               grams: round?.grams ?? recommendedGrams, isPreview: true)
    }
}
