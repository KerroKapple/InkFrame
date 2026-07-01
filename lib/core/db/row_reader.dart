// 类型化行解码：把仓储 Map<String,Object?> 边界的强转收敛到一处。
// 类型不符抛 LocalIOError(op:'decode')，取代散落的 `as` 崩溃(_TypeError)与各自的 _asDouble。
// ADR-0003 不废弃 Map 边界——本扩展只让 fromRow / 行读取变安全可诊断。
import 'dart:convert';

import '../errors/ink_error.dart';

extension DbRow on Map<String, Object?> {
  LocalIOError _decodeError(String col, String expected, Object? actual) =>
      LocalIOError(
        extra: <String, Object?>{
          'op': 'decode',
          'column': col,
          'expected': expected,
          'actual': actual?.runtimeType.toString() ?? 'null',
        },
      );

  /// 必填文本列(TEXT)。null 或非 String → LocalIOError。
  String reqString(String col) {
    final v = this[col];
    if (v is String) return v;
    throw _decodeError(col, 'String', v);
  }

  /// 可空文本列。null → null；非 String → LocalIOError。
  String? optString(String col) {
    final v = this[col];
    if (v == null) return null;
    if (v is String) return v;
    throw _decodeError(col, 'String', v);
  }

  /// 必填 id 列(UUID)。null → LocalIOError；否则字符串化(驱动可能回 String 或 UuidValue)。
  String reqId(String col) {
    final v = this[col];
    if (v == null) throw _decodeError(col, 'id', v);
    return v.toString();
  }

  /// 可空 id 列。null → null；否则字符串化。
  String? optId(String col) => this[col]?.toString();

  /// 必填整数列(INTEGER/BIGINT)。
  int reqInt(String col) {
    final v = this[col];
    if (v is int) return v;
    throw _decodeError(col, 'int', v);
  }

  /// 可空整数列。null → null；非 int → LocalIOError。
  int? optInt(String col) {
    final v = this[col];
    if (v == null) return null;
    if (v is int) return v;
    throw _decodeError(col, 'int', v);
  }

  /// 可空浮点列(REAL/double precision)。null → null；num → toDouble；否则 LocalIOError。
  double? optDouble(String col) {
    final v = this[col];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    throw _decodeError(col, 'double', v);
  }

  /// 可空布尔列(BOOLEAN)。null → null；非 bool → LocalIOError。
  bool? optBool(String col) {
    final v = this[col];
    if (v == null) return null;
    if (v is bool) return v;
    throw _decodeError(col, 'bool', v);
  }

  /// JSONB 字符串数组列。null/空 → const []；驱动可能回已解码 List 或 JSON 文本，
  /// 两者都容忍（元素强制 toString）。非 List/非 JSON 数组 → LocalIOError。
  List<String> stringList(String col) {
    final v = this[col];
    if (v == null) return const <String>[];
    if (v is List) {
      return v.map((e) => e.toString()).toList(growable: false);
    }
    if (v is String) {
      if (v.trim().isEmpty) return const <String>[];
      final decoded = jsonDecode(v);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList(growable: false);
      }
      throw _decodeError(col, 'List', v);
    }
    throw _decodeError(col, 'List', v);
  }
}
