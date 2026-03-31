# 熵析云枢 - Flutter 移动端

Flutter 构建的考勤打卡 App，支持 Android、iOS 和 Windows 桌面。

---

## 环境要求

- **Flutter SDK** 3.22+（含 Dart 3.5+）
- Windows 需开启 **开发者模式**（系统设置 → 隐私和安全性 → 开发者选项 → 开启）

### 可选（按运行方式选择）

| 运行方式 | 需要安装 | 说明 |
|----------|---------|------|
| **Windows 桌面** | 无需额外安装 | 最简单，直接在电脑上弹窗运行 |
| **Chrome 浏览器** | Chrome | 浏览器中运行，相机/GPS 功能受限 |
| **Android 真机** | USB 驱动 | 手机开启 USB 调试，数据线连接 |
| **Android 模拟器** | Android Studio 或 Android SDK | 需要模拟器镜像 |
| **iOS** | macOS + Xcode | Windows 无法编译 iOS |

---

## 安装与运行

### 1. 安装依赖

```bash
cd mobile
flutter pub get
```

### 2. 检查环境

```bash
flutter doctor
```

输出中只要有一个 `[✓]` 的目标平台即可运行。

### 3. 选择运行方式

#### 方式 A：Windows 桌面（推荐，无需模拟器）

```bash
flutter run -d windows
```

会弹出一个桌面窗口运行 App，所有 UI 和功能与手机端完全一致。
适合开发调试，**不需要 Android Studio 或 Xcode**。

#### 方式 B：Chrome 浏览器

```bash
flutter run -d chrome
```

注意：Web 模式下相机和定位行为与原生有差异。

#### 方式 C：Android 真机

1. 手机进入 **设置 → 关于手机 → 连续点击版本号 7 次** 开启开发者选项
2. 进入 **开发者选项 → 开启 USB 调试**
3. 用数据线连接电脑
4. 运行：

```bash
flutter devices     # 确认手机被识别
flutter run         # 自动编译并安装到手机
```

#### 方式 D：打包 APK 安装

```bash
flutter build apk --release
```

生成的 APK 在 `build/app/outputs/flutter-apk/app-release.apk`，
可直接传到 Android 手机安装。

---

## 连接后端

编辑 `lib/config/app_config.dart` 修改 API 地址：

```dart
class AppConfig {
  // 根据运行环境选择一个取消注释：
  static const String apiBaseUrl = 'http://10.0.2.2:8000/api/v1';         // Android 模拟器
  // static const String apiBaseUrl = 'http://localhost:8000/api/v1';      // iOS 模拟器 / Windows 桌面
  // static const String apiBaseUrl = 'http://192.168.1.xxx:8000/api/v1'; // 真机（替换为电脑局域网 IP）
}
```

**查看电脑局域网 IP**：在终端运行 `ipconfig`，找到 `IPv4 地址`。

**注意**：后端需要启动在 `0.0.0.0`（而非 `127.0.0.1`），真机才能访问：

```bash
cd backend
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

---

## 功能流程

### 首次登录（新员工）

```
输入账号密码 → 检测到"待激活"状态 → 进入设置向导
    ↓
步骤1: 修改密码（必须修改初始密码）
    ↓
步骤2: 注册人脸（前置摄像头拍 1-3 张照片，上传后端提取特征向量）
    ↓
步骤3: 点击"激活账户" → 状态变为 active → 进入主页
```

### 日常打卡

```
主页 → 点击"签到"大按钮
    ↓
自动打开前置摄像头拍照 + 获取 GPS 坐标
    ↓
上传到后端 → 人脸比对（余弦相似度 ≥ 0.45） + 位置验证（Haversine 距离 ≤ 半径）
    ↓
