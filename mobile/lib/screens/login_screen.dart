import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _errorMsg;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      await ref.read(authProvider.notifier).login(
            _usernameCtrl.text.trim(),
            _passwordCtrl.text,
          );
    } catch (error) {
      if (!mounted) {
        return;
      }

      var msg = '登录失败，请稍后重试';
      if (error is DioException && (error.response?.statusCode == 401 || error.response?.statusCode == 400)) {
        final detail = error.response?.data?['detail'];
        if (detail is String && detail.isNotEmpty) {
          msg = detail;
        }
      } else if (error.toString().toLowerCase().contains('connection')) {
        msg = '网络连接失败，请检查当前网络';
      }

      setState(() => _errorMsg = msg);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 420;

    return Scaffold(
      body: Container(
        decoration: AppTheme.loginBackground(),
        child: Stack(
          children: [
            ...AppTheme.loginBackgroundDecorations(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(isWide ? 28 : 20, 18, isWide ? 28 : 20, 18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BrandBlock(theme: theme),
                        const SizedBox(height: 30),
                        Text(
                          '登录',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontSize: isWide ? 60 : 52,
                            height: 0.95,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '欢迎回来，请验证您的身份',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 28),
                        _LoginCard(
                          formKey: _formKey,
                          usernameCtrl: _usernameCtrl,
                          passwordCtrl: _passwordCtrl,
                          loading: _loading,
                          obscure: _obscure,
                          errorMsg: _errorMsg,
                          onToggleObscure: () => setState(() => _obscure = !_obscure),
                          onSubmit: _login,
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            'VERSION 1.0.0 • SECURE INFRASTRUCTURE',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 10,
                              letterSpacing: 2.6,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandBlock extends StatelessWidget {
  final ThemeData theme;

  const _BrandBlock({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.84),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B4D9B).withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(
            Icons.fingerprint_rounded,
            size: 28,
            color: Color(0xFF0B4D9B),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '熵析云枢',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ENTROPY AXIS',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 11,
                letterSpacing: 2.6,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController usernameCtrl;
  final TextEditingController passwordCtrl;
  final bool loading;
  final bool obscure;
  final String? errorMsg;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;

  const _LoginCard({
    required this.formKey,
    required this.usernameCtrl,
    required this.passwordCtrl,
    required this.loading,
    required this.obscure,
    required this.errorMsg,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
        ),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (errorMsg != null) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMsg!,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const _FieldLabel(
              icon: Icons.person_rounded,
              text: '用户名',
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: usernameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: '请输入您的账号',
              ),
              validator: (value) => (value == null || value.trim().isEmpty) ? '请输入用户名' : null,
            ),
            const SizedBox(height: 22),
            const _FieldLabel(
              icon: Icons.lock_rounded,
              text: '密码',
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: passwordCtrl,
              obscureText: obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                hintText: '请输入您的密码',
                suffixIcon: IconButton(
                  onPressed: onToggleObscure,
                  icon: Icon(
                    obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: (value) => (value == null || value.isEmpty) ? '请输入密码' : null,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF94A3B8),
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '忘记密码？',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: loading ? null : onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0B4D9B),
                  shadowColor: const Color(0xFF0B4D9B).withValues(alpha: 0.18),
                  elevation: 0,
                ),
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('登 录'),
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                  children: const [
                    TextSpan(text: '还没有账号？'),
                    TextSpan(
                      text: ' 立即注册',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FieldLabel({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}
