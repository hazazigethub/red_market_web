import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// إدارة إعلان الشاشة الرئيسية — الأيام والمراجعة
class AdminSplashAdsScreen extends StatefulWidget {
  const AdminSplashAdsScreen({super.key});

  @override
  State<AdminSplashAdsScreen> createState() => _AdminSplashAdsScreenState();
}

class _AdminSplashAdsScreenState extends State<AdminSplashAdsScreen> {
  static const Color brandRed = Color(0xFFC21815);

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _days = [];
  List<Map<String, dynamic>> _ads = [];
  bool _loading = true;
  bool _generating = false;

  int _tab = 0;
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
      final days = await supabase
          .from('splash_ad_days')
          .select()
          .gte('ad_date', DateTime.now().toIso8601String().substring(0, 10))
          .order('ad_date');

      final ads = await supabase
          .from('splash_ads')
          .select('*, merchants(store_name)')
          .order('ad_date', ascending: false);

      if (!mounted) return;
      setState(() {
        _days = List<Map<String, dynamic>>.from(days);
        _ads = List<Map<String, dynamic>>.from(ads);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Splash admin error: $e');
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

  Future<void> _generate() async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final res = await supabase
          .rpc('generate_splash_days', params: {'p_count': 30});
      await _load();
      _snack('أُضيف ${res ?? 30} يوماً', Colors.green);
    } catch (e) {
      debugPrint('Generate error: $e');
      _snack('تعذر التوليد', Colors.red);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// نافذة تعديل اليوم
  void _editDay(Map<String, dynamic> d) {
    final price = TextEditingController(
        text: '${(d['price'] as num?)?.toInt() ?? 0}');
    final occasion =
        TextEditingController(text: (d['occasion_name'] ?? '').toString());
    bool isOpen = d['is_open'] == true;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: brandRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.event_rounded,
                      color: brandRed, size: 17),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    (d['ad_date'] ?? '').toString(),
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style:
                        const TextStyle(fontFamily: 'Cairo', fontSize: 13.5),
                    decoration: _dec('سعر اليوم', Icons.payments_outlined),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: occasion,
                    style:
                        const TextStyle(fontFamily: 'Cairo', fontSize: 13.5),
                    decoration:
                        _dec('اسم المناسبة', Icons.celebration_outlined),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: isOpen,
                    activeColor: brandRed,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('الحجز مفتوح',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold)),
                    onChanged: (v) => setModal(() => isOpen = v),
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
                  backgroundColor: brandRed,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: saving
                    ? null
                    : () async {
                        setModal(() => saving = true);
                        try {
                          await supabase.from('splash_ad_days').update({
                            'price': int.tryParse(price.text.trim()) ?? 0,
                            'occasion_name': occasion.text.trim().isEmpty
                                ? null
                                : occasion.text.trim(),
                            'is_open': isOpen,
                          }).eq('ad_date', d['ad_date']);

                          if (ctx.mounted) Navigator.pop(ctx);
                          await _load();
                          _snack('حُفظ اليوم', Colors.green);
                        } catch (e) {
                          debugPrint('Save error: $e');
                          setModal(() => saving = false);
                          _snack('تعذر الحفظ', Colors.red);
                        }
                      },
                child: Text(saving ? 'جاري الحفظ...' : 'حفظ',
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

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          fontFamily: 'Cairo', fontSize: 13, color: Colors.grey.shade600),
      prefixIcon: Icon(icon, size: 19, color: Colors.grey.shade500),
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: brandRed, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  // ===================== المراجعة =====================

  String _groupOf(Map<String, dynamic> a) {
    if (a['status'] == 'suspended') return 'suspended';
    if (a['is_approved'] == true) return 'approved';
    return 'pending';
  }

  Future<void> _approve(Map<String, dynamic> a) async {
    try {
      await supabase.from('splash_ads').update({
        'is_approved': true,
        'rejection_reason': null,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', a['id']);

      await _load();
      _snack('اعتُمد الإعلان', Colors.green);
    } catch (e) {
      debugPrint('Approve error: $e');
      _snack('تعذر الاعتماد', Colors.red);
    }
  }

  void _suspendDialog(Map<String, dynamic> a) {
    final ctrl = TextEditingController();
    bool saving = false;

    final store =
        (a['merchants']?['store_name'] ?? 'المتجر').toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.block_rounded, color: Colors.red, size: 19),
                SizedBox(width: 10),
                Text('إيقاف الإعلان',
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
                    'سيُوقف الإعلان ويُعاد مبلغ '
                    '${(a['final_price'] as num?)?.toStringAsFixed(2)} ر.س '
                    'إلى رصيد $store، ويصله إشعار بالسبب.',
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
                      hintText: 'سبب الإيقاف — يظهر للتاجر في لوحته',
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
                              .rpc('suspend_splash_ad', params: {
                            'p_ad_id': a['id'],
                            'p_reason': ctrl.text.trim(),
                          });
                          final map = Map<String, dynamic>.from(res as Map);

                          if (ctx.mounted) Navigator.pop(ctx);

                          if (map['ok'] == true) {
                            await _load();
                            _snack(
                              'أُوقف الإعلان وأُعيد '
                              '${(map['refunded'] as num?)?.toStringAsFixed(2)} ر.س',
                              Colors.orange,
                            );
                          } else {
                            _snack(
                                map['error']?.toString() ?? 'تعذر الإيقاف',
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

  // ===================== البناء =====================

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
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('إعلان الشاشة الرئيسية',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 19,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    'موضع واحد حصري لكل يوم — والحجز يبدأ بعد ثلاثة أيام',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: Colors.grey.shade500),
                  ),

                  const SizedBox(height: 18),

                  Wrap(
                    spacing: 8,
                    children: [
                      _mainTab(0, 'الأيام والأسعار'),
                      _mainTab(1, 'المراجعة'),
                    ],
                  ),

                  const SizedBox(height: 18),

                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                          child: CircularProgressIndicator(color: brandRed)),
                    )
                  else if (_tab == 0)
                    _daysView()
                  else
                    _reviewView(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mainTab(int index, String label) {
    final on = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: on ? brandRed : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? brandRed : const Color(0xFFEDEFF3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: on ? FontWeight.bold : FontWeight.normal,
            color: on ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  // ===== الأيام =====

  Widget _daysView() {
    final taken = <String>{
      for (final a in _ads)
        if (['paid', 'scheduled', 'active'].contains(a['status']))
          (a['ad_date'] ?? '').toString()
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('${_days.length} يوماً',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    color: Colors.grey.shade600)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _generating ? null : _generate,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(_generating ? 'جاري...' : 'توليد 30 يوماً',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: brandRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        if (_days.isEmpty)
          _emptyMsg('لا أيام')
        else
          LayoutBuilder(
            builder: (context, c) {
              const gap = 10.0;
              int cols = 5;
              if (c.maxWidth < 500) {
                cols = 2;
              } else if (c.maxWidth < 760) {
                cols = 3;
              } else if (c.maxWidth < 1000) {
                cols = 4;
              }
              final w = (c.maxWidth - gap * (cols - 1)) / cols;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: _days
                    .map((d) => SizedBox(
                        width: w, child: _dayCard(d, taken)))
                    .toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _dayCard(Map<String, dynamic> d, Set<String> taken) {
    final date = (d['ad_date'] ?? '').toString();
    final isTaken = taken.contains(date);
    final open = d['is_open'] == true;
    final occasion = (d['occasion_name'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isTaken ? brandRed.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTaken
              ? brandRed.withValues(alpha: 0.4)
              : occasion.isNotEmpty
                  ? brandRed.withValues(alpha: 0.25)
                  : const Color(0xFFEDEFF3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  date.length >= 10 ? date.substring(5) : date,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
              ),
              InkWell(
                onTap: () => _editDay(d),
                borderRadius: BorderRadius.circular(7),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.edit_outlined,
                      size: 15, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),

          if (occasion.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(occasion,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: brandRed)),
          ],

          const SizedBox(height: 9),

          Row(
            children: [
              Text(
                '${(d['price'] as num?)?.toInt() ?? 0}',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
              Text(' ر.س',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 9.5,
                      color: Colors.grey.shade500)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isTaken
                      ? brandRed.withValues(alpha: 0.1)
                      : open
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  isTaken ? 'محجوز' : (open ? 'متاح' : 'مغلق'),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isTaken
                        ? brandRed
                        : open
                            ? Colors.green.shade700
                            : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== المراجعة =====

  Widget _reviewView() {
    final visible = _ads.where((a) => _groupOf(a) == _filter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: _filters.map((f) {
            final count = _ads.where((a) => _groupOf(a) == f.key).length;
            final on = _filter == f.key;

            return GestureDetector(
              onTap: () => setState(() => _filter = f.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: on ? brandRed.withValues(alpha: 0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                      color: on ? brandRed : const Color(0xFFEDEFF3)),
                ),
                child: Text(
                  '${f.label} ($count)',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: on ? FontWeight.bold : FontWeight.normal,
                    color: on ? brandRed : Colors.grey.shade700,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        if (visible.isEmpty)
          _emptyMsg(_filter == 'pending'
              ? 'لا إعلانات بانتظار المراجعة'
              : _filter == 'approved'
                  ? 'لا إعلانات معتمدة'
                  : 'لا إعلانات موقوفة')
        else
          ...visible.map(_adCard),
      ],
    );
  }

  Widget _adCard(Map<String, dynamic> a) {
    final group = _groupOf(a);
    final status = (a['status'] ?? '').toString();
    final reason = (a['rejection_reason'] ?? '').toString();
    final store = (a['merchants']?['store_name'] ?? 'متجر').toString();

    final (String label, Color color) = switch (status) {
      'paid' => ('مدفوع', Colors.blue),
      'scheduled' => ('مجدول', Colors.blue),
      'active' => ('يعرض اليوم', Colors.green),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((a['image_url'] ?? '').toString().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    a['image_url'],
                    width: 52,
                    height: 88,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 52,
                      height: 88,
                      color: const Color(0xFFF1F2F5),
                      child: const Icon(Icons.image_outlined,
                          size: 17, color: Colors.grey),
                    ),
                  ),
                ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(
                      'يوم ${a['ad_date']}',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          a['target_type'] == 'product'
                              ? Icons.inventory_2_outlined
                              : Icons.storefront_outlined,
                          size: 13,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          a['target_type'] == 'product'
                              ? 'يفتح منتجاً'
                              : 'يفتح المتجر',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 10.5,
                              color: Colors.grey.shade600),
                        ),
                      ],
                    ),
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
              Icon(Icons.visibility_outlined,
                  size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text('${a['impressions'] ?? 0}',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Colors.grey.shade600)),
              const SizedBox(width: 14),
              Icon(Icons.skip_next_outlined,
                  size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text('${a['skips'] ?? 0}',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Colors.grey.shade600)),
              const SizedBox(width: 14),
              Icon(Icons.touch_app_outlined,
                  size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text('${a['clicks'] ?? 0}',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Colors.grey.shade600)),
              const Spacer(),
              Text(
                '${(a['final_price'] as num?)?.toStringAsFixed(2)} ر.س',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: brandRed),
              ),
            ],
          ),

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

          if (group != 'suspended' &&
              ['paid', 'scheduled', 'active'].contains(status)) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (group == 'pending')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approve(a),
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
                  onPressed: () => _suspendDialog(a),
                  icon: const Icon(Icons.block_rounded, size: 16),
                  label: const Text('إيقاف',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side:
                        BorderSide(color: Colors.red.withValues(alpha: 0.4)),
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

  Widget _emptyMsg(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.smartphone_outlined,
                size: 52, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(msg,
                style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 14, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
