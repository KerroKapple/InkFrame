// Studio 模块共享状态：当前 studio 名 + 侧栏选中的 project。
// 跳 Settings 由 currentScreenProvider 直接承担，不再需要本地意图桥。
// studio 名未设置时为 null，UI 层用 l10n.studioDefaultName 兜底。
import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentStudioProvider = StateProvider<String?>((_) => null);
final selectedProjectIdProvider = StateProvider<String?>((_) => null);
