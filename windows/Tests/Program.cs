using TeaPanel;

int checks = 0;
void Check(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
    checks++;
}

DateTimeOffset now = DateTimeOffset.FromUnixTimeSeconds(1_800_000_000);
TeaStore Fresh(TeaPreferences? preferences = null) => new(preferences, () => now);
var store = Fresh();
foreach (var (tea, temperature, cooling, first, grams330, grams200) in new[]
{
    (TeaKind.Gardenia, 80, 120, 120, "2.0", "1.2"),
    (TeaKind.Tieguanyin, 100, 0, 60, "8.3", "5.0"),
    (TeaKind.Jasmine, 85, 120, 180, "6.6", "4.0")
})
{
    store.SelectTea(tea);
    store.WaterML = 330;
    Check(TeaText.Grams(store.RecommendedGrams) == grams330, "330 mL dose: " + tea);
    Check(store.WaterTemperatureC == temperature && store.CoolingSeconds == cooling, "Preset temperature/cooling: " + tea);
    Check(Enumerable.Range(1, 4).Select(store.Recipe.BrewSeconds).SequenceEqual(new[] { first, first + 30, first + 60, first + 90 }), "First four infusions: " + tea);
    store.WaterML = 200;
    Check(TeaText.Grams(store.RecommendedGrams) == grams200, "200 mL dose: " + tea);
}
Check(TeaText.Grams(8.25) == "8.3", "Midpoints round away from zero");
Check(TeaText.Clock(60600) == "1010:00" && TeaText.Clock(-1) == "00:00", "Long and nonnegative clocks");

store = Fresh();
store.WaterPerGram = 110;
Check(store.IsCustomMode && TeaText.Grams(store.RecommendedGrams) == "3.0", "Ratio detaches custom mode and changes dose");
store.WaterML = 331;
store.StartNewRound();
Check(store.Phase == TeaPhase.Idle && store.ValidationMessage is not null, "Over-capacity water blocks start");
store.WaterML = 330;
store.StartNewRound();
Check(store.Phase == TeaPhase.Cooling && store.Round?.StartedInfusions == 0 && store.RemainingSeconds == 120, "Cooling does not consume an infusion");
store.StartNewRound();
Check(store.Round?.StartedInfusions == 0, "A repeated start cannot replace the round");
store.WaterML = 300;
store.WaterPerGram = 100;
store.ConfigurationName = "下一轮的茶";
store.SetIcon(TeaIcon.Moon);
Check(store.Round?.WaterML == 330 && store.Round.Grams == 3 && store.DisplayIcon == TeaIcon.Leaf, "Round retains dose, water and icon");
now = now.AddSeconds(120);
store.Tick();
Check(store.Phase == TeaPhase.WaitingForLeaves && store.Reminder?.Kind == ReminderKind.AddLeaves, "Cooling asks for leaves");
var reminderId = store.Reminder!.Id;
store.PreviewReminder();
now = now.AddSeconds(900);
store.Tick();
Check(store.Phase == TeaPhase.WaitingForLeaves && store.Reminder?.Id == reminderId, "Real reminder persists and preview cannot replace it");
Check(store.Reminder?.Configuration.Name != "下一轮的茶" && store.Reminder?.Grams == 3, "Reminder uses this round's identity and dose");
store.ConfirmLeaves();
var deadline = store.Deadline;
store.ConfirmLeaves();
Check(store.Phase == TeaPhase.Brewing && store.RemainingSeconds == 120 && store.Round?.StartedInfusions == 1 && store.Deadline == deadline, "Only actual confirmation starts one full brew");
store.FirstBrewSeconds = 240;
Check(store.RemainingSeconds == 120, "Editing duration does not alter current timer");
now = now.AddSeconds(120);
store.Tick();
Check(store.Phase == TeaPhase.Ready && store.Reminder?.Kind == ReminderKind.TeaReady, "Brew completion reminds");
store.SkipCooling();
Check(store.Phase == TeaPhase.Ready && store.Round?.StartedInfusions == 1, "Skipping after completion is a no-op");
store.DismissReminder();
Check(store.Phase == TeaPhase.Ready && store.Reminder is null, "Acknowledgment retains the finished round");
store.PrepareRefill();
Check(store.Phase == TeaPhase.PreparingRefill && store.Deadline is null, "Refill waits for fresh water");
store.StartRefill();
Check(store.Phase == TeaPhase.Cooling && store.PlannedBrewSeconds == 270 && store.Round?.Grams == 3, "Next infusion applies time edits and keeps leaves");
now = now.AddSeconds(120);
store.Tick();
Check(store.Reminder?.Infusion == 2 && store.Reminder.Grams == 3, "Refill reminder has correct infusion/dose");
store.ConfirmLeaves();
Check(store.RemainingSeconds == 270 && store.DisplayedInfusion == 2, "Refill duration is correct");
store.EndRound();
Check(store.Round is null && store.Reminder is null && store.Deadline is null && store.StartingInfusion == 1, "Ending clears transient state");
store.StartNewRound(true);
Check(store.Round?.WaterML == 300 && store.Round.Grams == 3 && store.DisplayName == "下一轮的茶", "Next round applies identity and water changes");

