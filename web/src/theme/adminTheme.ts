import type { ThemeConfig } from 'antd';

export const adminTheme: ThemeConfig = {
  token: {
    colorPrimary: '#0b4d9b',
    colorInfo: '#0b4d9b',
    colorSuccess: '#0f9f7f',
    colorWarning: '#f59e0b',
    colorError: '#dc2626',
    colorText: '#0f172a',
    colorTextSecondary: '#667085',
    colorBorder: '#e2e8f0',
    colorBorderSecondary: '#edf2f7',
    colorBgLayout: '#f4f7fb',
    colorBgContainer: '#ffffff',
    colorFillSecondary: '#f8fafc',
    colorFillTertiary: '#f1f5f9',
    borderRadius: 18,
    borderRadiusLG: 24,
    borderRadiusSM: 14,
    fontFamily:
      '"Manrope","PingFang SC","Microsoft YaHei","Helvetica Neue",Arial,sans-serif',
    boxShadow:
      '0 16px 40px rgba(15, 23, 42, 0.06), 0 4px 12px rgba(15, 23, 42, 0.03)',
    boxShadowSecondary:
      '0 10px 30px rgba(15, 23, 42, 0.05), 0 2px 10px rgba(15, 23, 42, 0.03)',
  },
  components: {
    Layout: {
      headerBg: 'rgba(255,255,255,0.8)',
      siderBg: 'rgba(255,255,255,0.72)',
      bodyBg: '#f4f7fb',
      triggerBg: '#ffffff',
    },
    Menu: {
      itemBg: 'transparent',
      itemColor: '#475569',
      itemHoverBg: '#eef4fb',
      itemSelectedBg: '#e7f0fb',
      itemSelectedColor: '#0b4d9b',
      itemBorderRadius: 14,
      activeBarBorderWidth: 0,
      iconSize: 18,
    },
    Card: {
      borderRadiusLG: 28,
      boxShadowTertiary: '0 16px 36px rgba(15, 23, 42, 0.05)',
      bodyPadding: 20,
    },
    Button: {
      borderRadius: 999,
      controlHeight: 42,
      controlHeightLG: 48,
      fontWeight: 600,
    },
    Input: {
      borderRadius: 999,
      activeBorderColor: '#0b4d9b',
      hoverBorderColor: '#8bb1e5',
      colorBgContainer: '#f8fafc',
    },
    InputNumber: {
      borderRadius: 18,
    },
    Select: {
      borderRadius: 999,
      optionSelectedBg: '#eef4fb',
    },
    DatePicker: {
      borderRadius: 999,
      activeBorderColor: '#0b4d9b',
    },
    Table: {
      borderColor: '#edf2f7',
      headerBg: '#f8fafc',
      rowHoverBg: '#fbfdff',
      headerColor: '#334155',
      cellPaddingBlock: 15,
    },
    Modal: {
      borderRadiusLG: 28,
    },
    Tag: {
      borderRadiusSM: 999,
    },
    Statistic: {
      contentFontSize: 34,
      titleFontSize: 13,
    },
  },
};
