import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/privacy/privacy_service.dart';
import '../settings/settings_blocks.dart';
import 'privacy_flows.dart';

/// Есть ли на телефоне датчик с заведённым пальцем.
final fingerprintSensorProvider = FutureProvider<bool>((ref) => ref.watch(biometricsProvider).available());

String closeAfterLabel(L l, Duration delay) => switch (delay.inMinutes) {
  0 => l.closeAfterNow,
  1 => l.closeAfterMinute,
  final minutes => l.closeAfterMinutes(minutes),
};

/// «Приватность» в настройках: код, замок на вход, отпечаток, когда закрывать, скрытые папки.
class PrivacySettings extends ConsumerWidget {
  const PrivacySettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final lock = ref.watch(privacyLockProvider).value;
    final open = ref.watch(hiddenOpenProvider).value ?? false;
    final fingerprint = ref.watch(fingerprintOnProvider).value ?? false;
    final sensor = ref.watch(fingerprintSensorProvider).value ?? false;
    final privacy = ref.read(privacyServiceProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(l.privacySection),
        SettingsGroup(
          tint: settingsTint('violet'),
          children: [
            if (lock == null)
              SettingsRow(icon: 'password', title: l.codeCreateRow, onTap: () => createCodeFlow(context, ref))
            else ...[
              SettingsSwitchRow(icon: 'lock', title: l.appLockRow, value: lock.appLock, onChanged: privacy.setAppLock),
              if (sensor)
                SettingsSwitchRow(
                  icon: 'fingerprint',
                  title: l.fingerprintRow,
                  value: fingerprint,
                  onChanged: (on) async {
                    if (!on) return privacy.forgetFingerprint();
                    // ключ для пальца даёт код: открытое скрытое его уже знает
                    if (await privacy.rememberForFingerprint()) return;
                    if (!context.mounted) return;
                    final keys = await askCodeFlow(context, ref, title: l.codeEnterTitle);
                    if (keys != null) await privacy.rememberForFingerprint(keys);
                  },
                ),
              SettingsRow(
                icon: 'timer',
                title: l.closeAfterRow,
                value: closeAfterLabel(l, lock.closeAfter),
                onTap: () => _pickDelay(context, ref, lock.closeAfter),
              ),
              SettingsRow(
                icon: open ? 'lock' : 'lock_open',
                title: open ? l.hiddenCloseRow : l.hiddenOpenRow,
                onTap: () => open ? privacy.close() : openHiddenFlow(context, ref),
              ),
              SettingsRow(icon: 'password', title: l.codeChangeRow, onTap: () => changeCodeFlow(context, ref)),
            ],
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(l.privacyHint, style: text.bodySmall!.copyWith(color: Tokens.muted, height: 1.4)),
        ),
      ],
    );
  }

  Future<void> _pickDelay(BuildContext context, WidgetRef ref, Duration current) async {
    final l = L.of(context);
    final picked = await showModalBottomSheet<Duration>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final delay in lockDelays) _Choice(title: closeAfterLabel(l, delay), selected: delay == current, onTap: () => Navigator.pop(sheet, delay)),
            ],
          ),
        ),
      ),
    );
    if (picked != null) await ref.read(privacyServiceProvider).setCloseAfter(picked);
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.title, required this.selected, required this.onTap});

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.short,
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(color: selected ? Tokens.accent : Tokens.containerHigh, borderRadius: BorderRadius.circular(Radii.tile)),
          child: Row(
            children: [
              Expanded(
                child: Text(title, style: text.bodyLarge!.copyWith(color: selected ? Tokens.onAccent : Tokens.onSurface)),
              ),
              if (selected) Icon(symbolIcon('check'), color: Tokens.onAccent),
            ],
          ),
        ),
      ),
    );
  }
}
