import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/ludo_customization.dart';

void main() {
  test('all Ludo customization collections have matching palettes', () {
    expect(LudoCustomization.boardNames.length, LudoCustomization.boardPalettes.length);
    expect(LudoCustomization.frames.length, LudoCustomization.frameColors.length);
    expect(LudoCustomization.banners.length, LudoCustomization.bannerPalettes.length);
    expect(LudoCustomization.backgrounds.length, LudoCustomization.backgroundPalettes.length);
    expect(LudoCustomization.avatars.length, 8);
    expect(LudoCustomization.charms.length, 8);
  });

  test('every board palette provides three usable colors', () {
    for (final palette in LudoCustomization.boardPalettes) {
      expect(palette.length, 3);
      expect(palette.toSet().length, 3);
    }
  });
}
