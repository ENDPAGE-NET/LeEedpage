import { createBrowserRouter, Navigate } from 'react-router-dom';
import AdminLayout from './components/Layout/AdminLayout';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import UserList from './pages/Users/UserList';
import RuleList from './pages/Rules/RuleList';
import RuleConfig from './pages/Rules/RuleConfig';
import Records from './pages/Attendance/Records';
import LeaveApproval from './pages/Leave/LeaveApproval';

const router = createBrowserRouter([
  {
    path: '/login',
    element: <Login />,
  },
  {
    path: '/',
    element: <AdminLayout />,
    children: [
      {
        index: true,
        element: <Navigate to="/dashboard" replace />,
      },
      {
        path: 'dashboard',
        element: <Dashboard />,
      },
      {
        path: 'users',
        element: <UserList />,
      },
      {
        path: 'rules',
        element: <RuleList />,
      },
      {
        path: 'rules/:userId',
        element: <RuleConfig />,
      },
      {
        path: 'attendance',
        element: <Records />,
      },
      {
        path: 'leave',
        element: <LeaveApproval />,
      },
    ],
  },
]);

export default router;
