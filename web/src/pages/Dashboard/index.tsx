import { useEffect, useState } from 'react';
import { Card, Col, Row, Statistic, DatePicker, Typography, Spin, Table, Tag, Tooltip } from 'antd';
import {
  UserOutlined,
  CheckCircleOutlined,
  ClockCircleOutlined,
  WarningOutlined,
} from '@ant-design/icons';
import dayjs from 'dayjs';
import { getStatistics, getDailyStatistics } from '../../api/attendance';
import type { DailyStats } from '../../api/attendance';
import { getUsers } from '../../api/users';
import type { AttendanceStatistics } from '../../types';

const { RangePicker } = DatePicker;

export default function Dashboard() {
  const [stats, setStats] = useState<AttendanceStatistics | null>(null);
  const [dailyStats, setDailyStats] = useState<DailyStats[]>([]);
  const [userCount, setUserCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [dateRange, setDateRange] = useState<[dayjs.Dayjs, dayjs.Dayjs]>([
    dayjs().startOf('month'),
    dayjs(),
  ]);

  const fetchData = async () => {
    setLoading(true);
    try {
      const from = dateRange[0].format('YYYY-MM-DD');
      const to = dateRange[1].format('YYYY-MM-DD');
      const [statsData, usersData, daily] = await Promise.all([
        getStatistics(from, to),
        getUsers({ page: 1, page_size: 1 }),
        getDailyStatistics(from, to),
      ]);
      setStats(statsData);
      setUserCount(usersData.total);
      setDailyStats(daily);
    } catch {
      // 忽略
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [dateRange]);

  const maxCheckins = Math.max(...dailyStats.map((d) => d.checkins), 1);

  const dailyColumns = [
    { title: '日期', dataIndex: 'date', key: 'date', width: 120 },
    {
      title: '签到',
      dataIndex: 'checkins',
      key: 'checkins',
      width: 200,
      render: (v: number) => (
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div
            style={{
              height: 16,
              width: `${(v / maxCheckins) * 100}%`,
              minWidth: v > 0 ? 4 : 0,
              background: '#52c41a',
              borderRadius: 3,
              transition: 'width 0.3s',
            }}
          />
          <span>{v}</span>
        </div>
      ),
    },
    { title: '签退', dataIndex: 'checkouts', key: 'checkouts', width: 80 },
    {
      title: '迟到',
      dataIndex: 'late_count',
      key: 'late_count',
      width: 80,
      render: (v: number) => v > 0 ? <Tag color="orange">{v}</Tag> : 0,
    },
    {
      title: '早退',
      dataIndex: 'early_leave_count',
      key: 'early_leave_count',
      width: 80,
      render: (v: number) => v > 0 ? <Tag color="red">{v}</Tag> : 0,
    },
  ];

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <Typography.Title level={4} style={{ margin: 0 }}>仪表盘</Typography.Title>
        <RangePicker
          value={dateRange}
          onChange={(dates) => {
            if (dates && dates[0] && dates[1]) {
              setDateRange([dates[0], dates[1]]);
            }
          }}
        />
      </div>

      <Spin spinning={loading}>
        <Row gutter={[16, 16]}>
          <Col xs={24} sm={12} lg={6}>
            <Card>
              <Statistic
                title="总用户数"
                value={userCount}
                prefix={<UserOutlined />}
                valueStyle={{ color: '#1890ff' }}
              />
            </Card>
          </Col>
          <Col xs={24} sm={12} lg={6}>
            <Card>
              <Statistic
                title="签到次数"
                value={stats?.total_checkins || 0}
                prefix={<CheckCircleOutlined />}
                valueStyle={{ color: '#52c41a' }}
              />
            </Card>
          </Col>
          <Col xs={24} sm={12} lg={6}>
            <Card>
              <Statistic
                title="迟到次数"
                value={stats?.late_count || 0}
                prefix={<ClockCircleOutlined />}
                valueStyle={{ color: '#faad14' }}
              />
            </Card>
          </Col>
          <Col xs={24} sm={12} lg={6}>
            <Card>
              <Statistic
                title="早退次数"
                value={stats?.early_leave_count || 0}
                prefix={<WarningOutlined />}
                valueStyle={{ color: '#ff4d4f' }}
              />
            </Card>
          </Col>
        </Row>

        {/* 每日考勤趋势图（柱状可视化） */}
        <Card title="每日考勤趋势" style={{ marginTop: 16 }}>
          {dailyStats.length > 0 ? (
            <div style={{ overflowX: 'auto' }}>
              <div style={{ display: 'flex', alignItems: 'flex-end', gap: 4, height: 160, minWidth: dailyStats.length * 36, padding: '0 8px' }}>
                {dailyStats.map((d) => (
                  <Tooltip
                    key={d.date}
                    title={`${d.date}: 签到${d.checkins} 签退${d.checkouts} 迟到${d.late_count} 早退${d.early_leave_count}`}
                  >
                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', flex: 1, minWidth: 28 }}>
                      <div style={{ display: 'flex', gap: 2, alignItems: 'flex-end', height: 120 }}>
                        <div
                          style={{
                            width: 12,
                            height: `${(d.checkins / maxCheckins) * 110}px`,
                            minHeight: d.checkins > 0 ? 4 : 0,
                            background: '#52c41a',
                            borderRadius: '3px 3px 0 0',
                          }}
                        />
                        <div
                          style={{
                            width: 12,
                            height: `${(d.checkouts / maxCheckins) * 110}px`,
                            minHeight: d.checkouts > 0 ? 4 : 0,
                            background: '#1890ff',
                            borderRadius: '3px 3px 0 0',
                          }}
                        />
                      </div>
                      <div style={{ fontSize: 10, color: '#999', marginTop: 4, writingMode: 'vertical-lr', height: 36 }}>
                        {d.date.slice(5)}
                      </div>
                    </div>
                  </Tooltip>
                ))}
              </div>
              <div style={{ display: 'flex', gap: 16, marginTop: 8, justifyContent: 'center' }}>
                <span><span style={{ display: 'inline-block', width: 12, height: 12, background: '#52c41a', borderRadius: 2, marginRight: 4 }} />签到</span>
                <span><span style={{ display: 'inline-block', width: 12, height: 12, background: '#1890ff', borderRadius: 2, marginRight: 4 }} />签退</span>
              </div>
            </div>
          ) : (
            <div style={{ textAlign: 'center', color: '#999', padding: 40 }}>暂无数据</div>
          )}
        </Card>

        {/* 每日明细表格 */}
        <Card title="每日考勤明细" style={{ marginTop: 16 }}>
          <Table
            columns={dailyColumns}
            dataSource={dailyStats}
            rowKey="date"
            size="small"
            pagination={false}
            scroll={{ x: 560 }}
          />
        </Card>
      </Spin>
    </div>
  );
}
