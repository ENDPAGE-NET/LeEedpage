import { useMemo, useState } from 'react';
import { Outlet, useLocation, useNavigate, Navigate } from 'react-router-dom';
import {
  Avatar,
  Button,
  Dropdown,
  Layout,
  Menu,
  Result,
  Tag,
  Typography,
  theme,
} from 'antd';
import {
  ClockCircleOutlined,
  DashboardOutlined,
  FileTextOutlined,
  LogoutOutlined,
  MenuFoldOutlined,
  MenuUnfoldOutlined,
  SettingOutlined,
  UserOutlined,
} from '@ant-design/icons';
import dayjs from 'dayjs';

import { useAuthStore } from '../../store/auth';

const { Header, Sider, Content } = Layout;

const routeMeta: Record<string, { title: string; subtitle: string }> = {
  '/dashboard': {
    title: '仪表盘',
    subtitle: '集中查看今日人力状态、打卡趋势和异常波动。',
  },
  '/users': {
    title: '用户管理',
    subtitle: '管理员工账号、头像、人脸资料与启用状态。',
  },
  '/attendance': {
    title: '考勤记录',
    subtitle: '按日期快速检索签到签退、位置校验和异常记录。',
  },
  '/leave': {
    title: '请假审批',
    subtitle: '统一处理请假流转，保持审批节奏与留痕。',
  },
  '/rules': {
    title: '打卡规则',
    subtitle: '按员工或批量配置时间、地点和工作日要求。',
  },
};

