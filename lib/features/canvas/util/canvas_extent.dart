// 全向无限画布的舞台几何（B 案：居中定舞台）。
//
// 舞台是固定 100k×100k 的巨型 Stack，**世界原点在舞台正中央**——四个方向
// 都有 50k 的漫游空间，节点坐标可以为负（DB 原样存世界坐标）。
// 相机初始平移 -kStageHalf 对准世界原点（见 canvas_zoom.initialCanvasTransform），
// 所以默认视角下"屏幕坐标 == 世界坐标"，与旧的第一象限舞台行为无缝衔接。
//
// 为什么不做"内容驱动 + 原点搬移补偿"：原点变化发生在拖拽中会让舞台在
// 手指下面滑动（补偿矩阵与布局不同帧），一帧闪跳无法根除；定舞台没有任何
// 动态项，坐标数学一次定死。100k 边长在 float32 光栅坐标下精度损失 <0.1px。
import 'dart:ui';

/// 舞台半边长 = 世界原点到舞台边缘的距离（各方向可漫游 50k）。
const double kStageHalf = 50000;

/// 舞台尺寸（100k × 100k）。
const Size kStageSize = Size(kStageHalf * 2, kStageHalf * 2);

/// 世界原点在舞台坐标系中的位置（舞台正中央）。
const Offset kStageOrigin = Offset(kStageHalf, kStageHalf);

/// 节点可达的世界坐标范围（moveNode clamp）——距舞台边缘留 2000 余量，
/// 防止节点贴死边缘后无法再拖拽。
const double kWorldReach = kStageHalf - 2000;

/// 世界坐标 → 舞台坐标（Stack/Positioned/CustomPaint 使用的坐标系）。
Offset worldToStage(Offset world) => world + kStageOrigin;

/// 舞台坐标 → 世界坐标。
Offset stageToWorld(Offset stage) => stage - kStageOrigin;