var skipping = Fresh();
skipping.SetStartingInfusion(3);
skipping.SkipCooling();
Check(skipping.Phase == TeaPhase.Brewing && skipping.RemainingSeconds == 180 && skipping.DisplayedInfusion == 3, "Direct start honors chosen infusion");
deadline = skipping.Deadline;
skipping.SkipCooling();
Check(skipping.Deadline == deadline && skipping.Round?.StartedInfusions == 3, "Repeated skip cannot restart brewing");
skipping.EndRound();
skipping.SetStartingInfusion(2);
skipping.StartNewRound();
now = now.AddSeconds(45);
skipping.Tick();
skipping.FirstBrewSeconds = 240;
skipping.PreviewReminder();
skipping.SkipCooling();
Check(skipping.Phase == TeaPhase.Brewing && skipping.RemainingSeconds == 150 && skipping.DisplayedInfusion == 2, "Mid-cooling skip preserves the originally planned full duration");
Check(skipping.Reminder is null && skipping.CoolingSeconds == 120, "Skipping clears preview without changing future cooling");
now = now.AddSeconds(150);
skipping.Tick();
skipping.PrepareRefill();
skipping.SkipCooling();
Check(skipping.Phase == TeaPhase.Brewing && skipping.RemainingSeconds == 300 && skipping.DisplayedInfusion == 3, "Direct refill applies future duration edit");

var noCooling = Fresh();
noCooling.SelectTea(TeaKind.Tieguanyin);
Check(!noCooling.CanSkipCooling, "Zero-cooling preset has no redundant skip action");
noCooling.StartNewRound();
Check(noCooling.Phase == TeaPhase.Brewing && noCooling.RemainingSeconds == 60, "Tieguanyin starts directly");
noCooling.PreviewReminder();
Check(noCooling.Reminder?.IsPreview == true && noCooling.Phase == TeaPhase.Brewing, "Preview leaves real timer running");
now = now.AddSeconds(3600);
noCooling.Tick();
Check(noCooling.Phase == TeaPhase.Ready && noCooling.Reminder?.IsPreview == false, "Expired real timer replaces preview after a long clock jump");
noCooling.PrepareRefill();
noCooling.StartRefill();
Check(noCooling.RemainingSeconds == 90 && noCooling.DisplayedInfusion == 2, "Tieguanyin refill increments duration");

