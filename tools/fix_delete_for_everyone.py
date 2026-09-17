from pathlib import Path
import re

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

# Shared delete-for-everyone: hide deleted rows for every participant.
s = s.replace(
    "loaded.removeWhere((m) => hidden.contains('${m['id']}'));",
    "loaded.removeWhere((m) => hidden.contains('${m['id']}') || m['deleted_at'] != null);",
    1,
)

# Replace the current delete implementation regardless of minor formatting differences.
pattern = re.compile(r"  Future<void> deleteForEveryone\(Map<String, dynamic> message\) async \{.*?\n  \}\n\n  Future<void> saveMessage", re.S)
replacement = """  Future<void> deleteForEveryone(Map<String, dynamic> message) async {
    if (message['sender_id'] != supabase.auth.currentUser?.id) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف برای همه'),
        content: const Text('این پیام برای همه اعضای گفتگو حذف می‌شود.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final updated = await supabase.from('messages').update({
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'body': null,
      }).eq('id', message['id']).eq('sender_id', supabase.auth.currentUser!.id).select('id,deleted_at');
      if ((updated as List).isEmpty) {
        throw Exception('پیام حذف نشد؛ مجوز حذف برای همه یا مالکیت پیام بررسی شود.');
      }
      if (mounted) {
        setState(() {
          messages.removeWhere((m) => '${m['id']}' == '${message['id']}');
          reactions.remove('${message['id']}');
          attachments.remove('${message['id']}');
        });
      }
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'حذف برای همه ناموفق بود: $e');
    }
  }

  Future<void> saveMessage"""
s, n = pattern.subn(replacement, s, count=1)
if n != 1:
    raise SystemExit('deleteForEveryone block not found')

# Group admin detection: use the actual conversation_members.role source too.
old_admin = """  Future<bool> _isGroupAdmin() async {
    try {
      final uid=supabase.auth.currentUser!.id;
      final r=await supabase.from('conversation_admins').select('role').eq('conversation_id',widget.id).eq('user_id',uid).maybeSingle();
      return r!=null;
    } catch (_) { return false; }
  }
"""
new_admin = """  Future<bool> _isGroupAdmin() async {
    try {
      final uid = supabase.auth.currentUser!.id;
      final c = await supabase.from('conversations').select('created_by,type').eq('id', widget.id).maybeSingle();
      if (c == null || !['group','channel'].contains('${c['type']}')) return false;
      if ('${c['created_by']}' == uid) return true;
      final m = await supabase.from('conversation_members').select('role').eq('conversation_id', widget.id).eq('user_id', uid).maybeSingle();
      if (m?['role'] == 'admin') return true;
      final a = await supabase.from('conversation_admins').select('role').eq('conversation_id', widget.id).eq('user_id', uid).maybeSingle();
      return a?['role'] == 'owner' || a?['role'] == 'admin';
    } catch (_) { return false; }
  }
"""
if old_admin in s:
    s = s.replace(old_admin, new_admin, 1)

# Group management should use member roles as the primary role store, with legacy admin rows as fallback.
s = s.replace(
    "admins=List<Map<String,dynamic>>.from(await supabase.from('conversation_admins').select('user_id,role').eq('conversation_id',widget.conversationId));",
    "final legacyAdmins=List<Map<String,dynamic>>.from(await supabase.from('conversation_admins').select('user_id,role').eq('conversation_id',widget.conversationId));\n      admins=[...members.where((m)=>m['role']=='admin').map((m)=>{'user_id':m['id'],'role':'admin'}), ...legacyAdmins.where((a)=>!members.any((m)=>'${m['id']}'=='${a['user_id']}'))];",
    1,
)

