// 设置浮层静态复刻的数据形状 + 稿上原文（docs/design/handoff-2026-09/InkFrame Screens.html 第 3 屏）。
//
// 与 palette_fixture 同例：手写 const 值对象，只在呈现层被读；假数据必须是稿上原文。
// 接线后本文件整体删除。
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

/// 状态列的语义色：稿上 ✓ 绿 / ! 琥珀 / – 灰 / ✕ 红。
enum SeState { verified, lowBalance, missing, failed }

@immutable
class SeProvider {
  const SeProvider({
    required this.name,
    required this.caps,
    required this.key,
    required this.region,
    required this.mark,
    required this.state,
    required this.status,
    this.keyMissing = false,
  });
  final String name;
  final String caps;
  final String key;
  /// 稿：未配置的 Key 列文字是 #6B6B6B（fg6），其余 #D6D6D6（fg2）。
  final bool keyMissing;
  final String region;
  final String mark;
  final String state;
  final SeState status;
}

@immutable
class SeSlider {
  const SeSlider({required this.label, required this.value, required this.pct});
  final String label;
  final String value;
  /// 稿：填充宽度百分比（0..1）。
  final double pct;
}

abstract final class SettingsFixture {
  static const Size designSize = Size(1600, 1000);
  static const Size dialogSize = Size(1120, 740);

  static const String title = '设置';
  static const String escHint = 'Esc';
  static const String close = '✕';

  static const List<String> nav = <String>['常规', 'API 密钥', '快捷键', '性能', '节点布局', '网络', '存储', '语言', '关于'];
  static const int selectedNav = 1;

  static const String pageTitle = 'API 密钥';
  static const String pageNote = 'Key 存入 macOS 钥匙串 / Windows 凭据管理器，不进数据库、不随项目导出。验证结果缓存 1 小时。';

  static const List<String> columns = <String>['Provider', 'Key', '区域', '状态'];

  static const List<SeProvider> providers = <SeProvider>[
    SeProvider(name: 'fal.ai', caps: '图像 · 视频 · 9 模型', key: 'fal_••••••••••••7c1e', region: '全球', mark: '✓', state: '已验证', status: SeState.verified),
    SeProvider(name: 'Google Gemini', caps: '图像 · gemini-image', key: 'AIza••••••••••••3f2a', region: '全球', mark: '✓', state: '已验证', status: SeState.verified),
    SeProvider(name: 'DashScope（阿里）', caps: '图像 · 视频 · Kling / Wanx', key: 'sk-••••••••••••9b40', region: '中国', mark: '✓', state: '已验证', status: SeState.verified),
    SeProvider(name: 'OpenAI', caps: '图像 · gpt-image-2', key: 'sk-••••••••••••1d77', region: '全球', mark: '!', state: '余额不足', status: SeState.lowBalance),
    SeProvider(name: 'Stability AI', caps: '图像 · Stable Image Core', key: '未配置', keyMissing: true, region: '全球', mark: '–', state: '未配置', status: SeState.missing),
    SeProvider(name: '本地 ComfyUI', caps: '自定义端点 · OpenAI 兼容', key: 'http://127.0.0.1:8188', region: '本地', mark: '✕', state: '连接失败', status: SeState.failed),
  ];

  static const String addCustom = '添加自定义 Provider';
  static const String reverifyAll = '全部重新验证';
  static const String customNote = 'OpenAI 兼容端点写入 custom_providers.json';

  static const String concurrencyTitle = '并发与配额';
  static const List<SeSlider> concurrency = <SeSlider>[
    SeSlider(label: '全局并发上限', value: '2', pct: 0.5),
    SeSlider(label: 'fal.ai 并发', value: '2', pct: 0.4),
    SeSlider(label: '轮询超时', value: '30 min', pct: 1.0),
  ];
  static const String concurrencyNote = '实际可调度数 = min(全局剩余槽位, 该 Provider 剩余槽位)。性能档位会改写全局上限。';

  static const String footerNote = '改动即时生效并写入钥匙串';
  static const String exportDiagnostics = '导出诊断包';
  static const String done = '完成';
}
