import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';
import '../../shell/dashboard_shell.dart';
import '../admin/categories_page.dart';
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

  Future<void> _login() async {
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
            items: const [
              NavItem('التصنيفات', Icons.category, AdminCategoriesScreen()),
              NavItem('العملاء', Icons.people, AdminAnalyticsUsersScreen()),
              NavItem('تصنيفات المتاجر', Icons.storefront, AdminAnalyticsMerchantCategoriesScreen()),
              NavItem('تصنيفات المنتجات', Icons.inventory_2, AdminAnalyticsProductCategoriesScreen()),
              NavItem('الإشعارات', Icons.notifications, AdminNotificationsScreen()),
              NavItem('أكواد الخصم', Icons.local_offer, DiscountCodesScreen()),
              NavItem('الإعدادات', Icons.settings, AdminSettingsScreen()),
            ],
          ),
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
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
