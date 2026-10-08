# Visual Assets / 视觉资源

MicFirst 的现役 App icon 为 2026-09-21 定稿的「瓷白声浪 · 均衡器版」。菜单栏图标于 2026-10-07 接入原生系统符号和自定义 SF Symbols symbolset，与 App icon 独立。

## App Icon

![MicFirst app icon](assets/micfirst-app-icon-256.png)

前景麦克风手持朱红色“1”号接力棒，领先后方的耳机和音箱，表达 MicFirst 的首选输入身份。瓷白主角、暖灰钛色肢体、低饱和青玉跑道与少量朱红构成配色；跑道只保留前后两组均衡器短柱，横向于局部行进方向，避免装饰纹样混杂。

耳机、音箱是竞速构思中的音频设备配角，不表示 MicFirst 管理输出设备。应用功能仍为输入设备优先级选择、回退与恢复。

Files:

- `docs/assets/micfirst-app-icon.png`：正式 1024px 透明 PNG。
- `docs/assets/micfirst-app-icon-256.png`：中英文 README 使用的 256px 透明 PNG。
- `MicFirst/Assets.xcassets/AppIcon.appiconset`：现有 10 个 macOS 槽位，覆盖 16–1024 实际像素，兼容应用 macOS 13 部署目标。
- [设计交付记录](design/app-icon/releases/1.0/README.md)：正式资源、导出参数与验证结果。
- [选定原图与提示词](design/app-icon/2026-09-21-porcelain-equalizer/README.md)：保留未经修改的 imagegen 输出和完整实际提示词。
- [探索索引](design/app-icon/README.md)：历轮候选与取舍。

## Production Export

在仓库根目录运行：

```sh
swift scripts/export-app-icon.swift
```

导出使用 macOS Core Graphics 与 ImageIO，只规范化生成图的 alpha、按实际非透明边界取图、统一留白并缩放，不重新绘制已选定图案。alpha ≤ 8 的外缘残留清零，alpha ≥ 240 的内部恢复完全不透明，中间保留抗锯齿过渡；同时保持直通 RGB 颜色。

按当前图像实际边界保持长宽比例，将底板最长边置于 1024 画布的 824px 范围内并居中。各槽位直接从规范化后的原图导出，避免逐级缩放。完整参数见交付目录的 `export-report.json`。

16/32px 下以麦克风轮廓和朱红色点作为识别依据，配角、短柱和数字不保证可辨。本轮未另行设计小尺寸简化符号。菜单栏使用独立的单色图标，不依赖 App icon 缩小。

## Menu Bar Icon

现役菜单栏有九个视觉状态：音量未知时区分普通麦克风／带锁麦克风；已知为零时共用原生静音麦克风；低、中、高音量分别有无锁和带锁版本。锁表示自动输入优先级已开启。这里的音量来自设备的输入音量属性，不是采集音频得到的实时电平。

![Compiled MicFirst menu symbols, light appearance](design/status-hud/2026-10-07-native-symbols/evidence/nine-states-light.png)

浅色和深色使用同一组单色符号，由系统着色。三档声波通过 Variable Color 阈值激活：低档一条，中档两条，高档三条；未激活的声波保留系统的淡色显示。缺失、不合法或读取失败的音量保持未知；禁用的滑块可以显示零占位，但不会把菜单栏状态变为静音。

- 系统 `mic.fill`（新版名称 `microphone.fill`）：未知、自动优先级关闭。
- 系统 `mic.slash.fill`（新版名称 `microphone.slash.fill`）：已知音量为零，两种开关状态共用。
- `MicFirst/Assets.xcassets/MenuBarMicrophoneUnknownLocked.symbolset`：未知、自动优先级开启。
- `MicFirst/Assets.xcassets/MenuBarMicrophoneVolume.symbolset`：已知非零音量、自动优先级关闭。
- `MicFirst/Assets.xcassets/MenuBarMicrophoneVolumeLocked.symbolset`：已知非零音量、自动优先级开启。
- `scripts/generate-menu-bar-symbols.py`：从保留的 Apple 导出模板构建三份主符号与六份独立波纹资源，采用 SF Symbols 7 格式及原生 Draw 注解，包含 Ultralight／Regular／Black 三个 Small master。
- [接入与验证记录](design/status-hud/2026-10-07-native-symbols/README.md)：九态映射、浅深渲染、真实按钮捕获，以及菜单栏转场的实测限制。

SwiftUI `MenuBarExtra` 继续拥有菜单栏项和 `.window` 菜单。macOS 26+ 的 `MenuBarSymbolRenderer` 只向 MicFirst 自己的公开 `NSStatusBarButton` 加入实时 `NSImageView`；透明、固定尺寸的标签图保留系统注册与布局，原按钮继续处理点击和辅助功能。实时视图播放原生 Draw On／反向 Draw Off：只绘入新增波纹或收回减少的波纹，麦克风和已有波纹保持稳定；灰色波纹留在底层。静音／未知／锁变化请求原生 Magic Replace，以普通 Replace 回退。macOS 26 以下及 Reduce Motion 使用静态更新。这个窄范围桥接解决了 `MenuBarExtra` 将 SwiftUI 标签转成静态 `NSImage`、标签上的动画没有传到菜单栏的限制。

