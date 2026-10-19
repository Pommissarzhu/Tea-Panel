<p align="center">
  <img src="Resources/AppIcon.png" width="112" alt="茶伴应用图标">
</p>

<h1 align="center">茶伴 · Tea Panel</h1>

<p align="center">一个安静的 macOS 菜单栏泡茶提醒器。</p>

<p align="center">
  <strong>简体中文</strong> · <a href="README.en-US.md">English (US)</a>
</p>

<p align="center">macOS 13+ · Apple Silicon · Swift 6 · MIT</p>

设置实际注水量，查看建议投茶量，然后按“晾水 → 确认投茶 → 浸泡”的流程泡茶。到点时，静音悬浮卡片会持续显示，直到你处理提醒。

应用在简体中文系统中显示为**茶伴**，英文名为 **Tea Panel**。界面与默认 README 使用**简体中文**，另提供美式英语 README。

<p align="center">
  <img src="docs/images/brewing-panel.png" width="384" alt="茶伴主界面：栀子花茶，注水 330 mL，建议干茶 6.6 克">
</p>

## 功能

- **三种内置模板**：栀子花茶、铁观音、茉莉花茶。
- **按水量计算投茶量**：根据实际注水量和水茶比例，计算建议干茶重量。
- **分段计时**：先晾水，确认投茶后再浸泡；准备好时也可直接跳过晾水。
- **同一批茶叶续泡**：每泡自动加时，支持从第 1–99 泡中的任一泡开始。
- **持续静音提醒**：菜单栏显示倒计时，到点显示悬浮卡片，处理后才收起。
- **自定义配方**：最多保存 10 条配置，可设置名称、图标、比例、参考水温和时间。
- **本地保存**：杯子设置、已存配方和最近草稿保存在 Mac 上，应用不发起网络请求。
- **原生界面**：使用 SwiftUI 和 AppKit，适配“减少动态效果”，无第三方依赖。

## 快速开始

### 下载安装包

从 [GitHub Releases](https://github.com/Pommissarzhu/Tea-Panel/releases) 下载 `Tea-Panel-<版本号>-Apple-Silicon.dmg`。打开磁盘映像，将**茶伴**拖入 **Applications**，再从“应用程序”启动。安装包不需要 Xcode 或 Command Line Tools。

当前安装包使用临时签名（ad hoc），尚未进行 Developer ID 签名和 Apple 公证。首次打开时，macOS 可能要求在“系统设置 → 隐私与安全性”中允许打开。

### 从源码构建

- **Apple Silicon** Mac，运行 **macOS 13 Ventura 或更高版本**。
- Xcode Command Line Tools，包含 **Swift 6** 编译器和 macOS SDK。

尚未安装 Command Line Tools 时，先运行 `xcode-select --install`。

克隆或下载仓库，在仓库根目录打开终端并运行：

```sh
zsh build.sh --run
```

脚本会生成并打开 `build/Tea Panel.app`。也可用 `zsh build.sh` 只构建，再自行打开，或将应用复制到“应用程序”目录。启动后菜单会展开，之后点击菜单栏图标即可再次打开。

构建脚本目前仅面向 `arm64`，本地构建和 GitHub Actions 安装包均使用临时签名（ad hoc）。

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

当前测试包括 **193 项核心检查**和 **68 项动效与菜单栏检查**。全屏、多显示器和实际合盖唤醒仍需对应环境下的交互验收。代码结构和验证范围见[贡献指南](CONTRIBUTING.md)。

推送与应用版本一致的 `v<版本号>` 标签后，GitHub Actions 会运行核心检查、编译、校验签名、打包 DMG，并发布到 GitHub Releases。也可在 Actions 中手动运行 **Build and Release**，仅生成可下载的构建产物。发布步骤见[贡献指南](CONTRIBUTING.md#releases)。

```text
.
├── .github/workflows/ # GitHub Actions 自动打包与发布
├── Sources/          # SwiftUI 界面、AppKit 集成、计时逻辑和动效
├── Resources/        # 应用元数据和当前图标
├── Tests/            # 核心逻辑及窗口回归检查
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
| [产品方案](docs/product-plan.zh-CN.md) | 首版产品约定 |
| [历史验收记录](docs/verification.zh-CN.md) | 既有测试与界面检查结果 |
| [图标设计](docs/design/app-icon.zh-CN.md) | 当前图标来源及独立的设计提案 |

退出应用会结束当前泡茶会话。重新打开时保留偏好设置，正在进行的计时不会恢复。

## 许可证

茶伴（Tea Panel）的原创代码、文档和应用图形采用 [MIT License](LICENSE)。
