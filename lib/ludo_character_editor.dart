import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum LudoItemRarity { common, rare, epic, legendary }

class LudoCosmeticItem {
  final String id, name, category, assetKey, preview;
  final LudoItemRarity rarity;
  final String? emoji, color;
  final bool available;

  const LudoCosmeticItem({
    required this.id, required this.name, required this.category,
    required this.assetKey, required this.preview, required this.rarity,
    this.emoji, this.color, this.available = true,
  });

  factory LudoCosmeticItem.fromJson(Map<String, dynamic> json) {
    final rarityName = (json['rarity'] ?? 'common').toString();
    return LudoCosmeticItem(
      id: json['id'].toString(),
      name: (json['name'] ?? json['id']).toString(),
      category: (json['category'] ?? 'character').toString(),
      assetKey: (json['asset_key'] ?? '').toString(),
      preview: (json['preview'] ?? '').toString(),
      rarity: LudoItemRarity.values.firstWhere(
        (v) => v.name == rarityName, orElse: () => LudoItemRarity.common,
      ),
      emoji: json['emoji']?.toString(),
      color: json['color_hex']?.toString(),
      available: json['is_active'] == true,
    );
  }
}

class LudoCharacterAppearance {
  final String characterId, faceId, bodyColor;
  final String? hatId, glassesId, auraId;
  const LudoCharacterAppearance({
    this.characterId = 'fox_01', this.faceId = 'happy',
    this.bodyColor = '#F28A35', this.hatId, this.glassesId, this.auraId,
  });

  LudoCharacterAppearance copyWith({
    String? characterId, String? faceId, String? bodyColor,
    String? hatId, String? glassesId, String? auraId,
    bool clearHat = false, bool clearGlasses = false, bool clearAura = false,
  }) => LudoCharacterAppearance(
    characterId: characterId ?? this.characterId,
    faceId: faceId ?? this.faceId,
    bodyColor: bodyColor ?? this.bodyColor,
    hatId: clearHat ? null : hatId ?? this.hatId,
    glassesId: clearGlasses ? null : glassesId ?? this.glassesId,
    auraId: clearAura ? null : auraId ?? this.auraId,
  );

  Map<String, dynamic> toJson() => {
    'character_id': characterId, 'face_id': faceId, 'body_color': bodyColor,
    'hat_id': hatId, 'glasses_id': glassesId, 'aura_id': auraId,
  };

  factory LudoCharacterAppearance.fromJson(Map<String, dynamic> json) =>
    LudoCharacterAppearance(
      characterId: (json['character_id'] ?? 'fox_01').toString(),
      faceId: (json['face_id'] ?? 'happy').toString(),
      bodyColor: (json['body_color'] ?? '#F28A35').toString(),
      hatId: json['hat_id']?.toString(),
      glassesId: json['glasses_id']?.toString(),
      auraId: json['aura_id']?.toString(),
    );
}

class LudoCosmeticRepository {
  LudoCosmeticRepository(this._db);
  final SupabaseClient _db;

  Future<List<LudoCosmeticItem>> loadCatalog() async {
    final rows = await _db.from('ludo_cosmetic_catalog')
      .select('id,name,category,asset_key,preview,rarity,emoji,color_hex,is_active')
      .eq('is_active', true).order('sort_order');
    return rows.map((row) => LudoCosmeticItem.fromJson(
      Map<String, dynamic>.from(row),
    )).toList();
  }

