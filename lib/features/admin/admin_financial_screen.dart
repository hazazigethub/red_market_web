import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// التقرير المالي — إيرادات المنصة والتزاماتها
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
              constraints: const BoxConstraints(maxWidth: 1000),
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
    final subs = Map<String, dynamic>.from(d['subscriptions'] as Map);
    final ads = Map<String, dynamic>.from(d['ads'] as Map);
    final wallets = Map<String, dynamic>.from(d['wallets'] as Map);
    final refunds = Map<String, dynamic>.from(d['refunds'] as Map);

    final net = _n(d['net_revenue']);
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
          'إيرادات المنصة والتزاماتها تجاه التجار',
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11.5,
              color: Colors.grey.shade500),
        ),

        const SizedBox(height: 20),

        // ===== صافي الإيراد =====
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [brandRed, Color(0xFF8E1010)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('صافي الإيراد المحقق',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13.5,
                      color: Colors.white70)),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    net.toStringAsFixed(2),
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.1),
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text('ر.س',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: Colors.white70)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'الاشتراكات + الإعلانات المنتهية − الاستردادات',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10.5,
                    color: Colors.white60),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _whiteBox('الاشتراكات',
                        _n(subs['revenue'])),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _whiteBox('الإعلانات', _n(ads['earned'])),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ===== الالتزام =====
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
                        'مبالغ شحنها التجار ولم ينفقوها — ليست إيراداً',
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

        const SizedBox(height: 22),

        // ===== الأقسام الثلاثة =====
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 760;

            final cards = [
              _section(
                'الاشتراكات',
                Icons.card_membership_outlined,
                Colors.blue,
                [
                  ('الإيراد', _money(_n(subs['revenue'])), true),
                  ('اشتراكات نشطة', '${_i(subs['active'])}', false),
                  ('إجمالي الاشتراكات', '${_i(subs['total'])}', false),
                  ('فترات تجريبية', '${_i(subs['trials'])}', false),
                ],
              ),
              _section(
                'الإعلانات',
                Icons.ad_units_outlined,
                brandRed,
                [
                  ('محقق', _money(_n(ads['earned'])), true),
                  ('تحت التنفيذ', _money(_n(ads['pending'])), false),
                ],
              ),
              _section(
                'المحافظ',
                Icons.account_balance_wallet_outlined,
                Colors.green,
                [
                  ('شُحن', _money(_n(wallets['charged'])), false),
                  ('صُرف', _money(_n(wallets['spent'])), true),
                  ('الباقي', _money(_n(wallets['balance'])), false),
                ],
              ),
            ];

            if (!wide) {
              return Column(
                children: [
                  cards[0],
                  const SizedBox(height: 12),
                  cards[1],
                  const SizedBox(height: 12),
                  cards[2],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
                const SizedBox(width: 12),
                Expanded(child: cards[2]),
              ],
            );
          },
        ),

        const SizedBox(height: 16),

        // ===== الاستردادات =====
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEDEFF3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.undo_rounded,
                      size: 18, color: Colors.grey),
                  const SizedBox(width: 10),
                  const Text('الاستردادات',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 14),
              _line(
                'استرداد اشتراكات',
                '${_money(_n(refunds['subscriptions']))} '
                    '(${_i(refunds['subscriptions_count'])})',
              ),
              const SizedBox(height: 9),
              _line('أُعيد لمحافظ التجار',
                  _money(_n(refunds['wallet']))),
              const SizedBox(height: 10),
              Text(
                'استرداد الاشتراكات يُخصم من الإيراد — '
                'وما يعود للمحافظ يبقى التزاماً',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10.5,
                    height: 1.9,
                    color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _whiteBox(String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: Colors.white70)),
          const SizedBox(height: 5),
          Text(_money(value),
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _section(
    String title,
    IconData icon,
    Color color,
    List<(String, String, bool)> rows,
  ) {
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
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _line(r.$1, r.$2, bold: r.$3),
              )),
        ],
      ),
    );
  }

  Widget _line(String label, String value, {bool bold = false}) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.grey.shade600)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: bold ? 13.5 : 12.5,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: bold ? brandRed : const Color(0xFF1F2937))),
      ],
    );
  }
}
