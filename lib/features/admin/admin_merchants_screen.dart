import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- الصفحة الرئيسية: الإحصائيات ---
class AdminMerchantsScreen extends StatefulWidget {
  const AdminMerchantsScreen({super.key});

  @override
  State<AdminMerchantsScreen> createState() => _AdminMerchantsScreenState();
}

class _AdminMerchantsScreenState extends State<AdminMerchantsScreen> {
  final supabase = Supabase.instance.client;
  static const Color brandRed = Color(0xFFC21815);
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: brandRed,
          elevation: 0,
          title: const Text("إحصائيات وإدارة المتاجر",
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Column(
          children: [
            // شريط البحث الرئيسي
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
              decoration: const BoxDecoration(
                color: brandRed,
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30)),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: "ابحث باسم المتجر أو الإيميل...",
                  hintStyle: const TextStyle(
                      fontFamily: 'Cairo', color: Colors.grey, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: brandRed),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none),
                ),
              ),
            ),

            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: supabase
                    .from('profiles')
                    .select()
                    .eq('role', 'merchant')
                    .then((v) => List<Map<String, dynamic>>.from(v)),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: brandRed));
                  }
                  final rawData = snapshot.data ?? [];

                  final filteredData = rawData.where((m) {
                    final name = (m['store_name'] ?? m['full_name'] ?? '')
                        .toString()
                        .toLowerCase();
                    final email = (m['email'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery.toLowerCase()) ||
                        email.contains(_searchQuery.toLowerCase());
                  }).toList();

                  final activeList = filteredData
                      .where((m) =>
                          (m['is_subscription_active'] ?? false) &&
                          !(m['is_banned'] ?? false))
                      .toList();

                  final bannedList = filteredData
                      .where((m) => (m['is_banned'] ?? false))
                      .toList();

                  final expiredList = filteredData
                      .where((m) =>
                          !(m['is_subscription_active'] ?? false) &&
                          !(m['is_banned'] ?? false))
                      .toList();

                  // منطق التجار الذين لم يشتركوا أبداً (بناءً على الجداول المرسلة)
                  final neverSubscribedList = filteredData
                      .where((m) =>
                          !(m['is_subscription_active'] ?? false) &&
                          (m['user_status'] == null ||
                              m['user_status'] == 'new'))
                      .toList();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildSummaryCard(
                            "إجمالي التجار",
                            "${filteredData.length}",
                            Colors.purple,
                            Icons.group_work,
                            filteredData,
                            "الكل"),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                                child: _buildSmallStatCard(
                                    "نشط حالياً",
                                    "${activeList.length}",
                                    Colors.green,
                                    Icons.bolt,
                                    activeList,
                                    "النشطة")),
                            const SizedBox(width: 15),
                            Expanded(
                                child: _buildSmallStatCard(
                                    "لم يشتركوا أبداً",
                                    "${neverSubscribedList.length}",
                                    Colors.orange,
                                    Icons.person_add_disabled,
                                    neverSubscribedList,
                                    "غير المشتركين")),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                                child: _buildSmallStatCard(
                                    "المحظورة",
                                    "${bannedList.length}",
                                    Colors.black,
                                    Icons.block,
                                    bannedList,
                                    "المحظورة")),
                            const SizedBox(width: 15),
                            Expanded(
                                child: _buildSmallStatCard(
                                    "اشتراك منتهي",
                                    "${expiredList.length}",
                                    Colors.red,
                                    Icons.money_off,
                                    expiredList,
                                    "المنتهية")),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color,
      IconData icon, List<Map<String, dynamic>> list, String category) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => MerchantGridPage(
                  merchants: list, title: category, brandColor: brandRed))),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)
            ]),
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color)),
            const SizedBox(width: 15),
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallStatCard(String title, String value, Color color,
      IconData icon, List<Map<String, dynamic>> list, String category) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => MerchantGridPage(
                  merchants: list, title: category, brandColor: brandRed))),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withOpacity(0.1), width: 1.5)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// --- الصفحة الثانية: عرض المربعات (Grid) ---
class MerchantGridPage extends StatefulWidget {
  final List<Map<String, dynamic>> merchants;
  final String title;
  final Color brandColor;
  const MerchantGridPage(
      {super.key,
      required this.merchants,
      required this.title,
      required this.brandColor});

