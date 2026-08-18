import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

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
          title: Text("من نحن",
              style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF2D3436),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'Cairo')),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildLogoSection(isDark),
              const SizedBox(height: 40),
              _buildInfoCard(
                title: "رؤيتنا",
                content:
                    "نسعى لأن نكون المنصة الرائدة في تمكين التجار المحليين وتقديم تجربة تسوق رقمية فريدة تخدم المجتمع وتدعم الاقتصاد المحلي وفق رؤية 2030.",
                icon: Icons.visibility_rounded,
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              _buildInfoCard(
                title: "مهمتنا",
                content:
                    "توفير أدوات تقنية متطورة وسهلة الاستخدام للتجار لإدارة أعمالهم بفعالية، وربطهم بالعملاء بطريقة سريعة وآمنة.",
                icon: Icons.track_changes_rounded,
                isDark: isDark,
              ),
              const SizedBox(height: 40),
              _buildFooterInfo(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.info_outline_rounded,
                size: 50, color: Colors.white),
          ),
        ),
        const SizedBox(height: 15),
        Text(
          "تطبيق 2030",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
            color: isDark ? Colors.white : const Color(0xFF2D3436),
          ),
        ),
        Text(
          "المستقبل يبدأ من هنا",
          style: TextStyle(
            fontSize: 14,
            fontFamily: 'Cairo',
            color: isDark ? Colors.white38 : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    required IconData icon,
    required bool isDark,
  }) {
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
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF4CAF50), size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                  color: Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.8,
              fontFamily: 'Cairo',
              color: isDark ? Colors.white70 : const Color(0xFF2D3436),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterInfo(bool isDark) {
    return Column(
      children: [
        Divider(color: isDark ? Colors.white10 : Colors.black12),
        const SizedBox(height: 20),
        Text(
          "الإصدار 1.0.0",
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'Cairo',
            color: isDark ? Colors.white24 : Colors.grey,
          ),
        ),
      ],
    );
  }
}
