import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:red_market_core/red_market_core.dart';
import 'merchant_subscriptions_page.dart';

const Color brandRed = Color(0xFFC21815);

class ProductItem {
  final String id;
  String name;
  String categoryId;
  String storeCategory;
  double price;
  double? oldPrice;
  String description;
  String productUrl;
  bool isAvailable;
  String imageUrl;
  bool isFlashSale;
  DateTime? flashSaleExpiry;

  ProductItem({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.storeCategory,
    required this.price,
    this.oldPrice,
    required this.description,
    required this.productUrl,
    required this.isAvailable,
    required this.imageUrl,
    this.isFlashSale = false,
    this.flashSaleExpiry,
  });

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    return ProductItem(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      categoryId: json['category_id']?.toString() ?? '',
      storeCategory: json['store_category'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      oldPrice: (json['old_price'] as num?)?.toDouble(),
      description: json['description'] ?? '',
      productUrl: json['product_url'] ?? '',
      isAvailable: json['is_available'] ?? true,
      imageUrl: (json['image_url'] != null &&
              json['image_url'].toString().trim().length > 10)
          ? json['image_url'].toString()
          : 'https://cdn-icons-png.flaticon.com/512/3075/3075977.png',
      isFlashSale: json['is_flash_sale'] ?? false,
      flashSaleExpiry: json['flash_sale_expiry'] != null
          ? DateTime.parse(json['flash_sale_expiry'])
          : null,
    );
  }

  Map<String, dynamic> toJson(String merchantId) {
    return {
      'merchant_id': merchantId,
      'name': name,
      'category_id': categoryId,
      'store_category': storeCategory,
      'price': price,
      'old_price': oldPrice,
      'description': description,
      'product_url': productUrl,
      'is_available': isAvailable,
      'image_url': imageUrl,
      'is_flash_sale': isFlashSale,
      'flash_sale_expiry': flashSaleExpiry?.toIso8601String(),
    };
  }
}

class CategoryItem {
  final String id;
  final String name;
  final String? storeCategoryId;

  CategoryItem({
    required this.id,
    required this.name,
    this.storeCategoryId,
  });

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      storeCategoryId: json['store_category_id']?.toString(),
    );
  }
}

