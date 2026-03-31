import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Alert,
  Button,
  Form,
  Input,
  Modal,
  Select,
  Space,
  Spin,
  Table,
  Tag,
  Typography,
  message,
} from 'antd';
import { ReloadOutlined, SearchOutlined, SettingOutlined, TeamOutlined } from '@ant-design/icons';

import RuleForm, {
  createDefaultRuleFormValues,
  mapRuleToFormValues,
  serializeRuleValues,
  type RuleFormValues,
} from '../../components/Rules/RuleForm';
import {
  batchApplyRules,
  getBatchRulePreview,
  getUserRule,
  type BatchRulePreviewResponse,
} from '../../api/rules';
import { getUsers } from '../../api/users';
import type { CheckinRule, User } from '../../types';

interface UserWithRule extends User {
  rule: CheckinRule | null;
  ruleLoading: boolean;
}

const statusOptions = [
  { value: '', label: '全部状态' },
  { value: 'pending', label: '待激活' },
  { value: 'active', label: '已激活' },
  { value: 'disabled', label: '已禁用' },
];

const defaultBatchPreview: BatchRulePreviewResponse = {
  matched_count: 0,
  configured_count: 0,
  distinct_rule_count: 0,
  preview_source: 'default',
  preview_user_name: null,
  rule: null,
};

function getPreviewDescription(preview: BatchRulePreviewResponse, hasLocalDraft: boolean) {
  if (hasLocalDraft) {
    return '当前显示的是你尚未提交的本地草稿。若想回到已生效规则，可点击“重新读取已生效规则”。';
  }

  if (preview.preview_source === 'uniform' && preview.rule) {
    return `当前筛选结果中的 ${preview.configured_count} 名员工已统一使用同一套规则，弹窗会直接回显这套已生效配置。`;
  }

  if (preview.preview_source === 'latest' && preview.rule) {
    return `当前筛选结果里存在 ${preview.distinct_rule_count} 套不同规则，已优先回显最近更新的一套${
      preview.preview_user_name ? `（来自 ${preview.preview_user_name}）` : ''
    }，请确认后再批量应用。`;
  }

  return '当前筛选结果还没有已生效规则，已为你准备默认模板。';
}

