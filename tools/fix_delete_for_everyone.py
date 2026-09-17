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

# Make the delete operation observable and remove it immediately from the local UI.
old_delete = """      await supabase.from('messages').update({\n        'deleted_at': DateTime.now().toUtc().toIso8601String(),\n        'body': null,\n      }).eq('id', message['id']).eq('sender_id', supabase.auth.currentUser!.id);\n      await load();\n"""
new_delete = """      final updated = await supabase.from('messages').update({\n        'deleted_at': DateTime.now().toUtc().toIso8601String(),\n        'body': null,\n      }).eq('id', message['id']).eq('sender_id', supabase.auth.currentUser!.id).select('id,deleted_at');\n      if ((updated as List).isEmpty) {\n        throw Exception('پیام حذف نشد؛ مجوز حذف برای همه یا مالکیت پیام بررسی شود.');\n      }\n      if (mounted) {\n        setState(() {\n          messages.removeWhere((m) => '${m['id']}' == '${message['id']}');\n          reactions.remove('${message['id']}');\n          attachments.remove('${message['id']}');\n        });\n      }\n      await load();\n"""
if old_delete in s:
    s = s.replace(old_delete, new_delete, 1)

# Group admin detection: use the actual conversation_members.role source too.
old_admin = """  Future<bool> _isGroupAdmin() async {\n    try {\n      final uid=supabase.auth.currentUser!.id;\n      final r=await supabase.from('conversation_admins').select('role').eq('conversation_id',widget.id).eq('user_id',uid).maybeSingle();\n      return r!=null;\n    } catch (_) { return false; }\n  }\n"""
new_admin = """  Future<bool> _isGroupAdmin() async {\n    try {\n      final uid = supabase.auth.currentUser!.id;\n      final c = await supabase.from('conversations').select('created_by,type').eq('id', widget.id).maybeSingle();\n      if (c == null || !['group','channel'].contains('${c['type']}')) return false;\n      if ('${c['created_by']}' == uid) return true;\n      final m = await supabase.from('conversation_members').select('role').eq('conversation_id', widget.id).eq('user_id', uid).maybeSingle();\n      if (m?['role'] == 'admin') return true;\n      final a = await supabase.from('conversation_admins').select('role').eq('conversation_id', widget.id).eq('user_id', uid).maybeSingle();\n      return a?['role'] == 'owner' || a?['role'] == 'admin';\n    } catch (_) { return false; }\n  }\n"""
if old_admin in s:
    s = s.replace(old_admin, new_admin, 1)

# Group management should use member roles as the primary role store, with legacy admin rows as fallback.
s = s.replace(
    "admins=List<Map<String,dynamic>>.from(await supabase.from('conversation_admins').select('user_id,role').eq('conversation_id',widget.conversationId));",
    "final legacyAdmins=List<Map<String,dynamic>>.from(await supabase.from('conversation_admins').select('user_id,role').eq('conversation_id',widget.conversationId));\n      admins=[...members.where((m)=>m['role']=='admin').map((m)=>{'user_id':m['id'],'role':'admin'}), ...legacyAdmins.where((a)=>!members.any((m)=>'${m['id']}'=='${a['user_id']}'))];",
    1,
)

