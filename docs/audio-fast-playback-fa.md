# پیگیری قطع دائمی صدا هنگام بازی سریع در Android

این گزارش جایگزین نتیجه‌گیری مرحلهٔ اول در `audio-diagnosis-fa.md` برای وضعیت فعلی کد است. کاربر تأیید کرد: **Android، بازی ادامه دارد، همهٔ صداها تا راه‌اندازی مجدد برنامه قطع می‌شوند.**

## ۱. خلاصه مشکل

موضوع فقط overlap شنیداری نیست؛ باید مسیری بررسی شود که پلیرهای native را به‌تدریج از چرخهٔ بازیافت خارج کند یا یک Pool معیوب را برای همیشه زنده نگه دارد.

دو مسیر مشخص در سورس نسخهٔ قفل‌شده پیدا شد و اصلاح هدفمند برای آن‌ها اعمال شد. با این حال، بدون اجرای نسخهٔ اصلاح‌شده و لاگ گوشی، وقوع دقیق زنجیرهٔ زیر در دستگاه کاربر هنوز اثبات نشده است. این گزارش، «اشکال قابل استنتاج از سورس» را با «بازتولید روی گوشی» یکسان نمی‌گیرد.

## ۲. معماری فعلی

نسخه‌ها بدون تغییر: `flame 1.38.0`، `flame_audio 2.12.2`، `audioplayers 6.7.1` و `audioplayers_android 5.2.1`.

سه AudioPool موجود برای تاس، حرکت و موشک حفظ شدند. هیچ AudioPlayer مستقل، backend تازه، فایل صوتی، تغییر ولوم یا تغییر dependency اضافه نشد. APIهای `initialize`، `playDiceSound`، `playMoveSound`، `playRocketSound` و `dispose` همان امضاها را دارند.

تنها فایل production این پیگیری `audio_manager.dart` است. کلاس خصوصی `_SoundChannel` در همان فایل، مالکیت و وضعیت هر کدام از سه Pool را مدیریت می‌کند؛ خودش موتور صوتی یا پیاده‌سازی جایگزین AudioPool نیست.

## ۳. مسیر رویداد تا پخش

مسیرهای بازی عوض نشده‌اند:

- تاس آفلاین و آنلاین/بات → `LudoDice` → `AudioManager.playDiceSound`؛
- حرکت و برگشت مهره → `TokenComponent` → `AudioManager.playMoveSound`؛
- موشک → `RocketComponent.onLoad` → `AudioManager.playRocketSound`.

پس از بررسی mute و lifecycle، درخواست به همان Pool مربوط به صدا می‌رسد. caller حتی با `await playMoveSound()` منتظر شروع native یا پایان فایل نمی‌ماند. شروع‌های سالم می‌توانند هم‌زمان باشند.

## ۴. مسیرهای خرابی پیدا‌شده

### مسیر A: audio focus → pause بدون completion → پلیرهای بازیافت‌نشده

۱. `AudioPool.createFromAsset` در نسخهٔ ۶٫۷٫۱ context مخصوص mixing را اعمال نمی‌کند. تنظیم پیش‌فرض Android، `AndroidAudioFocus.gain` است.

۲. هر AudioPlayer داخل Pool، FocusManager خودش را دارد. در صورت اعلام focus loss، `WrappedPlayer` پلیر را pause می‌کند. در loss دائمی، `playing` در native نیز false می‌شود.

۳. pause به معنی پایان نمونه نیست؛ `onPlayerComplete` صادر نمی‌شود. Pool از همین completion برای خارج‌کردن پلیر از `currentPlayers` و بازگرداندنش به `availablePlayers` استفاده می‌کند.

۴. درخواست بعدی وقتی available player نداشته باشد، پلیر دیگری می‌سازد. **maxPlayers سقف active player نیست.** به همین دلیل صرف تنظیم عدد ۳ یا ۴ جلوی این زنجیره را نمی‌گیرد.

