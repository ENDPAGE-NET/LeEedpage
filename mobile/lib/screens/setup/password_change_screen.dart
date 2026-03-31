import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class PasswordChangeScreen extends ConsumerStatefulWidget {
  const PasswordChangeScreen({super.key});

  @override
  ConsumerState<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends ConsumerState<PasswordChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiService().changePassword(_oldPwdCtrl.text, _newPwdCtrl.text);
      await ref.read(authProvider.notifier).refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密码修改成功'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        String msg = '密码修改失败，请检查原密码';
        if (e is DioException && e.response?.data is Map) {
          final detail = e.response?.data['detail'];
          if (detail is String) msg = detail;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _oldPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDeco(String label, IconData icon, bool obscure, VoidCallback toggle) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey[400]),
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
      suffixIcon: IconButton(
        icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey[400]),
        onPressed: toggle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('修改密码'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shield_outlined, size: 32, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 16),
              const Text('更新您的安全凭据', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                '考勤安全是合规的基础。\n新密码需包含字母与数字。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.5),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _oldPwdCtrl,
                obscureText: _obscureOld,
                decoration: _inputDeco('当前密码', Icons.lock_outline, _obscureOld, () => setState(() => _obscureOld = !_obscureOld)),
                validator: (v) => (v == null || v.isEmpty) ? '请输入原密码' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _newPwdCtrl,
                obscureText: _obscureNew,
                decoration: _inputDeco('新密码', Icons.lock, _obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入新密码';
                  if (v.length < 6) return '密码至少6个字符';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                decoration: _inputDeco('确认新密码', Icons.lock, _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm)),
                validator: (v) => v != _newPwdCtrl.text ? '两次密码不一致' : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading ? const SizedBox.shrink() : const Icon(Icons.arrow_forward),
                  label: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('提交修改', style: TextStyle(fontSize: 16)),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 安全常识提示
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.security, size: 16, color: Colors.blue[400]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '安全常识指南\n密码设置建议使用字母、数字和特殊字符的组合，长度不少于6位。',
                        style: TextStyle(fontSize: 11, color: Colors.blue[700], height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
