// FileSecureStorageService：本地开发兜底的文件型实现。
//
// 背景：macOS 上 flutter_secure_storage 依赖 Keychain，而 Keychain 访问
// 需要 code-sign 身份 + application-identifier entitlement。
// ad-hoc / 未签名的 Debug 构建无法访问 Keychain，报 errSecMissingEntitlement (-34018)。
//
// 本实现把密钥写到 AppPaths.config/secrets.dev.json，仅在 Debug 构建使用，
// Release 仍走 PlatformSecureStorageService（Keychain / Credential Manager）。
//
// 注意：文件未加密，仅用于本地开发。不要用这条路径分发任何构建产物。
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/interfaces/secure_storage_service.dart';
import '../core/paths/app_paths.dart';

class FileSecureStorageService implements SecureStorageService {
  FileSecureStorageService(this._pathsResolver);

  /// 懒取 AppPaths，避免在 provider 构造阶段就 watch appPathsProvider，
  /// 让不触发 store/retrieve 的测试免于必须 override appPathsProvider。
  final AppPaths Function() _pathsResolver;

  File get _file =>
      File(p.join(_pathsResolver().config.path, 'secrets.dev.json'));

  Future<Map<String, String>> _read() async {
    final f = _file;
    if (!await f.exists()) {
      return <String, String>{};
    }
    final raw = await f.readAsString();
    if (raw.trim().isEmpty) {
      return <String, String>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw StateError('secrets.dev.json not a JSON object');
    }
    return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  Future<void> _write(Map<String, String> data) async {
    final f = _file;
    if (!await f.parent.exists()) {
      await f.parent.create(recursive: true);
    }
    await f.writeAsString(jsonEncode(data), flush: true);
  }

  @override
  Future<void> store(String key, String value) async {
    final data = await _read();
    data[key] = value;
    await _write(data);
  }

  @override
  Future<String?> retrieve(String key) async {
    final data = await _read();
    return data[key];
  }

  @override
  Future<void> delete(String key) async {
    final data = await _read();
    data.remove(key);
    await _write(data);
  }

  @override
  Future<bool> exists(String key) async {
    final data = await _read();
    return data.containsKey(key);
  }
}
