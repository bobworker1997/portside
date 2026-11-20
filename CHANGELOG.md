# Changelog

English | [繁體中文](CHANGELOG.zh-TW.md)

## v0.1.1

### Fixed

- **Auto-start no longer skips "confirm before connecting"**: Previously, a connection set to "connect automatically when Portside opens" would connect right away on launch, even if its environment (for example, Production) required confirmation before connecting. Such connections now show a confirmation dialog on launch, noting that the connection was started automatically. Choose "Connect" to connect, or "Cancel" to skip that connection; other auto-start connections continue as usual.

### Improved

- In Settings, when a connection has auto-start turned on and its environment requires confirmation, an orange note now explains that a confirmation dialog will appear when Portside opens.

## v0.1.0

- First public release.
