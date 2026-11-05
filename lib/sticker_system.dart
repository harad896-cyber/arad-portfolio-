import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _StickerPlaybackBudget {
  static const int limit = 3;
  static final ValueNotifier<Set<String>> active = ValueNotifier(<String>{});
  static final Map<String, double> _visible = {};

  static void update(String id, double fraction) {
    if (fraction < .08) { _visible.remove(id); } else { _visible[id] = fraction; }
    final ranked = _visible.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    active.value = ranked.take(limit).map((entry) => entry.key).toSet();
  }

  static void remove(String id) {
    _visible.remove(id);
    final ranked = _visible.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    active.value = ranked.take(limit).map((entry) => entry.key).toSet();
  }
}

class StickerPlayer extends StatefulWidget {
  const StickerPlayer({super.key, required this.url, this.format = 'lottie',
    this.previewUrl, this.size = 176, this.instanceId});
  final String url;
  final String format;
  final String? previewUrl;
  final double size;
  final String? instanceId;

  @override
  State<StickerPlayer> createState() => _StickerPlayerState();
}

class _StickerPlayerState extends State<StickerPlayer> {
  late final String _id = widget.instanceId ?? ('sticker-' + identityHashCode(this).toString());

  @override
  void dispose() { _StickerPlaybackBudget.remove(_id); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('visibility-' + _id),
      onVisibilityChanged: (info) => _StickerPlaybackBudget.update(_id, info.visibleFraction),
      child: ValueListenableBuilder<Set<String>>(
        valueListenable: _StickerPlaybackBudget.active,
        builder: (context, activeIds, _) {
          final play = activeIds.contains(_id);
          if (widget.format == 'gif') {
            if (!play) {
              return SizedBox(width: widget.size, height: widget.size, child: _placeholder(context));
            }
            return Image.network(widget.url, width: widget.size, height: widget.size,
              fit: BoxFit.contain, errorBuilder: (_, __, ___) => _placeholder(context));
          }
          if (widget.format == 'png' || widget.format == 'webp') {
            return Image.network(widget.url, width: widget.size, height: widget.size,
              fit: BoxFit.contain, errorBuilder: (_, __, ___) => _placeholder(context));
          }
          return SizedBox(width: widget.size, height: widget.size,
            child: Lottie.network(widget.url, animate: play, repeat: true, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _placeholder(context)));
        },
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Center(
    child: Icon(Icons.auto_awesome_rounded, size: 38,
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .65)));
}

class StickerPickerSheet extends StatefulWidget {
  const StickerPickerSheet({super.key, required this.supabase, required this.onEmojiSelected,
    required this.onStickerSelected, required this.onGifSelected});
  final SupabaseClient supabase;
  final ValueChanged<String> onEmojiSelected;
  final Future<void> Function(Map<String, dynamic>) onStickerSelected;
  final Future<void> Function(Map<String, dynamic>) onGifSelected;

  @override
  State<StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<StickerPickerSheet> {
  static const _tenorKey = String.fromEnvironment('TENOR_API_KEY');
  static const _giphyKey = String.fromEnvironment('GIPHY_API_KEY');
  static const _emojis = <String>[
    '😀','😃','😄','😁','😆','😅','😂','🤣','🥹','😊','😍','🥰','😘','😉','😎','🤩',
    '🥳','😭','😢','😡','🤔','🤗','😴','🤯','👋','👍','👎','👏','🙌','🙏','💪','🤝',
    '🫶','❤️','🧡','💛','💚','💙','💜','🤍','🖤','💔','❤️‍🔥','✨','🔥','🎉','🎁','🌹',
    '🌸','🌈','⭐','🌙','☀️','⚡','🚀','🏆','🎮','☕','🍓','🍉'
  ];

  int _tab = 0;
  bool _loadingStickers = true;
  bool _searchingGifs = false;
  String _stickerError = '';
  String _query = '';
  String _provider = 'Tenor';
  final TextEditingController _gifSearch = TextEditingController();
  List<Map<String, dynamic>> _stickers = [];
  List<Map<String, dynamic>> _gifs = [];
  List<String> _recentIds = [];
  Map<String, int> _usage = {};

  @override
  void initState() { super.initState(); _loadLocalUsage(); _loadStickers(); }

  @override
  void dispose() { _gifSearch.dispose(); super.dispose(); }

  Future<void> _loadLocalUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = widget.supabase.auth.currentUser?.id ?? 'guest';
    final recent = prefs.getStringList('sticker_recent_' + uid) ?? <String>[];
    Map<String, int> usage = {};
    final raw = prefs.getString('sticker_usage_' + uid);
    if (raw != null) {
      try {
        usage = (jsonDecode(raw) as Map).map((key, value) =>
          MapEntry(key.toString(), (value as num).toInt()));
      } catch (_) {}
    }
    if (mounted) setState(() { _recentIds = recent; _usage = usage; });
  }

