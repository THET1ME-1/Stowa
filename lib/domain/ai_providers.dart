/// Поставщики ИИ, которых Stowa знает по имени. Ключ человек приносит свой,
/// поставщик узнаётся по началу ключа, а адрес, модель по умолчанию и умение
/// расшифровывать голос берутся отсюда. Любой другой API, совместимый с OpenAI,
/// подключается своим адресом.
library;

/// На каком языке говорит поставщик.
enum AiProtocol {
  /// `/chat/completions`, `/models`, `/audio/transcriptions`: OpenRouter, OpenAI и почти все остальные.
  openai,

  /// Messages API Anthropic: свои заголовки, `system` отдельно, картинки блоками `image`.
  anthropic,
}

class AiProvider {
  const AiProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.model,
    this.protocol = AiProtocol.openai,
    this.keyPattern,
    this.prefer = const [],
    this.speech = false,
    this.openModels = false,
  });

  final String id;
  final String name;
  final String baseUrl;
  final AiProtocol protocol;

  /// Модель разбора по умолчанию.
  final String model;

  /// Чем начинается ключ этого поставщика. Нет шаблона — ключ не узнаётся,
  /// поставщика выбирают руками (у DeepSeek и Qwen ключи одинакового вида).
  final RegExp? keyPattern;

  /// Части имён моделей от лучшей к худшей: когда модели по умолчанию в списке
  /// поставщика уже нет, берётся первая подходящая отсюда.
  final List<String> prefer;

  /// Есть `/audio/transcriptions`: голосовые можно расшифровывать.
  final bool speech;

  /// Список моделей отдаётся и без ключа: ключ проверяется коротким запросом к модели.
  final bool openModels;

  String get host => Uri.parse(baseUrl).host;
}

/// Адрес поставщика по умолчанию: OpenRouter, протокол OpenAI chat completions.
const defaultAiBaseUrl = 'https://openrouter.ai/api/v1';

/// Модель разбора по умолчанию: бесплатная, видит картинки, держит строгий JSON.
const defaultSortModel = 'nvidia/nemotron-3.5-super-vl:free';

final openRouter = AiProvider(
  id: 'openrouter',
  name: 'OpenRouter',
  baseUrl: defaultAiBaseUrl,
  model: defaultSortModel,
  keyPattern: RegExp(r'^sk-or-'),
  speech: true,
);

final anthropic = AiProvider(
  id: 'anthropic',
  name: 'Anthropic (Claude)',
  baseUrl: 'https://api.anthropic.com/v1',
  protocol: AiProtocol.anthropic,
  model: 'claude-opus-5-5',
  keyPattern: RegExp(r'^sk-ant-'),
  prefer: const ['claude-opus-5-5', 'claude-fable', 'claude-opus'],
);