var custom = Fresh();
custom.WaterML = 330;
custom.WaterTemperatureC = 80;
Check(!custom.IsCustomMode, "Unchanged values do not create a draft");
custom.CupCapacityML = 400;
custom.WaterML = 300;
custom.SetStartingInfusion(3);
custom.SelectTea(TeaKind.Jasmine);
Check(!custom.IsCustomMode && custom.WaterML == 300 && custom.CupCapacityML == 400 && custom.DisplayedInfusion == 3, "Cup, water and infusion remain independent of templates");
custom.EnterCustomMode();
custom.ConfigurationName = "  ";
Check(!custom.SaveConfiguration() && custom.CustomConfigurations.Length == 0, "Blank name cannot use a slot");
custom.ConfigurationName = "  办公花茶  ";
custom.SetIcon(TeaIcon.Heart);
Check(custom.SaveConfiguration() && custom.ConfigurationName == "办公花茶" && !custom.HasUnsavedChanges, "Save trims name and retains icon");
string firstId = custom.Configuration.Id;
custom.FirstBrewSeconds = 90;
Check(custom.HasUnsavedChanges && custom.SavedConfiguration?.Recipe.FirstBrewSeconds == 180, "Editing saved draft does not overwrite saved entry");
Check(custom.SaveConfiguration() && custom.Configuration.Id == firstId && custom.CustomConfigurations.Length == 1, "Update reuses slot and identity");
custom.ConfigurationName = "下午茶";
Check(custom.SaveConfiguration(true) && custom.Configuration.Id != firstId && custom.CustomConfigurations.Length == 2, "Save-as creates a distinct entry");
Check(custom.CustomConfigurations.Single(c => c.Id == firstId).Name == "办公花茶", "Save-as preserves original");
for (int i = 3; i <= 10; i++)
{
    custom.SelectTea(TeaKind.Jasmine);
    custom.ConfigurationName = "配方 " + i;
    Check(custom.SaveConfiguration(), "Save within capacity " + i);
}
custom.SelectTea(TeaKind.Tieguanyin);
custom.ConfigurationName = "第十一条";
Check(!custom.SaveConfiguration() && custom.CustomConfigurations.Length == 10, "Eleventh entry cannot replace another profile");
custom.SelectCustomConfiguration(firstId);
custom.ConfigurationName = "改名后的工作茶";
Check(custom.SaveConfiguration() && !custom.SaveConfiguration(true) && custom.CustomConfigurations.Length == 10, "At capacity, update works and save-as does not");
var retainedRecipe = custom.Recipe;
custom.DeleteSelectedConfiguration();
Check(custom.CustomConfigurations.Length == 9 && custom.HasUnsavedChanges && custom.Recipe == retainedRecipe, "Delete retains recoverable draft");
Check(custom.SaveConfiguration() && custom.CustomConfigurations.Length == 10, "Deleted draft can be saved again");
custom.ConfigurationName = "未保存草稿";
var reloaded = Fresh(custom.Preferences);
Check(reloaded.IsCustomMode && reloaded.ConfigurationName == "未保存草稿" && reloaded.HasUnsavedChanges, "Draft and saved entries are independent");
Check(reloaded.WaterML == 300 && reloaded.CupCapacityML == 400 && reloaded.StartingInfusion == 1, "Reload retains shared settings but not infusion");
custom.StartNewRound(true);
var activeConfiguration = custom.Configuration;
custom.SelectTea(TeaKind.Gardenia);
custom.SelectCustomConfiguration(firstId);
custom.DeleteSelectedConfiguration();
custom.SetStartingInfusion(8);
Check(custom.Configuration == activeConfiguration && custom.CustomConfigurations.Length == 10 && custom.DisplayedInfusion == 3, "Active round blocks switching, deletion and infusion edits");
Check(Fresh(custom.Preferences).Phase == TeaPhase.Idle, "Relaunch never resumes an active timer");

var limits = Fresh();
limits.SetStartingInfusion(0);
Check(limits.StartingInfusion == 1, "Starting infusion clamps low");
limits.SetStartingInfusion(200);
Check(limits.StartingInfusion == 99, "Starting infusion clamps high");
limits.FirstBrewSeconds = 1800;
limits.IncrementSeconds = 600;
limits.SkipCooling();
Check(limits.RemainingSeconds == 60600, "Maximum UI durations at infusion 99 remain valid");
foreach (double value in new[] { 0, -1, double.NaN, double.PositiveInfinity })
{
    var invalid = Fresh();
    invalid.WaterML = value;
    invalid.SkipCooling();
    Check(invalid.Phase == TeaPhase.Idle && invalid.ValidationMessage is not null, "Invalid water cannot start: " + value);
    invalid = Fresh();
    invalid.WaterPerGram = value;
    invalid.StartNewRound();
    Check(invalid.Phase == TeaPhase.Idle && invalid.ValidationMessage is not null, "Invalid ratio cannot start: " + value);
}
var invalidWater = Fresh();
invalidWater.ConfigurationName = "配置独立保存";
invalidWater.WaterML = 500;
Check(invalidWater.SaveConfiguration() && invalidWater.ValidationMessage is not null, "Invalid water does not prevent saving valid tea configuration");
invalidWater.CupCapacityML = 250;
Check(invalidWater.WaterML == 250, "Reducing cup capacity also caps water");

