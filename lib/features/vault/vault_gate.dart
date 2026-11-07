import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/settings_repository.dart';
import '../home/home_screen.dart';
import '../item/item_screen.dart';
import 'vault_setup_screen.dart';

/// Первый экран приложения: хранилище пропало — «не найдено», место ещё не выбрано —
/// выбор как у Obsidian, иначе главная.
class VaultGate extends ConsumerStatefulWidget {
  const VaultGate({super.key});

  @override
  ConsumerState<VaultGate> createState() => _VaultGateState();
}

enum _Stage { missing, setup, home }

class _VaultGateState extends ConsumerState<VaultGate> {
  late _Stage _stage = ref.read(vaultMissingProvider)
      ? _Stage.missing
      : ref.read(vaultAskedProvider)
      ? _Stage.home
      : _Stage.setup;

  @override
  void initState() {
    super.initState();
    // заметка при запуске — только когда приложение сразу открылось на главной
    if (_stage == _Stage.home) WidgetsBinding.instance.addPostFrameCallback((_) => _openStartNote());
  }

  /// Последняя или случайная заметка поверх главной: «назад» ведёт на главную.
  Future<void> _openStartNote() async {
    final items = ref.read(itemsRepositoryProvider);
    final id = switch (ref.read(startScreenProvider)) {
      StartScreen.home => null,
      StartScreen.last => await items.lastOpenedId(),
      StartScreen.random => await items.randomId(),
    };
    if (id == null || !mounted) return;
    Navigator.of(context).push(itemRoute(id));
  }

  void _home() => setState(() => _stage = _Stage.home);

  @override
  Widget build(BuildContext context) => switch (_stage) {
    _Stage.missing => VaultMissingScreen(onFixed: _home),
    _Stage.setup => VaultSetupScreen(onDone: _home),
    _Stage.home => const HomeScreen(),
  };
}
