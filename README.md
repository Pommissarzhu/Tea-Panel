<p align="center">
  <img src="Resources/AppIcon.png" width="112" alt="茶伴应用图标">
</p>

<h1 align="center">茶伴 · Tea Panel</h1>

<p align="center">一个安静的原生泡茶提醒器，常驻 Mac 菜单栏或 Windows 托盘。</p>

<p align="center">
  <strong>简体中文</strong> · <a href="README.en-US.md">English (US)</a>
</p>

<p align="center">macOS 13+ / Apple Silicon · Windows 11 / x64 · MIT</p>

设置实际注水量，查看建议投茶量，然后按“晾水 → 确认投茶 → 浸泡”的流程泡茶。到点时，静音悬浮卡片会持续显示，直到你处理提醒。

macOS 应用在简体中文系统中显示为**茶伴**，英文名为 **Tea Panel**；Windows 窗口名为**茶伴 · Tea Panel**，程序为 `TeaPanel.exe`。两端界面与默认 README 使用**简体中文**，另提供美式英语 README。

<p align="center">
  <img src="docs/images/brewing-panel.png" width="384" alt="macOS 茶伴主界面：栀子花茶，注水 330 mL，建议干茶 6.6 克">
  <img src="docs/images/windows-brewing-panel.png" width="384" alt="Windows 茶伴原生 WPF 主面板：栀子花茶，330 mL，6.6 克干茶">
</p>

## 功能

- **三种内置模板**：栀子花茶、铁观音、茉莉花茶。
- **按水量计算投茶量**：根据实际注水量和水茶比例，计算建议干茶重量。
- **分段计时**：先晾水，确认投茶后再浸泡；准备好时也可直接跳过晾水。
- **同一批茶叶续泡**：每泡自动加时，支持从第 1–99 泡中的任一泡开始。
- **持续静音提醒**：macOS 菜单栏显示倒计时；Windows 在主面板和托盘悬停提示中显示。到点显示悬浮卡片，处理后才收起。
- **自定义配方**：最多保存 10 条配置，可设置名称、图标、比例、参考水温和时间。
- **本地保存**：杯子设置、已存配方和最近草稿保存在本机，应用不发起网络请求。
- **原生界面**：macOS 使用 SwiftUI/AppKit，Windows 使用 C#/WPF/.NET 10；适配系统动画设置，无第三方应用依赖。

## 快速开始

### macOS 安装

