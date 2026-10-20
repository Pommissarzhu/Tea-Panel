# Windows 使用与构建指南

[English](windows-guide.md) · [返回项目首页](../README.md)

Windows 版为 C# / WPF 原生托盘应用，首版面向 Windows 11 x64。配方、投茶量、分段计时、自定义配置和续泡规则与 macOS 一致。

主面板沿用 Mac 版的 384 × 668 逻辑尺寸、图标茶种卡片、泡次标记、并排输入卡片和固定底栏。Windows 使用本机字体和语义相同的本地矢量图形。

## 启动与托盘

从 [v0.4.2 Release](https://github.com/Pommissarzhu/Tea-Panel/releases/tag/v0.4.2) 下载并双击 `Tea-Panel-0.4.2-Windows-x64.exe`。只需一个 EXE，已包含 .NET 运行时，不用解压或另装 .NET，也不需要旁边放 DLL。同一个 Release 也提供 macOS 的 DMG 和两端的校验文件。

更新时先从托盘退出旧版，再运行新 EXE。本地设置沿用原来的文件。

单文件采用 .NET 官方打包方式；运行时会自动把少量原生依赖释放到临时缓存，不需要手动处理。详见[单文件部署说明](https://learn.microsoft.com/en-us/dotnet/core/deploying/single-file/overview#native-libraries)。

- 启动时显示一次主面板，之后左键托盘图标切换显示。
- 图标可能位于通知区域的折叠菜单中；悬停提示包含茶名、阶段和剩余时间。
- 右键提供“打开茶伴”和“退出”。主面板按 Esc、切换应用或关闭窗口只会隐藏；退出应用才结束本轮计时。
- 应用同时只运行一个实例、一轮泡茶。

![Windows 原生主面板](images/windows-brewing-panel.png)

## 泡茶和配置

1. 选茶种，填写本次注水量和起始泡次。杯子容量在设置中修改，默认均为 330 mL。
2. 接好水后开始晾水；到点按提示投茶，再确认开始浸泡。铁观音默认直接浸泡。
3. 水已准备好时可跳过晾水，从点击时开始完整浸泡计时。
4. 泡好后取出茶滤或倒出茶汤，确认提醒。要继续用原茶叶时选择续泡，准备好新水后再开始。
5. 换新茶叶或结束本轮恢复第 1 泡。退出后不会恢复当前计时。

设置中可以编辑名称、图标、水茶比例、参考水温和时间。时间与 Mac 版一样分为独立的分钟、秒菜单，例如 `02 分` 和 `05 秒`；改分钟保留秒数，改秒数保留分钟，不会因打开设置而取整。首泡下限和各项上限仍会生效。数字输入在失去焦点或按 Return 后提交，无法解析的输入会提示并阻止开始计时。

点击“自定义”直接进入参数页，也可以在其旁边快捷保存或更新。右侧“已存 n/10”菜单列出带图标的配置，选中后返回泡茶页；空列表显示“还没有保存的配置”。

修改茶叶参数会产生自定义草稿，点击保存才进入已存列表；最多 10 条，支持更新、另存和删除。容量、水量和起始泡次独立于配方，不会创建新配置。无效水量阻止开始泡茶，但不影响保存其他参数有效的配置。

当前轮的名称、图标、水量和干茶量保持不变；当前已安排的浸泡时长也固定。时间修改从下一泡生效，其他配置变化用于下一轮。精确默认值与示例见[共同泡茶规则](guide.zh-CN.md)。

## 提醒和显示

到点后，鼠标所在屏幕的顶部出现置顶卡片。卡片持续显示到你确认或结束本轮，静音、不主动抢占输入焦点。主面板内的“预览提醒”不会启动计时，也不会覆盖待处理的真实提醒。

![Windows 持续提醒](images/windows-reminder.png)

Windows 使用托盘图标、悬停提示和面板倒计时；没有 macOS 菜单栏的常驻倒计时文字。晾水是固定计时，不测量实际水温。

计时以现实截止时刻计算，休眠和锁屏经过的时间计入；恢复使用后重新检查。锁屏期间不要求显示卡片。不同显示器、缩放和全屏模式的验证范围见[Windows 验证记录](windows-verification.zh-CN.md)。

选茶时高亮平滑切换；改用量、泡次时，大号读数交叉淡化并轻微上下移动，圆环位置固定。设置页和下拉列表有短淡入，按钮提供悬停与按下反馈；倒计时逐秒直接更新，计时圆环平滑推进。当前阶段由“晾水 → 投茶 → 泡茶”标记显示；未计时时只显示浅色圆环。

系统关闭动画时，窗口和内容改用短淡入淡出，取消位移和缩放。键盘可以通过托盘打开面板并使用 Tab 操作控件，焦点以圆角描边显示。下拉框打开时先按 Esc 收起列表，再按 Esc 隐藏面板。

## 本地设置

设置文件为 `%LOCALAPPDATA%\TeaPanel\preferences.json`，不随 EXE 的位置变化。只保存杯子、水量、当前模式、已存配置和最近草稿；计时、提醒和泡次只保留在内存。

保存失败时显示提示并保留已有文件和内存编辑。无法解析的原文件保存为同目录的 `.unreadable-<标识>.bak` 副本；其他版本的数据不会被本版本直接覆盖。两端不自动同步或导入对方设置，详见[数据说明](data-storage.md)。

## 开发命令

构建需要 .NET 10 SDK，不需要完整 Visual Studio。脚本支持 Windows PowerShell 5.1 和 PowerShell 7，在仓库根目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File windows/build.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File windows/build.ps1 -Run
powershell -NoProfile -ExecutionPolicy Bypass -File windows/test.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File windows/test.ps1 -Desktop
powershell -NoProfile -ExecutionPolicy Bypass -File windows/package.ps1
```

`build.ps1` 生成 `build/windows/app/TeaPanel.exe`。构建脚本优先使用 `TEA_PANEL_DOTNET` 指定的可执行文件，其次是仓库内可选的 `build/tools/dotnet/dotnet.exe`，最后是 PATH 中的 SDK。

普通测试覆盖核心和存储；`-Desktop` 另运行真实 WPF 窗口检查，使用隔离数据和注入时钟，结果与截图位于 `build/windows/verification/`。测试不会修改用户真实茶伴设置或系统动画开关。

打包生成 `dist/Tea-Panel-0.4.2-Windows-x64.exe` 和 `.exe.sha256`；校验文件不影响运行。应用项目之外只有一个轻量核心测试项目，不引入数据库、后台服务或第三方应用包。

## GitHub Actions 构建

**Build and Release** 的 Windows 任务调用相同的 `windows/package.ps1`，检查输出只有 EXE 和校验文件，并核对 SHA-256。手动运行工作流只生成构建产物；推送匹配版本的标签才创建 Release。

网页下载的 Windows artifact 会由 GitHub 包装为 ZIP，解压得到单文件 EXE 和 `.exe.sha256`。也可按[贡献指南](../CONTRIBUTING.md#releases)用 `gh run download` 直接下载文件。正式 Release 的附件直接提供 EXE，不需要下载 DLL 或安装 .NET。
