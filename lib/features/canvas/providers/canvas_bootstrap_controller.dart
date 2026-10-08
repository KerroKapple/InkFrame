// CanvasBootstrapController — 示例项目创建入口（ON-2/ON-2b）。
//
// createSample 建示例 Project + Canvas 并种入演示内容：1 条示例泳道 +
// 1 个预填 prompt 的 image config 节点 + 该节点名下两个 result 节点
// （随应用打包的两张水墨成片，P7 把原「内置示例」页并进来——那两张图不再需要
// 一个专门的浮层来看，它们现在就是一个真项目里的真产物，能进画廊、能对比、
// 能「存为角色」）。全程纯本地，不触发生成、不要 API Key。
//
// 三个 UI 入口（首启向导 / Studio 空态 / Studio 网格虚线格）传入 l10n 化的
// SampleSeed，本控制器不触 l10n（分层：文案属 UI 层）；成片的资产路径是内部
// 字面量，不进 ARB。
//
// 落库走 UnitOfWork 单事务——任一步失败整体回滚，不留半成品示例项目。
// 成片是 best-effort：资产读不出来或写盘失败就少种几个 result 节点，绝不把
// 一次能成的示例项目拖垮；顺序恒为「先落盘、再建节点」，于是不会留下指向
// 不存在文件的节点（反过来留下的孤儿文件由 DiskOrphanFileReaper 记账）。

import 'dart:async' show unawaited;
import 'dart:io' show FileSystemException;
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show AssetBundle, ByteData, PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/asset_bundle.dart';
import '../../../core/di/file_resolver.dart';
import '../../../core/di/logger.dart';
import '../../../core/di/preferences.dart';
import '../../../core/di/repositories.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../core/interfaces/unit_of_work.dart';
import '../../../core/logging/logger_service.dart';
import '../../shell/models/shell_state.dart';
import '../../shell/providers/shell_controller.dart';
import '../models/canvas_node.dart';

/// 示例内容文案（UI 层从 ARB 构造传入）。
typedef SampleSeed = ({
  String laneLabel,
  String laneStylePrompt,
  String nodeLabel,
  String nodePrompt,
});

/// 示例节点世界坐标：默认泳道厚 400（horizontal 带 = Y ∈ [0,400)），
/// image 默认尺寸 260×220 → (120, 90) 整体落带内且贴近舞台原点（首启视野）。
const Offset kSampleNodePosition = Offset(120, 90);

/// 随应用打包的示例成片（原「内置示例」那两张水墨图）。顺序即种入顺序。
const List<String> kSampleArtifactAssets = <String>[
  'assets/samples/ink-wash-mountains-square.jpg',
  'assets/samples/ink-wash-storyboard-wide.jpg',
];

/// 成片在画布目录下的相对路径前缀（`images/sample-1.jpg` …）。
const String _kSampleArtifactStem = 'images/sample';

/// 成片节点落在 config 节点右侧一排（不进泳道，与生成路径一致）。
const Offset _kFirstArtifactPosition = Offset(440, 90);
const double _kArtifactStepX = 300;

const String _logModule = 'canvas.bootstrap';

final canvasBootstrapControllerProvider = Provider.autoDispose(
  CanvasBootstrapController.new,
  name: 'canvasBootstrapControllerProvider',
);

class CanvasBootstrapController {
  CanvasBootstrapController(this._ref);

  final Ref _ref;

