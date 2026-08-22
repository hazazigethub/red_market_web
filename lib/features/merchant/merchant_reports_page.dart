import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui' as ui;

class MerchantReportsPage extends StatefulWidget {
  final String? merchantId;
  const MerchantReportsPage({super.key, this.merchantId});

  @override
  State<MerchantReportsPage> createState() => _MerchantReportsPageState();
}

class _MerchantReportsPageState extends State<MerchantReportsPage> {
  final supabase = Supabase.instance.client;
  static const Color brandRed = Color(0xFFC21815);

  bool _isLoading = true;

  // ✅ مضاف: صلاحيات الباقة
  bool _hasBasicReports = false;
  bool _hasDetailedReports = false;

  // إحصائيات المتجر
  int _storeVisits = 0;
  int _followersCount = 0;

  // إحصائيات المنتجات
  int _productViews = 0;
  int _productLikes = 0;
  int _productSaves = 0;
  int _productShares = 0;

  // إحصائيات الريلز
  int _reelViews = 0;
  int _reelLikes = 0;
  int _reelShares = 0;
  int _reelComments = 0;

  // أكثر المنتجات مشاهدة
  List<Map<String, dynamic>> _topProducts = [];

  // أكثر الريلز مشاهدة
  List<Map<String, dynamic>> _topReels = [];

  // بيانات تفصيلية لكل نوع تفاعل
  final Map<String, List<Map<String, dynamic>>> _productDetailMap = {};
  final Map<String, List<Map<String, dynamic>>> _reelDetailMap = {};

  // إجمالي التفاعلات
  int get _totalProductInteractions =>
      _productViews + _productLikes + _productSaves + _productShares;
  int get _totalReelInteractions =>
      _reelViews + _reelLikes + _reelShares + _reelComments;

  @override
  void initState() {
    super.initState();
    _fetchAllStats();
  }

