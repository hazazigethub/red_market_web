import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui' as ui;
import 'package:red_market_core/red_market_core.dart';

// 1. مزود البيانات - جلب الباقات النشطة فقط وتصفيتها بدقة حسب السعر
final adminPlansProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await Supabase.instance.client
      .from('subscription_plans')
      .select()
      .eq('is_active', true) // جلب الباقات المفعلة فقط من قبل الأدمن
      .order('price', ascending: true);
  return List<Map<String, dynamic>>.from(data);
});

// ✅ مضاف: مزود لجلب الباقة الحالية للتاجر
final currentMerchantPlanProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;

  final profile = await Supabase.instance.client
      .from('profiles')
      .select('plan_id, subscription_end_date')
      .eq('id', userId)
      .maybeSingle();

  if (profile == null || profile['plan_id'] == null) return null;

  final plan = await Supabase.instance.client
      .from('subscription_plans')
      .select('id, price, name')
      .eq('id', profile['plan_id'])
      .maybeSingle();

  if (plan == null) return null;
  final result = {
    ...plan,
    'subscription_end_date': profile['subscription_end_date'],
  };
  debugPrint("✅ Plan Data: $result");
  return result;
});

// ✅ مضاف: Enum لحالات الباقة
enum _PlanStatus { current, downgrade, upgrade, available }

class MerchantSubscriptionsPage extends ConsumerStatefulWidget {
  const MerchantSubscriptionsPage({super.key});

  @override
  ConsumerState<MerchantSubscriptionsPage> createState() =>
      _MerchantSubscriptionsPageState();
}

