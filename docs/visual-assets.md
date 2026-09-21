# Visual Assets / 视觉资源

MicFirst 的现役 App icon 为 2026-09-21 定稿的「瓷白声浪 · 均衡器版」。菜单栏图标保持原有 template image，不随本次 App icon 更新。

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

![MicFirst menu bar icon preview](assets/audio-input-locker-menu-bar-preview.png)

菜单栏两套 template image 维持现状：直立麦克风，以及带右下角锁头的状态图。使用 alpha mask，由 macOS 处理浅色/深色菜单栏、选中态和高对比度显示。

- `MicFirst/Assets.xcassets/MenuBarIcon.imageset`：普通状态，18/36/54px。
- `MicFirst/Assets.xcassets/MenuBarIconLocked.imageset`：带锁头状态，18/36/54px。
- `docs/assets/audio-input-locker-menu-bar-icon-source.svg`：普通状态源图。
- `docs/assets/audio-input-locker-menu-bar-icon-locked-source.svg`：带锁头源图。
- `docs/assets/audio-input-locker-menu-bar-icon-template.png`、`audio-input-locker-menu-bar-icon-locked-template.png`：文档预览。

## Color Roles

- Porcelain White：主角与底板，柔和暖白。
- Warm Titanium：中等明度暖灰支架、四肢与配角结构。
- Graphite：麦克风格栅等必要深色细节。
- Celadon：低饱和青玉跑道与稍深的均衡器短柱。
- Vermilion：接力棒，白色数字“1”，主要品牌色点。

颜色以批准的 PNG 为准；图标配色不修改应用内系统控件的 accent color。

## Historical Assets

`docs/assets/audio-input-locker-app-icon-256.png` 保留旧版白色麦克风与金色挂锁设计，供历史 AudioInputLocker 页面引用。未使用的旧 1024px 主图与未选中的 MicFirst 候选已按用户要求清理。现役 AppIcon 和中英文 README 使用 MicFirst 新图标。
