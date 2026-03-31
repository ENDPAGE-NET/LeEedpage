# ENDPAGE 熵析云枢打卡系统

企业考勤管理系统，包含 Web 管理端、Flutter 移动端和后端 API。

## 项目结构

```
├── backend/    FastAPI 后端 (Python)
├── web/        Web 管理端 (React + Ant Design)
├── mobile/     Flutter 移动端 (iOS/Android)
└── PLAN.md     开发计划
```

## 快速启动

### 1. 启动后端
```bash
cd backend
pip install -r requirements.txt
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### 2. 启动 Web 管理端
```bash
cd web
npm install
npm run dev
```
浏览器打开 http://localhost:3000

### 3. 启动 Flutter 移动端
```bash
cd mobile
flutter pub get
flutter run
```

## 默认管理员账户
- 用户名: `admin`
- 密码: `admin123`

## 技术栈
- 后端: Python FastAPI + SQLAlchemy + SQLite
- Web: React + Vite + Ant Design + TypeScript
- 移动端: Flutter + Riverpod
- 人脸识别: InsightFace (服务端)
