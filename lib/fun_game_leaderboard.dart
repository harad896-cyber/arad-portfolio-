import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'fun_zone_theme.dart';

class FunGameLeaderboardPage extends StatefulWidget {
  const FunGameLeaderboardPage({super.key});
  @override State<FunGameLeaderboardPage> createState() => _FunGameLeaderboardPageState();
}

class _FunGameLeaderboardPageState extends State<FunGameLeaderboardPage> {
  late Future<List<Map<String, dynamic>>> future;
  @override void initState() { super.initState(); future = load(); }

  Future<List<Map<String, dynamic>>> load() async {
    final client = Supabase.instance.client;
    final stats = (await client.from('fun_game_stats')
      .select('user_id,points,rating,games_played,wins,draws,losses')
      .order('points', ascending: false).order('rating', ascending: false).limit(50) as List)
      .map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final ids = stats.map((e) => e['user_id'].toString()).toList();
    final profiles = ids.isEmpty ? <Map<String, dynamic>>[] :
      (await client.from('profiles').select('id,username,display_name,avatar_url').inFilter('id', ids) as List)
        .map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final byId = {for (final p in profiles) p['id'].toString(): p};
    for (final row in stats) { row['_profile'] = byId[row['user_id'].toString()]; }
    return stats;
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(title: const Text('جدول امتیازها'), backgroundColor: Colors.transparent,
      actions: [IconButton(onPressed: () => setState(() => future = load()), icon: const Icon(Icons.refresh_rounded))]),
    floatingActionButton: const FunZoneThemeButton(),
    body: FunZoneBackdrop(child: FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.leaderboard_rounded, size: 54, color: Colors.white70),
            const SizedBox(height: 12),
            const Text('جدول امتیازها هنوز آماده نیست.', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 8),
            const Text('پس از فعال‌شدن ثبت امتیازها، رتبه و آمار بازیکنان اینجا نمایش داده می‌شود.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, height: 1.5)),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: () => setState(() => future = load()), icon: const Icon(Icons.refresh), label: const Text('تلاش دوباره')),
          ])));
        final rows = snapshot.data!;
        final me = Supabase.instance.client.auth.currentUser?.id;
        final mine = rows.where((r) => r['user_id'] == me).firstOrNull;
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(colors: [Color(0xFFB88A32), Color(0xFFF3D77D), Color(0xFF8E6122)])),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('امتیاز حساب تو', style: TextStyle(color: Color(0xFF38240B), fontWeight: FontWeight.w800)),
              Text(mine == null ? '۰' : (mine['points'] as num).toInt().toString(),
                style: const TextStyle(color: Color(0xFF38240B), fontSize: 34, fontWeight: FontWeight.w900)),
              if (mine != null) Text('رتبه ${rows.indexOf(mine) + 1}  ·  ${mine['wins']} برد  ·  ${mine['games_played']} مسابقه',
                style: const TextStyle(color: Color(0xFF38240B), fontWeight: FontWeight.w700)),
            ])),
          const SizedBox(height: 18),
          const Text('بازیکنان برتر', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (rows.isEmpty) const Padding(padding: EdgeInsets.all(28),
            child: Text('هنوز مسابقه‌ای برای ثبت امتیاز انجام نشده است.', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70))),
          for (var i = 0; i < rows.length; i++) _LeaderboardTile(rank: i + 1, row: rows[i], isMe: rows[i]['user_id'] == me),
        ]);
      },
    )),
  );
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> row;
  final bool isMe;
  const _LeaderboardTile({required this.rank, required this.row, required this.isMe});
  @override Widget build(BuildContext context) {
    final p = row['_profile'] as Map<String, dynamic>?;
    final name = (p?['display_name'] ?? p?['username'] ?? 'بازیکن').toString();
    final username = p?['username']?.toString();
    final medal = rank == 1 ? const Color(0xFFFFD65A) : rank == 2 ? const Color(0xFFC8D2DE) :
      rank == 3 ? const Color(0xFFCC8E58) : Colors.white54;
    return Container(margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: isMe ? .16 : .09),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: isMe ? const Color(0xFFFFD65A) : Colors.white.withValues(alpha: .07))),
      child: ListTile(
        leading: SizedBox(width: 42, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(rank <= 3 ? Icons.emoji_events_rounded : Icons.person_rounded, color: medal),
          Text(rank.toString(), style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800)),
        ])),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        subtitle: Text('${username == null || username.isEmpty ? 'بازیکن گپ‌رسان' : '@$username'}  ·  ${row['wins']} برد از ${row['games_played']} مسابقه',
          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        trailing: Text('${row['points']} امتیاز', style: const TextStyle(color: Color(0xFFFFD978), fontWeight: FontWeight.w900)),
      ),
    );
  }
}
