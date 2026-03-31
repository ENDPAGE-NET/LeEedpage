import type { FormInstance } from 'antd';
import { Button, Card, Checkbox, Divider, Form, Input, InputNumber, Space, Switch, TimePicker } from 'antd';
import dayjs from 'dayjs';
import type { Dayjs } from 'dayjs';

import type { CheckinRule } from '../../types';
import LocationPicker, { type RuleLocationValue } from './LocationPicker';

const weekDays = [
  { label: '周一', value: 1 },
  { label: '周二', value: 2 },
  { label: '周三', value: 3 },
  { label: '周四', value: 4 },
  { label: '周五', value: 5 },
  { label: '周六', value: 6 },
  { label: '周日', value: 7 },
];

type RuleFormSource = Partial<
  Pick<
    CheckinRule,
    | 'location_required'
    | 'location_name'
    | 'location_address'
    | 'latitude'
    | 'longitude'
    | 'allowed_radius_m'
    | 'time_required'
    | 'checkin_start'
    | 'checkin_end'
    | 'checkout_start'
    | 'checkout_end'
    | 'work_days'
  >
>;

export interface RuleFormValues {
  location_required: boolean;
  location_name?: string | null;
  location_address?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  allowed_radius_m?: number;
  time_required: boolean;
  checkin_start?: Dayjs | null;
  checkin_end?: Dayjs | null;
  checkout_start?: Dayjs | null;
  checkout_end?: Dayjs | null;
  work_days: number[];
}

interface Props {
  form: FormInstance<RuleFormValues>;
  onSubmit?: () => void;
  onValuesChange?: (changedValues: Partial<RuleFormValues>, values: RuleFormValues) => void;
  submitting?: boolean;
  submitText?: string;
  showSubmitButton?: boolean;
}

export function createDefaultRuleFormValues(): RuleFormValues {
  return {
    location_required: false,
    location_name: null,
    location_address: null,
    latitude: null,
    longitude: null,
    allowed_radius_m: 200,
    time_required: false,
    checkin_start: null,
    checkin_end: null,
    checkout_start: null,
    checkout_end: null,
    work_days: [1, 2, 3, 4, 5],
  };
}

export function mapRuleToFormValues(rule?: RuleFormSource | null): RuleFormValues {
  const defaults = createDefaultRuleFormValues();
  if (!rule) {
    return defaults;
  }

  return {
    location_required: rule.location_required ?? defaults.location_required,
    location_name: rule.location_name ?? defaults.location_name,
    location_address: rule.location_address ?? defaults.location_address,
    latitude: rule.latitude ?? defaults.latitude,
    longitude: rule.longitude ?? defaults.longitude,
    allowed_radius_m: rule.allowed_radius_m ?? defaults.allowed_radius_m,
    time_required: rule.time_required ?? defaults.time_required,
    checkin_start: rule.checkin_start ? dayjs(rule.checkin_start, 'HH:mm') : null,
    checkin_end: rule.checkin_end ? dayjs(rule.checkin_end, 'HH:mm') : null,
    checkout_start: rule.checkout_start ? dayjs(rule.checkout_start, 'HH:mm') : null,
    checkout_end: rule.checkout_end ? dayjs(rule.checkout_end, 'HH:mm') : null,
    work_days: rule.work_days?.length ? rule.work_days : defaults.work_days,
  };
}

export function serializeRuleValues(values: RuleFormValues) {
  return {
    location_required: values.location_required || false,
    location_name: values.location_name || null,
    location_address: values.location_address || null,
    latitude: values.latitude ?? null,
    longitude: values.longitude ?? null,
    allowed_radius_m: values.allowed_radius_m || 200,
    time_required: values.time_required || false,
    checkin_start: values.checkin_start ? values.checkin_start.format('HH:mm') : null,
    checkin_end: values.checkin_end ? values.checkin_end.format('HH:mm') : null,
    checkout_start: values.checkout_start ? values.checkout_start.format('HH:mm') : null,
    checkout_end: values.checkout_end ? values.checkout_end.format('HH:mm') : null,
    work_days: values.work_days?.length ? values.work_days : [1, 2, 3, 4, 5],
  };
}

export default function RuleForm({
  form,
  onSubmit,
  onValuesChange,
  submitting = false,
  submitText = '保存规则',
  showSubmitButton = true,
}: Props) {
  const locationRequired = Form.useWatch('location_required', form) ?? false;
  const timeRequired = Form.useWatch('time_required', form) ?? false;
  const latitude = Form.useWatch('latitude', form);
  const longitude = Form.useWatch('longitude', form);
  const locationName = Form.useWatch('location_name', form);
  const locationAddress = Form.useWatch('location_address', form);

  const handleLocationChange = (location: RuleLocationValue) => {
    form.setFieldsValue({
      latitude: location.latitude ?? null,
      longitude: location.longitude ?? null,
      location_name: location.location_name ?? null,
      location_address: location.location_address ?? null,
    });
  };

  return (
    <Form
      form={form}
      layout="vertical"
      onValuesChange={onValuesChange}
      onFinish={() => {
        void onSubmit?.();
      }}
    >
      <Form.Item name="location_name" hidden>
        <Input />
      </Form.Item>
      <Form.Item name="location_address" hidden>
        <Input />
      </Form.Item>
      <Form.Item name="latitude" hidden>
        <InputNumber />
      </Form.Item>
      <Form.Item name="longitude" hidden>
        <InputNumber />
      </Form.Item>

      <Card title="工作日设置" style={{ marginBottom: 16 }}>
        <Form.Item
          name="work_days"
          label="工作日"
          rules={[{ required: true, message: '至少选择一个工作日' }]}
        >
          <Checkbox.Group options={weekDays} />
        </Form.Item>
      </Card>

      <Card title="地点要求" style={{ marginBottom: 16 }}>
        <Form.Item name="location_required" label="启用地点打卡" valuePropName="checked">
          <Switch />
        </Form.Item>
        {locationRequired ? (
          <>
            <LocationPicker
              value={{
                latitude,
                longitude,
                location_name: locationName,
                location_address: locationAddress,
              }}
              onChange={handleLocationChange}
            />
            <Form.Item
              name="allowed_radius_m"
              label="允许半径（米）"
              style={{ marginTop: 16, marginBottom: 0 }}
              rules={[{ required: true, message: '请输入允许半径' }]}
            >
              <InputNumber style={{ width: '100%' }} min={10} max={10000} />
            </Form.Item>
          </>
        ) : null}
      </Card>

      <Card title="时间要求" style={{ marginBottom: 16 }}>
        <Form.Item name="time_required" label="启用时间打卡" valuePropName="checked">
          <Switch />
        </Form.Item>
        {timeRequired ? (
          <>
            <Divider plain>签到时间窗口</Divider>
            <Space wrap>
              <Form.Item name="checkin_start" label="最早签到">
                <TimePicker format="HH:mm" />
              </Form.Item>
              <Form.Item name="checkin_end" label="最晚签到（超过算迟到）">
                <TimePicker format="HH:mm" />
              </Form.Item>
            </Space>

            <Divider plain>签退时间窗口</Divider>
            <Space wrap>
              <Form.Item name="checkout_start" label="最早签退（之前算早退）">
                <TimePicker format="HH:mm" />
              </Form.Item>
              <Form.Item name="checkout_end" label="最晚签退">
                <TimePicker format="HH:mm" />
              </Form.Item>
            </Space>
          </>
        ) : null}
      </Card>

      {showSubmitButton ? (
        <Button type="primary" htmlType="submit" loading={submitting} size="large">
          {submitText}
        </Button>
      ) : null}
    </Form>
  );
}
