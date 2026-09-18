import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class E2eeService {
  E2eeService(this.supabase);
  final SupabaseClient supabase;
  static const storage = FlutterSecureStorage();
  static const privateName = 'arad_e2ee_x25519_private_v1';
  static const publicName = 'arad_e2ee_x25519_public_v1';
  final X25519 x25519 = X25519();
  final AesGcm aes = AesGcm.with256bits();

  Future<SimpleKeyPairData> identity() async {
    final pr = await storage.read(key: privateName);
    final pu = await storage.read(key: publicName);
    if (pr != null && pu != null) {
      return SimpleKeyPairData(
        base64Url.decode(pr),
        publicKey: SimplePublicKey(base64Url.decode(pu), type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );
    }
    final pair = await x25519.newKeyPair();
    final data = await pair.extract();
    final pub = await pair.extractPublicKey();
    await storage.write(key: privateName, value: base64UrlEncode(data.bytes));
    await storage.write(key: publicName, value: base64UrlEncode(pub.bytes));
    return data;
  }

  Future<void> ensureIdentity() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('ابتدا وارد حساب شوید.');
    final pair = await identity();
    final pub = await pair.extractPublicKey();
    await supabase.from('e2ee_identity_keys').upsert({
      'user_id': uid,
      'public_key': base64UrlEncode(pub.bytes),
      'key_version': 1,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<String> fingerprint(String publicKey) async {
    final hash = await Sha256().hash(base64Url.decode(publicKey));
    return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().substring(0, 16).toUpperCase();
  }

  Future<SecretKey> conversationKey(String conversationId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('جلسه کاربر منقضی شده است.');
    await ensureIdentity();
    final members = List<Map<String,dynamic>>.from(await supabase.from('conversation_members').select('user_id').eq('conversation_id', conversationId));
    final peerId = members.map((m) => m['user_id'].toString()).firstWhere((id) => id != uid, orElse: () => '');
    if (peerId.isEmpty) throw Exception('Secret Chat فقط برای گفتگوی دونفره فعال است.');
    final row = await supabase.from('e2ee_identity_keys').select('public_key').eq('user_id', peerId).maybeSingle();
    final value = row?['public_key']?.toString();
    if (value == null || value.isEmpty) throw Exception('طرف مقابل هنوز Secret Chat را فعال نکرده است.');
    final pair = await identity();
    final remote = SimplePublicKey(base64Url.decode(value), type: KeyPairType.x25519);
    final shared = await x25519.sharedSecretKey(keyPair: pair, remotePublicKey: remote);
    final sharedBytes = await shared.extractBytes();
    final ctx = utf8.encode('AradMessenger-E2EE-v1:' + conversationId);
    final digest = await Sha256().hash(<int>[...sharedBytes, ...ctx]);
    return SecretKey(digest.bytes);
  }

  Future<String> encrypt(String conversationId, String text) async {
    final box = await aes.encryptString(text, secretKey: await conversationKey(conversationId));
    return base64UrlEncode(box.concatenation());
  }

  Future<String> decrypt(String conversationId, String encoded) async {
    final box = SecretBox.fromConcatenation(
      base64Url.decode(encoded),
      nonceLength: aes.nonceLength,
      macLength: aes.macAlgorithm.macLength,
    );
    return aes.decryptString(box, secretKey: await conversationKey(conversationId));
  }
}

class SecretChatPage extends StatefulWidget {
  final String conversationId;
  final String title;
  const SecretChatPage({super.key, required this.conversationId, required this.title});
  @override State<SecretChatPage> createState() => _SecretChatPageState();
}

class _SecretChatPageState extends State<SecretChatPage> {
  final supabase = Supabase.instance.client;
  late final E2eeService e2ee = E2eeService(supabase);
  final input = TextEditingController();
  final scroll = ScrollController();
  RealtimeChannel? channel;
  List<Map<String,dynamic>> messages = [];
  bool loading = true;
  bool sending = false;
  String? error;
  String? keyFingerprint;

  @override void initState() { super.initState(); start(); }

  Future<void> start() async {
    try {
      await e2ee.ensureIdentity();
      final uid = supabase.auth.currentUser!.id;
      final members = List<Map<String,dynamic>>.from(await supabase.from('conversation_members').select('user_id').eq('conversation_id', widget.conversationId));
      final peerId = members.map((m) => m['user_id'].toString()).firstWhere((id) => id != uid, orElse: () => '');
      if (peerId.isEmpty) throw Exception('این گفتگو دونفره نیست.');
      final peer = await supabase.from('e2ee_identity_keys').select('public_key').eq('user_id', peerId).maybeSingle();
      final publicKey = peer?['public_key']?.toString();
      if (publicKey == null || publicKey.isEmpty) throw Exception('طرف مقابل باید یک‌بار Secret Chat را باز کند.');
      keyFingerprint = await e2ee.fingerprint(publicKey);
      await loadMessages();
      channel = supabase.channel('secret-' + widget.conversationId)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'secret_messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: widget.conversationId),
          callback: (_) => loadMessages(),
        ).subscribe();
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> loadMessages() async {
    final rows = await supabase.from('secret_messages').select('id,sender_id,ciphertext,created_at').eq('conversation_id', widget.conversationId).order('created_at');
    final decoded = <Map<String,dynamic>>[];
    for (final row in List<Map<String,dynamic>>.from(rows)) {
      try {
        decoded.add({...row, '_text': await e2ee.decrypt(widget.conversationId, row['ciphertext'].toString())});
      } catch (_) {
        decoded.add({...row, '_text': 'پیام رمزگذاری‌شده قابل بازیابی نیست'});
      }
    }
    if (!mounted) return;
    setState(() => messages = decoded);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
    });
  }

  Future<void> send() async {
    final text = input.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      final ciphertext = await e2ee.encrypt(widget.conversationId, text);
      await supabase.from('secret_messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': supabase.auth.currentUser!.id,
        'ciphertext': ciphertext,
      });
      input.clear();
      await loadMessages();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override void dispose() {
    input.dispose();
    scroll.dispose();
    if (channel != null) supabase.removeChannel(channel!);
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [const Icon(Icons.lock_rounded, size: 20), const SizedBox(width: 8), Expanded(child: Text(widget.title))]),
        actions: [
          if (keyFingerprint != null) IconButton(
            tooltip: 'اثر انگشت کلید',
            icon: const Icon(Icons.verified_user_rounded),
            onPressed: () => showDialog(context: context, builder: (_) => AlertDialog(
              title: const Text('اثر انگشت کلید امنیتی'),
              content: SelectableText(keyFingerprint!),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن'))],
            )),
          ),
        ],
      ),
      body: loading ? const Center(child: CircularProgressIndicator()) :
        error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline_rounded, size: 56),
          const SizedBox(height: 14),
          Text(error!, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: start, icon: const Icon(Icons.refresh_rounded), label: const Text('تلاش دوباره')),
        ]))) :
        Column(children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: .35), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(Icons.shield_rounded, color: scheme.primary),
              const SizedBox(width: 10),
              const Expanded(child: Text('پیام‌ها قبل از ارسال روی دستگاه رمزگذاری می‌شوند و سرور فقط متن رمز‌شده را دریافت می‌کند.')),
            ]),
          ),
          Expanded(child: ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.all(12),
            itemCount: messages.length,
            itemBuilder: (_, i) {
              final m = messages[i];
              final mine = m['sender_id'].toString() == supabase.auth.currentUser?.id;
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 340),
                  margin: const EdgeInsets.only(bottom: 7),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
                  child: Text(m['_text']?.toString() ?? ''),
                ),
              );
            },
          )),
          SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(10, 4, 10, 10), child: Row(children: [
            Expanded(child: TextField(controller: input, minLines: 1, maxLines: 5, textDirection: TextDirection.rtl, decoration: const InputDecoration(hintText: 'پیام محرمانه...', prefixIcon: Icon(Icons.lock_rounded)), onSubmitted: (_) => send())),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: sending ? null : send, icon: const Icon(Icons.send_rounded)),
          ]))),
        ]),
    );
  }
}
