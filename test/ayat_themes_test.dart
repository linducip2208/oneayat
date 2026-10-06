import 'package:flutter_test/flutter_test.dart';
import 'package:oneayat/data/ayat_themes.dart';

void main() {
  test('seed keys resolve to themes', () {
    expect(themesOf('94:5'), contains('sabar'));
    expect(themesOf('112:1'), containsAll(['ikhlas', 'tauhid']));
    expect(themesOf('2:255'), isEmpty); // untagged, not bundled
  });

  test('theme counts aggregate', () {
    final c = themeCounts(['94:5', '94:6', '112:1']);
    expect(c['sabar'], 2);
    expect(c['ikhlas'], 1);
  });
}