class ProductsPage extends StatefulWidget {
  final String? merchantId;
  const ProductsPage({super.key, this.merchantId});
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  // ✅ التبويب الرئيسي: منتجات أو أقسام
  String _currentView = "المنتجات";

  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  List<ProductItem> _productsList = [];
  List<CategoryItem> _mainCategories = [];
  List<CategoryItem> _allSubCategories = [];
  List<CategoryItem> _categoriesList = [];
  List<String> _myStoreCategories = [];
  bool _isLoading = true;
  String _selectedStoreCategory = "الكل";
  int _productLimit = 5;
  bool _isSubscriptionActive = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    await _fetchProductLimit();
    await _fetchCategories();
    await _fetchProducts();
    _loadMyStoreCategories();
  }

  Future<void> _fetchProductLimit() async {
    try {
      final userId = widget.merchantId ?? supabase.auth.currentUser?.id;
      if (userId == null) return;
      // ✅ إذا كان الأدمن — أعطه صلاحيات كاملة
      if (widget.merchantId != null &&
          widget.merchantId != supabase.auth.currentUser?.id) {
        if (mounted)
          setState(() {
            _isSubscriptionActive = true;
            _productLimit = 9999;
          });
      }
      final profile = await supabase
          .from('profiles')
          .select('plan_id, is_subscription_active')
          .eq('id', userId)
          .maybeSingle();
      if (profile == null) return;

      if (mounted) {
        setState(() {
          _isSubscriptionActive = profile['is_subscription_active'] ?? false;
        });
      }

      if (profile['plan_id'] == null) return;
      final plan = await supabase
          .from('subscription_plans')
          .select('product_limit')
          .eq('id', profile['plan_id'])
          .maybeSingle();
      if (plan != null && plan['product_limit'] != null) {
        if (mounted) {
          setState(() {
            _productLimit = (plan['product_limit'] as num).toInt();
          });
        }
      }
      if (plan != null && plan['product_limit'] != null) {
        if (mounted) {
          setState(() {
            _productLimit = (plan['product_limit'] as num).toInt();
          });
        }
      }
    } catch (e) {
      debugPrint("خطأ في جلب حد المنتجات: $e");
    }
  }

  void _loadMyStoreCategories() {
    setState(() {
      _myStoreCategories = _productsList
          .map((p) => p.storeCategory)
          .where((sc) => sc.isNotEmpty)
          .toSet()
          .toList();
    });
  }

  Future<void> _fetchProducts() async {
    try {
      final userId = widget.merchantId ?? supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await supabase
          .from('products')
          .select()
          .eq('merchant_id', userId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _productsList =
              (data as List).map((e) => ProductItem.fromJson(e)).toList();
          _loadMyStoreCategories();
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('PRODUCTS ERROR: $e | $st');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProduct(String productId) async {
    try {
      await supabase.from('products').delete().eq('id', productId);
      _fetchProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("تم حذف المنتج بنجاح",
                  style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("خطأ في الحذف: $e",
                  style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final storeData =
          await supabase.from('store_categories').select().order('name');
      final productData =
          await supabase.from('product_categories').select().order('name');
      if (mounted) {
        setState(() {
          _mainCategories =
              (storeData as List).map((e) => CategoryItem.fromJson(e)).toList();
          _allSubCategories = (productData as List)
              .map((e) => CategoryItem.fromJson(e))
              .toList();
          _categoriesList = _allSubCategories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAllCategoriesFallback() async {
    try {
      final data = await supabase
          .from('product_categories')
          .select()
          .eq('is_visible', true)
          .order('name');
      if (mounted) {
        setState(() {
          _categoriesList =
              (data as List).map((e) => CategoryItem.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint("Fallback Error: $e");
    }
  }

  Future<String?> _uploadImage(XFile imageFile) async {
    try {
      final userId = widget.merchantId ?? supabase.auth.currentUser?.id;
      if (userId == null) return null;
      final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await imageFile.readAsBytes();
      await supabase.storage.from('product-images').uploadBinary(
            fileName,
            bytes,
            fileOptions:
                const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      final String publicUrl =
          supabase.storage.from('product-images').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      debugPrint("خطأ أثناء رفع الصورة: $e");
      return null;
    }
  }

  Future<void> _upsertProduct(ProductItem product,
      {bool isUpdate = false}) async {
    final userId = widget.merchantId ?? supabase.auth.currentUser?.id;
    if (userId == null) return;
    isUpdate
        ? await supabase
            .from('products')
            .update(product.toJson(userId))
            .eq('id', product.id)
        : await supabase.from('products').insert(product.toJson(userId));
    _fetchProducts();
  }

  void _showCategorySearchDialog(
      String? currentId, Function(CategoryItem) onSelect) {
    String searchQuery = "";
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = _categoriesList
                .where((c) => c.name.contains(searchQuery))
                .toList();
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text("اختر التصنيف المعتمد للمنصة",
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      color: brandRed,
                      fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (v) => setDialogState(() => searchQuery = v),
                      style: const TextStyle(fontFamily: 'Cairo'),
                      decoration: InputDecoration(
                        hintText: "ابحث باسم التصنيف...",
                        prefixIcon: const Icon(Icons.search, color: brandRed),
                        filled: true,
                        fillColor: brandRed.withOpacity(0.05),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          bool isSelected = currentId == filtered[i].id;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                                color: isSelected
                                    ? brandRed.withOpacity(0.1)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                  backgroundColor: isSelected
                                      ? brandRed
                                      : Colors.grey.shade300,
                                  radius: 5),
                              title: Text(filtered[i].name,
                                  style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w600)),
                              onTap: () {
                                onSelect(filtered[i]);
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAddStoreCategoryDialog() {
    final TextEditingController catCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("إضافة قسم جديد لمتجري",
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: brandRed)),
          content: TextField(
            controller: catCtrl,
            autofocus: true,
            style: const TextStyle(fontFamily: 'Cairo'),
            decoration: InputDecoration(
              hintText: "اسم القسم (مثلاً: حلويات)...",
              prefixIcon: const Icon(Icons.folder_open, color: brandRed),
              filled: true,
              fillColor: brandRed.withOpacity(0.05),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("إلغاء",
                    style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: brandRed,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  if (catCtrl.text.isNotEmpty) {
                    setState(() {
                      _myStoreCategories.add(catCtrl.text);
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text("تأكيد",
                    style:
                        TextStyle(color: Colors.white, fontFamily: 'Cairo'))),
          ],
        ),
      ),
    );
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
          backgroundColor: brandRed,
          title: const Text("إدارة المتجر",
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          centerTitle: true,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
              onPressed: () => context.pop()),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: brandRed))
            : !_isSubscriptionActive
                ? _buildSubscriptionRequired()
                : Column(
                    children: [
                      // ✅ الكرتان العلويتان
                      _buildTopCards(isDark),

                      // ✅ شريط الفلترة — يظهر فقط في تبويب المنتجات
                      if (_currentView == "المنتجات") _buildFilterTabs(isDark),

                      // ✅ شريط عدد المنتجات — يظهر فقط في تبويب المنتجات
                      if (_currentView == "المنتجات")
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _productsList.length >= _productLimit
                                ? Colors.red.withOpacity(0.08)
                                : brandRed.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _productsList.length >= _productLimit
                                  ? Colors.red.withOpacity(0.3)
                                  : brandRed.withOpacity(0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                color: _productsList.length >= _productLimit
                                    ? Colors.red
                                    : brandRed,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "المنتجات: ${_productsList.length} / $_productLimit",
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _productsList.length >= _productLimit
                                      ? Colors.red
                                      : brandRed,
                                ),
                              ),
                              if (_productsList.length >= _productLimit) ...[
                                const Spacer(),
                                const Text(
                                  "وصلت للحد الأقصى",
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11,
                                      color: Colors.red),
                                ),
                              ],
                            ],
                          ),
                        ),

                      Expanded(
                        child: _currentView == "المنتجات"
                            ? _buildProductsList(
                                _productsList
                                    .where((p) =>
                                        _selectedStoreCategory == "الكل" ||
                                        p.storeCategory ==
                                            _selectedStoreCategory)
                                    .toList(),
                                isDark)
                            : _buildCategoriesView(),
                      ),
                    ],
                  ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            if (_currentView == "المنتجات") {
              if (_productsList.length >= _productLimit) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "وصلت للحد الأقصى ($_productLimit منتج). رقّ باقتك لإضافة المزيد.",
                      style: const TextStyle(fontFamily: 'Cairo'),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (_myStoreCategories.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "يجب إضافة قسم لمتجرك أولاً قبل إضافة منتجات",
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                // ✅ ننتقل لتبويب الأقسام تلقائياً
                setState(() => _currentView = "الأقسام");
                return;
              }
              _showAddProductForm(isDark);
            } else {
              _showAddStoreCategoryDialog();
            }
          },
          backgroundColor: brandRed,
          icon: Icon(
              _currentView == "المنتجات"
                  ? Icons.add_shopping_cart
                  : Icons.create_new_folder,
              color: Colors.white),
          label: Text(_currentView == "المنتجات" ? "إضافة منتج" : "إضافة قسم",
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildSubscriptionRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: brandRed.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  size: 60, color: brandRed),
            ),
            const SizedBox(height: 24),
            const Text(
              "منتجاتك موقوفة مؤقتاً",
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              "لا يمكن عرض أو إدارة المنتجات بدون اشتراك فعّال. فعّل باقتك لتظهر منتجاتك للعملاء.",
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: brandRed,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.card_membership_rounded,
                  color: Colors.white),
              label: const Text("تفعيل الباقة",
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MerchantSubscriptionsPage()),
              ).then((_) => _fetchInitialData()),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ الكرتان العلويتان
  Widget _buildTopCards(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _buildTopCard(
              title: "المنتجات",
              icon: Icons.inventory_2_rounded,
              count: _productsList.length,
              isActive: _currentView == "المنتجات",
              isDark: isDark,
              onTap: () => setState(() => _currentView = "المنتجات"),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTopCard(
              title: "أقسام المتجر",
              icon: Icons.folder_special_rounded,
              count: _myStoreCategories.length,
              isActive: _currentView == "الأقسام",
              isDark: isDark,
              onTap: () => setState(() => _currentView = "الأقسام"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCard({
    required String title,
    required IconData icon,
    required int count,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive
              ? brandRed
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? brandRed.withOpacity(0.3)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isActive ? brandRed : Colors.grey.withOpacity(0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : brandRed,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isActive
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  Text(
                    "$count عنصر",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: isActive ? Colors.white70 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ شريط فلترة الأقسام داخل تبويب المنتجات
  Widget _buildFilterTabs(bool isDark) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterTab("الكل", isDark),
          ..._myStoreCategories
              .map((cat) => _buildFilterTab(cat, isDark))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String title, bool isDark) {
    bool isSelected = _selectedStoreCategory == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedStoreCategory = title),
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color:
              isSelected ? brandRed : (isDark ? Colors.white10 : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: isSelected ? brandRed : Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsList(List<ProductItem> filteredProducts, bool isDark) {
    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 60, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 12),
            const Text("لا توجد منتجات في هذا القسم حالياً",
                style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) =>
          _buildProductItem(filteredProducts[index], isDark),
    );
  }

  Widget _buildProductItem(ProductItem product, bool isDark) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                product.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.broken_image,
                    size: 40,
                    color: Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      PriceWidget(
                        price: product.price,
                        fontSize: 15,
                        color: const Color(0xFF4CAF50),
                      ),
                      if (product.oldPrice != null) ...[
                        const SizedBox(width: 8),
                        PriceWidget(
                          price: product.price,
                          fontSize: 15,
                          color: const Color(0xFF4CAF50),
                        ),
                      ],
                    ],
                  ),
                  if (product.storeCategory.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        product.storeCategory,
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.blue,
                            fontFamily: 'Cairo'),
                      ),
                    ),
                  if (product.isFlashSale)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: brandRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        "عروض 24 ساعة 🔥",
                        style: TextStyle(
                            fontSize: 10,
                            color: brandRed,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              children: [
                Switch(
                  value: product.isAvailable,
                  activeColor: brandRed,
                  onChanged: (val) async {
                    await supabase
                        .from('products')
                        .update({'is_available': val}).eq('id', product.id);
                    _fetchProducts();
                  },
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.edit,
                            color: Colors.blue, size: 20),
                        onPressed: () => _showAddProductForm(isDark,
                            productToEdit: product)),
                    IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: brandRed, size: 20),
                        onPressed: () => _confirmDelete(product)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(ProductItem product) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("حذف المنتج",
              style:
                  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: Text(
              "هل أنت متأكد من رغبتك في حذف '${product.name}'؟ لا يمكن التراجع عن هذه العملية.",
              style: const TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("إلغاء",
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteProduct(product.id);
                },
                child: const Text("حذف الآن",
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        color: brandRed,
                        fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesView() {
    if (_myStoreCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_outlined,
                size: 60, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 12),
            const Text("لم تضف أقساماً لمتجرك بعد",
                style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            const SizedBox(height: 8),
            const Text("اضغط على زر إضافة قسم في الأسفل",
                style: TextStyle(
                    fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _myStoreCategories.length,
        itemBuilder: (context, index) {
          final catName = _myStoreCategories[index];
          final productCount =
              _productsList.where((p) => p.storeCategory == catName).length;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: brandRed.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.folder_special_rounded,
                    color: brandRed, size: 20),
              ),
              title: Text(catName,
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              subtitle: Text("$productCount منتج",
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontSize: 11, color: Colors.grey)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.grey, size: 20),
                onPressed: () {
                  setState(() => _myStoreCategories.removeAt(index));
                },
              ),
            ),
          );
        });
  }

  void _showAddProductForm(bool isDark, {ProductItem? productToEdit}) {
    final nameController =
        TextEditingController(text: productToEdit?.name ?? "");
    final oldPriceController =
        TextEditingController(text: productToEdit?.oldPrice?.toString() ?? "");
    final priceController =
        TextEditingController(text: productToEdit?.price.toString() ?? "");
    final discountInputController = TextEditingController();
    final urlController =
        TextEditingController(text: productToEdit?.productUrl ?? "");
    final descController =
        TextEditingController(text: productToEdit?.description ?? "");

    String? selectedCategoryId = productToEdit?.categoryId;
    String selectedCategoryName = _allSubCategories
            .any((c) => c.id == selectedCategoryId)
        ? _allSubCategories.firstWhere((c) => c.id == selectedCategoryId).name
        : "اضغط لاختيار التصنيف المعتمد...";

    String? storeCategoryValue = productToEdit?.storeCategory;

    XFile? pickedImage;
    bool isSaving = false;
    String discountType = "fixed";
    bool showError = false;

    bool isFlashSale = productToEdit?.isFlashSale ?? false;
    DateTime? flashSaleExpiry = productToEdit?.flashSaleExpiry;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          void calculateNewPrice() {
            double original = double.tryParse(oldPriceController.text) ?? 0;
            if (discountType == "percent") {
              double percent =
                  double.tryParse(discountInputController.text) ?? 0;
              double calculated = original - (original * (percent / 100));
              priceController.text =
                  calculated > 0 ? calculated.toStringAsFixed(2) : "0.00";
            }
          }

          return Container(
            decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30))),
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 24,
                right: 24,
                top: 20),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text("بيانات المنتج",
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final img = await _picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1024,
                      imageQuality: 80,
                    );
                    if (img != null) setModalState(() => pickedImage = img);
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: (showError &&
                                pickedImage == null &&
                                productToEdit == null)
                            ? Border.all(color: Colors.red, width: 2)
                            : null,
                        borderRadius: BorderRadius.circular(15)),
                    child: pickedImage != null
                        ? const Icon(Icons.check_circle,
                            color: Colors.green, size: 50)
                        : (productToEdit != null
                            ? Image.network(productToEdit.imageUrl,
                                fit: BoxFit.contain)
                            : const Icon(Icons.add_a_photo,
                                color: Colors.grey)),
                  ),
                ),
                const SizedBox(height: 10),
                _buildInput(nameController, "اسم المنتج", Icons.shopping_bag,
                    isDark, showError),
                _buildInputMultiline(
                    descController, "وصف المنتج", Icons.description, isDark),
                const SizedBox(height: 10),
                const Text(
                  "* القسم الداخلي للمتجر (إلزامي)",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: brandRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: (storeCategoryValue != null &&
                          _myStoreCategories.contains(storeCategoryValue))
                      ? storeCategoryValue
                      : null,
                  isExpanded: true,
                  dropdownColor:
                      isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  items: _myStoreCategories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category,
                          style: const TextStyle(
                              fontFamily: 'Cairo', fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) =>
                      setModalState(() => storeCategoryValue = newValue),
                  decoration: InputDecoration(
                    prefixIcon:
                        const Icon(Icons.storefront, color: brandRed, size: 20),
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        color: (showError && storeCategoryValue == null)
                            ? Colors.red
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  hint: const Text("اختر القسم الداخلي للمتجر",
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                ),
                const SizedBox(height: 10),
                InkWell(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onTap: () =>
                      _showCategorySearchDialog(selectedCategoryId, (cat) {
                    setModalState(() {
                      selectedCategoryId = cat.id;
                      selectedCategoryName = cat.name;
                    });
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: brandRed.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: (showError && selectedCategoryId == null)
                            ? Colors.red.shade700
                            : brandRed.withOpacity(0.1),
                        width:
                            (showError && selectedCategoryId == null) ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.category, color: brandRed, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedCategoryName,
                            style: const TextStyle(
                                fontFamily: 'Cairo', fontSize: 14),
                          ),
                        ),
                        const Icon(Icons.search, color: brandRed, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: brandRed.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: brandRed.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.bolt, color: brandRed),
                              SizedBox(width: 8),
                              Text("عروض 24 ساعة 🔥",
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                      color: brandRed)),
                            ],
                          ),
                          Switch(
                            value: isFlashSale,
                            activeColor: brandRed,
                            onChanged: (val) {
                              setModalState(() {
                                isFlashSale = val;
                                if (val && flashSaleExpiry == null) {
                                  flashSaleExpiry = DateTime.now()
                                      .add(const Duration(hours: 24));
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      if (isFlashSale) ...[
                        const Divider(),
                        InkWell(
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: flashSaleExpiry ??
                                  DateTime.now().add(const Duration(hours: 24)),
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 30)),
                            );
                            if (picked != null) {
                              final TimeOfDay? time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(
                                    flashSaleExpiry ?? DateTime.now()),
                              );
                              if (time != null) {
                                setModalState(() {
                                  flashSaleExpiry = DateTime(
                                      picked.year,
                                      picked.month,
                                      picked.day,
                                      time.hour,
                                      time.minute);
                                });
                              }
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_filled,
                                    color: brandRed, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  flashSaleExpiry == null
                                      ? "حدد وقت انتهاء العرض"
                                      : intl.DateFormat('yyyy/MM/dd HH:mm')
                                          .format(flashSaleExpiry!),
                                  style: const TextStyle(
                                      fontFamily: 'Cairo', fontSize: 13),
                                ),
                                const Spacer(),
                                const Icon(Icons.edit_calendar,
                                    size: 18, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                  const Text("نوع الخصم: ",
                      style: TextStyle(
                          fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  ChoiceChip(
                      label: const Text("مبلغ ثابت"),
                      selected: discountType == "fixed",
                      onSelected: (val) => setModalState(() {
                            discountType = "fixed";
                            discountInputController.clear();
                          })),
                  const SizedBox(width: 8),
                  ChoiceChip(
                      label: const Text("نسبة %"),
                      selected: discountType == "percent",
                      onSelected: (val) =>
                          setModalState(() => discountType = "percent")),
                  if (discountType == "percent") ...[
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextField(
                            controller: discountInputController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) =>
                                setModalState(() => calculateNewPrice()),
                            decoration: InputDecoration(
                                hintText: "%",
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8))))),
                  ]
                ]),
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                      child: _buildInput(oldPriceController, "السعر الأصلي",
                          Icons.history, isDark, showError,
                          isNumber: true,
                          onChanged: (_) => calculateNewPrice())),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _buildInput(priceController, "السعر الجديد",
                          Icons.auto_fix_high, isDark, showError,
                          isNumber: true, readOnly: discountType == "percent")),
                ]),
                _buildInput(urlController, "رابط المنتج (متجر خارجي)",
                    Icons.link, isDark, showError),
                const SizedBox(height: 10),
                SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: brandRed,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15))),
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (nameController.text.isEmpty ||
                                  priceController.text.isEmpty ||
                                  selectedCategoryId == null ||
                                  storeCategoryValue == null ||
                                  (pickedImage == null &&
                                      productToEdit == null)) {
                                setModalState(() => showError = true);
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text("يرجى إكمال البيانات ورفع صورة"),
                                    backgroundColor: brandRed,
                                  ),
                                );
                                return;
                              }
                              setModalState(() => isSaving = true);
                              String finalUrl = productToEdit?.imageUrl ?? "";
                              if (pickedImage != null) {
                                final newUrl = await _uploadImage(pickedImage!);
                                if (newUrl != null)
                                  finalUrl = newUrl;
                                else {
                                  setModalState(() => isSaving = false);
                                  return;
                                }
                              }
                              await _upsertProduct(
                                  ProductItem(
                                    id: productToEdit?.id ?? "",
                                    name: nameController.text,
                                    categoryId: selectedCategoryId!,
                                    storeCategory: storeCategoryValue ?? "عام",
                                    price:
                                        double.tryParse(priceController.text) ??
                                            0,
                                    oldPrice: double.tryParse(
                                        oldPriceController.text),
                                    description: descController.text,
                                    isAvailable:
                                        productToEdit?.isAvailable ?? true,
                                    imageUrl: finalUrl,
                                    productUrl: urlController.text,
                                    isFlashSale: isFlashSale,
                                    flashSaleExpiry: flashSaleExpiry,
                                  ),
                                  isUpdate: productToEdit != null);
                              if (mounted) Navigator.pop(sheetContext);
                            },
                      child: isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("حفظ المنتج",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo')),
                    )),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputMultiline(TextEditingController ctrl, String hint,
          IconData icon, bool isDark) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctrl,
          maxLines: 5,
          minLines: 3,
          style: TextStyle(
              color: isDark ? Colors.white : Colors.black, height: 1.6),
          decoration: InputDecoration(
            labelText: hint,
            labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
            alignLabelWithHint: true,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: Icon(icon, color: brandRed, size: 20),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.shade400)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: brandRed, width: 2)),
          ),
        ),
      );
  Widget _buildInput(TextEditingController ctrl, String hint, IconData icon,
          bool isDark, bool showError,
          {bool isNumber = false,
          bool readOnly = false,
          Function(String)? onChanged}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctrl,
          onChanged: onChanged,
          readOnly: readOnly,
          keyboardType: isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            labelText: hint,
            labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
            fillColor: readOnly ? Colors.grey.withOpacity(0.1) : null,
            filled: readOnly,
            prefixIcon: Icon(icon, color: brandRed, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            enabledBorder: (showError && ctrl.text.isEmpty)
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Colors.red, width: 2))
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey.shade400)),
            focusedBorder: (showError && ctrl.text.isEmpty)
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Colors.red, width: 2))
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: brandRed, width: 2)),
          ),
        ),
      );

  Widget _buildProductImage(ProductItem product, bool isDark) => ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Container(
          width: 75,
          height: 75,
          color: isDark ? Colors.black26 : Colors.grey.shade100,
          child: (product.imageUrl.isEmpty || product.imageUrl == 'null')
              ? const Icon(Icons.image_not_supported, color: Colors.grey)
              : Image.network(
                  product.imageUrl,
                  fit: BoxFit.cover,
                  key: ValueKey(product.imageUrl),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2));
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.image_not_supported, color: Colors.grey),
                )));
}