۵. پیام focus loss در این مسیر وضعیت Dart را مثل فراخوانی `AudioPlayer.pause()` به‌روزرسانی نمی‌کند. در سورس همین نسخه، `FramePositionUpdater` پیش‌فرض نیز می‌تواند تا رسیدن stop/completion در سمت Dart باقی بماند. علاوه بر پلیر native، polling موقعیت هم ممکن است باقی بماند.

این زنجیره با قطع کامل صدا بعد از فشار زیاد سازگار است، ولی اینکه OS/OEM گوشی کاربر دقیقاً همین focus lossها را صادر کرده باشد، هنوز نیاز به لاگ دارد.

**اصلاح:** فقط در Android، ساخت Pool از API رسمی `AudioPool.create(source: AssetSource(...), audioContext: ...)` با `AndroidAudioFocus.none` انجام می‌شود. بدین ترتیب افکت‌های کوتاه برای focus انحصاری با یکدیگر رقابت نمی‌کنند. مسیر cache، حالت `mediaPlayer`، minPlayers و ظرفیت‌های قبلی عوض نشده‌اند. برای iOS/Web/Desktop، context همچنان null است.

### مسیر B: خطای start → رزروِ بدون rollback → استفادهٔ دوباره از Pool خراب

در سورس `AudioPool.start()` ترتیب دقیق چنین است:

```text
رزرو/ساخت پلیر
currentPlayers[playerId] = player
await player.setVolume(...)
await player.resume()
نصب listener مربوط به completion
برگرداندن StopFunction
```

اگر setVolume یا resume خطا بدهد، این نسخه در این مسیر rollback ندارد: پلیر رزروشده در currentPlayers باقی می‌ماند و listener بازیافت هم ممکن است هنوز نصب نشده باشد. در کد قبلی، catch فقط جلوی انتشار exception را می‌گرفت؛ منابع پلیر را پس نمی‌گرفت و Pool نیز برای درخواست‌های بعدی آماده فرض می‌شد.

**اصلاح:** پس از خطای واقعی start، همان Pool معیوب می‌شود؛ درخواست تازه وارد آن نمی‌شود. ابتدا شروع‌های قبلاً صادرشده تمام می‌شوند، سپس کل آن Pool dispose می‌شود تا پلیرهای رزروشدهٔ جا‌مانده نیز آزاد شوند. Poolهای سالم صداهای دیگر دست‌نخورده‌اند. شکست مداوم ساخت native نیز حداکثر سه تلاش متوالی در چرخهٔ فعلی دارد؛ پس از آن کانال قرنطینه می‌شود تا خطای setup به ساخت نامحدود پلیر تبدیل نشود. بعد از فاصلهٔ retry یک‌ثانیه‌ای، درخواست بعدی می‌تواند Pool همان صدا را دوباره آماده کند؛ نیازی به restart کل برنامه برای این مسیر خطا نیست.

اگر خود dispose شکست بخورد، Pool قبلی نگه داشته و قرنطینه می‌شود؛ Pool تازه روی منابعی که هنوز آزاد نشده‌اند ساخته نمی‌شود. retry بعدی ابتدا دوباره آزادسازی همان Pool را امتحان می‌کند.

## ۵. ارتباط با concurrent playback و AudioPlayer مشترک

مشکلِ پیدا‌شده «نبود AudioPool» یا «یک AudioPlayer برای تمام افکت‌ها» نیست. مشکل، interaction بین focus و چرخهٔ completion، و همچنین چرخهٔ معیوب رزرو/خطای start است.

در این پیگیری، افزایش تعداد پلیرها به‌عنوان درمان استفاده نشد. mixing و بازیافت سالم مهم‌تر از افزایش ظرفیت‌اند.

## ۶. تغییرهای دقیق

