// 事件日志的只读视图：按 seq 索引、沿 parent_seq 走出一条分支。
//
// 日志是一棵树：每件事件的 parent_seq 指向它接在哪件之后（null = 空根）。
// 「当前分支」= 从某个头事件沿父链走回根；分叉 = 新事件挂到更早的事件上。
import '../../../core/models/director.dart';

class DirectorLog {
  DirectorLog(Iterable<DirectorEvent> events)
      : events = List<DirectorEvent>.unmodifiable(
          events.toList()..sort((DirectorEvent a, DirectorEvent b) => a.seq.compareTo(b.seq)),
        ) {
    for (final DirectorEvent e in this.events) {
      _bySeq[e.seq] = e;
    }
  }

  /// 全部事件，按 seq 升序。
  final List<DirectorEvent> events;
  final Map<int, DirectorEvent> _bySeq = <int, DirectorEvent>{};

  DirectorEvent? operator [](int seq) => _bySeq[seq];

  /// 最近追加的事件 seq；空日志 ⇒ null。
  int? get latestSeq => events.isEmpty ? null : events.last.seq;

  /// 从根到 [head] 的一条分支（含 head，按先后）。head 为 null / 不存在 ⇒ 空。
  List<DirectorEvent> pathTo(int? head) {
    final List<DirectorEvent> out = <DirectorEvent>[];
    final Set<int> seen = <int>{};
    DirectorEvent? cur = head == null ? null : _bySeq[head];
    while (cur != null && seen.add(cur.seq)) {
      out.add(cur);
      final int? parent = cur.parentSeq;
      cur = parent == null ? null : _bySeq[parent];
    }
    return out.reversed.toList(growable: false);
  }

  /// [head] 所在分支上最近一件 [kind]。
  DirectorEvent? lastOnPath(int? head, DirectorEventKind kind) {
    final List<DirectorEvent> path = pathTo(head);
    for (int i = path.length - 1; i >= 0; i--) {
      if (path[i].kind == kind) return path[i];
    }
    return null;
  }

  Iterable<DirectorEvent> ofKind(DirectorEventKind kind) =>
      events.where((DirectorEvent e) => e.kind == kind);

  DirectorLog append(DirectorEvent e) => DirectorLog(<DirectorEvent>[...events, e]);
}
