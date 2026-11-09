import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/db/database.dart';
import '../../domain/models.dart';
import '../../domain/qr.dart';
import '../../l10n/app_localizations.dart';

/// Что нашлось в тексте вещи: касанием позвонить, написать, открыть, скопировать сумму.
class FactsChips extends StatelessWidget {
  const FactsChips({super.key, required this.facts, required this.onLink});

  final List<Fact> facts;
  final Future<void> Function(String url) onLink;

  // порядок кнопок: то, ради чего заметку открывают у роутера или на кассе, — первым
  static const _order = [
    FactKind.qr,
    FactKind.password,
    FactKind.loyaltyCard,
    FactKind.promoCode,
    FactKind.tracking,
    FactKind.phone,
    FactKind.email,
    FactKind.address,
    FactKind.price,
    FactKind.link,
  ];

  // адрес — только найденный в тексте: адрес страницы показывает её карточка
  static bool _shows(Fact fact) => _order.contains(fact.kind) && (fact.kind != FactKind.address || fact.detail == 'text');

  /// Есть ли что показать: без этого блок не занимает места.
  static bool hasAny(List<Fact> facts) => facts.any(_shows);

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ordered = [
      for (final kind in _order)
        for (final fact in facts)
          if (fact.kind == kind && _shows(fact)) fact,
    ];
    Future<void> open(Uri uri) async {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
      if (!opened) showNote(messenger, l.linkOpenFailed, overDock: true);
    }

    Future<void> copy(String text, String note) async {
      await Clipboard.setData(ClipboardData(text: text));
      showNote(messenger, note, overDock: true);
    }

    // QR с фото: Wi-Fi — имя сети, касание копирует пароль; ссылка открывается; текст копируется
    Widget qrChip(Fact fact) {
      final code = parseQr(fact.value);
      return switch (code.kind) {
        QrKind.wifi => _FactChip(icon: 'wifi', label: l.qrWifi(code.network!), tooltip: l.qrCopyPassword, onTap: () => copy(code.password ?? '', l.qrPasswordCopied)),
        QrKind.url => _FactChip(icon: 'qr_code_2', label: _shortLink(code.text), tooltip: l.qrOpenLink, onTap: () => onLink(code.text)),
        QrKind.text => _FactChip(icon: 'qr_code_2', label: code.text, tooltip: l.qrCopyText, onTap: () => copy(code.text, l.itemCopied)),
      };
    }

    // из текста: пароль и карта копируются, не показывая себя; трек — у 17track, адрес — в картах
    Widget? textChip(Fact fact) => switch (fact.kind) {
      FactKind.password => _FactChip(
        icon: fact.detail == null ? 'key' : 'wifi',
        label: fact.detail == null ? l.factPassword : l.factPasswordFor(fact.detail!),
        tooltip: l.factCopyPassword,
        onTap: () => copy(fact.value, l.qrPasswordCopied),
      ),
      FactKind.loyaltyCard => _FactChip(
        icon: 'loyalty',
        label: l.factCard(fact.value.substring(fact.value.length - 4)),
        tooltip: l.factCopyCard,
        onTap: () => copy(fact.value, l.itemCopied),
      ),
      FactKind.promoCode => _FactChip(icon: 'sell', label: l.factPromo(fact.value), tooltip: l.factCopyPromo, onTap: () => copy(fact.value, l.itemCopied)),
      FactKind.tracking => _FactChip(
        icon: 'local_shipping',
        label: fact.value,
        tooltip: l.factTrack,
        onTap: () => open(Uri.parse('https://t.17track.net/${_trackLanguage(l.localeName)}#nums=${fact.value}')),
      ),
      FactKind.address => _FactChip(
        icon: 'map',
        label: fact.value,
        tooltip: l.factOnMap,
        onTap: () => open(Uri.parse('geo:0,0?q=${Uri.encodeComponent(fact.value)}')),
      ),
      _ => null,
    };

    return Wrap(
      key: const ValueKey('item-facts'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final fact in ordered)
          if (fact.kind == FactKind.qr)
            qrChip(fact)
          else if (textChip(fact) case final chip?)
            chip
          else
            _FactChip(
              icon: switch (fact.kind) {
                FactKind.phone => 'call',
                FactKind.email => 'mail',
                FactKind.price => 'payments',
                _ => 'link',
              },
              label: fact.kind == FactKind.link ? _shortLink(fact.value) : fact.value,
              tooltip: switch (fact.kind) {
                FactKind.phone => l.factCall,
                FactKind.email => l.factWrite,
                FactKind.price => l.factCopy,
                _ => l.itemOpenLink,
              },
              onTap: switch (fact.kind) {
                FactKind.phone => () => open(Uri(scheme: 'tel', path: fact.detail ?? fact.value)),
                FactKind.email => () => open(Uri(scheme: 'mailto', path: fact.value)),
                FactKind.price => () async {
                  await Clipboard.setData(ClipboardData(text: fact.value));
                  showNote(messenger, l.itemCopied, overDock: true);
                },
                _ => () => onLink(fact.value),
              },
            ),
      ],
    );
  }

  // 17track говорит на этих языках; остальным — по-английски
  String _trackLanguage(String locale) => const {'ru', 'de', 'es', 'pl', 'uk'}.contains(locale) ? locale : 'en';

  // адрес без схемы и «www.», длинный — с многоточием в конце
  String _shortLink(String url) {
    final bare = url.replaceFirst(RegExp(r'^https?://(www\.)?'), '');
    return bare.length > 32 ? '${bare.substring(0, 31)}…' : bare;
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.label, required this.tooltip, required this.onTap});

  final String icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Tokens.containerHigh,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(symbolIcon(icon), size: 18, color: Tokens.onSurface),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Tokens.onSurface),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «Снято 3 мая 2024 · Google Pixel 8» — из EXIF фото. Нечего сказать — null.
String? photoTakenLine(L l, List<Fact> facts, DateTime now) {
  final taken = facts.where((fact) => fact.kind == FactKind.takenAt).map((fact) => fact.at).nonNulls.firstOrNull;
  final camera = facts.where((fact) => fact.kind == FactKind.camera).map((fact) => fact.value).firstOrNull;
  if (taken == null && camera == null) return null;
  final day = taken == null ? null : (taken.year == now.year ? DateFormat.MMMMd(l.localeName) : DateFormat.yMMMMd(l.localeName)).format(taken);
  return [if (day != null) l.photoTaken(day), ?camera].join(' · ');
}
