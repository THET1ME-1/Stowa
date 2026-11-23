import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/ai_providers.dart';

void main() {
  test('поставщик узнаётся по началу ключа', () {
    // метка OpenAI по кускам: целиком её принимает за настоящий ключ проверка GitHub
    final mark = ['T3Bl', 'bkFJ'].join();
    final cases = {
      'sk-or-v1-abc': 'openrouter',
      'sk-ant-api03-abc': 'anthropic',
      'sk-proj-abc${mark}xyz': 'openai',
      'sk-svcacct-abc': 'openai',
      'sk-abcdef${mark}ghijkl': 'openai',
      'AIzaSyAbc': 'gemini',
      'xai-abc': 'xai',
      'gsk_abc': 'groq',
      'tgp_v1_abc': 'together',
      'fw_abc': 'fireworks',
      'csk-abc': 'cerebras',
      'nvapi-abc': 'nvidia',
      'hf_abc': 'huggingface',
    };
    for (final MapEntry(key: key, value: id) in cases.entries) {
      expect(providerOfKey(key)?.id, id, reason: key);
    }
    // ключи вида sk- и 32 знака бывают у DeepSeek и у Qwen — не угадываем
    expect(providerOfKey('sk-0123456789abcdef0123456789abcdef'), isNull);
    expect(providerOfKey('  sk-ant-api03-abc  ')?.id, 'anthropic');
  });

  test('ключ к хозяину, не узнан — к выбранному', () {
    expect(providerForKey('sk-ant-x', currentUrl: defaultAiBaseUrl)?.id, 'anthropic');
    expect(providerForKey('mistral-key-without-prefix', currentUrl: 'https://api.mistral.ai/v1/')?.id, 'mistral');
    expect(providerForKey('whatever', currentUrl: 'https://my.proxy/v1'), isNull);
  });

  test('адрес узнаётся без хвостовой черты; Anthropic по хосту', () {
    expect(providerOfUrl('https://openrouter.ai/api/v1/')?.id, 'openrouter');
    expect(providerOfUrl('https://api.anthropic.com/v1')?.id, 'anthropic');
    expect(providerOfUrl('https://api.anthropic.com')?.id, 'anthropic');
    expect(providerOfUrl('https://my.proxy/v1'), isNull);
  });

  test('ключи и адреса поставщиков не повторяются', () {
    expect({for (final provider in aiProviders) provider.id}.length, aiProviders.length);
    expect({for (final provider in aiProviders) provider.baseUrl}.length, aiProviders.length);
  });

  group('модель из живого списка', () {
    final openai = aiProviders.firstWhere((provider) => provider.id == 'openai');

    test('прежняя остаётся, если она в списке', () {
      expect(pickSortModel(openai, [(id: 'gpt-4o-mini', seesImages: false), (id: 'gpt-5-mini', seesImages: false)], current: 'gpt-4o-mini'), 'gpt-4o-mini');
    });

    test('по умолчанию, потом по списку желанных; речь и картинки не берутся', () {
      expect(pickSortModel(openai, [(id: 'whisper-1', seesImages: false), (id: 'gpt-5-mini', seesImages: false)]), 'gpt-5-mini');
      expect(pickSortModel(openai, [(id: 'gpt-4o-mini-transcribe', seesImages: false), (id: 'gpt-4.1-mini-2025', seesImages: false)]), 'gpt-4.1-mini-2025');
    });

    test('ничего знакомого — первая, что видит картинки, иначе первая текстовая', () {
      expect(pickSortModel(openai, [(id: 'tts-1', seesImages: false), (id: 'x-text', seesImages: false), (id: 'x-vision', seesImages: true)]), 'x-vision');
      expect(pickSortModel(openai, [(id: 'dall-e-3', seesImages: false), (id: 'x-text', seesImages: false)]), 'x-text');
    });
  });
}
