using System;
using System.ComponentModel;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text.Json;

namespace TeaPanel;

public enum TeaKind { Gardenia, Tieguanyin, Jasmine }
public enum TeaIcon { Leaf, Flower, Cup, Mug, Drop, Sun, Moon, Star, Flame, Heart }
public enum TeaPhase { Idle, Cooling, WaitingForLeaves, Brewing, Ready, PreparingRefill }
public enum ReminderKind { AddLeaves, TeaReady }

public sealed record TeaRecipe(int CoolingSeconds, int FirstBrewSeconds, int IncrementSeconds, double WaterPerGram)
{
    public int BrewSeconds(int infusion) => FirstBrewSeconds + Math.Max(0, infusion - 1) * IncrementSeconds;
}

public sealed record TeaConfiguration(string Id, string Name, TeaIcon Icon, TeaKind BaseTea,
    int WaterTemperatureC, TeaRecipe Recipe)
{
    public TeaConfiguration CustomCopy() => this with { Id = Guid.NewGuid().ToString(), Name = Name + " · 自定义" };
}

public static class TeaPresets
{
    public static string Detail(TeaKind tea) => tea switch
    {
        TeaKind.Gardenia => "栀子 + 绿茶",
        TeaKind.Tieguanyin => "乌龙茶",
        _ => "茉莉 + 绿茶"
    };

    public static string Name(TeaKind tea) => tea switch
    {
        TeaKind.Gardenia => "栀子花茶",
        TeaKind.Tieguanyin => "铁观音",
        _ => "茉莉花茶"
    };

    public static TeaConfiguration Get(TeaKind tea) => tea switch
    {
        TeaKind.Gardenia => new("gardenia", Name(tea), TeaIcon.Leaf, tea, 80, new(180, 180, 30, 50)),
        TeaKind.Tieguanyin => new("tieguanyin", Name(tea), TeaIcon.Cup, tea, 100, new(0, 60, 30, 40)),
        _ => new("jasmine", Name(tea), TeaIcon.Flower, tea, 85, new(120, 180, 30, 50))
    };
}

public sealed record TeaPreferences
{
    public int SchemaVersion { get; init; } = 1;
    public double CupCapacityML { get; init; } = 330;
    public double WaterML { get; init; } = 330;
    public TeaKind SelectedTea { get; init; } = TeaKind.Gardenia;
    public TeaConfiguration[] CustomConfigurations { get; init; } = [];
    public TeaConfiguration? CustomDraft { get; init; }
    public bool UsesCustomMode { get; init; }
}

public sealed record TeaRound(TeaConfiguration Configuration, double WaterML, int StartedInfusions)
{
    public double Grams => WaterML / Configuration.Recipe.WaterPerGram;
}

public sealed record TeaReminder(ReminderKind Kind, TeaConfiguration Configuration, int Infusion,
    double Grams, bool IsPreview = false)
{
    public Guid Id { get; } = Guid.NewGuid();
}

public static class TeaText
{
    public static string Number(double value) => value.ToString("0.#", CultureInfo.InvariantCulture);
    public static string Grams(double value) => Math.Round(value, 1, MidpointRounding.AwayFromZero)
        .ToString("F1", CultureInfo.InvariantCulture);
    public static string Clock(int seconds) => $"{Math.Max(0, seconds) / 60:00}:{Math.Max(0, seconds) % 60:00}";
    public static string Duration(int seconds) => seconds switch
    {
        <= 0 => "跳过",
        < 60 => $"{seconds} 秒",
        _ when seconds % 60 == 0 => $"{seconds / 60} 分钟",
        _ => $"{seconds / 60} 分 {seconds % 60} 秒"
    };
}

// All mutations are made by the UI thread. The injected clock and save callback keep this
// state machine independent of WPF, Windows events, and the user's real preference file.
public sealed class TeaStore : INotifyPropertyChanged
{
    public const int MaximumConfigurations = 10;
    private readonly Func<DateTimeOffset> now;
    private readonly Action<TeaPreferences>? save;
    private DateTimeOffset clockDate;
    public event PropertyChangedEventHandler? PropertyChanged;