已定位到可见、具有正高度和屏幕坐标的系统状态按钮，其 20 ms 连续缓存渲染记录到路径中间帧；Reduce Motion 对照保持单一目标帧。证据、时序及限制见接入记录。这些是自有实时按钮的渲染采样，仍不等于显示器合成视频，2026-10-08 用户已在实际菜单栏认可统一 0.8 倍速度的观感；尚未与系统音量菜单做逐帧时序对照。菜单点击、高亮及多显示器行为未在此次动画确认中验收。没有根据系统音量的外观推断其内部实现；Draw On／Off 与 Variable Draw 的区别遵循 [Apple 的 SF Symbols 7 说明](https://developer.apple.com/videos/play/wwdc2025/337/)。

早期的数字「1」、跑步人物、七态 PNG 等保留为设计探索；`MenuBarIcon.imageset`、`MenuBarIconLocked.imageset` 与 `docs/assets/audio-input-locker-menu-bar-*` 是旧 template image，现役菜单栏已不再引用。

## HUD 插画

HUD 在 34 pt 使用两态麦克风吉祥物：开启为拿「1」号接力棒跑步的小人，关闭为坐在方块上翘二郎腿、双手抱臂、接力棒横放地面等候。输入优先级关闭时随锁按钮一起切换，不改动文案、胶囊尺寸或出现逻辑。

- `docs/design/status-hud/2026-10-07/runner/hud-microphone.png`：开启态原始 PNG。
- `docs/design/status-hud/2026-10-07-arms-folded/disabled/hud-microphone.png`：关闭态原始 PNG。
- `scripts/export-hud-microphone.py`：从上述已批准 PNG 生成 `HUDMicrophoneEnabled` 与 `HUDMicrophoneDisabled` 两个 imageset（1x/2x/3x）。只规范化 alpha 并按 34 pt 缩放，不重绘、不裁切、不改变构图。
- 两态对照与浅深背景检查：`docs/design/status-hud/2026-10-07-arms-folded/states-comparison.png`。

更早的 `MicFirst/HUDMicrophone.png`（普通桌面麦克风、无状态区分）属于 AudioInputLocker 时期，已随本次接入移除。

## Color Roles

- Porcelain White：主角与底板，柔和暖白。
- Warm Titanium：中等明度暖灰支架、四肢与配角结构。
- Graphite：麦克风格栅等必要深色细节。
- Celadon：低饱和青玉跑道与稍深的均衡器短柱。
- Vermilion：接力棒，白色数字“1”，主要品牌色点。

颜色以批准的 PNG 为准；图标配色不修改应用内系统控件的 accent color。

## Historical Assets

`docs/assets/audio-input-locker-app-icon-256.png` 保留旧版白色麦克风与金色挂锁设计，供历史 AudioInputLocker 页面引用。未使用的旧 1024px 主图与未选中的 MicFirst 候选已按用户要求清理。现役 AppIcon 和中英文 README 使用 MicFirst 新图标。

## README Screenshots

`docs/assets/screenshots/micfirst-{menu,settings,hud}-{en,zh}.png` 是中英文 README 和 GitHub Release 使用的现役截图。它们由 Debug 构建的 `--priority-preview --export-screenshots <目录>` 用模拟设备离屏渲染，不含真实设备名或桌面内容。同目录下的 `menu-popover.png` 与 `restore-hud.png` 是 AudioInputLocker 的历史截图，不代表 MicFirst 界面。

## Mac App Store Badge

`docs/assets/mac-app-store-badge-{en,zh-cn}.svg` 是 Apple 官方“Download on the Mac App Store”黑色徽章，未经修改，分别供英文和中文 README 使用。来源为 `https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-mac-app-store/black/{en-us,zh-cn}`。徽章存放在仓库内，因为 GitHub 的图片代理拉不到旧的 `tools.applemarketingtools.com` 外链。

中文 README 链接到 `/cn/` 商店页面：中国大陆直连 `apps.apple.com` 时，其他地区的链接会被重定向到 `/cn` 首页。英文 README 使用不带地区的链接（`apps.apple.com/app/micfirst/id…`），由 Apple 按访问者地区定向，并附一个中国大陆链接。

当前菜单栏图标保留 16 pt／small 配置，动画速度 0.8。macOS 26+ 占位图宽 18 pt，本机按钮总宽实测 34 pt。六个带声波状态统一右移 2 pt；静音与未知状态不偏移。水平微调已固化，临时调节控件已移除。
