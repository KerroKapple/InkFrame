// 左栏状态（PR-4）：页键 / 收起键 / 「管理」链接三种入口各自的语义。
//
// 靶子是开合规则本身：点展开着的当前页 = 收起；点别的页 = 展开并切页（哪怕原来收着）；
// 收起键只动开合、不动页；「管理」= 无论原来什么状态都展开并停在角色页。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/left_rail_state.dart';

void main() {
  late ProviderContainer container;
  LeftRailController control() => container.read(leftRailProvider.notifier);
  LeftRailState state() => container.read(leftRailProvider);

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('默认：展开、停在大纲页（稿上第一眼就是大纲）', () {
    expect(state(), const LeftRailState(page: LeftRailPage.outline));
    expect(state().expanded, isTrue);
    expect(state().isActive(LeftRailPage.outline), isTrue);
    expect(state().isActive(LeftRailPage.assets), isFalse);
  });

  test('点展开着的当前页 = 收起，页照旧记着', () {
    control().tapPage(LeftRailPage.outline);
    expect(state(), const LeftRailState(page: LeftRailPage.outline, expanded: false));
    expect(state().isActive(LeftRailPage.outline), isFalse, reason: '收起后没有键是点亮的');
  });

  test('点非当前页 = 展开并切到该页；收着时点任何页键也是展开', () {
    control().tapPage(LeftRailPage.assets);
    expect(state(), const LeftRailState(page: LeftRailPage.assets));

    control().tapPage(LeftRailPage.assets); // 收起
    control().tapPage(LeftRailPage.characters);
    expect(state(), const LeftRailState(page: LeftRailPage.characters));

    control().tapPage(LeftRailPage.characters); // 收起
    control().tapPage(LeftRailPage.characters); // 收着时点同一页 = 展开
    expect(state(), const LeftRailState(page: LeftRailPage.characters));
  });

  test('收起键（toggle）只动开合，不动页', () {
    control().tapPage(LeftRailPage.assets);
    control().toggle();
    expect(state(), const LeftRailState(page: LeftRailPage.assets, expanded: false));
    control().toggle();
    expect(state(), const LeftRailState(page: LeftRailPage.assets));
  });

  test('open（「管理」链接）：收着也展开，并停在指定页', () {
    control().toggle();
    expect(state().expanded, isFalse);
    control().open(LeftRailPage.characters);
    expect(state(), const LeftRailState(page: LeftRailPage.characters));
  });

  test('同值重设不通知（导航条与面板都 watch 它）', () {
    int notified = 0;
    container.listen<LeftRailState>(leftRailProvider, (_, _) => notified++);
    control().open(LeftRailPage.outline); // 与默认值相等
    expect(notified, 0);
    control().open(LeftRailPage.assets);
    expect(notified, 1);
  });
}
