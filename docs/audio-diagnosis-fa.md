# گزارش بررسی اولیهٔ صوت Flutter + Flame

> **این گزارش مرحلهٔ اولیه است.** پس از تأیید کاربر مبنی بر قطع دائمی تمام صداها در Android و ادامهٔ کار بازی، اصلاحات تکمیلی اعمال شد. وضعیت فعلی، تفاوت‌ها و محدودیت تست در [گزارش پیگیری بازی سریع](audio-fast-playback-fa.md) آمده است. توضیح‌های «بدون تغییر ماندن context» و رفتار اولیهٔ خطا در این سند، تاریخچهٔ مرحلهٔ اول هستند.

تاریخ بررسی: ۲۰۲۶-۰۹-۲۵ — مبنای کد: `7bc067a`، شاخهٔ `arena/01a0d893-ludo-tavakoli`.

## 1. خلاصه مشکل

گزارش کاربر: هنگام بازی سریع، صداها گاهی قطع می‌شوند، درست هم‌زمان پخش نمی‌شوند یا شنیده نمی‌شوند.

**نتیجهٔ تصمیم‌گیری: علت نهایی این رفتار روی دستگاه هنوز تأیید نشده است. مهاجرت به AudioPool انجام نشد؛ پروژه از قبل سه AudioPool مستقل دارد. افزودن AudioPool یا افزایش تصادفی تعداد پلیرها، راه‌حل اثبات‌شدهٔ این مشکل نیست.**

بررسی سورس، دو اشکال قطعی در رسیدگی به خطا نشان داد: خطای آماده‌سازی بدون هیچ گزارش بلعیده می‌شد و خطای Future مربوط به `pool.start()` بدون رسیدگی رها می‌شد. فقط این مرز خطا و ابزار مشاهدهٔ آن اصلاح شد. این اصلاح به معنی تأیید برطرف‌شدن قطع صدای گزارش‌شده نیست.

## 2. معماری صوتی فعلی پروژه

### نسخه‌ها

نسخه‌های زیر از `apps/ludo_app/pubspec.lock` خوانده شدند، نه از حداقل نسخهٔ مجاز در pubspec:

| پکیج | محدودیت pubspec / نوع | نسخهٔ resolve‌شده |
|---|---|---|
| flame | `^1.30.1` | `1.38.0` |
| flame_audio | `^2.11.8` | `2.12.2` |
| audioplayers | غیرمستقیم | `6.7.1` |
| audioplayers_android | غیرمستقیم | `5.2.1` |
| audioplayers_darwin | غیرمستقیم | `6.4.0` |
| audioplayers_platform_interface | غیرمستقیم | `7.1.1` |
| audioplayers_web | غیرمستقیم | `5.2.1` |
| audioplayers_linux | غیرمستقیم | `4.2.1` |
| audioplayers_windows | غیرمستقیم | `4.3.1` |

Flutter/Dart SDK در این محیط نصب نیست؛ نسخهٔ SDK نصب‌شده قابل گزارش نیست. نیازمندی پروژه Dart `^3.11.5` است و lockfile حداقل Flutter `3.41.0` را ثبت کرده است. هیچ وابستگی یا lockfile تغییر نکرد.

### ساختار

- تنها مرکز صوت بازی: `lib/features/game/game_engine/managers/audio_manager.dart`؛ کلاس static با طول عمر سراسری برنامه.
- سه Pool جدا برای `dice.mp3`، `move.mp3` و `rocket.mp3` با `AudioPool.createFromAsset`.
- هیچ فراخوانی مستقیم `FlameAudio.play`، هیچ `AudioPlayer` مشترک برای این سه صدا و هیچ ساخت مستقیم پلیر در eventهای بازی پیدا نشد.
- `AudioPool` از طریق export پکیج `flame_audio` در دسترس است؛ پیاده‌سازی واقعی آن در `audioplayers 6.7.1` است.
- فایل صوتی یا مسیر پخش جداگانه‌ای برای دکمه، اعلان، برد یا موسیقی پس‌زمینه در کد برنامه وجود ندارد. تنظیم «اعلان‌ها» به معنی وجود صدای notification در بازی نیست.

### معنی واقعی ظرفیت و آماده‌سازی

در نسخهٔ دقیق کتابخانه:

- `minPlayers` پیش‌فرض **۱** است؛ بنابراین تعیین `maxPlayers: 4` به معنی پیش‌بارگذاری چهار پلیر نیست.
- `maxPlayers` سقف تعداد **پلیرهای بیکارِ نگه‌داری‌شده** است، نه سقف پخش هم‌زمان.
- وقتی پلیر آماده موجود نباشد، `start()` یک پلیر تازه می‌سازد. درخواست پنجم صرفاً به علت `maxPlayers: 4` رد نمی‌شود.
- هر Pool دارای lock داخلی برای رزرو پلیر و شروع پخش است؛ lock تا پایان فایل صوتی نگه داشته نمی‌شود.
- حالت پیش‌فرض `PlayerMode.mediaPlayer` و release mode داخلی `ReleaseMode.stop` است. پایان طبیعی صدا از طریق `onPlayerComplete` پلیر را به Pool برمی‌گرداند.
- در مسیر overflow، کتابخانه `release()` می‌کند؛ این با `dispose()` کامل یکسان نیست. مصرف منابع در فشار بسیار بالا باید روی دستگاه اندازه‌گیری شود، نه اینکه `maxPlayers` یک سقف سراسری فرض شود.

## 3. مسیر اجرای صدا از event تا playback

| رویداد | مسیر واقعی | الگوی فراخوانی |
|---|---|---|
| تاس آفلاین | `LudoDice.onTapDown → playSound → AudioManager.playDiceSound → dicePool.start` | یک بار برای تاس پذیرفته‌شده؛ انیمیشن ۰٫۳ ثانیه مستقل از پایان صدا |
| تاس آنلاین/بات | `OnlineMatchScreen._handleState → _scheduleSnapshot → _drainSnapshots → Ludo.animateDiceValue → LudoDice.showServerRoll → playSound → dicePool.start` | در صف نمایش snapshot؛ قبل از اعمال snapshot حدود ۳۴۰ میلی‌ثانیه مکث بصری |
| حرکت رو به جلو | `GameState.moveForward` یا `OnlineSessionAdapter.apply → TokenComponent.animatePath → AudioManager.playMoveSound → movePool.start` | یک درخواست در هر خانه؛ سه افکت ۵۰ میلی‌ثانیه‌ای و مکث ۱۲۰ میلی‌ثانیه‌ای، یعنی حدود ۲۷۰ میلی‌ثانیه یا بیشتر بین دو خانه |
| مهرهٔ زده‌شده | `tokenCollision/moveBackward` یا برنامهٔ capture در adapter آنلاین `→ animatePathBackward → playMoveSound` | تنها یک صدا برای هر مهرهٔ برگشتی، نه در هر خانه؛ چند قربانی می‌توانند با `Future.wait` هم‌زمان شروع شوند |
| موشک فتاح | `OnlineSessionAdapter → launchFattahRocket → RocketComponent.onLoad → playRocketSound → rocketPool.start` | یک بار هنگام بارگذاری overlay؛ پرواز و انفجار بصری جمعاً ۰٫۸۷ ثانیه |

`animateToSpot` و `animateToBase` خودشان صدایی پخش نمی‌کنند. در fast-forward آنلاین، adapter همین مسیرهای کوتاه را انتخاب می‌کند و انیمیشن موشک را نیز عمداً کنار می‌گذارد. همچنین جایگزین‌شدن snapshot معوق می‌تواند roll صوتی/بصری معوق را حذف کند. بنابراین «صدای رویداد نیامد» لزوماً خطای backend صوت نیست؛ ممکن است اصلاً درخواست پخش صادر نشده باشد. این سیاست‌های نمایش تغییر نکردند.

### await و هم‌زمانی

`await AudioManager.playMoveSound()` در کد مهره، **منتظر پایان صدا نیست**. متد قبلی فقط `unawaited(pool.start())` اجرا می‌کرد و Future خودش فوراً خاتمه می‌یافت. این رفتار non-blocking حفظ شد؛ هیچ انتظار تازه‌ای به حرکت مهره یا گردش نوبت اضافه نشد.

خود `pool.start()` نیز Future پایان فایل نیست؛ Future آماده‌شدن شروع پخش است و یک `StopFunction` برمی‌گرداند. صداهای تاس، حرکت و موشک می‌توانند هم‌پوشانی طبیعی داشته باشند. مثلاً فایل تاس حدود ۷۹۲ میلی‌ثانیه است، نه ۳۰۰ یا ۳۴۰ میلی‌ثانیه؛ شروع حرکت پیش از تمام‌شدن نمونهٔ تاس ذاتاً نامعتبر نیست.

## 4. علت اصلی که پیدا شد

