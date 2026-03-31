import client from './client';
import type { User, UserListResponse } from '../types';

export async function getUsers(params: {
  page?: number;
  page_size?: number;
  search?: string;
  status?: string;
  role?: string;
}): Promise<UserListResponse> {
  const res = await client.get<UserListResponse>('/users', { params });
  return res.data;
}

export async function getUser(id: string): Promise<User> {
  const res = await client.get<User>(`/users/${id}`);
  return res.data;
}

export async function createUser(data: {
  username: string;
  password: string;
  full_name: string;
  phone?: string;
  email?: string;
  role?: string;
}): Promise<User> {
  const res = await client.post<User>('/users', data);
  return res.data;
}

export async function updateUser(id: string, data: {
  full_name?: string;
  phone?: string;
  email?: string;
  role?: string;
  status?: string;
}): Promise<User> {
  const res = await client.put<User>(`/users/${id}`, data);
  return res.data;
}

export async function deleteUser(id: string) {
  const res = await client.delete(`/users/${id}`);
  return res.data;
}

export async function resetPassword(id: string) {
  const res = await client.post(`/users/${id}/reset-password`);
  return res.data;
}

export async function resetFace(id: string) {
  const res = await client.delete(`/users/${id}/face`);
  return res.data;
}
