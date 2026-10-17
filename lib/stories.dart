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
        final p = await _storiesSupabase.from('profiles').select('id,display_name,username,avatar_url').inFilter('id', ids);
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
    for (final s in _stories) {
      final key = s['user_id'].toString();
      if (!grouped.containsKey(key)) grouped[key] = {...s, '_story_count': 1};
      else grouped[key]!['_story_count'] = (grouped[key]!['_story_count'] as int? ?? 1) + 1;
    }
    final people = grouped.values.toList();
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          const SizedBox(width: 8),
          _StoryAddTile(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StoriesPage())).then((_) => _load()),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: people.isEmpty
                ? Align(
                    alignment: Alignment.centerRight,
                    child: Text('استوری جدیدی نیست', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    itemCount: people.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final story = people[index];
                      final userId = story['user_id'].toString();
                      return _StoryTile(
                        story: story,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => StoriesPage(initialUserId: userId)),
                        ).then((_) => _load()),
                      );
                    },
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _StoryAddTile extends StatelessWidget {
  final VoidCallback onTap;
  const _StoryAddTile({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: SizedBox(width: 64, child: Column(children: [
    Container(width: 46, height: 46, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary.withValues(alpha:.18), Theme.of(context).colorScheme.secondary.withValues(alpha:.10)]), border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha:.75), width: 2), boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha:.16), blurRadius: 12)]), child: const Icon(Icons.add_rounded, size: 30)),
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
    final name = (p['display_name'] ?? p['username'] ?? 'کاربر').toString();
    final avatar = p['avatar_url']?.toString();
    return GestureDetector(onTap: onTap, child: SizedBox(width: 64, child: Column(children: [
      Container(width: 46, height: 46, padding: const EdgeInsets.all(2), decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary]), boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha:.20), blurRadius: 13)]),
      child: Stack(clipBehavior: Clip.none, children: [
        CircleAvatar(backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null, child: avatar == null || avatar.isEmpty ? const Icon(Icons.person) : null),
        Positioned(left: -2, bottom: -2, child: Container(
          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1.5)),
          child: Text('${story['_story_count'] ?? 1}', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 10, fontWeight: FontWeight.w900)),
        )),
      ])),
      const SizedBox(height: 5), Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700))
    ])));
  }
}

class StoriesPage extends StatefulWidget {
  final String? initialStoryId;
  final String? initialUserId;
  const StoriesPage({super.key, this.initialStoryId, this.initialUserId});
  @override
  State<StoriesPage> createState() => _StoriesPageState();
}

class _StoriesPageState extends State<StoriesPage> {
  List<Map<String, dynamic>> _stories = [];
  Map<String, String> _urls = {};
  final Map<String, Uint8List> _mediaBytes = <String, Uint8List>{};
  final Map<String, String> _urlErrors = <String, String>{};
  int _index = 0;
  bool _loading = true;
  final Set<String> _likedIds = <String>{};
  final Map<String, int> _likeCounts = <String, int>{};
  final Map<String, int> _commentCounts = <String, int>{};
  final Map<String, int> _viewCounts = <String, int>{};
  final Set<String> _urlLoadingIds = <String>{};
  final Set<String> _urlFailedIds = <String>{};
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

