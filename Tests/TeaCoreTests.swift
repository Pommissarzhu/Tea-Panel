import Foundation

@main
enum TeaCoreTests {
    @MainActor static func main() throws {
        let suite = "local.teapanel.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = TeaStore(defaults: defaults, now: { now })
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }

        check(store.preferences.waterML == 330 && store.recommendedGrams == 2 && teaGrams(store.recommendedGrams) == "2.0",
              "Gardenia should default to exactly 2 g of dry tea for 330 ml")
        check(TeaKind.gardenia.recommendedWaterTemperatureC == 80, "Gardenia green tea should reference 80 C")
        check(TeaKind.tieguanyin.recommendedWaterTemperatureC == 100, "Tieguanyin should reference 100 C")
        store.selectTea(.tieguanyin)
        check(store.recommendedGrams == 8.25 && teaGrams(store.recommendedGrams) == "8.3",
              "Tieguanyin 5 g / 200 ml should scale exactly and display half-up to one decimal")
        store.selectTea(.jasmine)
        check(teaGrams(store.recommendedGrams) == "6.6", "Jasmine 4 g / 200 ml should scale to 6.6 g")
        check(store.configuration.waterTemperatureC == 85 && store.recipe.coolingSeconds == 120,
              "Jasmine should reference 85 C and cool for two minutes")
        for (tea, waterML, grams, times) in [
            (TeaKind.gardenia, 330.0, 2.0, [120, 150, 180, 210]),
            (TeaKind.jasmine, 200.0, 4.0, [180, 210, 240, 270]),
            (TeaKind.tieguanyin, 200.0, 5.0, [60, 90, 120, 150])
        ] {
            store.setWaterML(waterML)
            store.selectTea(tea)
            check(store.recommendedGrams == grams, "Each confirmed recipe must give the specified dose for its water volume")
            check((1...4).map { store.recipe.brewSeconds(for: $0) } == times,
                  "The first four infusions must match the confirmed time table")
        }
        store.setWaterML(330)
        store.selectTea(.gardenia)
        store.updateRecipe(for: .gardenia) { $0.waterPerGram = 110 }
        check(teaGrams(store.recommendedGrams) == "3.0", "Custom 330 / 110 should still be 3.0 g")
        store.updateRecipe(for: .gardenia) { $0.waterPerGram = 100 }
        check(teaGrams(store.recommendedGrams) == "3.3", "330 / 100 should be 3.3 g")
        store.updateRecipe(for: .gardenia) { $0.waterPerGram = 80 }
        check(teaGrams(store.recommendedGrams) == "4.1", "330 / 80 should round to 4.1 g")
        store.updateRecipe(for: .gardenia) { $0.waterPerGram = 110 }
        store.setWaterML(300)
        check(teaGrams(store.recommendedGrams) == "2.7", "Actual water volume should be used")
        store.setWaterML(331)
        check(store.validationMessage != nil, "Water must fit in cup")
        store.startNewRound()
        check(store.phase == .idle, "Invalid input must not start a timer")
        store.setWaterML(330)

        store.startNewRound()
        check(store.phase == .cooling && store.round?.startedInfusions == 0, "Cooling is not a consumed infusion")
        check(store.remainingSeconds == 120, "Gardenia cooling should be two minutes")
        store.setWaterML(300)
        store.updateRecipe(for: .gardenia) { $0.waterPerGram = 100 }
        check(store.round?.waterML == 330 && store.round?.grams == 3, "Round water and grams must be frozen")
        now = now.addingTimeInterval(120)
        store.tick()
        check(store.phase == .waitingForLeaves && store.reminder?.kind == .addLeaves, "Cooling should request confirmation")
        let reminderID = store.reminder?.id
        now = now.addingTimeInterval(240)
        store.tick()
        check(store.phase == .waitingForLeaves && store.reminder?.id == reminderID, "A missed reminder must persist without auto-brewing")
        store.confirmLeaves()
        check(store.phase == .brewing && store.remainingSeconds == 120, "The two-minute brew starts at actual confirmation time")
        check(store.round?.startedInfusions == 1, "Only actual brewing counts")
        now = now.addingTimeInterval(120)
        store.tick()
        check(store.phase == .ready && store.reminder?.kind == .teaReady, "Brew completion must remind")

