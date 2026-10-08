// 交付面板（P6）：序列标签右侧那一栏 320，替掉 P2 留的占位。
//
// 三层（几何照抄静态复刻件，见 delivery_panel_rows.dart 头注）：
//   页签条 29（交付 / 片段 / 历史——后两个**只画标签不挂内容**，点击无反应、无 hover）
//   滚动区（目标软件块 + 三个分组 + 交付前检查）
//   底部摘要 59（固定，不随滚动）
// 结果条（32）插在页签条下面、滚动区上面：它是「上一次交付的回执」，不该被滚走。
//
// 本件只负责**呈现 + 把改动交给 controller**：
//   - 交付设置读写 → deliverySettingsProvider（改动即存，无保存按钮）
//   - 计划 / 检查项 → deliveryPlanProvider / deliveryPreflightProvider（与主按钮同源）
//   - 真正的落盘 → run_delivery.dart（唯一入口）
//
// 门控（任务书 §5）：`ShellState.project == null` ⇒ 整面板只剩「请先打开一个项目」，
// **不碰任何仓储**（deliveryPlanProvider 里那一支同口径）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/folder_opener.dart';
import '../../../core/interfaces/delivery_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../shell/models/shell_state.dart';
import '../../shell/providers/active_project.dart';
import '../delivery_keys.dart';
import '../models/delivery_plan.dart';
import '../models/delivery_settings.dart';
import '../models/delivery_writer_registry.dart';
import '../providers/delivery_controller.dart';
import '../providers/delivery_plan_provider.dart';
import '../providers/delivery_settings_controller.dart';
import '../providers/delivery_writers.dart';
import '../run_delivery.dart';
import '../util/delivery_preflight.dart';
import '../util/delivery_target_labels.dart';
import 'delivery_panel_rows.dart';
import 'delivery_preflight_list.dart';
import 'delivery_result_bar.dart';

class DeliveryPanel extends ConsumerWidget {
  const DeliveryPanel({super.key, required this.canvasId});

  final String canvasId;

  /// 稿：320 content + 1px 左沿。
  static const double contentWidth = 320;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProjectRef? project = ref.watch(activeProjectProvider);
    if (project == null) {
      return _PanelFrame(
        child: Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(InkSpacing.s12),
              child: Text(
                key: DeliveryKeys.emptyState,
                context.l10n.deliveryNoProject,
                textAlign: TextAlign.center,
                style: context.inkTypography.meta.copyWith(
                  color: context.inkColors.fg5,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return _DeliveryPanelBody(canvasId: canvasId, project: project);
  }
}

/// 外框 + 页签条。两态共用（空态也要有页签条，面板位置不该忽然塌掉）。
class _PanelFrame extends StatelessWidget {
  const _PanelFrame({required this.child, this.extra});

  final Widget child;
  final List<Widget>? extra;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    // 必须是 Container 不能是 DecoratedBox：后者只画边框、不占位，1px 左沿会
    // 盖掉内容第一列，整栏跟着左移 1px（复刻件同注）。
    return Container(
      key: DeliveryKeys.panel,
      width: DeliveryPanel.contentWidth + 1,
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border(left: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _Tabs(),
          ...?extra,
          child,
        ],
      ),
    );
  }
}

/// 页签条 29 = 28 内容 + 1px 下沿。当前页**顶部** 1px 琥珀线，底色与面板连成一片。
/// 「片段」「历史」只画标签：没有内容可挂，挂个点击就是死交互。
class _Tabs extends StatelessWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    final AppLocalizations l = context.l10n;
    final List<String> labels = <String>[
      l.sequenceDeliveryTab,
      l.deliveryTabClips,
      l.deliveryTabHistory,
    ];
    return Container(
      height: kDvTabsHeight,
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < labels.length; i++)
            SizedBox(
              width: kDvTabWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: i == 0 ? c.surface3 : null,
                  border:
                      i == 0 ? Border(top: BorderSide(color: c.accent)) : null,
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: (i == 0 ? t.bodyStrong : t.body).copyWith(
                      color: i == 0 ? c.fg1 : c.fg5,
                      height: kDvLhSans12 / 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DeliveryPanelBody extends ConsumerWidget {
  const _DeliveryPanelBody({required this.canvasId, required this.project});

  final String canvasId;
  final ProjectRef project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DeliverySettings settings =
        ref.watch(deliverySettingsProvider(project.id)).valueOrNull ??
            DeliverySettings.defaults;
    final DeliveryPlan plan = ref.watch(deliveryPlanProvider(canvasId));
    final DeliveryPreflight preflight =
        ref.watch(deliveryPreflightProvider(canvasId));
    final DeliveryWriterRegistry registry =
        ref.watch(deliveryWriterRegistryProvider);
    final DeliveryState delivery = ref.watch(deliveryControllerProvider);

    void save(DeliverySettings next) {
      ref.read(deliverySettingsProvider(project.id).notifier).save(next);
    }

    return _PanelFrame(
      extra: <Widget>[
        if (delivery is DeliverySucceeded)
          DeliveryResultBar.success(
            outcome: delivery.outcome,
            onOpenFolder: () => _openFolder(ref, delivery.outcome),
            onCopyPath: () => _copyPath(delivery.outcome),
            onDismiss: () =>
                ref.read(deliveryControllerProvider.notifier).dismissResult(),
          )
        else if (delivery is DeliveryFailed)
          DeliveryResultBar.failure(
            error: delivery.error,
            onRetry: () => runDeliveryForCanvas(ref, canvasId),
            onDismiss: () =>
                ref.read(deliveryControllerProvider.notifier).dismissResult(),
          ),
      ],
      child: Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _TargetBlock(
                      settings: settings,
                      registry: registry,
                      onSelect: (DeliveryTarget t) =>
                          save(settings.copyWith(target: t)),
                    ),
                    _ProjectFileGroup(
                      settings: settings,
                      registry: registry,
                      onTcStart: (int frames) =>
                          save(settings.copyWith(timecodeStartFrames: frames)),
                    ),
                    _MediaGroup(
                      settings: settings,
                      onRelativePaths: (bool v) =>
                          save(settings.copyWith(relativePaths: v)),
                    ),
                    _MarkersGroup(
                      settings: settings,
                      onSceneMarkers: (bool v) =>
                          save(settings.copyWith(markersFromScenes: v)),
                      onShotLanguage: (bool v) =>
                          save(settings.copyWith(shotLanguageInComments: v)),
                    ),
                    DeliveryPreflightList(
                      preflight: preflight,
                      projectName: project.name,
                    ),
                  ],
                ),
              ),
            ),
            _Footer(plan: plan, registry: registry, projectId: project.id),
          ],
        ),
      ),
    );
  }

  void _openFolder(WidgetRef ref, DeliveryOutcome outcome) {
    // best-effort：打不开文件夹（缺可执行文件）不该崩 UI（与 LB-09 同款）。
    ref.read(folderOpenerProvider).open(outcome.outputDirAbsolutePath).ignore();
  }

  void _copyPath(DeliveryOutcome outcome) {
    Clipboard.setData(ClipboardData(text: outcome.outputDirAbsolutePath))
        .ignore();
  }
}