    public TeaPreferences Preferences { get; private set; }
    public TeaPhase Phase { get; private set; }
    public TeaRound? Round { get; private set; }
    public TeaReminder? Reminder { get; private set; }
    public DateTimeOffset? Deadline { get; private set; }
    public int PhaseDuration { get; private set; }
    public int PlannedBrewSeconds { get; private set; }
    public int StartingInfusion { get; private set; } = 1;
    public string? ConfigurationMessage { get; private set; }
    public string? StorageMessage { get; private set; }

    public TeaStore(TeaPreferences? preferences = null, Func<DateTimeOffset>? now = null,
        Action<TeaPreferences>? save = null, string? storageMessage = null)
    {
        Preferences = preferences ?? new();
        this.now = now ?? (() => DateTimeOffset.UtcNow);
        this.save = save;
        clockDate = this.now();
        StorageMessage = storageMessage;
    }

    public bool IsCustomMode => Preferences.UsesCustomMode && Preferences.CustomDraft is not null;
    public TeaConfiguration Configuration => IsCustomMode ? Preferences.CustomDraft! : TeaPresets.Get(Preferences.SelectedTea);
    public TeaRecipe Recipe => Configuration.Recipe;
    public TeaConfiguration[] CustomConfigurations => Preferences.CustomConfigurations;
    public TeaConfiguration? SavedConfiguration => CustomConfigurations.FirstOrDefault(c => c.Id == Configuration.Id);
    public bool HasUnsavedChanges => IsCustomMode && SavedConfiguration != Configuration;
    public bool CanSaveAsNew => CustomConfigurations.Length < MaximumConfigurations;
    public bool IsActive => Phase != TeaPhase.Idle;
    public string DisplayName => Round?.Configuration.Name ?? Configuration.Name;
    public TeaIcon DisplayIcon => Round?.Configuration.Icon ?? Configuration.Icon;
    public bool CanSkipCooling => Phase == TeaPhase.Cooling
        || ((Phase is TeaPhase.Idle or TeaPhase.PreparingRefill) && Recipe.CoolingSeconds > 0);
    public int RemainingSeconds => Deadline is { } deadline
        ? Math.Max(0, (int)Math.Ceiling((deadline - clockDate).TotalSeconds)) : 0;
    public double Progress => PhaseDuration > 0 ? Math.Clamp(1 - (double)RemainingSeconds / PhaseDuration, 0, 1) : 1;
    public int DisplayedInfusion => Round is { } round
        ? round.StartedInfusions + (Phase is TeaPhase.Brewing or TeaPhase.Ready ? 0 : 1) : StartingInfusion;
    public int CurrentBrewSeconds => Phase is TeaPhase.Idle or TeaPhase.PreparingRefill
        ? Recipe.BrewSeconds(DisplayedInfusion) : PlannedBrewSeconds;
    public double RecommendedGrams => double.IsFinite(Recipe.WaterPerGram) && Recipe.WaterPerGram > 0
        ? Preferences.WaterML / Recipe.WaterPerGram : 0;

    public string? ConfigurationValidationMessage =>
        !double.IsFinite(Recipe.WaterPerGram) || Recipe.WaterPerGram <= 0 ? "水与干茶的比例要大于 0"
        : Configuration.WaterTemperatureC is < 50 or > 100 ? "参考水温应在 50–100°C 之间"
        : Recipe.CoolingSeconds < 0 || Recipe.FirstBrewSeconds <= 0 || Recipe.IncrementSeconds < 0 ? "请设置有效的计时时间"
        : null;

    public string? ValidationMessage =>
        !double.IsFinite(CupCapacityML) || CupCapacityML <= 0 || !double.IsFinite(WaterML) || WaterML <= 0 ? "水量和容量都要大于 0"
        : WaterML > CupCapacityML ? "注水量不能超过杯子容量" : ConfigurationValidationMessage;

    public string StatusText => Phase switch
    {
        TeaPhase.Cooling => "晾 " + TeaText.Clock(RemainingSeconds),
        TeaPhase.Brewing => "泡 " + TeaText.Clock(RemainingSeconds),
        TeaPhase.WaitingForLeaves => "待投茶",
        TeaPhase.Ready => "已泡好",
        TeaPhase.PreparingRefill => $"第 {DisplayedInfusion} 泡",
        _ => "准备一杯茶"
    };

