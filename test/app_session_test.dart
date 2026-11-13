import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/app_session.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/services/vault/vault_location.dart';

void main() {
  VaultSession session(AppDatabase db) => VaultSession(db: db, place: VaultPlace(files: Directory.systemTemp, vault: null, reachable: true), lock: null);

  testWidgets('другое хранилище: приложение строится заново на его базе, старая база закрывается', (tester) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final first = _TrackedDatabase();
    final second = AppDatabase.memory();
    addTearDown(second.close);
    late ReopenSession reopen;
    final built = <AppDatabase>[];
    final states = <int>{};

    await tester.pumpWidget(
      SessionHost(
        first: session(first),
        open: (prepared) async => session(prepared!),
        app: (current, again) {
          reopen = again;
          built.add(current.db);
          return Directionality(textDirection: TextDirection.ltr, child: _Probe(onState: states.add));
        },
      ),
    );
    expect(built.last, same(first));

    await tester.runAsync(() async {
      final done = reopen(second);
      await tester.pump();
      await tester.pump();
      await done;
    });
    await tester.pump();
    expect(built.last, same(second));
    // состояние нового приложения своё: прежние экраны не переезжают
    expect(states, hasLength(2));
    expect(first.closed, isTrue);
  });
}

class _Probe extends StatefulWidget {
  const _Probe({required this.onState});

  final ValueChanged<int> onState;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.onState(identityHashCode(this));
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _TrackedDatabase extends AppDatabase {
  _TrackedDatabase() : super(NativeDatabase.memory());

  bool closed = false;

  @override
  Future<void> close() {
    closed = true;
    return super.close();
  }
}