| مورد | قبل از پیگیری | بعد از پیگیری |
|---|---|---|
| focus افکت‌های Android | default GAIN | NONE برای هر پلیر افکت |
| خطای start | صرفاً catch/log؛ استفادهٔ مجدد از همان Pool | علامت‌گذاری معیوب، توقف پذیرش، dispose امن و retry محدود |
| درخواست‌های start معوق | صف بدون محدودیت در lock کتابخانه | حداکثر ۳/۴/۲ Future شروعِ در حال انتظار |
| initialize هم‌زمان | امکان چند ساخت موازی برای یک صدا | single-flight سراسری و per-channel |
| شکست بارگذاری یک صدا | امکان جلوگیری از ساخت صداهای بعدی | جداسازی شکست؛ صداهای سالم آماده می‌شوند |
| معطل‌ماندن startup صوت | ممکن است game initializer منتظر بماند | بودجهٔ کلی ۳ ثانیه؛ ادامهٔ بازی با آماده‌شدن تدریجی صدا |
| timeout و ساخت native دیرهنگام | محافظ مشخصی نداشت | Future واقعی حفظ می‌شود؛ timeout مجوز ساخت جایگزین هم‌زمان نیست |
| dispose هنگام start/load | امکان تداخل | انتظار برای عملیات در جریان؛ بدون آزادسازی زیر پای start |

**سیاست فشار:** وقتی تعداد Futureهای شروعِ معوق به حد می‌رسد، درخواست اضافهٔ همان صدا اجرا نمی‌شود و در حالت تشخیص با `start_backpressure` ثبت می‌شود. صداهای در حال پخش قطع نمی‌شوند و بازی متوقف نمی‌شود. این محافظ صفِ start است، نه ادعای تعیین سقف قطعی برای active native playerها.

**سیاست recovery:** درخواستِ محرکِ بارگذاری مجدد بعداً با تأخیر پخش نمی‌شود؛ پس از آماده‌شدن Pool، درخواست بعدی صدا پخش می‌کند. این کار از پخش افکت‌های کهنه روی رویدادهای جدید جلوگیری می‌کند.

## ۷. ظرفیت‌ها و دلیل آن‌ها

| صدا | maxPlayers قبلی/فعلی | سقف جدید pending start |
|---|---:|---:|
| تاس | ۳ / ۳ | ۳ |
| حرکت | ۴ / ۴ | ۴ |
| موشک | ۲ / ۲ | ۲ |

عددهای cache افزایش نیافتند و minPlayers پیش‌فرض ۱ باقی ماند. همان بودجه‌های کوچک موجود برای محدودکردن درخواست‌های native معوق نیز استفاده شدند؛ این عددها اندازه‌گیری توان سخت‌افزار گوشی کاربر نیستند.

برای حرکت معمولی، فاصلهٔ درخواست‌ها حدود ۲۷۰ میلی‌ثانیه و طول نمونه حدود ۱۹۲ میلی‌ثانیه است. تاس و موشک نمونه‌های طولانی‌تر دارند و overlap مجاز است. capture گروهی می‌تواند burst داشته باشد؛ در فشار شدید ممکن است درخواست‌های اضافی همان افکت با سیاست بالا کنار گذاشته شوند، به جای اینکه صف نامحدود بسازند.

## ۸. چرا timer برای stop یا reset دوره‌ای اضافه نشد؟

یک نکتهٔ مهم‌تر در همان کتابخانه پیدا شد: StopFunction برگشتی از start، پلیر را با playerId پیدا می‌کند؛ شناسهٔ مستقل هر نوبت پخش ندارد. اگر یک صدا طبیعی تمام شود و پلیر دوباره استفاده شود، اجرای دیرهنگام StopFunction قدیمی می‌تواند صدای تازهٔ همان پلیر را قطع کند.

بنابراین هیچ «stop بعد از یک ثانیه»، timer دوره‌ای برای reset یا حدس مدت playback اضافه نشد. stop طبیعی همچنان بر عهدهٔ AudioPool است. فقط Poolی که واقعاً start آن خطا داده بازسازی می‌شود، نه تمام صداها به‌صورت تصادفی.

## ۹. تست‌ها و وضعیت واقعی اجرا

