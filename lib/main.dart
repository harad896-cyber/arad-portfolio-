// Auth OTP flow: email code + owner authorization.
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'group_management.dart';
import 'channel_management.dart';
import 'invite.dart';
import 'profile_page.dart';
import 'chat_background_page.dart';
import 'call_session.dart';
import 'voice_message_player.dart';


String t(String key, String locale) {
  const data = {
    'fa': {'login':'ورود','signup':'ثبت‌نام','email':'ایمیل','password':'رمز عبور','google':'ورود با حساب Google','profile':'پروفایل شما','continue':'ادامه','settings':'تنظیمات','language':'زبان'},
    'en': {'login':'Login','signup':'Sign up','email':'Email','password':'Password','google':'Continue with Google','profile':'Your profile','continue':'Continue','settings':'Settings','language':'Language'},
    'ar': {'login':'تسجيل الدخول','signup':'إنشاء حساب','email':'البريد الإلكتروني','password':'كلمة المرور','google':'المتابعة باستخدام Google','profile':'ملفك الشخصي','continue':'متابعة','settings':'الإعدادات','language':'اللغة'},
    'tr': {'login':'Giriş','signup':'Kayıt ol','email':'E-posta','password':'Şifre','google':'Google ile devam et','profile':'Profiliniz','continue':'Devam','settings':'Ayarlar','language':'Dil'},
    'fr': {'login':'Connexion','signup':'Inscription','email':'E-mail','password':'Mot de passe','google':'Continuer avec Google','profile':'Votre profil','continue':'Continuer','settings':'Paramètres','language':'Langue'},
    'de': {'login':'Anmelden','signup':'Registrieren','email':'E-Mail','password':'Passwort','google':'Mit Google fortfahren','profile':'Ihr Profil','continue':'Weiter','settings':'Einstellungen','language':'Sprache'},
  };
  return data[locale]?[key] ?? data['en']![key] ?? key;
}

class LanguageController extends ChangeNotifier {
  Locale locale = const Locale('fa');

  Future<void> _hydrateMessages(List<Map<String, dynamic>> loaded) async {
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
    if (ids.isEmpty) return;
    final rr = await supabase.from('message_reactions').select('message_id,user_id,reaction,created_at').inFilter('message_id', ids);
    for (final r in List<Map<String, dynamic>>.from(rr)) {
      reactions.putIfAbsent(r['message_id'].toString(), () => []).add(r);
    }
    final aa = await supabase.from('message_attachments').select('message_id,storage_path,file_name,mime_type,file_size,duration_ms').inFilter('message_id', ids);
    for (final a in List<Map<String, dynamic>>.from(aa)) {
      attachments[a['message_id'].toString()] = a;
    }
  }

