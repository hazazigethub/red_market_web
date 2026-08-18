import 'package:flutter/material.dart';

class AcceptableUsePage extends StatelessWidget {
  const AcceptableUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ اكتشاف وضع الثيم الحالي (داكن أم فاتح)
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        // ✅ تحديث خلفية الصفحة ديناميكياً
        backgroundColor:
            isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(
            "الاستخدام المقبول",
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF2D3436),
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          // ✅ تحديث خلفية الـ AppBar
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : Colors.black, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(
                height: 1, color: isDark ? Colors.white10 : Colors.black12),
          ),
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIntroSection(isDark),
              const SizedBox(height: 25),
              _buildGuidelinesCard(isDark),
              const SizedBox(height: 30),
              _buildWarningBox(isDark),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.verified_user_outlined,
              color: Color(0xFF4CAF50), size: 40),
          const SizedBox(height: 12),
          Text(
            "تلتزم منصتنا بتوفير بيئة آمنة وموثوقة لكافة التجار والعملاء. تهدف هذه السياسة لضمان استمرارية الخدمة بأعلى معايير الجودة.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              fontFamily: 'Cairo',
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelinesCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "ضوابط الاستخدام للمتاجر",
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(height: 20),
          _buildGuidelineRow(
              Icons.check_circle_outline,
              "دقة المعلومات",
              "يجب تزويد التطبيق بمعلومات صحيحة ومحدثة عن المتجر والمنتجات.",
              isDark),
          _buildGuidelineRow(
              Icons.check_circle_outline,
              "جودة المحتوى",
              "يمنع استخدام صور مضللة أو نصوص تسيء للمنافسين أو العملاء.",
              isDark),
          _buildGuidelineRow(
              Icons.check_circle_outline,
              "النشاط القانوني",
              "يقتصر استخدام المتجر على الأنشطة التجارية المشروعة والمسجلة.",
              isDark),
          _buildGuidelineRow(
              Icons.check_circle_outline,
              "أمن البيانات",
              "يمنع محاولة الوصول غير المصرح به لأي جزء من أنظمة المنصة.",
              isDark),
        ],
      ),
    );
  }

  Widget _buildGuidelineRow(
      IconData icon, String title, String desc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF4CAF50), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87)),
                Text(desc,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.grey[600],
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBox(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.redAccent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "مخالفة سياسة الاستخدام قد تؤدي إلى تعليق حساب المتجر بشكل مؤقت أو دائم.",
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? Colors.redAccent.withOpacity(0.8)
                    : Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
