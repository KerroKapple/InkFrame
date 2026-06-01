import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/batch_result_repository.dart';
import 'package:inkframe/core/interfaces/style_lane_repository.dart';

void main() {
  test('styleLane / batchResult 已声明为正确类型的 FutureProvider', () {
    expect(styleLaneRepositoryProvider,
        isA<FutureProvider<StyleLaneRepository>>());
    expect(batchResultRepositoryProvider,
        isA<FutureProvider<BatchResultRepository>>());
  });
}
