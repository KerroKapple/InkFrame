// 默认 Provider 标识符。
//
// config 节点未显式指定 provider_id 时，GenerationController 用这些中性常量兜底。
// 放 core/constants 而非 import 具体 provider 类——遵循 DIP，UI/Controller 不依赖
// providers/*_provider.dart 实现。值须与对应 Provider 的 capabilities.providerId 一致。

/// 默认文生图 Provider（对应 gemini_image_provider 的 kGeminiImageCapabilities.providerId）。
const String kDefaultImageProviderId = 'gemini-image';
