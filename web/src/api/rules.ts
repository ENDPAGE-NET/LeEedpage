import client from './client';
import type { CheckinRule } from '../types';

export interface RulePayload {
  location_required?: boolean;
  location_name?: string | null;
  location_address?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  allowed_radius_m?: number;
  time_required?: boolean;
  checkin_start?: string | null;
  checkin_end?: string | null;
  checkout_start?: string | null;
  checkout_end?: string | null;
  work_days?: number[];
}

export interface BatchApplyRulesPayload {
  filters: {
    search?: string;
    status?: string;
  };
  rule: RulePayload;
}

export interface BatchApplyRulesResponse {
  matched_count: number;
  updated_count: number;
  unchanged_count: number;
}

export interface BatchRulePreviewResponse {
  matched_count: number;
  configured_count: number;
  distinct_rule_count: number;
  preview_source: 'uniform' | 'latest' | 'default';
  preview_user_name?: string | null;
  rule: RulePayload | null;
}

export async function getUserRule(userId: string): Promise<CheckinRule | null> {
  const res = await client.get<CheckinRule | null>(`/rules/users/${userId}`);
  return res.data;
}

export async function setUserRule(userId: string, data: RulePayload): Promise<CheckinRule> {
  const res = await client.put<CheckinRule>(`/rules/users/${userId}`, data);
  return res.data;
}

export async function batchApplyRules(data: BatchApplyRulesPayload): Promise<BatchApplyRulesResponse> {
  const res = await client.post<BatchApplyRulesResponse>('/rules/batch-apply', data);
  return res.data;
}

export async function getBatchRulePreview(params: {
  search?: string;
  status?: string;
}): Promise<BatchRulePreviewResponse> {
  const res = await client.get<BatchRulePreviewResponse>('/rules/batch-preview', { params });
  return res.data;
}