  Future<void> _recordStickerUse(String id) async {
    final uid = widget.supabase.auth.currentUser?.id ?? 'guest';
    final prefs = await SharedPreferences.getInstance();
    final recent = <String>[id, ..._recentIds.where((value) => value != id)].take(30).toList();
    final usage = Map<String, int>.from(_usage);
    usage[id] = (usage[id] ?? 0) + 1;
    await prefs.setStringList('sticker_recent_' + uid, recent);
    await prefs.setString('sticker_usage_' + uid, jsonEncode(usage));
    if (mounted) setState(() { _recentIds = recent; _usage = usage; });
  }

  Future<void> _loadStickers() async {
    try {
      final packs = await widget.supabase.from('sticker_packs').select('id,name,slug,sort_order')
        .eq('is_active', true).order('sort_order');
      final rows = await widget.supabase.from('stickers')
        .select('id,pack_id,name,asset_path,preview_path,format,tags,sort_order')
        .eq('is_active', true).order('sort_order');
      final packRows = List<Map<String, dynamic>>.from(packs);
      final packIds = packRows.map((row) => row['id'].toString()).toSet();
      final result = <Map<String, dynamic>>[];
      for (final raw in rows as List) {
        final row = Map<String, dynamic>.from(raw);
        if (!packIds.contains(row['pack_id']?.toString())) continue;
        final path = row['asset_path']?.toString() ?? '';
        final preview = row['preview_path']?.toString() ?? '';
        row['url'] = widget.supabase.storage.from('stickers').getPublicUrl(path);
        row['preview_url'] = preview.isEmpty ? '' :
          widget.supabase.storage.from('stickers').getPublicUrl(preview);
        final pack = packRows.where((p) => p['id'].toString() == row['pack_id'].toString());
        row['pack_name'] = pack.isEmpty ? '' : pack.first['name'].toString();
        result.add(row);
      }
      if (mounted) setState(() { _stickers = result; _loadingStickers = false; });
    } catch (error) {
      if (mounted) setState(() { _loadingStickers = false; _stickerError = error.toString(); });
    }
  }

  List<Map<String, dynamic>> get _visibleStickers {
    final byId = {for (final item in _stickers) item['id'].toString(): item};
    final recent = _recentIds.map((id) => byId[id]).whereType<Map<String, dynamic>>().toList();
    if (recent.isNotEmpty) return recent;
    final sorted = List<Map<String, dynamic>>.from(_stickers);
    sorted.sort((a, b) => (_usage[b['id'].toString()] ?? 0)
      .compareTo(_usage[a['id'].toString()] ?? 0));
    return sorted;
  }

