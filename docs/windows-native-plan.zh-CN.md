# 茶伴原生 Windows 版与双平台仓库计划

日期：2026-10-19

状态：Windows 首版与交互动效修订已实现，本地构建、核心与隔离桌面检查、自包含打包通过；远端双平台构建结果见 [Actions](https://github.com/Pommissarzhu/Tea-Panel/actions/workflows/release.yml)，扩展实机场景仍待验证。详情见[Windows 验证记录](windows-verification.zh-CN.md)。

功能基线：macOS 版 0.3.9，提交 `0d3df5c`。

当前源码版本：两端均为 0.4.2，尚未发布。Windows 本地完成 92 项核心与存储检查、78 项桌面检查；按后续要求改为交付 `dist/Tea-Panel-0.4.2-Windows-x64.exe` 及校验文件。

目标是在现有仓库内增加一个 **C# + WPF 的 Windows 原生托盘应用**，延续茶伴的泡茶流程、配方和视觉风格。macOS 继续使用 SwiftUI/AppKit；两端各自实现界面和系统集成，保持相同的产品规则。

## 1. 技术与范围

| 项目 | 首版选择 |
| --- | --- |
| 目标系统 | Windows 11 x64，其他系统和架构留待有实机时扩展 |
| 语言和界面 | C#、WPF、.NET 10 LTS，目标框架 `net10.0-windows` |
| 托盘入口 | .NET 自带的 Windows Forms `NotifyIcon`，主界面仍使用 WPF |
| 界面组织 | XAML、少量 code-behind、一个可绑定的 `TeaStore` |
| 配置保存 | `System.Text.Json` 和本地 JSON 文件 |
| 分发方式 | 包含 .NET 运行时与原生依赖的单文件 EXE，双击运行 |
| 工程规模 | 一个应用项目、一个轻量核心测试项目，不额外引用第三方 NuGet 包 |

[WPF](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/overview/) 提供 Windows 桌面界面、数据绑定和动画；[.NET 10 为 LTS 版本](https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core)。本项目采用这套组合，是因为需要的主要是托盘、两个小窗口和本地计时，能够用现成的 .NET 桌面能力完成。

首版聚焦现有功能：账号、云同步、统计、自动更新、后台服务、商店上架和复杂安装器均不纳入本次范围。验证围绕功能、数据保存和实际桌面行为展开，不增加专门的复杂安全审计阶段。

## 2. 与 macOS 对齐的功能

| 功能 | Windows 首版要求 |
| --- | --- |
| 内置模板 | 栀子花茶、铁观音、茉莉花茶，默认参数与现版一致 |
| 用量计算 | 默认容量和注水量均为 330 mL；按水量与比例计算，显示一位小数 |
| 分段计时 | 晾水、等待确认投茶、浸泡、泡好；支持跳过晾水 |
| 续泡 | 同一批茶叶续泡并递增加时，允许从第 1–99 泡中的任一泡开始 |
| 自定义配置 | 名称、10 种语义图标、比例、参考水温和时间；最多保存 10 条，支持更新、另存、删除和最近草稿 |
| 提醒 | 持续静音悬浮卡片，用户处理后收起；预览不干扰真实计时或覆盖未处理的真实提醒 |
| 本地状态 | 保存共用容量、水量、配置、当前模式和草稿；退出结束当前轮，重开从第 1 泡开始 |
| 交互反馈 | 输入校验、焦点、悬停、保存提示、数值过渡，以及系统关闭动画时的适配 |

默认模板作为两端共同的验收基准：

| 模板 | 参考水温 | 水 : 干茶 | 晾水 | 首泡 | 每次续泡增加 | 330 mL 投茶量 |
| --- | --- | --- | --- | --- | --- | --- |
| 栀子花茶 | 80°C | 50 : 1 | 180 秒 | 180 秒 | 30 秒 | 6.6 克 |
| 铁观音 | 100°C | 40 : 1 | 跳过 | 60 秒 | 30 秒 | 8.3 克 |
| 茉莉花茶 | 85°C | 50 : 1 | 120 秒 | 180 秒 | 30 秒 | 6.6 克 |

核心规则直接参照 [TeaCore.swift](../Sources/TeaCore.swift)、[核心测试](../Tests/TeaCoreTests.swift)和[使用指南](guide.zh-CN.md)：

- 投茶量 = 注水量 ÷ 水茶比例；第 n 泡时长 = 首泡时长 +（n − 1）× 续泡加时。水量变化不自动缩放计时。
- C# 显示投茶量时明确使用 `MidpointRounding.AwayFromZero`，保持 8.25 克显示为 8.3 克，避免默认舍入规则造成差异。
- 开始一轮后固定本轮名称、图标、水量和投茶量。当前已经安排的浸泡时长保持不变，包括晾水途中修改参数后再跳过晾水的情况；新的时间设置用于下一泡，其余配置修改用于下一轮。
- 只有实际开始浸泡才消耗一次泡数；等待投茶期间不会自行进入浸泡。跳过晾水从点击时开始完整浸泡，不重复启动或增加泡次。
- 杯子容量和注水量独立于茶叶配置；修改这些值或起始泡次不产生自定义配置。计时中禁止切换茶种、切换已存配置和删除当前配置。
- 茶叶参数实际变化后才进入自定义模式；内置模板不占保存名额。满 10 条仍可更新或删除，删除后保留当前参数为未保存草稿。
- 无效水量阻止开始泡茶，但不阻止保存其他字段有效的茶叶配置。空名称、无效比例和无效时间按现有规则提示。

## 3. Windows 桌面交互

### 托盘和主面板

使用 [NotifyIcon](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.notifyicon?view=windowsdesktop-10.0) 常驻通知区域。左键切换主面板，右键提供“打开茶伴”和“退出”。启动时展示一次主面板；关闭面板、按 Esc 或切换到其他应用时隐藏，托盘和计时继续运行。

Windows 托盘入口使用图标，悬停提示显示茶名、阶段和剩余时间，完整倒计时在主面板内显示。首版不为复刻 macOS 菜单栏文字而绘制动态数字图标或改造任务栏。

主面板打开时根据点击位置和屏幕工作区定位，展开后位置固定。处理任务栏遮挡及物理像素与 WPF DIP 的换算；高缩放或较小屏幕下允许内容滚动。使用一个简单的进程互斥量避免重复启动多轮计时，退出时释放托盘图标和系统事件订阅。

### 持续提醒

复用独立的 WPF 提醒窗口：置顶、不出现在任务栏、出现时不激活，定位到鼠标所在屏幕工作区的顶部中央。以 [`ShowActivated=false`](https://learn.microsoft.com/en-us/dotnet/api/system.windows.window.showactivated?view=windowsdesktop-10.0) 为起点实现非抢焦点显示，并通过真实打字场景验收；用户主动点击卡片后可以正常操作。

提醒不依赖系统通知的显示时长，持续保留到确认或结束本轮。全屏和多显示器必须实测，不承诺覆盖独占全屏；锁屏期间不要求可见，解锁后仍保留待处理提醒。

### 计时和视觉

- 用注入的 `Func<DateTimeOffset>` 提供时间，按 UTC 截止时刻计算剩余秒数；UI 定时刷新只负责调用 `Tick`，不按回调次数递减。休眠恢复和会话解锁时立即刷新，回调回到 UI 线程。
- 沿用浅米色背景、森林绿、圆角卡片、大号读数和进度环。使用 Windows 字体和本地矢量图标，以语义映射替换 SF Symbols；应用图标从现有 `Resources/AppIcon.png` 生成 Windows `.ico`。
- 菜单与提醒采用短淡入淡出和轻微位移，数值过渡保持布局稳定。系统关闭动画时读取 [`SystemParameters.ClientAreaAnimation`](https://learn.microsoft.com/en-us/dotnet/api/system.windows.systemparameters.clientareaanimation?view=windowsdesktop-10.0)，取消位移和缩放。反复开合不能被旧动画的完成回调错误隐藏。

## 4. 双平台代码如何共存

保留现有 macOS 目录和根目录脚本，新增 `windows/`。首版不搬迁 Swift 文件，也不引入跨语言公共核心、插件系统或代码生成。

```text
Sources/                         # 现有 macOS Swift 源码
Resources/                       # 现有 macOS 资源和应用图标源文件
Tests/                           # 现有 macOS 回归检查
build.sh / test.sh / package.sh   # 现有 macOS 命令
windows/
  TeaPanel/
    TeaPanel.csproj
    App.xaml / App.xaml.cs       # 应用启动与退出
    TeaCore.cs                   # 数据模型、TeaStore、状态机和计算
    PreferenceStorage.cs         # JSON 读写
    TrayHost.cs                  # 托盘和系统事件
    NativeDesktop.cs             # 屏幕工作区与 DPI 定位
    TeaGraphics.cs               # 本地图标与进度环
    MenuWindow.xaml / MenuWindow.xaml.cs         # 泡茶主面板和参数页
    ReminderWindow.xaml / ReminderWindow.xaml.cs # 持续提醒
    Styles.xaml / PanelMotion.cs # 统一样式和少量动效
    TeaMotion.cs                 # 按钮、选中状态、读数和内容切换反馈
    Assets/AppIcon.ico
  Tests/
    TeaCoreTests.csproj
    Program.cs
  build.ps1
  test.ps1
  package.ps1
docs/                            # 两端指南、计划和验证记录
.github/workflows/release.yml     # 后续扩展现有发布流程
```

两个 `.csproj` 可直接通过 CLI 使用，暂不需要解决方案文件。测试项目按现有 Swift 测试的方式运行可执行检查，通过源码链接编译 `TeaCore.cs` 和需要检查的存储代码，避免另拆一个公共类库。

两端共享产品规则、原始图形和文档，各自维护运行代码及平台存储。规则调整时同时更新对应测试；首版无需为三条默认配方建立共享配置加载系统。实现时补充根目录 `AGENTS.md`、两份 README、数据说明和 `.gitignore` 中的 Windows 命令及 `bin/`、`obj/` 等生成目录规则。

## 5. Windows 本地数据

保存到 `%LOCALAPPDATA%\TeaPanel\preferences.json`，不依赖 EXE 所在目录或当前工作目录。记录一个简单的 `schemaVersion`，其余字段覆盖共用杯子设置、当前模式、已存配置和最近草稿。

使用临时文件写完后替换正式文件；保存失败时提示并保留原文件及内存中的设置。无法解析的原始文件保留副本，再使用默认设置，避免直接覆盖用户配置。测试使用唯一的临时目录并清理，不读取真实偏好。

Windows 从自己的第一版数据格式开始，不移植 macOS 历史迁移分支，也不自动导入 Mac 的 `UserDefaults`。macOS 的配置键、备份和迁移行为继续遵循[现有数据说明](data-storage.md)。跨平台导入导出留待后续明确需要时再做。

## 6. 实施顺序

每阶段交付可以独立检查的结果，完成后再进入下一阶段。

| 阶段 | 工作 | 完成标准 |
| --- | --- | --- |
| 1. 跑通桌面骨架 | 创建应用和脚本，接入托盘、主面板与测试提醒，处理退出和单实例 | Windows 11 上能打开、隐藏和退出；测试提醒出现时不打断其他应用输入；反复点击不产生多个窗口 |
| 2. 对齐核心和存储 | 移植模板、计时状态、用量、续泡、自定义配置及本地保存，加入注入时钟的核心测试 | 默认值和关键边界与 Swift 一致；完整走完一轮和续泡；重启保留设置但不恢复计时 |
| 3. 完成界面和系统行为 | 补齐参数页、保存反馈、预览、动效、唤醒刷新及多屏/DPI 定位 | 日常操作可完成；持续提醒、焦点、休眠恢复和关闭动画设置通过实机检查，保存截图与环境记录 |
| 4. 打包和双平台发布 | 生成 Windows 单文件 EXE 与 SHA-256，扩展现有 Actions，更新中英文文档和更新日志 | 干净 Windows 环境直接运行 EXE；两端构建、核心检查及产物正常；同一个 Release 包含各平台包 |

### 必须覆盖的核心检查

1. 三种模板的投茶量和前四泡时间；8.25 → 8.3 的舍入，以及第 99 泡的长时间显示。
2. 晾水到点仅等待投茶，确认后才开始完整浸泡；无晾水模板直接开始。
3. 开始前、晾水中和准备续泡时跳过晾水；重复点击不会重置计时或重复增加泡次。
4. 从第 2／3 泡接入、继续续泡及换新茶叶；泡次不随设置重启恢复。
5. 本轮快照与下一泡时间修改的生效范围；预览和真实提醒互不覆盖。
6. 自定义草稿、保存、更新、另存、删除、10 条上限，以及水量与配置独立。
7. 正常保存/重载、保存失败和损坏文件保留；恢复后的截止时刻检查可用注入时间验证。

### 实机检查

在 Windows 11 桌面检查一条完整流程、托盘反复开合、Esc/失焦关闭、正在打字时出现提醒、长时间未处理提醒、真实休眠/唤醒、锁屏/解锁和系统动画开关。检查 100%、125%、150%、200% 缩放；有多显示器时检查混合 DPI 和屏幕边缘定位。没有对应设备的项明确记录为待验证。

Windows CI 负责构建和核心检查，不替代上述桌面验收。macOS 保留现有核心与窗口检查；发布时复用已有 macOS CI，在有 Mac 图形会话时再运行 `zsh test.sh --motion`，Windows 环境不声称完成 macOS 原生验收。

## 7. 构建与发布约定

以下命令已实现：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File windows/build.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File windows/build.ps1 -Run
powershell -NoProfile -ExecutionPolicy Bypass -File windows/test.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File windows/package.ps1
```

构建需要 .NET 10 SDK；脚本兼容 Windows 自带的 PowerShell 5.1，也可使用 PowerShell 7。日常编辑器不限，不要求安装完整 Visual Studio。打包脚本使用[自包含发布](https://learn.microsoft.com/en-us/dotnet/core/deploying/#publish-as-self-contained)，例如：

```powershell
dotnet publish windows/TeaPanel/TeaPanel.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o build/windows/win-x64
```

后续要求将交付方式改为单文件：`dist/Tea-Panel-<版本号>-Windows-x64.exe`，另生成 SHA-256 校验文件，MIT 许可证嵌入程序集。项目在单文件发布时开启原生依赖打包、程序集压缩和内嵌调试符号；运行时自动释放少量原生库到临时缓存，采用 [.NET 官方单文件机制](https://learn.microsoft.com/en-us/dotnet/core/deploying/single-file/overview)。不增加 Native AOT 或运行时裁剪，以目标机器无需另装 .NET、无需管理员权限即可运行作为验收标准。

现有 `release.yml` 已增加独立的 Windows 构建任务；macOS 和 Windows 各自测试、打包、上传产物，最后由一个发布任务统一创建 Release，避免两端重复创建同一标签的 Release。Windows CI 调用本地相同的 `windows/package.ps1`，并验证产物只有 EXE 和匹配的校验文件。手动触发继续只生成构建产物，网页下载由 GitHub 包装为 ZIP，内部依然为独立 EXE；标签发布则直接提供 EXE 附件。桌面检查在本地完成，不加入复杂的自动化测试平台。

两端沿用同一产品版本和 `v<版本号>` 标签，分别在 `Info.plist` 和 `.csproj` 中维护版本，并在发布时与标签核对。首个 Windows 正式版使用后续新版本，不修改已发布的 0.3.9。macOS DMG、Windows 单文件 EXE 和各自校验文件并列提供。
