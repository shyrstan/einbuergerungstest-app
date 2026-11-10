# Серверная проверка Premium (уровень 4 защиты)

Функция `verify-premium` (Supabase Edge Function) проверяет у серверов Google то, что приложение сообщает о себе:

- **токен покупки** через Google Play Developer API: поддельную покупку (Lucky Patcher, эмулятор биллинга) Google не подтвердит;
- **токен Play Integrity**: перепакованный или переподписанный APK получает вердикт `UNRECOGNIZED_VERSION`.

Пока в сборке не заданы `VERIFY_URL` и `VERIFY_KEY`, приложение работает без сервера и полагается на уровни 1–3: перепроверка покупки при каждом запуске, обфускация, автоматическая защита Play.

Если сервер недоступен или ответ неясен (`null`), Premium у пользователя **не отбирается**. Отбирается он только при явном отказе Google.

## Что нужно один раз

1. **Supabase.** Выбрать проект: новый или существующий. Задеплоить функцию из `verify-premium/index.ts` с выключенной проверкой JWT (`--no-verify-jwt`): функция не хранит данных и не выдаёт секретов.
2. **Google Cloud.**
   1. В проекте включить *Google Play Android Developer API* и *Play Integrity API*.
   2. Создать сервисный аккаунт и скачать его JSON-ключ.
3. **Play Console → Пользователи и разрешения.**
   1. Пригласить e-mail сервисного аккаунта.
   2. Для обоих приложений выдать право «Просмотр финансовых данных».
4. **Play Console → каждое приложение → Целостность приложения → Play Integrity API.** Связать тот же Cloud-проект.
5. **Supabase → Edge Functions → Secrets.** Добавить `GOOGLE_SERVICE_ACCOUNT_JSON` — весь JSON-ключ целиком. Это делает владелец аккаунта сам.
6. **GitHub → Settings → Secrets and variables → Actions → Variables:**
   - `VERIFY_URL` = `https://<project-ref>.supabase.co/functions/v1/verify-premium`
   - `VERIFY_KEY` = publishable (anon) ключ проекта Supabase. Он и так публичный.
   - `PLAY_CLOUD_PROJECT` = номер (не ID) Cloud-проекта.
7. Поднять `version` в `pubspec.yaml` (например, `1.0.0+4`), запушить и загрузить новую AAB.

## Проверка после включения

- Обычная покупка через Play → Premium остаётся.
- Возврат денег в Play Console → при следующем запуске Premium снимается: уровень 1 работает и без сервера.
- APK, переподписанный чужим ключом → `appRecognized=false` → Premium снимается.

Логи функции: Supabase → Edge Functions → verify-premium → Logs.
