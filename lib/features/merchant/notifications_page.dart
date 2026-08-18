import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool showAll = true;
  final supabase = Supabase.instance.client;

  /// اختيار الأيقونة بناءً على النوع المخزن في العمود الجديد أو محتوى العنوان
  IconData _getIconData(String? iconType, String title) {
    switch (iconType) {
      case 'order':
        return Icons.shopping_basket_outlined;
      case 'offer':
        return Icons.campaign_outlined;
      case 'reservation':
        return Icons.event_available_outlined;
      default:
        // محاولة الاستنتاج من العنوان إذا كان النوع افتراضي
        if (title.contains('طلب')) return Icons.shopping_basket_outlined;
        if (title.contains('حجز')) return Icons.event_available_outlined;
        return Icons.notifications_none_outlined;
    }
  }

  String _formatTime(String createdAt) {
    DateTime dateTime = DateTime.parse(createdAt).toLocal();
    Duration diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    return DateFormat('MM-dd').format(dateTime);
  }

  /// تحديث حالة القراءة في العمود الجديد is_read
  Future<void> _markAsRead(String id) async {
    try {
      await supabase
          .from('notifications_log')
          .update({'is_read': true}).eq('id', id);
    } catch (e) {
      debugPrint("Error marking as read: $e");
    }
  }

  Future<void> _deleteNotification(String id) async {
    await supabase.from('notifications_log').delete().eq('id', id);
  }

  void _showNotificationDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(item['title'] ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            item['body'] ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 15),
          ),
        ),
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> _notificationsStream() {
    return supabase
        .from('notifications_log')
        .stream(primaryKey: ['id'])
        .eq('status', 'sent')
        .order('created_at', ascending: false);
  }

  /// فلترة الإشعارات (العامة + الخاصة بالتاجر + قسم التجار)
  List<Map<String, dynamic>> _filterForMerchant(
      List<Map<String, dynamic>> rows, String userId) {
    return rows.where((r) {
      final type = r['target_type'];
      final targetId = r['target_id'];
      final segment = r['segment_filter'];

      if (type == 'all') return true;
      if (type == 'specific' && targetId == userId) return true;
      if (type == 'segment' && segment != null && segment.contains('merchants'))
        return true;
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text("الإشعارات",
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo')),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: userId == null
          ? const Center(
              child: Text("سجّل دخول أولاً",
                  style: TextStyle(fontFamily: 'Cairo')))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _notificationsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF4CAF50)));
                }

                final allRows = snapshot.data ?? [];
                final myRows = _filterForMerchant(allRows, userId);

                if (myRows.isEmpty) return _buildEmptyState(isDark);

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: myRows.length,
                  itemBuilder: (context, index) {
                    final item = myRows[index];
                    final bool isRead = item['is_read'] ?? false;

                    return Dismissible(
                      key: Key(item['id'].toString()),
                      direction: DismissDirection.startToEnd,
                      onDismissed: (direction) =>
                          _deleteNotification(item['id'].toString()),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: InkWell(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () {
                          _markAsRead(item['id'].toString());
                          _showNotificationDialog(item);
                        },
                        child: _buildNotificationItem(
                          isDark: isDark,
                          title: item['title'] ?? '',
                          subtitle: item['body'] ?? '',
                          time: _formatTime(item['created_at']),
                          icon: _getIconData(
                              item['icon_type'], item['title'] ?? ''),
                          isUnread: !isRead,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildNotificationItem({
    required bool isDark,
    required String title,
    required String subtitle,
    required String time,
    required IconData icon,
    bool isUnread = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الوقت جهة اليسار
          Text(time,
              style: TextStyle(
                  color: isDark ? Colors.white24 : Colors.grey.shade400,
                  fontSize: 10)),
          const Spacer(),
          // المحتوى في المنتصف
          Expanded(
            flex: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isUnread)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50), shape: BoxShape.circle),
                      ),
                    Text(title,
                        style: TextStyle(
                            fontWeight:
                                isUnread ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                            fontFamily: 'Cairo',
                            color: isDark ? Colors.white : Colors.black)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                        fontFamily: 'Cairo',
                        fontSize: 12),
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 15),
          // الأيقونة جهة اليمين
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color:
                    const Color(0xFF4CAF50).withOpacity(isDark ? 0.15 : 0.05),
                shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFF4CAF50), size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 50, color: isDark ? Colors.white12 : Colors.grey.shade300),
          const SizedBox(height: 10),
          const Text("لا توجد إشعارات حالياً",
              style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
        ],
      ),
    );
  }
}
