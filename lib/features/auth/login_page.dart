import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';
import '../../shell/dashboard_shell.dart';
import 'merchant_register_page.dart';
import '../admin/categories_page.dart';
import '../admin/admin_home_page.dart';
import '../admin/new_merchants_screen.dart';
import '../admin/admin_banners_screen.dart';
import '../admin/admin_announcements_screen.dart';
import '../merchant/merchant_home_page.dart';
import '../merchant/manage_reels_page.dart';
import '../merchant/products_page.dart';
import '../merchant/review_reels_page.dart';
import '../merchant/reviews_page.dart';
import '../merchant/merchant_reports_page.dart';
import '../merchant/merchant_subscriptions_page.dart';
import '../merchant/store_preview_page.dart';
import '../merchant/notifications_page.dart' as merchant_notif;
import '../merchant/useful_links_page.dart';
import '../merchant/store_settings_page.dart';
import '../merchant/merchant_bank_account_page.dart';
import '../admin/admin_analytics_visits_screen.dart';
import '../admin/admin_customer_screen.dart';
import '../admin/admin_products_screen.dart';
import '../admin/admin_merchants_screen.dart';
import '../admin/admin_analytics_merchants_screen.dart';
import '../admin/admin_analytics_products_screen.dart';
import '../admin/admin_reports_screen.dart';
import '../admin/admin_settings_screen.dart';
import '../admin/admin_notifications_screen.dart';
import '../admin/discount_codes_screen.dart';
import '../admin/maintenance_screen.dart';
import '../admin/admin_analytics_customer_screen.dart';
import '../admin/admin_analytics_merchant_categories_screen.dart';
import '../admin/admin_analytics_product_categories_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  /// يحوّل رسائل الخطأ الإنجليزية إلى العربية
  String _arabicError(Object e) {
    if (e is AuthException) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login')) {
        return 'رقم الجوال أو كلمة المرور غير صحيحة';
      }
      if (msg.contains('email not confirmed')) {
        return 'لم يتم تأكيد الحساب بعد';
      }
      if (msg.contains('too many') || msg.contains('rate limit')) {
        return 'محاولات كثيرة، انتظر قليلاً ثم حاول مجدداً';
      }
      if (msg.contains('user not found')) {
        return 'لا يوجد حساب بهذا الرقم';
      }
      return 'تعذر تسجيل الدخول، حاول مجدداً';
    }

    final text = e.toString();
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('ClientException')) {
      return 'تعذر الاتصال، تحقق من الشبكة';
    }

    // رسائلنا العربية تمر كما هي
    return text.replaceAll('Exception: ', '');
  }

  Future<void> _login() async {
    if (_phone.text.trim().isEmpty || _password.text.trim().isEmpty) {
      setState(() => _error = 'يرجى إدخال رقم الجوال وكلمة المرور');
      return;
    }

    setState(() { _loading = true; _error = null; });
    final supabase = Supabase.instance.client;
    try {
      final clean = _phone.text.trim().replaceAll(RegExp(r'\D'), '');
      final email = 'u$clean@redocean-official.com';
      final res = await supabase.auth.signInWithPassword(
        email: email, password: _password.text.trim());

      final uid = res.user?.id;
      if (uid == null) throw 'تعذر تسجيل الدخول';

      final profile = await supabase
          .from('profiles').select('role').eq('id', uid).maybeSingle();
      final role = profile?['role']?.toString();

      if (role != 'super_admin' && role != 'merchant') {
        await supabase.auth.signOut();
        throw 'هذه اللوحة مخصصة للتجار والإدارة فقط';
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => DashboardShell(
            role: role!,
            items: role == 'merchant'
                ? const [
                    NavItem('الرئيسية', Icons.dashboard, MerchantHomePage()),
                    NavItem('منتجاتي', Icons.inventory_2, ProductsPage()),
                    NavItem('الريلز', Icons.video_library, ManageReelsPage()),
                    NavItem('التقييمات', Icons.star, ReviewsPage()),
                    NavItem('التقارير', Icons.bar_chart, MerchantReportsPage()),
                    NavItem('الاشتراكات', Icons.card_membership, MerchantSubscriptionsPage()),
                    NavItem('الإشعارات', Icons.notifications, merchant_notif.NotificationsPage()),
                    NavItem('إعدادات المتجر', Icons.settings, StoreSettingsPage()),
                    NavItem('الحساب البنكي', Icons.account_balance, MerchantBankAccountPage()),
                    NavItem('روابط مفيدة', Icons.link, UsefulLinksPage()),
                  ]
                : const [
              NavItem('الرئيسية', Icons.dashboard, AdminHomePage()),
              NavItem('التصنيفات', Icons.category, AdminCategoriesScreen()),
              NavItem('إدارة العملاء', Icons.people, AdminUsersScreen()),
              NavItem('إدارة التجار', Icons.storefront, AdminMerchantsScreen()),
              NavItem('التجار الجدد', Icons.fiber_new_outlined, NewMerchantsScreen()),
              NavItem('إدارة المنتجات', Icons.inventory, AdminProductsScreen()),
              NavItem('تحليلات العملاء', Icons.analytics, AdminAnalyticsUsersScreen()),
              NavItem('تصنيفات المتاجر', Icons.storefront, AdminAnalyticsMerchantCategoriesScreen()),
              NavItem('تصنيفات المنتجات', Icons.inventory_2, AdminAnalyticsProductCategoriesScreen()),
              NavItem('الإشعارات', Icons.notifications, AdminNotificationsScreen()),
              NavItem('أكواد الخصم', Icons.local_offer, DiscountCodesScreen()),
              NavItem('التجار', Icons.store, AdminAnalyticsMerchantsScreen()),
              NavItem('المنتجات', Icons.shopping_bag, AdminAnalyticsProductsScreen()),
              NavItem('البلاغات', Icons.flag, AdminReportsScreen()),
              NavItem('الزيارات', Icons.trending_up, AdminAnalyticsVisitsScreen()),
              NavItem('البنرات', Icons.ad_units, AdminBannersScreen()),
              NavItem('الإعلانات', Icons.campaign, AdminAnnouncementsScreen()),
              NavItem('الإعدادات', Icons.settings, AdminSettingsScreen()),
            ],
          ),
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _error = _arabicError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('رد ماركت',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold,
                    color: AppColors.brand)),
                const SizedBox(height: 8),
                const Text('لوحة التحكم', style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 32),
                TextField(
                  controller: _phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الجوال', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white),
                    child: _loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('دخول', style: TextStyle(fontSize: 16)),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const MerchantRegisterPage())),
                  child: const Text('تسجيل متجر جديد'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
