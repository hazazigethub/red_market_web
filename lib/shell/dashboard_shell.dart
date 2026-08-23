import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:red_market_core/red_market_core.dart';

class NavItem {
  final String label;
  final IconData icon;
  final Widget page;
  const NavItem(this.label, this.icon, this.page);
}

class DashboardShell extends StatefulWidget {
  final String role;
  final List<NavItem> items;
  const DashboardShell({super.key, required this.role, required this.items});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _index = 0;

  void goTo(String label) {
    final i = widget.items.indexWhere((e) => e.label == label);
    if (i >= 0) setState(() => _index = i);
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 1100;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _topBar(wide),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: DashboardNav(
                        goTo: goTo,
                        child: widget.items[_index].page,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

    );
  }

  Widget _sidebar() => Container(
        width: 250,
        color: Colors.white,
        child: _sidebarContent(),
      );

  Widget _sidebarContent() => Column(
        children: [
          Container(
            height: 70,
            alignment: Alignment.center,
            color: AppColors.brand,
            child: const Text('رد ماركت',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: widget.items.length,
              itemBuilder: (context, i) {
                final selected = i == _index;
                return ListTile(
                  leading: Icon(widget.items[i].icon,
                      color: selected ? AppColors.brand : Colors.grey[600], size: 22),
                  title: Text(widget.items[i].label,
                      style: TextStyle(
                          fontSize: 14,
                          color: selected ? AppColors.brand : Colors.grey[800],
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                  selected: selected,
                  selectedTileColor: AppColors.brand.withValues(alpha: 0.08),
                  onTap: () {
                    setState(() => _index = i);
                    if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red, size: 22),
            title: const Text('تسجيل الخروج',
                style: TextStyle(fontSize: 14, color: Colors.red)),
            onTap: _logout,
          ),
        ],
      );

  Widget _topBar(bool wide) => Container(
        height: 70,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            if (_index != 0)
              TextButton.icon(
                onPressed: () => setState(() => _index = 0),
                icon: const Icon(Icons.home, size: 18),
                label: const Text('الرئيسية'),
                style: TextButton.styleFrom(foregroundColor: AppColors.brand),
              ),
            const Spacer(),
          ],
        ),
      );
}


class DashboardNav extends InheritedWidget {
  final void Function(String label) goTo;
  const DashboardNav({super.key, required this.goTo, required super.child});

  static DashboardNav? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DashboardNav>();

  @override
  bool updateShouldNotify(DashboardNav oldWidget) => false;
}
