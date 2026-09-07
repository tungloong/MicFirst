# FAQ And Troubleshooting

## English

### Does MicFirst record audio?

No. MicFirst does not record, process, upload, or analyze microphone
audio. It uses Core Audio to list input devices, switch the system default input
device, read/write input volume when supported, and observe device changes.

### Why does a device have no volume slider?

Some input devices do not expose a writable input-volume control through Core
Audio. MicFirst enables the slider only when macOS reports that the device
supports it.

### Does input priority work with AirPods and USB microphones?

It is designed for that workflow. While Input Priority is on, the app uses the
first available device in the saved order and restores it after external changes. Behavior can still vary by device firmware and macOS routing rules.

### Does the app need microphone permission?

The app does not record audio, so it is not expected to request microphone
recording permission. It manages device selection through Core Audio.

### Why does macOS warn about the preview download?

The current GitHub preview build is not notarized. Build from source or wait for
a notarized/App Store release if you prefer the normal Gatekeeper path.

### What should I include in a bug report?

Include your macOS version, Mac model, app version or commit, involved audio
devices, steps to reproduce, expected behavior, and actual behavior.

## 简体中文

### MicFirst 会录音吗？

不会。MicFirst 不会录制、处理、上传或分析麦克风音频。它只使用
Core Audio 列出输入设备、切换系统默认输入、在设备支持时读写输入音量，并监听设备变化。

### 为什么某些设备没有音量滑杆？

有些输入设备没有通过 Core Audio 暴露可写的输入音量控制。只有 macOS 报告该设备支持时，MicFirst 才会启用滑杆。

### 输入优先级支持 AirPods 和 USB 麦克风吗？

这是它主要想解决的场景之一。输入优先级开启时，App 始终选择排序最靠前的可用设备；其他进程改变默认输入后会自动恢复。实际表现仍可能受设备固件和 macOS 路由规则影响。

### app 需要麦克风权限吗？

app 不录音，因此正常情况下不需要请求麦克风录制权限。它通过 Core Audio 管理设备选择。

### 为什么 macOS 会警告 GitHub preview 下载？

当前 GitHub preview build 尚未 notarize。你可以从源码构建，或者等待后续 notarized / App Store 版本。

### 报 bug 时应该提供什么？

请提供 macOS 版本、Mac 机型、app 版本或 commit、相关音频设备、复现步骤、预期行为和实际行为。