### اضافه/به‌روز‌شده

`audio_manager_test.dart`:

- ارسال context بدون focus مستقل فقط در Android؛ عدم تغییر iOS؛
- routing و volume معمولی؛
- ۳۰۰۰ درخواست سریع با شروع‌های معوق: انتظار حداکثر ۹ شروع native معوق، بدون انتظار caller؛
- recovery فقط صدای خراب، cooldown و عدم بازسازی مکرر؛
- انتظار تا پایان سایر startها قبل از dispose؛
- قرنطینه پس از خطای dispose؛
- initialize هم‌زمان، یک asset معیوب، dispose/restart حین بارگذاری؛
- startup معلق و بودجهٔ سه‌ثانیه‌ای؛ عدم ساخت duplicate بعد از timeout؛
- mute و عدم فعال‌شدن اتفاقی بعد از dispose.

`audio_pool_regression_test.dart`:

از **خود AudioPool/AudioPlayer نسخهٔ واقعی Dart** استفاده می‌کند؛ فقط MethodChannel/EventChannel پلتفرم شبیه‌سازی می‌شود. سه سناریو نوشته شده است:

1. تزریق focus loss بدون completion: بررسی جا‌ماندن پلیرها با وجود maxPlayers برابر ۱؛
2. context mixing، ۲۰۰ burst سه‌تایی و completion: انتظار استفادهٔ مجدد از همان سه پلیر؛
3. خطای resume بعد از رزرو: بررسی باقی‌ماندن رزرو و آزادشدنش با dispose کل Pool.

این تست‌ها، حتی در صورت موفقیت، شبیه‌سازی رفتار پلتفرم‌اند و جای تست شنیداری Android واقعی را نمی‌گیرند.

### اجرا در این محیط

- خواندن و تطبیق سورس دقیق کتابخانه و Android backend: انجام شد.
- `git diff --check`: موفق.
- تطبیق بایت‌های سه MP3، pubspec و lockfile با Git: بدون تغییر.
- تلاش برای `flutter analyze`، تست‌ها و build Android: **با کد ۱۲۷ و `flutter: command not found` متوقف شد**. دانلود SDK نیز از این محیط در دسترس نبود.
- **هیچ تست Flutter، build APK یا بازتولید واقعی روی گوشی در این پیگیری موفق اجرا نشده است.** عددهای سناریوهای تست در بالا انتظار/assertion هستند، نه نتیجهٔ اجرای تست.

فرمان‌های لازم در محیط دارای SDK:

```bash
cd apps/ludo_app
flutter pub get --enforce-lockfile
flutter analyze
flutter test test/audio_manager_test.dart test/audio_pool_regression_test.dart test/audio_assets_test.dart test/rocket_asset_test.dart
flutter run --dart-define=AUDIO_DIAGNOSTICS=true
```

## ۱۰. فایل‌های این پیگیری

- `apps/ludo_app/lib/features/game/game_engine/managers/audio_manager.dart`
- `apps/ludo_app/test/audio_manager_test.dart`
- `apps/ludo_app/test/audio_pool_regression_test.dart` — جدید
- `docs/audio-fast-playback-fa.md` — این گزارش
- `docs/audio-diagnosis-fa.md` — فقط مشخص‌کردن تاریخی‌بودن نتیجهٔ مرحلهٔ اول و لینک پیگیری

تغییرهای تاس، آنلاین و دیگر فایل‌های موجود در working tree مربوط به درخواست‌های قبلی هستند؛ در این پیگیری بازنویسی نشدند. نیازی به تغییر API سرور برای این اصلاح صوت نیست.

## ۱۱. بررسی لازم روی گوشی و محدودیت‌ها

در DevTools، لاگ `ludo.audio` را فیلتر کنید:

- `pool_create ... androidFocus=none`: تنظیم جدید واقعاً در build فعال است؛
- `start_failed` سپس `pool_disposed` و بعد `pool_ready`: مسیر خطا و recovery؛
- `start_backpressure`: backend در شروع عقب افتاده و درخواست اضافه کنار گذاشته شده؛
- `pool_dispose_failed`: آزادسازی native شکست خورده و کانال قرنطینه شده؛
- `pool_setup_quarantined`: سه ساخت متوالی شکست خورده‌اند؛ retry خودکار بیشتر انجام نمی‌شود تا lifecycle صوت صریحاً reset شود؛
- `initialize_timed_out`: آماده‌سازی دیر شده ولی شروع بازی آزاد شده است.

تاس‌های سریع، حرکت شش‌خانه‌ای، capture گروهی، ترکیب موشک/حرکت، چند بازی متوالی و background/foreground را امتحان کنید. `adb shell dumpsys audio` و `adb shell dumpsys media.player` همراه لاگ AudioFocus/MediaPlayer برای بررسی focus و روند تعداد پلیرها مفیدند. اطلاعات حساب یا tokenهای نامرتبط را از لاگ ارسالی حذف کنید.

**محدودیت‌های باقی‌مانده:**

- این کد نمی‌تواند از موفق‌بودن Futureِ start نتیجه بگیرد که خروجی واقعاً شنیده شده است. خطاهای بعدی decoder، completion یا stream ممکن است مسیر دیگری داشته باشند.
- شکست ساخت پلیر پیش از ثبت آن در Pool، محدودیت دیگری در کتابخانه است؛ dispose فقط پلیرهای قابل‌دسترسیِ Pool را آزاد می‌کند، نه یک پلیر نیمه‌ساخته که constructor اصلاً تحویل نداده است. سقف retry جلوی تکرار نامحدود این وضعیت را می‌گیرد، اما آزادسازی تمام منابع داخلی SDK در آن مسیر قابل تضمین نیست.
- یک platform call که هیچ‌وقت پاسخ ندهد با timeout لغو نمی‌شود. درخواست‌ها محدود می‌مانند و startup بازی بودجه دارد، ولی آن کانال ممکن است همچنان منتظر native بماند. dispose عمداً بازسازی هم‌زمان روی چنین عملیات لغونشده‌ای انجام نمی‌دهد.
- تعداد active playerهای کتابخانه سقف سخت تازه‌ای ندارد؛ این patch روی علتِ جا‌ماندن ناشی از focus و cleanup خطاهای start، و محدودکردن صف start تمرکز دارد. تضمین عمومی برای تمام خرابی‌های backend داده نمی‌شود.
- NONE اجازهٔ mixing با صدای دیگر برنامه‌ها را نیز می‌دهد؛ رفتار تماس، اعلان و background باید در گوشی هدف بررسی شود.
- در recovery ممکن است افکت جاریِ همان Pool خراب متوقف شود؛ Poolهای سالم تاس/حرکت/موشک متوقف نمی‌شوند.

### سورس‌های دقیق مبنا

- [AudioPool 6.7.1: رزرو، start، completion، maxPlayers و StopFunction](https://github.com/bluefireteam/audioplayers/blob/audioplayers-v6.7.1/packages/audioplayers/lib/src/audio_pool.dart)
- [Android FocusManager](https://github.com/bluefireteam/audioplayers/blob/audioplayers-v6.7.1/packages/audioplayers_android/android/src/main/kotlin/xyz/luan/audioplayers/player/FocusManager.kt)
- [Android WrappedPlayer: focus loss و pause](https://github.com/bluefireteam/audioplayers/blob/audioplayers-v6.7.1/packages/audioplayers_android/android/src/main/kotlin/xyz/luan/audioplayers/player/WrappedPlayer.kt)
- [AudioPlayer و updater](https://github.com/bluefireteam/audioplayers/blob/audioplayers-v6.7.1/packages/audioplayers/lib/src/audioplayer.dart)
- [FramePositionUpdater](https://github.com/bluefireteam/audioplayers/blob/audioplayers-v6.7.1/packages/audioplayers/lib/src/position_updater.dart)
