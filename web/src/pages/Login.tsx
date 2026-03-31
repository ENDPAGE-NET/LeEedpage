import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Alert, Button, Card, Form, Input, Typography, message } from 'antd';
import { LockOutlined, SafetyCertificateOutlined, UserOutlined } from '@ant-design/icons';

import { getCurrentUser, login } from '../api/auth';
import { useAuthStore } from '../store/auth';

export default function Login() {
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');
  const navigate = useNavigate();
  const { setUser } = useAuthStore();

  const onFinish = async (values: { username: string; password: string }) => {
    setLoading(true);
    setErrorMsg('');
    try {
      const res = await login(values);
      localStorage.setItem('access_token', res.access_token);
      localStorage.setItem('refresh_token', res.refresh_token);

      const user = await getCurrentUser();
      if (user.role !== 'admin') {
        localStorage.removeItem('access_token');
        localStorage.removeItem('refresh_token');
        setErrorMsg('权限不足：仅管理员可登录管理后台，员工请使用移动端完成打卡。');
        return;
      }

      setUser(user);
      message.success('登录成功');
      navigate('/dashboard');
    } catch (err: any) {
      const detail = err.response?.data?.detail;
      if (detail === '用户名或密码错误') {
        setErrorMsg('用户名或密码错误，请重新输入。');
      } else if (detail === '账户已禁用') {
        setErrorMsg('该账号已被禁用，请联系管理员处理。');
      } else {
        setErrorMsg(detail || '登录失败，请稍后重试。');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div
      style={{
        minHeight: '100vh',
        display: 'grid',
        placeItems: 'center',
        padding: 24,
        background:
          'radial-gradient(circle at top left, rgba(224,231,255,0.6), transparent 26%), radial-gradient(circle at bottom right, rgba(219,234,254,0.8), transparent 24%), linear-gradient(180deg, #f7f9fd 0%, #f3f6fb 100%)',
      }}
    >
      <div
        style={{
          width: 'min(1080px, 100%)',
          display: 'grid',
          gridTemplateColumns: 'minmax(320px, 460px) minmax(360px, 460px)',
          gap: 24,
        }}
      >
        <div
          style={{
            padding: '32px 24px 32px 6px',
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'space-between',
          }}
        >
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 30 }}>
              <div className="brand-badge">EA</div>
              <div>
                <Typography.Text style={{ display: 'block', fontWeight: 800, fontSize: 20 }}>
                  熵析云枢
                </Typography.Text>
                <Typography.Text type="secondary" style={{ letterSpacing: 2, fontSize: 12 }}>
                  ENTROPY AXIS ADMIN
                </Typography.Text>
              </div>
            </div>

            <Typography.Title
              style={{
                fontSize: 68,
                lineHeight: 0.95,
                letterSpacing: -3,
                marginBottom: 18,
                maxWidth: 420,
              }}
            >
              登录管理台
            </Typography.Title>
            <Typography.Paragraph
              style={{
                color: '#64748b',
                maxWidth: 420,
                fontSize: 16,
                lineHeight: 1.7,
              }}
            >
              用更轻的界面处理日常考勤、规则、人员与审批。当前入口仅向管理员开放。
            </Typography.Paragraph>
          </div>

          <div style={{ display: 'grid', gap: 14 }}>
            <FeatureLine
              title="白色运营工作台"
              description="聚焦结构、节奏和信息密度，而不是杂乱的后台卡片堆叠。"
            />
            <FeatureLine
              title="统一规则与审批"
              description="用户、打卡、请假在同一套管理视图中完成闭环。"
            />
            <Typography.Text type="secondary" style={{ letterSpacing: 2, fontSize: 11, marginTop: 8 }}>
              VERSION 1.0.0 • SECURE INFRASTRUCTURE
            </Typography.Text>
          </div>
        </div>

        <Card
          bordered={false}
          style={{
            borderRadius: 34,
            background: 'rgba(255,255,255,0.84)',
            backdropFilter: 'blur(18px)',
            boxShadow: '0 28px 50px rgba(15, 23, 42, 0.08)',
          }}
          styles={{ body: { padding: 30 } }}
        >
          <div style={{ marginBottom: 28 }}>
            <Typography.Text type="secondary" style={{ fontWeight: 700, letterSpacing: 1.6 }}>
              管理员身份验证
            </Typography.Text>
            <Typography.Title level={3} style={{ marginTop: 10, marginBottom: 6 }}>
              欢迎回来
            </Typography.Title>
            <Typography.Text type="secondary">
              输入管理员账号密码以继续进入后台工作区。
            </Typography.Text>
          </div>

          {errorMsg ? (
            <Alert
              message={errorMsg}
              type="error"
              showIcon
              closable
              onClose={() => setErrorMsg('')}
              style={{ marginBottom: 18, borderRadius: 18 }}
            />
          ) : null}

          <Form onFinish={onFinish} size="large" autoComplete="off" layout="vertical">
            <Form.Item
              label={<FieldLabel icon={<UserOutlined />} text="用户名" />}
              name="username"
              rules={[{ required: true, message: '请输入用户名' }]}
            >
              <Input prefix={<UserOutlined />} placeholder="请输入您的账号" />
            </Form.Item>
            <Form.Item
              label={<FieldLabel icon={<LockOutlined />} text="密码" />}
              name="password"
              rules={[{ required: true, message: '请输入密码' }]}
            >
              <Input.Password prefix={<LockOutlined />} placeholder="请输入您的密码" />
            </Form.Item>
            <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 16 }}>
              <Button type="link" style={{ paddingInline: 0, color: '#94a3b8', fontWeight: 600 }}>
                忘记密码？
              </Button>
            </div>
            <Form.Item style={{ marginBottom: 12 }}>
              <Button type="primary" htmlType="submit" loading={loading} block size="large">
                登 录
              </Button>
            </Form.Item>
          </Form>

          <div
            style={{
              marginTop: 18,
              paddingTop: 18,
              borderTop: '1px solid #edf2f7',
              display: 'flex',
              alignItems: 'center',
              gap: 12,
              color: '#64748b',
            }}
          >
            <SafetyCertificateOutlined style={{ color: '#0b4d9b' }} />
            <Typography.Text type="secondary" style={{ fontSize: 13 }}>
              员工账号不会进入此后台，请使用移动端完成日常打卡。
            </Typography.Text>
          </div>
        </Card>
      </div>
    </div>
  );
}

function FieldLabel({ icon, text }: { icon: React.ReactNode; text: string }) {
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8, fontWeight: 700, color: '#475569' }}>
      {icon}
      {text}
    </span>
  );
}

function FeatureLine({ title, description }: { title: string; description: string }) {
  return (
    <div
      style={{
        padding: 16,
        borderRadius: 22,
        background: 'rgba(255,255,255,0.68)',
        border: '1px solid rgba(255,255,255,0.6)',
      }}
    >
      <Typography.Text style={{ display: 'block', fontWeight: 700, marginBottom: 6 }}>
        {title}
      </Typography.Text>
      <Typography.Text type="secondary" style={{ lineHeight: 1.6 }}>
        {description}
      </Typography.Text>
    </div>
  );
}
