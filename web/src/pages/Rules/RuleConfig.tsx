import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Button, Form, Spin, Typography, message } from 'antd';
import { ArrowLeftOutlined } from '@ant-design/icons';

import RuleForm, {
  createDefaultRuleFormValues,
  mapRuleToFormValues,
  serializeRuleValues,
  type RuleFormValues,
} from '../../components/Rules/RuleForm';
import { getUser } from '../../api/users';
import { getUserRule, setUserRule } from '../../api/rules';

export default function RuleConfig() {
  const { userId } = useParams<{ userId: string }>();
  const navigate = useNavigate();
  const [form] = Form.useForm<RuleFormValues>();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [userName, setUserName] = useState('');

  useEffect(() => {
    if (!userId) {
      return;
    }

    const fetchData = async () => {
      setLoading(true);
      try {
        const [user, rule] = await Promise.all([getUser(userId), getUserRule(userId)]);
        setUserName(user.full_name);
        form.setFieldsValue(mapRuleToFormValues(rule) ?? createDefaultRuleFormValues());
      } catch {
        message.error('获取规则数据失败');
      } finally {
        setLoading(false);
      }
    };

    void fetchData();
  }, [form, userId]);

  const handleSave = async () => {
    if (!userId) {
      return;
    }

    setSaving(true);
    try {
      const values = await form.validateFields();
      await setUserRule(userId, serializeRuleValues(values));
      message.success('规则保存成功');
    } catch (error: any) {
      if (error?.response?.data?.detail) {
        message.error(error.response.data.detail);
      }
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return <Spin size="large" style={{ display: 'block', margin: '100px auto' }} />;
  }

  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
        <Button icon={<ArrowLeftOutlined />} onClick={() => navigate('/rules')}>
          返回
        </Button>
        <Typography.Title level={4} style={{ margin: 0 }}>
          打卡规则 - {userName}
        </Typography.Title>
      </div>

      <RuleForm
        form={form}
        onSubmit={handleSave}
        submitting={saving}
        submitText="保存规则"
      />
    </div>
  );
}
