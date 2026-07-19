# P2P 聊天（Flutter 版）

**点对点聊天，无需服务器中转消息。** 基于 Flutter + Dart 实现，支持两种模式：

- 🔎 **局域网模式**：UDP 广播发现（端口 `5005`）+ TCP 直连收发（端口 `5006`），纯 P2P，完全不经任何服务器
- 🌐 **跨网模式**：WebRTC 数据通道 + Firebase 信令。**信令只交换连接握手，聊天消息端到端直连加密，不经过服务器**，因此即使双方在不同 WiFi / 不同网络也能聊
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
│   ├── firebase_options.dart       # Firebase 配置模板（⚠️ 需填真实值）
│   ├── services/
│   │   ├── p2p_service.dart        # ⭐ 核心：双模式（LAN + WAN）调度
│   │   ├── signaling_service.dart  # Firebase 信令（仅转发握手）
│   │   └── webrtc_transport.dart   # WebRTC 数据通道封装
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

### 局域网模式（同 WiFi，纯直连）
1. 把 APK 装到两台（或多台）安卓手机
2. **确保连同一个 WiFi（同一网段）**
3. 打开 App → 输入昵称 → 选「局域网」→ 自动发现对方设备
4. 点对方设备 → 开始聊天

> 若 UDP 广播被路由器隔离（AP 隔离），可用「手动输入对方 IP」直接连。

### 跨网模式（不同 WiFi / 不同网络）
> 首次使用需先 [配置 Firebase](#配置-firebase跨网模式需要)。

1. 双方打开 App → 输入昵称 → 选「跨网」
2. 一方点「创建房间」，得到 6 位房间号，发给对方
3. 另一方在「输入对方房间号」处填入，点「加入」
4. 连接建立后即可聊天——消息走端到端加密直连，**不经任何服务器**

---

## 配置 Firebase（跨网模式需要）

跨网模式用 Firebase Realtime Database 作为「信令通道」，只转发 WebRTC 握手包，不碰聊天内容。

1. 打开 https://console.firebase.google.com → **添加项目**
2. 项目内 → **构建 → Realtime Database → 创建数据库**（地理位置选就近区域）
3. 项目设置（⚙️）→ **你的应用 → 添加应用（Android）**
   - 包名填 `com.example.p2pchat`（须与 `android/app/build.gradle` 的 `applicationId` 一致）
   - 下载 `google-services.json`，放到 `android/app/google-services.json`
4. 项目设置里**复制**应用配置：`apiKey`、`applicationId`（形如 `1:123:android:abc`）、`projectId`、`databaseURL`
5. 打开 `lib/firebase_options.dart`，把全部 `YOUR_XXX` 占位替换成真实值（**务必填 `databaseURL`**）
6. 重新 `flutter pub get` → `flutter build apk`（或推送 GitHub 自动打包）

> 开发期数据库规则（Realtime Database → Rules）可临时设为可读写：
> `{ "rules": { ".read": true, ".write": true } }`；正式发布请收紧并加鉴权。

---

## 排错

| 现象 | 可能原因 | 解决 |
|------|---------|------|
| 发现不了设备 | 不在同一 WiFi / AP 隔离 | 用「手动连接」输入对方 IP；关闭 AP 隔离 |
| 发送失败 | 对方离线 / 端口被拦 | 确认双方都在线、未装防火墙类 App |
| 首次打包很慢 | 下载 Gradle/SDK | 正常现象，后续会缓存 |
| 低版本安卓无图标 | 仅矢量图标 | 已用 `@drawable/ic_launcher` 矢量，API 21+ 正常显示 |
| 跨网创建/加入失败 | Firebase 未配置或房间号错 | 见「配置 Firebase」一节；确认双方房间号一致 |
| 跨网连不上 | 对称型 NAT 无法打洞 | 公共 STUN 覆盖多数家庭宽带；企业/校园网可能需自建 TURN（进阶） |

---

## 技术说明

- **端口**：UDP 发现 `5005`，TCP 消息 `5006`（可在 `p2p_service.dart` 顶部修改）
- **权限**：`INTERNET` / `ACCESS_NETWORK_STATE` / `ACCESS_WIFI_STATE`，并开启 `usesCleartextTraffic`
- **离线判定**：超过 12 秒未收到广播的对端自动从列表移除
- **扩展**：如需「不依赖路由器」的直连，可后续接入 Wi-Fi Direct（需平台通道调用 `WifiP2pManager`）
