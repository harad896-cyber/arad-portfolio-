from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

old_load = """      if (uid != null && loaded.isNotEmpty) {\n        final deletedRows = await supabase.from('message_user_deletions').select('message_id').eq('user_id', uid);\n        final hidden = {for (final r in List<Map<String, dynamic>>.from(deletedRows)) '${r['message_id']}'};\n        loaded.removeWhere((m) => hidden.contains('${m['id']}'));\n      }\n"""
new_load = """      if (uid != null && loaded.isNotEmpty) {\n        final deletedRows = await supabase.from('message_user_deletions').select('message_id').eq('user_id', uid);\n        final hidden = {for (final r in List<Map<String, dynamic>>.from(deletedRows)) '${r['message_id']}'};\n        // 'Delete for everyone' is a shared deletion: once deleted_at is set,\n        // the message must disappear for every participant, not just show an empty bubble.\n        loaded.removeWhere((m) => hidden.contains('${m['id']}') || m['deleted_at'] != null);\n      }\n"""
if old_load not in s:
    raise SystemExit('load block not found')
s = s.replace(old_load, new_load, 1)

old_delete = """      await supabase.from('messages').update({\n        'deleted_at': DateTime.now().toUtc().toIso8601String(),\n        'body': null,\n      }).eq('id', message['id']).eq('sender_id', supabase.auth.currentUser!.id);\n      await load();\n"""
new_delete = """      final updated = await supabase.from('messages').update({\n        'deleted_at': DateTime.now().toUtc().toIso8601String(),\n        'body': null,\n      }).eq('id', message['id']).eq('sender_id', supabase.auth.currentUser!.id).select('id,deleted_at');\n      if ((updated as List).isEmpty) {\n        throw Exception('پیام حذف نشد؛ مجوز حذف برای همه یا مالکیت پیام بررسی شود.');\n      }\n      if (mounted) {\n        setState(() {\n          messages.removeWhere((m) => '${m['id']}' == '${message['id']}');\n          reactions.remove('${message['id']}');\n          attachments.remove('${message['id']}');\n        });\n      }\n      await load();\n"""
if old_delete not in s:
    raise SystemExit('delete block not found')
s = s.replace(old_delete, new_delete, 1)

p.write_text(s, encoding='utf-8')
print('delete-for-everyone fix applied')