old_toggle = """  Future<void> toggleAdmin(Map<String,dynamic> p)async{\n    final id=p['id'].toString(); if(id==supabase.auth.currentUser!.id){showMsg(context,'مالک را نمی‌توان تغییر داد.');return;}\n    try{\n      if(isAdmin(id)) await supabase.from('conversation_admins').delete().eq('conversation_id',widget.conversationId).eq('user_id',id);\n      else await supabase.from('conversation_admins').insert({'conversation_id':widget.conversationId,'user_id':id,'role':'admin'});\n      await load();\n    }catch(e){if(mounted)showMsg(context,'تغییر مدیر ناموفق بود: '+e.toString());}\n  }\n"""
new_toggle = """  Future<void> toggleAdmin(Map<String,dynamic> p)async{\n    final id=p['id'].toString();\n    if(id==supabase.auth.currentUser!.id){showMsg(context,'مالک را نمی‌توان تغییر داد.');return;}\n    try{\n      final current = await supabase.from('conversation_members').select('role').eq('conversation_id',widget.conversationId).eq('user_id',id).maybeSingle();\n      if(current==null) return;\n      await supabase.from('conversation_members').delete().eq('conversation_id',widget.conversationId).eq('user_id',id);\n      await supabase.from('conversation_members').insert({'conversation_id':widget.conversationId,'user_id':id,'role':current['role']=='admin'?'member':'admin'});\n      await load();\n    }catch(e){if(mounted)showMsg(context,'تغییر مدیر ناموفق بود: '+e.toString());}\n  }\n"""
if old_toggle in s:
    s = s.replace(old_toggle, new_toggle, 1)

# Cleaner, non-reversed chat layout: solid header/input, no translucent overlay, and normal top-to-bottom list.
s = s.replace("      extendBodyBehindAppBar: true,\n      appBar: AppBar(\n        backgroundColor: scheme.surface.withValues(alpha: .62),", "      extendBodyBehindAppBar: false,\n      appBar: AppBar(\n        backgroundColor: scheme.surface,")
s = s.replace("        flexibleSpace: ClipRect(\n          child: BackdropFilter(\n            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),\n            child: Container(\n              color: scheme.surface.withValues(alpha: .20),\n              decoration: BoxDecoration(\n                border: Border(\n                  bottom: BorderSide(color: scheme.onSurface.withValues(alpha: .07)),\n                ),\n              ),\n            ),\n          ),\n        ),", "        surfaceTintColor: Colors.transparent,\n        elevation: 0,\n        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: scheme.onSurface.withValues(alpha: .07))),")
s = s.replace("padding: const EdgeInsets.fromLTRB(12, 92, 12, 12),", "padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),")
s = s.replace("color: dark ? const Color(0xFF17191D) : const Color(0xFFF0F2F5),", "color: dark ? const Color(0xFF14171B) : const Color(0xFFEFF2F5),")
s = s.replace("color: scheme.surface.withValues(alpha: dark ? .72 : .78),", "color: dark ? const Color(0xFF20242A) : Colors.white,")
s = s.replace("border: Border.all(color: scheme.onSurface.withValues(alpha: .08)),", "border: Border.all(color: scheme.onSurface.withValues(alpha: .10)),", 1)

# Flat input bar instead of the old glass stack.
s = s.replace("color: scheme.surface.withValues(alpha: dark ? .72 : .78),\n                        borderRadius: BorderRadius.circular(24),", "color: dark ? const Color(0xFF20242A) : Colors.white,\n                        borderRadius: BorderRadius.circular(24),")

# Link messages: never print the raw URL as the primary content.
old_link = """            const Icon(Icons.link_rounded, size: 28),\n            const SizedBox(height: 4),\n            Text(url, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: textColor)),\n            Text(Uri.tryParse(url)?.host ?? 'لینک', style: TextStyle(fontSize: 11, color: mine ? Colors.white70 : scheme.primary)),\n"""
new_link = """            Container(width: double.infinity, height: 92, decoration: BoxDecoration(color: mine ? Colors.white.withValues(alpha:.12) : scheme.primary.withValues(alpha:.08), borderRadius: BorderRadius.circular(12)), child: const Center(child: Icon(Icons.language_rounded, size: 34))),\n            const SizedBox(height: 8),\n            Text('پیش‌نمایش لینک', style: TextStyle(fontWeight: FontWeight.w800, color: textColor)),\n            const SizedBox(height: 2),\n            Text(Uri.tryParse(url)?.host ?? 'لینک', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: mine ? Colors.white70 : scheme.primary)),\n"""
if old_link in s:
    s = s.replace(old_link, new_link, 1)

p.write_text(s, encoding='utf-8')
print('chat visual, delete-for-everyone, and group management fixes applied')
