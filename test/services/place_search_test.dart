import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/services/place_search.dart';

void main() {
  test('ответ Photon: название, улица с домом и город под ним, точка', () {
    final found = placesFromPhoton({
      'features': [
        {
          'geometry': {'coordinates': [28.8244644, 47.0188945]},
          'properties': {'name': 'Universitatea de Stat', 'street': 'Strada Alexei Mateevici', 'housenumber': '60', 'city': 'Chișinău'},
        },
        // без названия: адрес — сам заголовок, город под ним
        {
          'geometry': {'coordinates': [28.83, 47.02]},
          'properties': {'street': 'Strada Alexandru Pușkin', 'housenumber': '52', 'city': 'Chișinău'},
        },
        // город целиком: под ним ничего
        {
          'geometry': {'coordinates': [28.86, 47.0]},
          'properties': {'name': 'Chișinău', 'city': 'Chișinău'},
        },
        // битая запись пропускается
        {'geometry': {'coordinates': []}, 'properties': {'name': 'Пусто'}},
      ],
    });
    expect([for (final place in found) (place.name, place.address)], [
      ('Universitatea de Stat', 'Strada Alexei Mateevici 60, Chișinău'),
      ('Strada Alexandru Pușkin 52', 'Chișinău'),
      ('Chișinău', null),
    ]);
    expect((found.first.latitude, found.first.longitude), (47.0188945, 28.8244644));
  });

  test('чужой ответ без features — пусто', () {
    expect(placesFromPhoton({'message': 'rate limited'}), isEmpty);
  });
}
