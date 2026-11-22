# Подписка Stowa Sync в приложении — план

> Исполняется в этой же сессии (`superpowers:executing-plans`), без агентов. Шаги — галочки `- [ ]`.

**Цель:** в каждой сборке своя касса, экран покупки, «Купить подписку» первым пунктом настроек, «Войти» отдельным пунктом; Stowa Sync и боковая панель работают только с подпиской.

**Устройство:** подписку знает `SubscriptionService` — снимок состояния аккаунта с сервера, сохранённый у себя (настройки, синхронизация и панель знают его с первого кадра и без сети). Оплату ведёт `Checkout`: внешняя касса (`LavaCheckout`) или магазин (`StoreCheckout` поверх `in_app_purchase`); какая — решает `--dart-define=STOWA_STORE`. Вход — тот же код на почту, форма вынесена из экрана Stowa Sync и работает без хранилища и без подписки.

**Стек:** Flutter, Riverpod, `in_app_purchase` 3.3 (Android — базовые планы `stowa_sub` по `offerToken`, iOS — StoreKit 2), `url_launcher`.

**Описание:** `docs/specs/2026-11-22-stowa-sync-subscription-design.md`.

## Общие условия

- Сборки: без `STOWA_STORE` — внешняя касса (APK с GitHub, сайт, компьютер); `play`; `appstore`. В сборках магазинов нет ни кнопки, ни ссылки, ни строки про внешнюю кассу — и ни одна строка `.arb` не называет её по имени: словари едут во все сборки.
- Тарифы: месяц, 3 месяца, год. Внешняя касса: цены с сервера (`GET /v1/billing/plans`), валюта по стране устройства (RU, BY, KZ, KG, AM, UZ, TJ, AZ — рубли; страны евро — евро; остальные — доллары), можно сменить. Магазины: цены магазина.
- Номер покупателя (`buyer_id` из `/v1/account`) уходит магазину как `applicationUserName`.
- Покупка магазина закрывается на телефоне (`completePurchase`) только после ответа сервера; 409 (чек другого аккаунта) — тоже закрывается, человек видит, что покупка на другом аккаунте.
- Строки — во всех 7 словарях (`ru`, `en`, `uk`, `de`, `es`, `pl`, `ro`). Код — Read+Edit, как везде в проекте.
- Тесты: `TMPDIR=~/.cache/flutter-tmp systemd-run --user --scope -q -p CPUQuota=500% -p MemoryMax=5G -p MemorySwapMax=0 nice -n 19 flutter test -j 3 <файлы>`.

## На что смотреть при проверке

1. Оплатил на сайте, вернулся во вкладку Stowa — подписка видна без перезагрузки — тест `внешняя касса: вернулся — подписка включилась` (задача 3).
2. Нет сети при запуске, подписка куплена — Stowa Sync и панель открыты по сохранённому сроку — тест `снимок подписки читается без сети` (задача 1).
3. Срок сохранённого снимка прошёл — замок, даже без сети — тест `истёкший снимок не открывает` (задача 1).
4. Сборка Play — на экране покупки нет внешней кассы и есть «Восстановить покупку» — тест `сборка магазина: только магазин` (задача 3).
5. Вошёл без хранилища (сайт до выбора, телефон без папки) — вход проходит — тест `вход без хранилища` (задача 2).

---

### Задача 1: подписка в приложении

**Файлы:**
- Создать: `lib/services/billing/store_channel.dart`, `lib/services/billing/subscription.dart`, `lib/services/billing/billing_api.dart`, `lib/services/billing/subscription_service.dart`, `test/services/billing/subscription_service_test.dart`
- Изменить: `lib/services/sync/sync_service.dart` (`activate`, `deactivate`, `accountToken`), `lib/data/providers.dart`, `test/helpers/test_app.dart`

