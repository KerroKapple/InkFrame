// activeProjectProvider：ShellState.project 的派生只读投影（M-2 补测，
// fix round 1）。仓库规则「Every public method has a test」——此前零消费者
// 零测试。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/active_project.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

void main() {
  test('seed 带 project 的 ShellState → 读出对应 ProjectRef', () {
    final container = ProviderContainer(
      overrides: [
        shellControllerProvider.overrideWith(
          () => ShellNavigator(
            initial: const ShellState(
              tab: ShellTab.gallery,
              project: ProjectRef(id: 'p1', name: 'Alpha'),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(activeProjectProvider),
      const ProjectRef(id: 'p1', name: 'Alpha'),
    );
  });

  // 原本这条走 setProject——那个迁移是死 API（lib/ 下只有定义），已删。
  // 本条测的是投影【跟着真相源变】，换成任一真实在用的换项目迁移都成立，
  // 这里取 openGallery（Studio 点项目卡走的就是它）。
  test('openGallery 换项目后投影跟着变', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(activeProjectProvider), isNull);

    container
        .read(shellControllerProvider.notifier)
        .openGallery(const ProjectRef(id: 'p2', name: 'Beta'));

    expect(
      container.read(activeProjectProvider),
      const ProjectRef(id: 'p2', name: 'Beta'),
    );
  });
}
