// Clock provider：所有时间相关逻辑都通过 ref.read(clockProvider) 取值，单测覆盖 fake。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/logger_service.dart';

final clockProvider = Provider<Clock>(
  (ref) => const SystemClock(),
  name: 'clockProvider',
);
