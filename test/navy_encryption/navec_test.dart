import 'package:flutter_test/flutter_test.dart';
import 'package:navy_encrypt/navy_encryption/algorithms/aes.dart';
import 'package:navy_encrypt/navy_encryption/algorithms/base_algorithm.dart';
import 'package:navy_encrypt/navy_encryption/navec.dart';

void main() {
  test('available algorithms include AES 128, AES 256 and not-encrypt', () {
    final codes = Navec.algorithms.map((algo) => algo.code).toList();

    expect(codes, containsAll(<String>['AES128', 'AES256', Navec.notEncryptCode]));
    expect(Navec.algorithms.whereType<Aes>().length, equals(2));
    expect(
      Navec.algorithms.whereType<NotEncrypt>().length,
      equals(1),
    );
  });
}