string testRoot = Path.GetFullPath(Environment.GetEnvironmentVariable("TEA_PANEL_TEST_ROOT")
    ?? Path.Combine(Path.GetTempPath(), "TeaPanel.Tests"));
string directory = Path.GetFullPath(Path.Combine(testRoot, Guid.NewGuid().ToString("N")));
Directory.CreateDirectory(directory);
try
{
    var storage = new PreferenceStorage(directory);
    Check(storage.Load() == new TeaPreferences() || storage.Load().WaterML == 330, "Missing file uses defaults");
    storage.Save(custom.Preferences);
    var loaded = storage.Load();
    Check(loaded.CustomConfigurations.SequenceEqual(custom.CustomConfigurations)
        && loaded.CustomDraft == custom.Preferences.CustomDraft && loaded.WaterML == custom.WaterML, "JSON round-trip preserves all configs and unsaved draft");
    Check(!Directory.GetFiles(directory, "*.tmp").Any(), "Successful save leaves no temporary file");
    string original = File.ReadAllText(storage.FilePath);
    using (var locked = new FileStream(storage.FilePath, FileMode.Open, FileAccess.Read, FileShare.None))
    {
        var failing = new TeaStore(loaded, () => now, storage.Save);
        failing.WaterML = 123;
        Check(failing.WaterML == 123 && failing.StorageMessage is not null, "Save failure retains in-memory edit and reports error");
    }
    Check(File.ReadAllText(storage.FilePath) == original, "Save failure preserves previous file");
    var nonfinite = new TeaStore(loaded, () => now, storage.Save);
    nonfinite.WaterML = double.NaN;
    Check(nonfinite.StorageMessage is not null && File.ReadAllText(storage.FilePath) == original, "Nonfinite serialization leaves previous file intact");
    nonfinite.WaterML = 200;
    Check(nonfinite.StorageMessage is null && storage.Load().WaterML == 200, "Later successful edit clears save error");
    File.WriteAllText(storage.FilePath, "{broken JSON");
    storage = new PreferenceStorage(directory);
    Check(storage.Load().WaterML == 330 && storage.LoadMessage is not null, "Corrupt file falls back with message");
    Check(Directory.GetFiles(directory, "*.bak").Select(File.ReadAllText).Contains("{broken JSON"), "Corrupt original is preserved verbatim");
    storage.Save(new());
    File.WriteAllText(storage.FilePath, "{\"schemaVersion\":99,\"waterML\":123}");
    storage = new PreferenceStorage(directory);
    Check(storage.Load().WaterML == 330 && storage.LoadMessage is not null, "Unknown schema remains separate from current defaults");
    bool rejected = false;
    try { storage.Save(new()); } catch (IOException) { rejected = true; }
    Check(rejected && File.ReadAllText(storage.FilePath).Contains("99"), "Unknown schema cannot be overwritten by downgrade");
    File.WriteAllText(storage.FilePath, "{\"customConfigurations\":[{\"id\":\"x\",\"name\":null}]}");
    storage = new PreferenceStorage(directory);
    Check(storage.Load().CustomConfigurations.Length == 0 && storage.LoadMessage is not null, "Incomplete config data cannot crash startup");
}
finally
{
    // The directory is a freshly generated child of the explicit test root.
    string relative = Path.GetRelativePath(testRoot, directory);
    if (relative.Length == 0 || relative == "." || relative.StartsWith("..", StringComparison.Ordinal)
        || Path.IsPathRooted(relative)) throw new InvalidOperationException("Test cleanup escaped its root");
    Directory.Delete(directory, recursive: true);
}

Console.WriteLine($"Passed {checks} Windows core and preference checks.");
