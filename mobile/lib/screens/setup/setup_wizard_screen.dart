import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'password_change_screen.dart';
import 'face_registration_screen.dart';

class SetupWizardScreen extends ConsumerStatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen> {
  bool _activating = false;

  Future<void> _tryActivate() async {
    setState(() => _activating = true);
    try {
      await ApiService().completeActivation();
      await ref.read(authProvider.notifier).refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('账户激活成功！'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = '激活失败';
        if (e is DioException && e.response?.data is Map) {
          final detail = e.response?.data['detail'];
          if (detail is String) msg = detail;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox();

    final passwordDone = !user.mustChangePassword;
    final faceDone = user.hasFace;
    final progress = ((passwordDone ? 1 : 0) + (faceDone ? 1 : 0)) / 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('账户设置'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            child: const Text('退出'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // 顶部图标
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shield_outlined, size: 36, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 20),
            const Text('完成账户初始化', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '为了确保您的考勤安全，请按照以下步骤\n完成设置。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.5),
            ),
            const SizedBox(height: 28),

            // 步骤卡片
            _StepCard(
              step: 1,
              title: '修改密码',
              subtitle: passwordDone ? '已完成' : '确保您的账户安全性',
              icon: Icons.lock_outline,
              done: passwordDone,
              onTap: passwordDone
                  ? null
                  : () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PasswordChangeScreen()),
                      );
                      if (result == true) ref.read(authProvider.notifier).refreshUser();
                    },
            ),
            const SizedBox(height: 12),
            _StepCard(
              step: 2,
              title: '注册人脸',
              subtitle: faceDone ? '已完成' : '用于日常上下班打卡验证',
              icon: Icons.face,
              done: faceDone,
              onTap: faceDone
                  ? null
                  : () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FaceRegistrationScreen()),
                      );
                      if (result == true) ref.read(authProvider.notifier).refreshUser();
                    },
            ),
            const SizedBox(height: 24),

            // 进度
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('当前进度  ', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    value: progress,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: Colors.grey[200],
                  ),
                ),
                Text('  ${(progress * 100).toInt()}%', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 32),

            // 激活按钮
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: (passwordDone && faceDone && !_activating) ? _tryActivate : null,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _activating
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('激活账户', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),
            if (!passwordDone || !faceDone)
              Text('请先完成上述步骤', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            const SizedBox(height: 16),
            // 提示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue[400]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '完成设置后即可开始正常打卡',
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int step;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool done;
  final VoidCallback? onTap;

  const _StepCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.done,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: done ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: done ? BorderSide(color: Colors.green[200]!) : BorderSide.none,
      ),
      color: done ? Colors.green[50] : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: done ? Colors.green : Colors.blue,
                child: done
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : Text('$step', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 16, color: done ? Colors.green[700] : Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: done ? Colors.green[700] : null)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: done ? Colors.green[500] : Colors.grey[500])),
                  ],
                ),
              ),
              if (done)
                Icon(Icons.check_circle, color: Colors.green[400], size: 22)
              else
                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
