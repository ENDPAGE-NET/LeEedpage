import client from './client';

export interface LeaveRequest {
  id: string;
  user_id: string;
  user_name: string | null;
  leave_type: string;
  leave_type_label: string;
  start_date: string;
  end_date: string;
  days: number;
  reason: string;
  status: string;
  status_label: string;
  approver_name: string | null;
  approve_remark: string | null;
  approved_at: string | null;
  created_at: string;
}

export interface LeaveListResponse {
  total: number;
  items: LeaveRequest[];
}

export async function getLeaveRequests(params: {
  page?: number;
  page_size?: number;
  status?: string;
  user_id?: string;
}): Promise<LeaveListResponse> {
  const res = await client.get<LeaveListResponse>('/leave/requests', { params });
  return res.data;
}

export async function approveLeave(id: string, action: 'approve' | 'reject', remark: string = '') {
  const res = await client.post(`/leave/${id}/approve`, { action, remark });
  return res.data;
}

export async function setLeaveBalance(userId: string, year: number, leaveType: string, totalDays: number) {
  const res = await client.put(`/leave/balance/${userId}`, null, {
    params: { year, leave_type: leaveType, total_days: totalDays },
  });
  return res.data;
}