export default function RuleList() {
  const navigate = useNavigate();
  const [users, setUsers] = useState<UserWithRule[]>([]);
  const [loading, setLoading] = useState(false);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);

  const [batchOpen, setBatchOpen] = useState(false);
  const [batchLoading, setBatchLoading] = useState(false);
  const [batchSubmitting, setBatchSubmitting] = useState(false);
  const [batchDraft, setBatchDraft] = useState<RuleFormValues>(createDefaultRuleFormValues());
  const [batchDraftDirty, setBatchDraftDirty] = useState(false);
  const [batchPreview, setBatchPreview] = useState<BatchRulePreviewResponse>(defaultBatchPreview);
  const [batchSourceText, setBatchSourceText] = useState(getPreviewDescription(defaultBatchPreview, false));
  const [batchForm] = Form.useForm<RuleFormValues>();

  const filteredStatusLabel = useMemo(
    () => statusOptions.find((item) => item.value === statusFilter)?.label || '全部状态',
    [statusFilter],
  );

  const fetchUsers = async () => {
    setLoading(true);
    try {
      const response = await getUsers({
        page,
        page_size: 20,
        search,
        status: statusFilter,
        role: 'employee',
      });

      const rows: UserWithRule[] = response.items.map((user) => ({
        ...user,
        rule: null,
        ruleLoading: true,
      }));

      setUsers(rows);
      setTotal(response.total);

      const rules = await Promise.allSettled(response.items.map((user) => getUserRule(user.id)));
      setUsers(
        rows.map((row, index) => ({
          ...row,
          rule: rules[index].status === 'fulfilled' ? rules[index].value : null,
          ruleLoading: false,
        })),
      );
    } catch {
      message.error('获取规则列表失败');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void fetchUsers();
  }, [page, search, statusFilter]);

  const applyPreviewToForm = (preview: BatchRulePreviewResponse) => {
    const values = preview.rule ? mapRuleToFormValues(preview.rule) : createDefaultRuleFormValues();
    setBatchDraft(values);
    batchForm.setFieldsValue(values);
    setBatchDraftDirty(false);
    setBatchSourceText(getPreviewDescription(preview, false));
  };

  const loadBatchPreview = async ({ preferLocalDraft }: { preferLocalDraft: boolean }) => {
    setBatchLoading(true);
    try {
      const preview = await getBatchRulePreview({
        search,
        status: statusFilter,
      });
      setBatchPreview(preview);

      if (preferLocalDraft && batchDraftDirty) {
        batchForm.setFieldsValue(batchDraft);
        setBatchSourceText(getPreviewDescription(preview, true));
        return preview;
      }

      applyPreviewToForm(preview);
      return preview;
    } catch (error: any) {
      message.error(error?.response?.data?.detail || '获取批量配置预览失败');
      batchForm.setFieldsValue(batchDraft);
      return null;
    } finally {
      setBatchLoading(false);
    }
  };

  const openBatchModal = async () => {
    setBatchOpen(true);
    await loadBatchPreview({ preferLocalDraft: true });
  };

  const resetBatchDraftToDefaults = () => {
    const defaults = createDefaultRuleFormValues();
    setBatchDraft(defaults);
    setBatchDraftDirty(true);
    batchForm.setFieldsValue(defaults);
    setBatchSourceText('已切换为默认模板，当前内容尚未应用到员工规则。');
  };

  const reloadSavedBatchConfig = async () => {
    await loadBatchPreview({ preferLocalDraft: false });
  };

  const handleBatchValuesChange = (_: Partial<RuleFormValues>, values: RuleFormValues) => {
    setBatchDraft(values);
    setBatchDraftDirty(true);
    setBatchSourceText(getPreviewDescription(batchPreview, true));
  };

  const submitBatchApply = async () => {
    try {
      const values = await batchForm.validateFields();
      Modal.confirm({
        title: '确认批量应用规则',
        content: `当前筛选命中的全部员工都会被这套规则覆盖，预计影响 ${batchPreview.matched_count || total} 人。是否继续？`,
        okText: '确认应用',
        cancelText: '取消',
        onOk: async () => {
          setBatchSubmitting(true);
          try {
            const serialized = serializeRuleValues(values);
            const response = await batchApplyRules({
              filters: {
                search,
                status: statusFilter,
              },
              rule: serialized,
            });

            setBatchDraft(values);
            setBatchDraftDirty(false);
            setBatchPreview({
              matched_count: response.matched_count,
              configured_count: response.matched_count,
              distinct_rule_count: response.matched_count > 0 ? 1 : 0,
              preview_source: 'uniform',
              preview_user_name: null,
              rule: serialized,
            });
            setBatchSourceText('刚刚保存的批量规则已回显，下次打开会优先显示这套已生效配置。');

            const unchangedHint =
              response.unchanged_count > 0 ? `，其中 ${response.unchanged_count} 人规则本来就一致` : '';
            message.success(`批量应用成功，已更新 ${response.updated_count} 名员工${unchangedHint}`);
            setBatchOpen(false);
            await fetchUsers();
          } catch (error: any) {
            message.error(error?.response?.data?.detail || '批量应用失败');
          } finally {
            setBatchSubmitting(false);
          }
        },
      });
    } catch {
      // 表单校验提示由 antd 自动处理
    }
  };

  const columns = [
    {
      title: '姓名',
      dataIndex: 'full_name',
      key: 'full_name',
      width: 120,
    },
    {
      title: '用户名',
      dataIndex: 'username',
      key: 'username',
      width: 140,
    },
    {
      title: '状态',
      dataIndex: 'status',
      key: 'status',
      width: 100,
      render: (status: string) => {
        const statusMap: Record<string, { color: string; text: string }> = {
          pending: { color: 'orange', text: '待激活' },
          active: { color: 'green', text: '已激活' },
          disabled: { color: 'red', text: '已禁用' },
        };
        const item = statusMap[status];
        return item ? <Tag color={item.color}>{item.text}</Tag> : status;
      },
    },
    {
      title: '地点要求',
      key: 'location',
      width: 280,
      render: (_: unknown, record: UserWithRule) => {
        if (record.ruleLoading) {
          return <Tag>加载中...</Tag>;
        }
        if (!record.rule || !record.rule.location_required) {
          return <Tag>未启用</Tag>;
        }
        return (
          <Space direction="vertical" size={2}>
            <Tag color="blue">{record.rule.location_name || '已设置地点'}</Tag>
            <Typography.Text type="secondary">半径 {record.rule.allowed_radius_m}m</Typography.Text>
          </Space>
        );
      },
    },
    {
      title: '时间要求',
      key: 'time',
      width: 240,
      render: (_: unknown, record: UserWithRule) => {
        if (record.ruleLoading) {
          return <Tag>加载中...</Tag>;
        }
        if (!record.rule || !record.rule.time_required) {
          return <Tag>未启用</Tag>;
        }
        return (
          <Typography.Text>
            签到 {record.rule.checkin_start || '-'} ~ {record.rule.checkin_end || '-'}
          </Typography.Text>
        );
      },
    },
    {
      title: '工作日',
      key: 'work_days',
      width: 220,
      render: (_: unknown, record: UserWithRule) => {
        if (record.ruleLoading || !record.rule) {
          return '-';
        }

        const dayNames = ['', '一', '二', '三', '四', '五', '六', '日'];
        return record.rule.work_days.map((day) => `周${dayNames[day]}`).join(' ');
      },
    },
    {
      title: '操作',
      key: 'actions',
      width: 100,
      render: (_: unknown, record: UserWithRule) => (
        <Button
          type="primary"
          size="small"
          icon={<SettingOutlined />}
          onClick={() => navigate(`/rules/${record.id}`)}
        >
          配置
        </Button>
      ),
    },
  ];

  return (
    <div>
      <Typography.Title level={4} style={{ marginTop: 0 }}>
        打卡规则管理
      </Typography.Title>

      <Space style={{ marginBottom: 16 }} wrap>
        <Input
          placeholder="搜索用户名或姓名"
          prefix={<SearchOutlined />}
          value={search}
          onChange={(event) => {
            setSearch(event.target.value);
            setPage(1);
          }}
          style={{ width: 220 }}
          allowClear
        />
        <Select
          value={statusFilter}
          onChange={(value) => {
            setStatusFilter(value);
            setPage(1);
          }}
          style={{ width: 140 }}
          options={statusOptions}
        />
        <Button icon={<ReloadOutlined />} onClick={() => void fetchUsers()}>
          刷新
        </Button>
        <Button type="primary" icon={<TeamOutlined />} onClick={() => void openBatchModal()}>
          批量配置规则
        </Button>
      </Space>

      <Table
        columns={columns}
        dataSource={users}
        rowKey="id"
        loading={loading}
        scroll={{ x: 1180 }}
        pagination={{
          current: page,
          pageSize: 20,
          total,
          showTotal: (value) => `当前筛选共 ${value} 名员工`,
          onChange: (nextPage) => setPage(nextPage),
        }}
      />

      <Modal
        title="批量配置打卡规则"
        open={batchOpen}
        onCancel={() => setBatchOpen(false)}
        onOk={() => void submitBatchApply()}
        okText="应用到全部筛选结果"
        cancelText="取消"
        width={920}
        confirmLoading={batchSubmitting}
        okButtonProps={{ disabled: batchLoading || batchPreview.matched_count === 0 }}
      >
        <Space direction="vertical" size={12} style={{ width: '100%' }}>
          <Typography.Paragraph type="secondary" style={{ marginBottom: 0 }}>
            当前会按搜索“{search || '全部'}”和状态“{filteredStatusLabel}”匹配全部员工，跨分页生效。
          </Typography.Paragraph>

          <Alert
            type={batchDraftDirty || batchPreview.distinct_rule_count > 1 ? 'warning' : 'info'}
            showIcon
            message={`当前筛选命中 ${batchPreview.matched_count || total} 名员工，已有 ${batchPreview.configured_count} 人配置了规则`}
            description={batchSourceText}
          />

          <Space wrap>
            <Button onClick={() => void reloadSavedBatchConfig()} loading={batchLoading}>
              重新读取已生效规则
            </Button>
            <Button onClick={resetBatchDraftToDefaults}>重置为默认模板</Button>
          </Space>

          <Spin spinning={batchLoading}>
            <RuleForm
              form={batchForm}
              showSubmitButton={false}
              onValuesChange={handleBatchValuesChange}
            />
          </Spin>
        </Space>
      </Modal>
    </div>
  );
}