/// 目标软件块：标签 + 四段分段控件 + 11px 说明。
class _TargetBlock extends StatelessWidget {
  const _TargetBlock({
    required this.settings,
    required this.registry,
    required this.onSelect,
  });

  final DeliverySettings settings;
  final DeliveryWriterRegistry registry;
  final ValueChanged<DeliveryTarget> onSelect;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    final AppLocalizations l = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        InkSpacing.s12,
        InkSpacing.s14,
        InkSpacing.s12,
        InkSpacing.s12,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l.sequenceDeliveryTargets,
            style: t.body.copyWith(color: c.fg4, height: kDvLhSans12 / 12),
          ),
          const SizedBox(height: InkSpacing.s10),
          DeliverySegments<DeliveryTarget>(
            items: DeliveryTarget.values,
            selected: settings.target,
            labelOf: (DeliveryTarget t) => deliveryTargetLabel(l, t),
            // 可选性**只问 registry**：接上写出器那一段自动可选。
            enabledOf: registry.supports,
            keyOf: DeliveryKeys.segment,
            tooltipOf: (DeliveryTarget t) =>
                registry.supports(t) ? null : deliveryPendingTooltip(l, t),
            onSelect: onSelect,
          ),
          const SizedBox(height: InkSpacing.s10),
          Text(
            l.deliveryTargetHint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.meta.copyWith(color: c.fg6, height: kDvLhHint / 11),
          ),
        ],
      ),
    );
  }
}

class _ProjectFileGroup extends StatelessWidget {
  const _ProjectFileGroup({
    required this.settings,
    required this.registry,
    required this.onTcStart,
  });

  final DeliverySettings settings;
  final DeliveryWriterRegistry registry;
  final ValueChanged<int> onTcStart;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return DeliveryGroup(
      title: l.deliveryGroupProject,
      rows: <Widget>[
        DeliverySettingRow(
          label: l.deliveryRowFormat,
          value: DeliveryReadonlyValue(
            key: DeliveryKeys.formatValue,
            text: deliveryFormatLabel(l, registry, settings.target),
          ),
        ),
        DeliverySettingRow(
          label: l.deliveryRowFps,
          value: DeliveryMonoValue(text: l.deliveryFpsValue),
        ),
        DeliverySettingRow(
          label: l.deliveryRowTcStart,
          value: DeliveryTimecodeField(
            key: DeliveryKeys.tcStartField,
            frames: settings.timecodeStartFrames,
            onCommit: onTcStart,
          ),
        ),
        DeliverySettingRow(
          label: l.deliveryRowTracks,
          // 稿写的是「V1 视频 · A1 音频分离」——A1 不存在，不写「音频分离」（任务书 §2.2）。
          value: DeliveryReadonlyValue(text: l.deliveryTracksValue),
        ),
      ],
    );
  }
}

class _MediaGroup extends StatelessWidget {
  const _MediaGroup({required this.settings, required this.onRelativePaths});

