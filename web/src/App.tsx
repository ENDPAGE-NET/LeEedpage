import { useEffect, useRef } from 'react';
import { RouterProvider } from 'react-router-dom';
import { ConfigProvider, App as AntApp, Spin } from 'antd';
import zhCN from 'antd/locale/zh_CN';
import router from './router';
import { useAuthStore } from './store/auth';
import { adminTheme } from './theme/adminTheme';

function AppContent() {
  const { loading, fetchUser } = useAuthStore();
  const fetchedRef = useRef(false);

  useEffect(() => {
    if (fetchedRef.current) {
      return;
    }
    fetchedRef.current = true;
    void fetchUser();
  }, []);

  if (loading) {
    return (
      <div
        style={{
          height: '100vh',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background:
            'radial-gradient(circle at top right, rgba(219,234,254,0.9), transparent 30%), linear-gradient(180deg, #f7f9fd 0%, #f3f6fb 100%)',
        }}
      >
        <div
          style={{
            minWidth: 280,
            padding: 28,
            borderRadius: 28,
            background: 'rgba(255,255,255,0.84)',
            boxShadow: '0 24px 48px rgba(15,23,42,0.08)',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: 14,
          }}
        >
          <div className="brand-badge">EA</div>
          <Spin size="large" />
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontWeight: 800, fontSize: 18 }}>熵析云枢管理台</div>
            <div style={{ color: '#64748b', marginTop: 4 }}>正在同步管理员工作区</div>
          </div>
        </div>
      </div>
    );
  }

  return <RouterProvider router={router} />;
}

export default function App() {
  return (
    <ConfigProvider
      locale={zhCN}
      theme={adminTheme}
    >
      <AntApp>
        <AppContent />
      </AntApp>
    </ConfigProvider>
  );
}
