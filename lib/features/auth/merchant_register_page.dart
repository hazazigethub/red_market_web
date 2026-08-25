import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';

class MerchantRegisterPage extends StatefulWidget {
  const MerchantRegisterPage({super.key});

  @override
  State<MerchantRegisterPage> createState() => _MerchantRegisterPageState();
}

class _MerchantRegisterPageState extends State<MerchantRegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _ownerNameController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vatNumberController = TextEditingController();
  final _freelanceController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _crNumberController = TextEditingController();

  bool _isTermsAccepted = false;
  bool _isLoading = false;
  String? _selectedStoreCategory;
  Uint8List? _crImageBytes;
  String? _crImageName;
  String? _crImageMime;

  /// شهادة الضريبة — اختيارية
  Uint8List? _vatImageBytes;
  String? _vatImageName;
  String? _vatImageMime;

  /// نوع الوثيقة: سجل تجاري أو وثيقة عمل حر
  bool _isFreelance = false;

  final ImagePicker _picker = ImagePicker();
  late final Future<List<Map<String, dynamic>>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _loadCategories();
  }

  Future<List<Map<String, dynamic>>> _loadCategories() async {
    final v = await Supabase.instance.client
        .from('store_categories')
        .select('id, name');
    return List<Map<String, dynamic>>.from(v);
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _vatNumberController.dispose();
    _freelanceController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _crNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickCrImage() async {
    final img = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    if (!mounted) return;
    setState(() {
      _crImageBytes = bytes;
      _crImageName = img.name;
      _crImageMime = img.mimeType ?? 'image/jpeg';
    });
  }

  Future<void> _pickVatImage() async {
    final img = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    if (!mounted) return;
    setState(() {
      _vatImageBytes = bytes;
      _vatImageName = img.name;
      _vatImageMime = img.mimeType ?? 'image/jpeg';
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isTermsAccepted) {
      _showError('يرجى الموافقة على الشروط والأحكام أولاً');
      return;
    }
    if (_crImageBytes == null) {
      _showError(_isFreelance
          ? 'صورة وثيقة العمل الحر مطلوبة'
          : 'صورة السجل التجاري مطلوبة');
      return;
    }
    if (_selectedStoreCategory == null) {
      _showError('يرجى اختيار تصنيف المتجر');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('كلمات المرور غير متطابقة');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final String cleanPhone =
          _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
      final String techEmail = 'u$cleanPhone@redocean-official.com';
      final String password = _passwordController.text.trim();

      // 1) رفع صورة السجل التجاري
      final ext = (_crImageName ?? 'cr.jpg').split('.').last;
      final fileName =
          'cr_${cleanPhone}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await supabase.storage.from('merchants_docs').uploadBinary(
            fileName,
            _crImageBytes!,
            fileOptions: FileOptions(
                contentType: _crImageMime ?? 'image/jpeg', upsert: true),
          );
      final imageUrl =
          supabase.storage.from('merchants_docs').getPublicUrl(fileName);

      // رفع شهادة الضريبة إن أرفقها
      String? vatUrl;
      if (_vatImageBytes != null) {
        try {
          final vExt = (_vatImageName ?? 'vat.jpg').split('.').last;
          final vName =
              'vat_${cleanPhone}_${DateTime.now().millisecondsSinceEpoch}.$vExt';
          await supabase.storage.from('merchants_docs').uploadBinary(
                vName,
                _vatImageBytes!,
                fileOptions: FileOptions(
                    contentType: _vatImageMime ?? 'image/jpeg',
                    upsert: true),
              );
          vatUrl =
              supabase.storage.from('merchants_docs').getPublicUrl(vName);
        } catch (e) {
          debugPrint('VAT upload error: $e');
        }
      }

      // 2) إنشاء الحساب — الدور يُعيَّن من قاعدة البيانات
      final response = await supabase.auth.signUp(
        email: techEmail,
        password: password,
        data: {
          'role': 'merchant',
          'full_name': _ownerNameController.text.trim(),
        },
      );

      final user = response.user;
      if (user == null) throw 'تعذر إنشاء الحساب';

      int latestTermsVersion = 0;
      try {
        final termsData = await supabase
            .from('terms_content')
            .select('version')
            .eq('type', 'merchant')
            .maybeSingle();
        latestTermsVersion = (termsData?['version'] as num?)?.toInt() ?? 0;
      } catch (_) {}

      // 3) بيانات الملف الشخصي
      await supabase.from('profiles').upsert({
        'id': user.id,
        'full_name': _ownerNameController.text.trim(),
        'phone_number': cleanPhone,
        'email_contact': _emailController.text.trim(),
        'accepted_terms_version': latestTermsVersion,
      });

      // 4) بيانات المتجر
      await supabase.from('merchants').upsert({
        'id': user.id,
        'owner_id': user.id,
        'store_name': _nameController.text.trim(),
        'phone_number': cleanPhone,
        'email_contact': _emailController.text.trim(),
        'owner_name': _ownerNameController.text.trim(),
        'cr_number': _isFreelance ? null : _crNumberController.text.trim(),
        'freelance_license_number':
            _isFreelance ? _freelanceController.text.trim() : null,
        'vat_number': _vatNumberController.text.trim().isEmpty
            ? null
            : _vatNumberController.text.trim(),
        'vat_certificate_url': vatUrl,
        'cr_image_url': imageUrl,
        'store_category_id': _selectedStoreCategory,
        'is_subscription_active': false,
        'is_banned': false,
        'is_permanent_ban': false,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تم إنشاء حساب التاجر بنجاح — سجّل الدخول للمتابعة'),
            backgroundColor: Color(0xFF4CAF50)),
      );
      await supabase.auth.signOut();
      if (mounted) Navigator.of(context).pop();
    } on AuthException catch (e) {
      _showError('خطأ في التسجيل: ${e.message}');
    } catch (e) {
      _showError('حدث خطأ: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Container(
            width: 520,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('تسجيل متجر جديد',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brand)),
                  const SizedBox(height: 8),
                  const Text('انضم إلى رد ماركت واعرض منتجاتك',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 28),

                  _field(_ownerNameController, 'اسم المالك',
                      Icons.person_outline),
                  const SizedBox(height: 14),
                  _field(_nameController, 'اسم المتجر', Icons.storefront),
                  const SizedBox(height: 14),
                  _field(_phoneController, 'رقم الجوال', Icons.phone,
                      keyboard: TextInputType.phone),
                  const SizedBox(height: 14),
                  _field(_emailController, 'البريد الإلكتروني', Icons.email,
                      keyboard: TextInputType.emailAddress),
                  const SizedBox(height: 14),
                  // نوع الوثيقة
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F2F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _docTab('سجل تجاري', false),
                        _docTab('عمل حر', true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_isFreelance)
                    _field(_freelanceController, 'رقم وثيقة العمل الحر',
                        Icons.workspace_premium_outlined)
                  else
                    _field(_crNumberController, 'رقم السجل التجاري',
                        Icons.badge_outlined),
                  const SizedBox(height: 14),

                  // الرقم الضريبي — اختياري
                  TextFormField(
                    controller: _vatNumberController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الرقم الضريبي (اختياري)',
                      prefixIcon: Icon(Icons.receipt_long_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _categoriesFuture,
                    builder: (context, snap) {
                      final items = snap.data ?? const [];
                      return DropdownButtonFormField<String>(
                        initialValue: _selectedStoreCategory,
                        decoration: const InputDecoration(
                          labelText: 'تصنيف المتجر',
                          prefixIcon: Icon(Icons.category_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: items
                            .map((c) => DropdownMenuItem<String>(
                                  value: c['id'].toString(),
                                  child: Text(c['name']?.toString() ?? ''),
                                ))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedStoreCategory = val),
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  _field(_passwordController, 'كلمة المرور', Icons.lock,
                      obscure: true),
                  const SizedBox(height: 14),
                  _field(_confirmPasswordController, 'تأكيد كلمة المرور',
                      Icons.lock_outline,
                      obscure: true),
                  const SizedBox(height: 20),

                  OutlinedButton.icon(
                    onPressed: _pickCrImage,
                    icon: const Icon(Icons.upload_file),
                    label: Text(_crImageBytes == null
                        ? (_isFreelance
                            ? 'رفع صورة وثيقة العمل الحر'
                            : 'رفع صورة السجل التجاري')
                        : 'تم اختيار الصورة ✓'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: AppColors.brand,
                    ),
                  ),
                  if (_crImageBytes != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(_crImageBytes!,
                          height: 140, fit: BoxFit.cover),
                    ),
                  ],
                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: _pickVatImage,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(_vatImageBytes == null
                        ? 'رفع شهادة الضريبة (اختياري)'
                        : 'تم اختيار الشهادة ✓'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: Colors.grey.shade700,
                    ),
                  ),
                  if (_vatImageBytes != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(_vatImageBytes!,
                          height: 120, fit: BoxFit.cover),
                    ),
                  ],
                  const SizedBox(height: 12),

                  CheckboxListTile(
                    value: _isTermsAccepted,
                    onChanged: (v) =>
                        setState(() => _isTermsAccepted = v ?? false),
                    title: const Text('أوافق على الشروط والأحكام',
                        style: TextStyle(fontSize: 14)),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.brand,
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('إنشاء الحساب',
                              style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('لديك حساب؟ سجّل الدخول'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _docTab(String label, bool freelance) {
    final on = _isFreelance == freelance;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isFreelance = freelance),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppColors.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: on ? FontWeight.bold : FontWeight.normal,
              color: on ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {bool obscure = false, TextInputType? keyboard}) {
    return TextFormField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
    );
  }
}
