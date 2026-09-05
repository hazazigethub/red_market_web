import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'banner_terms_sheet.dart';

/// شاشة إعلانات التاجر — حجز البنرات الأسبوعية
class MerchantAdsPage extends StatefulWidget {
  const MerchantAdsPage({super.key});

  @override
  State<MerchantAdsPage> createState() => _MerchantAdsPageState();
}

class _MerchantAdsPageState extends State<MerchantAdsPage> {
  static const Color brandRed = Color(0xFFC21815);

  // مقاسات ملزمة
  static const Map<String, ({int w, int h})> _sizes = {
    'wide': (w: 1500, h: 350),
    'small': (w: 760, h: 400),
  };
  static const int _maxKb = 500;

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _weeks = [];
  List<Map<String, dynamic>> _myBookings = [];
  bool _loading = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final weeks = await supabase.rpc('get_available_weeks');

      final uid = supabase.auth.currentUser?.id;
      List bookings = [];
      if (uid != null) {
        bookings = await supabase
            .from('banner_bookings')
            .select('*, banner_weeks(week_number, year, week_start, week_end)')
            .eq('merchant_id', uid)
            .order('created_at', ascending: false);
      }

      if (mounted) {
        setState(() {
          _weeks = List<Map<String, dynamic>>.from(weeks as List);
          _myBookings = List<Map<String, dynamic>>.from(bookings);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Ads load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  String _fmt(dynamic raw) {
    final d = DateTime.tryParse((raw ?? '').toString());
    if (d == null) return '—';
    return '${d.day}/${d.month}';
  }

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
                  const Text('إعلاناتي',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 19,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    'احجز مساحة إعلانية أسبوعية تظهر لزوار المنصة',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.5,
                        color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 18),

                  // ===== التبويبات =====
                  Wrap(
                    spacing: 8,
                    children: [
                      _tabChip(0, 'الأسابيع المتاحة', _weeks.length),
                      _tabChip(1, 'حجوزاتي', _myBookings.length),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                          child: CircularProgressIndicator(color: brandRed)),
                    )
                  else if (_tab == 0)
                    _weeksGrid()
                  else
                    _bookingsList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabChip(int index, String label, int count) {
    final on = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: on ? brandRed : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? brandRed : const Color(0xFFEDEFF3)),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12.5,
            fontWeight: on ? FontWeight.bold : FontWeight.normal,
            color: on ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  // ===================== الأسابيع =====================

  Widget _weeksGrid() {
    if (_weeks.isEmpty) {
      return _empty('لا توجد أسابيع متاحة للحجز حالياً',
          Icons.calendar_month_outlined);
    }

    return LayoutBuilder(
      builder: (context, c) {
        const gap = 14.0;
        int cols = 3;
        if (c.maxWidth < 560) {
          cols = 1;
        } else if (c.maxWidth < 900) {
          cols = 2;
        }
        final w = (c.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: _weeks
              .map((week) => SizedBox(width: w, child: _weekCard(week)))
              .toList(),
        );
      },
    );
  }

  Widget _weekCard(Map<String, dynamic> w) {
    final occasion = (w['occasion_name'] ?? '').toString();
    final wideLeft = (w['wide_available'] as num?)?.toInt() ?? 0;
    final smallLeft = (w['small_available'] as num?)?.toInt() ?? 0;
    final soldOut = wideLeft <= 0 && smallLeft <= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: occasion.isNotEmpty
              ? brandRed.withValues(alpha: 0.35)
              : const Color(0xFFEDEFF3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${_fmt(w['week_start'])} — ${_fmt(w['week_end'])}',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text('أسبوع ${w['week_number']}',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10.5,
                      color: Colors.grey.shade500)),
            ],
          ),

          const SizedBox(height: 5),

          if (occasion.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.local_fire_department_rounded,
                    size: 14, color: brandRed),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(occasion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: brandRed)),
                ),
              ],
            )
          else
            Text('أسبوع عادي',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    color: Colors.grey.shade400)),

          const SizedBox(height: 14),
          const Divider(color: Color(0xFFEDEFF3), height: 1),
          const SizedBox(height: 12),

          _typeRow(w, 'wide', 'بنر عريض', w['price_wide'], wideLeft),
          const SizedBox(height: 9),
          _typeRow(w, 'small', 'بنر صغير', w['price_small'], smallLeft),

          if (soldOut) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('اكتمل الحجز',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _typeRow(Map<String, dynamic> w, String type, String label,
      dynamic price, int left) {
    final gone = left <= 0;
    final scarce = left > 0 && left <= 3;

    return InkWell(
      onTap: gone ? null : () => _openBooking(w, type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: gone ? const Color(0xFFFAFAFA) : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              type == 'wide'
                  ? Icons.crop_16_9_rounded
                  : Icons.crop_square_rounded,
              size: 17,
              color: gone ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    color: gone ? Colors.grey : const Color(0xFF1F2937))),
            const Spacer(),
            Text(
              '${(price as num?)?.toInt() ?? 0} ر.س',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: gone ? Colors.grey : brandRed),
            ),
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: gone
                    ? Colors.grey.withValues(alpha: 0.1)
                    : scarce
                        ? Colors.orange.withValues(alpha: 0.13)
                        : Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                gone ? 'مكتمل' : 'باقٍ $left',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: gone
                      ? Colors.grey
                      : scarce
                          ? Colors.orange.shade800
                          : Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== نافذة الحجز =====================

  void _openBooking(Map<String, dynamic> week, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingSheet(
        week: week,
        bannerType: type,
        onDone: _load,
      ),
    );
  }

  // ===================== حجوزاتي =====================

  Widget _bookingsList() {
    if (_myBookings.isEmpty) {
      return _empty('لم تحجز أي إعلان بعد', Icons.ad_units_outlined);
    }

    return Column(
      children: _myBookings.map(_bookingCard).toList(),
    );
  }

  Widget _bookingCard(Map<String, dynamic> b) {
    final week = b['banner_weeks'] as Map<String, dynamic>?;
    final status = (b['status'] ?? '').toString();

    final (String label, Color color) = switch (status) {
      'pending' => ('بانتظار الدفع', Colors.orange),
      'released' => ('انتهت المهلة', Colors.grey),
      'paid' => ('مدفوع', Colors.blue),
      'scheduled' => ('مجدول', Colors.blue),
      'active' => ('يعرض الآن', Colors.green),
      'suspended' => ('موقوف', Colors.red),
      'expired' => ('انتهى', Colors.grey),
      _ => (status, Colors.grey),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
              if ((b['image_url'] ?? '').toString().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    b['image_url'],
                    width: 74,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 74,
                      height: 40,
                      color: const Color(0xFFF1F2F5),
                      child: const Icon(Icons.image_outlined,
                          size: 17, color: Colors.grey),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b['banner_type'] == 'wide' ? 'بنر عريض' : 'بنر صغير',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold),
                    ),
                    if (week != null)
                      Text(
                        '${_fmt(week['week_start'])} — ${_fmt(week['week_end'])}',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            color: Colors.grey.shade600),
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
              Text('${b['slots_count']} بنر',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.5,
                      color: Colors.grey.shade600)),
              const Spacer(),
              Text(
                '${(b['final_price'] as num?)?.toStringAsFixed(2) ?? '0'} ر.س',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: brandRed),
              ),
            ],
          ),

          if (status == 'active' || status == 'expired') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.visibility_outlined,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text('${b['impressions'] ?? 0} ظهور',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: Colors.grey.shade600)),
                const SizedBox(width: 16),
                Icon(Icons.touch_app_outlined,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text('${b['clicks'] ?? 0} نقرة',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: Colors.grey.shade600)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _empty(String msg, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(icon, size: 58, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          Text(msg,
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 15, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ============================================================
//                      نافذة الحجز
// ============================================================

class _BookingSheet extends StatefulWidget {
  final Map<String, dynamic> week;
  final String bannerType;
  final VoidCallback onDone;

  const _BookingSheet({
    required this.week,
    required this.bannerType,
    required this.onDone,
  });

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  static const Color brandRed = Color(0xFFC21815);
  static const int _maxKb = 500;

  final supabase = Supabase.instance.client;
  final _promoCtrl = TextEditingController();

  int _slots = 1;
  String _targetType = 'store';
  String? _productId;
  Uint8List? _imageBytes;
  String? _imageName;
  String? _uploadedUrl;
  bool _termsAccepted = false;
  bool _busy = false;
  String? _error;

  List<Map<String, dynamic>> _products = [];

  ({int w, int h}) get _size => widget.bannerType == 'wide'
      ? (w: 1500, h: 350)
      : (w: 760, h: 400);

  int get _unitPrice => widget.bannerType == 'wide'
      ? (widget.week['price_wide'] as num?)?.toInt() ?? 0
      : (widget.week['price_small'] as num?)?.toInt() ?? 0;

  int get _available => widget.bannerType == 'wide'
      ? (widget.week['wide_available'] as num?)?.toInt() ?? 0
      : (widget.week['small_available'] as num?)?.toInt() ?? 0;

  int get _maxSlots {
    final cap = (widget.week['max_slots'] as num?)?.toInt() ?? 4;
    return cap < _available ? cap : _available;
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _promoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;
      final res = await supabase
          .from('products')
          .select('id, name')
          .eq('merchant_id', uid)
          .eq('is_available', true)
          .order('created_at', ascending: false)
          .limit(100);
      if (mounted) {
        setState(() => _products = List<Map<String, dynamic>>.from(res));
      }
    } catch (e) {
      debugPrint('Products load error: $e');
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// اختيار الصورة مع فحص فوري
  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 100);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      // الحجم
      final kb = bytes.lengthInBytes / 1024;
      if (kb > _maxKb) {
        setState(() => _error =
            'حجم الملف ${kb.toStringAsFixed(0)} كيلوبايت — '
            'والحد الأقصى $_maxKb\n'
            'جرّب حفظ الصورة بصيغة JPG لتقليل حجمها');
        return;
      }

      // المقاس
      final decoded = await decodeImageFromList(bytes);
      if (decoded.width != _size.w || decoded.height != _size.h) {
        setState(() => _error =
            'المقاس غير مطابق\nالصورة: ${decoded.width} × ${decoded.height}\n'
            'المطلوب: ${_size.w} × ${_size.h}');
        return;
      }

      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
        _uploadedUrl = null;
        _error = null;
      });
    } catch (e) {
      debugPrint('Pick error: $e');
      setState(() => _error = 'تعذر قراءة الصورة');
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageBytes == null) return null;
    if (_uploadedUrl != null) return _uploadedUrl;

    try {
      final uid = supabase.auth.currentUser!.id;
      final ext = (_imageName ?? 'banner.png').split('.').last;
      final path =
          'bookings/$uid-${DateTime.now().millisecondsSinceEpoch}.$ext';

      await supabase.storage.from('banners_bucket').uploadBinary(
            path,
            _imageBytes!,
            fileOptions: const FileOptions(upsert: true),
          );

      _uploadedUrl =
          supabase.storage.from('banners_bucket').getPublicUrl(path);
      return _uploadedUrl;
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  Future<void> _submit() async {
    if (_busy) return;

    if (_imageBytes == null) {
      setState(() => _error = 'ارفع صورة البنر أولاً');
      return;
    }
    if (_targetType == 'product' && _productId == null) {
      setState(() => _error = 'اختر المنتج المستهدف');
      return;
    }
    if (!_termsAccepted) {
      setState(() => _error = 'يجب الموافقة على شروط الإعلان');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final url = await _uploadImage();
      if (url == null) {
        setState(() {
          _error = 'تعذر رفع الصورة';
          _busy = false;
        });
        return;
      }

      final res = await supabase.rpc('book_banner', params: {
        'p_week_id': widget.week['id'],
        'p_banner_type': widget.bannerType,
        'p_slots': _slots,
        'p_image_url': url,
        'p_target_type': _targetType,
        'p_product_id': _productId,
        'p_promo_code':
            _promoCtrl.text.trim().isEmpty ? null : _promoCtrl.text.trim(),
        'p_terms_version': 'v1.0',
      });

      final map = Map<String, dynamic>.from(res as Map);

      if (map['ok'] == true) {
        if (!mounted) return;
        Navigator.pop(context);
        widget.onDone();
        _snack(
          'حُجز مؤقتاً — أكمل الدفع خلال ${map['locked_minutes']} دقائق',
          Colors.orange,
        );
      } else {
        setState(() {
          _error = map['error']?.toString() ?? 'تعذر الحجز';
          _busy = false;
        });
      }
    } catch (e) {
      debugPrint('Book error: $e');
      setState(() {
        _error = 'تعذر إتمام الحجز، حاول مجدداً';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = _unitPrice * _slots;
    final vat = subtotal * 0.15;
    final total = subtotal + vat;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ===== المقبض =====
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.bannerType == 'wide'
                              ? 'حجز بنر عريض'
                              : 'حجز بنر صغير',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 17,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'المقاس ${_size.w} × ${_size.h} بكسل · '
                          'الحد الأقصى $_maxKb كيلوبايت · JPG أو WebP',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11.5,
                              color: Colors.grey.shade600),
                        ),

                        const SizedBox(height: 20),

                        // ===== الصورة =====
                        _sectionTitle('صورة البنر', Icons.image_outlined),
                        const SizedBox(height: 10),

                        if (_imageBytes != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.memory(
                              _imageBytes!,
                              width: double.infinity,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        InkWell(
                          onTap: _busy ? null : _pickImage,
                          borderRadius: BorderRadius.circular(11),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: _imageBytes != null
                                  ? Colors.green.withValues(alpha: 0.05)
                                  : const Color(0xFFF7F8FA),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: _imageBytes != null
                                    ? Colors.green.withValues(alpha: 0.35)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _imageBytes != null
                                      ? Icons.check_circle_rounded
                                      : Icons.upload_file_rounded,
                                  size: 19,
                                  color: _imageBytes != null
                                      ? Colors.green
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _imageBytes != null
                                        ? 'الصورة مطابقة للمواصفات'
                                        : 'اختر صورة البنر',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12.5,
                                      fontWeight: _imageBytes != null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: _imageBytes != null
                                          ? Colors.green.shade800
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                if (_imageBytes != null)
                                  Text('تغيير',
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 11.5,
                                          color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ===== الوجهة =====
                        _sectionTitle('وجهة البنر', Icons.link_rounded),
                        const SizedBox(height: 6),

                        RadioListTile<String>(
                          value: 'store',
                          groupValue: _targetType,
                          activeColor: brandRed,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('صفحة متجري',
                              style: TextStyle(
                                  fontFamily: 'Cairo', fontSize: 13)),
                          onChanged: (v) => setState(() {
                            _targetType = 'store';
                            _productId = null;
                          }),
                        ),
                        RadioListTile<String>(
                          value: 'product',
                          groupValue: _targetType,
                          activeColor: brandRed,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('منتج محدد',
                              style: TextStyle(
                                  fontFamily: 'Cairo', fontSize: 13)),
                          onChanged: (v) =>
                              setState(() => _targetType = 'product'),
                        ),

                        if (_targetType == 'product') ...[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _productId,
                            isExpanded: true,
                            decoration: _dec('اختر المنتج'),
                            items: _products
                                .map((p) => DropdownMenuItem<String>(
                                      value: p['id'].toString(),
                                      child: Text(
                                        (p['name'] ?? '').toString(),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 13),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _productId = v),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // ===== البنرات =====
                        _sectionTitle('عدد البنرات', Icons.layers_outlined),
                        const SizedBox(height: 4),
                        Text(
                          'كل بنر يمنحك نصيباً إضافياً من الظهور أمام العملاء · '
                          'المتاح $_available',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: List.generate(_maxSlots, (i) {
                            final n = i + 1;
                            final on = _slots == n;
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _slots = n),
                                child: Container(
                                  width: 46,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color:
                                        on ? brandRed : const Color(0xFFF7F8FA),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: on
                                            ? brandRed
                                            : Colors.grey.shade300),
                                  ),
                                  child: Center(
                                    child: Text('$n',
                                        style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: on
                                                ? Colors.white
                                                : Colors.grey.shade700)),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 20),

                        // ===== كود الخصم =====
                        _sectionTitle('كود الخصم', Icons.local_offer_outlined),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _promoCtrl,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(
                              fontFamily: 'Cairo', fontSize: 13),
                          decoration: _dec('اختياري'),
                        ),

                        const SizedBox(height: 20),

                        // ===== الملخّص =====
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F8FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _priceLine('سعر البنر', '$_unitPrice ر.س'),
                              const SizedBox(height: 8),
                              _priceLine('عدد البنرات', '$_slots'),
                              const SizedBox(height: 8),
                              _priceLine(
                                  'المجموع', '$subtotal ر.س'),
                              const SizedBox(height: 8),
                              _priceLine('ضريبة القيمة المضافة 15%',
                                  '${vat.toStringAsFixed(2)} ر.س'),
                              const Padding(
                                padding:
                                    EdgeInsets.symmetric(vertical: 10),
                                child: Divider(
                                    color: Color(0xFFE5E7EB), height: 1),
                              ),
                              Row(
                                children: [
                                  const Text('الإجمالي',
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  Text(
                                    '${total.toStringAsFixed(2)} ر.س',
                                    style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: brandRed),
                                  ),
                                ],
                              ),
                              Text(
                                'الخصم يُحتسب عند تأكيد الحجز',
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 10,
                                    color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ===== الموافقة =====
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _termsAccepted,
                              activeColor: brandRed,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onChanged: (v) =>
                                  setState(() => _termsAccepted = v ?? false),
                            ),
                            const SizedBox(width: 4),
                            const Text('أوافق على ',
                                style: TextStyle(
                                    fontFamily: 'Cairo', fontSize: 12.5)),
                            InkWell(
                              onTap: () async {
                                final agreed =
                                    await showBannerTermsSheet(context);
                                if (agreed == true) {
                                  setState(() => _termsAccepted = true);
                                }
                              },
                              child: const Text(
                                'شروط الإعلان',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: brandRed,
                                  decoration: TextDecoration.underline,
                                  decorationColor: brandRed,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: Colors.red, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                        color: Colors.red,
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                        height: 1.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 18),

                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed:
                                (_busy || !_termsAccepted) ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandRed,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Text('تأكيد الحجز',
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'يُحجز الموضع مؤقتاً 5 دقائق لإتمام الدفع',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 10.5,
                              color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 17, color: brandRed),
        const SizedBox(width: 9),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13.5,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _priceLine(String label, String value) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.grey.shade600)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  InputDecoration _dec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade400),
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
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    );
  }
}
