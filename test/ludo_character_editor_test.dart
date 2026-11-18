import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/ludo_character_editor.dart';

void main() {
  group('Ludo cosmetic appearance', () {
    test('appearance serializes and restores all cosmetic selections', () {
      const appearance = LudoCharacterAppearance(
        characterId: 'robot_01',
        faceId: 'smile',
        bodyColor: '#58B8C9',
        hatId: 'space_helmet',
        glassesId: 'neon_glasses',
        auraId: 'green_spark',
      );
      final restored = LudoCharacterAppearance.fromJson(appearance.toJson());
      expect(restored.characterId, 'robot_01');
      expect(restored.faceId, 'smile');
      expect(restored.bodyColor, '#58B8C9');
      expect(restored.hatId, 'space_helmet');
      expect(restored.glassesId, 'neon_glasses');
      expect(restored.auraId, 'green_spark');
    });

    test('copyWith can remove optional cosmetic slots', () {
      const appearance = LudoCharacterAppearance(
        hatId: 'crown', glassesId: 'neon_glasses', auraId: 'green_spark',
      );
      final changed = appearance.copyWith(
        clearHat: true, clearGlasses: true, clearAura: true,
      );
      expect(changed.hatId, isNull);
      expect(changed.glassesId, isNull);
      expect(changed.auraId, isNull);
    });

    test('face selection is preserved when appearance is copied', () {
      const appearance = LudoCharacterAppearance(faceId: 'happy');
      final changed = appearance.copyWith(faceId: 'wink');
      expect(changed.faceId, 'wink');
      expect(changed.characterId, appearance.characterId);
      expect(changed.bodyColor, appearance.bodyColor);
    });

    test('cosmetic catalog rejects missing ids and unknown categories', () {
      expect(
        () => LudoCosmeticItem.fromJson({'category': 'character'}),
        throwsFormatException,
      );
      expect(
        () => LudoCosmeticItem.fromJson({
          'id': 'broken', 'category': 'gameplay_power',
        }),
        throwsFormatException,
      );
    });

    test('unknown rarity safely falls back to common', () {
      final item = LudoCosmeticItem.fromJson({
        'id': 'test', 'name': 'Test', 'category': 'character',
        'rarity': 'unexpected', 'is_active': true,
      });
      expect(item.rarity, LudoItemRarity.common);
      expect(item.available, isTrue);
    });
  });
}
