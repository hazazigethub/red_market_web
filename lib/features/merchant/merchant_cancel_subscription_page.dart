import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantCancelSubscriptionPage extends StatefulWidget {
  const MerchantCancelSubscriptionPage({super.key});

  @override
  State<MerchantCancelSubscriptionPage> createState() =>
      _MerchantCancelSubscriptionPageState();
}

class _MerchantCancelSubscriptionPageState
    extends State<MerchantCancelSubscriptionPage> {
  static const Color brandRed = Color(0xFFC21815);

  final supabase = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final row = await supabase
          .from('merchant_subscriptions')
          .select()
          .eq('merchant_id', uid)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _sub = row == null ? null : Map<String, dynamic>.from(row);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Cancel page load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(dynamic raw) {
    if (raw == null) return '—';
    final d = DateTime.tryParse(raw.toString());
    if (d == null) return '—';
    return "${d.year}/${d.month}/${d.day}";
  }

  void _confirm() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('تأكيد الإلغاء',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              'سيبقى اشتراكك فعّالاً حتى ${_fmt(_sub?['expires_at'])}، '
              'ثم تختفي منتجاتك عن العملاء ولن يُجدَّد تلقائياً.',
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 13.5, height: 1.9),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('تراجع',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _cancel();
              },
              child: const Text('تأكيد الإلغاء',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancel() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final res = await supabase.rpc('cancel_subscription');
      final map = Map<String, dynamic>.from(res as Map);

      if (map['ok'] == true) {
        await _load();
        _snack('تم إلغاء التجديد — اشتراكك فعّال حتى نهاية المدة',
            Colors.orange);
      } else {
        _snack(map['error']?.toString() ?? 'تعذر الإلغاء', Colors.red);
      }
    } catch (e) {
      _snack('تعذر الإلغاء، حاول مجدداً', Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: color,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 50),
        child: Center(child: CircularProgressIndicator(color: brandRed)),
      );
    }

    if (_sub == null) return _empty();

    final cancelled = _sub?['cancelled_at'] != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: cancelled
                    ? Colors.orange.withValues(alpha: 0.4)
                    : const Color(0xFFEDEFF3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: (cancelled ? Colors.orange : brandRed)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                        cancelled
                            ? Icons.event_busy_rounded
                            : Icons.cancel_outlined,
                        color: cancelled ? Colors.orange : brandRed,
                        size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cancelled ? 'الاشتراك ملغى' : 'اشتراكك نشط',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          (_sub?['plan_name'] ?? 'باقة').toString(),
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

              const SizedBox(height: 18),
              const Divider(color: Color(0xFFEDEFF3), height: 1),
              const SizedBox(height: 14),

              Row(
                children: [
                  Text(cancelled ? 'فعّال حتى' : 'ينتهي في',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          color: Colors.grey.shade600)),
                  const Spacer(),
                  Text(_fmt(_sub?['expires_at']),
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

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
              const Text('ما الذي سيحدث عند الإلغاء',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...const [
                'يبقى اشتراكك فعّالاً حتى نهاية المدة المدفوعة',
                'تختفي منتجاتك ومقاطعك عن العملاء بعدها',
                'تبقى بياناتك محفوظة ويمكنك الاشتراك مجدداً',
                'لا استرداد للمبلغ المدفوع عن المدة المتبقية',
              ].map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.remove_circle_outline_rounded,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(p,
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12.5,
                                  height: 1.8)),
                        ),
                      ],
                    ),
                  )),

              const SizedBox(height: 8),

              if (cancelled)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: Colors.orange, size: 17),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'ألغيت التجديد. لإعادته، فعّل التجديد التلقائي.',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              height: 1.7,
                              color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _confirm,
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: Text(
                        _saving ? 'جاري الإلغاء...' : 'إلغاء الاشتراك',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.cancel_outlined, size: 54, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          const Text('لا يوجد اشتراك نشط',
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }
}
