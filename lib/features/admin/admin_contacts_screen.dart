import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminContactsScreen extends StatefulWidget {
  const AdminContactsScreen({super.key});

  @override
  State<AdminContactsScreen> createState() => _AdminContactsScreenState();
}

class _AdminContactsScreenState extends State<AdminContactsScreen> {
  static const Color brandRed = Color(0xFFC21815);

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String _filter = 'new';

  static const _filters = [
    (key: 'new', label: 'جديدة'),
    (key: 'handled', label: 'معالجة'),
    (key: 'closed', label: 'مغلقة'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('contact_requests')
          .select()
          .eq('status', _filter)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _rows = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Contacts load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: color,
    ));
  }

  Future<void> _updateStatus(
      Map<String, dynamic> row, String status, String? note) async {
    try {
      await supabase.from('contact_requests').update({
        'status': status,
        'handled_at': DateTime.now().toIso8601String(),
        if (note != null) 'admin_note': note,
      }).eq('id', row['id']);

      await _load();
      _snack(
        status == 'handled' ? 'تم وضعها كمعالجة' : 'تم إغلاق الرسالة',
        status == 'handled' ? Colors.green : Colors.grey.shade700,
      );
    } catch (e) {
      _snack('تعذر التحديث', Colors.red);
    }
  }

  void _noteDialog(Map<String, dynamic> row, String status) {
    final noteCtrl =
        TextEditingController(text: (row['admin_note'] ?? '').toString());
    final isHandled = status == 'handled';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isHandled ? 'تأكيد المعالجة' : 'إغلاق الرسالة',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHandled
                      ? 'أكّد أنك رددت على ${row['name'] ?? 'المرسل'}.'
                      : 'ستُغلق الرسالة ولن تظهر في الجديدة.',
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontSize: 13.5, height: 1.9),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'ملاحظة (اختياري)',
                    hintStyle: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Colors.grey.shade400),
                    filled: true,
                    fillColor: const Color(0xFFF7F8FA),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isHandled ? Colors.green : Colors.grey,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _updateStatus(row, status,
                    noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
              },
              child: Text(isHandled ? 'تأكيد' : 'إغلاق',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic raw) {
    if (raw == null) return '—';
    final d = DateTime.tryParse(raw.toString());
    if (d == null) return '—';
    final local = d.toLocal();
    return "${local.year}/${local.month}/${local.day} — "
        "${local.hour}:${local.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _load,
        color: brandRed,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text('رسائل التواصل',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 19,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Text('${_rows.length}',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              color: Colors.grey.shade500)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 8,
                    children: _filters.map((f) {
                      final on = _filter == f.key;
                      return GestureDetector(
                        onTap: () {
                          if (_filter == f.key) return;
                          setState(() => _filter = f.key);
                          _load();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: on ? brandRed : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    on ? brandRed : const Color(0xFFEDEFF3)),
                          ),
                          child: Text(
                            f.label,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12.5,
                              fontWeight:
                                  on ? FontWeight.bold : FontWeight.normal,
                              color: on ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                          child:
                              CircularProgressIndicator(color: brandRed)),
                    )
                  else if (_rows.isEmpty)
                    _empty()
                  else
                    ..._rows.map(_card),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> r) {
    final isNew = r['status'] == 'new';
    final phone = (r['phone'] ?? '').toString();
    final email = (r['email'] ?? '').toString();
    final note = (r['admin_note'] ?? '').toString();
    final registered = r['user_id'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isNew
                ? brandRed.withValues(alpha: 0.3)
                : const Color(0xFFEDEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: brandRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.mail_outline_rounded,
                    color: brandRed, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            (r['name'] ?? 'زائر').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (registered ? Colors.blue : Colors.grey)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            registered ? 'مسجّل' : 'زائر',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color:
                                    registered ? Colors.blue : Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    Text(_fmt(r['created_at']),
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFFEDEFF3), height: 1),
          const SizedBox(height: 14),

          if (phone.isNotEmpty) ...[
            _line(Icons.phone_android_rounded, phone),
            const SizedBox(height: 8),
          ],
          if (email.isNotEmpty) ...[
            _line(Icons.mail_outline_rounded, email),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 6),

          Text(
            (r['subject'] ?? '').toString(),
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13.5,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              (r['message'] ?? '').toString(),
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 12.5, height: 1.9),
            ),
          ),

          if (note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sticky_note_2_outlined,
                    size: 15, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(note,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          height: 1.7,
                          color: Colors.grey.shade600)),
                ),
              ],
            ),
          ],

          if (isNew) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _noteDialog(r, 'handled'),
                    icon: const Icon(Icons.check_rounded, size: 17),
                    label: const Text('تمت المعالجة',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => _noteDialog(r, 'closed'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade400),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('إغلاق',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade500),
        const SizedBox(width: 9),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.mark_email_read_outlined,
              size: 58, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          const Text('لا توجد رسائل',
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 15, color: Colors.grey)),
        ],
      ),
    );
  }
}