  Future<void> load() async {
    try {
      final rows = await supabase.from('messages').select().eq('conversation_id', widget.id).order('created_at', ascending: false).limit(_messagePageSize);
      final loaded = List<Map<String, dynamic>>.from(rows);
      loaded.sort((a, b) => (DateTime.tryParse(a['created_at'].toString()) ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(DateTime.tryParse(b['created_at'].toString()) ?? DateTime.fromMillisecondsSinceEpoch(0)));
      _hasOlderMessages = loaded.length == _messagePageSize;
      profiles = {};
      reactions = {};
      attachments = {};
      await _hydrateMessages(loaded);
      if (mounted) {
        setState(() { messages = loaded; loading = false; });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_messagesScroll.hasClients) return;
          _messagesScroll.jumpTo(_messagesScroll.position.maxScrollExtent);
        });
      }
      await markRead();
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        showMsg(context, 'خطا در پیام‌ها: $e');
      }
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlder || !_hasOlderMessages || messages.isEmpty) return;
    _loadingOlder = true;
    try {
      final oldest = messages.first['created_at'];
      final rows = await supabase.from('messages').select().eq('conversation_id', widget.id).lt('created_at', oldest).order('created_at', ascending: false).limit(_messagePageSize);
      final older = List<Map<String, dynamic>>.from(rows);
      older.sort((a, b) => (DateTime.tryParse(a['created_at'].toString()) ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(DateTime.tryParse(b['created_at'].toString()) ?? DateTime.fromMillisecondsSinceEpoch(0)));
      _hasOlderMessages = older.length == _messagePageSize;
      if (older.isEmpty) return;
      final beforeExtent = _messagesScroll.hasClients ? _messagesScroll.position.maxScrollExtent : 0.0;
      await _hydrateMessages(older);
      if (!mounted) return;
      setState(() => messages = [...older, ...messages]);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_messagesScroll.hasClients) return;
        final delta = _messagesScroll.position.maxScrollExtent - beforeExtent;
        _messagesScroll.jumpTo(_messagesScroll.offset + delta);
      });
    } catch (_) {
      if (mounted) showMsg(context, 'بارگذاری تاریخچه پیام‌ها ناموفق بود');
    } finally {
      _loadingOlder = false;
    }
  }

  Future<void> markRead() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;
      final unread = messages.where((m) => m['sender_id'].toString() != uid).take(50).toList();
      for (final row in unread) {
        await supabase.rpc('mark_message_read', params: {'p_message_id': row['id']});
      }
    } catch (_) {}
  }

  final List<String> quickReactions = const ['❤️','👍','😂','😮','😢','🙏'];
  Future<void> _toggleReaction(String messageId, String emoji) async {
    final uid=supabase.auth.currentUser?.id; if(uid==null)return;
    try { final existing=await supabase.from('message_reactions').select('message_id,user_id,reaction').eq('message_id',messageId).eq('user_id',uid).eq('reaction',emoji).maybeSingle();
      if(existing!=null) await supabase.from('message_reactions').delete().eq('message_id',messageId).eq('user_id',uid).eq('reaction',emoji);
      else { await supabase.from('message_reactions').delete().eq('message_id',messageId).eq('user_id',uid); await supabase.from('message_reactions').insert({'message_id':messageId,'user_id':uid,'reaction':emoji}); } await load();
    } catch(_) { if(mounted)showMsg(context,'واکنش ثبت نشد'); }
  }
  Future<void> _showReactionPicker(Map<String,dynamic> m) async {
    final id = m['id'].toString();
    await showModalBottomSheet<void>(context:context,backgroundColor:Colors.transparent,builder:(ctx){ final scheme=Theme.of(ctx).colorScheme;
      return TweenAnimationBuilder<double>(tween:Tween(begin:.85,end:1),duration:const Duration(milliseconds:180),curve:Curves.easeOutBack,builder:(c,scale,child)=>Transform.scale(scale:scale,child:child),child:
        Container(padding:const EdgeInsets.fromLTRB(12,10,12,18),decoration:BoxDecoration(color:scheme.surface,borderRadius:const BorderRadius.vertical(top:Radius.circular(28))),child:Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
          ...quickReactions.map((e)=>InkWell(onTap:(){Navigator.pop(ctx);_toggleReaction(id,e);},borderRadius:BorderRadius.circular(18),child:Padding(padding:const EdgeInsets.all(8),child:Text(e,style:const TextStyle(fontSize:27))))),
          IconButton(onPressed:(){Navigator.pop(ctx);_showReactionPeople(id);},icon:const Icon(Icons.add_circle_outline_rounded))]))); });
  }
  Future<void> _showReactionPeople(String messageId) async {
    final rows=await supabase.from('message_reactions').select('user_id,reaction').eq('message_id',messageId); if(!mounted)return;
    await showModalBottomSheet<void>(context:context,showDragHandle:true,builder:(ctx)=>ListView(padding:const EdgeInsets.all(16),children:[const Text('واکنش‌ها',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800)),const SizedBox(height:10),...List<Map<String,dynamic>>.from(rows).map((r)=>ListTile(leading:Text(r['reaction'].toString(),style:const TextStyle(fontSize:25)),title:Text(r['user_id'].toString()))) ]));
  }
  Widget _reactionBar(String messageId) {
    final rs = reactions[messageId] ?? [];
    if (rs.isEmpty) return const SizedBox.shrink();
    final grouped = <String,int>{};
    for (final r in rs) { final e = r['reaction'].toString(); grouped[e] = (grouped[e] ?? 0) + 1; }
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Wrap(
        spacing: 4,
        children: grouped.entries.map<Widget>((e) => InkWell(
          onTap: () => _showReactionPeople(messageId),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
            child: Text(e.key + (e.value > 1 ? ' ${e.value}' : '')),
          ),
        )).toList(),
      ),
    );
  }

  void _scrollToLatest() {
    if (!_messagesScroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messagesScroll.hasClients) return;
      _messagesScroll.animateTo(
        _messagesScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> sendText() async {
    final value = text.text.trim();
    if (value.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await supabase.from('messages').insert({
        'conversation_id': widget.id,
        'sender_id': supabase.auth.currentUser!.id,
        'body': value,
        'message_type': 'text',
        'reply_to': replyMessage?['id'],
      });
      text.clear();
      if (mounted) setState(() => replyMessage = null);
      await load();
      _scrollToLatest();
    } catch (e) {
      if (mounted) showMsg(context, 'ارسال نشد: $e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  String _mimeType(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.gif')) return 'image/gif';
    if (n.endsWith('.mp3')) return 'audio/mpeg';
    if (n.endsWith('.m4a')) return 'audio/mp4';
    if (n.endsWith('.aac')) return 'audio/aac';
    if (n.endsWith('.wav')) return 'audio/wav';
    if (n.endsWith('.ogg') || n.endsWith('.oga')) return 'audio/ogg';
    if (n.endsWith('.opus')) return 'audio/opus';
    if (n.endsWith('.mp4')) return 'video/mp4';
    if (n.endsWith('.mov')) return 'video/quicktime';
    if (n.endsWith('.pdf')) return 'application/pdf';
    return 'application/octet-stream';
  }

  Future<void> sendFile() async {
    if (sending) return;
    try {
      final result = await FilePicker.platform.pickFiles(withData: false);
      if (result == null) return;
      final f = result.files.single;
      final localPath = f.path;
      if (localPath == null || localPath.isEmpty) throw Exception('مسیر فایل از Android دریافت نشد');
      final bytes = await File(localPath).readAsBytes();
      if (bytes.isEmpty) throw Exception('فایل خالی است');
      final mime = _mimeType(f.name);
      final isAudio = mime.startsWith('audio/');
      final isImage = mime.startsWith('image/');
      final path = '${widget.id}/${DateTime.now().millisecondsSinceEpoch}_${f.name}';
      setState(() => sending = true);
      await supabase.storage.from('chat-media').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime, upsert: false));
      final msg = await supabase.from('messages').insert({
        'conversation_id': widget.id,
        'sender_id': supabase.auth.currentUser!.id,
        'body': f.name,
        'message_type': isAudio ? 'audio' : (isImage ? 'image' : 'file'),
        'reply_to': replyMessage?['id'],
      }).select().single();
      await supabase.from('message_attachments').insert({
        'message_id': msg['id'],
        'storage_path': path,
        'file_name': f.name,
        'file_size': f.size,
        'mime_type': mime,
      });
      if (mounted) setState(() => replyMessage = null);
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'فایل ارسال نشد: $e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _startVoiceRecording() async {
    if (sending || recordingVoice) return;
    try {
      if (!await _voiceRecorder.hasPermission()) { if (mounted) showMsg(context, 'دسترسی میکروفون فعال نیست.'); return; }
      final path = '${Directory.systemTemp.path}/arad_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _voiceRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100), path: path);
      _voiceStartedAt = DateTime.now();
      _voiceTimer?.cancel();
      _voiceTimer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted && recordingVoice) setState(() => voiceSeconds = DateTime.now().difference(_voiceStartedAt!).inSeconds); });
      _voiceAmplitudeSub?.cancel();
      _voiceAmplitudeSub = _voiceRecorder.onAmplitudeChanged(const Duration(milliseconds: 120)).listen((a) {
        if (!mounted) return;
        final normalized = ((a.current + 60) / 60).clamp(0.06, 1.0).toDouble();
        setState(() { voiceAmplitude = normalized; voiceWaveform.add(normalized); if (voiceWaveform.length > 34) voiceWaveform.removeAt(0); });
      });
      if (mounted) setState(() { recordingVoice=true; voiceLocked=false; voiceCancelArmed=false; voiceSeconds=0; voiceWaveform=[]; voiceAmplitude=.08; });
    } catch(e) { if(mounted) showMsg(context,'شروع ضبط ویس ناموفق بود: $e'); }
  }

  Future<void> _finishVoiceRecording({bool cancel=false}) async {
    if (!recordingVoice) return;
    _voiceTimer?.cancel(); await _voiceAmplitudeSub?.cancel();
    final path = await _voiceRecorder.stop();
    if (mounted) setState(() { recordingVoice=false; voiceLocked=false; voiceCancelArmed=false; });
    if (cancel || path==null || path.isEmpty) return;
    try {
      final file=File(path); final bytes=await file.readAsBytes();
      if(bytes.isEmpty) throw Exception('فایل ویس خالی است');
      setState(()=>sending=true);
      final storagePath='${widget.id}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await supabase.storage.from('chat-media').uploadBinary(storagePath,bytes,fileOptions:const FileOptions(contentType:'audio/mp4',upsert:false));
      final msg=await supabase.from('messages').insert({'conversation_id':widget.id,'sender_id':supabase.auth.currentUser!.id,'body':'پیام صوتی','message_type':'audio','reply_to':replyMessage?['id']}).select().single();
      await supabase.from('message_attachments').insert({'message_id':msg['id'],'storage_path':storagePath,'file_name':storagePath.split('/').last,'mime_type':'audio/mp4','file_size':bytes.length,'duration_ms':voiceSeconds*1000});
      if(mounted)setState(()=>replyMessage=null); try{await file.delete();}catch(_){}
      await load();
    }catch(e){if(mounted)showMsg(context,'ارسال ویس ناموفق بود: $e');}
    finally{if(mounted)setState(()=>sending=false);}
  }

  Future<void> toggleVoiceRecording() async {
    if (recordingVoice) { await _finishVoiceRecording(); } else { await _startVoiceRecording(); }
  }


  Future<void> sendCameraImage() async {
    if (sending) return;
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 88, maxWidth: 1800, maxHeight: 1800);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) throw Exception('تصویر خالی است');
      final path = '${widget.id}/${DateTime.now().millisecondsSinceEpoch}_camera_${image.name}';
      setState(() => sending = true);
      await supabase.storage.from('chat-media').uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false));
      final msg = await supabase.from('messages').insert({'conversation_id': widget.id, 'sender_id': supabase.auth.currentUser!.id, 'body': image.name, 'message_type': 'image', 'reply_to': replyMessage?['id']}).select().single();
      await supabase.from('message_attachments').insert({'message_id': msg['id'], 'storage_path': path, 'file_name': image.name, 'mime_type': 'image/jpeg', 'file_size': bytes.length});
      if (mounted) setState(() => replyMessage = null);
      await load();
    } catch (e) { if (mounted) showMsg(context, 'ارسال عکس دوربین ناموفق بود: $e'); }
    finally { if (mounted) setState(() => sending = false); }
  }

  Future<void> _showAttachmentPanel() async {
    await showModalBottomSheet<void>(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true, showDragHandle: false,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30), bottom: Radius.circular(24)),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22), child: Container(
            decoration: BoxDecoration(color: scheme.surface.withValues(alpha: .94), border: Border.all(color: scheme.onSurface.withValues(alpha: .08))),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 42, height: 4, decoration: BoxDecoration(color: scheme.onSurface.withValues(alpha: .22), borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 18),
              Row(children: [Expanded(child: Text('افزودن به پیام', textAlign: TextAlign.right, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded))]),
              GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 3, mainAxisSpacing: 16, crossAxisSpacing: 12, childAspectRatio: 1.05, children: [
                _attachmentItem(sheetContext, Icons.photo_library_rounded, 'گالری', () { Navigator.pop(sheetContext); sendImage(); }),
                _attachmentItem(sheetContext, Icons.camera_alt_rounded, 'دوربین', () { Navigator.pop(sheetContext); sendCameraImage(); }),
                _attachmentItem(sheetContext, Icons.insert_drive_file_rounded, 'فایل‌ها', () { Navigator.pop(sheetContext); sendFile(); }),
                _attachmentItem(sheetContext, Icons.music_note_rounded, 'موسیقی / صدا', () { Navigator.pop(sheetContext); sendFile(); }),
                _attachmentItem(sheetContext, Icons.emoji_emotions_rounded, 'اموجی', () { Navigator.pop(sheetContext); _showChatEmojiPicker(); }),
              ]),
            ]),
          )),
        ));
      },
    );
  }

  Widget _attachmentItem(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(borderRadius: BorderRadius.circular(24), onTap: onTap, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 68, height: 68, decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: .72), shape: BoxShape.circle), child: Icon(icon, size: 32, color: scheme.primary)),
      const SizedBox(height: 8), Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
    ]));
  }
  Future<void> sendImage() async {
    if (sending) return;
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1800, maxHeight: 1800);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) throw Exception('تصویر خالی است');
      final path = '${widget.id}/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      setState(() => sending = true);
      await supabase.storage.from('chat-media').uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false));
      final msg = await supabase.from('messages').insert({
        'conversation_id': widget.id,
        'sender_id': supabase.auth.currentUser!.id,
        'body': image.name,
        'message_type': 'image',
        'reply_to': replyMessage?['id'],
      }).select().single();
      await supabase.from('message_attachments').insert({
        'message_id': msg['id'],
        'storage_path': path,
        'file_name': image.name,
        'mime_type': 'image/jpeg',
        'file_size': bytes.length,
      });
      if (mounted) setState(() => replyMessage = null);
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'تصویر ارسال نشد: $e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _showChatEmojiPicker() async {
    const emojis = [
      '😀','😁','😂','🤣','😊','😍','🥰','😘','😎','🤩',
      '😢','😭','😡','😮','🤔','🙌','👏','🙏','👍','👎',
      '❤️','🧡','💛','💚','💙','💜','🖤','🤍','💔','❤️‍🔥',
      '🔥','✨','🎉','🎊','💯','⭐','⚡','🚀','🌹','☀️',
      '😇','🤗','😴','🤝','👀','💪','🫶','🦋','🎵','🍀',
    ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: .88),
                border: Border(top: BorderSide(color: scheme.onSurface.withValues(alpha: .10))),
              ),
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: emojis.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1,
                ),
                itemBuilder: (_, i) => InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.pop(sheetContext, emojis[i]),
                  child: Center(child: Text(emojis[i], style: const TextStyle(fontSize: 28))),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (selected != null && mounted) {
      final value = text.text;
      final selection = text.selection;
      final start = selection.start < 0 ? value.length : selection.start;
      final end = selection.end < 0 ? value.length : selection.end;
      text.value = TextEditingValue(
        text: value.replaceRange(start, end, selected),
        selection: TextSelection.collapsed(offset: start + selected.length),
      );
    }
  }

  Future<void> reactTo(Map<String, dynamic> message, String emoji) async {
    final uid = supabase.auth.currentUser!.id;
    try {
      final current = (reactions['${message['id']}'] ?? const <Map<String, dynamic>>[]).where((r) => r['user_id'] == uid).toList();
      if (current.isNotEmpty && current.first['reaction'] == emoji) {
        await supabase.from('message_reactions').delete().match({'message_id': message['id'], 'user_id': uid});
      } else {
        await supabase.from('message_reactions').upsert({'message_id': message['id'], 'user_id': uid, 'reaction': emoji});
      }
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'واکنش ذخیره نشد: $e');
    }
  }

  void setReply(Map<String, dynamic> message) {
    setState(() => replyMessage = message);
  }

  Future<void> editMessage(Map<String, dynamic> message) async {
    if (message['sender_id'] != supabase.auth.currentUser?.id || message['message_type'] != 'text') return;
    final controller = TextEditingController(text: message['body']?.toString() ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ویرایش پیام'),
        content: TextField(controller: controller, autofocus: true, maxLines: 5),
        actions: [
          IconButton(
            onPressed: () => _startChatCall(video: false),
            tooltip: 'تماس صوتی',
            icon: const Icon(Icons.call_rounded),
          ),
          IconButton(
            onPressed: () => _startChatCall(video: true),
            tooltip: 'تماس تصویری',
            icon: const Icon(Icons.videocam_rounded),
          ),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('ذخیره')),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty || value == (message['body']?.toString() ?? '')) return;
    try {
      await supabase.from('messages').update({
        'body': value,
        'edited_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', message['id']).eq('sender_id', supabase.auth.currentUser!.id);
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'ویرایش پیام ناموفق بود: $e');
    }
  }

  Future<void> deleteForMe(Map<String, dynamic> message) async {
    try {
      await supabase.from('message_user_deletions').upsert({
        'message_id': message['id'],
        'user_id': supabase.auth.currentUser!.id,
      });
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'حذف برای من ناموفق بود: $e');
    }
  }

  Future<void> deleteForEveryone(Map<String, dynamic> message) async {
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

  Future<void> saveMessage(Map<String, dynamic> message) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await supabase.from('saved_messages').upsert({
        'user_id': uid,
        'source_message_id': message['id'],
        'body': message['body'],
        'message_type': message['message_type'] ?? 'text',
      }, onConflict: 'user_id,source_message_id');
      if (mounted) showMsg(context, 'پیام ذخیره شد.');
    } catch (e) {
      if (mounted) showMsg(context, 'ذخیره پیام ناموفق بود. جدول saved_messages را در Supabase اجرا کنید.');
    }
  }

  Future<void> shareMessage(Map<String, dynamic> message) async {
    final body = "${message['body'] ?? ''}".trim();
    if (body.isEmpty) return;
    try {
      await Share.share(body);
    } catch (e) {
      if (mounted) showMsg(context, 'اشتراک‌گذاری ناموفق بود: $e');
    }
  }

  Future<void> copyMessageLink(Map<String, dynamic> message) async {
    final link = "arad://chat/${widget.id}/message/${message['id']}";
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) showMsg(context, 'لینک پیام کپی شد.');
  }

  Future<void> forwardMessage(Map<String, dynamic> message) async {
    final body = message['body']?.toString().trim() ?? '';
    if (body.isEmpty || message['deleted_at'] != null) {
      if (mounted) showMsg(context, 'این پیام قابل فوروارد نیست.');
      return;
    }
    try {
      final uid = supabase.auth.currentUser!.id;
      final memberRows = await supabase.from('conversation_members').select('conversation_id').eq('user_id', uid);
      final ids = (memberRows as List).map((e) => e['conversation_id']).where((id) => id != null).toList();
      if (ids.isEmpty) {
        if (mounted) showMsg(context, 'گفتگویی برای فوروارد وجود ندارد.');
        return;
      }
      final rows = await supabase.from('conversations').select('id,title,type,created_at').inFilter('id', ids).order('created_at', ascending: false);
      final rawTargets = List<Map<String, dynamic>>.from(rows).where((c) => '${c['id']}' != '${widget.id}').toList();
      final targets = <Map<String, dynamic>>[];
      for (final c in rawTargets) {
        var displayTitle = '${c['title'] ?? ''}'.trim();
        if (displayTitle.isEmpty && '${c['type']}' == 'direct') {
          final other = await supabase.from('conversation_members').select('user_id').eq('conversation_id', c['id']).neq('user_id', uid).maybeSingle();
          if (other != null) {
            final p = await supabase.from('profiles').select('display_name,username').eq('id', other['user_id']).maybeSingle();
            displayTitle = '${p?['display_name'] ?? p?['username'] ?? 'کاربر'}';
          }
        }
        if (displayTitle.isEmpty) {
          final type = '${c['type']}';
          displayTitle = type == 'group' ? 'گروه' : type == 'channel' ? 'کانال' : 'گفتگو';
        }
        targets.add({...c, '_display_title': displayTitle});
      }
      if (targets.isEmpty) {
        if (mounted) showMsg(context, 'گفتگوی دیگری برای فوروارد پیدا نشد.');
        return;
      }

      final target = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        showDragHandle: true,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .62,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('ارسال فوروارد به...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: targets.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (_, index) {
                      final c = targets[index];
                      final type = '${c['type']}';
                      final title = '${c['_display_title'] ?? c['title'] ?? (type == 'group' ? 'گروه' : type == 'channel' ? 'کانال' : 'گفتگو')}';
                      final icon = type == 'group' ? Icons.group_rounded : type == 'channel' ? Icons.campaign_rounded : Icons.person_rounded;
                      return ListTile(
                        leading: CircleAvatar(child: Icon(icon)),
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(type == 'group' ? 'گروه' : type == 'channel' ? 'کانال' : 'گفتگوی شخصی'),
                        trailing: const Icon(Icons.chevron_left_rounded),
                        onTap: () => Navigator.pop(sheetContext, c),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (target == null) return;

      final inserted = await supabase.from('messages').insert({
        'conversation_id': target['id'],
        'sender_id': uid,
        'body': body,
        'message_type': message['message_type'] ?? 'text',
        'reply_to': null,
      }).select().single();

      final type = '${message['message_type'] ?? 'text'}';
      if (type != 'text') {
        final attachment = await supabase.from('message_attachments')
            .select('storage_path,file_name,file_size,mime_type')
            .eq('message_id', message['id'])
            .maybeSingle();
        if (attachment != null) {
          await supabase.from('message_attachments').insert({
            'message_id': inserted['id'],
            'storage_path': attachment['storage_path'],
            'file_name': attachment['file_name'],
            'file_size': attachment['file_size'],
            'mime_type': attachment['mime_type'],
          });
        }
      }

      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatPage(id: '${target['id']}', title: '${target['_display_title'] ?? target['title'] ?? 'گفتگو'}'),
        ));
        showMsg(context, 'پیام با موفقیت فوروارد شد.');
      }
    } catch (e) {
      if (mounted) showMsg(context, 'فوروارد پیام ناموفق بود: $e');
    }
  }

  Future<void> showMessageActions(Map<String, dynamic> message) async {
    const emojis = ['❤️', '😁', '💘', '👍', '👎', '🔥', '🥰'];
    final scheme = Theme.of(context).colorScheme;
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'عملیات پیام',
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF20384A),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: _messageActionsContent(context, message),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .18),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: .96, end: 1).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _messageActionsContent(BuildContext context, Map<String, dynamic> message) {
    const emojis = ['❤️', '👍', '😂', '🔥', '😍'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 8),
        Row(children: [
          const Expanded(child: Text('واکنش و گزینه‌ها', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white70)),
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha:.14), borderRadius: BorderRadius.circular(28)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            ...emojis.map((e) => InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () { Navigator.pop(context); reactTo(message, e); },
              child: Padding(padding: const EdgeInsets.all(6), child: Text(e, style: const TextStyle(fontSize: 26))),
            )),
            IconButton(onPressed: () { Navigator.pop(context); _showMoreReactions(message); }, icon: const Icon(Icons.add_reaction_outlined, color: Colors.white)),
          ]),
        ),
        const SizedBox(height: 6),
        _actionTile(context, Icons.reply_rounded, 'پاسخ دادن', () => setReply(message)),
        _actionTile(context, Icons.forward_rounded, 'فوروارد', () => forwardMessage(message)),
        _actionTile(context, Icons.share_rounded, 'اشتراک‌گذاری', () => shareMessage(message)),
        if (message['sender_id'] == supabase.auth.currentUser?.id && message['message_type'] == 'text')
          _actionTile(context, Icons.edit_outlined, 'ویرایش', () => editMessage(message)),
        _actionTile(context, Icons.bookmark_add_outlined, 'ذخیره', () => saveMessage(message)),
        _actionTile(context, Icons.delete_outline_rounded, 'حذف برای من', () => deleteForMe(message)),
        if (message['sender_id'] == supabase.auth.currentUser?.id)
          _actionTile(context, Icons.delete_forever_outlined, 'حذف برای همه', () => deleteForEveryone(message)),
      ]),
    );
  }

  Future<void> _showMoreReactions(Map<String, dynamic> message) async {
    const more = ['😂','😍','😎','😢','😡','👏','🎉','❤️‍🔥','💯','🙏','🤝','👀','🚀','⭐','⚡','😮'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 5,
          padding: const EdgeInsets.all(18),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: more
              .map((e) => InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(context, e),
                    child: Center(child: Text(e, style: const TextStyle(fontSize: 30))),
                  ))
              .toList(),
        ),
      ),
    );
    if (selected != null) await reactTo(message, selected);
  }

  Future<void> _showMessageInfo(Map<String, dynamic> message) async {
    final created = message['created_at']?.toString() ?? 'نامشخص';
    final edited = message['edited_at'] != null;
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('اطلاعات پیام'), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('فرستنده: ' + _senderName(message)), const SizedBox(height: 8), Text('نوع: ' + (message['message_type']?.toString() ?? 'text')), const SizedBox(height: 8), Text('زمان ارسال: ' + created), if (edited) ...[const SizedBox(height: 8), const Text('وضعیت: ویرایش شده')]]), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('بستن'))]));
  }
  Widget _actionTile(
    BuildContext sheetContext,
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    return ListTile(
      dense: true,
      enabled: enabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(icon, color: enabled ? Colors.white : Colors.white38, size: 27),
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? Colors.white : Colors.white38,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: enabled
          ? () {
              Navigator.pop(sheetContext);
              onTap();
            }
          : null,
    );
  }

  Widget _replyPreview(Map<String, dynamic> message) {
    final id = '${message['reply_to'] ?? ''}';
    if (id.isEmpty) return const SizedBox.shrink();
    Map<String, dynamic>? parent;
    for (final item in messages) {
      if ('${item['id']}' == id) {
        parent = item;
        break;
      }
    }
    if (parent == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
      child: Text('${_senderName(parent!)}: ${parent['body'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
    );
  }

  Widget _reactionRow(Map<String, dynamic> message) {
    final list = reactions['${message['id']}'] ?? const <Map<String, dynamic>>[];
    if (list.isEmpty) return const SizedBox.shrink();
    final counts = <String, int>{};
    for (final r in list) {
      final emoji = '${r['reaction']}';
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Wrap(
        spacing: 4,
        children: counts.entries.map((e) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => reactTo(message, e.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
            child: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 12)),
          ),
        )).toList(),
      ),
    );
  }

  Widget _imageAttachment(Map<String, dynamic> m) {
    final a = attachments['${m['id']}'];
    final path = a?['storage_path']?.toString() ?? '';
    if (path.isEmpty) return const Icon(Icons.image_rounded, size: 42);
    return FutureBuilder<String?>(
      future: _attachmentUrl(path),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(width: 190, height: 150, child: Center(child: CircularProgressIndicator()));
        final url = snapshot.data;
        if (url == null || url.isEmpty) return const Icon(Icons.broken_image_rounded, size: 42);
        return GestureDetector(
          onTap: () => _openImage(m),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              width: 220,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(width: 220, height: 120, child: Center(child: Icon(Icons.broken_image_rounded, size: 42))),
            ),
          ),
        );
      },
    );
  }

  Widget _fileAttachment(Map<String, dynamic> m) {
    final a = attachments['${m['id']}'];
    final name = (a?['file_name'] ?? m['body'] ?? 'فایل').toString();
    final mime = (a?['mime_type'] ?? '').toString();
    final icon = mime.startsWith('audio/') ? Icons.music_note_rounded : mime == 'application/pdf' ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 32),
      const SizedBox(width: 8),
      Flexible(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
    ]);
  }

  Widget _glassMessageBubble(Map<String, dynamic> m) {
    final mine = m['sender_id'] == supabase.auth.currentUser!.id;
    final sender = _senderName(m);
    final avatarUrl = profiles['${m['sender_id']}']?['avatar_url']?.toString() ?? '';
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final myBubble = const Color(0xFFB85A86);
    final otherBubble = dark ? const Color(0xFF24272C) : const Color(0xFFF0F1F4);
    final textColor = mine
        ? (ThemeData.estimateBrightnessForColor(myBubble) == Brightness.dark ? Colors.white : Colors.black)
        : (dark ? Colors.white : const Color(0xFF20242A));
    final body = (m['body'] ?? '').toString();
    final urlMatch = RegExp(r'https?://\S+').firstMatch(body);
    final isGroup = _chatType != 'direct';

    Widget content;
    if (m['message_type'] == 'image') {
      content = _imageAttachment(m);
    } else if (m['message_type'] == 'audio') {
      content = _voicePlayButton(m['id'].toString());
    } else if (m['message_type'] == 'file') {
      content = _fileAttachment(m);
    } else if (urlMatch != null && urlMatch.start == 0) {
      final url = urlMatch.group(0)!;
      content = Container(
        width: 235,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (mine ? Colors.white : scheme.primary).withValues(alpha: .10),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: double.infinity, height: 92, decoration: BoxDecoration(color: mine ? Colors.white.withValues(alpha:.12) : scheme.primary.withValues(alpha:.08), borderRadius: BorderRadius.circular(12)), child: const Center(child: Icon(Icons.language_rounded, size: 34))),
            const SizedBox(height: 8),
            Text('پیش‌نمایش لینک', style: TextStyle(fontWeight: FontWeight.w800, color: textColor)),
            const SizedBox(height: 2),
            Text(Uri.tryParse(url)?.host ?? 'لینک', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: mine ? Colors.white70 : scheme.primary)),
          ],
        ),
      );
    } else {
      content = Text(body, style: TextStyle(fontSize: 15.5, height: 1.38, color: textColor));
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => showMessageActions(m),
        onDoubleTap: () => reactTo(m, '❤️'),
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0).abs() > 450) setReply(m);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!mine && isGroup) ...[
              CircleAvatar(
                radius: 16,
                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 17) : null,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .84),
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.fromLTRB(13, 9, 11, 7),
                decoration: BoxDecoration(
                  color: mine ? myBubble : otherBubble,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(mine ? 20 : 5),
                    bottomRight: Radius.circular(mine ? 5 : 20),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: dark ? .22 : .08), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!mine && isGroup)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(sender, style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary)),
                      ),
                    _replyPreview(m),
                    content,
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${_dateLabel(m['created_at'])}  ${_time(m['created_at'])}', style: TextStyle(fontSize: 10.5, color: mine ? textColor.withValues(alpha: .75) : scheme.onSurfaceVariant)),
                        if (mine) ...[
                          const SizedBox(width: 4),
                          Icon(m['read_at'] != null ? Icons.done_all_rounded : Icons.done_rounded, size: 15, color: m['read_at'] != null ? const Color(0xFF62B7FF) : textColor.withValues(alpha: .7)),
                        ],
                      ],
                    ),
                    _reactionRow(m),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    appTheme.addListener(_onAppThemeChanged);
    load();
    _loadChatType().then((_) => _loadGroupMemberCount());
    channel = supabase.channel('chat-${widget.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: widget.id),
        callback: (_) => load(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: widget.id),
        callback: (_) => load(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'message_user_deletions',
        callback: (_) => load(),
      )
      .subscribe();  }

  void _onAppThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appTheme.removeListener(_onAppThemeChanged);
    if (channel != null) supabase.removeChannel(channel!);
    _voiceRecorder.dispose();
    _voicePlayer.dispose();
    _messagesScroll.dispose();
    text.dispose();
    super.dispose();
  }

  Future<bool> _isGroupAdmin() async {
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
  Future<void> _openGroupManagement() async {
    if (!await _isGroupAdmin()) { if(mounted) showMsg(context,'فقط مدیر گروه یا کانال می‌تواند مدیریت کند.'); return; }
    if (mounted) await Navigator.push(context,MaterialPageRoute(builder:(_)=>GroupManagementPage(conversationId:widget.id,title:widget.title)));
  }

  void _startChatCall({required bool video}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallSessionPage(
          conversationId: widget.id,
          title: widget.title,
          video: video,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: scheme.onSurface.withValues(alpha: .07))),
        actions: [
          FutureBuilder<bool>(
            future: _isGroupAdmin(),
            builder: (_,snap) => snap.data==true
                ? IconButton(onPressed:_openGroupManagement,tooltip:'مدیریت گروه/کانال',icon:const Icon(Icons.admin_panel_settings_rounded))
                : const SizedBox.shrink(),
          ),
        ],
        title: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            if (_chatType == 'group') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => GroupProfilePage(conversationId: widget.id, title: widget.title)));
            } else if (_chatType == 'channel') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelManagementPage(conversationId: widget.id, title: widget.title)));
            }
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundImage: _chatType == 'direct' && _peerAvatarUrl.isNotEmpty ? NetworkImage(_peerAvatarUrl) : null,
                child: _chatType == 'direct' && _peerAvatarUrl.isNotEmpty ? null : Icon(_chatType == 'group' ? Icons.groups_rounded : Icons.person_rounded, size: 18),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: Text(widget.title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                        if (_chatType == 'direct' && _peerVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 17, color: Color(0xFF2F9BFF)),
                        ],
                      ],
                    ),
                    if (_chatType == 'group')
                      Text('$_groupMemberCount عضو', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                    if (_chatType == 'channel')
                      const Text('مدیریت کانال', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ), // GROUP_PROFILE_WIRED
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Color(appTheme.backgroundSeed),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(appTheme.backgroundSeed).withValues(alpha: .98),
              Color(appTheme.backgroundSeed).withValues(alpha: .90),
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : messages.isEmpty
                      ? const Center(child: Text('هنوز پیامی وجود ندارد.'))
                      : NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n is ScrollUpdateNotification && n.metrics.pixels <= n.metrics.minScrollExtent + 240) {
                              _loadOlderMessages();
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: _messagesScroll,
                            physics: const BouncingScrollPhysics(),
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                            reverse: false,
                            itemCount: messages.length,
                            itemBuilder: (context, i) => _glassMessageBubble(messages[i]),
                          ),
                        ),
            ),
            if (replyMessage != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: .78),
                      border: Border(top: BorderSide(color: scheme.onSurface.withValues(alpha: .08))),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.reply_rounded, size: 20, color: scheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_senderName(replyMessage!)}: ${replyMessage!['body'] ?? ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => replyMessage = null),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 5, 8, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF20242A) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: scheme.onSurface.withValues(alpha: .10)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .10),
                            blurRadius: 18,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: _showAttachmentPanel,
                            tooltip: 'پیوست‌ها',
                            icon: Icon(Icons.add_circle_outline_rounded, color: scheme.primary, size: 27),
                          ),
                          IconButton(
                            onPressed: toggleVoiceRecording,
                            tooltip: recordingVoice ? 'توقف و ارسال ویس' : 'ضبط ویس',
                            icon: Icon(
                              recordingVoice ? Icons.stop_circle_rounded : Icons.mic_rounded,
                              color: recordingVoice ? scheme.error : scheme.primary,
                            ),
                          ),
                          IconButton(
                            onPressed: _showChatEmojiPicker,
                            tooltip: 'اموجی',
                            icon: Icon(Icons.emoji_emotions_rounded, color: scheme.primary),
                          ),
                          Expanded(
                            child: TextField(
                              controller: text,
                              minLines: 1,
                              maxLines: 5,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(
                                hintText: 'پیام...',
                                filled: true,
                                fillColor: scheme.surface.withValues(alpha: .48),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(19),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          IconButton.filled(
                            onPressed: sending ? null : sendText,
                            icon: const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }}