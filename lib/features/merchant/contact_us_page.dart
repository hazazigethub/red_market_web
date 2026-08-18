import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ إضافة سوبابيس
import 'package:url_launcher/url_launcher.dart';

class ContactUsPage extends StatefulWidget {
  // ✅ تغيير لـ StatefulWidget
  const ContactUsPage({super.key});

  @override
  State<ContactUsPage> createState() => _ContactUsPageState();
}

class _ContactUsPageState extends State<ContactUsPage> {
  // ✅ تعريف الـ Controllers والـ Supabase
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final supabase = Supabase.instance.client;
  bool _isSending = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _openWhatsApp() async {
    final Uri url = Uri.parse('https://wa.me/message/4ZYS4PCSKP5BA1');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // ✅ دالة إرسال الرسالة لقاعدة البيانات (بصفتك تاجر)
  Future<void> _sendMerchantMessage() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();

    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("يرجى كتابة الموضوع وتفاصيل الرسالة",
              style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw "يجب تسجيل الدخول أولاً";

      await supabase.from('reports').insert({
        'reporter_id': user.id,
        'target_type': 'merchant_support', // لكي تظهر في قسم "دعم المتاجر"
        'reason': message, // تخزين النص في عمود reason
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم إرسال طلب الدعم بنجاح، سيتم الرد عليك قريباً ✅",
                style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _subjectController.clear();
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text("خطأ: $e", style: const TextStyle(fontFamily: 'Cairo')),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text("تواصل معنا (دعم المتاجر)",
              style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF2D3436),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                  fontSize: 18)),
          centerTitle: true,
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
              _buildSectionTitle("قنوات التواصل المباشر", isDark),
              const SizedBox(height: 15),

              GestureDetector(
                onTap: _openWhatsApp,
                child: _buildContactCard(
                    Icons.chat_rounded,
                    "واتساب",
                    "تواصل معنا مباشرة عبر واتساب",
                    isDark,
                    const Color(0xFF25D366)),
              ),
              _buildContactCard(
                  Icons.alternate_email_rounded,
                  "البريد الإلكتروني",
                  "support@RedOcean.com",
                  isDark,
                  Colors.orange),
              const SizedBox(height: 35),
              _buildSectionTitle("أرسل لنا رسالة مباشرة", isDark),
              const SizedBox(height: 15),

              // ✅ حقول الإدخال المربوطة بالـ Controllers
              _buildTextField(
                  label: "موضوع الرسالة",
                  isDark: isDark,
                  icon: Icons.subject_rounded,
                  controller: _subjectController),
              const SizedBox(height: 15),
              _buildTextField(
                label: "تفاصيل الرسالة",
                isDark: isDark,
                icon: Icons.chat_bubble_outline_rounded,
                maxLines: 5,
                controller: _messageController,
              ),
              const SizedBox(height: 30),
              _buildSubmitButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
            color: isDark ? Colors.white : const Color(0xFF2D3436)),
      ),
    );
  }

  Widget _buildContactCard(IconData icon, String title, String value,
      bool isDark, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
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
                offset: const Offset(0, 8))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: accentColor, size: 24),
        ),
        title: Text(title,
            style: TextStyle(
                fontSize: 11,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w600,
                color: Colors.grey[500])),
        subtitle: Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                color: isDark ? Colors.white : const Color(0xFF2D3436))),
        trailing: Icon(Icons.arrow_forward_ios_rounded,
            size: 14, color: Colors.grey[400]),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required bool isDark,
    required IconData icon,
    int maxLines = 1,
    required TextEditingController controller, // ✅ إضافة الكنترولر هنا
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border:
            Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller, // ✅ ربط الكنترولر
        maxLines: maxLines,
        style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontFamily: 'Cairo',
            fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
              color: Colors.grey[500], fontSize: 13, fontFamily: 'Cairo'),
          prefixIcon: Icon(icon, color: const Color(0xFF4CAF50), size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed:
            _isSending ? null : _sendMerchantMessage, // ✅ ربط الدالة بالزر
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18))),
        child: _isSending
            ? const CircularProgressIndicator(
                color: Colors.white) // ✅ عرض مؤشر تحميل
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text("إرسال الرسالة الآن",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Cairo')),
                ],
              ),
      ),
    );
  }
}
