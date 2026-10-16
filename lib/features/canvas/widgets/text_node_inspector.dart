// TextNodeInspector：单选 text 节点时的正文编辑面板（演示里的 F1：此前检查器对文本节点留空，
// 卡片又是只读的，文本节点根本没地方写内容）。
//
// 存哪：type_config.text——与读侧同一个键：生成链路 GenerationController._resolveAssociatedTexts
// 读 `tc['text']`，检查器的最终提示词预览与卡片正文读 CanvasNode.textContent（同一个键）。
//
// 怎么存：InspectorSubmitController(nodeId).saveDebounced——与镜头备注 / 提示词条同一条防抖写入链
// （按键合并、挂起期间 keepAlive、失败自动重试 + 检查器底部的「未保存 · 重试」行、退出前冲刷），
// 不另起一条。
//
// 卡片与预览什么时候跟上：防抖只写库、不动画布节点控制器的内存节点表。所以输入框失焦时（编辑告一段落）
// 再经同一条链立即写一笔、写完让本画布的节点控制器重载一次——卡片正文、连到的图像节点的提示词预览随之刷新。
// 与预设落库后 invalidate 节点控制器是同一个做法。这一笔与随后触发的防抖写的是同一个值，重复无害。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/components/ink_input.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/inspector_submit_controller.dart';
import 'inspector_rows.dart';

/// text 节点正文所在的 type_config 键（读侧见头注）。
const String kTextNodeContentKey = 'text';

class TextNodeInspector extends ConsumerStatefulWidget {
  const TextNodeInspector({super.key, required this.node});

  final CanvasNode node;

  /// 正文输入框的测试锚点。
  static const Key contentFieldKey = Key('inspector.text.content');

  @override
  ConsumerState<TextNodeInspector> createState() => _TextNodeInspectorState();
}

class _TextNodeInspectorState extends ConsumerState<TextNodeInspector> {
  late final TextEditingController _content =
      TextEditingController(text: widget.node.textContent ?? '');
  final FocusNode _focus = FocusNode();

  /// 上次让画布重载之后又改过——失焦时才需要再写一笔 + 重载。
  bool _dirty = false;

  InspectorSubmitController get _submitCtrl =>
      ref.read(inspectorSubmitControllerProvider(widget.node.id).notifier);

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    // 先摘监听再销毁：卸载引起的失焦不该再碰 ref（State 已卸载，ref 不可用）。挂起的防抖由控制器
    // 自己保活写完，不靠这里。
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _content.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _dirty = true;
    _submitCtrl.saveDebounced(<String, Object?>{kTextNodeContentKey: value});
  }

  void _onFocusChanged() {
    if (!mounted || _focus.hasFocus || !_dirty) return;
    unawaited(_commitAndRefresh());
  }

  /// 立即写一笔（同一条串行链，落库顺序 = 发起顺序）并让画布节点表重载。saveConfig 不抛——
  /// 失败照常翻成自动保存失败态，由检查器底部的失败行上屏 + 重试。
  Future<void> _commitAndRefresh() async {
    _dirty = false;
    final String? canvasId = widget.node.canvasId;
    await _submitCtrl.saveConfig(<String, Object?>{kTextNodeContentKey: _content.text});
    if (!mounted || canvasId == null) return;
    ref.invalidate(canvasNodesControllerProvider(canvasId));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // 订阅着写入控制器（不读值）：面板在屏期间它不被 autoDispose 回收，与 image / video 配置面板同口径；
    // 挂起写入期间控制器另有自己的 keepAlive。
    ref.watch(inspectorSubmitControllerProvider(widget.node.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InspectorGroup(
          title: l.canvasNodeTextType,
          children: <Widget>[
            InspectorRow(
              label: l.inspectorTextContentLabel,
              height: null,
              child: InkInput(
                key: TextNodeInspector.contentFieldKey,
                controller: _content,
                focusNode: _focus,
                hintText: l.inspectorTextContentHint,
                minLines: 4,
                maxLines: 14,
                onChanged: _onChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
