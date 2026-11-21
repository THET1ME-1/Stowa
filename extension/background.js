// Chrome и Edge: касание значка расширения открывает боковую панель со Stowa.
// В Firefox панель открывается своим значком в боковой панели, этот вызов ему не нужен.
if (globalThis.chrome && chrome.sidePanel && chrome.sidePanel.setPanelBehavior) {
  chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: true }).catch(() => {});
}
