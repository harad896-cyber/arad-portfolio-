from pathlib import Path
import re

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

# Use the reusable voice player so group voice messages have waveform seeking,
# visible elapsed/total duration, +/-10s controls and playback speed.
if "import 'voice_message_player.dart';" not in s:
    s = s.replace("import 'call_session.dart';", "import 'call_session.dart';\nimport 'voice_message_player.dart';", 1)

if 'int _groupMemberCount = 0;' not in s:
    s = s.replace("String _chatType = 'direct';", "String _chatType = 'direct';\n  int _groupMemberCount = 0;", 1)

old_load = '''  Future<void> _loadChatType() async {
    try {
      final r = await supabase.from('conversations').select('type').eq('id', widget.id).maybeSingle();
      if (mounted) setState(() { _chatType = (r?['type'] ?? 'direct').toString(); });
    } catch (_) {}
  }'''
new_load = '''  Future<void> _loadChatType() async {
    try {
      final r = await supabase.from('conversations').select('type').eq('id', widget.id).maybeSingle();
      final type = (r?['type'] ?? 'direct').toString();
      var count = 0;
      if (type == 'group') {
        final rows = await supabase.from('conversation_members').select('user_id').eq('conversation_id', widget.id);
        count = (rows as List).length;
      }
      if (mounted) setState(() { _chatType = type; _groupMemberCount = count; });
    } catch (_) {}
  }'''
if old_load in s:
    s = s.replace(old_load, new_load, 1)

old_voice = re.compile(r"  Widget _voicePlayButton\(String messageId\) \{.*?\n  \}\n\n  String _time\(dynamic value\)", re.S)
new_voice = '''  Widget _voicePlayButton(String messageId) {
    final a = attachments[messageId];
    final initialMs = ((a?['duration_ms'] as num?)?.toInt() ?? 0);
    return VoiceMessagePlayer(
      mine: true,
      initialDurationMs: initialMs,
      loadAudio: () async {
        final path = attachments[messageId]?['storage_path']?.toString() ?? '';
        if (path.isEmpty) throw Exception('مسیر فایل صوتی خالی است');
        return supabase.storage.from('chat-media').download(path);
      },
    );
  }

  String _time(dynamic value)'''
if old_voice.search(s):
    s = old_voice.sub(new_voice, s, count=1)

old_sub = """                    if (_chatType == 'group')
                      const Text('پروفایل گروه', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500)),"""
new_sub = """                    if (_chatType == 'group')
                      Text('$_groupMemberCount عضو', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),"""
if old_sub in s:
    s = s.replace(old_sub, new_sub, 1)

p.write_text(s, encoding='utf-8')
print('group header member count + reusable waveform voice player applied')
