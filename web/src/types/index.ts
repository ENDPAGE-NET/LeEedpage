export interface User {
  id: string;
  username: string;
  full_name: string;
  phone: string | null;
  email: string | null;
  role: 'admin' | 'employee';
  status: 'pending' | 'active' | 'disabled';
  must_change_password: boolean;
  has_face: boolean;
  avatar_url?: string | null;
  face_image_url?: string | null;
  created_at: string;
  updated_at: string;
}

export interface UserListResponse {
  total: number;
  items: User[];
}

export interface LoginRequest {
  username: string;
  password: string;
}

export interface TokenResponse {
  access_token: string;
  refresh_token: string;
  token_type: string;
}

export interface CheckinRule {
  id: string;
  user_id: string;
  location_required: boolean;
  location_name: string | null;
  location_address: string | null;
  latitude: number | null;
  longitude: number | null;
  allowed_radius_m: number;
  time_required: boolean;
  checkin_start: string | null;
  checkin_end: string | null;
  checkout_start: string | null;
  checkout_end: string | null;
  work_days: number[];
}

export interface AttendanceRecord {
  id: string;
  user_id: string;
  user_name: string | null;
  record_date: string;
  record_type: 'checkin' | 'checkout';
  face_verified: boolean;
  face_score: number | null;
  location_verified: boolean | null;
  latitude: number | null;
  longitude: number | null;
  distance_m: number | null;
  is_late: boolean;
  is_early_leave: boolean;
  device_info: string | null;
  recorded_at: string;
}

export interface AttendanceListResponse {
  total: number;
  items: AttendanceRecord[];
}

export interface AttendanceStatistics {
  total_records: number;
  total_checkins: number;
  total_checkouts: number;
  late_count: number;
  early_leave_count: number;
  date_range_start: string;
  date_range_end: string;
}
