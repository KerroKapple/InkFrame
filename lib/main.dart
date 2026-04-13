// InkFrame 应用入口：初始化 ProviderScope 并挂载 InkFrameApp。
import 'package:flutter/widgets.dart';

void main() {
  runApp(const _BootstrapPlaceholder());
}

// 占位容器：真正的 App 在后续 step 中装配。
class _BootstrapPlaceholder extends StatelessWidget {
  const _BootstrapPlaceholder();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