  Future<void> _fetchAllStats() async {
    setState(() => _isLoading = true);
    final merchantId = widget.merchantId ?? supabase.auth.currentUser?.id;
    if (merchantId == null) return;

    // ✅ إذا كان الأدمن — أعطه صلاحيات كاملة
    final isAdminViewing = widget.merchantId != null &&
        widget.merchantId != supabase.auth.currentUser?.id;
    if (isAdminViewing) {
      setState(() {
        _hasBasicReports = true;
        _hasDetailedReports = true;
      });
    } else {
      await _fetchPlanPermissions(merchantId);
    }

    if (!_hasBasicReports && !_hasDetailedReports) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      await Future.wait([
        _fetchStoreVisits(merchantId),
        _fetchFollowers(merchantId),
        _fetchProductStats(merchantId),
        _fetchReelStats(merchantId),
        _fetchTopProducts(merchantId),
        _fetchTopReels(merchantId),
      ]);
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ✅ مضاف: جلب صلاحيات الباقة
  Future<void> _fetchPlanPermissions(String merchantId) async {
    try {
      final profile = await supabase
          .from('profiles')
          .select('plan_id')
          .eq('id', merchantId)
          .maybeSingle();

      if (profile == null || profile['plan_id'] == null) return;

      final plan = await supabase
          .from('subscription_plans')
          .select('has_basic_reports, has_detailed_reports')
          .eq('id', profile['plan_id'])
          .maybeSingle();

      if (plan != null && mounted) {
        setState(() {
          _hasBasicReports = plan['has_basic_reports'] ?? false;
          _hasDetailedReports = plan['has_detailed_reports'] ?? false;
        });
      }
    } catch (e) {
      debugPrint("plan permissions error: $e");
    }
  }

  /// يجلب عدد متابعي المتجر
  Future<void> _fetchFollowers(String merchantId) async {
    try {
      final res = await supabase
          .from('merchants')
          .select('followers_count')
          .eq('id', merchantId)
          .maybeSingle();
      _followersCount = (res?['followers_count'] as int?) ?? 0;
    } catch (e) {
      debugPrint("followers error: $e");
    }
  }

  Future<void> _fetchStoreVisits(String merchantId) async {
    try {
      final res = await supabase
          .from('analytics_visits')
          .select('id')
          .eq('merchant_id', merchantId)
          .eq('page_name', 'store');
      _storeVisits = (res as List).length;
    } catch (e) {
      debugPrint("store visits error: $e");
    }
  }

  Future<void> _fetchProductStats(String merchantId) async {
    try {
      final views = await supabase
          .from('product_views')
          .select('id')
          .eq('merchant_id', merchantId);
      _productViews = (views as List).length;

      final products = await supabase
          .from('products')
          .select('id')
          .eq('merchant_id', merchantId);
      final productIds =
          (products as List).map((p) => p['id'].toString()).toList();

      if (productIds.isNotEmpty) {
        final likes = await supabase
            .from('product_likes')
            .select('product_id')
            .inFilter('product_id', productIds);
        _productLikes = (likes as List).length;

        final saves = await supabase
            .from('favorites')
            .select('product_id')
            .inFilter('product_id', productIds);
        _productSaves = (saves as List).length;

        final shares = await supabase
            .from('product_shares')
            .select('id')
            .eq('merchant_id', merchantId);
        _productShares = (shares as List).length;

        if (_hasDetailedReports) {
          await _fetchProductDetails(merchantId, productIds);
        }
      }
    } catch (e) {
      debugPrint("product stats error: $e");
    }
  }

  Future<void> _fetchProductDetails(
      String merchantId, List<String> productIds) async {
    try {
      final viewsRaw = await supabase
          .from('product_views')
          .select('product_id, products:product_id(name, image_url)')
          .eq('merchant_id', merchantId);

      final Map<String, int> viewCounts = {};
      final Map<String, dynamic> viewNames = {};
      for (final row in viewsRaw as List) {
        final id = row['product_id'].toString();
        viewCounts[id] = (viewCounts[id] ?? 0) + 1;
        if (row['products'] != null) viewNames[id] = row['products'];
      }
      _productDetailMap['views'] = viewCounts.entries.map((e) {
        final info = viewNames[e.key];
        return {
          'name': info?['name'] ?? 'منتج',
          'image_url': info?['image_url'] ?? '',
          'count': e.value,
          'label': 'مشاهدة',
        };
      }).toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      final likesRaw = await supabase
          .from('product_likes')
          .select('product_id, products:product_id(name, image_url)')
          .inFilter('product_id', productIds);

      final Map<String, int> likeCounts = {};
      final Map<String, dynamic> likeNames = {};
      for (final row in likesRaw as List) {
        final id = row['product_id'].toString();
        likeCounts[id] = (likeCounts[id] ?? 0) + 1;
        if (row['products'] != null) likeNames[id] = row['products'];
      }
      _productDetailMap['likes'] = likeCounts.entries.map((e) {
        final info = likeNames[e.key];
        return {
          'name': info?['name'] ?? 'منتج',
          'image_url': info?['image_url'] ?? '',
          'count': e.value,
          'label': 'إعجاب',
        };
      }).toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      final savesRaw = await supabase
          .from('favorites')
          .select('product_id, products:product_id(name, image_url)')
          .inFilter('product_id', productIds);

      final Map<String, int> saveCounts = {};
      final Map<String, dynamic> saveNames = {};
      for (final row in savesRaw as List) {
        final id = row['product_id'].toString();
        saveCounts[id] = (saveCounts[id] ?? 0) + 1;
        if (row['products'] != null) saveNames[id] = row['products'];
      }
      _productDetailMap['saves'] = saveCounts.entries.map((e) {
        final info = saveNames[e.key];
        return {
          'name': info?['name'] ?? 'منتج',
          'image_url': info?['image_url'] ?? '',
          'count': e.value,
          'label': 'حفظ',
        };
      }).toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      final sharesRaw = await supabase
          .from('product_shares')
          .select('product_id, products:product_id(name, image_url)')
          .eq('merchant_id', merchantId);

      final Map<String, int> shareCounts = {};
      final Map<String, dynamic> shareNames = {};
      for (final row in sharesRaw as List) {
        final id = row['product_id'].toString();
        shareCounts[id] = (shareCounts[id] ?? 0) + 1;
        if (row['products'] != null) shareNames[id] = row['products'];
      }
      _productDetailMap['shares'] = shareCounts.entries.map((e) {
        final info = shareNames[e.key];
        return {
          'name': info?['name'] ?? 'منتج',
          'image_url': info?['image_url'] ?? '',
          'count': e.value,
          'label': 'مشاركة',
        };
      }).toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    } catch (e) {
      debugPrint("product detail error: $e");
    }
  }

  Future<void> _fetchReelStats(String merchantId) async {
    try {
      final views = await supabase
          .from('reel_views')
          .select('id')
          .eq('merchant_id', merchantId);
      _reelViews = (views as List).length;

      final reels = await supabase
          .from('reels')
          .select('id')
          .eq('merchant_id', merchantId);
      final reelIds = (reels as List).map((r) => r['id'].toString()).toList();

      if (reelIds.isNotEmpty) {
        final likes = await supabase
            .from('reel_likes')
            .select('id')
            .inFilter('reel_id', reelIds);
        _reelLikes = (likes as List).length;

        final shares = await supabase
            .from('reel_shares')
            .select('id')
            .eq('merchant_id', merchantId);
        _reelShares = (shares as List).length;

        final comments = await supabase
            .from('reel_comments')
            .select('id')
            .inFilter('reel_id', reelIds);
        _reelComments = (comments as List).length;

        if (_hasDetailedReports) {
          await _fetchReelDetails(merchantId, reelIds);
        }
      }
    } catch (e) {
      debugPrint("reel stats error: $e");
    }
  }

  Future<void> _fetchReelDetails(
      String merchantId, List<String> reelIds) async {
    try {
      final viewsRaw = await supabase
          .from('reel_views')
          .select('reel_id, reels:reel_id(title, thumbnail_url)')
          .eq('merchant_id', merchantId);

      final Map<String, int> viewCounts = {};
      final Map<String, dynamic> viewNames = {};
      for (final row in viewsRaw as List) {
        final id = row['reel_id'].toString();
        viewCounts[id] = (viewCounts[id] ?? 0) + 1;
        if (row['reels'] != null) viewNames[id] = row['reels'];
      }
      _reelDetailMap['views'] = viewCounts.entries.map((e) {
        final info = viewNames[e.key];
        return {
          'name': info?['title'] ?? 'ريل',
          'image_url': info?['thumbnail_url'] ?? '',
          'count': e.value,
          'label': 'مشاهدة',
        };
      }).toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      final likesRaw = await supabase
          .from('reel_likes')
          .select('reel_id, reels:reel_id(title, thumbnail_url)')
          .inFilter('reel_id', reelIds);

      final Map<String, int> likeCounts = {};
      final Map<String, dynamic> likeNames = {};
      for (final row in likesRaw as List) {
        final id = row['reel_id'].toString();
        likeCounts[id] = (likeCounts[id] ?? 0) + 1;
        if (row['reels'] != null) likeNames[id] = row['reels'];
      }
      _reelDetailMap['likes'] = likeCounts.entries.map((e) {
        final info = likeNames[e.key];
        return {
          'name': info?['title'] ?? 'ريل',
          'image_url': info?['thumbnail_url'] ?? '',
          'count': e.value,
          'label': 'إعجاب',
        };
      }).toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      final sharesRaw = await supabase
          .from('reel_shares')
          .select('reel_id, reels:reel_id(title, thumbnail_url)')
          .eq('merchant_id', merchantId);

      final Map<String, int> shareCounts = {};
      final Map<String, dynamic> shareNames = {};
      for (final row in sharesRaw as List) {
        final id = row['reel_id'].toString();
        shareCounts[id] = (shareCounts[id] ?? 0) + 1;
        if (row['reels'] != null) shareNames[id] = row['reels'];
      }
      _reelDetailMap['shares'] = shareCounts.entries.map((e) {
        final info = shareNames[e.key];
        return {
          'name': info?['title'] ?? 'ريل',
          'image_url': info?['thumbnail_url'] ?? '',
          'count': e.value,
          'label': 'مشاركة',
        };
      }).toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      final commentsRaw = await supabase
          .from('reel_comments')
          .select('reel_id, reels:reel_id(title, thumbnail_url)')
          .inFilter('reel_id', reelIds);

      final Map<String, int> commentCounts = {};
      final Map<String, dynamic> commentNames = {};
      for (final row in commentsRaw as List) {
        final id = row['reel_id'].toString();
        commentCounts[id] = (commentCounts[id] ?? 0) + 1;
        if (row['reels'] != null) commentNames[id] = row['reels'];
      }
      _reelDetailMap['comments'] = commentCounts.entries.map((e) {
        final info = commentNames[e.key];
        return {
          'name': info?['title'] ?? 'ريل',
          'image_url': info?['thumbnail_url'] ?? '',
          'count': e.value,
          'label': 'تعليق',
        };
      }).toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    } catch (e) {
      debugPrint("reel detail error: $e");
    }
  }

  Future<void> _fetchTopProducts(String merchantId) async {
    try {
      final res = await supabase
          .from('product_views')
          .select('product_id, products:product_id(name, image_url)')
          .eq('merchant_id', merchantId);

      final List data = res as List;
      final Map<String, int> counts = {};
      final Map<String, dynamic> names = {};

      for (final row in data) {
        final id = row['product_id'].toString();
        counts[id] = (counts[id] ?? 0) + 1;
        if (row['products'] != null) names[id] = row['products'];
      }

      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      _topProducts = sorted.take(5).map((e) {
        final info = names[e.key];
        return {
          'name': info?['name'] ?? 'منتج',
          'image_url': info?['image_url'] ?? '',
          'views': e.value,
        };
      }).toList();
    } catch (e) {
      debugPrint("top products error: $e");
    }
  }

  Future<void> _fetchTopReels(String merchantId) async {
    try {
      final res = await supabase
          .from('reels')
          .select('id, title, thumbnail_url, likes_count, comments_count')
          .eq('merchant_id', merchantId)
          .order('likes_count', ascending: false)
          .limit(5);

      _topReels = (res as List)
          .map((r) => {
                'title': r['title'] ?? 'بدون عنوان',
                'thumbnail_url': r['thumbnail_url'] ?? '',
                'likes_count': r['likes_count'] ?? 0,
                'comments_count': r['comments_count'] ?? 0,
              })
          .toList();
    } catch (e) {
      debugPrint("top reels error: $e");
    }
  }

  void _showDetailSheet(
      String title, List<Map<String, dynamic>> items, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, scrollController) => Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            shape: BoxShape.circle),
                        child: Icon(Icons.bar_chart_rounded,
                            color: color, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(title,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text("${items.length} عنصر",
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: color,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_rounded,
                                  size: 60,
                                  color: Colors.grey.withOpacity(0.3)),
                              const SizedBox(height: 12),
                              const Text("لا توجد بيانات بعد",
                                  style: TextStyle(
                                      fontFamily: 'Cairo', color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final item = items[i];
                            final imageUrl =
                                item['image_url']?.toString() ?? '';
                            final name = item['name']?.toString() ?? '';
                            final count = item['count'] ?? 0;
                            final label = item['label']?.toString() ?? '';

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2A2A2A)
                                    : const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                        color: i == 0
                                            ? Colors.amber
                                            : i == 1
                                                ? Colors.grey[400]
                                                : i == 2
                                                    ? Colors.brown[300]
                                                    : color.withOpacity(0.15),
                                        shape: BoxShape.circle),
                                    child: Center(
                                      child: Text("${i + 1}",
                                          style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: i < 3
                                                  ? Colors.white
                                                  : color)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(imageUrl,
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                                    width: 48,
                                                    height: 48,
                                                    color: Colors.grey[200],
                                                    child: const Icon(
                                                        Icons.image,
                                                        color: Colors.grey,
                                                        size: 20)))
                                        : Container(
                                            width: 48,
                                            height: 48,
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.image,
                                                color: Colors.grey)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                        color: color.withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Text("$count $label",
                                        style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 11,
                                            color: color,
                                            fontWeight: FontWeight.bold)),
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
        ),
      ),
    );
  }

  // ✅ مضاف: شاشة الترقية
  Widget _buildUpgradePrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded,
                size: 80, color: Colors.grey.withOpacity(0.4)),
            const SizedBox(height: 20),
            const Text("التقارير غير متاحة في باقتك الحالية",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("رقّ باقتك للوصول إلى تقارير المتجر",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Cairo', fontSize: 13, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: brandRed,
          elevation: 0,
          centerTitle: true,
          title: const Text("تقارير المتجر",
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 18)),
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context)),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: brandRed))
            // ✅ مضاف: لا باقة → شاشة ترقية
            : !_hasBasicReports && !_hasDetailedReports
                ? _buildUpgradePrompt()
                : RefreshIndicator(
                    onRefresh: _fetchAllStats,
                    color: brandRed,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // الخانات الثلاث العلوية
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: Icons.storefront_rounded,
                                  label: "زيارات المتجر",
                                  value: _storeVisits,
                                  color: Colors.blue,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: Icons.inventory_2_rounded,
                                  label: "تفاعلات المنتجات",
                                  value: _totalProductInteractions,
                                  color: Colors.orange,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: Icons.play_circle_fill_rounded,
                                  label: "تفاعلات الريلز",
                                  value: _totalReelInteractions,
                                  color: Colors.redAccent,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: Icons.group_rounded,
                                  label: "المتابعون",
                                  value: _followersCount,
                                  color: Colors.teal,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // ✅ باقة بريميوم فقط: تفاصيل المنتجات والريلز
                          if (_hasDetailedReports) ...[
                            _buildSectionTitle("إحصائيات المنتجات",
                                Icons.inventory_2_rounded, Colors.orange),
                            const SizedBox(height: 12),
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.4,
                              children: [
                                _buildStatCard(
                                    icon: Icons.remove_red_eye_rounded,
                                    label: "مشاهدات المنتجات",
                                    value: _productViews,
                                    color: Colors.orange,
                                    isDark: isDark,
                                    onTap: () => _showDetailSheet(
                                        "مشاهدات المنتجات",
                                        _productDetailMap['views'] ?? [],
                                        Colors.orange)),
                                _buildStatCard(
                                    icon: Icons.favorite_rounded,
                                    label: "إعجابات المنتجات",
                                    value: _productLikes,
                                    color: Colors.red,
                                    isDark: isDark,
                                    onTap: () => _showDetailSheet(
                                        "إعجابات المنتجات",
                                        _productDetailMap['likes'] ?? [],
                                        Colors.red)),
                                _buildStatCard(
                                    icon: Icons.bookmark_rounded,
                                    label: "حفظ المنتجات",
                                    value: _productSaves,
                                    color: Colors.purple,
                                    isDark: isDark,
                                    onTap: () => _showDetailSheet(
                                        "حفظ المنتجات",
                                        _productDetailMap['saves'] ?? [],
                                        Colors.purple)),
                                _buildStatCard(
                                    icon: Icons.share_rounded,
                                    label: "مشاركات المنتجات",
                                    value: _productShares,
                                    color: Colors.teal,
                                    isDark: isDark,
                                    onTap: () => _showDetailSheet(
                                        "مشاركات المنتجات",
                                        _productDetailMap['shares'] ?? [],
                                        Colors.teal)),
                              ],
                            ),
                            const SizedBox(height: 24),
                            if (_topProducts.isNotEmpty) ...[
                              _buildSectionTitle("أكثر المنتجات مشاهدة",
                                  Icons.trending_up_rounded, Colors.orange),
                              const SizedBox(height: 12),
                              _buildTopList(
                                items: _topProducts,
                                imageKey: 'image_url',
                                titleKey: 'name',
                                valueKey: 'views',
                                valueLabel: 'مشاهدة',
                                color: Colors.orange,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 24),
                            ],
                            _buildSectionTitle(
                                "إحصائيات الريلز",
                                Icons.play_circle_fill_rounded,
                                Colors.redAccent),
                            const SizedBox(height: 12),
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.4,
                              children: [
                                _buildStatCard(
                                    icon: Icons.play_arrow_rounded,
                                    label: "مشاهدات الريلز",
                                    value: _reelViews,
                                    color: Colors.redAccent,
                                    isDark: isDark,
                                    onTap: () => _showDetailSheet(
                                        "مشاهدات الريلز",
                                        _reelDetailMap['views'] ?? [],
                                        Colors.redAccent)),
                                _buildStatCard(
                                    icon: Icons.favorite_rounded,
                                    label: "إعجابات الريلز",
                                    value: _reelLikes,
                                    color: Colors.pink,
                                    isDark: isDark,
                                    onTap: () => _showDetailSheet(
                                        "إعجابات الريلز",
                                        _reelDetailMap['likes'] ?? [],
                                        Colors.pink)),
                                _buildStatCard(
                                    icon: Icons.share_rounded,
                                    label: "مشاركات الريلز",
                                    value: _reelShares,
                                    color: Colors.indigo,
                                    isDark: isDark,
                                    onTap: () => _showDetailSheet(
                                        "مشاركات الريلز",
                                        _reelDetailMap['shares'] ?? [],
                                        Colors.indigo)),
                                _buildStatCard(
                                    icon: Icons.comment_rounded,
                                    label: "تعليقات الريلز",
                                    value: _reelComments,
                                    color: Colors.green,
                                    isDark: isDark,
                                    onTap: () => _showDetailSheet(
                                        "تعليقات الريلز",
                                        _reelDetailMap['comments'] ?? [],
                                        Colors.green)),
                              ],
                            ),
                          ],
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 16)),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(value.toString(),
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  color: isDark ? Colors.white60 : Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_left_rounded,
                      color: color.withOpacity(0.5), size: 18),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value.toString(),
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: color)),
                Text(label,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopList({
    required List<Map<String, dynamic>> items,
    required String imageKey,
    required String titleKey,
    required String valueKey,
    required String valueLabel,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: items.map((item) {
        final imageUrl = item[imageKey]?.toString() ?? '';
        final title = item[titleKey]?.toString() ?? '';
        final value = item[valueKey] ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imageUrl.isNotEmpty
                    ? Image.network(imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported,
                                color: Colors.grey, size: 20)))
                    : Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, color: Colors.grey)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Text("$value $valueLabel",
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
