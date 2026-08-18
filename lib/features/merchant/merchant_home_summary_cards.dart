// lib/features/merchant/dashboard/presentation/widgets/merchant_home_summary_cards.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:red_market_core/red_market_core.dart';

class MerchantHomeSummaryCards extends StatelessWidget {
  const MerchantHomeSummaryCards({super.key});

  static const Color primary = Color(0xFF4CAF50);

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim()) ?? 0.0;
  }

  double _readTotal(Map<String, dynamic> order) {
    // دعم أكثر من اسم عمود حسب قاعدة بياناتك
    return _toDouble(order['total_price'] ?? order['total_amount'] ?? 0);
  }

  // ✅ مكتمل = تم التسليم أو مكتمل (حسب طلبك)
  bool _isCompleted(String status) {
    final s = status.trim();
    return s == "تم التسليم" || s == "مكتمل";
  }

  // ✅ ملغي/مرفوض (لا يدخل ضمن نشط ولا ضمن أرباح)
  bool _isCanceled(String status) {
    final s = status.trim();
    return s == "ملغي" || s == "مرفوض";
  }

  // ✅ نشط = كل شيء غير المكتمل والملغي
  bool _isActive(String status) {
    return !_isCompleted(status) && !_isCanceled(status);
  }

  String _formatSar(double value) {
    final f = intl.NumberFormat("#,##0.00", "en");
    return f.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final merchantId = supabase.auth.currentUser?.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (merchantId == null) {
      return const Center(
        child: Text(
          "سجّل دخول أولاً",
          style: TextStyle(fontFamily: 'Cairo'),
        ),
      );
    }

    final ordersStream = supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('merchant_id', merchantId)
        .order('created_at', ascending: false);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ordersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _loadingRow(isDark);
        }

        final orders = snapshot.data ?? [];

        int activeCount = 0;
        int completedCount = 0;
        double profits = 0.0;

        for (final o in orders) {
          final status = (o['status'] ?? '').toString();

          if (_isActive(status)) activeCount++;

          if (_isCompleted(status)) {
            completedCount++;
            profits += _readTotal(o);
          }
        }

        return Row(
          children: [
            Expanded(
              child: _statCard(
                isDark: isDark,
                title: "طلبات نشطة",
                value: activeCount.toString(),
                icon: Icons.local_shipping_outlined,
                accent: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                isDark: isDark,
                title: "طلبات مكتملة",
                value: completedCount.toString(),
                icon: Icons.check_circle_outline,
                accent: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                isDark: isDark,
                title: "الأرباح",
                value: _formatSar(profits),
                icon: Icons.payments_outlined,
                accent: primary,
                valueWidget: PriceWidget(
                  price: profits,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _loadingRow(bool isDark) {
    Widget box() => Expanded(
          child: Container(
            height: 86,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );

    return Row(
      children: [
        box(),
        const SizedBox(width: 12),
        box(),
        const SizedBox(width: 12),
        box(),
      ],
    );
  }

  Widget _statCard({
    required bool isDark,
    required String title,
    required String value,
    required IconData icon,
    required Color accent,
    Widget? valueWidget,
  }) {
    return Container(
      height: 86,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withOpacity(isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                valueWidget ??
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
