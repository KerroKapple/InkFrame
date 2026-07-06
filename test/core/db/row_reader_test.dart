// DbRow 类型化访问器单测：类型不符抛 LocalIOError(op:'decode')，取代裸 _TypeError。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/db/row_reader.dart';
import 'package:inkframe/core/errors/ink_error.dart';

void main() {
  group('DbRow', () {
    final row = <String, Object?>{
      's': 'hi',
      'n': null,
      'i': 7,
      'd': 1.5,
      'di': 2, // num 但非 double
      'b': true,
      'id': 'uuid-text',
    };

    test('reqString 返回值；缺失/类型错 → LocalIOError', () {
      expect(row.reqString('s'), 'hi');
      expect(() => row.reqString('n'), throwsA(isA<LocalIOError>()));
      expect(() => row.reqString('i'), throwsA(isA<LocalIOError>()));
    });

    test('optString: null→null；类型错→LocalIOError', () {
      expect(row.optString('n'), isNull);
      expect(row.optString('s'), 'hi');
      expect(() => row.optString('i'), throwsA(isA<LocalIOError>()));
    });

    test('reqId 字符串化；null→LocalIOError', () {
      expect(row.reqId('id'), 'uuid-text');
      expect(row.reqId('i'), '7');
      expect(() => row.reqId('n'), throwsA(isA<LocalIOError>()));
    });

    test('optId: null→null；否则字符串化', () {
      expect(row.optId('n'), isNull);
      expect(row.optId('i'), '7');
    });

    test('optInt / reqInt', () {
      expect(row.optInt('i'), 7);
      expect(row.optInt('n'), isNull);
      expect(row.reqInt('i'), 7);
      expect(() => row.reqInt('s'), throwsA(isA<LocalIOError>()));
    });

    test('optDouble: num→toDouble；null→null；非num→LocalIOError', () {
      expect(row.optDouble('d'), 1.5);
      expect(row.optDouble('di'), 2.0);
      expect(row.optDouble('n'), isNull);
      expect(() => row.optDouble('s'), throwsA(isA<LocalIOError>()));
    });

    test('optBool', () {
      expect(row.optBool('b'), true);
      expect(row.optBool('n'), isNull);
      expect(() => row.optBool('i'), throwsA(isA<LocalIOError>()));
    });

    test('LocalIOError.extra 带 op/column/expected/actual', () {
      try {
        row.reqString('i');
        fail('should throw');
      } on LocalIOError catch (e) {
        expect(e.extra['op'], 'decode');
        expect(e.extra['column'], 'i');
        expect(e.extra['expected'], 'String');
        expect(e.extra['actual'], 'int');
      }
    });
  });
}
