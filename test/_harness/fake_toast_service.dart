// RecordingToastService：测试用 ToastService，只记录不画。
//
// 覆盖 toastServiceProvider 后，断言 [RecordingToastService.shown]（按弹出顺序）。
// 句柄的 update / complete / dismiss 也记下来，测进度卡用。
import 'package:inkframe/core/interfaces/toast_service.dart';

class RecordedToast {
  RecordedToast({
    required this.title,
    required this.kind,
    this.body,
    this.meta,
    this.thumbnailPath,
    this.primary,
    this.secondary,
    this.dedupeKey,
    this.chime = false,
  });

  String title;
  ToastKind kind;
  String? body;
  final String? meta;
  String? thumbnailPath;
  ToastAction? primary;
  ToastAction? secondary;
  final String? dedupeKey;
  bool chime;
  double? progress;
  bool dismissed = false;
}

class RecordingToastService implements ToastService {
  final List<RecordedToast> shown = <RecordedToast>[];

  /// 只看类型的便捷视图。
  List<ToastKind> get kinds => <ToastKind>[for (final t in shown) t.kind];

  /// 只看标题的便捷视图。
  List<String> get titles => <String>[for (final t in shown) t.title];

  @override
  ToastHandle show(
    String title, {
    ToastKind kind = ToastKind.info,
    String? body,
    String? meta,
    String? thumbnailPath,
    ToastAction? primary,
    ToastAction? secondary,
    String? dedupeKey,
    bool chime = false,
  }) {
    final RecordedToast t = RecordedToast(
      title: title,
      kind: kind,
      body: body,
      meta: meta,
      thumbnailPath: thumbnailPath,
      primary: primary,
      secondary: secondary,
      dedupeKey: dedupeKey,
      chime: chime,
    );
    shown.add(t);
    return _RecordingHandle(t);
  }
}

class _RecordingHandle implements ToastHandle {
  _RecordingHandle(this._t);

  final RecordedToast _t;

  @override
  void update({String? title, String? body, double? progress}) {
    if (title != null) _t.title = title;
    if (body != null) _t.body = body;
    if (progress != null) _t.progress = progress;
  }

  @override
  void complete({
    required ToastKind kind,
    required String title,
    String? body,
    String? thumbnailPath,
    ToastAction? primary,
    ToastAction? secondary,
    bool chime = false,
  }) {
    _t
      ..kind = kind
      ..title = title
      ..body = body
      ..thumbnailPath = thumbnailPath
      ..primary = primary
      ..secondary = secondary
      ..chime = chime;
  }

  @override
  void dismiss() => _t.dismissed = true;
}
