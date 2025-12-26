import 'package:flutter_test/flutter_test.dart';
import 'package:sing_list/service/normalize.dart';

void main() {
  test('normalize compresses spaces and lowercase', () {
    expect(normalizeTitle('  Hello   World  '), 'hello world');
    expect(normalizeArtist('Jay   Chou'), 'jay chou');
  });
}