class _MerchantSubscriptionsPageState
    extends ConsumerState<MerchantSubscriptionsPage> {
  /// دورة الفوترة لكل نوع باقة على حدة
  final Map<String, bool> _yearlyByType = {};

  int _selectedPlanIndex = 0;
  final Color brandRed = const Color(0xFFC21815);
  final Color darkCard = const Color(0xFF1E1E1E);

  // ✅ مضاف: دالة تحديد حالة الباقة
  _PlanStatus _getPlanStatus(
      Map<String, dynamic> plan, Map<String, dynamic>? currentPlan) {
    if (currentPlan == null) return _PlanStatus.available;
    final double currentPrice = (currentPlan['price'] as num?)?.toDouble() ?? 0;
    final double planPrice = (plan['price'] as num?)?.toDouble() ?? 0;
    final String currentPlanId = currentPlan['id'].toString();
    final String thisPlanId = plan['id'].toString();
    if (currentPlanId == thisPlanId) return _PlanStatus.current;
    if (planPrice < currentPrice) return _PlanStatus.downgrade;
    return _PlanStatus.upgrade;
  }

  // ✅ مضاف: نص الزر حسب الحالة
  String _getButtonLabel(_PlanStatus status) {
    switch (status) {
      case _PlanStatus.current:
        return "باقتك الحالية";
      case _PlanStatus.downgrade:
        return "غير متاح (تخفيض)";
      case _PlanStatus.upgrade:
        return "ترقية الباقة ↑";
      case _PlanStatus.available:
        return "اشتراك الآن";
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(adminPlansProvider);
    final currentPlanAsync = ref.watch(currentMerchantPlanProvider);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
        body: plansAsync.when(
          data: (plans) {
            if (plans.isEmpty) return _buildEmptyState();
            final currentPlan = currentPlanAsync.value;
            return RefreshIndicator(
              onRefresh: () async {
                ref.refresh(adminPlansProvider);
                ref.refresh(currentMerchantPlanProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        const gap = 16.0;
                        final cols = c.maxWidth >= 1100
                            ? 3
                            : c.maxWidth >= 720
                                ? 2
                                : 1;
                        final w = (c.maxWidth - gap * (cols - 1)) / cols;

                        // نجمع الباقات حسب النوع: كل نوع بطاقة واحدة
                        final grouped = <String, List<Map<String, dynamic>>>{};
                        for (final p in plans) {
                          final type = (p['plan_type'] ?? 'other').toString();
                          grouped.putIfAbsent(type, () => []).add(
                              Map<String, dynamic>.from(p));
                        }

                        const order = ['basic', 'growth', 'pro'];
                        final types = grouped.keys.toList()
                          ..sort((a, b) {
                            final ia = order.indexOf(a);
                            final ib = order.indexOf(b);
                            return (ia == -1 ? 99 : ia)
                                .compareTo(ib == -1 ? 99 : ib);
                          });

                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: List.generate(types.length, (index) {
                            final type = types[index];
                            final group = grouped[type]!;

                            // الشهرية والسنوية داخل النوع نفسه
                            final monthly = group.firstWhere(
                                (p) =>
                                    ((p['duration_days'] as num?)?.toInt() ??
                                        30) < 365,
                                orElse: () => group.first);
                            final yearly = group.firstWhere(
                                (p) =>
                                    ((p['duration_days'] as num?)?.toInt() ??
                                        30) >= 365,
                                orElse: () => <String, dynamic>{});

                            final hasYearly = yearly.isNotEmpty;
                            final isYearly =
                                _yearlyByType[type] == true && hasYearly;
                            final plan = isYearly ? yearly : monthly;

                            return SizedBox(
                              width: w,
                              child: _buildModernPlanCard(
                                context,
                                index: index,
                                plan: plan,
                                isDark: isDark,
                                currentPlan: currentPlan,
                                planType: type,
                                hasYearly: hasYearly,
                                isYearly: isYearly,
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
          loading: () =>
              Center(child: CircularProgressIndicator(color: brandRed)),
          error: (e, _) => Center(child: Text("حدث خطأ ما: $e")),
        ),
      ),
    );
  }

  Widget _buildModernPlanCard(BuildContext context,
      {required int index,
      required Map<String, dynamic> plan,
      required bool isDark,
      Map<String, dynamic>? currentPlan,
      String planType = '',
      bool hasYearly = false,
      bool isYearly = false}) {
    bool isSelected = _selectedPlanIndex == index;
    String duration = isYearly ? "سنوي" : "شهري";
    if (!hasYearly) duration = "شهري فقط";

    double currentPrice = (plan['price'] as num).toDouble();
    int discountPercent = plan['discount_percent'] ?? 0;

    // حساب السعر القديم قبل الخصم للعرض فقط
    double oldPrice = discountPercent > 0
        ? currentPrice / (1 - (discountPercent / 100))
        : currentPrice;

    final status = _getPlanStatus(plan, currentPlan);
    final bool isDisabled =
        status == _PlanStatus.current || status == _PlanStatus.downgrade;

    return GestureDetector(
      onTap:
          isDisabled ? null : () => setState(() => _selectedPlanIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutQuart,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: isDark ? darkCard : Colors.white,
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? brandRed.withOpacity(0.15)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
          border: Border.all(
            color: status == _PlanStatus.current
                ? Colors.green // ✅ لون أخضر للباقة الحالية
                : isSelected
                    ? brandRed
                    : brandRed.withOpacity(0.3),
            width: isSelected || status == _PlanStatus.current ? 2.5 : 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(plan['name'].toString().toUpperCase(),
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: brandRed)),
                            if (status == _PlanStatus.current &&
                                currentPlan?['subscription_end_date'] != null)
                              Text(
                                "ينتهي: ${DateTime.parse(currentPlan!['subscription_end_date']).day}/${DateTime.parse(currentPlan['subscription_end_date']).month}/${DateTime.parse(currentPlan['subscription_end_date']).year}",
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: brandRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(duration,
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: brandRed)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // مفتاح شهري / سنوي داخل الباقة
                    if (hasYearly) ...[
                      _cardBillingToggle(planType, isYearly, isDark),
                      const SizedBox(height: 16),
                    ],

                    // --- القسم المحدث: عرض السعر القديم والجديد والخصم ---
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (discountPercent > 0)
                          Row(
                            children: [
                              PriceWidget(
                                price: oldPrice,
                                fontSize: 16,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: brandRed.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "وفر $discountPercent%",
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    color: brandRed,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 5),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              "$currentPrice",
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Cairo',
                                color: brandRed,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Image.asset(
                              'assets/images/sar_symbol.png',
                              height: 22,
                              width: 22,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ],
                        ),
                      ],
                    ),
                    // --- نهاية قسم السعر المحدث ---

                    const Divider(
                        height: 40, thickness: 1, color: Color(0xFFEEEEEE)),

                    // ميزات الباقة كما حُفظت في قاعدة البيانات
                    Column(
                      children: ((plan['features'] as List?) ?? [])
                          .map((f) => _buildFeatureRow(
                              Icons.check_circle_rounded,
                              f.toString(),
                              isDark,
                              brandRed))
                          .toList(),
                    ),

                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: isDisabled
                            ? null
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نظام الدفع قيد التجهيز')));
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDisabled ? Colors.grey[300] : brandRed,
                          foregroundColor:
                              isDisabled ? Colors.grey : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                        ),
                        child: Text(_getButtonLabel(status),
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 80, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text("لا توجد باقات متاحة حالياً",
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  /// مفتاح شهري / سنوي داخل بطاقة الباقة
  Widget _cardBillingToggle(String type, bool isYearly, bool isDark) {
    Widget tab(String label, bool yearly) {
      final on = isYearly == yearly;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _yearlyByType[type] = yearly),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? brandRed : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: on ? FontWeight.bold : FontWeight.normal,
                color: on
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey.shade700),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFF1F2F5),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          tab('شهري', false),
          tab('سنوي', true),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(
      IconData icon, String text, bool isDark, Color brandRed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: brandRed),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.black87)),
          ),
        ],
      ),
    );
  }
}