        store.prepareRefill()
        check(store.phase == .preparingRefill && store.deadline == nil, "Refill waits until new water is ready")
        store.startRefill()
        check(store.phase == .cooling && store.plannedBrewSeconds == 150, "Second gardenia brew adds 30 seconds")
        check(store.round?.grams == 3 && store.round?.startedInfusions == 1, "Refill retains old leaves and does not count early")
        now = now.addingTimeInterval(120)
        store.tick()
        check(store.reminder?.infusion == 2, "Refill reminder must refer to infusion 2")
        store.confirmLeaves()
        check(store.round?.startedInfusions == 2 && store.remainingSeconds == 150, "Second brew uses incremented time")
        store.updateRecipe(for: .gardenia) { $0.firstBrewSeconds = 240 }
        check(store.remainingSeconds == 150, "Editing time cannot modify the running timer")
        store.endRound()
        check(store.phase == .idle && store.round == nil && store.reminder == nil, "Ending a round clears active work")
        store.startNewRound()
        check(store.round?.waterML == 300 && store.round?.waterPerGram == 100, "Next round applies new water and ratio")

        store.endRound()
        store.selectTea(.tieguanyin)
        store.startNewRound()
        check(store.phase == .brewing && store.remainingSeconds == 60, "Tieguanyin starts with the confirmed one-minute brew")
        now = now.addingTimeInterval(1000)
        store.tick()
        check(store.phase == .ready, "Waking after deadline completes the correct phase")
        store.prepareRefill()
        store.startRefill()
        check(store.remainingSeconds == 90, "Second Tieguanyin brew should add 30 seconds")

        let runningDeadline = store.deadline
        store.previewReminder()
        store.dismissReminder()
        check(store.deadline == runningDeadline && store.phase == .brewing, "Preview must not affect a real timer")
        let reloaded = TeaStore(defaults: defaults, now: { now })
        check(reloaded.preferences.selectedTea == .tieguanyin && reloaded.preferences.waterML == 300, "Water must reload independently of the selected tea")
        check(reloaded.phase == .idle, "Relaunch starts a fresh round")
        check(TeaKind.jasmine.defaultRecipe.brewSeconds(for: 3) == 240, "Jasmine third brew should be 4 minutes")

