// SemVer 解析 + 比较矩阵——UPD-1 的核心正确性来源。
//
// 关键坑（release plan UPD-1 卡面点名）：prerelease 数字段必须按数值比较,
// alpha.10 > alpha.9;GitHub "latest" 端点不含 prerelease,故必须自比 max。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/semver.dart';

void main() {
  group('SemVer.tryParse', () {
    test('解析裸版本', () {
      final v = SemVer.tryParse('1.2.3');
      expect(v, isNotNull);
      expect(v!.major, 1);
      expect(v.minor, 2);
      expect(v.patch, 3);
      expect(v.preRelease, isEmpty);
    });

    test('解析 v 前缀(GitHub tag 风格)', () {
      final v = SemVer.tryParse('v0.1.0-alpha.10');
      expect(v, isNotNull);
      expect(v!.major, 0);
      expect(v.preRelease, <String>['alpha', '10']);
    });

    test('解析 build metadata 并忽略于比较', () {
      final a = SemVer.tryParse('0.1.0-alpha.9+9');
      final b = SemVer.tryParse('0.1.0-alpha.9+42');
      expect(a, isNotNull);
      expect(b, isNotNull);
      expect(a!.compareTo(b!), 0);
    });

    test('非法输入返回 null', () {
      expect(SemVer.tryParse(''), isNull);
      expect(SemVer.tryParse('garbage'), isNull);
      expect(SemVer.tryParse('1.0'), isNull);
      expect(SemVer.tryParse('1.0.0-'), isNull);
      expect(SemVer.tryParse('1.0.0-alpha..1'), isNull);
      expect(SemVer.tryParse('v'), isNull);
    });
  });

  group('SemVer.compareTo', () {
    int cmp(String a, String b) =>
        SemVer.tryParse(a)!.compareTo(SemVer.tryParse(b)!);

    test('主/次/补丁位数值序', () {
      expect(cmp('1.0.0', '0.9.9'), greaterThan(0));
      expect(cmp('0.2.0', '0.1.9'), greaterThan(0));
      expect(cmp('0.1.10', '0.1.9'), greaterThan(0));
      expect(cmp('0.1.0', '0.1.0'), 0);
    });

    test('prerelease 数字段按数值比较:alpha.10 > alpha.9', () {
      expect(cmp('0.1.0-alpha.10', '0.1.0-alpha.9'), greaterThan(0));
      expect(cmp('0.1.0-alpha.2', '0.1.0-alpha.10'), lessThan(0));
    });

    test('正式版 > 同号 prerelease', () {
      expect(cmp('0.1.0', '0.1.0-beta.1'), greaterThan(0));
      expect(cmp('0.1.0-rc.1', '0.1.0'), lessThan(0));
    });

    test('字母段字典序:beta > alpha', () {
      expect(cmp('0.1.0-beta.1', '0.1.0-alpha.10'), greaterThan(0));
    });

    test('数字段 < 字母段(SemVer 2.0.0 §11)', () {
      expect(cmp('0.1.0-alpha.1', '0.1.0-alpha.beta'), lessThan(0));
    });

    test('前缀相同时段数多的更大:alpha < alpha.1', () {
      expect(cmp('0.1.0-alpha', '0.1.0-alpha.1'), lessThan(0));
    });

    test('高一版的 prerelease > 低版正式版', () {
      expect(cmp('0.2.0-alpha.1', '0.1.0'), greaterThan(0));
    });
  });

  group('SemVer 值语义', () {
    test('== 与 hashCode 忽略 build metadata 之外全字段', () {
      final a = SemVer.tryParse('0.1.0-alpha.9');
      final b = SemVer.tryParse('v0.1.0-alpha.9');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('toString 回吐规范形式', () {
      expect(SemVer.tryParse('v0.1.0-alpha.10')!.toString(), '0.1.0-alpha.10');
      expect(SemVer.tryParse('1.2.3')!.toString(), '1.2.3');
    });
  });
}