**Даёт:**
- `enum StoreChannel {direct, play, appstore}`; `StoreChannel storeChannelFrom(String define)`; `storeChannelProvider` (из `String.fromEnvironment('STOWA_STORE')`, тесты подменяют).
- `enum SubPlan {month, quarter, year}`; `enum SubSource {grant, lava, play, apple}`; `class Subscription {bool signedIn; String? email; bool active; DateTime? paidUntil; SubSource? source; SubPlan? plan; bool autoRenew; bool cancellable; bool test; String? buyerId; bool get activeNow; Map toJson(); static Subscription fromJson(Map)}`; `static const Subscription.none`. `activeNow` — `active` и `paidUntil` позже сейчас.
- `class BillingApi {BillingApi(http.Client client, {String base = syncServer}); Future<Map<String, Map<SubPlan, num>>?> lavaPrices(); Future<Subscription> account(String token) /* бросает SyncHttpError */; Future<({String url, String invoice})> lavaCheckout(String token, SubPlan plan, String currency, String lang); Future<DateTime?> lavaCancel(String token); Future<StoreVerdict> verifyPlay(String token, String purchaseToken); Future<StoreVerdict> verifyApple(String token, String transactionId); Future<bool> deleteAccount(String token) /* false — 409 */;}`; `sealed class StoreVerdict` — `StoreOk(bool active, DateTime? until)`, `StoreOwned()`, `StoreInvalid()`, `StoreUnavailable()`.
- `class SubscriptionService {SubscriptionService({required SyncService sync, required KeyStore store, required BillingApi api}); final ValueNotifier<Subscription> state; Future<void> load(); Future<Subscription> refresh(); Future<void> signedOut();}` — `refresh` берёт токен у `SyncService`, пишет снимок, включает и гасит синхронизацию (`sync.activate()` / `sync.deactivate()`); сеть упала — снимок прежний.
- `SyncService.activate()` — снимает `inactive`, запускает проход и ожидание правок; `deactivate()` — ставит `inactive`, гасит ожидание; `Future<String?> token()`.
- Провайдеры: `billingApiProvider`, `subscriptionStoreProvider` (`SecureKeyStore('subscription')`), `subscriptionServiceProvider`, `subscriptionProvider` (поток снимка).

- [ ] Тесты: `снимок подписки читается без сети`; `истёкший снимок не открывает`; `обновление включает синхронизацию`; `подписка кончилась — синхронизация гаснет`; `сеть упала — снимок прежний`; `выход стирает снимок`; разбор `/v1/account` и цен.
- [ ] Красные → код → зелёные → коммит «Подписка в приложении: снимок с сервера».

### Задача 2: вход отдельно от покупки

**Файлы:**
- Создать: `lib/features/account/email_code_form.dart`, `lib/features/account/sign_in_screen.dart`, `lib/features/account/account_screen.dart`, `test/features/account/account_test.dart`
- Изменить: `lib/features/settings/sync_screen.dart` (форма — общая), `lib/features/settings/settings_screen.dart` (пункт «Войти» / почта), словари.

**Даёт:** `EmailCodeForm({required void Function() onSignedIn})` — шаги почты и кода из экрана Stowa Sync с теми же ключами (`sync-email`, `sync-code`, …); работает без хранилища. `signInRoute()` → `bool` (вошёл). `accountRoute()` — почта, подписка, «Выйти», «Удалить аккаунт» (подтверждение; живая подписка внешней кассы — объяснение «сперва отмените», в сборках магазинов — «отмените в магазине»).

- [ ] Тесты: `вход без хранилища`; `пункт «Войти» ведёт ко входу, после входа — почта`; `удаление аккаунта спрашивает и выходит`; `удаление при живой подписке — объяснение`; прежние тесты экрана Stowa Sync зелёные.
- [ ] Красные → код → зелёные → коммит.

### Задача 3: экран покупки и кассы

**Файлы:**
- Создать: `lib/services/billing/checkout.dart`, `lib/services/billing/lava_checkout.dart`, `lib/services/billing/store_checkout.dart`, `lib/features/subscription/paywall_screen.dart`, `web/paid.html`, `test/features/subscription/paywall_test.dart`, `test/services/billing/checkout_test.dart`
- Изменить: `pubspec.yaml` (`in_app_purchase`), `lib/data/providers.dart`, словари.