### موارد قطعی در کد

1. **رهاشدن خطای Future پخش:** `unawaited` خطا را catch نمی‌کند. اگر `pool.start()` شکست می‌خورد، Future عمومی AudioManager قبلاً موفق تمام شده بود؛ `await` در caller نمی‌توانست این خطای جداشده را بگیرد. اکنون همان شروع غیرمسدودکننده داخل helper دارای `try/await/catch` انجام می‌شود.
2. **مخفی‌شدن خطای ساخت Pool:** catch اولیه حتی نام asset معیوب را ثبت نمی‌کرد. شکست dice می‌توانست ساخت همهٔ Poolها، و شکست move ساخت rocket را نیز متوقف کند. اکنون با فعال‌کردن diagnostics، مرحله و مسیر شکست ثبت می‌شود؛ ترتیب، رفتار retry و سیاست ادامهٔ بازی عوض نشده‌اند.

این‌ها ایرادهای واقعیِ مدیریت خطا هستند، اما بدون ثبت شکست در دستگاه کاربر نمی‌توان آن‌ها را علت قطعی قطع‌شدن صدا دانست.

### نامزد مهمِ وابسته به پلتفرم: audio focus

`AudioPool.createFromAsset` در این نسخه پارامتر `audioContext` ندارد و آن را به `create` نمی‌فرستد. در پروژه نیز تنظیم global context وجود ندارد. تنظیم پیش‌فرض Android برابر `AndroidAudioFocus.gain` است؛ در کد native، دریافت focus loss به `pause()` منجر می‌شود. در صورت pause شدن، پایان طبیعی نمونه ممکن است رخ ندهد و بازیافت خودکار پلیر نیز به تأخیر بیفتد.

از طرف دیگر، `FlameAudio.createPool` در نسخهٔ ۲٫۱۲٫۲ context پیش‌فرض `mixWithOthers` را اعمال می‌کند؛ اما پروژه اصلاً آن helper را فراخوانی نمی‌کند. پس نمی‌توان صرف import کردن `flame_audio` را به معنی فعال‌بودن mixing دانست.

این تفاوت در سورس تأیید شد، ولی وقوع focus loss بین صداهای همین برنامه روی دستگاه هدف تأیید نشده است. **AudioContext، player mode، min/maxPlayers و API ساخت Pool عمداً تغییر نکردند.** اگر لاگ دستگاه این مسیر را ثابت کند، `AudioPool.create` پارامتر رسمی `audioContext` دارد و اصلاح هدفمند context ممکن است کافی باشد؛ افزودن پارامتر خیالی به `createFromAsset` صحیح نیست.

## 5. آیا مشکل واقعاً از concurrent playback / shared AudioPlayer بود یا خیر

- فرض «استفاده از یک AudioPlayer برای همهٔ افکت‌ها»: با کد فعلی سازگار نیست.
- فرض «ردشدن صدا به محض رسیدن به maxPlayers»: با پیاده‌سازی نسخهٔ ۶٫۷٫۱ سازگار نیست.
- امکان overlap: بله؛ بین انواع صدا، چند capture، و درخواست‌های سریع وجود دارد و Pool از ابتدا برای آن استفاده شده است.
- مشکل runtime ناشی از focus، دیر ساخته‌شدن پلیر اضافی، خطای backend یا autoplay مرورگر: هنوز رد یا اثبات نشده است.
- مهاجرت یا افزایش ظرفیت AudioPool بدون این شواهد انجام نشد.

## 6. اگر AudioPool استفاده شد: دقیقاً چه فایل‌هایی تغییر کردند و چرا

**AudioPool جدیدی معرفی نشد و مهاجرتی انجام نشد.** سه Pool موجود، همان assetها و همان ظرفیت‌ها را حفظ کرده‌اند.

تنها فایل production تغییرکرده `audio_manager.dart` است:

- گرفتن خطای sync/async مربوط به `start()` داخل task جداشده؛
- تشخیص درخواست پخش در وضعیت muted یا Pool آماده‌نشده؛
- لاگ اختیاری آماده‌سازی، شروع، تأخیر شروع، خطا و dispose؛
- یک factory با برچسب `@visibleForTesting` برای تست بدون backend صوتی؛ مقدار production همان `AudioPool.createFromAsset` است.

هیچ call site گیم‌پلی، تاس، مهره، موشک، snapshot، تنظیمات، فایل صوتی یا dependency تغییر نکرد.

## 7. برای هر AudioPool: نام صدا و maxPlayers و دلیل انتخاب