class CategorySelectionPage extends StatefulWidget {
  final List<CategoryItem> mainCategories;
  final List<CategoryItem> allSubCategories;

  const CategorySelectionPage(
      {super.key,
      required this.mainCategories,
      required this.allSubCategories});

  @override
  State<CategorySelectionPage> createState() => _CategorySelectionPageState();
}

class _CategorySelectionPageState extends State<CategorySelectionPage> {
  String? selectedStoreId;

  @override
  Widget build(BuildContext context) {
    final List<CategoryItem> currentList;
    if (selectedStoreId == null) {
      currentList = widget.mainCategories;
    } else {
      currentList = widget.allSubCategories
          .where(
              (s) => s.storeCategoryId.toString() == selectedStoreId.toString())
          .toList();
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(selectedStoreId == null
              ? "اختر قسم المتجر"
              : "اختر القسم الفرعي"),
          backgroundColor: brandRed,
          leading: selectedStoreId != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => selectedStoreId = null))
              : null,
        ),
        body: ListView.separated(
          itemCount: currentList.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final item = currentList[i];
            return ListTile(
              title:
                  Text(item.name, style: const TextStyle(fontFamily: 'Cairo')),
              trailing: Icon(
                  selectedStoreId == null
                      ? Icons.arrow_forward_ios
                      : Icons.check,
                  size: 16),
              onTap: () {
                if (selectedStoreId == null) {
                  setState(() {
                    selectedStoreId = item.id;
                  });
                } else {
                  Navigator.pop(context, item);
                }
              },
            );
          },
        ),
      ),
    );
  }
}
