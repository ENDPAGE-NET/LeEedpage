import { useEffect, useState } from 'react';
import {
  Table, Button, Tag, Typography, Space, Select, Modal, Input, message, Card,
} from 'antd';
import { CheckOutlined, CloseOutlined, ReloadOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';
import { getLeaveRequests, approveLeave } from '../../api/leave';
import type { LeaveRequest } from '../../api/leave';

const statusMap: Record<string, { color: string; text: string }> = {
  pending: { color: 'orange', text: '待审批' },
  approved: { color: 'green', text: '已批准' },
  rejected: { color: 'red', text: '已拒绝' },
  cancelled: { color: 'default', text: '已取消' },
};

export default function LeaveApproval() {
  const [data, setData] = useState<LeaveRequest[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState('pending');
  const [remarkModal, setRemarkModal] = useState<{
    visible: boolean;
    id: string;
    action: 'approve' | 'reject';
    name: string;
  }>({ visible: false, id: '', action: 'approve', name: '' });
  const [remark, setRemark] = useState('');

  const fetchData = async () => {
    setLoading(true);
    try {
      const res = await getLeaveRequests({ page, page_size: 20, status: statusFilter });
      setData(res.items);
      setTotal(res.total);
    } catch {
      message.error('获取数据失败');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchData(); }, [page, statusFilter]);

  const handleApprove = async () => {
    try {
      await approveLeave(remarkModal.id, remarkModal.action, remark);
      message.success(remarkModal.action === 'approve' ? '已批准' : '已拒绝');
      setRemarkModal({ ...remarkModal, visible: false });
      setRemark('');
      fetchData();
    } catch (err: any) {
      message.error(err.response?.data?.detail || '操作失败');
    }
  };

  const columns = [
    {
      title: '申请人',
      dataIndex: 'user_name',
      key: 'user_name',
      width: 100,
      render: (v: string | null) => v || '-',
    },
    {
      title: '类型',
      dataIndex: 'leave_type_label',
      key: 'leave_type_label',
      width: 80,
    },
    {
      title: '日期',
      key: 'dates',
      width: 180,
      render: (_: any, r: LeaveRequest) => `${r.start_date} ~ ${r.end_date}`,
    },
    {
      title: '天数',
      dataIndex: 'days',
      key: 'days',
      width: 70,
      render: (v: number) => `${v}天`,
    },
    {
      title: '原因',
      dataIndex: 'reason',
      key: 'reason',
      ellipsis: true,
    },
    {
      title: '状态',
      dataIndex: 'status',
      key: 'status',
      width: 90,
      render: (s: string) => {
        const item = statusMap[s];
        return item ? <Tag color={item.color}>{item.text}</Tag> : s;
      },
    },
    {
      title: '审批人',
      dataIndex: 'approver_name',
      key: 'approver_name',
      width: 100,
      render: (v: string | null) => v || '-',
    },
    {
      title: '申请时间',
      dataIndex: 'created_at',
      key: 'created_at',
      width: 150,
      render: (v: string) => dayjs(v).format('YYYY-MM-DD HH:mm'),
    },
    {
      title: '操作',
      key: 'actions',
      width: 160,
      render: (_: any, r: LeaveRequest) => {
        if (r.status !== 'pending') return <Tag>{statusMap[r.status]?.text}</Tag>;
        return (
          <Space>
            <Button
              size="small"
              type="primary"
              icon={<CheckOutlined />}
              onClick={() => setRemarkModal({ visible: true, id: r.id, action: 'approve', name: r.user_name || '' })}
            >
              批准
            </Button>
            <Button
              size="small"
              danger
              icon={<CloseOutlined />}
              onClick={() => setRemarkModal({ visible: true, id: r.id, action: 'reject', name: r.user_name || '' })}
            >
              拒绝
            </Button>
          </Space>
        );
      },
    },
  ];

  return (
    <div>
      <Typography.Title level={4} style={{ marginTop: 0 }}>请假审批</Typography.Title>
      <Card style={{ marginBottom: 16 }}>
        <Space wrap>
          <Select
            value={statusFilter}
            onChange={(v) => { setStatusFilter(v); setPage(1); }}
            style={{ width: 130 }}
            options={[
              { value: '', label: '全部状态' },
              { value: 'pending', label: '待审批' },
              { value: 'approved', label: '已批准' },
              { value: 'rejected', label: '已拒绝' },
            ]}
          />
          <Button icon={<ReloadOutlined />} onClick={fetchData}>刷新</Button>
        </Space>
      </Card>

      <Table
        columns={columns}
        dataSource={data}
        rowKey="id"
        loading={loading}
        scroll={{ x: 1000 }}
        pagination={{
          current: page,
          pageSize: 20,
          total,
          showTotal: (t) => `共 ${t} 条`,
          onChange: (p) => setPage(p),
        }}
      />

      <Modal
        title={`${remarkModal.action === 'approve' ? '批准' : '拒绝'}请假 - ${remarkModal.name}`}
        open={remarkModal.visible}
        onOk={handleApprove}
        onCancel={() => { setRemarkModal({ ...remarkModal, visible: false }); setRemark(''); }}
        okText={remarkModal.action === 'approve' ? '确认批准' : '确认拒绝'}
        okButtonProps={{ danger: remarkModal.action === 'reject' }}
      >
        <Input.TextArea
          rows={3}
          placeholder="审批备注（可选）"
          value={remark}
          onChange={(e) => setRemark(e.target.value)}
        />
      </Modal>
    </div>
  );
}
