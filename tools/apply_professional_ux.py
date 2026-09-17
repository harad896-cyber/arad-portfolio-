from pathlib import Path

ROOT = Path('.')

# 1) Persistent per-account background color and profile entry.
main = ROOT / 'lib/main.dart'
s = main.read_text(encoding='utf-8')
if "import 'chat_background_page.dart';" not in s:
    s = s.replace("import 'profile_page.dart';", "import 'profile_page.dart';\nimport 'chat_background_page.dart';", 1)
if 'int backgroundSeed = 0xFFF5F5F7;' not in s:
    s = s.replace('  int seed = 0xFF7C5CFF;\n', '  int seed = 0xFF7C5CFF;\n  int backgroundSeed = 0xFFF5F5F7;\n', 1)
    s = s.replace("    seed = p.getInt('accent_seed_$key') ?? 0xFF7C5CFF;", "    seed = p.getInt('accent_seed_$key') ?? 0xFF7C5CFF;\n    backgroundSeed = p.getInt('chat_background_seed_$key') ?? 0xFFF5F5F7;", 1)
    marker = "  Future<void> setSeed(int value) async {"
    method = "  Future<void> setBackgroundSeed(int value) async {\n    backgroundSeed = value;\n    final p = await SharedPreferences.getInstance();\n    await p.setInt('chat_background_seed_$_scope', value);\n    notifyListeners();\n  }\n"
    s = s.replace(marker, method + marker, 1)
# Make the existing premium app background respond to the selected background without changing navigation or message logic.
s = s.replace('Color(0x247C5CFF),\n              Theme.of(context).scaffoldBackgroundColor,', 'Color(appTheme.backgroundSeed).withValues(alpha: .30),\n              Theme.of(context).scaffoldBackgroundColor,', 1)
main.write_text(s, encoding='utf-8')

# 2) Expose the picker from the user's profile.
profile = ROOT / 'lib/profile_page.dart'
p = profile.read_text(encoding='utf-8')
if "import 'chat_background_page.dart';" not in p:
    p = p.replace("import 'owner_admin_page.dart';", "import 'owner_admin_page.dart';\nimport 'chat_background_page.dart';", 1)
needle = "          ListTile(\n            leading: CircleAvatar(backgroundColor: s.primaryContainer, child: Icon(Icons.bookmark_rounded, color: s.primary)),"
if "پس‌زمینه چت" not in p and needle in p:
    tile = "          ListTile(\n            leading: CircleAvatar(backgroundColor: s.primaryContainer, child: Icon(Icons.palette_rounded, color: s.primary)),\n            title: const Text('پس‌زمینه چت', style: TextStyle(fontWeight: FontWeight.w800)),\n            subtitle: const Text('رنگ پس‌زمینه برای همین حساب روی این دستگاه'),\n            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatBackgroundPage())),\n          ),\n          const Divider(height: 1),\n"
    p = p.replace(needle, tile + needle, 1)
profile.write_text(p, encoding='utf-8')

# 3) Add real member selection to the group profile, backed by an RPC instead of a UI-only insert.
group = ROOT / 'lib/group_management.dart'
g = group.read_text(encoding='utf-8')
if 'Future<void> addMembers() async' not in g:
    anchor = "  Future<void> removeMember(String id) async {"
    method = r'''  Future<void> addMembers() async {
    if (!admin || busy) return;
    final search = TextEditingController();
    final selected = <String>{};
    try {
      final added = await showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheet) {
          List<Map<String, dynamic>> results = [];
          bool loadingUsers = false;
          return StatefulBuilder(builder: (sheet, setSheet) {
            Future<void> findUsers(String q) async {
              final term = q.trim();
              if (term.length < 2) { setSheet(() => results = []); return; }
              setSheet(() => loadingUsers = true);
              try {
                final rows = await db.from('profiles').select('id,display_name,username,avatar_url,is_verified').or('display_name.ilike.%$term%,username.ilike.%$term%').limit(30);
                final existing = members.map((m) => m['user_id'].toString()).toSet();
                setSheet(() => results = List<Map<String, dynamic>>.from(rows).where((r) => !existing.contains(r['id'].toString())).toList());
              } catch (_) { setSheet(() => results = []); }
              finally { if (sheet.mounted) setSheet(() => loadingUsers = false); }
            }
            return SafeArea(child: Padding(
              padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.viewInsetsOf(sheet).bottom + 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('افزودن اعضا', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                TextField(controller: search, autofocus: true, onChanged: findUsers, decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'نام یا آیدی کاربر')),
                const SizedBox(height: 8),
                if (loadingUsers) const LinearProgressIndicator(minHeight: 2),
                ConstrainedBox(constraints: const BoxConstraints(maxHeight: 360), child: ListView(shrinkWrap: true, children: results.map((u) {
                  final id = u['id'].toString(); final checked = selected.contains(id); final avatar = (u['avatar_url'] ?? '').toString();
                  return CheckboxListTile(value: checked, onChanged: (_) => setSheet(() => checked ? selected.remove(id) : selected.add(id)),
                    secondary: CircleAvatar(backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null, child: avatar.isEmpty ? const Icon(Icons.person) : null),
                    title: Text((u['display_name'] ?? u['username'] ?? 'کاربر').toString()), subtitle: Text((u['username'] ?? '').toString().isEmpty ? '' : '@${u['username']}'));
                }).toList())),
                const SizedBox(height: 10),
                FilledButton.icon(onPressed: selected.isEmpty ? null : () => Navigator.pop(sheet, selected.toList()), icon: const Icon(Icons.person_add_alt_1_rounded), label: Text(selected.isEmpty ? 'انتخاب اعضا' : 'افزودن ${selected.length} نفر')),
              ]),
            ));
          });
        },
      );
      if (added == null || added.isEmpty) return;
      setState(() => busy = true);
      final count = await db.rpc('add_group_members', params: {'p_conversation_id': widget.conversationId, 'p_user_ids': added});
      toast('${count ?? added.length} عضو به گروه اضافه شد.');
      await load();
    } catch (e) { toast('افزودن عضو ناموفق بود: $e'); }
    finally { search.dispose(); if (mounted) setState(() => busy = false); }
  }

'''
    if anchor not in g:
        raise SystemExit('group anchor not found')
    g = g.replace(anchor, method + anchor, 1)
needle = "        if (admin) const Divider(height: 1),\n"
if "title: const Text('افزودن اعضا'" not in g and needle in g:
    tile = "        if (admin) ListTile(leading: const Icon(Icons.person_add_alt_1_rounded), title: const Text('افزودن اعضا'), subtitle: const Text('جستجو و افزودن چند کاربر به‌صورت هم‌زمان'), trailing: const Icon(Icons.chevron_left), onTap: addMembers),\n"
    g = g.replace(needle, tile + needle, 1)
group.write_text(g, encoding='utf-8')

print('Professional UX patch applied: profile background picker + real group member selector.')
