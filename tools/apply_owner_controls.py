from pathlib import Path


def replace_once(path: str, old: str, new: str) -> bool:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    if new in text:
        return False
    if old not in text:
        raise SystemExit(f'pattern not found in {path}: {old[:100]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')
    return True


changed = False
changed |= replace_once(
    'lib/profile_page.dart',
    "import 'main.dart';\n",
    "import 'main.dart';\nimport 'owner_admin_page.dart';\n",
)
changed |= replace_once(
    'lib/profile_page.dart',
    "const VerificationAdminPage()",
    "const OwnerAdminPage()",
)

main_path = Path('lib/main.dart')
main = main_path.read_text(encoding='utf-8')
if 'class AppBanGate extends StatelessWidget' not in main:
    marker = "class ProfileGate extends StatelessWidget {"
    gate = '''class AppBanGate extends StatelessWidget {\n  const AppBanGate({super.key});\n\n  Future<bool> isBanned() async {\n    final user = supabase.auth.currentUser;\n    if (user == null) return false;\n    try {\n      final result = await supabase.rpc('is_current_user_app_banned');\n      return result == true;\n    } catch (_) {\n      return false;\n    }\n  }\n\n  @override\n  Widget build(BuildContext context) {\n    return FutureBuilder<bool>(\n      future: isBanned(),\n      builder: (context, snapshot) {\n        if (!snapshot.hasData) {\n          return const Scaffold(body: Center(child: CircularProgressIndicator()));\n        }\n        if (snapshot.data == true) return const AppBannedPage();\n        return const ProfileGate();\n      },\n    );\n  }\n}\n\nclass AppBannedPage extends StatelessWidget {\n  const AppBannedPage({super.key});\n\n  Future<void> signOut(BuildContext context) async {\n    await supabase.auth.signOut();\n    if (context.mounted) {\n      Navigator.of(context).pushAndRemoveUntil(\n        MaterialPageRoute(builder: (_) => const LoginPage()),\n        (_) => false,\n      );\n    }\n  }\n\n  @override\n  Widget build(BuildContext context) {\n    final s = Theme.of(context).colorScheme;\n    return Scaffold(\n      body: Center(\n        child: Padding(\n          padding: const EdgeInsets.all(28),\n          child: Column(\n            mainAxisAlignment: MainAxisAlignment.center,\n            children: [\n              CircleAvatar(\n                radius: 42,\n                backgroundColor: s.errorContainer,\n                child: Icon(Icons.block_rounded, color: s.error, size: 42),\n              ),\n              const SizedBox(height: 20),\n              const Text(\n                'دسترسی این حساب به برنامه محروم شده است',\n                textAlign: TextAlign.center,\n                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),\n              ),\n              const SizedBox(height: 10),\n              const Text(\n                'اگر فکر می‌کنید این تصمیم اشتباه است، با پشتیبانی برنامه تماس بگیرید.',\n                textAlign: TextAlign.center,\n              ),\n              const SizedBox(height: 22),\n              FilledButton.icon(\n                onPressed: () => signOut(context),\n                icon: const Icon(Icons.logout_rounded),\n                label: const Text('خروج از حساب'),\n              ),\n            ],\n          ),\n        ),\n      ),\n    );\n  }\n}\n\n'''
    main = main.replace(marker, gate + marker, 1)
    main = main.replace('return const ProfileGate();', 'return const AppBanGate();', 1)
    main_path.write_text(main, encoding='utf-8')
    changed = True

print('owner controls changed:', changed)
