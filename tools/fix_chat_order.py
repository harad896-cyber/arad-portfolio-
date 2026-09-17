from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

old_query = ".from('messages').select().eq('conversation_id', widget.id).order('created_at');"
new_query = ".from('messages').select().eq('conversation_id', widget.id).order('created_at', ascending: true);"
if old_query in s:
    s = s.replace(old_query, new_query, 1)

old_loaded = """      final loaded = List<Map<String, dynamic>>.from(rows);
      final uid = supabase.auth.currentUser?.id;"""
new_loaded = """      final loaded = List<Map<String, dynamic>>.from(rows);
      loaded.sort((a, b) {
        final ad = DateTime.tryParse('${a['created_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = DateTime.tryParse('${b['created_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return ad.compareTo(bd);
      });
      final uid = supabase.auth.currentUser?.id;"""
if old_loaded in s and new_loaded not in s:
    s = s.replace(old_loaded, new_loaded, 1)

old_state = """          messages = loaded;
          reactions = loadedReactions;
          attachments = loadedAttachments;
          loading = false;
        });
        // Keep chat ordered from top to bottom; do not force the list back to the bottom."""
new_state = """          messages = loaded;
          reactions = loadedReactions;
          attachments = loadedAttachments;
          loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_messagesScroll.hasClients) return;
          _messagesScroll.jumpTo(_messagesScroll.position.maxScrollExtent);
        });"""
if old_state in s:
    s = s.replace(old_state, new_state, 1)

if "reverse: false," not in s:
    raise SystemExit('Chat ListView reverse setting not found')

p.write_text(s, encoding='utf-8')
