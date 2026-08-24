import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';
import '../../shell/dashboard_shell.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  Future<int> _count(String table, [String? col, dynamic val]) async {
    try {
      var q = Supabase.instance.client.from(table).select('id');
      if (col != null) q = q.eq(col, val);
      return (await q as List).length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nav = DashboardNav.of(context);
    final tiles = <Map<String, dynamic>>[
      {'label': 'إدارة العملاء', 'icon': Icons.person_search_outlined},
      {'label': 'إدارة التجار', 'icon': Icons.manage_accounts_outlined},
      {'label': 'التجار الجدد', 'icon': Icons.fiber_new_outlined},
      {'label': 'التصنيفات', 'icon': Icons.category_outlined},
      {'label': 'إدارة المنتجات', 'icon': Icons.inventory_2_outlined},
      {'label': 'البلاغات', 'icon': Icons.report_problem_outlined},
      {'label': 'أكواد الخصم', 'icon': Icons.local_offer_outlined},
      {'label': 'الإشعارات', 'icon': Icons.notifications_outlined},
      {'label': 'النشرة الأسبوعية', 'icon': Icons.mail_outline_rounded},
      {'label': 'البنرات', 'icon': Icons.ad_units_outlined},
      {'label': 'الإعلانات', 'icon': Icons.campaign_outlined},
      {'label': 'الزيارات', 'icon': Icons.trending_up_outlined},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _stat('العملاء', _count('profiles', 'role', 'customer')),
            const SizedBox(width: 16),
            _stat('التجار', _count('profiles', 'role', 'merchant')),
            const SizedBox(width: 16),
            _stat('المنتجات', _count('products')),
            const SizedBox(width: 16),
            _stat('البلاغات', _count('reports', 'status', 'pending')),
            const SizedBox(width: 16),
            _stat('بانتظار الفحص', _count('merchants', 'is_verified', false)),
          ]),
          const SizedBox(height: 32),
          const Text('الأقسام',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
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
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(t['icon'] as IconData, size: 36, color: AppColors.brand),
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
            border: Border.all(color: Colors.grey.shade200),
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
