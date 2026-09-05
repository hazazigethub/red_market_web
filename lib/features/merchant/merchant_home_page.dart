import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';

import 'merchant_nav.dart';
import 'products_page.dart';
import 'manage_reels_page.dart';
import 'merchant_reports_page.dart';
import 'merchant_promo_page.dart';
import 'merchant_subscriptions_page.dart';
import 'merchant_ads_page.dart';
import 'notifications_page.dart';
import 'store_settings_page.dart';
import 'merchant_bank_account_page.dart';
import 'useful_links_page.dart';

class MerchantHomePage extends StatefulWidget {
  const MerchantHomePage({super.key});

  @override
  State<MerchantHomePage> createState() => _MerchantHomePageState();
}

class _MerchantHomePageState extends State<MerchantHomePage> {
  /// -1 يعني شاشة الترحيب
  int _index = -1;

  @override
  void initState() {
    super.initState();
    MerchantNav.requested.addListener(_onNavRequest);
  }

  @override
  void dispose() {
    MerchantNav.requested.removeListener(_onNavRequest);
    super.dispose();
  }

  /// ينتقل للقسم المطلوب من شاشة أخرى
  void _onNavRequest() {
    final target = MerchantNav.requested.value;
    if (target == null || !mounted) return;
    setState(() => _index = target);
    MerchantNav.clear();
  }

  static const _sections = <Map<String, dynamic>>[
    {'label': 'منتجاتي', 'icon': Icons.inventory_2_outlined},
    {'label': 'الريلز', 'icon': Icons.video_library_outlined},
    {'label': 'التقارير', 'icon': Icons.bar_chart_outlined},
    {'label': 'رسائل المتابعين', 'icon': Icons.campaign_outlined},
    {'label': 'إعلاناتي', 'icon': Icons.ad_units_outlined},
    {'label': 'الاشتراكات', 'icon': Icons.card_membership_outlined},
    {'label': 'الإشعارات', 'icon': Icons.notifications_outlined},
    {'label': 'إعدادات المتجر', 'icon': Icons.settings_outlined},
    {'label': 'رصيد المتجر', 'icon': Icons.account_balance_wallet_outlined},
    {'label': 'روابط مفيدة', 'icon': Icons.link_outlined},
  ];

  Widget _sectionBody(int i) {
    switch (i) {
      case 0:
        return const ProductsPage();
      case 1:
        return const ManageReelsPage();
      case 2:
        return const MerchantReportsPage();
      case 3:
        return const MerchantPromoPage();
      case 4:
        return const MerchantAdsPage();
      case 5:
        return const MerchantSubscriptionsPage();
      case 6:
        return const NotificationsPage();
      case 7:
        return const StoreSettingsPage();
      case 8:
        return const MerchantBankAccountPage();
      case 9:
        return const UsefulLinksPage();
      default:
        return _welcome();
    }
  }

  // ===================== الإحصاءات =====================

  Future<int> _count(String table, String col) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return 0;
      final res = await Supabase.instance.client
          .from(table)
          .select('id')
          .eq(col, uid)
          .count(CountOption.exact);
      return res.count;
    } catch (_) {
      return 0;
    }
  }

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

  // ===================== شاشة الترحيب =====================

  Widget _welcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Text(
                'مرحباً بك في متجرك',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'اختر قسماً من القائمة لإدارة متجرك',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              LayoutBuilder(
                builder: (context, c) {
                  const gap = 16.0;
                  final cols = c.maxWidth >= 800
                      ? 4
                      : c.maxWidth >= 520
                          ? 2
                          : 1;
                  final w = (c.maxWidth - gap * (cols - 1)) / cols;

                  final stats = [
                    _stat('منتجاتي', _count('products', 'merchant_id')),
                    _stat('الريلز', _count('reels', 'merchant_id')),
                    _stat('زيارات متجري',
                        _count('analytics_visits', 'merchant_id')),
                    _stat('المتابعون', _followers()),
                  ];

                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    alignment: WrapAlignment.center,
                    children: stats
                        .map((s) => SizedBox(width: w, child: s))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, Future<int> future) => Container(
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
      );

  // ===================== القائمة الجانبية =====================

  Widget _sideMenu() {
    return Container(
      width: 236,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        itemCount: _sections.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return _menuItem(
              label: 'الرئيسية',
              icon: Icons.dashboard_outlined,
              selected: _index == -1,
              onTap: () => setState(() => _index = -1),
            );
          }

          final s = _sections[i - 1];
          return _menuItem(
            label: s['label'] as String,
            icon: s['icon'] as IconData,
            selected: _index == i - 1,
            onTap: () => setState(() => _index = i - 1),
          );
        },
      ),
    );
  }

  Widget _menuItem({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.brand : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(icon,
                    size: 19,
                    color:
                        selected ? Colors.white : const Color(0xFF8A93A6)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: selected
                          ? Colors.white
                          : const Color(0xFF4A5468),
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===================== البناء =====================

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        children: [
          if (wide) _sideMenu(),
          Expanded(
            child: Container(
              color: const Color(0xFFF7F8FA),
              child: Column(
                children: [
                  // شريط اختيار الأقسام على الشاشات الضيقة
                  if (!wide)
                    SizedBox(
                      height: 54,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: _sections.length + 1,
                        itemBuilder: (context, i) {
                          final selected =
                              (i == 0 && _index == -1) || _index == i - 1;
                          final label = i == 0
                              ? 'الرئيسية'
                              : _sections[i - 1]['label'] as String;

                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _index = i == 0 ? -1 : i - 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.brand
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                      color: selected
                                          ? AppColors.brand
                                          : Colors.grey.shade300),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: selected
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  Expanded(child: _sectionBody(_index)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
