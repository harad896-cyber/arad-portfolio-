from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

if "import 'call_session.dart';" not in s:
    marker = "import 'profile_page.dart';"
    if marker not in s:
        raise SystemExit('profile import marker not found')
    s = s.replace(marker, marker + "\nimport 'call_session.dart';", 1)

chat_start = s.find('class _ChatPageState extends State<ChatPage>')
if chat_start < 0:
    raise SystemExit('ChatPage state marker not found')

build_marker = "  @override\n  Widget build(BuildContext context) {"
method_marker = s.find(build_marker, chat_start)
if method_marker < 0:
    raise SystemExit('ChatPage build marker not found')

method = """  void _startChatCall({required bool video}) {\n    Navigator.push(\n      context,\n      MaterialPageRoute(\n        builder: (_) => CallSessionPage(\n          conversationId: widget.id,\n          title: widget.title,\n          video: video,\n        ),\n      ),\n    );\n  }\n\n"""
if 'void _startChatCall({required bool video})' not in s[chat_start:method_marker]:
    s = s[:method_marker] + method + s[method_marker:]

chat_start = s.find('class _ChatPageState extends State<ChatPage>')
actions_pos = s.find('        actions: [', chat_start)
if actions_pos < 0:
    raise SystemExit('ChatPage actions marker not found')
insert_at = actions_pos + len('        actions: [')
controls = """\n          IconButton(\n            onPressed: () => _startChatCall(video: false),\n            tooltip: 'تماس صوتی',\n            icon: const Icon(Icons.call_rounded),\n          ),\n          IconButton(\n            onPressed: () => _startChatCall(video: true),\n            tooltip: 'تماس تصویری',\n            icon: const Icon(Icons.videocam_rounded),\n          ),"""
if "tooltip: 'تماس صوتی'" not in s[actions_pos:actions_pos + 1000]:
    s = s[:insert_at] + controls + s[insert_at:]

p.write_text(s, encoding='utf-8')
print('chat call controls patched successfully')
