import client from './client';
import type { AttendanceListResponse, AttendanceStatistics } from '../types';

export async function getAttendance(params: {
  page?: number;
  page_size?: number;
  user_id?: string;
  date_from?: string;
  date_to?: string;
}): Promise<AttendanceListResponse> {
  const res = await client.get<AttendanceListResponse>('/attendance', { params });
  return res.data;
}

export async function getStatistics(date_from: string, date_to: string): Promise<AttendanceStatistics> {
  const res = await client.get<AttendanceStatistics>('/attendance/statistics', {
    params: { date_from, date_to },
  });
  return res.data;
}

export interface DailyStats {
  date: string;
  total: number;
  checkins: number;
  checkouts: number;
  late_count: number;
  early_leave_count: number;
}

export async function getDailyStatistics(date_from: string, date_to: string): Promise<DailyStats[]> {
  const res = await client.get<DailyStats[]>('/attendance/statistics/daily', {
    params: { date_from, date_to },
  });
  return res.data;
}
