# 熵析云枢 - 后端服务

FastAPI 后端，提供 RESTful API 供 Web 管理端和 Flutter 移动端调用。

## 环境要求
- Python 3.12+

## 安装与运行

```bash
# 安装依赖
pip install -r requirements.txt

# 如需人脸识别，额外安装
pip install insightface onnxruntime

# 启动开发服务器
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

首次启动自动创建 SQLite 数据库和默认管理员 `admin / admin123`。

## API 文档
启动后访问 http://localhost:8000/docs

## 目录结构
```
app/
├── main.py              # 应用入口
├── config.py            # 配置
├── dependencies.py      # 认证依赖注入
├── models/              # ORM 模型 (user, face_data, checkin_rule, attendance)
├── schemas/             # Pydantic 请求/响应
├── api/                 # 路由 (auth, users, rules, attendance, face, activation)
├── services/            # 业务逻辑 (face_service, location_service)
└── core/                # 基础设施 (database, security, exceptions)
```

## 核心 API

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/v1/auth/login | 登录 |
| POST | /api/v1/auth/change-password | 修改密码 |
| GET/POST | /api/v1/users | 用户列表/创建 |
| POST | /api/v1/users/{id}/reset-password | 重置密码 |
| DELETE | /api/v1/users/{id}/face | 重置人脸 |
| PUT | /api/v1/rules/users/{id} | 配置打卡规则 |
| POST | /api/v1/face/register | 注册人脸 |
| POST | /api/v1/activation/complete | 激活账户 |
| POST | /api/v1/attendance/checkin | 签到 |
| POST | /api/v1/attendance/checkout | 签退 |
| GET | /api/v1/attendance/statistics | 统计数据 |

## 环境变量
复制 `.env.example` 为 `.env`，生产环境务必修改 `SECRET_KEY`。
