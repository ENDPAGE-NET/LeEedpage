# 熵析云枢 - Web 管理端

React + Vite + Ant Design 构建的企业考勤管理后台。

## 环境要求
- Node.js 18+
- npm 9+

## 安装与运行

```bash
# 安装依赖
npm install

# 启动开发服务器（端口 3000，自动代理 /api 到后端 8000）
npm run dev

# 生产构建
npm run build
```

确保后端已在 http://localhost:8000 启动。

## 功能页面
- **登录页** — 管理员登录
- **仪表盘** — 考勤统计概览（签到/迟到/早退数据）
- **用户管理** — 新建/编辑/禁用用户、重置密码、重置人脸
- **打卡规则** — 为每个用户配置地点要求（经纬度+半径）和时间要求
- **考勤记录** — 查看所有员工打卡明细，按日期筛选

## 目录结构
```
src/
├── api/            # Axios API 调用 (client, auth, users, rules, attendance)
├── components/     # 可复用组件 (Layout/AdminLayout)
├── pages/          # 页面
│   ├── Login.tsx
│   ├── Dashboard/
│   ├── Users/UserList.tsx
│   ├── Rules/RuleConfig.tsx
│   └── Attendance/Records.tsx
├── store/          # Zustand 状态管理 (auth)
├── types/          # TypeScript 类型定义
├── router.tsx      # 路由配置
└── App.tsx         # 应用入口
```

## 默认账户
- 用户名: `admin`
- 密码: `admin123`