        // Old JSON has no revision field. Upgrade stock fields without erasing custom values.
        let legacy = Data(#"{"cupCapacityML":330,"waterML":300,"selectedTea":"jasmine","recipes":{"gardenia":{"coolingSeconds":120,"firstBrewSeconds":120,"incrementSeconds":30,"waterPerGram":110},"tieguanyin":{"coolingSeconds":0,"firstBrewSeconds":180,"incrementSeconds":60,"waterPerGram":110},"jasmine":{"coolingSeconds":90,"firstBrewSeconds":165,"incrementSeconds":45,"waterPerGram":90}}}"#.utf8)
        defaults.set(legacy, forKey: TeaStore.preferencesKey)
        let migrated = TeaStore(defaults: defaults, now: { now })
        check(migrated.preferences.recipe(for: .gardenia) == TeaKind.gardenia.defaultRecipe, "Saved v1 gardenia defaults should upgrade")
        check(migrated.preferences.recipe(for: .tieguanyin) == TeaKind.tieguanyin.defaultRecipe, "Saved v1 Tieguanyin defaults should upgrade")
        let customJasmine = migrated.configuration.recipe
        check(customJasmine.coolingSeconds == 90 && customJasmine.firstBrewSeconds == 165 && customJasmine.incrementSeconds == 45 && customJasmine.waterPerGram == 90, "Custom recipe fields must be preserved")
        check(migrated.preferences.waterML == 300 && migrated.preferences.selectedTea == .jasmine, "Migration must preserve water and selection")
        check(defaults.data(forKey: TeaStore.templateBackupKey) == legacy, "Original preferences should remain recoverable")
        check(migrated.preferences.templateRevision == TeaPreferences.currentTemplateRevision, "Migration should record completion")
        check(migrated.isCustomMode && migrated.customConfigurations.count == 1, "Legacy custom values must become a saved custom configuration")
        check(migrated.preferences.recipes.isEmpty, "Built-in templates must no longer contain overrides")
        check(defaults.data(forKey: TeaStore.customModeBackupKey) == legacy, "Pre-custom-mode preferences should remain recoverable")
        migrated.updateRecipe(for: .jasmine) { $0.waterPerGram = 110 }
        let reopened = TeaStore(defaults: defaults, now: { now })
        check(reopened.configuration.recipe.waterPerGram == 110, "A new custom value must not be overwritten on every launch")
        check(reopened.customConfigurations.count == 1, "Reopening must not duplicate migrated profiles")

        // Updating built-in recipes must preserve saved profiles, including the previous gardenia default.
        let previousProfiles = [
            TeaConfiguration(id: "previous-gardenia", name: "旧栀子", icon: .leaf, baseTea: .gardenia,
                             waterTemperatureC: 80,
                             recipe: TeaRecipe(coolingSeconds: 180, firstBrewSeconds: 180, incrementSeconds: 30, waterPerGram: 50)),
            TeaConfiguration(id: "previous-tieguanyin", name: "旧铁观音", icon: .cup, baseTea: .tieguanyin,
                             waterTemperatureC: 95,
                             recipe: TeaRecipe(coolingSeconds: 0, firstBrewSeconds: 150, incrementSeconds: 30, waterPerGram: 100)),
            TeaConfiguration(id: "previous-jasmine", name: "旧茉莉", icon: .flower, baseTea: .jasmine,
                             waterTemperatureC: 80,
                             recipe: TeaRecipe(coolingSeconds: 180, firstBrewSeconds: 120, incrementSeconds: 30, waterPerGram: 250.0 / 3.0))
        ]
        var previousPreferences = TeaPreferences()
        previousPreferences.cupCapacityML = 400
        previousPreferences.waterML = 300
        previousPreferences.selectedTea = .gardenia
        previousPreferences.templateRevision = 2
        previousPreferences.customConfigurations = previousProfiles
        var previousDraft = previousProfiles[0]
        previousDraft.name = "尚未保存的旧草稿"
        previousDraft.recipe.firstBrewSeconds = 135
        previousPreferences.customDraft = previousDraft
        previousPreferences.usesCustomMode = true
        let previousData = try JSONEncoder().encode(previousPreferences)
        defaults.set(previousData, forKey: TeaStore.preferencesKey)
        let updatedTemplates = TeaStore(defaults: defaults, now: { now })
        check(updatedTemplates.customConfigurations == previousProfiles,
              "A template update must preserve every saved configuration, including old default values")
        check(updatedTemplates.configuration == previousDraft && updatedTemplates.hasUnsavedChanges,
              "A template update must retain the selected unsaved draft")
        check(updatedTemplates.preferences.cupCapacityML == 400 && updatedTemplates.preferences.waterML == 300,
              "A template update must not reset shared cup or water settings")
        check(defaults.data(forKey: TeaStore.preferencesKey) == previousData,
              "Loading current preferences must not rewrite or migrate existing custom data")
        updatedTemplates.selectTea(.gardenia)
        let updatedReload = TeaStore(defaults: defaults, now: { now })
        check(!updatedReload.isCustomMode && updatedReload.configuration.waterTemperatureC == 80
              && updatedReload.recipe.coolingSeconds == 120 && updatedReload.recipe.firstBrewSeconds == 120
              && updatedReload.recipe.incrementSeconds == 30 && updatedReload.recipe.waterPerGram == 165,
              "Selecting a built-in template must use the new recipe after relaunch")
        check(updatedReload.customConfigurations == previousProfiles && updatedReload.preferences.customDraft == previousDraft,
              "Selecting the updated template must retain all saved profiles and the recent draft")

        let customSuite = "local.teapanel.custom-tests.\(UUID().uuidString)"
        let customDefaults = UserDefaults(suiteName: customSuite)!
        defer { customDefaults.removePersistentDomain(forName: customSuite) }
        let custom = TeaStore(defaults: customDefaults, now: { now })
        custom.setWaterML(330)
        check(!custom.isCustomMode, "Committing an unchanged value must not enter custom mode")
        custom.setWaterML(300)
        custom.setCapacity(400)
        custom.setStartingInfusion(3)
        check(!custom.isCustomMode && !custom.hasUnsavedChanges, "Water, cup and infusion must not create a custom profile")
        custom.selectTea(.jasmine)
        check(custom.preferences.waterML == 300 && custom.preferences.cupCapacityML == 400 && custom.displayedInfusion == 3,
              "Template selection must retain cup, water and the selected infusion")
        let brewReload = TeaStore(defaults: customDefaults, now: { now })
        check(brewReload.preferences.waterML == 300 && brewReload.preferences.cupCapacityML == 400,
              "Shared cup and water settings must persist")
        check(brewReload.displayedInfusion == 1, "Infusion belongs to this session and must not persist in a profile")
        custom.setStartingInfusion(1)
        let parameterEdits: [@MainActor (TeaStore) -> Void] = [
            { $0.setTemperature(85) },
            { $0.updateRecipe(for: .gardenia) { $0.coolingSeconds = 150 } },
            { $0.updateRecipe(for: .gardenia) { $0.firstBrewSeconds = 150 } },
            { $0.updateRecipe(for: .gardenia) { $0.incrementSeconds = 45 } },
            { $0.updateRecipe(for: .gardenia) { $0.waterPerGram = 80 } },
            { $0.setConfigurationName("工作茶") },
            { $0.setConfigurationIcon(.moon) }
        ]
        for edit in parameterEdits {
            custom.selectTea(.gardenia)
            edit(custom)
            check(custom.isCustomMode && custom.hasUnsavedChanges, "Every changed parameter must detach into a custom draft")
            custom.selectTea(.gardenia)
            check(custom.configuration == TeaConfiguration.template(for: .gardenia), "Editing must leave the built-in template intact")
        }
        custom.enterCustomMode()
        custom.setConfigurationName("   ")
        check(!custom.saveConfiguration() && custom.customConfigurations.isEmpty, "An empty name must not use a save slot")
        custom.setConfigurationName("  办公花茶  ")
        custom.setConfigurationIcon(.heart)
        custom.setWaterML(300)
        check(custom.saveConfiguration(), "A custom profile should save")
        let firstID = custom.configuration.id
        check(custom.configuration.name == "办公花茶" && custom.configuration.icon == .heart, "Name and icon must be retained")
        check(custom.customConfigurations.count == 1 && !custom.hasUnsavedChanges, "Saving should create exactly one clean profile")
        let savedProfile = custom.configuration
        custom.setWaterML(250)
        custom.setCapacity(500)
        custom.setStartingInfusion(2)
        check(custom.configuration == savedProfile && !custom.hasUnsavedChanges, "Shared settings must not dirty a saved profile")
        custom.selectTea(.jasmine)
        custom.selectCustomConfiguration(id: firstID)
        check(custom.preferences.waterML == 250 && custom.preferences.cupCapacityML == 500 && custom.displayedInfusion == 2,
              "Loading a saved profile must not replace water, cup or infusion")
        custom.setStartingInfusion(1)
        custom.updateRecipe(for: .gardenia) { $0.firstBrewSeconds = 90 }
        check(custom.hasUnsavedChanges && custom.savedConfiguration?.recipe.firstBrewSeconds == 120, "Editing a saved profile must not overwrite it until save")
        check(custom.saveConfiguration() && custom.configuration.id == firstID && custom.customConfigurations.count == 1, "Update must reuse a save slot")
        custom.setConfigurationName("下午茶")
        check(custom.saveConfiguration(asNew: true), "Save-as should create another profile")
        check(custom.configuration.id != firstID && custom.customConfigurations.count == 2, "Save-as must have a distinct ID")
        check(custom.customConfigurations.first(where: { $0.id == firstID })?.name == "办公花茶", "Save-as must preserve the original profile")
        for index in 3...10 {
            custom.selectTea(.jasmine)
            custom.setConfigurationName("配方 \(index)")
            check(custom.saveConfiguration(), "Profiles up to the limit must save")
        }
        let fullList = custom.customConfigurations
        custom.selectTea(.tieguanyin)
        custom.setConfigurationName("第十一条")
        check(!custom.saveConfiguration() && custom.customConfigurations == fullList, "The eleventh profile must not overwrite an existing profile")
        custom.selectCustomConfiguration(id: firstID)
        custom.setConfigurationName("改名后的工作茶")
        check(custom.saveConfiguration() && custom.customConfigurations.count == 10, "Updating must still work at the limit")
        check(!custom.saveConfiguration(asNew: true) && custom.customConfigurations.count == 10, "Save-as must honor the ten-profile limit")
        let deletedRecipe = custom.configuration.recipe
        custom.deleteSelectedConfiguration()
        check(custom.customConfigurations.count == 9 && custom.hasUnsavedChanges, "Deleting a profile must free a slot and keep a recoverable draft")
        check(custom.configuration.recipe == deletedRecipe, "Deleting a saved entry must retain the working parameters")
        check(custom.saveConfiguration() && custom.customConfigurations.count == 10, "A retained draft can be saved again after deletion")
        custom.setConfigurationName("还没保存的草稿")
        let draftReload = TeaStore(defaults: customDefaults, now: { now })
        check(draftReload.customConfigurations == custom.customConfigurations, "All saved profiles must persist")
        check(draftReload.isCustomMode && draftReload.configuration.name == "还没保存的草稿" && draftReload.hasUnsavedChanges, "Unsaved draft and mode must persist independently")

        custom.setConfigurationName("提醒测试茶")
        custom.setConfigurationIcon(.moon)
        custom.updateRecipe(for: .gardenia) { $0.coolingSeconds = 0; $0.firstBrewSeconds = 60 }
        custom.startNewRound()
        check(custom.phase == .brewing && custom.displaySymbol == TeaIcon.moon.rawValue, "Custom recipes and icons must be used by actual brewing")
        let frozenConfiguration = custom.round?.configuration
        custom.setConfigurationName("下一轮的名字")
        custom.setConfigurationIcon(.sun)
        custom.selectTea(.jasmine)
        check(custom.round?.configuration == frozenConfiguration && custom.configuration.baseTea == .gardenia, "Round identity must remain frozen and selection locked while active")
        now = now.addingTimeInterval(61)
        custom.tick()
        check(custom.reminder?.name == "提醒测试茶" && custom.reminder?.symbol == TeaIcon.moon.rawValue, "Real reminders must use the round's saved name and icon")
        let realReminderID = custom.reminder?.id
        custom.previewReminder()
        check(custom.reminder?.id == realReminderID, "A preview must not replace a pending real reminder")
        custom.endRound()
        custom.startNewRound()
        check(custom.displayName == "下一轮的名字" && custom.displaySymbol == TeaIcon.sun.rawValue, "The next round should pick up edited identity")

        // Joining at an existing infusion must use its time and continue numbering correctly.
        let infusionSuite = "local.teapanel.infusion-tests.\(UUID().uuidString)"
        let infusionDefaults = UserDefaults(suiteName: infusionSuite)!
        defer { infusionDefaults.removePersistentDomain(forName: infusionSuite) }
        let joining = TeaStore(defaults: infusionDefaults, now: { now })
        joining.setWaterML(300)
        for tea in TeaKind.allCases {
            for infusion in [2, 3] {
                joining.selectTea(tea)
                joining.setStartingInfusion(infusion)
                let expected = tea.defaultRecipe.brewSeconds(for: infusion)
                check(joining.currentBrewSeconds == expected, "Preview must reflect the chosen tea and infusion")
                joining.startNewRound()
                check(joining.displayedInfusion == infusion && joining.plannedBrewSeconds == expected,
                      "Joining must begin at the selected infusion")
                if tea.defaultRecipe.coolingSeconds > 0 {
                    now = now.addingTimeInterval(Double(tea.defaultRecipe.coolingSeconds))
                    joining.tick()
                    check(joining.reminder?.kind == .addLeaves && joining.reminder?.infusion == infusion,
                          "Cooling reminder must refer to the selected infusion and existing leaves")
                    joining.confirmLeaves()
                }
                check(joining.phase == .brewing && joining.remainingSeconds == expected && joining.round?.startedInfusions == infusion,
                      "Actual brewing must use the selected infusion's duration")
                joining.setStartingInfusion(1)
                check(joining.displayedInfusion == infusion, "Changing the selector cannot alter a running infusion")
                now = now.addingTimeInterval(Double(expected))
                joining.tick()
                check(joining.reminder?.kind == .teaReady && joining.reminder?.infusion == infusion,
                      "Finished reminder must preserve the selected infusion")
                joining.prepareRefill()
                check(joining.displayedInfusion == infusion + 1 && joining.currentBrewSeconds == expected + tea.defaultRecipe.incrementSeconds,
                      "Refill must continue from the selected infusion")
                joining.startRefill()
                check(joining.plannedBrewSeconds == expected + tea.defaultRecipe.incrementSeconds,
                      "Next pour must apply the next infusion's time")
                joining.endRound()
                check(joining.displayedInfusion == 1 && joining.preferences.waterML == 300,
                      "New leaves reset infusion while retaining shared water")
            }
        }
        joining.setStartingInfusion(0)
        check(joining.displayedInfusion == 1, "Infusion cannot be below one")
        joining.setStartingInfusion(100)
        check(joining.displayedInfusion == 99, "Infusion must remain within the selector's range")

        // Skipping cooling starts this infusion once, from now, without editing the recipe.
        let skipSuite = "local.teapanel.skip-tests.\(UUID().uuidString)"
        let skipDefaults = UserDefaults(suiteName: skipSuite)!
        defer { skipDefaults.removePersistentDomain(forName: skipSuite) }
        let skipping = TeaStore(defaults: skipDefaults, now: { now })
        let originalRecipe = skipping.recipe
        check(skipping.canSkipCooling, "Flower tea must offer a direct brewing action before starting")
        skipping.skipCooling()
        check(skipping.phase == .brewing && skipping.remainingSeconds == 120 && skipping.displayedInfusion == 1,
              "Direct start must skip cooling and leaf confirmation for the first infusion")
        check(skipping.round?.startedInfusions == 1 && skipping.reminder == nil && skipping.statusText == "泡 02:00",
              "Direct start must count one infusion and show the brewing timer")
        check(skipping.recipe == originalRecipe && !skipping.isCustomMode,
              "Skipping this pour must not edit a built-in recipe or enter custom mode")
        let directDeadline = skipping.deadline
        now = now.addingTimeInterval(20)
        skipping.skipCooling()
        check(skipping.deadline == directDeadline && skipping.round?.startedInfusions == 1 && !skipping.canSkipCooling,
              "Repeated direct-start actions must not reset or double count an active brew")
        now = now.addingTimeInterval(100)
        skipping.tick()
        check(skipping.phase == .ready && skipping.reminder?.kind == .teaReady && skipping.reminder?.infusion == 1,
              "A skipped cooling stage must lead directly to the correct tea-ready reminder")
        let directReminderID = skipping.reminder?.id
        skipping.skipCooling()
        check(skipping.phase == .ready && skipping.reminder?.id == directReminderID && !skipping.canSkipCooling,
              "Skipping must not start another infusion from a finished cup")
        let originalGrams = skipping.round?.grams
        skipping.prepareRefill()
        check(skipping.canSkipCooling && skipping.displayedInfusion == 2, "Preparing a refill must offer skipping for the next infusion")
        skipping.skipCooling()
        check(skipping.phase == .brewing && skipping.remainingSeconds == 150 && skipping.displayedInfusion == 2,
              "A direct refill must use the second infusion's increased time")
        check(skipping.round?.grams == originalGrams && skipping.round?.startedInfusions == 2 && skipping.reminder == nil,
              "Direct refill must keep the existing leaves and clear the previous reminder")
        skipping.endRound()
        skipping.selectTea(.jasmine)
        skipping.setStartingInfusion(3)
        skipping.skipCooling()
        check(skipping.phase == .brewing && skipping.remainingSeconds == 240 && skipping.displayedInfusion == 3,
              "Direct start must honor a manually selected third infusion")
        skipping.endRound()
        skipping.selectTea(.gardenia)
        skipping.setStartingInfusion(2)
        skipping.startNewRound()
        check(skipping.phase == .cooling && skipping.canSkipCooling && skipping.round?.startedInfusions == 1,
              "An active cooling stage must offer skipping without counting the infusion early")
        now = now.addingTimeInterval(45)
        skipping.tick()
        skipping.previewReminder()
        skipping.updateRecipe(for: .gardenia) { $0.firstBrewSeconds = 240 }
        let editedConfiguration = skipping.configuration
        skipping.skipCooling()
        check(skipping.phase == .brewing && skipping.remainingSeconds == 150 && skipping.phaseDuration == 150,
              "Skipping mid-cooling must use the planned full brew time, not subtract cooling or apply later edits")
        check(skipping.displayedInfusion == 2 && skipping.round?.startedInfusions == 2 && skipping.reminder == nil,
              "Skipping mid-cooling must preserve infusion numbering and dismiss an open preview")
        check(skipping.configuration == editedConfiguration && skipping.recipe.coolingSeconds == 120,
              "Skipping must not change custom parameters or disable cooling on future pours")
        now = now.addingTimeInterval(150)
        skipping.tick()
        check(skipping.phase == .ready && skipping.reminder?.infusion == 2 && skipping.reminder?.kind == .teaReady,
              "Mid-cooling skip must retain the correct final reminder")
        skipping.prepareRefill()
        skipping.startRefill()
        check(skipping.phase == .cooling && skipping.remainingSeconds == 120 && skipping.displayedInfusion == 3,
              "The next normal pour must still cool according to its recipe")
        skipping.endRound()
        skipping.setWaterML(500)
        skipping.skipCooling()
        check(skipping.phase == .idle && skipping.round == nil, "Skipping must not bypass initial water validation")
        skipping.setWaterML(330)
        skipping.selectTea(.tieguanyin)
        check(!skipping.canSkipCooling, "A recipe without cooling must not show a redundant skip action")

        // Migrate current custom water out of old saved profiles without losing profiles or drafts.
        let profileLegacy = Data(#"{"cupCapacityML":330,"waterML":330,"selectedTea":"jasmine","recipes":{},"templateRevision":2,"customModeRevision":1,"usesCustomMode":true,"customConfigurations":[{"id":"legacy-profile","name":"工作茶","icon":"moon.fill","baseTea":"jasmine","cupCapacityML":400,"waterML":300,"waterTemperatureC":80,"recipe":{"coolingSeconds":180,"firstBrewSeconds":120,"incrementSeconds":45,"waterPerGram":90}}],"customDraft":{"id":"legacy-profile","name":"旧草稿","icon":"moon.fill","baseTea":"jasmine","cupCapacityML":360,"waterML":280,"waterTemperatureC":80,"recipe":{"coolingSeconds":180,"firstBrewSeconds":150,"incrementSeconds":45,"waterPerGram":90}}}"#.utf8)
        infusionDefaults.set(profileLegacy, forKey: TeaStore.preferencesKey)
        let split = TeaStore(defaults: infusionDefaults, now: { now })
        check(split.preferences.cupCapacityML == 360 && split.preferences.waterML == 280,
              "Migration must retain the active custom draft's water, rather than stale global or saved values")
        check(split.customConfigurations.count == 1 && split.customConfigurations[0].id == "legacy-profile" && split.hasUnsavedChanges,
              "Migration must retain profile identity and unsaved draft state")
        check(split.configuration.name == "旧草稿" && split.recipe.firstBrewSeconds == 150 && split.configuration.icon == .moon,
              "Migration must preserve recipe, name and icon")
        check(infusionDefaults.data(forKey: TeaStore.independentBrewBackupKey) == profileLegacy,
              "The pre-split preferences must remain recoverable")
        let splitData = infusionDefaults.data(forKey: TeaStore.preferencesKey)!
        let splitJSON = try JSONSerialization.jsonObject(with: splitData) as! [String: Any]
        let profilesJSON = splitJSON["customConfigurations"] as! [[String: Any]]
        let draftJSON = splitJSON["customDraft"] as! [String: Any]
        check(profilesJSON.allSatisfy { $0["waterML"] == nil && $0["cupCapacityML"] == nil }
              && draftJSON["waterML"] == nil && draftJSON["cupCapacityML"] == nil,
              "Persisted profiles and drafts must no longer contain water or cup settings")
        split.setWaterML(250)
        split.selectCustomConfiguration(id: "legacy-profile")
        check(split.preferences.waterML == 250 && !split.hasUnsavedChanges,
              "A migrated profile must use current shared water without carrying its legacy water back")
        let splitReload = TeaStore(defaults: infusionDefaults, now: { now })
        check(splitReload.preferences.waterML == 250 && splitReload.customConfigurations.count == 1,
              "Relaunch must not repeat migration or overwrite the new shared water")
        splitReload.setWaterML(500)
        splitReload.setConfigurationName("配置独立保存")
        check(splitReload.validationMessage != nil && splitReload.saveConfiguration(),
              "Invalid current water must block brewing, not saving an otherwise valid tea profile")
        check(infusionDefaults.data(forKey: TeaStore.independentBrewBackupKey) == profileLegacy,
              "Later saves must not overwrite the original migration backup")

        let waterOnlyLegacy = Data(#"{"cupCapacityML":500,"waterML":450,"selectedTea":"gardenia","recipes":{},"templateRevision":2}"#.utf8)
        infusionDefaults.set(waterOnlyLegacy, forKey: TeaStore.preferencesKey)
        let waterOnly = TeaStore(defaults: infusionDefaults, now: { now })
        check(waterOnly.preferences.cupCapacityML == 500 && waterOnly.preferences.waterML == 450,
              "Pre-custom-mode shared water must be retained")
        check(!waterOnly.isCustomMode && waterOnly.customConfigurations.isEmpty,
              "Legacy cup-only changes must not consume a tea configuration slot")
        print("通过 \(checks) 项核心计时与投茶量检查")
    }
}
