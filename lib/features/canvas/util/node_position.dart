// 新建节点的默认落点：固定区域内随机散布，避免叠在同一点。
// Random 由调用方注入，保证可测。

import 'dart:math';
import 'dart:ui';

const double _kMinOffset = 200;
const double _kSpread = 400;

Offset pickRandomNodePosition(Random random) => Offset(
      _kMinOffset + random.nextDouble() * _kSpread,
      _kMinOffset + random.nextDouble() * _kSpread,
    );