  int _loadGeneration = 0;

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final previousStoryId = _stories.isNotEmpty && _index < _stories.length
        ? _stories[_index]['id']?.toString()
        : null;
    try {
      final rows = await _storiesSupabase
          .from('stories')
          .select('id,user_id,media_path,media_type,caption,created_at,expires_at')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .inFilter('media_type', ['image', 'video'])
          .order('created_at', ascending: true)
          .limit(80);
      final stories = List<Map<String, dynamic>>.from(rows);
      if (!mounted || generation != _loadGeneration) return;
      final profileIds = stories.map((s) => s['user_id']?.toString() ?? '').where((id) => id.isNotEmpty).toSet().toList();
      if (profileIds.isNotEmpty) {
        try {
          final profileRows = await _storiesSupabase.from('profiles').select('id,display_name,username,avatar_url').inFilter('id', profileIds);
          final byId = {for (final p in List<Map<String, dynamic>>.from(profileRows)) p['id'].toString(): p};
          for (final story in stories) { story['profile'] = byId[story['user_id']?.toString()] ?? <String, dynamic>{}; }
        } catch (_) {}
      }
      if (!mounted || generation != _loadGeneration) return;

      if (stories.isEmpty) {
        setState(() {
          _stories = [];
          _urls = {};
          _mediaBytes.clear();
          _urlErrors.clear();
          _index = 0;
          _loading = false;
          _likedIds.clear();
          _likeCounts.clear();
          _commentCounts.clear();
          _viewCounts.clear();
          _urlLoadingIds.clear();
          _urlFailedIds.clear();
        });
        _timer?.cancel();
        return;
      }

      final ids = stories.map((s) => s['id'].toString()).toList();
      final uid = _storiesSupabase.auth.currentUser?.id;
      // Open the newest available story by default; older stories may reference removed media.
      var nextIndex = stories.length - 1;
      var foundSelection = false;
      for (final candidate in [previousStoryId, widget.initialStoryId]) {
        if (candidate == null || candidate.isEmpty) continue;
        final found = stories.indexWhere((s) => s['id'].toString() == candidate);
        if (found >= 0) {
          nextIndex = found;
          foundSelection = true;
          break;
        }
      }
      if (!foundSelection && widget.initialUserId != null) {
        for (var i = stories.length - 1; i >= 0; i--) {
          if (stories[i]['user_id']?.toString() == widget.initialUserId) {
            nextIndex = i;
            break;
          }
        }
      }
      final selectedId = stories[nextIndex]['id']?.toString();
      final validIds = ids.toSet();
      setState(() {
        _stories = stories;
        _urls.removeWhere((id, _) => !validIds.contains(id));
        _mediaBytes.removeWhere((id, _) => !validIds.contains(id));
        _urlErrors.removeWhere((id, _) => !validIds.contains(id));
        _urlFailedIds.removeWhere((id) => !validIds.contains(id));
        _index = nextIndex;
        _loading = false;
      });

      // Sign only the selected story first. Signing dozens of private Storage
      // objects at once made the viewer appear blank on slower phones/connections.
      final selectionChanged = selectedId != previousStoryId;
      if (selectionChanged) _timer?.cancel();
      unawaited(_ensureSignedUrl(
        stories[nextIndex],
        startTimerWhenReady: selectionChanged || _timer == null,
      ));
      unawaited(_loadEngagement(ids, uid, generation));
    } catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('استوری‌ها بارگذاری نشدند: ${error.toString().replaceFirst('Exception: ', '')}', maxLines: 3)),
        );
      }
    }
  }

  Future<void> _ensureSignedUrl(
    Map<String, dynamic> story, {
    bool startTimerWhenReady = false,
  }) async {
    final id = story['id']?.toString() ?? '';
    var path = story['media_path']?.toString().trim() ?? '';
    // Support older rows that saved a full Storage URL instead of an object key.
    if (path.startsWith('http://') || path.startsWith('https://')) {
      // Older uploads may store a complete Supabase Storage URL. Normalize
      // public, signed and authenticated object URLs back to the bucket key
      // before requesting a fresh signed URL.
      try {
        final uri = Uri.parse(path);
        final segments = uri.pathSegments;
        final objectAt = segments.indexOf('object');
        if (objectAt >= 0 && objectAt + 2 < segments.length) {
          final bucketAt = segments.indexOf('stories', objectAt + 1);
          if (bucketAt >= 0 && bucketAt + 1 < segments.length) {
            path = segments.skip(bucketAt + 1).map(Uri.decodeComponent).join('/');
          }
        } else {
          final marker = '/stories/';
          final at = uri.path.indexOf(marker);
          if (at >= 0) path = Uri.decodeComponent(uri.path.substring(at + marker.length).split('?').first);
        }
      } catch (_) {}
    }
    path = path.replaceFirst(RegExp(r'^/+'), '');
    if (id.isEmpty || path.isEmpty) {
      if (mounted) setState(() => _urlFailedIds.add(id));
      return;
    }
    if ((_urls[id] ?? '').isNotEmpty) {
      if (startTimerWhenReady && mounted && _stories.isNotEmpty &&
          _stories[_index]['id']?.toString() == id) {
        _startTimer();
      }
      return;
    }
    if (!_urlLoadingIds.add(id)) return;
    if (mounted) setState(() { _urlFailedIds.remove(id); _urlErrors.remove(id); });
    try {
      final signed = await _storiesSupabase.storage
          .from('stories')
          .createSignedUrl(path, 3600)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (_stories.any((item) => item['id']?.toString() == id)) {
        setState(() {
          _urls[id] = signed;
          _urlFailedIds.remove(id);
          _urlErrors.remove(id);
        });
        if (startTimerWhenReady && _stories.isNotEmpty &&
            _stories[_index]['id']?.toString() == id) {
          _startTimer();
        }
      }
    } catch (error) {
      // Some devices/storage configurations fail to issue a signed URL even
      // though the authenticated user can still download the object directly.
      // Fall back to bytes for images, and keep the actual error for diagnosis.
      if (story['media_type'] != 'video') {
        try {
          final bytes = await _storiesSupabase.storage
              .from('stories')
              .download(path)
              .timeout(const Duration(seconds: 20));
          if (mounted && _stories.any((item) => item['id']?.toString() == id)) {
            setState(() {
              _mediaBytes[id] = Uint8List.fromList(bytes);
              _urlFailedIds.remove(id);
              _urlErrors.remove(id);
            });
            if (startTimerWhenReady && _stories.isNotEmpty && _stories[_index]['id']?.toString() == id) {
              _startTimer();
            }
            return;
          }
        } catch (downloadError) {
          if (mounted) setState(() {
            _urlFailedIds.add(id);
            _urlErrors[id] = downloadError.toString();
          });
        }
      } else if (mounted) {
        setState(() {
          _urlFailedIds.add(id);
          _urlErrors[id] = error.toString();
        });
      }
    } finally {
      _urlLoadingIds.remove(id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _retryCurrentMedia() async {
    if (_stories.isEmpty) return;
    final id = _stories[_index]['id']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() {
      _urls.remove(id);
      _mediaBytes.remove(id);
      _urlErrors.remove(id);
      _urlFailedIds.remove(id);
    });
    await _ensureSignedUrl(_stories[_index], startTimerWhenReady: true);
  }

  Future<void> _loadEngagement(List<String> ids, String? uid, int generation) async {
    if (ids.isEmpty) return;
    try {
      final analytics = await Future.wait<dynamic>([
        _storiesSupabase.from('story_likes').select('story_id,user_id').inFilter('story_id', ids)
            .then<dynamic>((v) => v).catchError((_) => <Map<String, dynamic>>[]),
        _storiesSupabase.from('story_comments').select('story_id').inFilter('story_id', ids)
            .then<dynamic>((v) => v).catchError((_) => <Map<String, dynamic>>[]),
        _storiesSupabase.from('story_views').select('story_id,viewer_id').inFilter('story_id', ids)
            .then<dynamic>((v) => v).catchError((_) => <Map<String, dynamic>>[]),
      ]);
      final liked = <String>{};
      final likes = <String, int>{};
      final comments = <String, int>{};
      final views = <String, int>{};
      for (final row in List<Map<String, dynamic>>.from(analytics[0] as List)) {
        final id = row['story_id'].toString();
        likes[id] = (likes[id] ?? 0) + 1;
        if (row['user_id']?.toString() == uid) liked.add(id);
      }
      for (final row in List<Map<String, dynamic>>.from(analytics[1] as List)) {
        final id = row['story_id'].toString();
        comments[id] = (comments[id] ?? 0) + 1;
      }
      for (final row in List<Map<String, dynamic>>.from(analytics[2] as List)) {
        final id = row['story_id'].toString();
        views[id] = (views[id] ?? 0) + 1;
      }
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _likedIds
          ..clear()
          ..addAll(liked);
        _likeCounts
          ..clear()
          ..addAll(likes);
        _commentCounts
          ..clear()
          ..addAll(comments);
        _viewCounts
          ..clear()
          ..addAll(views);
      });
    } catch (_) {
      // Story media stays usable even if optional engagement tables are unavailable.
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_stories.isEmpty) return;
    _timer = Timer(Duration(seconds: _stories[_index]['media_type'] == 'video' ? 8 : 5), _next);
    _markViewed();
  }

  Future<void> _markViewed() async {
    if (_stories.isEmpty) return;
    final story = _stories[_index];
    final uid = _storiesSupabase.auth.currentUser?.id;
    if (uid == null || story['user_id']?.toString() == uid) return;
    try { await _storiesSupabase.from('story_views').upsert({'story_id': story['id'], 'viewer_id': uid, 'viewed_at': DateTime.now().toUtc().toIso8601String()}); } catch (_) {}
  }

  void _next() {
    if (_stories.isEmpty) return;
    if (_index >= _stories.length - 1) { Navigator.pop(context); return; }
    _timer?.cancel();
    setState(() => _index++);
    unawaited(_ensureSignedUrl(_stories[_index], startTimerWhenReady: true));
  }

  void _previous() {
    if (_stories.isEmpty || _index == 0) return;
    _timer?.cancel();
    setState(() => _index--);
    unawaited(_ensureSignedUrl(_stories[_index], startTimerWhenReady: true));
  }

  Future<void> _toggleCurrentLike() async {
    if (_stories.isEmpty) return;
    final story = _stories[_index];
    final id = story['id'].toString();
    final uid = _storiesSupabase.auth.currentUser?.id;
    if (uid == null) return;
    final wasLiked = _likedIds.contains(id);
    setState(() {
      if (wasLiked) { _likedIds.remove(id); _likeCounts[id] = ((_likeCounts[id] ?? 1) - 1).clamp(0, 1 << 30).toInt(); }
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

  Future<void> _showViewers() async {
    if (_stories.isEmpty) return;
    final story = _stories[_index];
    if (story['user_id']?.toString() != _storiesSupabase.auth.currentUser?.id) return;
    try {
      final rows = List<Map<String, dynamic>>.from(await _storiesSupabase
          .from('story_views').select('viewer_id,viewed_at').eq('story_id', story['id']).order('viewed_at', ascending: false));
      final ids = rows.map((r) => r['viewer_id']?.toString() ?? '').where((id) => id.isNotEmpty).toSet().toList();
      final people = <String, Map<String, dynamic>>{};
      if (ids.isNotEmpty) {
        final profiles = await _storiesSupabase.from('profiles').select('id,display_name,username,avatar_url').inFilter('id', ids);
        for (final p in List<Map<String, dynamic>>.from(profiles)) people[p['id'].toString()] = p;
      }
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context, showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * .55,
            child: Column(children: [
              Padding(padding: const EdgeInsets.all(16), child: Align(alignment: Alignment.centerRight, child: Text('بازدیدکنندگان (${rows.length})', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)))),
              Expanded(child: rows.isEmpty
                ? const Center(child: Text('هنوز کسی این استوری را ندیده است.'))
                : ListView(children: rows.map((r) {
                    final id = r['viewer_id']?.toString() ?? '';
                    final p = people[id] ?? {};
                    final name = (p['display_name'] ?? p['username'] ?? 'کاربر').toString();
                    final avatar = (p['avatar_url'] ?? '').toString();
                    final at = DateTime.tryParse(r['viewed_at']?.toString() ?? '')?.toLocal();
                    final time = at == null ? '' : '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
                    return ListTile(
                      leading: CircleAvatar(backgroundImage: avatar.isEmpty ? null : NetworkImage(avatar), child: avatar.isEmpty ? const Icon(Icons.person_outline) : null),
                      title: Text(name),
                      subtitle: Text(time),
                    );
                  }).toList())),
            ]),
          ),
        ),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فهرست بازدیدکنندگان بارگذاری نشد.')));
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
    await Share.share('استوری در پیام‌رسان آراد${caption.isEmpty ? '' : '\n$caption'}\nلینک باز کردن استوری: arad://story/${Uri.encodeComponent(id)}\nمحدوده نمایش: ${audience == 'everyone' ? 'همه' : audience == 'private' ? 'خصوصی' : 'مخاطبین'}');
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
    final storyId = s['id'].toString();
    final url = _urls[storyId];
    final mediaBytes = _mediaBytes[storyId];
    final mine = s['user_id'].toString() == _storiesSupabase.auth.currentUser?.id;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('استوری'), actions: const []),
      body: GestureDetector(
        onTapUp: (d) => d.localPosition.dx < MediaQuery.of(context).size.width / 2 ? _previous() : _next(),
        child: Stack(fit: StackFit.expand, children: [
          if ((url == null || url.isEmpty) && mediaBytes == null)
            Center(
              child: _urlLoadingIds.contains(s['id'].toString())
                  ? const Column(mainAxisSize: MainAxisSize.min, children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 12),
                      Text('در حال بارگذاری استوری…', style: TextStyle(color: Colors.white)),
                    ])
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(s['media_type'] == 'video' ? Icons.videocam_off_rounded : Icons.broken_image_rounded, color: Colors.white70, size: 48),
                      const SizedBox(height: 10),
                      Text(_urlFailedIds.contains(s['id'].toString()) ? 'رسانهٔ استوری بارگذاری نشد' : 'آماده‌سازی استوری…', style: const TextStyle(color: Colors.white, fontSize: 14)),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: _retryCurrentMedia,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('تلاش دوباره'),
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                      ),
                    ]),
            )
          else if (s['media_type'] == 'video')
            StoryVideo(key: ValueKey(s['id']), url: url ?? '')
          else if (mediaBytes != null && s['media_type'] != 'video')
            InteractiveViewer(child: Image.memory(mediaBytes, key: ValueKey(s['id']), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Center(child: Text('نمایش عکس ناموفق بود', style: TextStyle(color: Colors.white)))))
          else
            Stack(fit: StackFit.expand, children: [
              Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.expand()),
              Container(color: Colors.black.withValues(alpha: .28)),
              Center(child: InteractiveViewer(child: Image.network(
                url!, key: ValueKey(s['id']), fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white)),
                errorBuilder: (_, __, ___) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.broken_image_rounded, color: Colors.white, size: 48),
                  const SizedBox(height: 8),
                  const Text('نمایش عکس ناموفق بود', style: TextStyle(color: Colors.white)),
                  TextButton.icon(onPressed: _retryCurrentMedia, icon: const Icon(Icons.refresh_rounded), label: const Text('بارگذاری دوباره'), style: TextButton.styleFrom(foregroundColor: Colors.white)),
                ])),
              )),
            ]),
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xB8000000), Colors.transparent])),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: List.generate(
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
                )),
                const SizedBox(height: 13),
                Row(children: [
                  CircleAvatar(radius: 19, backgroundColor: Colors.white24, backgroundImage: ((s['profile']?['avatar_url'] ?? '').toString().trim().isNotEmpty) ? NetworkImage(s['profile']['avatar_url'].toString()) : null,
                    child: ((s['profile']?['avatar_url'] ?? '').toString().trim().isEmpty) ? const Icon(Icons.person_rounded, color: Colors.white) : null),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((s['profile']?['display_name'] ?? s['profile']?['username'] ?? 'استوری').toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                    const Text('استوری آراد مسنجر', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ])),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white)),
                ]),
              ]),
            ),
          ),
          Positioned(
            left: 12, right: 12, bottom: 16,
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _storyBottomButton(
                    icon: Icons.add_circle_outline_rounded,
                    label: 'استوری جدید',
                    onTap: _createStory,
                  ),
                  if (mine) ...[
                    const SizedBox(width: 10),
                    _storyBottomButton(
                      icon: Icons.delete_outline_rounded,
                      label: 'حذف',
                      onTap: _deleteCurrent,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 12, right: 12, bottom: (s['caption'] ?? '').toString().trim().isNotEmpty ? 154 : 76,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .58),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: .14)),
                ),
                child: Row(children: [
                  Expanded(child: Text(
                    (s['audience'] ?? 'contacts') == 'everyone' ? 'عمومی' : (s['audience'] ?? 'contacts') == 'private' ? 'خصوصی' : 'مخاطبین',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  )),
                  IconButton(tooltip: 'پسندیدن', onPressed: _toggleCurrentLike, icon: Icon(_likedIds.contains(s['id'].toString()) ? Icons.favorite : Icons.favorite_border, color: _likedIds.contains(s['id'].toString()) ? Colors.pinkAccent : Colors.white)),
                  Text('${_likeCounts[s['id'].toString()] ?? 0}', style: const TextStyle(color: Colors.white)),
                  if (mine) ...[
                    IconButton(tooltip: 'بازدیدکنندگان', onPressed: _showViewers, icon: const Icon(Icons.visibility_outlined, color: Colors.white)),
                    Text('${_viewCounts[s['id'].toString()] ?? 0}', style: const TextStyle(color: Colors.white)),
                  ],
                  IconButton(tooltip: 'نظرها', onPressed: _openComments, icon: const Icon(Icons.mode_comment_outlined, color: Colors.white)),
                  Text('${_commentCounts[s['id'].toString()] ?? 0}', style: const TextStyle(color: Colors.white)),
                  IconButton(tooltip: 'اشتراک‌گذاری', onPressed: _shareCurrent, icon: const Icon(Icons.share_outlined, color: Colors.white)),
                ]),
              ),
            ),
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
    final durationHours = await showModalBottomSheet<int>(
      context: context,
      builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const ListTile(title: Text('مدت نمایش استوری')),
        ListTile(leading: const Icon(Icons.hourglass_bottom_rounded), title: const Text('۲ ساعت'), onTap: () => Navigator.pop(c, 2)),
        ListTile(leading: const Icon(Icons.hourglass_bottom_rounded), title: const Text('۳ ساعت'), onTap: () => Navigator.pop(c, 3)),
        ListTile(leading: const Icon(Icons.schedule_rounded), title: const Text('۲۴ ساعت (پیش‌فرض)'), onTap: () => Navigator.pop(c, 24)),
      ])),
    );
    if (durationHours == null) return;
    final uid = _storiesSupabase.auth.currentUser?.id;
    if (uid == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : (choice == 'video' ? 'mp4' : 'jpg');
    final path = '$uid/${DateTime.now().microsecondsSinceEpoch}.$ext';
    try {
      final contentType = switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'mov' => 'video/quicktime',
        'webm' => 'video/webm',
        'm4v' => 'video/x-m4v',
        'mp4' => 'video/mp4',
        _ => choice == 'video' ? 'video/mp4' : 'image/jpeg',
      };
      await _storiesSupabase.storage.from('stories').uploadBinary(
        path,
        Uint8List.fromList(bytes),
        fileOptions: FileOptions(upsert: false, contentType: contentType),
      );
      String? caption;
      if (mounted) {
        final controller = TextEditingController();
        caption = await showDialog<String>(context: context, builder: (c) => AlertDialog(title: const Text('متن استوری'), content: TextField(controller: controller, maxLength: 500, decoration: const InputDecoration(hintText: 'اختیاری')), actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('رد کردن')),
          FilledButton(onPressed: () => Navigator.pop(c, controller.text.trim()), child: const Text('انتشار'))
        ]));
        controller.dispose();
      }
      await _storiesSupabase.from('stories').insert({'user_id': uid, 'media_path': path, 'media_type': choice, 'caption': caption, 'audience': audience, 'expires_at': DateTime.now().toUtc().add(Duration(hours: durationHours)).toIso8601String()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('استوری منتشر شد.')));
        await _load();
        if (mounted && _stories.isNotEmpty) {
          final uid = _storiesSupabase.auth.currentUser?.id;
          var mineIndex = -1;
          for (var i = _stories.length - 1; i >= 0; i--) {
            if (_stories[i]['user_id']?.toString() == uid) {
              mineIndex = i;
              break;
            }
          }
          if (mineIndex >= 0) setState(() => _index = mineIndex);
          _startTimer();
        }
      }
    } catch (error) {
      try { await _storiesSupabase.storage.from('stories').remove([path]); } catch (_) {}
      if (mounted) {
        final detail = error.toString().replaceFirst('Exception: ', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('استوری منتشر نشد: ${detail.isEmpty ? 'خطای ناشناخته' : detail}', maxLines: 3, overflow: TextOverflow.ellipsis),
          duration: const Duration(seconds: 7),
          action: SnackBarAction(label: 'بارگذاری دوباره', onPressed: () => _load()),
        ));
      }
    }
  }
}


Widget _storyBottomButton({required IconData icon, required String label, required VoidCallback onTap}) {
  return Material(
    color: Colors.black.withValues(alpha: .72),
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: .22)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 19),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
      ),
    ),
  );
}


class StoryVideo extends StatefulWidget {
  final String url;
  const StoryVideo({super.key, required this.url});
  @override
  State<StoryVideo> createState() => _StoryVideoState();
}

class _StoryVideoState extends State<StoryVideo> {
  VideoPlayerController? _controller;
  bool _failed = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    if (!mounted) return;
    setState(() { _loading = true; _failed = false; });
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize().timeout(const Duration(seconds: 20));
      await controller.setLooping(true);
      await controller.play();
      if (mounted && identical(_controller, controller)) {
        setState(() { _loading = false; _failed = false; });
      }
    } catch (_) {
      try { await controller.dispose(); } catch (_) {}
      if (identical(_controller, controller)) _controller = null;
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_loading) return const Center(child: CircularProgressIndicator(color: Colors.white));
    if (_failed || c == null || !c.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 48),
            const SizedBox(height: 8),
            const Text('پخش ویدئو ناموفق بود', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _init,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تلاش دوباره'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }
    return Center(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)));
  }
}