  @override
  State<MerchantGridPage> createState() => _MerchantGridPageState();
}

class _MerchantGridPageState extends State<MerchantGridPage> {
  late List<Map<String, dynamic>> _filteredList;
  String _internalQuery = '';

  @override
  void initState() {
    super.initState();
    _filteredList = widget.merchants;
  }

  void _filter(String val) {
    setState(() {
      _internalQuery = val;
      _filteredList = widget.merchants.where((m) {
        final name =
            (m['store_name'] ?? m['full_name'] ?? '').toString().toLowerCase();
        return name.contains(_internalQuery.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
            backgroundColor: widget.brandColor,
            title: Text("متاجر: ${widget.title}",
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            iconTheme: const IconThemeData(color: Colors.white)),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
              decoration: BoxDecoration(
                  color: widget.brandColor,
                  borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30))),
              child: TextField(
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: "بحث في هذه القائمة...",
                  prefixIcon: Icon(Icons.search, color: widget.brandColor),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: _filteredList.isEmpty
                  ? const Center(
                      child: Text("لا توجد بيانات",
                          style: TextStyle(fontFamily: 'Cairo')))
                  : GridView.builder(
                      padding: const EdgeInsets.all(20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 15,
                              mainAxisSpacing: 15,
                              childAspectRatio: 0.75),
                      itemCount: _filteredList.length,
                      itemBuilder: (context, index) {
                        final m = _filteredList[index];
                        return GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      MerchantControlScreen(merchant: m))),
                          child: _buildItem(m),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(Map m) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ]),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
              radius: 35,
              backgroundColor: widget.brandColor.withOpacity(0.1),
              backgroundImage: m['store_logo_url'] != null
                  ? NetworkImage(m['store_logo_url'])
                  : null,
              child: m['store_logo_url'] == null
                  ? Icon(Icons.store, color: widget.brandColor, size: 30)
                  : null),
          const SizedBox(height: 12),
          Text(m['store_name'] ?? m['full_name'] ?? 'بدون اسم',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const SizedBox(height: 10),
          _getStatusBadge(m),
        ],
      ),
    );
  }

  Widget _getStatusBadge(Map m) {
    bool isBanned = m['is_banned'] ?? false;
    if (isBanned) {
      return const Text("محظور",
          style: TextStyle(
              color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold));
    }
    bool isSubscriptionActive = m['is_subscription_active'] ?? false;
    return isSubscriptionActive
        ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
        : const Text("اشتراك منتهي",
            style: TextStyle(color: Colors.red, fontSize: 10));
  }
}

// --- الصفحة الثالثة: إدارة المتجر ---
class MerchantControlScreen extends StatefulWidget {
  final Map merchant;
  const MerchantControlScreen({super.key, required this.merchant});

  @override
  State<MerchantControlScreen> createState() => _MerchantControlScreenState();
}

class _MerchantControlScreenState extends State<MerchantControlScreen> {
  final supabase = Supabase.instance.client;
  late bool isVerified;
  late bool isBanned;

  String? selectedReason;
  String? selectedDuration;
  bool isPermanentBan = false;

  final List<String> banReasons = [
    "محتوى مخالف للشروط",
    "احتيال أو بلاغات كاذبة",
    "انتهاء فترة السماح للسداد",
    "إساءة استخدام المنصة",
    "أخرى"
  ];

  final List<Map<String, dynamic>> banDurations = [
    {"label": "3 أيام", "days": 3},
    {"label": "أسبوع", "days": 7},
    {"label": "شهر", "days": 30},
  ];

  @override
  void initState() {
    super.initState();
    isVerified = widget.merchant['is_verified'] ?? false;
    isBanned = widget.merchant['is_banned'] ?? false;
  }