**Даёт:**
- `class PlanOffer {SubPlan plan; String price; num amount; String currency; Object? native;}`; `sealed class BuyResult` — `BuyDone(Subscription)`, `BuyWaiting(String url)`, `BuyCancelled()`, `BuyOwned()`, `BuyFailed()`.
- `abstract class Checkout {Future<List<PlanOffer>> offers(); Future<BuyResult> buy(PlanOffer offer); bool get canRestore; Future<BuyResult> restore(); List<String> get currencies; String currency; }`.
- `LavaCheckout` — счёт с сервера, страница оплаты во внешнем браузере (`urlOpenerProvider`), `BuyWaiting`; экран ждёт: при возврате приложения и раз в 5 секунд 30 минут зовёт `SubscriptionService.refresh()`.
- `abstract interface class StoreBilling {Future<List<PlanOffer>> products(); Future<void> buy(PlanOffer offer, String buyerId); Future<void> restore(String buyerId); Stream<StorePurchase> get purchases; Future<void> complete(StorePurchase purchase);}`; `InAppStoreBilling` поверх `in_app_purchase` (Android — `GooglePlayProductDetails` базовых планов без промо-предложений, `basePlanId` → тариф; iOS — три товара). `StoreCheckout` — покупка, чек на сервер, закрытие после ответа.
- `paywallRoute()` — пять пунктов (два с «Скоро»), три тарифа (год выбран, выгода к помесячной), «Продолжить»; не вошёл — `signInRoute()` и покупка дальше сама; ожидание оплаты; «Stowa Sync включена до …». Внизу условия продления по кассе, «Условия» и «Конфиденциальность», в магазинах — «Восстановить покупку».

- [ ] Тесты: `пять пунктов, два — скоро`; `цены внешней кассы в валюте страны, смена валюты`; `не вошёл — сперва вход, потом счёт`; `внешняя касса: вернулся — подписка включилась`; `сборка магазина: только магазин` (нет смены валюты и внешней страницы, есть «Восстановить»); `покупка в магазине закрывается после ответа сервера`; `чек другого аккаунта — сообщение, покупка закрыта`; `ни одна строка словарей не называет внешнюю кассу`.
- [ ] Красные → код → зелёные → коммит.

### Задача 4: настройки и экран подписки

**Файлы:** создать `lib/features/subscription/subscription_screen.dart`, `lib/features/subscription/subscribe_card.dart`; изменить `settings_screen.dart`, `storage_screen.dart` (строка Stowa Sync), словари; тесты `test/features/subscription/subscription_settings_test.dart`.

**Даёт:** первым пунктом настроек — карточка «Купить подписку» цветом акцента (нет подписки) или строка «Stowa Sync · до 22 декабря» (есть). Экран подписки: тариф, срок, откуда; внешняя касса — «Отменить продление» с подтверждением; магазин — «Управлять в Google Play / App Store» (страница подписок магазина); выдана вручную — «Выдана до …».

- [ ] Тесты: `без подписки первым пунктом — купить`; `с подпиской — срок`; `отмена продления спрашивает и показывает срок`; `магазинная — ведёт в магазин`.
- [ ] Красные → код → зелёные → коммит.

### Задача 5: замки

**Файлы:** изменить `sync_screen.dart`, `lib/features/web/panel_host.dart` или `panel_screen.dart`; создать `lib/features/subscription/locked_card.dart`; тесты в `sync_screen_test.dart` и тесте панели.

**Даёт:** Stowa Sync: не вошёл — «Купить подписку» и форма входа «Уже есть подписка»; вошёл без подписки — карточка подписки вместо управления; с подпиской — как сейчас. Панель без подписки — «Боковая панель — часть Stowa Sync» и кнопка, открывающая покупку на сайте (`https://stowa.work/?subscribe`; сайт по этому адресу сразу открывает экран покупки).

- [ ] Тесты: `вошёл без подписки — предложение вместо управления`; `не вошёл — купить и войти`; `панель без подписки — замок`, `панель с подпиской — строка`.
- [ ] Красные → код → зелёные → коммит.

### Задача 6: документы, сайт, проверка

- [ ] `site/terms.html` и `site/ru/terms.html` — условия подписки; политика (`site/privacy.html`, `site/ru/privacy.html`) — аккаунт, оплата, что хранит сервер; `docs/store/privacy-answers.md`.
- [ ] Весь набор тестов, `flutter analyze` — 0.
- [ ] Сайт: `tool/web/build.sh`, выкладка, проверка stowa.work, togetherly.day, sync.stowa.work; `paid.html` открывается.
- [ ] CI зелёный, `CLAUDE.md` проекта — раздел о подписке.
