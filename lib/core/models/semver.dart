// SemVer：语义化版本值类型（SemVer 2.0.0 子集,UPD-1 更新检查用）。
//
// 手写不可变类（与 AppPreferences 同例外）：纯值类型,不引 freezed/json 代码生成。
// 比较遵循 SemVer 2.0.0 §11：主/次/补丁数值序;正式版 > 同号 prerelease;
// prerelease 逐段比较——纯数字段按数值(alpha.10 > alpha.9)、数字段 < 字母段、
// 字母段字典序、前缀相同段数多者大;build metadata 不参与比较与相等。
import 'package:flutter/foundation.dart';

@immutable
class SemVer implements Comparable<SemVer> {
  const SemVer._({
    required this.major,
    required this.minor,
    required this.patch,
    required this.preRelease,
  });

  final int major;
  final int minor;
  final int patch;

  /// prerelease 标识符列表（'-' 后按 '.' 切分）。空列表 = 正式版。
  final List<String> preRelease;

  static final RegExp _pattern = RegExp(
    r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z][0-9A-Za-z.-]*))?(?:\+[0-9A-Za-z][0-9A-Za-z.-]*)?$',
  );

  /// 宽容解析：接受可选 'v' 前缀（GitHub tag 风格）;非法输入返回 null 而非抛。
  static SemVer? tryParse(String input) {
    final m = _pattern.firstMatch(input.trim());
    if (m == null) return null;
    final pre = m.group(4);
    final List<String> ids;
    if (pre == null) {
      ids = const <String>[];
    } else {
      ids = pre.split('.');
      if (ids.any((id) => id.isEmpty)) return null;
    }
    return SemVer._(
      major: int.parse(m.group(1)!),
      minor: int.parse(m.group(2)!),
      patch: int.parse(m.group(3)!),
      preRelease: List.unmodifiable(ids),
    );
  }

  @override
  int compareTo(SemVer other) {
    int c = major.compareTo(other.major);
    if (c != 0) return c;
    c = minor.compareTo(other.minor);
    if (c != 0) return c;
    c = patch.compareTo(other.patch);
    if (c != 0) return c;
    // 正式版 > 任意 prerelease（SemVer §11.3）。
    if (preRelease.isEmpty && other.preRelease.isEmpty) return 0;
    if (preRelease.isEmpty) return 1;
    if (other.preRelease.isEmpty) return -1;
    final n = preRelease.length < other.preRelease.length
        ? preRelease.length
        : other.preRelease.length;
    for (int i = 0; i < n; i++) {
      final r = _compareIdentifier(preRelease[i], other.preRelease[i]);
      if (r != 0) return r;
    }
    // 前缀相同,段数多者更大（SemVer §11.4.4）。
    return preRelease.length.compareTo(other.preRelease.length);
  }

  static int _compareIdentifier(String a, String b) {
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null) return -1; // 数字段 < 字母段
    if (nb != null) return 1;
    return a.compareTo(b);
  }

  @override
  String toString() => preRelease.isEmpty
      ? '$major.$minor.$patch'
      : '$major.$minor.$patch-${preRelease.join('.')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemVer &&
          other.major == major &&
          other.minor == minor &&
          other.patch == patch &&
          listEquals(other.preRelease, preRelease);

  @override
  int get hashCode => Object.hash(major, minor, patch, Object.hashAll(preRelease));
}