  final DeliverySettings settings;
  final ValueChanged<bool> onRelativePaths;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return DeliveryGroup(
      title: l.deliveryGroupMedia,
      rows: <Widget>[
        DeliverySettingRow(
          label: l.deliveryRowNaming,
          value: DeliveryMonoValue(text: l.deliveryNamingValue),
        ),
        DeliverySettingRow(
          label: l.deliveryRowTranscode,
          value: DeliveryReadonlyValue(text: l.deliveryTranscodeValue),
        ),
        DeliverySettingRow(
          label: l.deliveryRowRelativePaths,
          value: DeliveryToggleValue(
            key: DeliveryKeys.relativePathsToggle,
            on: settings.relativePaths,
            label: settings.relativePaths
                ? l.deliveryRelativePathsOn
                : l.deliveryRelativePathsOff,
            onChanged: onRelativePaths,
          ),
        ),
      ],
    );
  }
}

class _MarkersGroup extends StatelessWidget {
  const _MarkersGroup({
    required this.settings,
    required this.onSceneMarkers,
    required this.onShotLanguage,
  });

  final DeliverySettings settings;
  final ValueChanged<bool> onSceneMarkers;
  final ValueChanged<bool> onShotLanguage;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return DeliveryGroup(
      title: l.deliveryGroupMarkers,
      rows: <Widget>[
        DeliverySettingRow(
          label: l.deliveryRowSceneMarkers,
          value: DeliveryToggleValue(
            key: DeliveryKeys.sceneMarkersToggle,
            on: settings.markersFromScenes,
            label: settings.markersFromScenes
                ? l.deliverySceneMarkersOn
                : l.deliverySceneMarkersOff,
            onChanged: onSceneMarkers,
          ),
        ),
        DeliverySettingRow(
          label: l.deliveryRowShotLanguage,
          value: DeliveryToggleValue(
            key: DeliveryKeys.shotLanguageToggle,
            on: settings.shotLanguageInComments,
            label: settings.shotLanguageInComments
                ? l.deliveryShotLanguageOn
                : l.deliveryShotLanguageOff,
            onChanged: onShotLanguage,
          ),
        ),
        // 稿上「提示词 → metadata.json」那一行**已删**：提示词恒写，不给开关。
        DeliverySettingRow(
          label: l.deliveryRowPlaceholders,
          value: DeliveryReadonlyValue(text: l.deliveryPlaceholderValue),
        ),
      ],
    );
  }
}

/// 底部摘要 59 = padding 10×2 + 16 + gap 6 + 16 + 1px 上沿。固定，不随滚动。
class _Footer extends ConsumerWidget {
  const _Footer({
    required this.plan,
    required this.registry,
    required this.projectId,
  });

  final DeliveryPlan plan;
  final DeliveryWriterRegistry registry;
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    final AppLocalizations l = context.l10n;
    final TextStyle label =
        t.meta.copyWith(color: c.fg5, height: kDvLhSans11 / 11);
    final DeliveryProjectWriter? writer =
        registry.forTarget(plan.settings.target);
    final String path = ref.watch(deliveryOutputDirPathProvider(projectId)) ??
        kDeliveryOutputDirRelative;
    return Container(
      height: kDvFooterHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.s12,
        vertical: InkSpacing.s10,
      ),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(top: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(l.deliveryOutputLabel, style: label),
              // 路径是等宽，过长**中间**省略（尾部那一半才有信息）。
              //
              // 这里**不能**写成 `Spacer() + Flexible()`：两者 flex 都是 1，剩余
              // 宽会被五五分掉，值只拿到一半、再被自己的 ellipsis 截成「C:」。
              // 用 Expanded 独占剩余宽 + 右对齐，右边缘照样贴齐。
              // （同一个坑在画布头把缩放读数推离过中线，见 workspace golden 那次回归。）
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext inner, BoxConstraints box) {
                    // 量之前必须把外层 DefaultTextStyle 合进来：Text 自己会合，
                    // TextPainter 不会。只传 t.mono 的话字体族回落到更窄的那个，
                    // 量出来偏小 ⇒ 仍然放不下。同一个样式对象两边共用才对得上。
                    final TextStyle monoStyle =
                        DefaultTextStyle.of(inner).style.merge(
                              t.mono.copyWith(
                                color: c.fg5,
                                height: kDvLhMono11 / 11,
                              ),
                            );
                    return Text(
                      key: DeliveryKeys.footerOutput,
                      fitMiddleEllipsis(
                        path,
                        monoStyle,
                        box.maxWidth,
                        MediaQuery.textScalerOf(inner),
                      ),
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      style: monoStyle,
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: InkSpacing.s6),
          Row(
            children: <Widget>[
              Text(l.deliveryIncludeLabel, style: label),
              // 清单是无衬线——和上一行的字体不一样，别顺手统一。
              // 同上：Expanded 而不是 Spacer + Flexible。
              Expanded(
                child: Text(
                  key: DeliveryKeys.footerInclude,
                  l.deliveryIncludeSummary(
                    plan.mp4Count,
                    writer?.fileExtension ?? '',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: label,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