    // Two-way WPF bindings commit numeric fields on focus loss or Return.
    public double CupCapacityML { get => Preferences.CupCapacityML; set => SetCapacity(value); }
    public double WaterML { get => Preferences.WaterML; set => ChangePreferences(Preferences with { WaterML = value }); }
    public double WaterPerGram { get => Recipe.WaterPerGram; set => EditConfiguration(c => c with { Recipe = c.Recipe with { WaterPerGram = value } }); }
    public string ConfigurationName { get => Configuration.Name; set => EditConfiguration(c => c with { Name = value }); }
    public int WaterTemperatureC { get => Configuration.WaterTemperatureC; set => EditConfiguration(c => c with { WaterTemperatureC = value }); }
    public int CoolingSeconds { get => Recipe.CoolingSeconds; set => EditConfiguration(c => c with { Recipe = c.Recipe with { CoolingSeconds = value } }); }
    public int FirstBrewSeconds { get => Recipe.FirstBrewSeconds; set => EditConfiguration(c => c with { Recipe = c.Recipe with { FirstBrewSeconds = value } }); }
    public int IncrementSeconds { get => Recipe.IncrementSeconds; set => EditConfiguration(c => c with { Recipe = c.Recipe with { IncrementSeconds = value } }); }

    public void SelectTea(TeaKind tea)
    {
        if (IsActive) return;
        ConfigurationMessage = null;
        ChangePreferences(Preferences with { SelectedTea = tea, UsesCustomMode = false });
    }

    public void SetCapacity(double value)
    {
        ChangePreferences(Preferences with { CupCapacityML = value,
            WaterML = value > 0 && Preferences.WaterML > value ? value : Preferences.WaterML });
    }

    public void SetStartingInfusion(int value)
    {
        if (IsActive) return;
        StartingInfusion = Math.Clamp(value, 1, 99);
        NotifyAll();
    }

    public void SetIcon(TeaIcon icon) => EditConfiguration(c => c with { Icon = icon });

    private void EditConfiguration(Func<TeaConfiguration, TeaConfiguration> edit)
    {
        var original = Configuration;
        var edited = edit(original);
        if (edited == original) return;
        if (!IsCustomMode)
            edited = edited with { Id = Guid.NewGuid().ToString(),
                Name = edited.Name == original.Name ? original.Name + " · 自定义" : edited.Name };
        ConfigurationMessage = null;
        ChangePreferences(Preferences with { CustomDraft = edited, UsesCustomMode = true });
    }

    public void EnterCustomMode()
    {
        if (IsActive) return;
        ConfigurationMessage = null;
        ChangePreferences(Preferences with { CustomDraft = Preferences.CustomDraft ?? Configuration.CustomCopy(), UsesCustomMode = true });
    }

    public void SelectCustomConfiguration(string id)
    {
        if (IsActive || CustomConfigurations.FirstOrDefault(c => c.Id == id) is not { } selected) return;
        ConfigurationMessage = null;
        ChangePreferences(Preferences with { CustomDraft = selected, SelectedTea = selected.BaseTea, UsesCustomMode = true });
    }

    public bool SaveConfiguration(bool asNew = false)
    {
        if (!IsCustomMode) return false;
        if (ConfigurationValidationMessage is { } error) return Message(error);
        var edited = Configuration with { Name = Configuration.Name.Trim() };
        if (edited.Name.Length == 0) return Message("请给配置起个名字");
        var saved = CustomConfigurations.ToList();
        int index = saved.FindIndex(c => c.Id == edited.Id);
        if (!asNew && index >= 0) saved[index] = edited;
        else
        {
            if (!CanSaveAsNew) return Message("最多保存 10 条，请更新或删除已有配置");
            if (asNew) edited = edited with { Id = Guid.NewGuid().ToString() };
            saved.Add(edited);
        }
        ConfigurationMessage = "已保存";
        ChangePreferences(Preferences with { CustomConfigurations = saved.ToArray(), CustomDraft = edited });
        return true;
    }

    public void DeleteSelectedConfiguration()
    {
        if (IsActive || SavedConfiguration is null) return;
        string id = Configuration.Id;
        ConfigurationMessage = "已删除，当前参数保留为未保存草稿";
        ChangePreferences(Preferences with
        {
            CustomConfigurations = CustomConfigurations.Where(c => c.Id != id).ToArray(),
            CustomDraft = Configuration with { Id = Guid.NewGuid().ToString() }
        });
    }

