import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminMerchantBannersScreen extends StatefulWidget {
  const AdminMerchantBannersScreen({super.key});

  @override
  State<AdminMerchantBannersScreen> createState() =>
      _AdminMerchantBannersScreenState();
}

class _AdminMerchantBannersScreenState
    extends State<AdminMerchantBannersScreen> {
  static const Color brandRed = Color(0xFFC21815);

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String _filter = 'pending';

  static const _filters = [
    (key: 'pending', label: 'لم تُراجع'),
    (key: 'approved', label: 'معتمدة'),
    (key: 'suspended', label: 'موقوفة'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await supabase.rpc('get_merchant_banners');
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(res as List);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Merchant banners error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: color,
    ));
  }

  /// تصنيف البنر
  String _groupOf(Map<String, dynamic> b) {
    if (b['status'] == 'suspended') return 'suspended';
    if (b['is_approved'] == true) return 'approved';
    return 'pending';
  }

  Future<void> _approve(Map<String, dynamic> b) async {
    try {
      final res = await supabase.rpc('approve_banner_booking',
          params: {'p_booking_id': b['id']});
      final map = Map<String, dynamic>.from(res as Map);

      if (map['ok'] == true) {
        await _load();
        _snack('اعتُمد البنر', Colors.green);
      } else {
        _snack(map['error']?.toString() ?? 'تعذر الاعتماد', Colors.red);
      }
    } catch (e) {
      debugPrint('Approve error: $e');
      _snack('تعذر تنفيذ العملية', Colors.red);
    }
  }

  /// نافذة الإيقاف مع السبب
  void _suspendDialog(Map<String, dynamic> b) {
    final ctrl = TextEditingController();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.block_rounded, color: Colors.red, size: 19),
                SizedBox(width: 10),
                Text('إيقاف البنر',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'سيُخفى البنر ويُعاد مبلغ '
                    '${(b['final_price'] as num?)?.toStringAsFixed(2)} ر.س '
                    'إلى رصيد ${b['store_name']}، ويصله إشعار بالسبب.',
                    style: const TextStyle(
                        fontFamily: 'Cairo', fontSize: 13, height: 1.9),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: ctrl,
                    maxLines: 3,
                    autofocus: true,
                    style:
                        const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    decoration: InputDecoration(
                      hintText:
                          'سبب الإيقاف — يظهر للتاجر في لوحته',
                      hintStyle: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Colors.grey.shade400),
                      filled: true,
                      fillColor: const Color(0xFFF7F8FA),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style:
                        TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: saving
                    ? null
                    : () async {
                        if (ctrl.text.trim().isEmpty) {
                          _snack('اكتب سبب الإيقاف', Colors.orange);
                          return;
                        }
                        setModal(() => saving = true);

                        try {
                          final res = await supabase
                              .rpc('suspend_banner_booking', params: {
                            'p_booking_id': b['id'],
                            'p_reason': ctrl.text.trim(),
                          });
                          final map = Map<String, dynamic>.from(res as Map);

                          if (ctx.mounted) Navigator.pop(ctx);

                          if (map['ok'] == true) {
                            await _load();
                            _snack(
                              'أُوقف البنر وأُعيد '
                              '${(map['refunded'] as num?)?.toStringAsFixed(2)} ر.س',
                              Colors.orange,
                            );
                          } else {
                            _snack(map['error']?.toString() ?? 'تعذر الإيقاف',
                                Colors.red);
                          }
                        } catch (e) {
                          debugPrint('Suspend error: $e');
                          setModal(() => saving = false);
                          _snack('تعذر تنفيذ العملية', Colors.red);
                        }
                      },
                child: Text(saving ? 'جاري...' : 'إيقاف واسترداد',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(dynamic raw) {
    final d = DateTime.tryParse((raw ?? '').toString());
    if (d == null) return '—';
    return '${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    final visible = _rows.where((b) => _groupOf(b) == _filter).toList();

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text('بنرات التجار',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 19,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Text('${visible.length}',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              color: Colors.grey.shade500)),
                    ],
                  ),

                  const SizedBox(height: 6),
                  Text(
                    'البنرات تُنشر تلقائياً — والمراجعة للإيقاف عند المخالفة',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: Colors.grey.shade500),
                  ),

                  const SizedBox(height: 18),

                  Wrap(
                    spacing: 8,
                    children: _filters.map((f) {
                      final count =
                          _rows.where((b) => _groupOf(b) == f.key).length;
                      final on = _filter == f.key;

                      return GestureDetector(
                        onTap: () => setState(() => _filter = f.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: on ? brandRed : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    on ? brandRed : const Color(0xFFEDEFF3)),
                          ),
                          child: Text(
                            '${f.label} ($count)',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12.5,
                              fontWeight:
                                  on ? FontWeight.bold : FontWeight.normal,
                              color:
                                  on ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                          child: CircularProgressIndicator(color: brandRed)),
                    )
                  else if (visible.isEmpty)
                    _empty()
                  else
                    ...visible.map(_card),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> b) {
    final group = _groupOf(b);
    final status = (b['status'] ?? '').toString();
    final reason = (b['rejection_reason'] ?? '').toString();
    final occasion = (b['occasion_name'] ?? '').toString();

    final (String label, Color color) = switch (status) {
      'paid' => ('مدفوع — لم يبدأ', Colors.blue),
      'scheduled' => ('مجدول', Colors.blue),
      'active' => ('يعرض الآن', Colors.green),
      'suspended' => ('موقوف', Colors.red),
      'expired' => ('انتهى', Colors.grey),
      'cancelled' => ('ألغاه التاجر', Colors.grey),
      _ => (status, Colors.grey),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: group == 'pending'
              ? Colors.orange.withValues(alpha: 0.35)
              : const Color(0xFFEDEFF3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ===== الصورة والترويسة =====
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((b['image_url'] ?? '').toString().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    b['image_url'],
                    width: 110,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 110,
                      height: 58,
                      color: const Color(0xFFF1F2F5),
                      child: const Icon(Icons.image_outlined,
                          size: 18, color: Colors.grey),
                    ),
                  ),
                ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (b['store_name'] ?? 'متجر').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${b['banner_type'] == 'wide' ? 'عريض' : 'صغير'} · '
                      '${b['slots_count']} بنر · '
                      'أسبوع ${b['week_number']} '
                      '(${_fmt(b['week_start'])} — ${_fmt(b['week_end'])})',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          color: Colors.grey.shade600),
                    ),
                    if (occasion.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(occasion,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: brandRed)),
                    ],
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: Color(0xFFEDEFF3), height: 1),
          const SizedBox(height: 10),

          Row(
            children: [
              Icon(
                b['target_type'] == 'product'
                    ? Icons.inventory_2_outlined
                    : Icons.storefront_outlined,
                size: 14,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Text(
                b['target_type'] == 'product' ? 'يفتح منتجاً' : 'يفتح المتجر',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: Colors.grey.shade600),
              ),
              const SizedBox(width: 16),
              Icon(Icons.visibility_outlined,
                  size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text('${b['impressions'] ?? 0}',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Colors.grey.shade600)),
              const SizedBox(width: 12),
              Icon(Icons.touch_app_outlined,
                  size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text('${b['clicks'] ?? 0}',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Colors.grey.shade600)),
              const Spacer(),
              Text(
                '${(b['final_price'] as num?)?.toStringAsFixed(2)} ر.س',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: brandRed),
              ),
            ],
          ),

          // ===== سبب الإيقاف =====
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  right: BorderSide(
                      color: Colors.red.withValues(alpha: 0.5), width: 2.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 15, color: Colors.red),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(reason,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            height: 1.8,
                            color: Colors.red)),
                  ),
                ],
              ),
            ),
          ],

          // ===== الأزرار =====
          if (group != 'suspended' &&
              (status == 'paid' ||
                  status == 'scheduled' ||
                  status == 'active')) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (group == 'pending')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approve(b),
                      icon: const Icon(Icons.check_rounded, size: 17),
                      label: const Text('اعتماد',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                if (group == 'pending') const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _suspendDialog(b),
                  icon: const Icon(Icons.block_rounded, size: 16),
                  label: const Text('إيقاف',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.ad_units_outlined, size: 58, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          Text(
            _filter == 'pending'
                ? 'لا بنرات بانتظار المراجعة'
                : _filter == 'approved'
                    ? 'لا بنرات معتمدة'
                    : 'لا بنرات موقوفة',
            style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 15, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
