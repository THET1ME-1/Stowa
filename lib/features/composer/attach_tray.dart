import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';

/// Миниатюры галереи живут, пока открыто приложение: повторно лоток открывается мгновенно.
final _thumbs = <String, Uint8List?>{};

Future<Uint8List?> galleryThumb(AssetEntity asset) async {
  if (_thumbs.containsKey(asset.id)) return _thumbs[asset.id];
  final data = await asset.thumbnailDataWithSize(const ThumbnailSize.square(240));
  return _thumbs[asset.id] = data;
}

/// Вложения прямо над строкой: вкладки, выбранная раскрывается в пилюлю с подписью,
/// снизу сетка последних фото и видео.
class AttachTray extends StatefulWidget {
  const AttachTray({
    super.key,
    required this.selected,
    required this.onToggle,
    required this.onCamera,
    required this.onVideo,
    required this.onFiles,
    required this.onLink,
  });

  /// Id выбранных из галереи по порядку: номер на плитке.
  final List<String> selected;
  final void Function(AssetEntity asset, Uint8List? thumb) onToggle;
  final VoidCallback onCamera;
  final VoidCallback onVideo;
  final VoidCallback onFiles;
  final VoidCallback onLink;

  @override
  State<AttachTray> createState() => _AttachTrayState();
}

class _AttachTrayState extends State<AttachTray> {
  int _tab = 0;
  PermissionState? _permission;
  List<AssetEntity> _assets = const [];

  @override
  void initState() {
    super.initState();
    _load(request: true);
  }

  Future<void> _load({required bool request}) async {
    try {
      final permission = request ? await PhotoManager.requestPermissionExtend() : await PhotoManager.getPermissionState(requestOption: const PermissionRequestOption());
      var assets = const <AssetEntity>[];
      if (permission.hasAccess) {
        assets = await PhotoManager.getAssetListRange(
          start: 0,
          end: 120,
          filterOption: FilterOptionGroup(orders: const [OrderOption()]),
        );
      }
      if (mounted) {
        setState(() {
          _permission = permission;
          _assets = assets;
        });
      }
    } catch (_) {
      // нет плагина (тесты) или система отказала — лоток покажет просьбу о доступе
      if (mounted) setState(() => _permission = PermissionState.denied);
    }
  }

  void _pickTab(int index, VoidCallback? action) {
    setState(() => _tab = index);
    if (action == null) return;
    action();
    // вкладка-действие открыла системное окно, лоток возвращается к галерее
    Future.delayed(Motion.long, () {
      if (mounted) setState(() => _tab = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tabs = [
      ('photo_library', l.trayGallery, null),
      ('photo_camera', l.trayCamera, widget.onCamera),
      ('videocam', l.trayVideo, widget.onVideo),
      ('attach_file', l.trayFile, widget.onFiles),
      ('link', l.trayLink, widget.onLink),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 2),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            for (final (index, (icon, label, action)) in tabs.indexed)
              _Tab(icon: icon, label: label, on: _tab == index, onTap: () => _pickTab(index, action)),
          ]),
        ),
        Flexible(child: _grid(l)),
      ]),
    );
  }

  Widget _grid(L l) {
    final text = Theme.of(context).textTheme;
    final permission = _permission;
    if (permission == null) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: Tokens.onSurfaceVariant)));
    if (!permission.hasAccess || _assets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            permission.hasAccess ? l.trayEmpty : l.trayAccess,
            textAlign: TextAlign.center,
            style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant),
          ),
          if (!permission.hasAccess) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                await PhotoManager.openSetting();
                await _load(request: true);
              },
              child: Text(l.trayAllow),
            ),
          ],
        ]),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 340),
      child: GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 4, crossAxisSpacing: 4),
        itemCount: _assets.length,
        itemBuilder: (context, index) {
          final asset = _assets[index];
          final number = widget.selected.indexOf(asset.id);
          return _GalleryTile(asset: asset, number: number < 0 ? null : number + 1, onTap: (thumb) => widget.onToggle(asset, thumb));
        },
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.icon, required this.label, required this.on, required this.onTap});

  final String icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = on ? Tokens.onAccent : Tokens.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: Motion.long,
            curve: Motion.spatial,
            height: 44,
            constraints: const BoxConstraints(minWidth: 44),
            padding: EdgeInsets.fromLTRB(on ? 12 : 10, 0, on ? 16 : 10, 0),
            decoration: BoxDecoration(color: on ? Tokens.accent : Colors.transparent, borderRadius: BorderRadius.circular(22)),
            child: AnimatedSize(
              duration: Motion.long,
              curve: Motion.spatial,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(symbolIcon(icon), color: color),
                if (on) ...[
                  const SizedBox(width: 6),
                  Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryTile extends StatefulWidget {
  const _GalleryTile({required this.asset, required this.number, required this.onTap});

  final AssetEntity asset;
  final int? number;
  final ValueChanged<Uint8List?> onTap;

  @override
  State<_GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends State<_GalleryTile> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    galleryThumb(widget.asset).then((data) {
      if (mounted) setState(() => _thumb = data);
    });
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.number != null;
    final asset = widget.asset;
    final video = asset.type == AssetType.video;
    return GestureDetector(
      onTap: () => widget.onTap(_thumb),
      child: AnimatedScale(
        scale: on ? 0.86 : 1,
        duration: Motion.medium,
        curve: Motion.spatial,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.spatial,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: Tokens.containerHighest, borderRadius: BorderRadius.circular(on ? 24 : 14)),
          child: Stack(fit: StackFit.expand, children: [
            if (_thumb != null) Image.memory(_thumb!, fit: BoxFit.cover, gaplessPlayback: true),
            if (video)
              Positioned(
                left: 6,
                bottom: 6,
                child: Text(
                  _duration(asset.videoDuration),
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(color: Colors.white, fontWeight: FontWeight.w700, shadows: const []),
                ),
              ),
            Positioned(
              right: 6,
              top: 6,
              child: AnimatedContainer(
                duration: Motion.short,
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? Tokens.accent : Colors.transparent,
                  border: Border.all(color: Tokens.accent, width: 2),
                ),
                child: on
                    ? Text('${widget.number}', style: Theme.of(context).textTheme.labelSmall!.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: Tokens.onAccent))
                    : null,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  String _duration(Duration duration) => '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
}
