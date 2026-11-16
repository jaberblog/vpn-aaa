# Evelyn VPN — اپ VLESS با فلاتر و flutter_vless

اپ اندروید VPN برپایهٔ VLESS Reality، ساخته‌شده با فلاتر و کتابخانهٔ
[`flutter_vless`](https://pub.dev/packages/flutter_vless) (هستهٔ Xray).
کانفیگ پیش‌فرض تو در `lib/default_config.dart` است.

## امکانات

- دکمهٔ **اتصال / قطع اتصال** (حالت VPN کامل، نه فقط پروکسی)
- نمایش **سرعت دانلود و آپلود** لحظه‌ای + مجموع دانلود/آپلود + مدت اتصال
- تست **تاخیر (پینگ)** سرور با دکمهٔ ⚡ بالای صفحه
- لیست سرورها: افزودن کانفیگ جدید با چسباندن لینک (`vless://` و بقیهٔ
  فرمت‌های پشتیبانی‌شده)، انتخاب و حذف سرور
- رابط فارسی و راست‌به‌چپ، تم تیره

## خروجی APK با گیت‌هاب (بدون نصب فلاتر روی کامپیوتر)

> ⚠️ **مهم:** این پروژه کانفیگ شخصی تو را دارد. مخزن گیت‌هاب را حتماً
> **Private** بساز و لینک کانفیگ را برای کسی نفرست.

1. در گیت‌هاب یک مخزن **Private** جدید بساز (مثلاً `evelyn-vpn`).
2. محتوای این پوشه را در آن مخزن push کن (فایل `android/local.properties`
   را push نکن — مخصوص کامپیوتر خودت است).
3. به تب **Actions** برو؛ ورک‌فلو `Build APK` با push به `main` یا با
   دکمهٔ **Run workflow** اجرا می‌شود.
4. بعد از سبز شدن، از پایین صفحهٔ همان run، فایل
   **`evelyn-vpn-apk`** را دانلود کن و `app-release.apk` را روی گوشی نصب کن.
   (فایل Artifact تا ۳۰ روز نگه داشته می‌شود.)

## اجرای محلی (اختیاری)

```bash
flutter pub get
flutter run -d android        # روی گوشی یا شبیه‌ساز
flutter build apk --release   # خروجی: build/app/outputs/flutter-apk/app-release.apk
```

## استفاده

1. برنامه را باز کن، روی **اتصال** بزن.
2. دیالوگ سیستمی VPN اندروید را تایید کن (فقط بار اول).
3. وضعیت «متصل» و سرعت دانلود/آپلود را همان‌جا می‌بینی.
4. برای عوض کردن سرور، اول قطع کن، بعد سرور دیگر را انتخاب کن.

## نکتهٔ نسخهٔ کتابخانه

`flutter_vless` دقیقاً روی نسخهٔ **1.1.5** پین شده است. دلیلش این است که
API منتشرشده در pub.dev برای این نسخه (`FlutterVless(onStatusChanged: …)`،
`initializeVless(…)`، `startVless(remark:…, config:…)` و
`VlessStatus` با `duration` به ثانیه و `connectionState`) با مستند
`doc/api.md` شاخهٔ main گیت‌هاب فرق می‌کند (آنجا سازندهٔ دیگری با
`onError`/`onLog` و `initializeVless(isCore:…)` آمده است). پس نسخه را
بدون بررسی API نسخهٔ جدید بالا نبر.

## ساختار

- `lib/main.dart` — رابط کاربری و منطق اتصال/قطع، سرعت و پینگ
- `lib/default_config.dart` — کانفیگ پیش‌فرض (لینک VLESS)
- `android/app/build.gradle.kts` — `minSdk = 23` و `useLegacyPackaging = true`
  (طبق راهنمای اندروید flutter_vless)
- `.github/workflows/build-apk.yml` — ساخت APK در گیت‌هاب اکشنز