  Future<void> _searchGifs() async {
    final query = _gifSearch.text.trim();
    if (query.isEmpty) return;
    setState(() { _query = query; _searchingGifs = true; _gifs = []; });
    try {
      final results = <Map<String, dynamic>>[];
      if (_provider == 'Tenor' && _tenorKey.isNotEmpty) {
        final uri = Uri.https('tenor.googleapis.com', '/v2/search', {
          'q': query, 'key': _tenorKey, 'client_key': 'gapresan',
          'limit': '24', 'media_filter': 'gif'
        });
        final response = await http.get(uri).timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) throw Exception('Tenor ' + response.statusCode.toString());
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        for (final raw in (data['results'] as List? ?? const [])) {
          final item = Map<String, dynamic>.from(raw as Map);
          final formats = Map<String, dynamic>.from(item['media_formats'] as Map? ?? {});
          final gif = Map<String, dynamic>.from(formats['gif'] as Map? ?? {});
          final preview = Map<String, dynamic>.from(formats['tinygif'] as Map? ?? gif);
          if ((gif['url'] ?? '').toString().isEmpty) continue;
          results.add({'id': item['id']?.toString() ?? gif['url'], 'url': gif['url'].toString(),
            'preview_url': preview['url']?.toString() ?? '', 'provider': 'Tenor', 'format': 'gif'});
        }
      } else if (_provider == 'Giphy' && _giphyKey.isNotEmpty) {
        final uri = Uri.https('api.giphy.com', '/v1/gifs/search', {
          'api_key': _giphyKey, 'q': query, 'limit': '24', 'rating': 'pg'
        });
        final response = await http.get(uri).timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) throw Exception('Giphy ' + response.statusCode.toString());
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        for (final raw in (data['data'] as List? ?? const [])) {
          final item = Map<String, dynamic>.from(raw as Map);
          final images = Map<String, dynamic>.from(item['images'] as Map? ?? {});
          final original = Map<String, dynamic>.from(images['original'] as Map? ?? {});
          final still = Map<String, dynamic>.from(images['fixed_width_still'] as Map? ?? {});
          if ((original['url'] ?? '').toString().isEmpty) continue;
          results.add({'id': item['id']?.toString() ?? original['url'], 'url': original['url'].toString(),
            'preview_url': still['url']?.toString() ?? '', 'provider': 'Giphy', 'format': 'gif'});
        }
      } else {
        throw Exception('کلید API برای ' + _provider + ' در تنظیمات Build تعریف نشده است.');
      }
      if (mounted) setState(() => _gifs = results);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('جست‌وجوی GIF ناموفق بود: ' + error.toString())));
    } finally {
      if (mounted) setState(() => _searchingGifs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = MediaQuery.of(context).size.height * .76;
    return SafeArea(top: false, child: Container(
      height: height.clamp(360.0, 680.0),
      decoration: BoxDecoration(color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: scheme.primary.withValues(alpha: .3)))),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(children: [
        Container(width: 42, height: 4, decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: .24), borderRadius: BorderRadius.circular(8))),
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.auto_awesome_rounded, color: scheme.primary),
          const SizedBox(width: 8),
          const Expanded(child: Text('اموجی، استیکر و GIF',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
        ]),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, icon: Icon(Icons.emoji_emotions_outlined), label: Text('اموجی')),
            ButtonSegment(value: 1, icon: Icon(Icons.auto_awesome_rounded), label: Text('استیکرها')),
            ButtonSegment(value: 2, icon: Icon(Icons.gif_box_outlined), label: Text('GIF')),
          ],
          selected: {_tab}, showSelectedIcon: false,
          onSelectionChanged: (value) => setState(() => _tab = value.first)),
        const SizedBox(height: 10),
        Expanded(child: _tab == 0 ? _emojiGrid() : _tab == 1 ? _stickerGrid() : _gifPanel()),
      ]),
    ));
  }

  Widget _emojiGrid() => GridView.builder(
    itemCount: _emojis.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 8, mainAxisSpacing: 5, crossAxisSpacing: 5),
    itemBuilder: (context, index) => InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => widget.onEmojiSelected(_emojis[index]),
      child: Center(child: Text(_emojis[index], style: const TextStyle(fontSize: 27)))));

  Widget _stickerGrid() {
    if (_loadingStickers) return const Center(child: CircularProgressIndicator());
    if (_stickerError.isNotEmpty) return Center(child: Text(
      'بارگذاری استیکرها ناموفق بود.\n' + _stickerError, textAlign: TextAlign.center));
    if (_stickers.isEmpty) return const Center(child: Text(
      'هنوز بستهٔ استیکری منتشر نشده است.\nپس از بارگذاری فایل‌های Lottie در Storage، استیکرها اینجا نمایش داده می‌شوند.',
      textAlign: TextAlign.center));
    final items = _visibleStickers;
    return GridView.builder(
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await _recordStickerUse(item['id'].toString());
            if (!mounted) return;
            Navigator.pop(context);
            await widget.onStickerSelected(item);
          },
          child: Container(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.all(5),
            child: Column(children: [
              Expanded(child: StickerPlayer(url: item['url'].toString(),
                format: item['format']?.toString() ?? 'lottie',
                previewUrl: item['preview_url']?.toString(), size: 96,
                instanceId: 'picker-' + item['id'].toString())),
              Text(item['name']?.toString() ?? '', maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ])));
      });
  }

  Widget _gifPanel() => Column(children: [
    Row(children: [
      Expanded(child: TextField(controller: _gifSearch, textInputAction: TextInputAction.search,
        onSubmitted: (_) => _searchGifs(),
        decoration: const InputDecoration(hintText: 'جست‌وجوی GIF',
          prefixIcon: Icon(Icons.search_rounded), isDense: true))),
      const SizedBox(width: 8),
      DropdownButton<String>(value: _provider,
        items: const [
          DropdownMenuItem(value: 'Tenor', child: Text('Tenor')),
          DropdownMenuItem(value: 'Giphy', child: Text('Giphy'))],
        onChanged: (value) => setState(() { _provider = value ?? 'Tenor'; _gifs = []; })),
      IconButton(onPressed: _searchingGifs ? null : _searchGifs,
        icon: _searchingGifs
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.search_rounded)),
    ]),
    const SizedBox(height: 8),
    Expanded(child: _gifs.isEmpty
      ? Center(child: Text(
          ((_provider == 'Tenor' && _tenorKey.isEmpty) || (_provider == 'Giphy' && _giphyKey.isEmpty))
            ? 'برای جست‌وجوی ' + _provider + ' باید کلید API هنگام Build با --dart-define تنظیم شود.'
            : _query.isEmpty ? 'یک عبارت جست‌وجو کنید.' : 'نتیجه‌ای پیدا نشد.',
          textAlign: TextAlign.center))
      : GridView.builder(itemCount: _gifs.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.35),
          itemBuilder: (context, index) {
            final item = _gifs[index];
            return InkWell(borderRadius: BorderRadius.circular(14),
              onTap: () async { Navigator.pop(context); await widget.onGifSelected(item); },
              child: ClipRRect(borderRadius: BorderRadius.circular(14),
                child: StickerPlayer(url: item['url'].toString(), format: 'gif',
                  size: 150, instanceId: 'gif-search-' + item['id'].toString())));
          })),
  ]);
}
