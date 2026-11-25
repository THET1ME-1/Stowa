import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/services/web_push_crypto.dart';

List<int> b64(String text) => base64Url.decode(base64Url.normalize(text.replaceAll(' ', '')));

void main() {
  test('шифрование push по RFC 8291: пример из приложения A байт в байт', () async {
    final body = await webPushBody(
      plaintext: utf8.encode('When I grow up, I want to be a watermelon'),
      uaPublic: b64('BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4'),
      authSecret: b64('BTBZMqHH6r4Tts7J_aSIgg'),
      asPublic: b64('BP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A8'),
      sharedSecret: b64('kyrL1jIIOHEzg3sM2ZWRHDRB62YACZhhSlknJ672kSs'),
      salt: b64('DGv6ra1nlYgDCS1FRnbzlw'),
    );
    final header = b64('DGv6ra1nlYgDCS1FRnbzlwAAEABBBP4z 9KsN6nGRTbVYI_c7VJSPQTBtkgcy27ml mlMoZIIgDll6e3vCYLocInmYWAmS6Tlz AC8wEqKK6PBru3jl7A8');
    final cipher = b64('8pfeW0KbunFT06SuDKoJH9Ql87S1QUrd irN6GcG7sFz1y1sqLgVi1VhjVkHsUoEs bI_0LpXMuGvnzQ');
    expect(body, [...header, ...cipher]);
  });

  test('уведомление для push: длинный текст режется, кнопки парами', () {
    final notice = jsonDecode(utf8.decode(webPushNotice(title: 'Позвонить маме', body: 'а' * 1000, tag: 'reminder-7', payload: 'id-1', actions: const [('done', 'Готово')]))) as Map;
    expect((notice['body'] as String).length, 400);
    expect(notice['actions'], [
      ['done', 'Готово'],
    ]);
    expect(notice['requireInteraction'], isTrue);
  });
}