    public void StartNewRound(bool skipCooling = false)
    {
        if (Phase != TeaPhase.Idle || ValidationMessage is not null) return;
        Reminder = null;
        Round = new(Configuration, WaterML, StartingInfusion - 1);
        BeginPour(skipCooling);
        NotifyAll();
    }

    private void BeginPour(bool skipCooling)
    {
        if (Round is null) return;
        PlannedBrewSeconds = Recipe.BrewSeconds(Round.StartedInfusions + 1);
        if (Recipe.CoolingSeconds > 0 && !skipCooling) BeginTimer(TeaPhase.Cooling, Recipe.CoolingSeconds);
        else BeginBrewing();
    }

    public void ConfirmLeaves()
    {
        if (Phase != TeaPhase.WaitingForLeaves) return;
        Reminder = null;
        BeginBrewing();
        NotifyAll();
    }

    public void SkipCooling()
    {
        switch (Phase)
        {
            case TeaPhase.Idle: StartNewRound(true); return;
            case TeaPhase.PreparingRefill: StartRefill(true); return;
            case TeaPhase.Cooling:
                Reminder = null;
                BeginBrewing();
                NotifyAll();
                break;
        }
    }

    private void BeginBrewing()
    {
        if (Round is null) return;
        Round = Round with { StartedInfusions = Round.StartedInfusions + 1 };
        BeginTimer(TeaPhase.Brewing, PlannedBrewSeconds);
    }

    private void BeginTimer(TeaPhase phase, int seconds)
    {
        clockDate = now();
        PhaseDuration = seconds;
        Deadline = clockDate.AddSeconds(seconds);
        Phase = phase;
    }

    public void PrepareRefill()
    {
        if (Phase != TeaPhase.Ready) return;
        Reminder = null;
        Phase = TeaPhase.PreparingRefill;
        NotifyAll();
    }

    public void StartRefill(bool skipCooling = false)
    {
        if (Phase != TeaPhase.PreparingRefill) return;
        BeginPour(skipCooling);
        NotifyAll();
    }

    public void EndRound()
    {
        Reminder = null;
        Deadline = null;
        Round = null;
        Phase = TeaPhase.Idle;
        StartingInfusion = 1;
        NotifyAll();
    }

    public void Tick()
    {
        clockDate = now();
        if (Deadline is { } deadline && clockDate >= deadline && Round is { } round)
        {
            if (Phase == TeaPhase.Cooling)
            {
                Deadline = null;
                Phase = TeaPhase.WaitingForLeaves;
                Reminder = new(ReminderKind.AddLeaves, round.Configuration, round.StartedInfusions + 1, round.Grams);
                NotifyAll();
                return;
            }
            if (Phase == TeaPhase.Brewing)
            {
                Deadline = null;
                Phase = TeaPhase.Ready;
                Reminder = new(ReminderKind.TeaReady, round.Configuration, round.StartedInfusions, round.Grams);
                NotifyAll();
                return;
            }
        }
        foreach (string property in new[] { nameof(RemainingSeconds), nameof(Progress), nameof(StatusText) })
            PropertyChanged?.Invoke(this, new(property));
    }

    public void DismissReminder() { Reminder = null; NotifyAll(); }

    public void PreviewReminder()
    {
        if (Reminder is not null) return;
        Reminder = new(ReminderKind.TeaReady, Round?.Configuration ?? Configuration,
            Math.Max(1, DisplayedInfusion), Round?.Grams ?? RecommendedGrams, true);
        NotifyAll();
    }

    private bool Message(string text)
    {
        ConfigurationMessage = text;
        NotifyAll();
        return false;
    }

    private void ChangePreferences(TeaPreferences preferences)
    {
        if (preferences != Preferences)
        {
            Preferences = preferences;
            try { save?.Invoke(preferences); StorageMessage = null; }
            catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException or ArgumentException)
            { StorageMessage = "设置尚未保存：" + error.Message; }
        }
        NotifyAll();
    }

    private void NotifyAll() => PropertyChanged?.Invoke(this, new(null));
}