| صدا | maxPlayers قبل/بعد | minPlayers قبل/بعد | دلیل عدم تغییر |
|---|---|---|---|
| تاس | ۳ / ۳ | پیش‌فرض ۱ / ۱ | ظرفیت از قبل وجود داشت؛ کمبود یا نیاز به افزایش در runtime ثابت نشد |
| حرکت | ۴ / ۴ | پیش‌فرض ۱ / ۱ | حرکت معمولی از طول نمونه کندتر است؛ capture هم‌زمان ممکن است، ولی maxPlayers سقف concurrency نیست |
| موشک | ۲ / ۲ | پیش‌فرض ۱ / ۱ | ظرفیت موجود؛ دلیل فنی برای Pool تازه یا تغییر ظرفیت مشاهده نشد |

دلیل انتخاب اعداد اولیه در کد مستند نشده است. این گزارش ادعا نمی‌کند که اعداد بالا با اندازه‌گیری concurrency روی دستگاه بهینه شده‌اند.

## 8. اگر AudioPool استفاده نشد: علت دقیق عدم استفاده و راه‌حل واقعی

منظور از «استفاده نشد»، **اضافه‌کردن یا مهاجرت تازه** است؛ Poolهای موجود حذف نشده‌اند.

راه‌حل قطعی برای نقص مدیریت خطا، catch کردن Future واقعی `start()` است، نه catch کردن Future عمومی متدی که پخش را قبلاً جدا کرده است. برای قطع صدای گزارش‌شده، فعلاً گام درست ثبت شواهد است؛ افزایش Pool نمی‌تواند خطای بارگذاری، نبودن event پخش، focus loss یا سیاست autoplay را به‌خودی‌خود حل کند.

تشخیص اختیاری:

```bash
cd apps/ludo_app
flutter run --dart-define=AUDIO_DIAGNOSTICS=true
```

در DevTools بخش Logging، نام `ludo.audio` را فیلتر کنید. build عادی بدون این define، این لاگ‌ها و Stopwatchها را فعال نمی‌کند.

| نشانهٔ لاگ | تفسیر درست |
|---|---|
| `pool_create` سپس `pool_ready` | ساخت Pool انجام شده؛ تضمین شنیده‌شدن صدا نیست |
| `pool_failed path=...` | خطای مشخص ساخت/بارگذاری، همراه exception و stack |
| `play_skipped ... reason=muted` | تنظیم sound خاموش بوده است |
| `play_skipped ... reason=pool_not_ready` | مرجع Pool موجود نیست؛ آماده‌سازی شروع نشده یا شکست خورده است |
| `start_requested ... request=... pendingStarts=...` | درخواست صادر شده؛ pendingStarts فقط Futureهای startِ تمام‌نشده را می‌شمارد، نه پلیرهای در حال پخش |
| `start_returned ... elapsedMs=...` | Future شروع برگشته؛ به معنی completion یا خروجی شنیداری نیست |
| `start_failed ...` | خطای Future شروع مهار و ثبت شده است |
| نبودن `start_requested` برای یک رویداد | ابتدا مسیر event/fast-forward/حذف snapshot را بررسی کنید؛ هنوز درخواست صوتی نداشته‌ایم |

این ابزار هیچ listener دائمی تازه، صف playback، retry خودکار، timer دوره‌ای یا history نامحدود در حافظه اضافه نمی‌کند. خطاهای داخلی native یا callback بازیافت کتابخانه که بعد از بازگشت `start()` رخ دهند، الزاماً با این catch گرفته نمی‌شوند؛ لاگ پلتفرم نیز لازم است.

## 9. تست‌هایی که انجام شد و نتیجه هرکدام

### اجراشده

- جست‌وجوی سراسری کد برای APIهای صوتی، call siteها، init، dispose، route و lifecycle: انجام شد؛ مسیرهای بالا نتیجهٔ این بررسی‌اند.
- تطبیق API با سورس tagهای دقیق `flame_audio-v2.12.2` و `audioplayers-v6.7.1`: انجام شد؛ نسخه‌های native نیز با lockfile تطبیق داده شدند.
- وجود هر سه فایل در Git و اعلان آن‌ها در pubspec: تأیید شد.
- بررسی prefix: `AudioPool.createFromAsset` از `AudioCache.instance` با prefix برابر `assets/` استفاده می‌کند؛ `audio/move.mp3` به `assets/audio/move.mp3` می‌رسد. prefix متفاوت `FlameAudio.audioCache` در این مسیر دخالت ندارد.
- `ffprobe` و decode کامل با `ffmpeg -v error -xerror -i <file> -f null -`: هر سه فایل exit code صفر و stderr خالی داشتند:

| فایل | مدت فایل | نرخ نمونه / کانال |
|---|---|---|
| dice.mp3 | ۰٫۷۹۲ ثانیه | 24000 Hz / stereo |
| move.mp3 | ۰٫۱۹۲ ثانیه | 48000 Hz / stereo |
| rocket.mp3 | ۰٫۹۹۲۶۶۷ ثانیه | 44100 Hz / mono |

این نتیجه سلامت decode فایل‌های مخزن را نشان می‌دهد، نه دسترسی asset در APK نصب‌شده یا سازگاری قطعی decoder هر دستگاه. ابزارهای FFmpeg فقط در `/tmp` نصب شدند؛ به پروژه dependency یا binary اضافه نشد.

- `git diff --check`: موفق.
- عدم تغییر pubspec، lockfile، assetها و فایل‌های gameplay در diff: تأیید شد.

### تست‌های نوشته‌شده، ولی اجرا‌نشده

`test/audio_manager_test.dart` با Poolهای mock، پوشش موارد زیر را اضافه می‌کند:

1. مسیر و ظرفیت‌های فعلی، و reuse در initializeهای متوالی؛
2. پخش عادی و حفظ volume؛
3. شش درخواست سریع تاس، دوازده حرکت و یک موشک با Future شروعِ معوق؛ عدم مسدودکردن caller؛
4. عدم فراخوانی stop بلافاصله پس از start؛
5. مهار خطاهای sync و async شروع؛
6. آماده‌سازی معوق و درخواست زودهنگام؛
7. شکست بخشی از initialize و رفتار retry موجود؛
8. تنظیم mute؛
9. dispose صریح و initialize مجدد.

`test/audio_assets_test.dart` هر سه asset را از manifest و `rootBundle` واقعی تست Flutter می‌خواند و با فایل مخزن مقایسه می‌کند. `rocket_asset_test.dart` موجود نیز بدون تغییر باقی ماند.

**محدودیت اجرا:** تلاش برای `flutter analyze`، `flutter test` و `flutter build apk --debug` به دلیل `flutter: command not found` با کد ۱۲۷ متوقف شد. دانلود SDK نیز در این محیط با خطای اتصال TLS به مخزن Flutter در دسترس نبود. هیچ تست Flutter یا build را موفق اعلام نمی‌کنیم. حتی موفقیت تست mock، شنیده‌شدن صحیح صدا روی سخت‌افزار را ثابت نمی‌کند.

فرمان‌های اجرای کامل در محیط دارای SDK:

```bash
cd apps/ludo_app
flutter pub get --enforce-lockfile
flutter analyze
flutter test test/audio_manager_test.dart test/audio_assets_test.dart test/rocket_asset_test.dart
flutter test --dart-define=AUDIO_DIAGNOSTICS=true test/audio_manager_test.dart
flutter build apk --debug
```

## 10. فایل‌های تغییرکرده

1. `apps/ludo_app/lib/features/game/game_engine/managers/audio_manager.dart` — اصلاح محدود مرز خطا و diagnostics اختیاری؛ معماری و APIهای عمومی playback حفظ شدند.
2. `apps/ludo_app/test/audio_manager_test.dart` — تست‌های mock برای routing، هم‌زمانی درخواست‌ها و رفتار خطا.
3. `apps/ludo_app/test/audio_assets_test.dart` — تست بسته‌بندی هر سه asset.
4. `docs/audio-diagnosis-fa.md` — این گزارش و برنامهٔ بازتولید.

## 11. ریسک‌ها یا مواردی که هنوز نیاز به بررسی runtime دارند

