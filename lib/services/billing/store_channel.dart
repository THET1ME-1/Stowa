/// Чем платят в этой сборке.
enum StoreChannel {
  /// APK с GitHub, сайт, компьютер: внешняя касса.
  direct,

  /// Google Play: оплата Google.
  play,

  /// App Store: оплата Apple.
  appstore,
}

/// Касса по метке сборки `--dart-define=STOWA_STORE`. Неизвестная метка — внешняя касса.
StoreChannel storeChannelFrom(String define) => switch (define.trim().toLowerCase()) {
  'play' => StoreChannel.play,
  'appstore' => StoreChannel.appstore,
  _ => StoreChannel.direct,
};

/// Касса этой сборки.
const buildStoreChannel = String.fromEnvironment('STOWA_STORE');