  Future<void> _toggleStatus(String column, bool currentValue) async {
    final newValue = !currentValue;

    setState(() {
      if (column == 'is_verified') isVerified = newValue;
      if (column == 'is_banned') isBanned = newValue;
    });

    try {
      Map<String, dynamic> updateData = {column: newValue};

      if (column == 'is_banned' && newValue == true) {
        updateData['ban_reason'] = selectedReason ?? "غير محدد";
        updateData['is_permanent_ban'] = isPermanentBan;
        if (!isPermanentBan && selectedDuration != null) {
          int days = banDurations
              .firstWhere((d) => d['label'] == selectedDuration)['days'];
          updateData['ban_until'] =
              DateTime.now().add(Duration(days: days)).toIso8601String();
        }
      }

      await supabase
          .from('profiles')
          .update(updateData)
          .eq('id', widget.merchant['id']);
      await supabase
          .from('merchants')
          .update(updateData)
          .eq('id', widget.merchant['id']);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("تم التحديث", style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1)));
    } catch (e) {
      setState(() {
        if (column == 'is_verified') isVerified = currentValue;
        if (column == 'is_banned') isBanned = currentValue;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("فشل الاتصال بالخادم")));
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandRed = Color(0xFFC21815);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: const Text("لوحة التحكم بالمتجر",
                style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.black,
                    fontWeight: FontWeight.bold)),
            iconTheme: const IconThemeData(color: Colors.black),
            centerTitle: true),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                        radius: 60,
                        backgroundColor: brandRed.withOpacity(0.1),
                        backgroundImage: widget.merchant['store_logo_url'] !=
                                null
                            ? NetworkImage(widget.merchant['store_logo_url'])
                            : null,
                        child: widget.merchant['store_logo_url'] == null
                            ? const Icon(Icons.store, size: 60, color: brandRed)
                            : null),
                    const SizedBox(height: 20),
                    Text(widget.merchant['store_name'] ?? 'اسم المتجر',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo')),
                    Text(widget.merchant['email'] ?? '',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontFamily: 'Cairo')),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              _buildAdminButton(
                label: isVerified ? "تعطيل حساب المتجر" : "تفعيل المتجر الآن",
                icon: isVerified
                    ? Icons.no_accounts_rounded
                    : Icons.verified_rounded,
                primaryColor:
                    isVerified ? Colors.orange.shade600 : Colors.green.shade600,
                onTap: () => _toggleStatus('is_verified', isVerified),
              ),
              const SizedBox(height: 20),
              if (!isBanned) ...[
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text("إعدادات الحظر:",
                      style: TextStyle(
                          fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none),
                    hintText: "اختر سبب الحظر",
                  ),
                  items: banReasons
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (val) => setState(() => selectedReason = val),
                ),
                const SizedBox(height: 10),
                if (!isPermanentBan)
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none),
                      hintText: "حدد مدة الحظر",
                    ),
                    items: banDurations
                        .map((d) => DropdownMenuItem(
                            value: d['label'] as String,
                            child: Text(d['label'])))
                        .toList(),
                    onChanged: (val) => setState(() => selectedDuration = val),
                  ),
                CheckboxListTile(
                  title: const Text("حظر دائم (لا يمكن للمتجر التظلم)",
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                  value: isPermanentBan,
                  onChanged: (val) => setState(() {
                    isPermanentBan = val!;
                    if (isPermanentBan) selectedDuration = null;
                  }),
                  activeColor: brandRed,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              _buildAdminButton(
                label: isBanned ? "رفع الحظر عن المتجر" : "تأكيد حظر المتجر",
                icon: isBanned ? Icons.gavel_rounded : Icons.block_flipped,
                primaryColor: isBanned ? Colors.blueGrey.shade700 : brandRed,
                onTap: () {
                  if (!isBanned) {
                    if (selectedReason == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("يرجى اختيار سبب الحظر")));
                      return;
                    }
                    if (!isPermanentBan && selectedDuration == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("يرجى اختيار مدة الحظر")));
                      return;
                    }
                  }
                  _toggleStatus('is_banned', isBanned);
                },
              ),
              const SizedBox(height: 20),
              _buildAdminButton(
                label: "إرسال رسالة إدارية",
                icon: Icons.chat_bubble_outline_rounded,
                primaryColor: Colors.blue.shade800,
                onTap: () {},
              ),
              const SizedBox(height: 20),
              _buildAdminButton(
                label: "داشبورد التاجر",
                icon: Icons.dashboard_customize_rounded,
                primaryColor: Colors.teal.shade700,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لوحة التاجر ستتوفر قريباً')));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminButton(
      {required String label,
      required IconData icon,
      required Color primaryColor,
      required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: primaryColor.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Material(
        color: primaryColor,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.bold))),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
