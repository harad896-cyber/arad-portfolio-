# Arad Messenger

پیام‌رسان اختصاصی Arad با Flutter و Supabase.

## وضعیت فعلی

- مخزن مستقل از سایت `arad-portfolio`
- اتصال Flutter به Supabase
- ورود با ایمیل و رمز عبور
- ساختار اولیه صفحه اصلی
- دیتابیس اولیه برای کاربران، گفتگوها، اعضای گفتگو و پیام‌ها
- Row Level Security برای داده‌های اصلی فعال شده است

## معماری

- Flutter / Dart — اپلیکیشن موبایل
- Supabase Auth — احراز هویت
- PostgreSQL — دیتابیس
- Supabase Realtime — پیام‌رسانی لحظه‌ای
- Supabase Storage — فایل، عکس، ویدیو و صدا

## اجرای محلی

```bash
flutter pub get
flutter run
```

این پروژه عمداً در مخزن `arad-portfolio-` قرار دارد و به مخزن سایت `arad-portfolio` دست نمی‌زند.
