import client from './client';
import type { LoginRequest, TokenResponse, User } from '../types';

export async function login(data: LoginRequest): Promise<TokenResponse> {
  const res = await client.post<TokenResponse>('/auth/login', data);
  return res.data;
}

export async function refreshToken(refresh_token: string): Promise<TokenResponse> {
  const res = await client.post<TokenResponse>('/auth/refresh', { refresh_token });
  return res.data;
}

export async function getCurrentUser(): Promise<User> {
  const res = await client.get<User>('/users/me');
  return res.data;
}

export async function changePassword(old_password: string, new_password: string) {
  const res = await client.post('/auth/change-password', { old_password, new_password });
  return res.data;
}
