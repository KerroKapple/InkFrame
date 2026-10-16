// 示例项目的种子文案：三个入口（首启向导 / Studio 空态与网格虚线格 / ⌘K）共用这一处从 ARB 取。
//
// 原来每个入口各写一份 record 字面量——SampleSeed 加一个字段就得逐个入口去补，漏一个就是编译错。
// 只收用户看得见的文案（泳道名、两镜的节点名与提示词）；泳道风格提示词是发给模型的，
// 英文常量在控制器里（kSampleLaneStylePrompt），不进 ARB。
import '../../../l10n/generated/app_localizations.dart';
import '../providers/canvas_bootstrap_controller.dart';

/// [l] 语言下的示例种子文案。
SampleSeed sampleSeedOf(AppLocalizations l) => (
      laneLabel: l.canvasSampleLaneLabel,
      nodeLabel: l.canvasSampleNodeLabel,
      nodePrompt: l.canvasSampleNodePrompt,
      secondNodeLabel: l.canvasSampleSecondNodeLabel,
      secondNodePrompt: l.canvasSampleSecondNodePrompt,
    );
