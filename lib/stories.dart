import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

final _storiesSupabase = Supabase.instance.client;

class StoriesTray extends StatefulWidget {
  const StoriesTray({super.key});
  @override
  State<StoriesTray> createState() => _StoriesTrayState();
}

class _StoriesTrayState extends State<StoriesTray> {
  List<Map<String, dynamic>> _stories = [];
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = _storiesSupabase.channel('stories-tray-${_storiesSupabase.auth.currentUser?.id ?? 'guest'}')
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'stories', callback: (_) => _load())
      .subscribe();
  }

  Future<void> _load() async {
    try {
      final rows = await _storiesSupabase.from('stories').select('id,user_id,media_path,media_type,caption,audience,created_at,expires_at')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String()).inFilter('media_type', ['image','video']).order('created_at', ascending: false).limit(40);
      final list = List<Map<String, dynamic>>.from(rows);
      final ids = list.map((e) => e['user_id'].toString()).toSet().toList();
      final profiles = <String, Map<String, dynamic>>{};
      if (ids.isNotEmpty) {
        final p = await _storiesSupabase.from('profiles').select('id,full_name,username,avatar_url').inFilter('id', ids);
        for (final row in List<Map<String, dynamic>>.from(p)) profiles[row['id'].toString()] = row;
      }
      for (final row in list) row['profile'] = profiles[row['user_id'].toString()] ?? {};
      if (mounted) setState(() => _stories = list);
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_channel != null) _storiesSupabase.removeChannel(_channel!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, Map<String, dynamic>>{};
    for (final s in _stories) grouped.putIfAbsent(s['user_id'].toString(), () => s);
    return SizedBox(height: 106, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 8, 12, 8), children: [
      _StoryAddTile(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StoriesPage())).then((_) => _load())),
      ...grouped.values.map((story) => _StoryTile(story: story, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoriesPage(initialStoryId: story['id'].toString()))).then((_) => _load()))),
    ]));
  }
}

class _StoryAddTile extends StatelessWidget {
  final VoidCallback onTap;
  const _StoryAddTile({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: SizedBox(width: 76, child: Column(children: [
    Container(width: 62, height: 62, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary.withValues(alpha:.18), Theme.of(context).colorScheme.secondary.withValues(alpha:.10)]), border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha:.75), width: 2), boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha:.16), blurRadius: 12)]), child: const Icon(Icons.add_rounded, size: 30)),
    const SizedBox(height: 5), const Text('استوری من', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))
  ])));
}

class _StoryTile extends StatelessWidget {
  final Map<String, dynamic> story;
  final VoidCallback onTap;
  const _StoryTile({required this.story, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = Map<String, dynamic>.from(story['profile'] ?? {});
    final name = (p['full_name'] ?? p['username'] ?? 'کاربر').toString();
    final avatar = p['avatar_url']?.toString();
    return GestureDetector(onTap: onTap, child: SizedBox(width: 76, child: Column(children: [
      Container(width: 62, height: 62, padding: const EdgeInsets.all(2), decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary]), boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha:.20), blurRadius: 13)]),
      child: CircleAvatar(backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null, child: avatar == null || avatar.isEmpty ? const Icon(Icons.person) : null)),
      const SizedBox(height: 5), Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))
    ])));
  }
}

class StoriesPage extends StatefulWidget {
  final String? initialStoryId;
  const StoriesPage({super.key, this.initialStoryId});
  @override
  State<StoriesPage> createState() => _StoriesPageState();
}

