// WsTone → 颜色槽：呈现层按语义色调取 token，不传 Color。
import 'package:flutter/widgets.dart';

import '../../../theme/tokens.dart';
import '../models/workspace_fixture.dart';

extension WsToneX on WsTone {
  Color fg(InkColors c) => this == WsTone.accent ? c.accent : c.fg4;
  Color strong(InkColors c) => this == WsTone.accent ? c.accent : c.fg5;
}
