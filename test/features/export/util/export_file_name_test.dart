// isValidExportBaseName —— 与服务端 _assertPlainFileName 同规则的本地预校验。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/export/util/export_file_name.dart';

void main() {
  test('合法单层文件名通过', () {
    expect(isValidExportBaseName('my_cut'), isTrue);
    expect(isValidExportBaseName('final-v2'), isTrue);
    expect(isValidExportBaseName('分镜成片'), isTrue);
    expect(isValidExportBaseName('a.b'), isTrue);
  });

  test('空串拒绝（留空=默认名走 null，不经本校验）', () {
    expect(isValidExportBaseName(''), isFalse);
  });

  test('路径分隔符 / 盘符冒号拒绝', () {
    expect(isValidExportBaseName('a/b'), isFalse);
    expect(isValidExportBaseName('a\\b'), isFalse);
    expect(isValidExportBaseName('C:v'), isFalse);
  });

  test('.. 穿越段拒绝', () {
    expect(isValidExportBaseName('..'), isFalse);
    expect(isValidExportBaseName('a..b'), isFalse);
  });

  test('控制字符拒绝', () {
    expect(isValidExportBaseName('a\x00b'), isFalse);
    expect(isValidExportBaseName('a\x1fb'), isFalse);
    expect(isValidExportBaseName('a\x7fb'), isFalse);
  });

  test('Windows 非法字符拒绝（* ? " < > |）', () {
    expect(isValidExportBaseName('final*cut'), isFalse);
    expect(isValidExportBaseName('a?b'), isFalse);
    expect(isValidExportBaseName('x|y'), isFalse);
    expect(isValidExportBaseName('a"b'), isFalse);
    expect(isValidExportBaseName('a<b'), isFalse);
    expect(isValidExportBaseName('a>b'), isFalse);
  });

  test('Windows 保留设备名拒绝（大小写不敏感，含带扩展名形态）', () {
    expect(isValidExportBaseName('CON'), isFalse);
    expect(isValidExportBaseName('nul'), isFalse);
    expect(isValidExportBaseName('Com1'), isFalse);
    expect(isValidExportBaseName('lpt9'), isFalse);
    expect(isValidExportBaseName('con.backup'), isFalse);
    expect(isValidExportBaseName('NUL.mp4'), isFalse);
    expect(isValidExportBaseName('Com1.txt'), isFalse);
    // 保留名按首个点段匹配：作为普通前缀合法。
    expect(isValidExportBaseName('console'), isTrue);
    expect(isValidExportBaseName('config-x'), isTrue);
  });
}
