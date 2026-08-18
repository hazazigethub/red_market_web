import 'package:flutter/material.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ اكتشاف وضع الثيم الحالي (داكن أم فاتح)
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Map<String, String>> faqs = [
      {
        'q': 'كيف يمكنني إضافة منتج جديد؟',
        'a':
            'من خلال لوحة التحكم، انتقل إلى قسم المنتجات واضغط على زر إضافة منتج، ثم قم بتعبئة بيانات المنتج وصوره.'
      },
      {
        'q': 'هل يمكنني تغيير معلومات المتجر؟',
        'a':
            'نعم، يمكنك تعديل اسم المتجر، الشعار، وصورة الغلاف من خلال صفحة إعدادات المتجر في القائمة الجانبية.'
      },
      {
        'q': 'كيف يتم سحب الأرباح؟',
        'a':
            'يتم تحويل الأرباح دورياً إلى حسابك البنكي المسجل في النظام بعد مراجعة الطلبات المكتملة وتجاوز فترة الأمان.'
      },
      {
        'q': 'كيف يمكنني إطلاق حملة ترويجية؟',
        'a':
            'انتقل إلى صفحة "إرسال ترويج"، حدد الجمهور المستهدف وميزانية الحملة ثم قم بتأكيد الإرسال.'
      },
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        // ✅ تحديث خلفية الصفحة ديناميكياً
        backgroundColor:
            isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text("الأسئلة الشائعة",
              style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF2D3436),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                  fontSize: 18)),
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
        body: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          physics: const BouncingScrollPhysics(),
          itemCount: faqs.length,
          itemBuilder: (context, index) {
            return _buildFaqItem(
                faqs[index]['q']!, faqs[index]['a']!, isDark, context);
          },
        ),
      ),
    );
  }

  Widget _buildFaqItem(
      String question, String answer, bool isDark, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
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
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          iconColor: const Color(0xFF4CAF50),
          collapsedIconColor: isDark ? Colors.white38 : Colors.grey[400],
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          title: Text(
            question,
            style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF2D3436),
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                fontSize: 14),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  answer,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 13,
                      height: 1.6),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
