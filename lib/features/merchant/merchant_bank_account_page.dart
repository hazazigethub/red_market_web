import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ إضافة Riverpod
import 'package:go_router/go_router.dart'; // ✅ إضافة GoRouter
import 'package:red_market_core/red_market_core.dart';

// ملاحظة: الرصيد ثابت مؤقتاً حتى يُبنى نظام المحفظة
final merchantBalanceProvider = Provider<double>((ref) => 0.0);

class MerchantBankAccountPage extends ConsumerStatefulWidget {
  const MerchantBankAccountPage({super.key});

  @override
  ConsumerState<MerchantBankAccountPage> createState() =>
      _MerchantBankAccountPageState();
}

class _MerchantBankAccountPageState
    extends ConsumerState<MerchantBankAccountPage> {
  final _formKey = GlobalKey<FormState>();

  // وحدات التحكم في النصوص
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _ibanController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();

  String? _selectedBank;
  bool _isLinked = false;

  final List<String> _saudiBanks = [
    "مصرف الراجحي",
    "البنك الأهلي السعودي",
    "بنك الرياض",
    "بنك الإنماء",
    "بنك البلاد",
    "البنك العربي الوطني",
    "البنك السعودي للاستثمار"
  ];

  void _linkAccount() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLinked = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("تم ربط وتوثيق الحساب البنكي بنجاح ✅",
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Cairo')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF4CAF50)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    // ✅ جلب الرصيد الحقيقي للمتجر من المزود
    final double currentBalance = ref.watch(merchantBalanceProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          elevation: 0,
          title: Text("الإدارة المالية",
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF2D3436))),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : Colors.black, size: 20),
            onPressed: () => context.pop(), // ✅ استخدام GoRouter
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(
                height: 1, color: isDark ? Colors.white10 : Colors.black12),
          ),
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusCard(isDark, currentBalance),
              const SizedBox(height: 35),
              _buildBankForm(isDark),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // بطاقة عرض الرصيد وحالة الحساب المحسنة
  Widget _buildStatusCard(bool isDark, double balance) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isLinked
              ? [const Color(0xFF2E7D32), const Color(0xFF1B5E20)]
              : (isDark
                  ? [const Color(0xFF37474F), const Color(0xFF263238)]
                  : [const Color(0xFF455A64), const Color(0xFF263238)]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
              color: (_isLinked ? Colors.green : Colors.black)
                  .withOpacity(isDark ? 0.3 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("إجمالي الأرباح المتاحة",
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontFamily: 'Cairo')),
                  const SizedBox(height: 4),
                  PriceWidget(
                    price: balance,
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ],
              ),
              _buildStatusBadge(),
            ],
          ),
          const SizedBox(height: 35),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBalanceMiniInfo(
                    "الرصيد المعلق", "0.00 ر.س", Icons.timer_outlined),
                Container(width: 1, height: 30, color: Colors.white24),
                _buildBalanceMiniInfo("آخر تحويل",
                    _isLinked ? "30-12-2025" : "--", Icons.history_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
          color: _isLinked
              ? Colors.white.withOpacity(0.2)
              : Colors.amber.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color:
                  _isLinked ? Colors.white30 : Colors.amber.withOpacity(0.5))),
      child: Row(
        children: [
          Icon(_isLinked ? Icons.verified_rounded : Icons.warning_amber_rounded,
              color: _isLinked ? Colors.white : Colors.amber, size: 16),
          const SizedBox(width: 8),
          Text(_isLinked ? "حساب موثق" : "يتطلب ربط",
              style: TextStyle(
                  color: _isLinked ? Colors.white : Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildBalanceMiniInfo(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white60, size: 14),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    color: Colors.white60, fontSize: 10, fontFamily: 'Cairo')),
          ],
        ),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo')),
      ],
    );
  }

  // نموذج إدخال البيانات البنكية المطور
  Widget _buildBankForm(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security_rounded,
                  color: Color(0xFF4CAF50), size: 20),
              const SizedBox(width: 10),
              Text("بيانات التحويل البنكي",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF2D3436),
                      fontFamily: 'Cairo')),
            ],
          ),
          const SizedBox(height: 25),
          _buildLabel("البنك المحلي المعتمد", isDark),
          DropdownButtonFormField<String>(
            dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF4CAF50)),
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontFamily: 'Cairo',
                fontSize: 14),
            decoration: _inputDecoration("اختر البنك لاستقبال الأرباح",
                Icons.account_balance_rounded, isDark),
            items: _saudiBanks
                .map((bank) => DropdownMenuItem(value: bank, child: Text(bank)))
                .toList(),
            onChanged: (val) => setState(() => _selectedBank = val),
            validator: (val) => val == null ? "يرجى اختيار البنك" : null,
          ),
          const SizedBox(height: 20),
          _buildLabel("اسم صاحب الحساب (المستفيد)", isDark),
          TextFormField(
            controller: _ownerNameController,
            textAlign: TextAlign.right,
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w600),
            decoration: _inputDecoration("الاسم الكامل كما يظهر في بطاقة البنك",
                Icons.person_outline_rounded, isDark),
            validator: (val) => val!.isEmpty ? "يرجى إدخال اسم المستفيد" : null,
          ),
          const SizedBox(height: 20),
          _buildLabel("رقم الآيبان (IBAN)", isDark),
          TextFormField(
            controller: _ibanController,
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2),
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              LengthLimitingTextInputFormatter(24),
            ],
            decoration: _inputDecoration(
                    "SA00 0000 0000...", Icons.fingerprint_rounded, isDark)
                .copyWith(
              helperText: "تنسيق صحيح: يبدأ بـ SA متبوعاً بـ 22 رقماً",
              helperStyle: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Cairo',
                  color: isDark ? Colors.white38 : Colors.grey),
            ),
            validator: (val) {
              if (val!.isEmpty) return "يرجى إدخال الآيبان";
              if (!val.toUpperCase().startsWith("SA") || val.length != 24)
                return "تنسيق الآيبان غير صحيح (24 خانة)";
              return null;
            },
          ),
          const SizedBox(height: 35),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: _linkAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text("حفظ وتأكيد البيانات البنكية",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                          fontSize: 15)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Center(
            child: Text(
              "تتم معالجة كافة البيانات المالية عبر أنظمة مشفرة وآمنة",
              style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Cairo',
                  color: isDark ? Colors.white24 : Colors.grey),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) => Padding(
        padding: const EdgeInsets.only(bottom: 8, right: 5),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black54,
                fontFamily: 'Cairo')),
      );

  InputDecoration _inputDecoration(String hint, IconData icon, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          color: isDark ? Colors.white24 : Colors.grey,
          fontSize: 13,
          fontFamily: 'Cairo'),
      prefixIcon: Icon(icon, color: const Color(0xFF4CAF50), size: 22),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
      contentPadding: const EdgeInsets.all(18),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5)),
      errorStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
    );
  }
}
