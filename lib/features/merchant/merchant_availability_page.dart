import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantAvailabilityPage extends StatefulWidget {
  const MerchantAvailabilityPage({super.key});

  @override
  State<MerchantAvailabilityPage> createState() =>
      _MerchantAvailabilityPageState();
}

class _MerchantAvailabilityPageState extends State<MerchantAvailabilityPage> {
  final supabase = Supabase.instance.client;
  // أيام الأسبوع
  final List<String> weekDays = [
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت'
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = supabase.auth.currentUser?.id;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text("إعدادات أوقات الحجوزات",
              style:
                  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          elevation: 0,
          leading: const BackButton(),
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: supabase
              .from('merchant_availability')
              .stream(primaryKey: ['id'])
              .eq('merchant_id', userId ?? '')
              .order('day_of_week', ascending: true),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4CAF50)));
            }

            final data = snapshot.data ?? [];

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: weekDays.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                // البحث عن إعدادات هذا اليوم في البيانات القادمة من السيرفر
                final daySettings = data.firstWhere(
                    (e) => e['day_of_week'] == index + 1,
                    orElse: () => {});
                final bool isActive = daySettings['is_active'] ?? false;
                final String startTime = daySettings['start_time'] ?? '09:00';
                final String endTime = daySettings['end_time'] ?? '22:00';

                return Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isActive
                            ? const Color(0xFF4CAF50)
                            : (isDark ? Colors.white10 : Colors.grey.shade300)),
                  ),
                  child: Row(
                    children: [
                      // اسم اليوم
                      SizedBox(
                        width: 70,
                        child: Text(weekDays[index],
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black)),
                      ),

                      // الأوقات (تظهر فقط إذا كان اليوم مفعلاً)
                      if (isActive) ...[
                        _timeChip(context, "من $startTime", isDark),
                        const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 5),
                            child: Text("-")),
                        _timeChip(context, "إلى $endTime", isDark),
                      ] else
                        const Expanded(
                            child: Text("مغلق",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontFamily: 'Cairo', color: Colors.grey))),

                      // زر التفعيل
                      Switch(
                        value: isActive,
                        activeColor: const Color(0xFF4CAF50),
                        onChanged: (val) => _updateDay(userId!, index + 1, val,
                            startTime, endTime, daySettings['id']),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _timeChip(BuildContext context, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: isDark ? Colors.black26 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  Future<void> _updateDay(String merchantId, int dayIndex, bool isActive,
      String start, String end, dynamic recordId) async {
    // إذا كان السجل موجوداً نحدثه، وإلا ننشئه
    if (recordId != null) {
      await supabase
          .from('merchant_availability')
          .update({'is_active': isActive}).eq('id', recordId);
    } else {
      await supabase.from('merchant_availability').insert({
        'merchant_id': merchantId,
        'day_of_week': dayIndex,
        'is_active': isActive,
        'start_time': start, // قيم افتراضية
        'end_time': end,
      });
    }
  }
}
