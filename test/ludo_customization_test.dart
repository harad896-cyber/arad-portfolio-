import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/ludo_customization.dart';

void main() {
  test('all Ludo customization collections have matching palettes', () {
    expect(LudoCustomization.boardNames.length, LudoCustomization.boardPalettes.length);
    expect(LudoCustomization.frames.length, LudoCustomization.frameColors.length);
    expect(LudoCustomization.banners.length, LudoCustomization.bannerPalettes.length);
    expect(LudoCustomization.backgrounds.length, LudoCustomization.backgroundPalettes.length);
    expect(LudoCustomization.avatars.length, 10);
    expect(LudoCustomization.charms.length, 10);
  });

  test('every board palette provides three usable colors', () {
    for (final palette in LudoCustomization.boardPalettes) {
      expect(palette.length, 3);
      expect(palette.toSet().length, 3);
    }
  });
}

test('expanded Ludo themes, banners, and backgrounds stay in sync', () {
  expect(LudoCustomization.boardNames.length, 8);
  expect(LudoCustomization.boardPalettes.length, 8);
  expect(LudoCustomization.frames.length, 8);
  expect(LudoCustomization.frameColors.length, 8);
  expect(LudoCustomization.banners.length, 8);
  expect(LudoCustomization.bannerPalettes.length, 8);
  expect(LudoCustomization.backgrounds.length, 8);
  expect(LudoCustomization.backgroundPalettes.length, 8);
});

test('invalid optional profile photo data safely falls back to no image', () {
  expect(LudoCustomization.decodeImage(null), isNull);
  expect(LudoCustomization.decodeImage(''), isNull);
  expect(LudoCustomization.decodeImage('not-an-image'), isNull);
});