old_toggle = """  Future<void> toggleAdmin(Map<String,dynamic> p)async{
    final id=p['id'].toString(); if(id==supabase.auth.currentUser!.id){showMsg(context,'مالک را نمی‌توان تغییر داد.');return;}
    try{
      if(isAdmin(id)) await supabase.from('conversation_admins').delete().eq('conversation_id',widget.conversationId).eq('user_id',id);
      else await supabase.from('conversation_admins').insert({'conversation_id':widget.conversationId,'user_id':id,'role':'admin'});
      await load();
    }catch(e){if(mounted)showMsg(context,'تغییر مدیر ناموفق بود: '+e.toString());}
  }
"""
new_toggle = """  Future<void> toggleAdmin(Map<String,dynamic> p)async{
    final id=p['id'].toString();
    if(id==supabase.auth.currentUser!.id){showMsg(context,'مالک را نمی‌توان تغییر داد.');return;}
    try{
      final current = await supabase.from('conversation_members').select('role').eq('conversation_id',widget.conversationId).eq('user_id',id).maybeSingle();
      if(current==null) return;
      await supabase.from('conversation_members').delete().eq('conversation_id',widget.conversationId).eq('user_id',id);
      await supabase.from('conversation_members').insert({'conversation_id':widget.conversationId,'user_id':id,'role':current['role']=='admin'?'member':'admin'});
      await load();
    }catch(e){if(mounted)showMsg(context,'تغییر مدیر ناموفق بود: '+e.toString());}
  }
"""
if old_toggle in s:
    s = s.replace(old_toggle, new_toggle, 1)

# Cleaner, non-reversed chat layout.
s = s.replace("      extendBodyBehindAppBar: true,\n      appBar: AppBar(\n        backgroundColor: scheme.surface.withValues(alpha: .62),", "      extendBodyBehindAppBar: false,\n      appBar: AppBar(\n        backgroundColor: scheme.surface,")
s = s.replace("        flexibleSpace: ClipRect(\n          child: BackdropFilter(\n            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),\n            child: Container(\n              color: scheme.surface.withValues(alpha: .20),\n              decoration: BoxDecoration(\n                border: Border(\n                  bottom: BorderSide(color: scheme.onSurface.withValues(alpha: .07)),\n                ),\n              ),\n            ),\n          ),\n        ),", "        surfaceTintColor: Colors.transparent,\n        elevation: 0,\n        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: scheme.onSurface.withValues(alpha: .07))),")
s = s.replace("padding: const EdgeInsets.fromLTRB(12, 92, 12, 12),", "padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),")
s = s.replace("color: dark ? const Color(0xFF17191D) : const Color(0xFFF0F2F5),", "color: dark ? const Color(0xFF14171B) : const Color(0xFFEFF2F5),")
s = s.replace("color: scheme.surface.withValues(alpha: dark ? .72 : .78),", "color: dark ? const Color(0xFF20242A) : Colors.white,")
s = s.replace("border: Border.all(color: scheme.onSurface.withValues(alpha: .08)),", "border: Border.all(color: scheme.onSurface.withValues(alpha: .10)),", 1)
s = s.replace("color: scheme.surface.withValues(alpha: dark ? .72 : .78),\n                        borderRadius: BorderRadius.circular(24),", "color: dark ? const Color(0xFF20242A) : Colors.white,\n                        borderRadius: BorderRadius.circular(24),")

# Link messages: show a preview card instead of the raw URL.
old_link = """            const Icon(Icons.link_rounded, size: 28),
            const SizedBox(height: 4),
            Text(url, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: textColor)),
            Text(Uri.tryParse(url)?.host ?? 'لینک', style: TextStyle(fontSize: 11, color: mine ? Colors.white70 : scheme.primary)),
"""
new_link = """            Container(width: double.infinity, height: 92, decoration: BoxDecoration(color: mine ? Colors.white.withValues(alpha:.12) : scheme.primary.withValues(alpha:.08), borderRadius: BorderRadius.circular(12)), child: const Center(child: Icon(Icons.language_rounded, size: 34))),
            const SizedBox(height: 8),
            Text('پیش‌نمایش لینک', style: TextStyle(fontWeight: FontWeight.w800, color: textColor)),
            const SizedBox(height: 2),
            Text(Uri.tryParse(url)?.host ?? 'لینک', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: mine ? Colors.white70 : scheme.primary)),
"""
if old_link in s:
    s = s.replace(old_link, new_link, 1)

p.write_text(s, encoding='utf-8')
print('chat visual, delete-for-everyone, and group management fixes applied')