  Future<LudoCharacterAppearance> loadAppearance() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return const LudoCharacterAppearance();
    final row = await _db.from('ludo_player_appearance')
      .select('character_id,face_id,body_color,hat_id,glasses_id,aura_id')
      .eq('user_id', uid).maybeSingle();
    return row == null ? const LudoCharacterAppearance()
      : LudoCharacterAppearance.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> saveAppearance(LudoCharacterAppearance appearance) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('برای ذخیره ظاهر وارد حساب شو.');
    await _db.from('ludo_player_appearance').upsert({
      'user_id': uid, ...appearance.toJson(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }
}

class LudoCharacterEditorPage extends StatefulWidget {
  const LudoCharacterEditorPage({super.key});
  @override State<LudoCharacterEditorPage> createState() => _LudoCharacterEditorPageState();
}

class _LudoCharacterEditorPageState extends State<LudoCharacterEditorPage> {
  final _db = Supabase.instance.client;
  late final _repository = LudoCosmeticRepository(_db);
  static const _fallback = <LudoCosmeticItem>[
    LudoCosmeticItem(id:'fox_01',name:'روباه',category:'character',assetKey:'',preview:'',rarity:LudoItemRarity.common,emoji:'🦊',color:'#F28A35'),
    LudoCosmeticItem(id:'robot_01',name:'ربات',category:'character',assetKey:'',preview:'',rarity:LudoItemRarity.rare,emoji:'🤖',color:'#58B8C9'),
    LudoCosmeticItem(id:'tiger_01',name:'ببر',category:'character',assetKey:'',preview:'',rarity:LudoItemRarity.epic,emoji:'🐯',color:'#E99A35'),
    LudoCosmeticItem(id:'astronaut_01',name:'فضانورد',category:'character',assetKey:'',preview:'',rarity:LudoItemRarity.legendary,emoji:'🧑‍🚀',color:'#91A9D8'),
    LudoCosmeticItem(id:'space_helmet',name:'کلاه فضایی',category:'hat',assetKey:'',preview:'',rarity:LudoItemRarity.epic,emoji:'🪖'),
    LudoCosmeticItem(id:'crown',name:'تاج',category:'hat',assetKey:'',preview:'',rarity:LudoItemRarity.legendary,emoji:'👑'),
    LudoCosmeticItem(id:'neon_glasses',name:'عینک نئونی',category:'glasses',assetKey:'',preview:'',rarity:LudoItemRarity.rare,emoji:'🕶️'),
    LudoCosmeticItem(id:'green_spark',name:'جرقه سبز',category:'aura',assetKey:'',preview:'',rarity:LudoItemRarity.legendary,emoji:'✨'),
  ];
  final _colors = const ['#F28A35','#4CBA75','#528EE8','#A76CE8','#E9C65B','#E87991'];
  List<LudoCosmeticItem> _catalog = _fallback;
  LudoCharacterAppearance _draft = const LudoCharacterAppearance();
  String _category = 'character';
  double _rotation = 0;
  bool _loading = true, _saving = false, _serverCatalog = false;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _repository.loadCatalog(), _repository.loadAppearance(),
      ]);
      if (!mounted) return;
      final items = results[0] as List<LudoCosmeticItem>;
      setState(() {
        if (items.isNotEmpty) { _catalog = items; _serverCatalog = true; }
        _draft = results[1] as LudoCharacterAppearance;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'کاتالوگ پیش‌فرض فعال است؛ اتصال سرور در دسترس نبود.'; });
    }
  }

  Color _hex(String value) {
    final clean = value.replaceFirst('#','');
    final parsed = int.tryParse(clean, radix:16) ?? 0xF28A35;
    return Color(0xFF000000 | parsed);
  }

  List<LudoCosmeticItem> get _visible => _catalog.where((item) =>
    item.category == _category && item.available).toList();

  LudoCosmeticItem? _itemById(String? id) {
    if (id == null) return null;
    for (final item in _catalog) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _choose(LudoCosmeticItem item) {
    setState(() {
      switch (item.category) {
        case 'character': _draft = _draft.copyWith(characterId:item.id, bodyColor:item.color ?? _draft.bodyColor); break;
        case 'hat': _draft = _draft.copyWith(hatId:item.id); break;
        case 'glasses': _draft = _draft.copyWith(glassesId:item.id); break;
        case 'aura': _draft = _draft.copyWith(auraId:item.id); break;
      }
    });
  }

  bool _selected(LudoCosmeticItem item) => switch(item.category) {
    'character' => _draft.characterId == item.id,
    'hat' => _draft.hatId == item.id,
    'glasses' => _draft.glassesId == item.id,
    'aura' => _draft.auraId == item.id,
    _ => false,
  };

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      await _repository.saveAppearance(_draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ظاهر کاراکتر در حساب گپ‌رسان ذخیره شد.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ',''));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF101722),
    appBar: AppBar(
      backgroundColor: const Color(0xFF101722), foregroundColor: Colors.white,
      title: const Text('استودیوی کاراکتر منچ'),
    ),
    body: _loading ? const Center(child:CircularProgressIndicator()) : SafeArea(
      child: Column(children:[
        if (_error != null) Padding(padding: const EdgeInsets.fromLTRB(16,8,16,0),
          child: Text(_error!,style:const TextStyle(color:Color(0xFFFFC56B),fontSize:12))),
        Expanded(child: ListView(padding:const EdgeInsets.all(16),children:[
          Container(
            height:250, decoration:BoxDecoration(
              borderRadius:BorderRadius.circular(26),
              gradient:const LinearGradient(colors:[Color(0xFF183A4B),Color(0xFF35204E),Color(0xFF10202C)]),
              border:Border.all(color:Colors.white12),
            ),
            child: GestureDetector(
              onHorizontalDragUpdate:(details)=>setState(()=>_rotation += details.delta.dx * .012),
              child: Center(child: Transform(
                alignment:Alignment.center,
                transform:Matrix4.identity()..rotateY(math.sin(_rotation)*.48)..rotateZ(math.sin(_rotation*.5)*.025),
                child: Stack(alignment:Alignment.center,children:[
                  if (_draft.auraId != null) Container(width:170,height:170,
                    decoration:BoxDecoration(shape:BoxShape.circle,
                      boxShadow:[BoxShadow(color:const Color(0xFF64E9B1).withValues(alpha:.55),blurRadius:35,spreadRadius:8)])),
                  Container(width:142,height:142,
                    decoration:BoxDecoration(shape:BoxShape.circle,color:_hex(_draft.bodyColor),
                      border:Border.all(color:Colors.white.withValues(alpha:.8),width:4),
                      boxShadow:const [BoxShadow(color:Colors.black38,blurRadius:18,offset:Offset(0,9))]),
                    child:Center(child:Text(_itemById(_draft.characterId)?.emoji ??
                      (_draft.characterId.startsWith('robot')?'🤖':_draft.characterId.startsWith('tiger')?'🐯':_draft.characterId.startsWith('astronaut')?'🧑‍🚀':'🦊'),
                      style:const TextStyle(fontSize:88))),
                  ),
                  if (_draft.hatId != null) Positioned(top:24,child:Text(
                    _itemById(_draft.hatId)?.emoji ?? '👑',
                    style:const TextStyle(fontSize:43))),
                  if (_draft.glassesId != null) const Positioned(top:99,child:Text('🕶️',style:TextStyle(fontSize:36))),
                  if (_draft.auraId != null) const Positioned(bottom:18,child:Text('✨',style:TextStyle(fontSize:26))),
                ]),
              )),
            ),
          ),
          const SizedBox(height:8),
          const Center(child:Text('برای چرخاندن کاراکتر، انگشت را افقی بکش',style:TextStyle(color:Colors.white60,fontSize:12))),
          const SizedBox(height:18),
          Wrap(spacing:8,runSpacing:8,children:[
            for(final entry in const [('character','شخصیت'),('hat','کلاه'),('glasses','عینک'),('aura','افکت')])
              ChoiceChip(label:Text(entry.$2),selected:_category==entry.$1,
                onSelected:(_)=>setState(()=>_category=entry.$1)),
          ]),
          const SizedBox(height:14),
          if(_category=='character') ...[
            const Text('رنگ کاراکتر',style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
            const SizedBox(height:8),
            Wrap(spacing:12,children:[for(final color in _colors)
              GestureDetector(onTap:()=>setState(()=>_draft=_draft.copyWith(bodyColor:color)),
                child:Container(width:34,height:34,decoration:BoxDecoration(
                  shape:BoxShape.circle,color:_hex(color),
                  border:Border.all(color:_draft.bodyColor==color?Colors.white:Colors.white24,width:3)))),
            ]),
            const SizedBox(height:14),
          ],
          Text(_category=='character'?'انتخاب کاراکتر':_category=='hat'?'انتخاب کلاه':_category=='glasses'?'انتخاب عینک':'انتخاب افکت دور مهره',
            style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
          const SizedBox(height:9),
          Wrap(spacing:10,runSpacing:10,children:[
            for(final item in _visible)
              InkWell(onTap:()=>_choose(item),borderRadius:BorderRadius.circular(16),
                child:Container(width:100,height:100,padding:const EdgeInsets.all(8),
                  decoration:BoxDecoration(color:const Color(0xFF1C2B3B),borderRadius:BorderRadius.circular(16),
                    border:Border.all(color:_selected(item)?const Color(0xFFFFD477):Colors.white12,width:_selected(item)?2.5:1)),
                  child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                    Text(item.emoji ?? '🎭',style:const TextStyle(fontSize:32)),
                    const SizedBox(height:4),
                    Text(item.name,style:const TextStyle(color:Colors.white,fontSize:11),textAlign:TextAlign.center),
                    Text(_rarity(item.rarity),style:TextStyle(color:_rarityColor(item.rarity),fontSize:9)),
                  ]))),
          ]),
          if(!_serverCatalog) const Padding(padding:EdgeInsets.only(top:12),
            child:Text('فهرست نمایشی داخلی؛ پس از فعال‌شدن کاتالوگ سرور، آیتم‌ها از راه دور به‌روزرسانی می‌شوند.',
              style:TextStyle(color:Colors.white38,fontSize:10))),
        ])),
        Padding(padding:const EdgeInsets.fromLTRB(16,8,16,16),child:Row(children:[
          Expanded(child:OutlinedButton(onPressed:()=>setState(()=>_draft=const LudoCharacterAppearance()),
            child:const Text('بازنشانی'))),
          const SizedBox(width:10),
          Expanded(flex:2,child:FilledButton.icon(onPressed:_saving?null:_save,
            icon:_saving?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.save_rounded),
            label:const Text('ذخیره ظاهر'))),
        ])),
      ]),
    ),
  );

  String _rarity(LudoItemRarity rarity)=>switch(rarity){
    LudoItemRarity.common=>'معمولی',LudoItemRarity.rare=>'نادر',
    LudoItemRarity.epic=>'حماسی',LudoItemRarity.legendary=>'افسانه‌ای',
  };
  Color _rarityColor(LudoItemRarity rarity)=>switch(rarity){
    LudoItemRarity.common=>Colors.white54,LudoItemRarity.rare=>const Color(0xFF64B5F6),
    LudoItemRarity.epic=>const Color(0xFFCE93D8),LudoItemRarity.legendary=>const Color(0xFFFFD54F),
  };
}