final aiProviders = <AiProvider>[
  openRouter,
  anthropic,
  AiProvider(
    id: 'openai',
    name: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    model: 'gpt-5-mini',
    // T3BlbkFJ — «OpenAI» в base64, он есть внутри любого ключа OpenAI
    keyPattern: RegExp(r'^sk-(proj|svcacct|admin)-|^sk-.*T3BlbkFJ'),
    prefer: const ['gpt-5-mini', 'gpt-5-nano', 'gpt-4.1-mini', 'gpt-4o-mini'],
    speech: true,
  ),
  AiProvider(
    id: 'gemini',
    name: 'Google Gemini',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    model: 'gemini-2.5-flash',
    keyPattern: RegExp(r'^AIza'),
    prefer: const ['gemini-2.5-flash', 'flash'],
  ),
  AiProvider(
    id: 'deepseek',
    name: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com/v1',
    model: 'deepseek-chat',
    prefer: const ['deepseek-chat'],
  ),
  AiProvider(
    id: 'xai',
    name: 'xAI (Grok)',
    baseUrl: 'https://api.x.ai/v1',
    model: 'grok-4-fast-non-reasoning',
    keyPattern: RegExp(r'^xai-'),
    prefer: const ['grok-4-fast-non-reasoning', 'grok-4-fast', 'grok-4', 'grok-3-mini'],
  ),
  AiProvider(
    id: 'mistral',
    name: 'Mistral',
    baseUrl: 'https://api.mistral.ai/v1',
    model: 'mistral-small-latest',
    prefer: const ['mistral-small-latest', 'mistral-medium-latest', 'pixtral'],
    speech: true,
  ),
  AiProvider(
    id: 'groq',
    name: 'Groq',
    baseUrl: 'https://api.groq.com/openai/v1',
    model: 'meta-llama/llama-4-scout-17b-16e-instruct',
    keyPattern: RegExp(r'^gsk_'),
    prefer: const ['llama-4-scout', 'llama-4-maverick', 'llama-3.3-70b'],
    speech: true,
  ),
  AiProvider(
    id: 'together',
    name: 'Together AI',
    baseUrl: 'https://api.together.xyz/v1',
    model: 'meta-llama/Llama-4-Scout-17B-16E-Instruct',
    keyPattern: RegExp(r'^tgp_'),
    prefer: const ['Llama-4-Scout', 'Llama-4-Maverick', 'Qwen2.5-VL', 'Llama-3.3-70B'],
  ),
  AiProvider(
    id: 'fireworks',
    name: 'Fireworks AI',
    baseUrl: 'https://api.fireworks.ai/inference/v1',
    model: 'accounts/fireworks/models/llama4-scout-instruct-basic',
    keyPattern: RegExp(r'^fw_'),
    prefer: const ['llama4-scout', 'llama4-maverick', 'qwen2p5-vl'],
  ),
  AiProvider(
    id: 'cerebras',
    name: 'Cerebras',
    baseUrl: 'https://api.cerebras.ai/v1',
    model: 'llama-4-scout-17b-16e-instruct',
    keyPattern: RegExp(r'^csk-'),
    prefer: const ['llama-4-scout', 'llama-3.3-70b', 'llama3.1-8b'],
  ),
  AiProvider(
    id: 'deepinfra',
    name: 'DeepInfra',
    baseUrl: 'https://api.deepinfra.com/v1/openai',
    model: 'meta-llama/Llama-4-Scout-17B-16E-Instruct',
    prefer: const ['Llama-4-Scout', 'Llama-4-Maverick', 'Qwen2.5-VL'],
    speech: true,
  ),
  // NVIDIA убран 25.11.2026 (хозяин: «убери нафиг»): его сервер не отвечает сайту, а список
  // у сайта и телефона один. Выбравший его раньше остаётся на нём как на «своём адресе»
  AiProvider(
    id: 'huggingface',
    name: 'Hugging Face',
    baseUrl: 'https://router.huggingface.co/v1',
    model: 'Qwen/Qwen3-VL-8B-Instruct',
    keyPattern: RegExp(r'^hf_'),
    prefer: const ['Qwen3-VL-8B', 'Qwen3-VL', 'gemma-3'],
    openModels: true,
  ),
  AiProvider(
    id: 'qwen',
    name: 'Qwen (Alibaba)',
    baseUrl: 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1',
    model: 'qwen-vl-plus',
    prefer: const ['qwen-vl-plus', 'qwen-plus', 'qwen-flash'],
  ),
  AiProvider(
    id: 'moonshot',
    name: 'Moonshot (Kimi)',
    baseUrl: 'https://api.moonshot.ai/v1',
    model: 'kimi-latest',
    prefer: const ['kimi-latest', 'moonshot-v1-8k-vision', 'kimi-k2'],
  ),
  AiProvider(
    id: 'zai',
    name: 'Z.ai (GLM)',
    baseUrl: 'https://api.z.ai/api/paas/v4',
    model: 'glm-4.5v',
    prefer: const ['glm-4.5v', 'glm-4.5-air', 'glm-4.5'],
  ),
];

String _clean(String url) => url.trim().replaceFirst(RegExp(r'/+$'), '');

/// Поставщик по адресу API; свой адрес — null.
AiProvider? providerOfUrl(String baseUrl) {
  final url = _clean(baseUrl);
  for (final provider in aiProviders) {
    if (provider.baseUrl == url) return provider;
  }
  // адрес Anthropic, вписанный руками, всё равно говорит на его языке
  if (Uri.tryParse(url)?.host == 'api.anthropic.com') return anthropic;
  return null;
}

/// Чей ключ: поставщик с подходящим началом, иначе null.
AiProvider? providerOfKey(String key) {
  final cleaned = key.trim();
  for (final provider in aiProviders) {
    if (provider.keyPattern?.hasMatch(cleaned) ?? false) return provider;
  }
  return null;
}

/// К кому идти с ключом: узнанный по ключу поставщик, иначе выбранный сейчас.
/// Ключ чужого вида к выбранному поставщику не отправляется, если узнан хозяин ключа.
AiProvider? providerForKey(String key, {required String currentUrl}) => providerOfKey(key) ?? providerOfUrl(currentUrl);

/// Слова в именах моделей, которые не пишут текст: речь, картинки, поиск, отпечатки смысла.
final _notChat = RegExp(r'embed|whisper|transcribe|tts|audio|realtime|image|dall-e|moderation|search|rerank|guard|speech|voxtral|ocr', caseSensitive: false);

/// Модель разбора из живого списка: прежняя, если она там есть, иначе по [AiProvider.prefer],
/// иначе первая, что видит картинки, иначе первая пишущая текст.
String pickSortModel(AiProvider provider, List<({String id, bool seesImages})> models, {String? current}) {
  final ids = {for (final model in models) model.id};
  if (current != null && ids.contains(current)) return current;
  if (ids.contains(provider.model)) return provider.model;
  final chat = [for (final model in models) if (!_notChat.hasMatch(model.id)) model];
  for (final part in provider.prefer) {
    final lower = part.toLowerCase();
    for (final model in chat) {
      if (model.id.toLowerCase().contains(lower)) return model.id;
    }
  }
  for (final model in chat) {
    if (model.seesImages) return model.id;
  }
  return chat.isEmpty ? provider.model : chat.first.id;
}
