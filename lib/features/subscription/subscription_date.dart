import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Срок подписки по-человечески: «22 декабря», другой год — «22 декабря 2027 г.».
String subscriptionDate(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toString();
  final local = date.toLocal();
  return local.year == DateTime.now().year ? DateFormat.MMMMd(locale).format(local) : DateFormat.yMMMMd(locale).format(local);
}
