from pathlib import Path

p = Path("lib/main.dart")
s = p.read_text(encoding="utf-8")

old = """class AccountSwitcherPage extends StatefulWidget {
  const AccountSwitcherPage({super.key});

  @override
  State<AccountSwitcherPage> createState() => _AccountSwitcherPageState();
}"""
new = """class AccountSwitcherPage extends StatefulWidget {
  final bool autoAdd;

  const AccountSwitcherPage({super.key, this.autoAdd = false});

  @override
  State<AccountSwitcherPage> createState() => _AccountSwitcherPageState();
}"""
if old not in s:
    raise SystemExit("AccountSwitcherPage declaration not found")
s = s.replace(old, new, 1)

old = """  @override
  void initState() {
    super.initState();
    _load();
  }"""
new = """  @override
  void initState() {
    super.initState();
    _load();
    if (widget.autoAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addAccount();
      });
    }
  }"""
if old not in s:
    raise SystemExit("AccountSwitcher initState not found")
s = s.replace(old, new, 1)

old = """        actions: [
          IconButton(
            tooltip: 'ویرایش پروفایل',
            icon: const Icon(Icons.edit_rounded),"""
new = """        actions: [
          IconButton(
            tooltip: 'تغییر یا افزودن حساب',
            icon: const Icon(Icons.manage_accounts_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountSwitcherPage()),
            ),
          ),
          IconButton(
            tooltip: 'ویرایش پروفایل',
            icon: const Icon(Icons.edit_rounded),"""
if old not in s:
    raise SystemExit("Profile AppBar actions not found")
s = s.replace(old, new, 1)

old = """          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSetupPage()));
              await load();
            },
            icon: const Icon(Icons.edit_rounded),
            label: const Text('ویرایش نام، نمایه و بیو'),
          ),
          const SizedBox(height: 24),          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.swap_horiz_rounded)),
              title: const Text('تغییر حساب', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('تا ۳ حساب را روی این دستگاه مدیریت و جابه‌جا کنید'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSwitcherPage())),
            ),
          ),"""
new = """          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSetupPage()));
              await load();
            },
            icon: const Icon(Icons.edit_rounded),
            label: const Text('ویرایش نام، نمایه و بیو'),
          ),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('حساب‌ها', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(
                    'تا ۳ حساب را روی این دستگاه نگه دارید و هر زمان خواستید با کد ۶ رقمی بین آن‌ها جابه‌جا شوید.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AccountSwitcherPage()),
                          ),
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: const Text('تغییر حساب'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AccountSwitcherPage(autoAdd: true)),
                          ),
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('افزودن حساب'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),"""
if old not in s:
    raise SystemExit("Profile account card not found")
s = s.replace(old, new, 1)

p.write_text(s, encoding="utf-8")
print("profile/account UI patched")