返回结果：通过/迟到/位置超出范围/人脸不匹配
```

签退流程相同。底部"记录"tab 可查看打卡历史。

---

## 目录结构详解

```
mobile/
├── pubspec.yaml                         # 项目配置 & 依赖声明
├── assets/
│   └── logo.png                         # ENDPAGE 公司 Logo
├── android/                             # Android 原生工程（自动生成，一般不用动）
├── ios/                                 # iOS 原生工程（自动生成）
├── windows/                             # Windows 桌面工程（自动生成）
│
└── lib/                                 # ★ Dart 源码（核心开发目录）
    ├── main.dart                        # 应用入口
    │                                    # - MaterialApp 初始化
    │                                    # - AuthGate：根据登录状态路由
    │                                    #   未登录 → LoginScreen
    │                                    #   待激活 → SetupWizardScreen
    │                                    #   已激活 → HomeScreen
    │
    ├── config/
    │   └── app_config.dart              # 后端 API 地址配置（按环境切换）
    │
    ├── models/                          # 数据模型（对应后端 JSON 响应）
    │   ├── user.dart                    # User 模型：id, username, role, status, has_face...
    │   └── attendance.dart              # AttendanceRecord 模型：face_score, distance_m, is_late...
    │
    ├── services/
    │   └── api_service.dart             # HTTP 请求封装（基于 Dio）
    │                                    # - login / getCurrentUser / changePassword
    │                                    # - registerFace（multipart 上传多张照片）
    │                                    # - checkin / checkout（上传照片 + GPS 坐标）
    │                                    # - getMyAttendance（分页查历史）
    │                                    # - 自动从 SecureStorage 读取 JWT 令牌
    │
    ├── providers/
    │   └── auth_provider.dart           # Riverpod 状态管理
    │                                    # - 管理登录/登出状态
    │                                    # - 持久化 token 到 SecureStorage
    │                                    # - 提供 currentUser 给所有页面
    │
    ├── screens/                         # 页面（每个文件 = 一个完整页面）
    │   ├── login_screen.dart            # 登录页：输入账号密码，调用 login API
    │   ├── home_screen.dart             # 主页：BottomNavigationBar（打卡 / 历史）
    │   ├── checkin_screen.dart          # 打卡页：
    │   │                                # - 签到/签退大按钮
    │   │                                # - 调用 image_picker 打开前置摄像头
    │   │                                # - 调用 geolocator 获取 GPS
    │   │                                # - 显示打卡结果（人脸分数/距离/状态）
    │   ├── history_screen.dart          # 历史记录：列表展示过往打卡明细
    │   └── setup/                       # 首次激活向导（3步流程）
    │       ├── setup_wizard_screen.dart # 向导容器：PageView 控制步骤切换
    │       ├── password_change_screen.dart # 步骤1：修改初始密码
    │       └── face_registration_screen.dart # 步骤2：拍照注册人脸
    │                                    # - 前置摄像头拍 1-3 张
    │                                    # - 网格预览 + 删除
    │                                    # - 上传到后端提取 512 维向量
    │
    └── widgets/                         # 可复用 UI 组件（目前为空，预留扩展）
```

---

## 依赖说明

| 包名 | 版本 | 用途 |
|------|------|------|
| `flutter_riverpod` | 2.6.1 | 状态管理（认证状态、用户信息） |
| `dio` | 5.7.0 | HTTP 客户端（支持 multipart 文件上传） |
| `flutter_secure_storage` | 9.2.4 | 安全存储 JWT token（加密） |
| `image_picker` | 1.1.2 | 调用摄像头拍照（人脸注册 + 打卡） |
| `geolocator` | 13.0.2 | GPS 定位（获取经纬度） |
| `permission_handler` | 11.3.1 | 运行时权限请求（相机、定位） |

---

## 权限说明

App 运行时会请求以下系统权限：

| 权限 | 用途 | 何时请求 |
|------|------|---------|
| 相机 | 人脸拍照（注册 + 每次打卡） | 首次注册人脸 / 首次打卡时 |
| 精确定位 | GPS 坐标用于位置验证 | 首次打卡时 |

如果用户拒绝权限，App 会提示需要授权才能完成操作。

---

## 常见问题

**Q: `flutter run -d windows` 报错？**
A: 确保已开启开发者模式，并运行 `flutter config --enable-windows-desktop`。

**Q: 真机连接后 `flutter devices` 看不到？**
A: 检查 USB 调试是否开启，尝试换数据线（充电线可能不支持数据传输）。

**Q: 打卡时提示"人脸验证未通过"？**
A: 确保后端已安装 `insightface`。未安装时使用随机向量，验证不稳定。

**Q: Windows 桌面模式下相机不可用？**
A: `image_picker` 在 Windows 上会弹出文件选择器代替相机，选一张自拍照片即可模拟。
