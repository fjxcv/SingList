import 'package:flutter_test/flutter_test.dart';
import 'package:sing_list/service/normalize.dart';

void main() {
  test('matchesSongKeyword is case and space insensitive', () {
    expect(
      matchesSongKeyword(titleNorm: 'hello', artistNorm: 'world', keyword: '  HELLO '),
      isTrue,
    );
    expect(
      matchesSongKeyword(titleNorm: 'hello', artistNorm: 'world', keyword: 'world'),
      isTrue,
    );
    expect(
      matchesSongKeyword(titleNorm: 'hello', artistNorm: 'world', keyword: 'other'),
      isFalse,
    );
    expect(
      matchesSongKeyword(titleNorm: 'hello', artistNorm: 'world', keyword: ''),
      isTrue,
    );
  });
}
