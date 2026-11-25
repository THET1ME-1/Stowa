{{flutter_js}}
{{flutter_build_config}}

// Без serviceWorkerSettings: устаревший service worker Flutter не регистрируется. На том же
// месте (/) живёт свой — web/stowa_sw.js с кнопками уведомлений, и чужой на каждой загрузке
// заменял его, а затем снимал себя вместе с ним.
_flutter.loader.load();
