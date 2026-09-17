from pathlib import Path

# Group management now lives in lib/group_management.dart.
# Keep this workflow step successful instead of looking for the old inline block in main.dart.
MAIN = Path('lib/main.dart')
if not MAIN.exists():
    raise SystemExit('lib/main.dart not found')
print('Group management is maintained in lib/group_management.dart; no inline patch needed.')
