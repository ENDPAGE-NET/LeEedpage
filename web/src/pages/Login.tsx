import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Form, Input, Button, Card, Typography, message, theme, Alert } from 'antd';
import { UserOutlined, LockOutlined } from '@ant-design/icons';
import { login, getCurrentUser } from '../api/auth';
import { useAuthStore } from '../store/auth';

export default function Login() {
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');
  const navigate = useNavigate();
  const { setUser } = useAuthStore();
  const { token } = theme.useToken();

  const onFinish = async (values: { username: string; password: string }) => {
    setLoading(true);
    setErrorMsg('');
    try {
      const res = await login(values);
      localStorage.setItem('access_token', res.access_token);
      localStorage.setItem('refresh_token', res.refresh_token);

      // 获取用户信息并检查权限
      const user = await getCurrentUser();

      if (user.role !== 'admin') {
        // 员工无权访问管理后台，清除 token
        localStorage.removeItem('access_token');
        localStorage.removeItem('refresh_token');
        setErrorMsg('权限不足：仅管理员可登录管理后台，员工请使用手机 App 打卡');
        return;
      }

      setUser(user);
      message.success('登录成功');
      navigate('/dashboard');
    } catch (err: any) {
      const detail = err.response?.data?.detail;
      if (detail === '用户名或密码错误') {
        setErrorMsg('用户名或密码错误，请重新输入');
      } else if (detail === '账户已禁用') {
        setErrorMsg('该账户已被禁用，请联系管理员');
      } else {
        setErrorMsg(detail || '登录失败，请稍后重试');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div
      style={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: `linear-gradient(135deg, ${token.colorPrimaryBg} 0%, ${token.colorBgLayout} 100%)`,
      }}
    >
      <Card
        style={{ width: 400, boxShadow: token.boxShadowTertiary }}
        bordered={false}
      >
        <div style={{ textAlign: 'center', marginBottom: 32 }}>
          <Typography.Title level={2} style={{ marginBottom: 4, color: token.colorPrimary }}>
            熵析云枢
          </Typography.Title>
          <Typography.Text type="secondary">企业考勤管理系统</Typography.Text>
        </div>
        {errorMsg && (
          <Alert
            message={errorMsg}
            type="error"
            showIcon
            closable
            onClose={() => setErrorMsg('')}
            style={{ marginBottom: 16 }}
          />
        )}
        <Form onFinish={onFinish} size="large" autoComplete="off">
          <Form.Item name="username" rules={[{ required: true, message: '请输入用户名' }]}>
            <Input prefix={<UserOutlined />} placeholder="用户名" />
          </Form.Item>
          <Form.Item name="password" rules={[{ required: true, message: '请输入密码' }]}>
            <Input.Password prefix={<LockOutlined />} placeholder="密码" />
          </Form.Item>
          <Form.Item>
            <Button type="primary" htmlType="submit" loading={loading} block>
              登录
            </Button>
          </Form.Item>
        </Form>
        <div style={{ textAlign: 'center' }}>
          <Typography.Text type="secondary" style={{ fontSize: 12 }}>
            员工请使用手机 App 进行打卡
          </Typography.Text>
        </div>
      </Card>
    </div>
  );
}
