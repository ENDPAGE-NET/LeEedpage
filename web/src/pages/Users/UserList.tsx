import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Avatar,
  Button,
  Card,
  Form,
  Image,
  Input,
  Modal,
  Popconfirm,
  Select,
  Space,
  Table,
  Tag,
  Typography,
  message,
} from 'antd';
import {
  KeyOutlined,
  PlusOutlined,
  ReloadOutlined,
  ScanOutlined,
  SearchOutlined,
  SettingOutlined,
  UserOutlined,
} from '@ant-design/icons';

import { createUser, deleteUser, getUsers, resetFace, resetPassword, updateUser } from '../../api/users';
import { resolveMediaUrl } from '../../lib/media';
import type { User } from '../../types';

const statusMap: Record<string, { color: string; text: string }> = {
  pending: { color: 'orange', text: '待激活' },
  active: { color: 'green', text: '已激活' },
  disabled: { color: 'red', text: '已禁用' },
};

const roleMap: Record<string, string> = {
  admin: '管理员',
  employee: '员工',
};

export default function UserList() {
  const navigate = useNavigate();
  const [users, setUsers] = useState<User[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [modalOpen, setModalOpen] = useState(false);
  const [editingUser, setEditingUser] = useState<User | null>(null);
  const [previewImage, setPreviewImage] = useState<string>();
  const [form] = Form.useForm();

  const fetchUsers = async () => {
    setLoading(true);
    try {
      const res = await getUsers({ page, page_size: pageSize, search, status: statusFilter });
      setUsers(res.items);
      setTotal(res.total);
    } catch {
      message.error('获取用户列表失败');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void fetchUsers();
  }, [page, pageSize, search, statusFilter]);

  const handleCreate = () => {
    setEditingUser(null);
    form.resetFields();
    form.setFieldsValue({ role: 'employee' });
    setModalOpen(true);
  };

  const handleEdit = (user: User) => {
    setEditingUser(user);
    form.setFieldsValue({
      username: user.username,
      full_name: user.full_name,
      phone: user.phone,
      email: user.email,
      role: user.role,
    });
    setModalOpen(true);
  };

  const handleSubmit = async () => {
    try {
      const values = await form.validateFields();
      if (editingUser) {
        await updateUser(editingUser.id, {
          full_name: values.full_name,
          phone: values.phone,
          email: values.email,
          role: values.role,
        });
        message.success('更新成功');
      } else {
        await createUser(values);
        message.success('创建成功');
      }
      setModalOpen(false);
      void fetchUsers();
    } catch (err: any) {
      if (err?.response?.data?.detail) {
        message.error(err.response.data.detail);
      }
    }
  };

  const handleDelete = async (id: string) => {
    try {
      await deleteUser(id);
      message.success('用户已禁用');
      void fetchUsers();
    } catch {
      message.error('操作失败');
    }
  };

  const handleResetPassword = async (id: string) => {
    try {
      const res = await resetPassword(id);
      Modal.success({
        title: '密码已重置',
        content: `临时密码: ${res.temp_password}`,
      });
    } catch {
      message.error('重置密码失败');
    }
  };

  const handleResetFace = async (id: string) => {
    try {
      await resetFace(id);
      message.success('人脸数据已重置');
      void fetchUsers();
    } catch {
      message.error('重置人脸失败');
    }
  };

  const columns = [
    {
      title: '头像',
      key: 'avatar',
      width: 92,
      render: (_: unknown, record: User) => {
        const imageUrl = resolveMediaUrl(record.avatar_url ?? record.face_image_url);
        return imageUrl ? (
          <Image
            src={imageUrl}
            alt={record.full_name}
            width={48}
            height={48}
            style={{ borderRadius: 12, objectFit: 'cover', cursor: 'pointer' }}
            preview={false}
            onClick={() => setPreviewImage(imageUrl)}
          />
        ) : (
          <Avatar size={48} style={{ backgroundColor: '#1677ff' }}>
            {record.full_name?.[0] || '?'}
          </Avatar>
        );
      },
    },
    {
      title: '用户信息',
      key: 'user',
      width: 220,
      render: (_: unknown, record: User) => (
        <Space direction="vertical" size={0}>
          <Typography.Text strong>{record.full_name}</Typography.Text>
          <Typography.Text type="secondary">{record.username}</Typography.Text>
        </Space>
      ),
    },
    {
      title: '角色',
      dataIndex: 'role',
      key: 'role',
      width: 90,
      render: (role: string) => roleMap[role] || role,
    },
    {
      title: '状态',
      dataIndex: 'status',
      key: 'status',
      width: 90,
      render: (status: string) => {
        const s = statusMap[status];
        return s ? <Tag color={s.color}>{s.text}</Tag> : status;
      },
    },
    {
      title: '人脸',
      dataIndex: 'has_face',
      key: 'has_face',
      width: 180,
      render: (has: boolean, record: User) =>
        has ? (
          <Space size="small">
            <Tag color="green">已录入</Tag>
            {record.face_image_url ? (
              <Button size="small" type="link" onClick={() => setPreviewImage(resolveMediaUrl(record.face_image_url))}>
                查看注册人脸
              </Button>
            ) : null}
          </Space>
        ) : (
          <Tag>未录入</Tag>
        ),
    },
    {
      title: '手机',
      dataIndex: 'phone',
      key: 'phone',
      width: 140,
      render: (value: string | null) => value || '-',
    },
    {
      title: '操作',
      key: 'actions',
      width: 340,
      render: (_: unknown, record: User) => (
        <Space size="small" wrap>
          <Button size="small" icon={<UserOutlined />} onClick={() => handleEdit(record)}>
            编辑
          </Button>
          <Button size="small" icon={<SettingOutlined />} onClick={() => navigate(`/rules/${record.id}`)}>
            规则
          </Button>
          <Popconfirm title="确认重置密码？" onConfirm={() => handleResetPassword(record.id)}>
            <Button size="small" icon={<KeyOutlined />}>
              重置密码
            </Button>
          </Popconfirm>
          {record.has_face ? (
            <Popconfirm title="确认重置人脸？用户需要重新注册" onConfirm={() => handleResetFace(record.id)}>
              <Button size="small" icon={<ScanOutlined />} danger>
                重置人脸
              </Button>
            </Popconfirm>
          ) : null}
          {record.status !== 'disabled' ? (
            <Popconfirm title="确认禁用该用户？" onConfirm={() => handleDelete(record.id)}>
              <Button size="small" danger>
                禁用
              </Button>
            </Popconfirm>
          ) : null}
        </Space>
      ),
    },
  ];

  return (
    <div>
      <Typography.Title level={4} style={{ marginTop: 0 }}>
        用户管理
      </Typography.Title>

      <Card style={{ marginBottom: 16 }}>
        <Space wrap>
          <Input
            placeholder="搜索用户名或姓名"
            prefix={<SearchOutlined />}
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(1);
            }}
            style={{ width: 220 }}
            allowClear
          />
          <Select
            placeholder="状态筛选"
            value={statusFilter || undefined}
            onChange={(value) => {
              setStatusFilter(value || '');
              setPage(1);
            }}
            style={{ width: 140 }}
            allowClear
            options={[
              { value: 'pending', label: '待激活' },
              { value: 'active', label: '已激活' },
              { value: 'disabled', label: '已禁用' },
            ]}
          />
          <Button icon={<ReloadOutlined />} onClick={() => void fetchUsers()}>
            刷新
          </Button>
          <Button type="primary" icon={<PlusOutlined />} onClick={handleCreate}>
            新建用户
          </Button>
        </Space>
      </Card>

      <Table
        columns={columns}
        dataSource={users}
        rowKey="id"
        loading={loading}
        scroll={{ x: 1150 }}
        pagination={{
          current: page,
          pageSize,
          total,
          showSizeChanger: true,
          showTotal: (count) => `共 ${count} 条`,
          onChange: (nextPage, nextPageSize) => {
            setPage(nextPage);
            setPageSize(nextPageSize);
          },
        }}
      />

      <Modal
        title={editingUser ? '编辑用户' : '新建用户'}
        open={modalOpen}
        onOk={() => void handleSubmit()}
        onCancel={() => setModalOpen(false)}
        okText="确定"
        cancelText="取消"
      >
        <Form form={form} layout="vertical">
          {!editingUser ? (
            <>
              <Form.Item name="username" label="用户名" rules={[{ required: true, message: '请输入用户名' }]}>
                <Input />
              </Form.Item>
              <Form.Item name="password" label="初始密码" rules={[{ required: true, message: '请输入初始密码' }]}>
                <Input.Password />
              </Form.Item>
            </>
          ) : null}
          <Form.Item name="full_name" label="姓名" rules={[{ required: true, message: '请输入姓名' }]}>
            <Input />
          </Form.Item>
          <Form.Item name="phone" label="手机号">
            <Input />
          </Form.Item>
          <Form.Item name="email" label="邮箱">
            <Input />
          </Form.Item>
          <Form.Item name="role" label="角色" rules={[{ required: true, message: '请选择角色' }]}>
            <Select
              options={[
                { value: 'employee', label: '员工' },
                { value: 'admin', label: '管理员' },
              ]}
            />
          </Form.Item>
        </Form>
      </Modal>

      <Image
        style={{ display: 'none' }}
        src={previewImage}
        preview={{
          visible: Boolean(previewImage),
          src: previewImage,
          onVisibleChange: (visible) => {
            if (!visible) {
              setPreviewImage(undefined);
            }
          },
        }}
      />
    </div>
  );
}
