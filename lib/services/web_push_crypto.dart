import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Тело push-сообщения по RFC 8291 (`aes128gcm`). Шифрует сама страница ключами своей
/// подписки, поэтому сервер Stowa хранит и пересылает его как есть, а текста напоминания не
/// видит. Обмен ключами — снаружи (в браузере его делает WebCrypto): [sharedSecret] —
/// ECDH(одноразовый ключ, [uaPublic]), [asPublic] — открытая часть одноразового ключа,
/// 65 байт без сжатия. [uaPublic] и [authSecret] — ключи подписки браузера, [salt] — 16
/// случайных байт на каждое сообщение.
Future<Uint8List> webPushBody({
  required List<int> plaintext,
  required List<int> uaPublic,
  required List<int> authSecret,
  required List<int> asPublic,
  required List<int> sharedSecret,
  required List<int> salt,
  int recordSize = 4096,
}) async {
  final hmac = Hmac.sha256();
  // ключ подписки и обмен ключами вместе: IKM = HKDF(auth_secret, ecdh_secret, key_info)
  final keyInfo = [...utf8.encode('WebPush: info'), 0, ...uaPublic, ...asPublic];
  final ikm = await (await Hkdf(hmac: hmac, outputLength: 32).deriveKey(secretKey: SecretKey(sharedSecret), nonce: authSecret, info: keyInfo)).extractBytes();
  final cek = await Hkdf(hmac: hmac, outputLength: 16).deriveKey(secretKey: SecretKey(ikm), nonce: salt, info: [...utf8.encode('Content-Encoding: aes128gcm'), 0]);
  final nonce = await (await Hkdf(hmac: hmac, outputLength: 12).deriveKey(secretKey: SecretKey(ikm), nonce: salt, info: [...utf8.encode('Content-Encoding: nonce'), 0])).extractBytes();
  // одна запись, последняя: после текста байт-разделитель 2
  final box = await AesGcm.with128bits().encrypt([...plaintext, 2], secretKey: cek, nonce: nonce);
  final size = ByteData(4)..setUint32(0, recordSize);
  return (BytesBuilder()
        ..add(salt)
        ..add(size.buffer.asUint8List())
        ..addByte(asPublic.length)
        ..add(asPublic)
        ..add(box.cipherText)
        ..add(box.mac.bytes))
      .toBytes();
}

/// Что покажет service worker, когда push придёт при закрытой вкладке: те же поля, что у
/// уведомления от самой вкладки. Текст режется, чтобы сообщение влезло в 4 КБ push-службы.
List<int> webPushNotice({required String title, required String body, required String tag, required String payload, required List<(String, String)> actions}) => utf8.encode(
  jsonEncode({
    'title': _cut(title, 200),
    'body': _cut(body, 400),
    'tag': tag,
    'payload': payload,
    'requireInteraction': true,
    'actions': [
      for (final (action, label) in actions) [action, label],
    ],
  }),
);

String _cut(String text, int most) => text.length <= most ? text : '${text.substring(0, most - 1)}…';