class _StoriesPageState extends State<StoriesPage> {
  List<Map<String, dynamic>> _stories = [];
  Map<String, String> _urls = {};
  int _index = 0;
  bool _loading = true;
  final Set<String> _likedIds = <String>{};
  final Map<String, int> _likeCounts = <String, int>{};
  final Map<String, int> _commentCounts = <String, int>{};
  Timer? _timer;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = _storiesSupabase.channel('stories-viewer-${_storiesSupabase.auth.currentUser?.id ?? 'guest'}')
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'stories', callback: (_) => _load())
      .subscribe();
  }

  Future<void> _load() async {
    try {
      final rows = await _storiesSupabase.from('stories').select('id,user_id,media_path,media_type,caption,created_at,expires_at')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String()).inFilter('media_type', ['image','video']).order('created_at', ascending: true);
      final stories = List<Map<String, dynamic>>.from(rows);
      final urls = <String, String>{};
      final ids = stories.map((s) => s['id'].toString()).toList();
      final uid = _storiesSupabase.auth.currentUser?.id;
      _likedIds.clear(); _likeCounts.clear(); _commentCounts.clear();
      if (ids.isNotEmpty) {
        try {
          final likes = await _storiesSupabase.from('story_likes').select('story_id,user_id').inFilter('story_id', ids);
          for (final row in List<Map<String,dynamic>>.from(likes)) {
            final id = row['story_id'].toString();
            _likeCounts[id] = (_likeCounts[id] ?? 0) + 1;
            if (row['user_id']?.toString() == uid) _likedIds.add(id);
          }
        } catch (_) {}
        try {
          final comments = await _storiesSupabase.from('story_comments').select('story_id').inFilter('story_id', ids);
          for (final row in List<Map<String,dynamic>>.from(comments)) {
            final id = row['story_id'].toString();
            _commentCounts[id] = (_commentCounts[id] ?? 0) + 1;
          }
        } catch (_) {}
      }
      for (final s in stories) {
        try { urls[s['id'].toString()] = await _storiesSupabase.storage.from('stories').createSignedUrl(s['media_path'].toString(), 3600); } catch (_) {}
      }
      var nextIndex = 0;
      if (widget.initialStoryId != null) {
        final found = stories.indexWhere((s) => s['id'].toString() == widget.initialStoryId);
        if (found >= 0) nextIndex = found;
      }
      if (mounted) { setState(() { _stories = stories; _urls = urls; _index = nextIndex.clamp(0, stories.isEmpty ? 0 : stories.length - 1).toInt(); _loading = false; }); _startTimer(); }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_stories.isEmpty) return;
    _timer = Timer(Duration(seconds: _stories[_index]['media_type'] == 'video' ? 8 : 5), _next);
    _markViewed();
  }

  Future<void> _markViewed() async {
    if (_stories.isEmpty) return;
    final uid = _storiesSupabase.auth.currentUser?.id;
    if (uid == null) return;
    try { await _storiesSupabase.from('story_views').upsert({'story_id': _stories[_index]['id'], 'viewer_id': uid, 'viewed_at': DateTime.now().toUtc().toIso8601String()}); } catch (_) {}
  }

  void _next() {
    if (_stories.isEmpty) return;
    if (_index >= _stories.length - 1) { Navigator.pop(context); return; }
    setState(() => _index++); _startTimer();
  }

  void _previous() {
    if (_stories.isEmpty || _index == 0) return;
    setState(() => _index--); _startTimer();
  }

  Future<void> _toggleCurrentLike() async {
    if (_stories.isEmpty) return;
    final story = _stories[_index];
    final id = story['id'].toString();
    final uid = _storiesSupabase.auth.currentUser?.id;
    if (uid == null) return;
    final wasLiked = _likedIds.contains(id);
    setState(() {
      if (wasLiked) { _likedIds.remove(id); _likeCounts[id] = ((_likeCounts[id] ?? 1) - 1).clamp(0, 1 << 30); }
      else { _likedIds.add(id); _likeCounts[id] = (_likeCounts[id] ?? 0) + 1; }
    });
    try {
      if (wasLiked) {
        await _storiesSupabase.from('story_likes').delete().eq('story_id', story['id']).eq('user_id', uid);
      } else {
        await _storiesSupabase.from('story_likes').insert({'story_id': story['id'], 'user_id': uid});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (wasLiked) { _likedIds.add(id); _likeCounts[id] = (_likeCounts[id] ?? 0) + 1; }
          else { _likedIds.remove(id); _likeCounts[id] = ((_likeCounts[id] ?? 1) - 1).clamp(0, 1 << 30); }
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ثبت پسندیدن انجام نشد.')));
      }
    }
  }

  Future<void> _openComments() async {
    if (_stories.isEmpty) return;
    final story = _stories[_index];
    final id = story['id'].toString();
    final uid = _storiesSupabase.auth.currentUser?.id;
    final controller = TextEditingController();
    List<Map<String,dynamic>> comments = [];
    try {
      final rows = await _storiesSupabase.from('story_comments').select('id,user_id,body,created_at').eq('story_id', story['id']).order('created_at');
      comments = List<Map<String,dynamic>>.from(rows);
    } catch (_) {}
    if (!mounted) { controller.dispose(); return; }
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, setSheetState) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(sheetContext).viewInsets.bottom + 16),
          child: SizedBox(height: MediaQuery.of(sheetContext).size.height * .55, child: Column(children: [
            const Align(alignment: Alignment.centerRight, child: Text('نظرهای استوری', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            const SizedBox(height: 8),
            Expanded(child: comments.isEmpty
              ? const Center(child: Text('هنوز نظری ثبت نشده است.'))
              : ListView.builder(itemCount: comments.length, itemBuilder: (_, i) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                  title: Text(comments[i]['body']?.toString() ?? ''),
                  subtitle: Text(comments[i]['user_id']?.toString() == uid ? 'شما' : 'مخاطب'),
                  dense: true,
                ))),
            Row(children: [
              Expanded(child: TextField(controller: controller, maxLength: 500, decoration: const InputDecoration(hintText: 'نظر بنویس...', counterText: ''))),
              IconButton(icon: const Icon(Icons.send_rounded), onPressed: () async {
                final body = controller.text.trim();
                if (body.isEmpty || uid == null) return;
                try {
                  final row = await _storiesSupabase.from('story_comments').insert({'story_id': story['id'], 'user_id': uid, 'body': body}).select('id,user_id,body,created_at').single();
                  controller.clear();
                  setSheetState(() => comments.add(Map<String,dynamic>.from(row)));
                  if (mounted) setState(() => _commentCounts[id] = (_commentCounts[id] ?? 0) + 1);
                } catch (_) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ثبت نظر انجام نشد؛ ممکن است این استوری برای مخاطبین مجاز باشد.')));
                }
              }),
            ]),
          ])),
        ),
      )),
    );
    controller.dispose();
  }

  Future<void> _shareCurrent() async {
    if (_stories.isEmpty) return;
    final story = _stories[_index];
    final caption = (story['caption'] ?? '').toString().trim();
    final id = story['id'].toString();
    final audience = (story['audience'] ?? 'contacts').toString();
    await Share.share('استوری در پیام‌رسان آراد${caption.isEmpty ? '' : '\n$caption'}\nشناسه استوری: $id\nمحدوده نمایش: ${audience == 'everyone' ? 'همه' : audience == 'private' ? 'خصوصی' : 'مخاطبین'}');
  }

  Future<void> _deleteCurrent() async {
    if (_stories.isEmpty) return;
    final uid = _storiesSupabase.auth.currentUser?.id;
    final s = _stories[_index];
    if (uid != s['user_id'].toString()) return;
    try {
      await _storiesSupabase.from('stories').delete().eq('id', s['id']);
      await _storiesSupabase.storage.from('stories').remove([s['media_path'].toString()]);
      if (!mounted) return;
      if (_stories.length == 1) { Navigator.pop(context); return; }
      setState(() { _stories.removeAt(_index); _index = _index.clamp(0, _stories.length - 1).toInt(); }); _startTimer();
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حذف استوری انجام نشد.'))); }
  }

  @override
  void dispose() { _timer?.cancel(); if (_channel != null) _storiesSupabase.removeChannel(_channel!); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_stories.isEmpty) return Scaffold(appBar: AppBar(title: const Text('استوری‌ها')), body: Center(child: FilledButton.icon(onPressed: _createStory, icon: const Icon(Icons.add), label: const Text('ساخت استوری'))));
    final s = _stories[_index];
    final url = _urls[s['id'].toString()];
    final mine = s['user_id'].toString() == _storiesSupabase.auth.currentUser?.id;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text('استوری'), actions: [if (mine) IconButton(onPressed: _deleteCurrent, icon: const Icon(Icons.delete_outline)), IconButton(onPressed: _createStory, icon: const Icon(Icons.add_circle_outline))]),
      body: GestureDetector(
        onTapUp: (d) => d.localPosition.dx < MediaQuery.of(context).size.width / 2 ? _previous() : _next(),
        child: Stack(fit: StackFit.expand, children: [
          if (url == null) const Center(child: CircularProgressIndicator())
          else if (s['media_type'] == 'video') StoryVideo(url: url)
          else InteractiveViewer(child: Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 48)))),
          Positioned(
            top: 10, left: 12, right: 12,
            child: Row(
              children: List.generate(
                _stories.length,
                (i) => Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i <= _index ? Colors.white : Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 24, left: 16, right: 16,
            child: Row(children: [
              Expanded(child: Text(
                (s['audience'] ?? 'contacts') == 'everyone' ? 'عمومی' : (s['audience'] ?? 'contacts') == 'private' ? 'خصوصی' : 'مخاطبین',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              )),
              IconButton(tooltip: 'پسندیدن', onPressed: _toggleCurrentLike, icon: Icon(_likedIds.contains(s['id'].toString()) ? Icons.favorite : Icons.favorite_border, color: _likedIds.contains(s['id'].toString()) ? Colors.pinkAccent : Colors.white)),
              Text('${_likeCounts[s['id'].toString()] ?? 0}', style: const TextStyle(color: Colors.white)),
              IconButton(tooltip: 'نظرها', onPressed: _openComments, icon: const Icon(Icons.mode_comment_outlined, color: Colors.white)),
              Text('${_commentCounts[s['id'].toString()] ?? 0}', style: const TextStyle(color: Colors.white)),
              IconButton(tooltip: 'اشتراک‌گذاری', onPressed: _shareCurrent, icon: const Icon(Icons.share_outlined, color: Colors.white)),
            ]),
          ),
          if ((s['caption'] ?? '').toString().trim().isNotEmpty)
            Positioned(
              bottom: 30, left: 18, right: 18,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  s['caption'].toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Future<void> _createStory() async {
    final picker = ImagePicker();
    final choice = await showModalBottomSheet<String>(context: context, builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('عکس'), onTap: () => Navigator.pop(c, 'image')),
      ListTile(leading: const Icon(Icons.videocam_outlined), title: const Text('ویدئو'), onTap: () => Navigator.pop(c, 'video'))
    ])));
    if (choice == null) return;
    final file = choice == 'image' ? await picker.pickImage(source: ImageSource.gallery, imageQuality: 90) : await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 1));
    if (file == null) return;
    final audience = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const ListTile(title: Text('چه کسانی استوری را ببینند؟')),
        ListTile(leading: const Icon(Icons.people_alt_outlined), title: const Text('مخاطبین'), subtitle: const Text('افراد داخل مخاطبین یا گفتگوی مشترک'), onTap: () => Navigator.pop(c, 'contacts')),
        ListTile(leading: const Icon(Icons.public_rounded), title: const Text('همه'), subtitle: const Text('استوری عمومی برای کاربران واردشده'), onTap: () => Navigator.pop(c, 'everyone')),
        ListTile(leading: const Icon(Icons.lock_outline_rounded), title: const Text('فقط خودم'), onTap: () => Navigator.pop(c, 'private')),
      ])),
    );
    if (audience == null) return;
    final uid = _storiesSupabase.auth.currentUser?.id;
    if (uid == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : (choice == 'video' ? 'mp4' : 'jpg');
    final path = '$uid/${DateTime.now().microsecondsSinceEpoch}.$ext';
    try {
      await _storiesSupabase.storage.from('stories').uploadBinary(path, Uint8List.fromList(bytes), fileOptions: FileOptions(upsert: false, contentType: choice == 'video' ? 'video/mp4' : 'image/jpeg'));
      String? caption;
      if (mounted) {
        final controller = TextEditingController();
        caption = await showDialog<String>(context: context, builder: (c) => AlertDialog(title: const Text('متن استوری'), content: TextField(controller: controller, maxLength: 500, decoration: const InputDecoration(hintText: 'اختیاری')), actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('رد کردن')),
          FilledButton(onPressed: () => Navigator.pop(c, controller.text.trim()), child: const Text('انتشار'))
        ]));
        controller.dispose();
      }
      await _storiesSupabase.from('stories').insert({'user_id': uid, 'media_path': path, 'media_type': choice, 'caption': caption, 'audience': audience, 'expires_at': DateTime.now().toUtc().add(const Duration(hours: 24)).toIso8601String()});
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('استوری منتشر شد.'))); await _load(); }
    } catch (_) {
      try { await _storiesSupabase.storage.from('stories').remove([path]); } catch (_) {}
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('انتشار استوری انجام نشد.')));
    }
  }
}

class StoryVideo extends StatefulWidget {
  final String url;
  const StoryVideo({super.key, required this.url});
  @override
  State<StoryVideo> createState() => _StoryVideoState();
}

class _StoryVideoState extends State<StoryVideo> {
  VideoPlayerController? _controller;
  @override
  void initState() { super.initState(); _init(); }
  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = c;
    await c.initialize(); await c.setLooping(true); await c.play();
    if (mounted) setState(() {});
  }
  @override
  void dispose() { _controller?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return const Center(child: CircularProgressIndicator());
    return Center(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)));
  }
}