从 [GitHub Releases](https://github.com/Pommissarzhu/Tea-Panel/releases) 下载 `Tea-Panel-<版本号>-Apple-Silicon.dmg`。打开磁盘映像，将**茶伴**拖入 **Applications**，再从“应用程序”启动。安装包不需要 Xcode 或 Command Line Tools。

当前安装包使用临时签名（ad hoc），尚未进行 Developer ID 签名和 Apple 公证。首次打开时，macOS 可能要求在“系统设置 → 隐私与安全性”中允许打开。

### Windows 安装

当前 Windows 源码为 **0.4.2**，尚未发布到 GitHub Releases。可按下文构建，或直接双击本地打包生成的 `Tea-Panel-0.4.2-Windows-x64.exe`。只需这一个 EXE，已包含 .NET 运行时，不需要解压、另装 .NET 或管理员权限。当前 Windows 包未进行代码签名。

启动后点击托盘图标打开主面板；右键菜单提供打开和退出。关闭面板、Esc 或失焦只隐藏窗口，计时继续；从托盘退出才结束本轮。Windows 详细说明见[使用与构建指南](docs/windows-guide.zh-CN.md)。

### macOS 从源码构建

- **Apple Silicon** Mac，运行 **macOS 13 Ventura 或更高版本**。
- Xcode Command Line Tools，包含 **Swift 6** 编译器和 macOS SDK。

尚未安装 Command Line Tools 时，先运行 `xcode-select --install`。

克隆或下载仓库，在仓库根目录打开终端并运行：

```sh
zsh build.sh --run
```

脚本会生成并打开 `build/Tea Panel.app`。也可用 `zsh build.sh` 只构建，再自行打开，或将应用复制到“应用程序”目录。启动后菜单会展开，之后点击菜单栏图标即可再次打开。

构建脚本目前仅面向 `arm64`，本地构建和 GitHub Actions 安装包均使用临时签名（ad hoc）。

### Windows 从源码构建

使用 Windows 11 x64 和 .NET 10 SDK，无需完整 Visual Studio。在仓库根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File windows/build.ps1 -Run
```

应用生成在 `build/windows/app/TeaPanel.exe`。脚本兼容 Windows PowerShell 5.1 和 PowerShell 7；可用 `TEA_PANEL_DOTNET` 指定本地 `dotnet.exe`。两端代码分别位于现有 `Sources/` 和新增 `windows/` 中。

## 泡第一杯茶

1. 选择茶种，填写实际注水量；默认为 330 mL。
2. 接好水，点击**已接水，开始晾水**。
3. 提醒出现后按建议克数投茶，点击**已投茶，开始泡茶**。
4. 泡好后取出茶滤或倒出茶汤，再点击确认提醒。
5. 想再泡一杯时选择**续泡**；更换茶叶时选择**换新茶叶**。

铁观音默认跳过晾水：先放好茶叶并注水，再开始浸泡计时。其他模板可通过**跳过晾水，直接泡茶**，立即开始当前泡次的完整浸泡计时。

点击**预览提醒**可查看卡片效果，不启动或改变真实计时。自定义配置、续泡和计时细节见[使用指南](docs/guide.zh-CN.md)。

## 内置模板

以下参数是杯泡的起点，可按茶叶和口感调整。

| 茶种 | 参考水温 | 每 200 mL 干茶量 | 晾水延时 | 首泡 | 每次续泡增加 |
| --- | --- | --- | --- | --- | --- |
| 栀子花茶（绿茶底） | 80°C | 4 克 | 3 分钟 | 3 分钟 | 30 秒 |
| 铁观音 | 100°C | 5 克 | 跳过 | 1 分钟 | 30 秒 |
| 茉莉花茶（绿茶底） | 85°C | 4 克 | 2 分钟 | 3 分钟 | 30 秒 |

330 mL 时，对应建议干茶量为 **6.6 克、8.3 克、6.6 克**。显示值四舍五入保留一位小数。

晾水采用固定计时，不测量真实水温；水温设置只作参考。计时器不能自动停止浸泡，提醒后仍需取出茶叶。

## 开发

```sh
zsh build.sh          # 生成 build/Tea Panel.app
zsh build.sh --run    # 构建并打开
zsh test.sh           # 运行核心逻辑检查
zsh test.sh --motion  # 另查窗口和菜单栏行为，需要 macOS 图形会话
zsh package.sh        # 重新构建并生成 dist/ 下的 DMG 和 SHA-256 校验文件
```

macOS 既有验收记录包括 **193 项核心检查**和 **68 项动效与菜单栏检查**。全屏、多显示器和实际合盖唤醒仍需对应环境下的交互验收。代码结构和验证范围见[贡献指南](CONTRIBUTING.md)。

Windows 命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File windows/test.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File windows/test.ps1 -Desktop
powershell -NoProfile -ExecutionPolicy Bypass -File windows/package.ps1
```

Windows 已通过 **92 项核心与存储检查**、**78 项桌面检查**，并在 200% 缩放下渲染验收。`-Desktop` 需要登录的图形桌面，使用隔离数据并短暂显示测试窗口；真实休眠、多显示器等仍见[验证记录](docs/windows-verification.zh-CN.md)。上面的 193/68 项是 macOS 既有验收记录，本次 Windows 开发未重新运行 macOS 测试。

打包命令生成 `dist/Tea-Panel-0.4.2-Windows-x64.exe` 和 `.exe.sha256`；校验文件不影响运行。开发用的 `build/windows/app/` 仍保留普通构建输出。

发布工作流已配置为两端分别检查、构建和打包，再由单个发布任务提供 macOS DMG、Windows 单文件 EXE 和各自 SHA-256。版本号与 `v<版本号>` 标签一致时发布；手动运行 **Build and Release** 只保留构建产物。发布步骤见[贡献指南](CONTRIBUTING.md#releases)。

手动构建后，在 Actions 运行页面下载 Windows artifact。GitHub 网页会将 artifact 包装为 ZIP，解压后只有单个 EXE 和可选的校验文件，运行不需要 DLL。也可用 `gh run download` 直接取出文件；Release 附件则直接提供 EXE。

```text
.
├── .github/workflows/ # GitHub Actions 自动打包与发布
├── Sources/          # SwiftUI 界面、AppKit 集成、计时逻辑和动效
├── Resources/        # 应用元数据和当前图标
├── Tests/            # 核心逻辑及窗口回归检查
├── windows/          # WPF 应用、Windows 回归检查和 PowerShell 脚本
├── docs/             # 使用指南、截图、设计说明和验收记录
├── build.sh          # 本地构建脚本
├── package.sh        # DMG 打包与校验
└── test.sh           # 本地测试脚本
```

生成的应用、磁盘映像、编译缓存和本地设置均排除在 Git 之外。

## 文档

| 文档 | 内容 |
| --- | --- |
| [使用指南](docs/guide.zh-CN.md) / [Usage guide](docs/guide.md) | 水量、配方、泡次与提醒的详细行为 |
| [更新记录](CHANGELOG.md) | 应用版本历史 |
| [贡献指南](CONTRIBUTING.md) | 构建、测试与修改约定 |
| [本地数据与迁移](docs/data-storage.md) | 偏好设置和旧版备份 |
| [Windows 指南](docs/windows-guide.zh-CN.md) / [English](docs/windows-guide.md) | 托盘操作、构建与打包 |
| [Windows 验证记录](docs/windows-verification.zh-CN.md) | 本地结果、截图与待验证场景 |
| [Windows 实施计划](docs/windows-native-plan.zh-CN.md) | 技术选择与双平台组织方式 |
| [产品方案](docs/product-plan.zh-CN.md) | 首版产品约定 |
| [历史验收记录](docs/verification.zh-CN.md) | 既有测试与界面检查结果 |
| [图标设计](docs/design/app-icon.zh-CN.md) | 当前图标来源及独立的设计提案 |

退出应用会结束当前泡茶会话。重新打开时保留偏好设置，正在进行的计时不会恢复。

## 许可证

茶伴（Tea Panel）的原创代码、文档和应用图形采用 [MIT License](LICENSE)。
