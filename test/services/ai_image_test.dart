import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/services/ai_image.dart';

void main() {
  test('фото 4000×3000 уходит модели 1024×768', () {
    expect(aiImageSize(4000, 3000), (1024, 768));
  });

  test('портрет ужимается по высоте', () {
    expect(aiImageSize(3000, 4000), (768, 1024));
  });

  test('маленькая картинка не растягивается', () {
    expect(aiImageSize(640, 480), (640, 480));
  });

  test('размер неизвестен — ограничение по длинной стороне без пропорций', () {
    expect(aiImageSize(null, null), (1024, 1024));
  });
}
