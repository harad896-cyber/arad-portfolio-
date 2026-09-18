from pathlib import Path
p=Path("lib/main.dart")
s=p.read_text(encoding="utf-8")

old="""  Future<String?> _attachmentUrl(String path) async {
    if (path.isEmpty) return null;
    try {
      return await supabase.storage.from('chat-media').createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }
"""
new="""  final Map<String, String> _attachmentUrlCache = {};

  Future<String?> _attachmentUrl(String path) async {
    if (path.isEmpty) return null;
    final cached = _attachmentUrlCache[path];
    if (cached != null && cached.isNotEmpty) return cached;
    try {
      final url = await supabase.storage.from('chat-media').createSignedUrl(path, 3600);
      if (url.isNotEmpty) _attachmentUrlCache[path] = url;
      return url;
    } catch (_) {
      return null;
    }
  }
"""
if old in s: s=s.replace(old,new,1)

s=s.replace("  StreamSubscription<Amplitude>? _voiceAmplitudeSub;\n","  StreamSubscription<Amplitude>? _voiceAmplitudeSub;\n  static const int _messagePageSize = 50;\n  bool _loadingOlder = false;\n  bool _hasOlderMessages = true;\n",1)

start=s.find("  Future<void> load() async {",s.find("class _ChatPageState"))
end=s.find("\n  Future<void> markRead() async {",start)
if start<0 or end<0: raise SystemExit("chat load anchors missing")
replacement="""  Future<void> _hydrateMessages(List<Map<String, dynamic>> loaded, {bool merge = false}) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid != null && loaded.isNotEmpty) {
      final ids = loaded.map((m) => m['id'].toString()).toList();
      final deletedRows = await supabase.from('message_user_deletions').select('message_id').eq('user_id', uid).inFilter('message_id', ids);
      final hidden = {for (final r in List<Map<String, dynamic>>.from(deletedRows)) r['message_id'].toString()};
      loaded.removeWhere((m) => hidden.contains(m['id'].toString()) || m['deleted_at'] != null);
    }
    final senderIds = loaded.map((m) => m['sender_id'].toString()).toSet().toList();
    if (senderIds.isNotEmpty) {
      final people = await supabase.from('profiles').select('id,display_name,username,avatar_url,is_verified').inFilter('id', senderIds);
      profiles.addAll({for (final p in List<Map<String, dynamic>>.from(people)) p['id'].toString(): p});
    }
    final ids = loaded.map((m) => m['id'].toString()).toList();
    final loadedReactions = <String, List<Map<String, dynamic>>>{};
    final loadedAttachments = <String, Map<String, dynamic>>{};
    if (ids.isNotEmpty) {
      final rr = await supabase.from('message_reactions').select('message_id,user_id,reaction,created_at').inFilter('message_id', ids);
      for (final r in List<Map<String, dynamic>>.from(rr)) loadedReactions.putIfAbsent(r['message_id'].toString(), () => []).add(r);
      final aa = await supabase.from('message_attachments').select('message_id,storage_path,file_name,mime_type,file_size,duration_ms').inFilter('message_id', ids);
      for (final a in List<Map<String, dynamic>>.from(aa)) loadedAttachments[a['message_id'].toString()]=a;
    }
    if (merge) {
      final existing=messages.map((m)=>m['id'].toString()).toSet();
      loaded=loaded.where((m)=>!existing.contains(m['id'].toString())).toList();
      messages=[...loaded,...messages]..sort((a,b){
        final ad=DateTime.tryParse(a['created_at'].toString())??DateTime.fromMillisecondsSinceEpoch(0);
        final bd=DateTime.tryParse(b['created_at'].toString())??DateTime.fromMillisecondsSinceEpoch(0);
        return ad.compareTo(bd);
      });
      reactions.addAll(loadedReactions); attachments.addAll(loadedAttachments);
    } else {
      messages=loaded; reactions=loadedReactions; attachments=loadedAttachments;
    }
  }

  Future<void> load() async {
    try {
      final rows=await supabase.from('messages').select().eq('conversation_id',widget.id).order('created_at',ascending:false).range(0,_messagePageSize-1);
      final loaded=List<Map<String,dynamic>>.from(rows).reversed.toList();
      _hasOlderMessages=loaded.length==_messagePageSize;
      await _hydrateMessages(loaded);
      if(mounted){
        setState(()=>loading=false);
        WidgetsBinding.instance.addPostFrameCallback((_){
          if(!mounted||!_messagesScroll.hasClients)return;
          _messagesScroll.jumpTo(_messagesScroll.position.maxScrollExtent);
        });
      }
      await markRead(); _scrollToLatest();
    } catch(e) {
      if(mounted){setState(()=>loading=false);showMsg(context,'خطا در پیام‌ها: $e');}
    }
  }

  Future<void> _loadOlderMessages() async {
    if(_loadingOlder||!_hasOlderMessages||messages.isEmpty)return;
    final oldest=messages.first['created_at']?.toString();
    if(oldest==null||oldest.isEmpty)return;
    setState(()=>_loadingOlder=true);
    try {
      final rows=await supabase.from('messages').select().eq('conversation_id',widget.id).lt('created_at',oldest).order('created_at',ascending:false).range(0,_messagePageSize-1);
      final older=List<Map<String,dynamic>>.from(rows).reversed.toList();
      _hasOlderMessages=older.length==_messagePageSize;
      final oldExtent=_messagesScroll.hasClients?_messagesScroll.position.maxScrollExtent:0.0;
      final oldPixels=_messagesScroll.hasClients?_messagesScroll.position.pixels:0.0;
      await _hydrateMessages(older,merge:true);
      if(mounted){
        setState((){});
        WidgetsBinding.instance.addPostFrameCallback((_){
          if(!_messagesScroll.hasClients)return;
          final delta=_messagesScroll.position.maxScrollExtent-oldExtent;
          _messagesScroll.jumpTo(oldPixels+delta);
        });
      }
    } catch(_){if(mounted)showMsg(context,'بارگذاری تاریخچه ناموفق بود.');}
    finally{if(mounted)setState(()=>_loadingOlder=false);}
  }
"""
s=s[:start]+replacement+s[end:]

