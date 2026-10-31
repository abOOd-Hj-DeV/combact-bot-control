# Combact Bot Control

نظام تحكم لاسلكي لروبوت قتالي بعجلتين + مطرقة، عبر WiFi مباشرة بين موبايل أندرويد وESP32 — بدون راوتر وبدون جهاز راديو.

WiFi-based combat robot controller: an Android phone talks directly to an ESP32 running its own access point. 5 channels, ~50 Hz UDP link, sub-second failsafe.

## البنية | Architecture

```
Android app (Flutter)  ──UDP @ 50Hz──►  ESP32 (SoftAP + Arduino/C++)
        ◄──telemetry @ 5Hz──                  ├── H-bridge ── محرك يسار
                                              ├── H-bridge ── محرك يمين
                                              └── H-bridge ── محرك المطرقة
```

- **`firmware/`** — فريم وير الـ ESP32 (PlatformIO, Arduino C++). الشبكة، البروتوكول، الـ mixer، الـ failsafe، التليمتري.
- **`app/`** — تطبيق التحكم Flutter: جويستيك للقيادة، سلايدر + زر FIRE للمطرقة، مفتاح ARM، شاشة تليمتري.

## البروتوكول | Protocol

### رزمة التحكم (موبايل ← روبوت)، 18 بايت

| الحقل | الحجم | الوصف |
|---|---|---|
| magic `"RC"` | 2 | تعريف الرزمة |
| version | 1 | رقم البروتوكول (1) |
| flags | 1 | bit0=ARM، bit1=INVERT، bit2=LOW_SPEED |
| seq | 2 | رقم تسلسلي — الرزم القديمة تُرفض |
| ch[5] | 10 | خمس قنوات int16 (‑1000..1000): throttle، steer، hammer، aux1، aux2 |
| crc16 | 2 | CRC-16/CCITT-FALSE |

### رزمة التليمتري (روبوت ← موبايل)، 16 بايت

flags (linked/armed/failsafe) + آخر seq + جهد البطارية mV + RSSI + معدل الاستقبال Hz + عدد الرزم الضائعة + CRC16.

## الأمان | Failsafe

- توقف كامل للمحركات والمطرقة بعد **300ms** بلا رزم صالحة — أقسى من قانون المسابقة (5 ثواني) وقابل للتعديل بـ `FAILSAFE_TIMEOUT_MS` في `firmware/src/config.h`.
- المطرقة لا تشتغل إلا بشرطين معاً: اتصال حي **و** مفتاح ARM مفعّل. عند عودة الاتصال بعد failsafe تبقى المطرقة مطفأة حتى إعادة التسليح.
- كل المخارج على صفر عند الإقلاع، وWatchdog يعيد تشغيل المتحكم إذا علق.
- LED الحالة: ثابت = متصل، وميض سريع = failsafe.

## التشغيل السريع | Quick start

```bash
# 1) الفريم وير — عدّل الأرجل في firmware/src/config.h حسب تمديدك
cd firmware && pio run -e esp32dev -t upload

# 2) التطبيق — ثبّته على الموبايل
cd app && flutter build apk --release
# التطبيق build/app/outputs/flutter-apk/app-release.apk

# 3) على الموبايل: اتصل بشبكة COMBACT-BOT (كلمة السر في config.h) وافتح التطبيق
```

## ملاحظات ميدانية | Field notes

- **القناة اللاسلكية:** افحص الشبكات بمكان المسابقة وثبّت `WIFI_CHANNEL` على الأفرغ (1/6/11).
- **الهوائي:** إذا جسم الروبوت معدن استخدم لوحة بمنفذ هوائي خارجي (u.FL) وأخرج الهوائي خارج الجسم.
- **التشويش الكهربائي:** منظّم جهد منفصل للـ ESP32، مكثفات على المحركات، أرضي مشترك.
- **الأداء المتوقع:** تأخير بحدود 5–15ms على 2.4GHz نظيف؛ يُقاس فعلياً عبر Rx rate والـ lost بالتليمتري.
