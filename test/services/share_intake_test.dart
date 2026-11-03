import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/services/share_intake.dart';

void main() {
  test('текст и ссылка из TikTok — одна вещь с текстом', () {
    final shared = sharedToCapture(const [
      SharedPiece(value: 'Паста с креветками за 15 минут', kind: SharedKind.text),
      SharedPiece(value: 'https://vt.tiktok.com/ZSpasta15/', kind: SharedKind.url),
    ]);
    expect(shared.text, 'Паста с креветками за 15 минут\nhttps://vt.tiktok.com/ZSpasta15/');
    expect(shared.files, isEmpty);
  });

  test('фото, видео и файлы идут вложениями, тип по расширению или от системы', () {
    final shared = sharedToCapture(const [
      SharedPiece(value: '/cache/IMG_1.jpg', kind: SharedKind.image),
      SharedPiece(value: '/cache/clip', kind: SharedKind.video, mime: 'video/mp4'),
      SharedPiece(value: '/cache/scan.pdf', kind: SharedKind.file),
    ]);
    expect(shared.text, isEmpty);
    expect(shared.files.map((file) => file.mime), ['image/jpeg', 'video/mp4', 'application/pdf']);
  });

  test('пустое и пробелы не сохраняются', () {
    expect(sharedToCapture(const [SharedPiece(value: '   ', kind: SharedKind.text)]).isEmpty, isTrue);
  });
}
