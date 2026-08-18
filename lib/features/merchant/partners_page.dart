import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ استيراد سوبابيز

class PartnersPage extends StatelessWidget {
  const PartnersPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ دالة جلب الشركاء من Supabase
    Future<List<Map<String, dynamic>>> _fetchPartners() async {
      final response = await Supabase.instance.client
          .from('partners')
          .select()
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Center(
            child: Text(
              "شركاؤنا",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                  color: Color(0xFF4CAF50)),
            ),
          ),
        ),

        // ✅ استخدام FutureBuilder لجلب البيانات الحقيقية
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchPartners(),
          builder: (context, snapshot) {
            // 1. حالة التحميل
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(40.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            // 2. حالة الخطأ أو قائمة فارغة
            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    "سيتم عرض الشركاء قريباً",
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
                  ),
                ),
              );
            }

            final partners = snapshot.data!;

            // 3. عرض البيانات عند توفرها
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 15,
                mainAxisSpacing: 20,
                childAspectRatio: 1.0,
              ),
              itemCount: partners.length,
              itemBuilder: (context, index) {
                final partner = partners[index];
                return Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 5)
                          ],
                        ),
                        child: Center(
                          child: Image.network(
                            partner['logo_url'] ?? '',
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2));
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.business_rounded,
                                    size: 30, color: Colors.grey),
                                Text("غير متاح",
                                    style: TextStyle(
                                        fontSize: 8, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      partner['name'] ?? '',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          fontFamily: 'Cairo'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}
