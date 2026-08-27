import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantCheckoutPage extends StatefulWidget {
  final Map<String, dynamic> plan;
  const MerchantCheckoutPage({super.key, required this.plan});

  @override
  State<MerchantCheckoutPage> createState() => _MerchantCheckoutPageState();
}

class _MerchantCheckoutPageState extends State<MerchantCheckoutPage> {
  static const Color brandRed = Color(0xFFC21815);

  final supabase = Supabase.instance.client;
  final _codeCtrl = TextEditingController();

  bool _checking = false;
  double _discountPercent = 0;
  String? _appliedCode;
  String? _codeError;

  double get _basePrice =>
      (widget.plan['price'] as num?)?.toDouble() ?? 0;

  double get _discountValue => _basePrice * (_discountPercent / 100);

  double get _finalPrice => _basePrice - _discountValue;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty || _checking) return;

    setState(() {
      _checking = true;
      _codeError = null;
    });

    try {
      final res = await supabase.rpc('check_promo_code', params: {
        'input_code': code,
        'input_plan_id': widget.plan['id'],
      });

      final map = Map<String, dynamic>.from(res as Map);

      if (map['valid'] == true) {
        setState(() {
          _discountPercent = (map['percent'] as num).toDouble();
          _appliedCode = code.toUpperCase();
          _codeError = null;
        });
      } else {
        setState(() {
          _discountPercent = 0;
          _appliedCode = null;
          _codeError = map['error']?.toString() ?? 'الكود غير صالح';
        });
      }
    } catch (e) {
      setState(() {
        _discountPercent = 0;
        _appliedCode = null;
        _codeError = 'تعذر التحقق من الكود';
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _removeCode() {
    setState(() {
      _codeCtrl.clear();
      _discountPercent = 0;
      _appliedCode = null;
      _codeError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = (widget.plan['duration_days'] as num?)?.toInt() ?? 30;
    final name = (widget.plan['name'] ?? 'باقة').toString();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ===== الترويسة =====
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              size: 18),
                        ),
                        const SizedBox(width: 4),
                        const Text('إتمام الاشتراك',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 19,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ===== ملخّص الباقة =====
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEDEFF3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: brandRed.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                    Icons.card_membership_rounded,
                                    color: brandRed,
                                    size: 19),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                      days >= 365
                                          ? 'اشتراك سنوي'
                                          : 'اشتراك شهري',
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 12,
                                          color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                          const Divider(color: Color(0xFFEDEFF3)),
                          const SizedBox(height: 14),

                          _row('سعر الباقة', _basePrice),
                          if (_discountPercent > 0) ...[
                            const SizedBox(height: 10),
                            _row(
                              'الخصم (${_discountPercent.toStringAsFixed(0)}%)',
                              -_discountValue,
                              color: Colors.green,
                            ),
                          ],

                          const SizedBox(height: 14),
                          const Divider(color: Color(0xFFEDEFF3)),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              const Text('الإجمالي',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Text(
                                '${_finalPrice.toStringAsFixed(2)} ر.س',
                                style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: brandRed),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ===== كود الخصم =====
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEDEFF3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('كود الخصم',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),

                          if (_appliedCode != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.green
                                        .withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      color: Colors.green, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'تم تطبيق $_appliedCode',
                                      style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _removeCode,
                                    child: Text('إزالة',
                                        style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 12,
                                            color: Colors.grey.shade600)),
                                  ),
                                ],
                              ),
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _codeCtrl,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    style: const TextStyle(
                                        fontFamily: 'Cairo', fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: 'أدخل الكود',
                                      hintStyle: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 12,
                                          color: Colors.grey.shade400),
                                      filled: true,
                                      fillColor: const Color(0xFFF7F8FA),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide.none),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 12),
                                      errorText: _codeError,
                                      errorStyle: const TextStyle(
                                          fontFamily: 'Cairo', fontSize: 11),
                                    ),
                                    onSubmitted: (_) => _applyCode(),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: _checking ? null : _applyCode,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: brandRed,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 22, vertical: 15),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: Text(
                                      _checking ? '...' : 'تطبيق',
                                      style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ===== الدفع =====
                    ElevatedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.lock_outline_rounded, size: 18),
                      label: const Text('إتمام الدفع',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandRed,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'بوابة الدفع قيد الربط — تواصل مع الإدارة لتفعيل اشتراكك',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            color: Colors.grey.shade500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, double value, {Color? color}) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: color ?? Colors.grey.shade700)),
        const Spacer(),
        Text(
          '${value.toStringAsFixed(2)} ر.س',
          style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87),
        ),
      ],
    );
  }
}
