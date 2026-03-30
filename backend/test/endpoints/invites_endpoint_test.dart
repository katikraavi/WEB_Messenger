import 'package:test/test.dart';

@Skip('Legacy Serverpod endpoint tests; backend now uses Shelf router handlers')
void main() {
  test('placeholder', () {
    expect(true, isTrue);
  });
}
