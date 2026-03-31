# ENDPAGE 熵析云枢打卡系统 - 实施计划

## Context
构建一个完整的企业考勤打卡系统，包含 Web 管理端、Flutter 移动端和后端 API。Web 端供管理员管理账户和配置打卡规则，Flutter 端供员工进行人脸识别打卡。

---

## 技术栈

| 组件 | 技术选型 | 理由 |
|------|----------|------|
| **后端** | Python FastAPI + SQLAlchemy 2.0 | 异步高性能，人脸识别生态好 |
| **数据库** | SQLite | 轻量零配置，单文件部署 |
| **Web 前端** | React + Vite + Ant Design + TypeScript | 企业管理界面成熟方案 |
| **移动端** | Flutter 3.x + Riverpod | 双端统一，状态管理清晰 |
| **人脸识别** | InsightFace (ArcFace) - 服务端 | 512维嵌入向量，余弦相似度匹配 |

---

## 项目结构 (Monorepo)

```
endpage-attendance/
├── .env.example
├── backend/                    # FastAPI 后端
│   ├── alembic/               # 数据库迁移
│   ├── app/
│   │   ├── main.py            # 应用入口
│   │   ├── config.py          # 配置管理
│   │   ├── models/            # ORM 模型 (user, attendance, checkin_rule, face_data)
│   │   ├── schemas/           # Pydantic 请求/响应
│   │   ├── api/               # 路由处理 (auth, users, attendance, rules, face)
│   │   ├── services/          # 业务逻辑 (auth, user, attendance, face, location)
│   │   ├── core/              # 安全、异常、中间件
│   │   └── utils/             # 工具函数
│   └── tests/
├── web/                       # React 管理端
│   └── src/
│       ├── api/               # Axios API 调用
│       ├── components/        # 可复用组件 (Layout, UserForm, AttendanceTable)
│       ├── pages/             # 页面 (Login, Dashboard, Users, Rules, Attendance)
│       ├── hooks/             # 自定义 hooks
│       ├── store/             # 状态管理
│       └── types/             # TypeScript 类型
├── mobile/                    # Flutter 移动端
│   └── lib/
│       ├── models/            # 数据模型
│       ├── services/          # API、相机、定位服务
│       ├── providers/         # Riverpod 状态
│       ├── screens/           # 登录、设置向导、打卡、历史
│       └── widgets/           # 可复用组件
└── docs/
```

---

## 数据库核心表

1. **users** — id, username, hashed_password, full_name, role(admin/employee), status(pending/active/disabled), phone, email
2. **face_data** — user_id, embedding(BLOB, numpy bytes), image_path, is_active
3. **checkin_rules** — user_id, location_required, lat/lng/radius, time_required, checkin_start/end, checkout_start/end, work_days
4. **attendance_records** — user_id, record_date, record_type(checkin/checkout), face_verified, face_score, location_verified, lat/lng, distance_m, is_late, is_early_leave, photo_path
5. **audit_logs** — actor_id, action, target_type, target_id, details(JSON text)

---

## 核心 API 端点

### 认证
- `POST /api/v1/auth/login` — 登录，返回 JWT
- `POST /api/v1/auth/refresh` — 刷新令牌

### 用户管理 (管理员)
- `GET/POST /api/v1/users` — 列表/创建
- `GET/PUT/DELETE /api/v1/users/{id}` — 查看/更新/禁用
- `POST /api/v1/users/{id}/reset-password` — 重置密码
- `DELETE /api/v1/users/{id}/face` — 重置人脸

### 首次激活 (员工)
- `POST /api/v1/activation/change-password` — 修改密码
- `POST /api/v1/activation/register-face` — 注册人脸 (上传3张照片)
- `POST /api/v1/activation/complete` — 标记激活

### 打卡规则 (管理员)
- `GET/PUT /api/v1/users/{id}/rules` — 查看/配置规则

### 考勤
- `POST /api/v1/attendance/checkin` — 签到 (人脸图片 + GPS)
- `POST /api/v1/attendance/checkout` — 签退
- `GET /api/v1/attendance` — 考勤记录 (管理员)
- `GET /api/v1/attendance/me` — 个人记录
- `GET /api/v1/attendance/statistics` — 统计数据

---

## 人脸识别方案

- **全部在服务端处理**，移动端仅拍照上传
- 注册：采集3张照片 → InsightFace 提取3个512维向量 → 取平均 → 序列化为 BLOB 存入 SQLite
- 验证：拍照 → 提取向量 → 从 SQLite 加载存储向量 → numpy 计算余弦相似度 → 阈值 0.45
- 管理员重置人脸：标记旧数据为非活跃，用户状态回退为 pending

---

## 实施顺序

### 阶段一：基础搭建 ✅
1. ✅ 初始化 monorepo 项目结构
2. ✅ 后端：FastAPI 脚手架、SQLite 数据库连接、Alembic 迁移
3. ✅ 后端：用户模型 + 认证端点 (JWT)
4. ✅ 后端：用户 CRUD 端点
5. ✅ Web：Vite + React 脚手架、登录页、认证上下文
6. ✅ Web：用户列表、创建/编辑表单

### 阶段二：规则与考勤核心 ✅
7. ✅ 后端：打卡规则模型 + CRUD 端点
8. ✅ 后端：考勤记录模型 + LocationService (Haversine)
9. ✅ Web：规则配置页（时间选择器）
10. ✅ Web：考勤记录表、基础仪表盘
11. ✅ Flutter：项目脚手架、登录页、认证流程

### 阶段三：人脸识别集成 ✅
12. ✅ 后端：InsightFace + FaceService (BLOB + numpy)
13. ✅ 后端：人脸注册/验证端点（已接入真实 FaceService）
14. ✅ Flutter：相机集成、人脸注册向导
15. ✅ Flutter：打卡页面（相机 + GPS）
16. ✅ Web：人脸重置按钮

### 阶段四：完善与集成（部分完成）
17. ✅ Flutter：打卡历史页
18. ✅ Web：仪表盘图表统计
19. 后端：审计日志
20. 端到端测试
21. 部署配置 (Nginx + HTTPS)

---

## 用户确认
- 界面语言：仅中文
- 人脸识别：基础验证（InsightFace 静态比对）
- 地图服务：高德地图 SDK（Web 端选点 + Flutter 端定位）
- 数据库：SQLite（轻量部署，无需额外服务）

---

## 当前进度
- ✅ 后端 API 全部完成并验证通过（admin/admin123 默认管理员）
- ✅ Web 管理端：登录、用户管理、规则配置、考勤记录、仪表盘
- ✅ Flutter 移动端：登录、首次激活（改密码+人脸注册）、打卡、历史记录
- ✅ InsightFace 人脸识别集成（FaceService 含占位模式）
- ✅ 前后端联调验证通过（后端 :8000，前端 :3000）
- ⏳ 待完成：审计日志、端到端测试、部署配置

---

## 关键文件
- `backend/app/services/face_service.py` — 人脸识别核心逻辑
- `backend/app/services/attendance_service.py` — 打卡业务流程编排
- `backend/app/api/auth.py` — JWT 认证基础
- `mobile/lib/screens/setup/face_registration_screen.dart` — 人脸注册 UX 关键路径
- `web/src/pages/Users/UserList.tsx` — 用户管理主界面
- `web/src/pages/Rules/RuleConfig.tsx` — 规则配置（地图 + 时间）