  /// 创建示例 Project + Canvas + 演示内容并切换到该画布。返回新画布 id。
  ///
  /// ME-27：本 provider 是 autoDispose，await 期间可能被 dispose——所有
  /// _ref.read 在入口同步完成，await 之后不再触 _ref。
  Future<String> createSample({
    required String projectName,
    required String canvasName,
    required SampleSeed seed,
  }) async {
    final uowFuture = _ref.read(unitOfWorkProvider.future);
    final nav = _ref.read(shellControllerProvider.notifier);
    final prefs = _ref.read(preferencesServiceProvider);
    final bundle = _ref.read(assetBundleProvider);
    final fileResolver = _ref.read(fileResolverServiceProvider);
    final logger = _ref.read(loggerProvider);
    final uow = await uowFuture;
    final nodeSize = defaultNodeSize(CanvasNodeType.image);
    // 成片字节先读出来：它不依赖任何 id，读失败就当没有成片（示例项目照建）。
    final List<Uint8List> artifacts = await _loadArtifacts(bundle, logger);
    final ids = await uow.run((s) async {
      final projectId = await s.projects.create(name: projectName);
      final canvasId = await s.canvas.create(
        projectId: projectId,
        name: canvasName,
      );
      final laneId = await s.styleLanes.create(
        canvasId: canvasId,
        label: seed.laneLabel,
        stylePrompt: seed.laneStylePrompt,
      );
      final configNodeId = await s.nodes.create(
        canvasId: canvasId,
        type: CanvasNodeType.image.name,
        nodeRole: NodeRole.config.name,
        label: seed.nodeLabel,
        laneId: laneId,
        positionX: kSampleNodePosition.dx,
        positionY: kSampleNodePosition.dy,
        width: nodeSize.width,
        height: nodeSize.height,
        typeConfig: <String, Object?>{'prompt': seed.nodePrompt},
      );
      await _seedArtifactNodes(
        scope: s,
        projectId: projectId,
        canvasId: canvasId,
        configNodeId: configNodeId,
        nodeSize: nodeSize,
        artifacts: artifacts,
        fileResolver: fileResolver,
        logger: logger,
      );
      return (projectId: projectId, canvasId: canvasId);
    });
    nav.openCanvas(
      ids.canvasId,
      withProject: ProjectRef(id: ids.projectId, name: projectName),
    );
    // 记住上次会话（fire-and-forget，服务内部吞盘错误）。
    unawaited(prefs.update(
      (p) => p.copyWith(
        lastCanvasId: ids.canvasId,
        lastProjectId: ids.projectId,
      ),
    ));
    return ids.canvasId;
  }

  /// 读打包成片的字节。任一张读不出来就整体放弃（宁可一张都不种，也不种半套
  /// 让「两张成片」的示例变成随机一张）。
  Future<List<Uint8List>> _loadArtifacts(
    AssetBundle bundle,
    LoggerService logger,
  ) async {
    final List<Uint8List> out = <Uint8List>[];
    for (final String asset in kSampleArtifactAssets) {
      try {
        final ByteData data = await bundle.load(asset);
        out.add(data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        ));
      } on FlutterError catch (e) {
        // AssetBundle.load 的真实抛出类型（资产没声明进 pubspec / 名字写错）。
        logger.warn(_logModule, 'sample artifact asset missing',
            extra: <String, Object?>{'asset': asset, 'message': e.message});
        return const <Uint8List>[];
      } on PlatformException catch (e) {
        logger.warn(_logModule, 'sample artifact asset unreadable',
            extra: <String, Object?>{'asset': asset, 'code': e.code});
        return const <Uint8List>[];
      }
    }
    return out;
  }

  /// 先落盘、再建 result 节点；某一张写盘失败就跳过它（不留指向不存在文件的节点）。
  Future<void> _seedArtifactNodes({
    required RepositoryScope scope,
    required String projectId,
    required String canvasId,
    required String configNodeId,
    required Size nodeSize,
    required List<Uint8List> artifacts,
    required FileResolverService fileResolver,
    required LoggerService logger,
  }) async {
    for (var i = 0; i < artifacts.length; i++) {
      final String relativePath = '$_kSampleArtifactStem-${i + 1}.jpg';
      final bool written = await _writeArtifact(
        projectId: projectId,
        canvasId: canvasId,
        relativePath: relativePath,
        bytes: artifacts[i],
        fileResolver: fileResolver,
        logger: logger,
      );
      if (!written) continue;
      await scope.nodes.create(
        canvasId: canvasId,
        type: CanvasNodeType.image.name,
        nodeRole: NodeRole.result.name,
        sourceNodeId: configNodeId,
        positionX: _kFirstArtifactPosition.dx + _kArtifactStepX * i,
        positionY: _kFirstArtifactPosition.dy,
        width: nodeSize.width,
        height: nodeSize.height,
        typeConfig: <String, Object?>{'image_url': relativePath},
      );
    }
  }

  Future<bool> _writeArtifact({
    required String projectId,
    required String canvasId,
    required String relativePath,
    required Uint8List bytes,
    required FileResolverService fileResolver,
    required LoggerService logger,
  }) async {
    try {
      final file = fileResolver.resolve(
        projectId: projectId,
        canvasId: canvasId,
        relativePath: relativePath,
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    } on FileSystemException catch (e) {
      logger.warn(_logModule, 'sample artifact write failed',
          extra: <String, Object?>{
            'path': relativePath,
            'message': e.message,
          });
      return false;
    } on PathSecurityError catch (e) {
      logger.warn(_logModule, 'sample artifact path rejected',
          extra: <String, Object?>{
            'path': relativePath,
            'message': e.message,
          });
      return false;
    }
  }
}
