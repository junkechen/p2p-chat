# P2P 聊天（Flutter 版）

**点对点聊天，无需服务器。** 基于 Flutter + Dart 原生 `dart:io` Socket 实现：

- 🔎 **设备发现**：UDP 广播（端口 `5005`），每 2 秒播一次，自动维护在线列表
- 💬 **消息传输**：TCP 直连（端口 `5006`），短连接收发，无中间服务器
- 📱 **屏幕适配**：`MediaQuery` + 相对布局，自适应不同尺寸/分辨率安卓机
- 🤖 **自动打包**：推送 GitHub 即触发云端构建 APK（GitHub Actions）

> 与旧版（Kivy/Python）不同，本版用 Flutter 重写，原生性能、UI 更顺滑、`flutter build apk` 一键出包。

---

## 项目结构

```
p2p_chat_flutter/
├── lib/
│   ├── main.dart                  # 入口 + MaterialApp
│   ├── models/
│   │   ├── device.dart            # PeerDevice（在线对端）
│   │   └── message.dart           # ChatMessage（消息）
│   ├── services/
│   │   └── p2p_service.dart       # ⭐ 核心：UDP发现 + TCP传输（单例）
│   ├── screens/
│   │   ├── setup_screen.dart      # ① 输入昵称
│   │   ├── discovery_screen.dart  # ② 发现设备 + 手动连接
│   │   └── chat_screen.dart       # ③ 聊天页
│   └── widgets/
│       └── message_bubble.dart    # 聊天气泡（左右分布）
├── android/                       # 原生配置（含网络权限/明文放行/图标）
├── .github/workflows/
│   └── build_apk.yml              # ⭐ 云端自动打包
├── pubspec.yaml
└── README.md
```

---

## 本地打包（有 Flutter 环境）

```bash
# 1. 安装依赖
flutter pub get

# 2. 连上手机或开模拟器，调试运行
flutter run

# 3. 出正式包（debug 签名）
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

> 首次 `flutter build` 会下载 Gradle/SDK，较慢；之后每次几分钟。

---

## 自动打包（GitHub Actions，推荐）

无需本地装 Flutter，推送代码即出包：

```bash
# 1. 在 GitHub 新建仓库（如 p2p-chat），然后关联
cd p2p_chat_flutter
git remote add origin https://github.com/<你的用户名>/p2p-chat.git
git push -u origin master

# 2. 打开 GitHub → Actions 标签页 → 等构建完成
# 3. 在 Artifacts 区下载 p2p-chat-apks（含 debug + release 两个 APK）
```

**自动流程**：`push` → 启动 Ubuntu 云机 → 装 Flutter/Java → `pub get` → 构建 → 上传 APK。

---

## 使用方式

1. 把 APK 装到两台（或多台）安卓手机
2. **确保连同一个 WiFi（同一网段）**
3. 打开 App → 输入昵称 → 自动发现对方设备
4. 点对方设备 → 开始聊天

> 若 UDP 广播被路由器隔离（AP 隔离），可用「手动输入对方 IP」直接连。

---

## 排错

| 现象 | 可能原因 | 解决 |
|------|---------|------|
| 发现不了设备 | 不在同一 WiFi / AP 隔离 | 用「手动连接」输入对方 IP；关闭 AP 隔离 |
| 发送失败 | 对方离线 / 端口被拦 | 确认双方都在线、未装防火墙类 App |
| 首次打包很慢 | 下载 Gradle/SDK | 正常现象，后续会缓存 |
| 低版本安卓无图标 | 仅矢量图标 | 已用 `@drawable/ic_launcher` 矢量，API 21+ 正常显示 |

---

## 技术说明

- **端口**：UDP 发现 `5005`，TCP 消息 `5006`（可在 `p2p_service.dart` 顶部修改）
- **权限**：`INTERNET` / `ACCESS_NETWORK_STATE` / `ACCESS_WIFI_STATE`，并开启 `usesCleartextTraffic`
- **离线判定**：超过 12 秒未收到广播的对端自动从列表移除
- **扩展**：如需「不依赖路由器」的直连，可后续接入 Wi-Fi Direct（需平台通道调用 `WifiP2pManager`）
