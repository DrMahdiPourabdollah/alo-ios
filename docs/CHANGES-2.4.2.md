# تغییرات 2.4.2

## فایل‌های مشترک
- `lib/voice/operation_queue.dart`: صف سبک برای عملیات async با ادامهٔ امن پس از خطا.
- `lib/voice/voice_native.dart`: هماهنگی عملیات ضبط، کنترل صفحهٔ بسته‌شده و پاک‌سازی مسیرهای موقت در خطا.
- `lib/ui/compose.dart`: کنترل وضعیت قبل از پایان/لغو، لغو در چرخهٔ عمر و سقف زمان مستقل از amplitude؛ اتکا به VAD به‌جای رد با بلندی صدا.
- `lib/domain/persian_text_normalizer.dart`: مرزبندی امن جداکنندهٔ هزارگان.
- `lib/domain/persian_number_parser.dart`: رد مقیاس تکراری بدون عدد جدید.
- `test/refinement_v242_test.dart`: ۱۸ تست رگرسیون عدد و صف عملیات ضبط.
- `pubspec.yaml`: نسخهٔ 2.4.2+7؛ بدون وابستگی جدید.

## فقط Android
- `tools/build_release.py`: نام خروجی کامل مطابق نسخهٔ 2.4.2.
- `android/app/build.gradle.kts`: اصلاح توضیح گمراه‌کنندهٔ امضای debug؛ رفتار امضای release تغییر نکرده است.

مدل‌های حجیم و کلیدهای امضا اضافه نشده‌اند. مدل، ظاهر، طرح دادهٔ ذخیره‌سازی و امکانات اپ حفظ شده‌اند.
