<p align="center"><img src="screens/icon.png" width="96" alt=""></p>

<h1 align="center">Hivogram: сборки</h1>

<p align="center">Готовые установщики Hivogram, Telegram для десятков аккаунтов в одном окне.<br>
<b><a href="https://github.com/chvdbhcx-del/hivogram-builds/releases/latest">⬇ Скачать последнюю версию</a></b></p>

![Hivogram](screens/main-dark.png)

## Что скачать

| Платформа | Файл в [Releases](https://github.com/chvdbhcx-del/hivogram-builds/releases) |
|---|---|
| Windows 10/11 | `Hivogram-…-windows-x64-setup.exe` |
| Android 7+ | `Hivogram-…-android.apk` |
| iPhone и любой браузер | без установки: <https://hivogram.pages.dev>, в Safari «Поделиться» → «На экран Домой» |
| Windows, Hivogram Lite (лёгкая версия на Rust) | `hivogram-lite-windows-x64-…-setup.exe` |

Ключи Telegram уже внутри: после установки просто войдите по номеру телефона.

Если Windows SmartScreen ругается, нажмите «Подробнее» → «Выполнить в любом случае»: сборки без цифровой подписи. Если Android не ставит APK поверх старой версии, удалите старую и поставьте заново.

| Телефон | Hivogram Lite |
|---|---|
| ![Телефон](screens/phone-dark.png) | ![Hivogram Lite](screens/lite-dark.png) |

## Как это собирается

Репозиторий публичный только ради бесплатных минут GitHub Actions. Исходники лежат в приватном репозитории и забираются по секрету `SOURCE_TOKEN`, здесь только workflow и готовые файлы.

| Workflow | Что делает |
|---|---|
| [Hivogram](https://github.com/chvdbhcx-del/hivogram-builds/actions/workflows/hivogram.yml) | Windows `.exe` + Android `.apk` в Releases, веб-приложение на hivogram.pages.dev |
| [Hivogram Lite](https://github.com/chvdbhcx-del/hivogram-builds/actions/workflows/lite.yml) | лёгкая Windows-версия на Rust, `.exe` в Releases |
| [Publish a run](https://github.com/chvdbhcx-del/hivogram-builds/actions/workflows/publish-run.yml) | выкладывает в Releases файлы уже прошедшего прогона Hivogram |

Запуск: Actions → workflow → Run workflow, там же можно выбрать ветку исходников.

### Секреты (Settings → Secrets and variables → Actions)

| Секрет | Зачем |
|---|---|
| `SOURCE_TOKEN` | fine-grained токен GitHub: доступ к приватному `alltginone` (там и Hivogram, и Hivogram Lite в `lite/`), Contents: Read-only |
| `TELEGRAM_API_ID`, `TELEGRAM_API_HASH` | ключи Hivogram, вшиваются во все сборки |
| `CLOUDFLARE_API_TOKEN` | заливка на Cloudflare Pages (токен с шаблона «Edit Cloudflare Workers») |
| `VAPID_KEY` | необязательно: Web Push-ключ Telegram, иначе берётся с web.telegram.org/a |
| `ANDROID_KEYSTORE_BASE64` | необязательно: base64 ключа подписи APK. Подходит `debug.keystore` с ПК (пароль и алиас по умолчанию `android` / `androiddebugkey`), тогда APK ставится поверх старого |
| `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | только для своего `.jks` |
