import 'package:flutter/material.dart';
import '../models/attendance.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final List<AttendanceRecord> _records = [];
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadRecords() async {
    setState(() { _loading = true; _page = 1; });
    try {
      final data = await ApiService().getMyAttendance(page: 1, pageSize: 20);
      final items = (data['items'] as List).map((e) => AttendanceRecord.fromJson(e)).toList();
      if (mounted) {
        setState(() {
          _records.clear();
          _records.addAll(items);
          _hasMore = items.length >= 20;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    _page++;
    try {
      final data = await ApiService().getMyAttendance(page: _page, pageSize: 20);
      final items = (data['items'] as List).map((e) => AttendanceRecord.fromJson(e)).toList();
      if (mounted) {
        setState(() {
          _records.addAll(items);
          _hasMore = items.length >= 20;
        });
      }
    } catch (_) {
      _page--;
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('考勤记录'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('暂无考勤记录', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRecords,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _records.length + (_loadingMore ? 1 : 0),
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      if (index >= _records.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      final r = _records[index];
                      final isCheckin = r.recordType == 'checkin';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              // 类型徽标
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isCheckin ? Colors.blue[50] : Colors.teal[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  r.typeLabel,
                                  style: TextStyle(
                                    color: isCheckin ? Colors.blue : Colors.teal,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // 日期时间 + 状态
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${r.recordDate}  ${r.recordedAt.length >= 19 ? r.recordedAt.substring(11, 19) : ''}',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        _buildStatusChip(r),
                                        if (r.locationVerified != null) ...[
                                          const SizedBox(width: 6),
                                          Icon(
                                            r.locationVerified! ? Icons.location_on : Icons.location_off,
                                            size: 14,
                                            color: r.locationVerified! ? Colors.green : Colors.red,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // 人脸分数
                              if (r.faceScore != null)
                                Text(
                                  '${(r.faceScore! * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: r.faceVerified ? Colors.green[700] : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildStatusChip(AttendanceRecord r) {
    Color color;
    String label;
    if (r.isLate) {
      color = Colors.orange;
      label = '迟到';
    } else if (r.isEarlyLeave) {
      color = Colors.red;
      label = '早退';
    } else {
      color = Colors.green;
      label = '正常';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
