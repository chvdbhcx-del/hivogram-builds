# Сборки и CI

## Workflow

| Workflow | Что делает |
|---|---|
| [Check](https://github.com/chvdbhcx-del/hivogram-builds/actions/workflows/check.yml) | проверки исходников (fmt, clippy, тесты, сборка хоста, тесты Lite); Hivogram и Hivogram Lite запускают его первым и без него ничего не публикуют |
| [Hivogram](https://github.com/chvdbhcx-del/hivogram-builds/actions/workflows/hivogram.yml) | Windows `.exe` + Android `.apk` в Releases, веб-приложение на hivogram.pages.dev |
| [Hivogram Lite](https://github.com/chvdbhcx-del/hivogram-builds/actions/workflows/lite.yml) | лёгкая Windows-версия на Rust, `.exe` в Releases |
| [Publish a run](https://github.com/chvdbhcx-del/hivogram-builds/actions/workflows/publish-run.yml) | выкладывает в Releases файлы уже прошедшего прогона Hivogram |

Запуск: Actions → workflow → Run workflow, там же можно выбрать ветку исходников.

## Секреты (Settings → Secrets and variables → Actions)

| Секрет | Зачем |
|---|---|
| `SOURCE_TOKEN` | fine-grained токен GitHub: доступ к репозиторию исходников, Contents: Read-only |
| `TELEGRAM_API_ID`, `TELEGRAM_API_HASH` | ключи Hivogram, вшиваются во все сборки |
| `CLOUDFLARE_API_TOKEN` | заливка на Cloudflare Pages (токен с шаблона «Edit Cloudflare Workers») |
| `VAPID_KEY` | необязательно: Web Push-ключ Telegram, иначе берётся с web.telegram.org/a |
| `ANDROID_KEYSTORE_BASE64` | необязательно: base64 ключа подписи APK. Подходит `debug.keystore` с ПК (пароль и алиас по умолчанию `android` / `androiddebugkey`), тогда APK ставится поверх старого |
| `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | только для своего `.jks` |
| `UPDATE_SIGNING_KEY` | секретный ключ minisign (без пароля), подписывает `SHA256SUMS*.txt` → `.minisig`. Без него релиз выходит без подписи (с предупреждением), и обновлённые приложения его не поставят |

## Подпись обновлений

Release-job подписывает `SHA256SUMS.txt` / `SHA256SUMS-lite.txt` (`.github/scripts/sign-sums.sh` → `minisign.mjs`, только Node, без пакетов). Приложения проверяют подпись встроенным открытым ключом до того, как доверять контрольным суммам; доверенный комментарий подписи называет тег релиза. Проверить вручную:

```sh
rsign verify -P RWREcf1Ctlup0X1o4PMGGXIGBJL4XwWVfMDdkasA9j787S+nJefsATMJ -x SHA256SUMS.txt.minisig SHA256SUMS.txt
```
