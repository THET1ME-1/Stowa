import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

// тёмная карта: светлую OSM выворачиваем и поворачиваем оттенок, как darkModeTileBuilder
const _night = ColorFilter.matrix([
  0.5740000009536743, -1.4299999475479126, -0.14399999380111694, 0, 255, //
  -0.4259999990463257, -0.429999977350235, -0.14399999380111694, 0, 255, //
  -0.4259999990463257, -1.4299999475479126, 0.8559999465942383, 0, 255, //
  0, 0, 0, 1, 0, //
]);

// и приглушаем под графит приложения: метки заметок важнее улиц
const _calm = ColorFilter.matrix([
  0.567, 0.393, 0.040, 0, 0, //
  0.117, 0.843, 0.040, 0, 0, //
  0.117, 0.393, 0.490, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// Плитки OpenStreetMap в цветах приложения. Перекраска — на весь слой разом: на каждой
/// плитке она давала два слоя на плитку, 40–60 на кадр прокрутки, и карта шла в 10 кадров.
/// Фильтры двумя слоями, а не одной матрицей: между ними яркие цвета обрезаются, и сумма
/// матриц красила бы парки и песок иначе.
class NightTiles extends StatelessWidget {
  const NightTiles({super.key});

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: _calm,
      child: ColorFiltered(
        colorFilter: _night,
        child: TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'app.stowa'),
      ),
    );
  }
}
