import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';
import 'admin_merchants_screen.dart';

/// قائمة التجار الجدد للمراجعة — الأحدث أولاً، مع تمييز غير المفحوصين
class NewMerchantsScreen extends StatefulWidget {
  const NewMerchantsScreen({super.key});

  @override
  State<NewMerchantsScreen> createState() => _NewMerchantsScreenState();
}

class _NewMerchantsScreenState extends State<NewMerchantsScreen> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future;
  bool _onlyUnverified = true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await supabase
        .from('merchants')
        .select()
        .order('created_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(rows);
  }

  void _refresh() {
    if (mounted) setState(() => _future = _load());
  }

  String _fmtDate(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    if (d == null) return '—';
    return '${d.year}/${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: AppColors.brand,
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: const Text('التجار الجدد',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo')),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              FilterChip(
                label: const Text('غير المفحوصين فقط'),
                selected: _onlyUnverified,
                selectedColor: AppColors.brand.withValues(alpha: 0.15),
                checkmarkColor: AppColors.brand,
                onSelected: (v) => setState(() => _onlyUnverified = v),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'تحديث',
                icon: const Icon(Icons.refresh),
                onPressed: _refresh,
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('تعذر التحميل: ${snap.error}'));
              }
              final all = snap.data ?? const [];
              final list = _onlyUnverified
                  ? all.where((m) => (m['is_verified'] ?? false) != true).toList()
                  : all;

              if (list.isEmpty) {
                return const Center(
                  child: Text('لا توجد نتائج',
                      style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final m = list[i];
                  final verified = (m['is_verified'] ?? false) == true;
                  final banned = (m['is_banned'] ?? false) == true;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.brand.withValues(alpha: 0.1),
                        child: Icon(
                          banned
                              ? Icons.block
                              : verified
                                  ? Icons.verified_outlined
                                  : Icons.store_outlined,
                          color: banned
                              ? Colors.red
                              : verified
                                  ? Colors.green
                                  : AppColors.brand,
                        ),
                      ),
                      title: Text(
                        m['store_name']?.toString() ?? 'متجر بلا اسم',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                      subtitle: Text(
                        'سجل: ${m['cr_number'] ?? '—'}   ·   ${_fmtDate(m['created_at'])}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontFamily: 'Cairo'),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: verified
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              verified ? 'تم الفحص' : 'بانتظار الفحص',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold,
                                  color: verified
                                      ? Colors.green.shade700
                                      : Colors.orange.shade800),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_left, color: Colors.grey),
                        ],
                      ),
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => MerchantControlScreen(merchant: m),
                        ));
                        _refresh();
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
