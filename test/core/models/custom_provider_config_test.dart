// CustomProviderConfig：providerId 派生 + snake_case JSON 序列化契约。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/custom_provider_config.dart';

void main() {
  const config = CustomProviderConfig(
    id: 'my-endpoint',
    displayName: 'My Endpoint',
    template: 'openai-image',
    baseUrl: 'https://example.com/v1',
    modelId: 'flux-pro',
  );

  test('providerId = custom:<id>', () {
    expect(config.providerId, 'custom:my-endpoint');
    expect(config.providerId, startsWith(kCustomProviderIdPrefix));
  });

  test('fromJson 读 snake_case key', () {
    final parsed = CustomProviderConfig.fromJson(const {
      'id': 'my-endpoint',
      'display_name': 'My Endpoint',
      'template': 'openai-image',
      'base_url': 'https://example.com/v1',
      'model_id': 'flux-pro',
    });
    expect(parsed, config);
  });

  test('toJson/fromJson round-trip', () {
    final json = config.toJson();
    expect(json['display_name'], 'My Endpoint');
    expect(json['base_url'], 'https://example.com/v1');
    expect(json['model_id'], 'flux-pro');
    expect(CustomProviderConfig.fromJson(json), config);
  });
}
