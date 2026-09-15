from pathlib import Path
import re

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

start = s.index('class _ChatPageState extends State<ChatPage> {')
end = s.index('class ProfilePage extends StatefulWidget {', start)
chat = s[start:end]

# The voice/media patches require these state fields. Add them exactly once.
if 'final AudioRecorder _voiceRecorder = AudioRecorder();' not in chat:
    marker = '  bool sending = false;'
    if marker not in chat:
        raise SystemExit('Chat state marker not found')
    chat = chat.replace(
        marker,
        marker + "\n  final AudioRecorder _voiceRecorder = AudioRecorder();\n  final AudioPlayer _voicePlayer = AudioPlayer();\n  bool recordingVoice = false;",
        1,
    )

# Remove duplicate dispose() methods introduced by stacked media patches.
def method_spans(source, name):
    spans = []
    for m in re.finditer(r'(?m)^  (?:@override\n  )?(?:Future<[^>]+>|void|Widget)\s+' + re.escape(name) + r'\s*\([^\n]*\)\s*\{', source):
        brace = source.find('{', m.start())
        depth = 0
        end_pos = None
        for i in range(brace, len(source)):
            if source[i] == '{':
                depth += 1
            elif source[i] == '}':
                depth -= 1
                if depth == 0:
                    end_pos = i + 1
                    break
        if end_pos is not None:
            spans.append((m.start(), end_pos))
    return spans

spans = method_spans(chat, 'dispose')
if len(spans) > 1:
    # Keep the first dispose implementation and delete later duplicates.
    for a, b in reversed(spans[1:]):
        chat = chat[:a] + chat[b:]

# Ensure the surviving dispose cleans up the audio resources, while preserving
# any existing channel/controller cleanup in that method.
spans = method_spans(chat, 'dispose')
if spans:
    a, b = spans[0]
    block = chat[a:b]
    if '_voiceRecorder.dispose();' not in block:
        marker = 'super.dispose();'
        if marker in block:
            block = block.replace(marker, '  _voiceRecorder.dispose();\n    _voicePlayer.dispose();\n    ' + marker, 1)
        else:
            block = block[:-1] + '  _voiceRecorder.dispose();\n  _voicePlayer.dispose();\n}'
        chat = chat[:a] + block + chat[b:]

# Music patch replaces the old helper with an inline player. Remove an unused
# helper if it exists, avoiding an analyzer warning.
spans = method_spans(chat, '_voicePlayButton')
for a, b in reversed(spans):
    chat = chat[:a] + chat[b:]

s = s[:start] + chat + s[end:]
p.write_text(s, encoding='utf-8')
print('Fixed duplicate dispose and audio player/recorder declarations')
