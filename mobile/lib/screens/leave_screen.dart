import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('请假'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: '申请请假'),
            Tab(text: '请假记录'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _LeaveApplyTab(onSubmitted: () => _tabCtrl.animateTo(1)),
          const _LeaveHistoryTab(),
        ],
      ),
    );
  }
}

// ============================================================
// 申请请假 Tab
// ============================================================
class _LeaveApplyTab extends StatefulWidget {
  final VoidCallback onSubmitted;
  const _LeaveApplyTab({required this.onSubmitted});

  @override
  State<_LeaveApplyTab> createState() => _LeaveApplyTabState();
}

class _LeaveApplyTabState extends State<_LeaveApplyTab> {
  final _formKey = GlobalKey<FormState>();
  String _leaveType = 'personal';
  final _reasonCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  double _days = 1;
  bool _loading = false;

  static const _typeOptions = [
    {'value': 'personal', 'label': '事假'},
    {'value': 'sick', 'label': '病假'},
    {'value': 'annual', 'label': '年假'},
    {'value': 'comp', 'label': '调休'},
    {'value': 'other', 'label': '其他'},
  ];

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? now) : (_endDate ?? _startDate ?? now),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
        } else {
          _endDate = picked;
        }
        _calcDays();
      });
    }
  }

  void _calcDays() {
    if (_startDate != null && _endDate != null) {
      _days = (_endDate!.difference(_startDate!).inDays + 1).toDouble();
      if (_days < 0.5) _days = 0.5;
    }
  }

  String _fmtDate(DateTime? d) => d == null ? '选择日期' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择请假日期'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiService().createLeaveRequest(
        leaveType: _leaveType,
        startDate: _fmtDate(_startDate),
        endDate: _fmtDate(_endDate),
        days: _days,
        reason: _reasonCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请假申请已提交，等待审批'), backgroundColor: Colors.green),
        );
        _reasonCtrl.clear();
        setState(() { _startDate = null; _endDate = null; _days = 1; });
        widget.onSubmitted();
      }
    } catch (e) {
      if (mounted) {
        String msg = '提交失败';
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
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 类型
            Text('请假类型', style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _typeOptions.map((t) {
                final selected = _leaveType == t['value'];
                return ChoiceChip(
                  label: Text(t['label']!),
                  selected: selected,
                  onSelected: (_) => setState(() => _leaveType = t['value']!),
                  selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // 日期
            Text('请假日期', style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(true),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(_fmtDate(_startDate)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('至')),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(false),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(_fmtDate(_endDate)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 天数调节
            Row(
              children: [
                Text('请假天数：', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: _days > 0.5 ? () => setState(() => _days -= 0.5) : null,
                ),
                Text('$_days 天', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () => setState(() => _days += 0.5),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 原因
            Text('请假原因', style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reasonCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '请详细说明请假原因...',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请填写请假原因' : null,
            ),
            const SizedBox(height: 28),

            // 提交
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('提交申请', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 请假记录 Tab
// ============================================================
class _LeaveHistoryTab extends StatefulWidget {
  const _LeaveHistoryTab();

  @override
  State<_LeaveHistoryTab> createState() => _LeaveHistoryTabState();
}

class _LeaveHistoryTabState extends State<_LeaveHistoryTab> {
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService().getMyLeaveRequests();
      setState(() => _records = List<Map<String, dynamic>>.from(data['items']));
    } catch (_) {}
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _cancel(String id) async {
    try {
      await ApiService().cancelLeaveRequest(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已取消'), backgroundColor: Colors.green),
      );
      _load();
    } catch (e) {
      String msg = '操作失败';
      if (e is DioException && e.response?.data is Map) {
        msg = e.response?.data['detail'] ?? msg;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('暂无请假记录', style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _records.length,
        itemBuilder: (context, i) {
          final r = _records[i];
          return _buildCard(r);
        },
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> r) {
    final status = r['status'] as String;
    Color statusColor;
    String statusText = r['status_label'] ?? status;
    switch (status) {
      case 'approved': statusColor = Colors.green; break;
      case 'rejected': statusColor = Colors.red; break;
      case 'cancelled': statusColor = Colors.grey; break;
      default: statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    r['leave_type_label'] ?? '',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${r['days']}天', style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(statusText, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('${r['start_date']} ~ ${r['end_date']}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text('原因：${r['reason']}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            if (r['approver_name'] != null) ...[
              const SizedBox(height: 4),
              Text('审批人：${r['approver_name']}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
            if (r['approve_remark'] != null && (r['approve_remark'] as String).isNotEmpty) ...[
              Text('审批备注：${r['approve_remark']}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
            if (status == 'pending') ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _cancel(r['id']),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('取消申请', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
