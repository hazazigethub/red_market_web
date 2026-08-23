import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';
import '../../shell/dashboard_shell.dart';

class MerchantHomePage extends StatelessWidget {
  const MerchantHomePage({super.key});

  /// يجلب عدد متابعي المتجر من عمود followers_count
  Future<int> _followers() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return 0;
      final res = await Supabase.instance.client
          .from('merchants')
          .select('followers_count')
          .eq('id', uid)
          .maybeSingle();
      return (res?['followers_count'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _count(String table, String col) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return 0;
      final res =
          await Supabase.instance.client.from(table).select('id').eq(col, uid);
      return (res as List).length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nav = DashboardNav.of(context);
    final tiles = <Map<String, dynamic>>[
      {'label': 'منتجاتي', 'icon': Icons.inventory_2_outlined},
      {'label': 'الريلز', 'icon': Icons.video_library_outlined},
      {'label': 'التقييمات', 'icon': Icons.star_outline},
      {'label': 'التقارير', 'icon': Icons.bar_chart_outlined},
      {'label': 'الاشتراكات', 'icon': Icons.card_membership_outlined},
      {'label': 'أوقات العمل', 'icon': Icons.schedule_outlined},
      {'label': 'الإشعارات', 'icon': Icons.notifications_outlined},
      {'label': 'إعدادات المتجر', 'icon': Icons.settings_outlined},
      {'label': 'الحساب البنكي', 'icon': Icons.account_balance_outlined},
      {'label': 'روابط مفيدة', 'icon': Icons.link_outlined},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _stat('منتجاتي', _count('products', 'merchant_id')),
            const SizedBox(width: 16),
            _stat('الريلز', _count('reels', 'merchant_id')),
            const SizedBox(width: 16),
            _stat('زيارات متجري', _count('analytics_visits', 'merchant_id')),
            const SizedBox(width: 16),
            _stat('المتابعون', _followers()),
          ]),
          const SizedBox(height: 32),
          const Text('الأقسام',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.extent(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            maxCrossAxisExtent: 240,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: tiles.map((t) {
              return InkWell(
                onTap: () => nav?.goTo(t['label'] as String),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(t['icon'] as IconData,
                          size: 36, color: AppColors.brand),
                      const SizedBox(height: 12),
                      Text(t['label'] as String,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, Future<int> future) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              FutureBuilder<int>(
                future: future,
                builder: (context, snap) => Text(
                  snap.hasData ? '${snap.data}' : '—',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brand),
                ),
              ),
            ],
          ),
        ),
      );
}
