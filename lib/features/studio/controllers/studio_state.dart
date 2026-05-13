// Studio 模块共享状态：当前 studio 名 + 侧栏选中的 project。
import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentStudioProvider = StateProvider<String>((_) => 'Kerro Studio');
final selectedProjectIdProvider = StateProvider<String?>((_) => null);
