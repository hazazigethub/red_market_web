import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// التقرير المالي — تفصيل مصادر الدخل والتزامات المنصة
class AdminFinancialScreen extends StatefulWidget {
  const AdminFinancialScreen({super.key});

  @override
  State<AdminFinancialScreen> createState() => _AdminFinancialScreenState();
}

class _AdminFinancialScreenState extends State<AdminFinancialScreen> {
  static const Color brandRed = Color(0xFFC21815);

  final supabase = Supabase.instance.client;

  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await supabase.rpc('get_financial_report');
      if (!mounted) return;
      setState(() {
        _data = Map<String, dynamic>.from(res as Map);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Financial report error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  double _n(dynamic v) => (v as num?)?.toDouble() ?? 0;
  int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
  String _money(double v) => '${v.toStringAsFixed(2)} ر.س';

  IconData _iconOf(String key) => switch (key) {
        'subscriptions' => Icons.card_membership_outlined,
        'banners' => Icons.view_carousel_outlined,
        'splash' => Icons.smartphone_outlined,
        'campaigns' => Icons.local_fire_department_outlined,
        _ => Icons.payments_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _load,
        color: brandRed,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(
                          child:
                              CircularProgressIndicator(color: brandRed)),
                    )
                  : (_data == null || _data!['ok'] != true)
                      ? _error()
                      : _content(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _error() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Text(
          _data?['error']?.toString() ?? 'تعذر تحميل التقرير',
          style: const TextStyle(
              fontFamily: 'Cairo', fontSize: 14, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _content() {
    final d = _data!;
    final sources = (d['sources'] as List?) ?? [];
    final wallets = Map<String, dynamic>.from(d['wallets'] as Map);

    final earned = _n(d['total_earned']);
    final pending = _n(d['total_pending']);
    final sold = _n(d['total_sold']);
    final refunded = _n(d['total_refunded']);
    final balance = _n(wallets['balance']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('التقرير المالي',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 19,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          'تفصيل مصادر الدخل — ما تحصّل فعلاً وما ينتظر التنفيذ',
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11.5,
              color: Colors.grey.shade500),
        ),

        const SizedBox(height: 20),

        // ===== الملخّص =====
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEDEFF3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الإيراد المحقق',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13.5,
                      color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    earned.toStringAsFixed(2),
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: brandRed,
                        height: 1.1),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('ر.س',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: Colors.grey.shade500)),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'خدمات انتهى تنفيذها — لا يمكن استردادها',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10.5,
                    color: Colors.grey.shade500),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Divider(color: Color(0xFFEDEFF3), height: 1),
              ),

              LayoutBuilder(
                builder: (context, c) {
                  const gap = 10.0;
                  final cols = c.maxWidth < 520 ? 2 : 3;
                  final w = (c.maxWidth - gap * (cols - 1)) / cols;

                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      SizedBox(
                        width: w,
                        child: _summaryBox('إجمالي المباع', sold,
                            Colors.grey.shade700),
                      ),
                      SizedBox(
                        width: w,
                        child: _summaryBox(
                            'تحت التنفيذ', pending, Colors.blue),
                      ),
                      SizedBox(
                        width: w,
                        child: _summaryBox(
                            'مستردّ', refunded, Colors.grey),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ===== التزام الأرصدة =====
        if (balance > 0)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    size: 20, color: Colors.orange),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('رصيد التجار — التزام عليك',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text(
                        'شُحن ${_money(_n(wallets['charged']))} · '
                        'صُرف ${_money(_n(wallets['spent']))}',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Text(
                  _money(balance),
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800),
                ),
              ],
            ),
          ),

        const SizedBox(height: 24),

        const Text('مصادر الدخل',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.bold)),

        const SizedBox(height: 14),

        // ===== بطاقات المصادر =====
        LayoutBuilder(
          builder: (context, c) {
            const gap = 12.0;
            final cols = c.maxWidth < 620 ? 1 : 2;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: sources
                  .map((s) => SizedBox(
                        width: w,
                        child: _sourceCard(
                            Map<String, dynamic>.from(s as Map)),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _summaryBox(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: Colors.grey.shade600)),
          const SizedBox(height: 5),
          Text(_money(value),
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  Widget _sourceCard(Map<String, dynamic> s) {
    final total = _n(s['total']);
    final earned = _n(s['earned']);
    final pending = _n(s['pending']);
    final refunded = _n(s['refunded']);
    final rate = total > 0 ? earned / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ===== الترويسة =====
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: brandRed.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(_iconOf(s['key'].toString()),
                    size: 17, color: brandRed),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  (s['name'] ?? '').toString(),
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                _money(total),
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937)),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              Text(
                '${_i(s['count'])} ${s['count_label'] ?? ''}',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: Colors.grey.shade600),
              ),
              if (s['extra'] != null && _i(s['extra']) > 0) ...[
                const SizedBox(width: 10),
                Text(
                  '· ${_i(s['extra'])} ${s['extra_label'] ?? ''}',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Colors.grey.shade500),
                ),
              ],
              const Spacer(),
              Text('إجمالي المباع',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      color: Colors.grey.shade400)),
            ],
          ),

          const SizedBox(height: 14),

          // ===== شريط النسبة =====
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 6,
              backgroundColor: const Color(0xFFF1F2F5),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ),

          const SizedBox(height: 14),

          _row('✅', 'محقق — تحصّل فعلاً', earned, Colors.green),
          const SizedBox(height: 9),
          _row('⏳', 'تحت التنفيذ — لم يكتمل', pending, Colors.blue),

          if (refunded > 0) ...[
            const SizedBox(height: 9),
            _row('↩', 'مستردّ للتاجر', refunded, Colors.grey),
          ],

          if ((s['note'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      s['note'].toString(),
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10.5,
                          color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String mark, String label, double value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11.5,
                  color: Colors.grey.shade600)),
        ),
        Text(_money(value),
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: color)),
      ],
    );
  }
}
