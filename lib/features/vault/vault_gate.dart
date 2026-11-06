import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../home/home_screen.dart';
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

  void _home() => setState(() => _stage = _Stage.home);

  @override
  Widget build(BuildContext context) => switch (_stage) {
    _Stage.missing => VaultMissingScreen(onFixed: _home),
    _Stage.setup => VaultSetupScreen(onDone: _home),
    _Stage.home => const HomeScreen(),
  };
}