old="""  Future<void> markRead() async {
    try {
      final rows = await supabase.from('messages').select('id').eq('conversation_id', widget.id).neq('sender_id', supabase.auth.currentUser!.id);
      for (final row in rows) {
        await supabase.rpc('mark_message_read', params: {'p_message_id': row['id']});
      }
    } catch (_) {}
  }
"""
new="""  Future<void> markRead() async {
    try {
      final uid=supabase.auth.currentUser?.id;
      if(uid==null||messages.isEmpty)return;
      for(final row in messages){
        if(row['sender_id'].toString()==uid||row['read_at']!=null)continue;
        await supabase.rpc('mark_message_read',params:{'p_message_id':row['id']});
      }
    } catch (_) {}
  }
"""
if old in s:s=s.replace(old,new,1)

needle="""                      : ListView.builder(
                          controller: _messagesScroll,
"""
repl="""                      : NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification.metrics.pixels <= 120 && notification is ScrollUpdateNotification) _loadOlderMessages();
                            return false;
                          },
                          child: ListView.builder(
                          controller: _messagesScroll,
"""
if needle not in s:raise SystemExit("chat list anchor missing")
s=s.replace(needle,repl,1)
needle="""                          itemBuilder: (context, i) => _glassMessageBubble(messages[i]),
                        ),
"""
repl="""                          itemBuilder: (context, i) => _glassMessageBubble(messages[i]),
                          ),
                        ),
"""
if needle not in s:raise SystemExit("chat list close missing")
s=s.replace(needle,repl,1)

s=s.replace("    _messagesScroll.dispose();\n    text.dispose();","    _messagesScroll.dispose();\n    _attachmentUrlCache.clear();\n    text.dispose();",1)
p.write_text(s,encoding="utf-8")
print("polish applied")
