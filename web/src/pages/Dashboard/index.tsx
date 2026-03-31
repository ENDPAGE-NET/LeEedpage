import { useEffect, useMemo, useRef, useState } from 'react';
import { Card, Col, DatePicker, Empty, Row, Space, Spin, Statistic, Table, Tag, Tooltip, Typography } from 'antd';
import { CheckCircleOutlined, ClockCircleOutlined, TeamOutlined, WarningOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';

import { getDailyStatistics, getStatistics } from '../../api/attendance';
import { getUsers } from '../../api/users';
import type { DailyStats } from '../../api/attendance';
import type { AttendanceStatistics } from '../../types';

const { RangePicker } = DatePicker;

export default function Dashboard() {
  const [stats, setStats] = useState<AttendanceStatistics | null>(null);
  const [dailyStats, setDailyStats] = useState<DailyStats[]>([]);
  const [userCount, setUserCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const latestRequestRef = useRef(0);
  const [dateRange, setDateRange] = useState<[dayjs.Dayjs, dayjs.Dayjs]>([
    dayjs().startOf('month'),
    dayjs(),
  ]);

  const fetchData = async () => {
    const requestId = latestRequestRef.current + 1;
    latestRequestRef.current = requestId;
    setLoading(true);
    try {
      const from = dateRange[0].format('YYYY-MM-DD');
      const to = dateRange[1].format('YYYY-MM-DD');
      const [statsData, usersData, daily] = await Promise.all([
        getStatistics(from, to),
        getUsers({ page: 1, page_size: 1 }),
        getDailyStatistics(from, to),
      ]);
      if (latestRequestRef.current !== requestId) {
        return;
      }
      setStats(statsData);
      setUserCount(usersData.total);
      setDailyStats(daily);
    } finally {
      if (latestRequestRef.current === requestId) {
        setLoading(false);
      }
    }
  };

  useEffect(() => {
    void fetchData();
  }, [dateRange]);

  const maxActivity = useMemo(
    () => Math.max(...dailyStats.map((item) => Math.max(item.checkins, item.checkouts)), 1),
    [dailyStats],
  );

  const dailyColumns = [
    { title: '日期', dataIndex: 'date', key: 'date', width: 120 },
    {
      title: '签到',
      dataIndex: 'checkins',
      key: 'checkins',
      width: 200,
      render: (value: number) => (
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div
            style={{
              height: 10,
              width: `${(value / maxActivity) * 100}%`,
              minWidth: value > 0 ? 8 : 0,
              borderRadius: 999,
              background: 'linear-gradient(90deg, #0b4d9b, #79a8e7)',
            }}
          />
          <span>{value}</span>
        </div>
      ),
    },
    {
      title: '签退',
      dataIndex: 'checkouts',
      key: 'checkouts',
      width: 80,
    },
    {
      title: '迟到',
      dataIndex: 'late_count',
      key: 'late_count',
      width: 80,
      render: (value: number) => (value > 0 ? <Tag color="orange">{value}</Tag> : 0),
    },
    {
      title: '早退',
      dataIndex: 'early_leave_count',
      key: 'early_leave_count',
      width: 80,
      render: (value: number) => (value > 0 ? <Tag color="red">{value}</Tag> : 0),
    },
  ];

  return (
    <div className="page-shell">
      <div className="page-header">
        <div>
          <div className="page-title">运营总览</div>
          <div className="page-subtitle">
            这里聚合管理员最常看的人员体量、出勤趋势与异常变化，用一个视图读懂当前考勤状态。
          </div>
        </div>
        <div className="page-toolbar">
          <RangePicker
            value={dateRange}
            onChange={(dates) => {
              if (dates?.[0] && dates?.[1]) {
                setDateRange([dates[0], dates[1]]);
              }
            }}
          />
        </div>
      </div>

      <Spin spinning={loading}>
        <Row gutter={[18, 18]}>
          <Col xs={24} sm={12} xl={6}>
            <Card className="admin-stat-card">
              <Statistic title="员工总数" value={userCount} prefix={<TeamOutlined />} />
            </Card>
          </Col>
          <Col xs={24} sm={12} xl={6}>
            <Card className="admin-stat-card">
              <Statistic
                title="签到次数"
                value={stats?.total_checkins || 0}
                prefix={<CheckCircleOutlined />}
                valueStyle={{ color: '#0b4d9b' }}
              />
            </Card>
          </Col>
          <Col xs={24} sm={12} xl={6}>
            <Card className="admin-stat-card">
              <Statistic
                title="迟到次数"
                value={stats?.late_count || 0}
                prefix={<ClockCircleOutlined />}
                valueStyle={{ color: '#f59e0b' }}
              />
            </Card>
          </Col>
          <Col xs={24} sm={12} xl={6}>
            <Card className="admin-stat-card">
              <Statistic
                title="早退次数"
                value={stats?.early_leave_count || 0}
                prefix={<WarningOutlined />}
                valueStyle={{ color: '#dc2626' }}
              />
            </Card>
          </Col>
        </Row>

        <Row gutter={[18, 18]} style={{ marginTop: 4 }}>
          <Col xs={24} xl={14}>
            <Card
              title="月度考勤趋势"
              extra={<Typography.Text type="secondary">签到 / 签退双维度</Typography.Text>}
            >
              {dailyStats.length > 0 ? (
                <div style={{ overflowX: 'auto' }}>
                  <div
                    style={{
                      display: 'flex',
                      alignItems: 'flex-end',
                      gap: 8,
                      minWidth: Math.max(dailyStats.length * 44, 520),
                      height: 220,
                      padding: '18px 8px 6px',
                    }}
                  >
                    {dailyStats.map((item) => (
                      <Tooltip
                        key={item.date}
                        title={`${item.date} · 签到 ${item.checkins} / 签退 ${item.checkouts} / 迟到 ${item.late_count} / 早退 ${item.early_leave_count}`}
                      >
                        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', flex: 1 }}>
                          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 4, height: 150 }}>
                            <div
                              style={{
                                width: 14,
                                height: `${(item.checkins / maxActivity) * 132}px`,
                                minHeight: item.checkins > 0 ? 6 : 0,
                                borderRadius: '999px 999px 6px 6px',
                                background: 'linear-gradient(180deg, #8cb9ef 0%, #0b4d9b 100%)',
                              }}
                            />
                            <div
                              style={{
                                width: 14,
                                height: `${(item.checkouts / maxActivity) * 132}px`,
                                minHeight: item.checkouts > 0 ? 6 : 0,
                                borderRadius: '999px 999px 6px 6px',
                                background: 'linear-gradient(180deg, #c7d8f8 0%, #6b8fcb 100%)',
                              }}
                            />
                          </div>
                          <div style={{ marginTop: 8, color: '#64748b', fontSize: 11 }}>{item.date.slice(5)}</div>
                        </div>
                      </Tooltip>
                    ))}
                  </div>
                  <Space style={{ marginTop: 12 }}>
                    <Tag color="blue">签到</Tag>
                    <Tag color="geekblue">签退</Tag>
                  </Space>
                </div>
              ) : (
                <Empty description="当前日期范围暂无趋势数据" />
              )}
            </Card>
          </Col>
          <Col xs={24} xl={10}>
            <Card title="管理提示" styles={{ body: { display: 'grid', gap: 14 } }}>
              <InsightPanel
                title="人员覆盖"
                text={`当前系统共纳管 ${userCount} 名员工，建议按部门节奏持续检查激活率与规则完成度。`}
              />
              <InsightPanel
                title="异常关注"
                text={`本时段累计迟到 ${stats?.late_count || 0} 次、早退 ${stats?.early_leave_count || 0} 次，建议结合规则页做针对性优化。`}
              />
              <InsightPanel
                title="数据范围"
                text={`${dateRange[0].format('YYYY.MM.DD')} - ${dateRange[1].format('YYYY.MM.DD')} 的统计结果会同步影响下方趋势与明细表。`}
              />
            </Card>
          </Col>
        </Row>

        <Card title="每日考勤明细" style={{ marginTop: 18 }}>
          <Table
            columns={dailyColumns}
            dataSource={dailyStats}
            rowKey="date"
            pagination={false}
            scroll={{ x: 560 }}
            locale={{ emptyText: <Empty description="当前范围暂无明细数据" /> }}
          />
        </Card>
      </Spin>
    </div>
  );
}

function InsightPanel({ title, text }: { title: string; text: string }) {
  return (
    <div
      style={{
        padding: 18,
        borderRadius: 22,
        background: 'linear-gradient(180deg, #fbfdff 0%, #f7f9fc 100%)',
        border: '1px solid #edf2f7',
      }}
    >
      <Typography.Text style={{ display: 'block', fontWeight: 700, marginBottom: 6 }}>
        {title}
      </Typography.Text>
      <Typography.Text type="secondary" style={{ lineHeight: 1.7 }}>
        {text}
      </Typography.Text>
    </div>
  );
}
