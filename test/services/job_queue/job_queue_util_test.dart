// job_queue_util.lostToCancel 真值表（LB-03）：cancel 竞态裁决的单一真相源谓词。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/services/job_queue/job_queue_util.dart';

void main() {
  group('lostToCancel 真值表 {cancelled × rows∈{null,0,1}}', () {
    test('cancelled=true, rows=null → true（纯内存无行数，退化为内存取消位）', () {
      expect(lostToCancel(rows: null, cancelled: true), isTrue);
    });
    test('cancelled=true, rows=0 → true（终态写库被 cancel 抢先，0 行）', () {
      expect(lostToCancel(rows: 0, cancelled: true), isTrue);
    });
    test('cancelled=true, rows=1 → false（本 job 抢先写成终态，1 行）', () {
      expect(lostToCancel(rows: 1, cancelled: true), isFalse);
    });
    test('cancelled=false, rows=null → false', () {
      expect(lostToCancel(rows: null, cancelled: false), isFalse);
    });
    test('cancelled=false, rows=0 → false（非取消语境二次失败同样 0 行，不得误判）', () {
      expect(lostToCancel(rows: 0, cancelled: false), isFalse);
    });
    test('cancelled=false, rows=1 → false', () {
      expect(lostToCancel(rows: 1, cancelled: false), isFalse);
    });
  });
}
