# hivogram-builds

Сборки Hivogram в GitHub Actions. Репозиторий публичный только ради бесплатных минут Actions:
исходники лежат в приватных репозиториях и забираются по секрету `SOURCE_TOKEN`, здесь только workflow и
готовые файлы в [Releases](../../releases).

| Workflow | Что делает |
|---|---|
| **Hivogram** | `alltginone`: Windows `.exe` + Android `.apk` в Releases, веб-приложение на https://hivogram.pages.dev |
| **Oxigram** | `hivogram-oxigram`: Windows `.exe` в Releases |

Запуск: Actions → workflow → Run workflow (можно выбрать ветку исходников).

## Секреты (Settings → Secrets and variables → Actions)

| Секрет | Зачем |
|---|---|
| `SOURCE_TOKEN` | fine-grained токен GitHub: доступ к `alltginone` и `hivogram-oxigram`, Contents: Read-only |
| `TELEGRAM_API_ID`, `TELEGRAM_API_HASH` | ключи Hivogram, вшиваются во все сборки |
| `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` | заливка на Cloudflare Pages (токен с правом «Cloudflare Pages: Edit») |
| `VAPID_KEY` | необязательно: Web Push-ключ Telegram (иначе берётся с web.telegram.org/a) |
| `ANDROID_KEYSTORE_BASE64` | необязательно: base64 ключа подписи APK; подходит `debug.keystore` с ПК (пароль/алиас по умолчанию `android`/`androiddebugkey`), тогда APK ставится поверх старого |
| `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | только для своего `.jks` |