export default function AdminLayout() {
  const [collapsed, setCollapsed] = useState(false);
  const navigate = useNavigate();
  const location = useLocation();
  const { user, loading, logout } = useAuthStore();
  const { token } = theme.useToken();

  if (!loading && !user) {
    return <Navigate to="/login" replace />;
  }

  if (!loading && user && user.role !== 'admin') {
    return (
      <Result
        status="403"
        title="权限不足"
        subTitle="仅管理员可访问管理后台，员工请使用移动端进行打卡。"
        extra={
          <Button
            type="primary"
            onClick={() => {
              logout();
              navigate('/login');
            }}
          >
            返回登录
          </Button>
        }
      />
    );
  }

  const selectedKey = useMemo(() => {
    if (location.pathname.startsWith('/rules/')) {
      return '/rules';
    }
    return location.pathname;
  }, [location.pathname]);

  const headerMeta = routeMeta[selectedKey] ?? {
    title: '管理后台',
    subtitle: '保持人员、规则与记录处于一致的管理视图。',
  };

  const menuItems = [
    { key: '/dashboard', icon: <DashboardOutlined />, label: '仪表盘' },
    { key: '/users', icon: <UserOutlined />, label: '用户管理' },
    { key: '/attendance', icon: <ClockCircleOutlined />, label: '考勤记录' },
    { key: '/leave', icon: <FileTextOutlined />, label: '请假审批' },
    { key: '/rules', icon: <SettingOutlined />, label: '打卡规则' },
  ];

  const userMenuItems = [
    {
      key: 'logout',
      icon: <LogoutOutlined />,
      label: '退出登录',
      onClick: () => {
        logout();
        navigate('/login');
      },
    },
  ];

  return (
    <Layout style={{ minHeight: '100vh', background: 'transparent' }}>
      <Sider
        trigger={null}
        collapsible
        collapsed={collapsed}
        width={280}
        collapsedWidth={92}
        theme="light"
        style={{
          background: 'transparent',
          padding: 18,
        }}
      >
        <div
          style={{
            height: '100%',
            borderRadius: 32,
            background: 'rgba(255,255,255,0.74)',
            backdropFilter: 'blur(18px)',
            boxShadow: token.boxShadow,
            padding: collapsed ? 14 : 18,
            display: 'flex',
            flexDirection: 'column',
            gap: 18,
          }}
        >
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: collapsed ? 0 : 14,
              justifyContent: collapsed ? 'center' : 'flex-start',
              minHeight: 72,
            }}
          >
            <div className="brand-badge">{collapsed ? 'EA' : '熵'}</div>
            {!collapsed ? (
              <div>
                <Typography.Text style={{ display: 'block', fontWeight: 800, fontSize: 18 }}>
                  熵析云枢
                </Typography.Text>
                <Typography.Text type="secondary" style={{ fontSize: 12, letterSpacing: 1.4 }}>
                  ADMIN CONSOLE
                </Typography.Text>
              </div>
            ) : null}
          </div>

          {!collapsed ? (
            <div
              style={{
                borderRadius: 24,
                padding: 16,
                background:
                  'linear-gradient(145deg, rgba(11,77,155,0.10), rgba(255,255,255,0.7) 55%, rgba(255,255,255,0.92))',
              }}
            >
              <Typography.Text style={{ display: 'block', fontWeight: 700, marginBottom: 6 }}>
                管理工作区
              </Typography.Text>
              <Typography.Text type="secondary" style={{ fontSize: 13, lineHeight: 1.6 }}>
                用更轻的界面密度处理更重的日常管理任务。
              </Typography.Text>
            </div>
          ) : null}

          <Menu
            mode="inline"
            selectedKeys={[selectedKey]}
            items={menuItems}
            onClick={({ key }) => navigate(key)}
            style={{
              border: 0,
              background: 'transparent',
              flex: 1,
            }}
          />

          {!collapsed ? (
            <div
              style={{
                borderRadius: 24,
                padding: 16,
                background: '#f8fafc',
                border: `1px solid ${token.colorBorderSecondary}`,
              }}
            >
              <Typography.Text type="secondary" style={{ display: 'block', fontSize: 12 }}>
                今日日期
              </Typography.Text>
              <Typography.Text style={{ display: 'block', marginTop: 4, fontWeight: 700 }}>
                {dayjs().format('YYYY 年 MM 月 DD 日')}
              </Typography.Text>
            </div>
          ) : null}
        </div>
      </Sider>

      <Layout style={{ background: 'transparent' }}>
        <Header
          style={{
            height: 96,
            lineHeight: 1,
            padding: '18px 26px 0 10px',
            background: 'transparent',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'flex-start',
          }}
        >
          <div style={{ display: 'flex', gap: 14, alignItems: 'center' }}>
            <Button
              type="text"
              shape="circle"
              size="large"
              icon={collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />}
              onClick={() => setCollapsed((value) => !value)}
              style={{
                background: 'rgba(255,255,255,0.72)',
                backdropFilter: 'blur(16px)',
                boxShadow: token.boxShadowSecondary,
              }}
            />
            <div>
              <Typography.Title level={2} style={{ margin: 0, fontSize: 30, letterSpacing: -1.2 }}>
                {headerMeta.title}
              </Typography.Title>
              <Typography.Text type="secondary" style={{ display: 'block', marginTop: 6 }}>
                {headerMeta.subtitle}
              </Typography.Text>
            </div>
          </div>

          <Dropdown menu={{ items: userMenuItems }} placement="bottomRight">
            <div
              style={{
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: 12,
                padding: '12px 14px',
                borderRadius: 999,
                background: 'rgba(255,255,255,0.72)',
                backdropFilter: 'blur(16px)',
                boxShadow: token.boxShadowSecondary,
              }}
            >
              <Avatar size={42} style={{ backgroundColor: token.colorPrimary }}>
                {user?.full_name?.[0] || 'A'}
              </Avatar>
              <div style={{ lineHeight: 1.2 }}>
                <Typography.Text style={{ display: 'block', fontWeight: 700 }}>
                  {user?.full_name || '管理员'}
                </Typography.Text>
                <Tag color="blue" bordered={false} style={{ marginTop: 6 }}>
                  管理员
                </Tag>
              </div>
            </div>
          </Dropdown>
        </Header>

        <Content style={{ padding: '8px 26px 26px 10px' }}>
          <div
            className="surface-panel"
            style={{
              minHeight: 'calc(100vh - 130px)',
              padding: 24,
            }}
          >
            <Outlet />
          </div>
        </Content>
      </Layout>
    </Layout>
  );
}
