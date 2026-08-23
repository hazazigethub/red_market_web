import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';

class NavItem {
  final String label;
  final IconData icon;
  final Widget page;
  const NavItem(this.label, this.icon, this.page);
}

class DashboardShell extends StatefulWidget {
  final String role;
  final List<NavItem> items;
  const DashboardShell({super.key, required this.role, required this.items});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  final supabase = Supabase.instance.client;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  int _index = 0;
  String _storeName = '';
  int _unread = 0;

  bool get _isMerchant => widget.role == 'merchant';

  @override
  void initState() {
    super.initState();
    _loadStoreName();
    if (_isMerchant) _loadUnread();
  }

  void goTo(String label) {
    final i = widget.items.indexWhere((e) => e.label == label);
    if (i >= 0) setState(() => _index = i);
  }

  Future<void> _loadStoreName() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;

      if (_isMerchant) {
        final m = await supabase
            .from('merchants')
            .select('store_name')
            .eq('id', uid)
            .maybeSingle();
        if (mounted) {
          setState(() => _storeName = (m?['store_name'] ?? 'متجري').toString());
        }
      } else {
        if (mounted) setState(() => _storeName = 'الإدارة');
      }
    } catch (e) {
      debugPrint('Store name error: $e');
    }
  }

  /// عدد إشعارات التاجر غير المقروءة
  Future<void> _loadUnread() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;

      final notifs = await supabase
          .from('notifications_log')
          .select('id, target_type, target_id, segment_filter')
          .eq('status', 'sent')
          .limit(200);

      final reads = await supabase
          .from('notification_reads')
          .select('notification_id')
          .eq('user_id', uid);

      final readIds = List<Map<String, dynamic>>.from(reads)
          .map((r) => r['notification_id']?.toString())
          .whereType<String>()
          .toSet();

      final mine = List<Map<String, dynamic>>.from(notifs).where((n) {
        final type = n['target_type'];
        final targetId = n['target_id'];
        final segment = n['segment_filter'];
        if (type == 'all') return true;
        if (type == 'specific' && targetId == uid) return true;
        if (type == 'segment' && segment != null) {
          return segment.toString().contains('merchant');
        }
        return false;
      });

      final count =
          mine.where((n) => !readIds.contains(n['id']?.toString())).length;

      if (mounted) setState(() => _unread = count);
    } catch (e) {
      debugPrint('Unread error: $e');
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 1100;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF7F8FA),
        body: Column(
          children: [
            _topBar(wide),
            Expanded(
              child: DashboardNav(
                goTo: goTo,
                child: widget.items[_index].page,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== الترويسة =====================

  Widget _topBar(bool wide) => Container(
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            if (_index != 0)
              TextButton.icon(
                onPressed: () => setState(() => _index = 0),
                icon: const Icon(Icons.home_rounded, size: 18),
                label: const Text('الرئيسية'),
                style: TextButton.styleFrom(foregroundColor: AppColors.brand),
              ),

            const Spacer(),

            // جرس الإشعارات — للتاجر فقط
            if (_isMerchant) ...[
              _bellButton(),
              const SizedBox(width: 16),
            ],

            // اسم المتجر
            if (_storeName.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storefront_outlined,
                        size: 17, color: AppColors.brand),
                    const SizedBox(width: 8),
                    Text(
                      _storeName,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937)),
                    ),
                  ],
                ),
              ),

            const SizedBox(width: 10),

            // زر الخروج
            IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded,
                  size: 20, color: Colors.red),
            ),
          ],
        ),
      );

  Widget _bellButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'الإشعارات',
          onPressed: () {
            goTo('الإشعارات');
            _loadUnread();
          },
          icon: const Icon(Icons.notifications_none_rounded,
              size: 24, color: Color(0xFF4A5468)),
        ),
        if (_unread > 0)
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _unread > 99 ? '99+' : '$_unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}

class DashboardNav extends InheritedWidget {
  final void Function(String label) goTo;
  const DashboardNav({super.key, required this.goTo, required super.child});

  static DashboardNav? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DashboardNav>();

  @override
  bool updateShouldNotify(DashboardNav oldWidget) => false;
}
