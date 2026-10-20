using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace TeaPanel;

public sealed class PreferenceStorage
{
    public static string DefaultDirectory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "TeaPanel");
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase, allowIntegerValues: false) }
    };

    public string FilePath { get; }
    public string? LoadMessage { get; private set; }
    private bool canSave = true;

    public PreferenceStorage(string? directory = null) => FilePath = Path.Combine(directory ?? DefaultDirectory, "preferences.json");

    public TeaPreferences Load()
    {
        if (!File.Exists(FilePath)) return new();
        try
        {
            var preferences = JsonSerializer.Deserialize<TeaPreferences>(File.ReadAllText(FilePath), Options);
            if (preferences is null || !HasValidStructure(preferences))
                throw new JsonException("配置文件格式不完整");
            if (preferences.SchemaVersion != 1)
            {
                canSave = false;
                LoadMessage = "此配置来自其他版本，已保留原文件；本次使用默认设置，暂不写入。";
                return new();
            }
            return preferences;
        }
        catch (JsonException)
        {
            try
            {
                string backup = FilePath + ".unreadable-" + Guid.NewGuid().ToString("N") + ".bak";
                File.Copy(FilePath, backup);
                LoadMessage = "原设置文件无法读取，已保留备份；本次使用默认设置。";
            }
            catch (Exception error) when (error is IOException or UnauthorizedAccessException)
            {
                canSave = false;
                LoadMessage = "原设置无法备份，已保留原文件；本次使用默认设置，暂不写入。";
            }
            return new();
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        {
            canSave = false;
            LoadMessage = "设置暂时无法读取，已保留原文件：" + error.Message;
            return new();
        }
    }

    public void Save(TeaPreferences preferences)
    {
        if (!canSave) throw new IOException("为保留原始设置，本次未覆盖配置文件。");
        // Serialize before opening a temporary file so invalid numeric values cannot damage
        // the previous preferences. A same-directory rename keeps replacement local.
        string json = JsonSerializer.Serialize(preferences, Options);
        Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
        string temporary = FilePath + ".tmp";
        try
        {
            File.WriteAllText(temporary, json, new UTF8Encoding(false));
            File.Move(temporary, FilePath, overwrite: true);
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }

    private static bool HasValidStructure(TeaPreferences preferences)
    {
        static bool Valid(TeaConfiguration configuration) => configuration is not null
            && !string.IsNullOrEmpty(configuration.Id) && configuration.Name is not null
            && configuration.Recipe is not null && Enum.IsDefined(configuration.Icon)
            && Enum.IsDefined(configuration.BaseTea);
        return Enum.IsDefined(preferences.SelectedTea) && preferences.CustomConfigurations is not null
            && preferences.CustomConfigurations.All(Valid)
            && (preferences.CustomDraft is null || Valid(preferences.CustomDraft));
    }
}
