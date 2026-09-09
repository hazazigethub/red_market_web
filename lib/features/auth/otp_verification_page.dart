import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// صفحة تحقق برمز مرسل عبر SMS — 4 خانات وعدّاد وإعادة إرسال.
/// ⚠️ التحقق شكلي حالياً، جاهز للربط بمزوّد الرسائل لاحقاً.
class OtpVerificationPage extends StatefulWidget {
  final String title;
  final String subtitle;
  final String phoneNumber;
  final VoidCallback onVerified;

  const OtpVerificationPage({
    super.key,
    this.title = 'رمز التحقق',
    required this.subtitle,
    required this.phoneNumber,
    required this.onVerified,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  static const Color brandRed = Color(0xFFD32027);

  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(4, (_) => FocusNode());

  Timer? _timer;
  int _remaining = 120;
  bool _canResend = false;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _remaining = 120;
      _canResend = false;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_remaining <= 1) {
        t.cancel();
        setState(() {
          _remaining = 0;
          _canResend = true;
        });
      } else {
        setState(() => _remaining--);
      }
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  String get _timeLabel {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _onChanged(int index, String value) {
    if (value.isNotEmpty && index < 3) {
      _nodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  Future<void> _verify() async {
    if (_code.length < 4 || _verifying) return;

    setState(() => _verifying = true);

    // ⚠️ محاكاة تحقق — يُستبدل باستدعاء مزوّد الرسائل
    await Future<void>.delayed(const Duration(milliseconds: 650));

    if (!mounted) return;
    setState(() => _verifying = false);

    Navigator.pop(context);
    widget.onVerified();
  }

  void _resend() {
    if (!_canResend) return;
    for (final c in _controllers) {
      c.clear();
    }
    _nodes.first.requestFocus();
    _startCountdown();

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('أُرسل رمز جديد إلى جوالك',
          style: TextStyle(fontFamily: 'Cairo')),
      backgroundColor: brandRed,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: brandRed.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sms_outlined,
                      color: brandRed, size: 26),
                ),
                const SizedBox(height: 16),

                Text(widget.title,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      height: 1.8,
                      color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),

                Text(
                  widget.phoneNumber,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: brandRed),
                ),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) => _box(i)),
                ),

                const SizedBox(height: 20),

                if (!_canResend)
                  Text(
                    'يمكنك طلب رمز جديد بعد $_timeLabel',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Colors.grey.shade500),
                  )
                else
                  GestureDetector(
                    onTap: _resend,
                    child: const Text(
                      'إعادة إرسال الرمز',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: brandRed),
                    ),
                  ),

                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        (_code.length < 4 || _verifying) ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandRed,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_verifying ? 'جاري التحقق...' : 'تأكيد',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 6),

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء',
                      style:
                          TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _box(int index) {
    final filled = _controllers[index].text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        width: 56,
        height: 62,
        child: TextField(
          controller: _controllers[index],
          focusNode: _nodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 22,
              fontWeight: FontWeight.bold),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: filled
                ? brandRed.withValues(alpha: 0.05)
                : const Color(0xFFF7F8FA),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: filled ? brandRed : const Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: brandRed, width: 1.6),
            ),
          ),
          onChanged: (v) => _onChanged(index, v),
        ),
      ),
    );
  }
}