- **دستگاه و پلتفرم نامعلوم است.** مدل دستگاه، نسخهٔ OS، Android/iOS/Web، debug/profile/release و نام صدایی که قطع می‌شود لازم است.
- **Audio focus:** هنگام بازتولید Android، لاگ‌های `AudioManager`/`AudioFocus`/`MediaPlayer`/`Audioplayers` و خروجی `adb shell dumpsys audio` را با زمان `start_requested` مقایسه کنید. وجود `start_returned` همراه pause/focus loss با نبود درخواست پخش تفاوت دارد. لاگ‌های نامرتبط، اطلاعات حساب و tokenها را حذف کنید.
- **Warm-up:** چون minPlayers برابر ۱ است، اولین overlap می‌تواند ساخت native player داشته باشد. latency درخواست اول و درخواست‌های گرم‌شده را مقایسه کنید؛ هنوز شواهدی برای افزایش prewarm نداریم.
- **منابع:** maxPlayers سقف active player یا Futureهای pending نیست. تعداد پلیرهای native، completionها، RAM و latency را در بازی طولانی اندازه بگیرید. افزایش پیوستهٔ pendingStarts فقط معطلی start را نشان می‌دهد؛ پلیر متوقف‌شده پس از start به لاگ native/پروفایلر نیاز دارد.
- **Lifecycle:** `AudioManager.dispose()` هیچ caller تولیدی ندارد. reuse سراسری بین بازی‌ها فعلاً برقرار است؛ این به‌تنهایی اثبات memory leak نیست. initialize/dispose هم‌زمان محافظ single-flight ندارد؛ boolean فقط initialize کامل‌شده را پوشش می‌دهد. این وضعیت بدون بازتولید به بازنویسی lifecycle تبدیل نشد.
- **Mute:** شروع بازی با sound خاموش باعث skip شدن init است. روشن‌شدن تنظیم به‌تنهایی initialize نمی‌کند؛ ورود معمول به بازی تازه initialize را دوباره فراخوانی می‌کند. تغییر تنظیم در حالی که همان game زنده می‌ماند نیاز به بازتولید دارد.
- **خروج/پس‌زمینه:** routeها یا lifecycle صداهای در حال پخش را صریحاً stop نمی‌کنند. `TokenComponent.onRemove` Future افکت‌ها را complete می‌کند، اما حلقه‌های async حرکت cancellation صریح ندارند؛ احتمال ادامهٔ فراخوانی پس از خروج نیاز به لاگ زمانی دارد. منطق حرکت تغییر نکرد.
- **Web/iOS:** سیاست autoplay و فعال‌سازی session/interruptions باید روی همان پلتفرم بررسی شود؛ سلامت MP3 در FFmpeg این موارد را رد نمی‌کند.

### ماتریس بازتولید روی دستگاه

| سناریو | شواهد مورد نیاز |
|---|---|
| بازی آهسته پس از ورود | pool_ready قبل از اولین start؛ هر event یک درخواست مورد انتظار |
| تاس‌های سریع/نوبت‌های پشت‌سرهم بات | نام صدا، زمان start/return، focus loss و اینکه snapshot حذف شده یا نه |
| حرکت شش‌خانه‌ای | فاصلهٔ startهای move حدود زمان انیمیشن، نه انتظار تا پایان MP3 |
| زدن چند مهره | شروع‌های move هم‌زمان و بازیافت بعد از completion |
| موشک و برگشت قربانی | overlap انتهای نمونهٔ rocket با move، بدون قطع ناخواسته |
| بیست بار خروج و ورود بازی | reuse Poolها، نبود ساخت تکراریِ غیرمنتظره و روند منابع |
| background/foreground و mute/unmute | تفاوت skip عمدی، وقفهٔ session و خطای واقعی start |

### منابع API بررسی‌شده

- [flame_audio 2.12.2 — helperها و cache/context](https://github.com/flame-engine/flame/blob/flame_audio-v2.12.2/packages/flame_audio/lib/flame_audio.dart)
- [audioplayers 6.7.1 — AudioPool و معنای min/maxPlayers](https://github.com/bluefireteam/audioplayers/blob/audioplayers-v6.7.1/packages/audioplayers/lib/src/audio_pool.dart)
- [AudioCache و prefix پیش‌فرض](https://github.com/bluefireteam/audioplayers/blob/audioplayers-v6.7.1/packages/audioplayers/lib/src/audio_cache.dart)
- [تنظیم پیش‌فرض AudioContext](https://github.com/bluefireteam/audioplayers/blob/audioplayers-v6.7.1/packages/audioplayers_platform_interface/lib/src/api/audio_context.dart)
- [Android FocusManager](https://github.com/bluefireteam/audioplayers/blob/audioplayers-v6.7.1/packages/audioplayers_android/android/src/main/kotlin/xyz/luan/audioplayers/player/FocusManager.kt)
- [Android WrappedPlayer و pause روی focus loss](https://github.com/bluefireteam/audioplayers/blob/audioplayers-v6.7.1/packages/audioplayers_android/android/src/main/kotlin/xyz/luan/audioplayers/player/WrappedPlayer.kt)
