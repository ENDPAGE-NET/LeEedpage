import { useEffect, useState } from 'react';
import { Table, DatePicker, Space, Tag, Typography, Card } from 'antd';
import dayjs from 'dayjs';
import { getAttendance } from '../../api/attendance';
import type { AttendanceRecord } from '../../types';

const { RangePicker } = DatePicker;

export default function Records() {
  const [records, setRecords] = useState<AttendanceRecord[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [dateRange, setDateRange] = useState<[dayjs.Dayjs, dayjs.Dayjs]>([
    dayjs().startOf('month'),
    dayjs(),
  ]);

  const fetchRecords = async () => {
    setLoading(true);
    try {
      const res = await getAttendance({
        page,
        page_size: pageSize,
        date_from: dateRange[0].format('YYYY-MM-DD'),
        date_to: dateRange[1].format('YYYY-MM-DD'),
      });
      setRecords(res.items);
      setTotal(res.total);
    } catch {
      // ignore
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchRecords();
  }, [page, pageSize, dateRange]);

  const columns = [
    {
      title: '姓名',
      dataIndex: 'user_name',
      key: 'user_name',
      width: 100,
      render: (v: string | null) => v || '-',
    },
    {
      title: '日期',
      dataIndex: 'record_date',
      key: 'record_date',
      width: 110,
    },
    {
      title: '类型',
      dataIndex: 'record_type',
      key: 'record_type',
      width: 80,
      render: (t: string) => t === 'checkin' ? <Tag color="blue">签到</Tag> : <Tag color="purple">签退</Tag>,
    },
    {
      title: '人脸验证',
      dataIndex: 'face_verified',
      key: 'face_verified',
      width: 90,
      render: (v: boolean) => v ? <Tag color="green">通过</Tag> : <Tag color="red">未通过</Tag>,
    },
    {
      title: '位置验证',
      dataIndex: 'location_verified',
      key: 'location_verified',
      width: 90,
      render: (v: boolean | null) => {
        if (v === null) return <Tag>无要求</Tag>;
        return v ? <Tag color="green">通过</Tag> : <Tag color="red">未通过</Tag>;
      },
    },
    {
      title: '距离(米)',
      dataIndex: 'distance_m',
      key: 'distance_m',
      width: 90,
      render: (v: number | null) => v !== null ? v.toFixed(1) : '-',
    },
    {
      title: '状态',
      key: 'status',
      width: 100,
      render: (_: any, r: AttendanceRecord) => {
        if (r.is_late) return <Tag color="orange">迟到</Tag>;
        if (r.is_early_leave) return <Tag color="orange">早退</Tag>;
        return <Tag color="green">正常</Tag>;
      },
    },
    {
      title: '打卡时间',
      dataIndex: 'recorded_at',
      key: 'recorded_at',
      width: 170,
      render: (v: string) => dayjs(v).format('YYYY-MM-DD HH:mm:ss'),
    },
  ];

  return (
    <div>
      <Typography.Title level={4} style={{ marginTop: 0 }}>考勤记录</Typography.Title>
      <Card style={{ marginBottom: 16 }}>
        <Space wrap>
          <RangePicker
            value={dateRange}
            onChange={(dates) => {
              if (dates && dates[0] && dates[1]) {
                setDateRange([dates[0], dates[1]]);
                setPage(1);
              }
            }}
          />
        </Space>
      </Card>
      <Table
        columns={columns}
        dataSource={records}
        rowKey="id"
        loading={loading}
        scroll={{ x: 900 }}
        pagination={{
          current: page,
          pageSize,
          total,
          showSizeChanger: true,
          showTotal: (t) => `共 ${t} 条`,
          onChange: (p, ps) => { setPage(p); setPageSize(ps); },
        }}
      />
    </div>
  );
}
