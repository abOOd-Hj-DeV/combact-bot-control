# Firmware — ESP32

فريم وير الروبوت: SoftAP + UDP، بروتوكول 5 قنوات، mixer للعجلتين، failsafe.

## الإعداد | Configuration

كل ما تحتاج تعديله في **`src/config.h`**:

| الإعداد | الافتراضي | الوصف |
|---|---|---|
| `WIFI_SSID` / `WIFI_PASSWORD` | `COMBACT-BOT` / `combact123` | الشبكة وكلمة السر — **غيّرها قبل المسابقة** |
| `WIFI_CHANNEL` | `6` | اختر الأفرغ من 1/6/11 بمكان المسابقة |
| `FAILSAFE_TIMEOUT_MS` | `300` | مهلة القطع بالمللي ثانية (< 5000 حسب القانون) |
| `DRIVE_DRIVER` | `DRIVER_L298N` | `DRIVER_L298N` أو `DRIVER_BTS7960` |
| أرجل المحركات | — | راجع الجدول تحت |
| `WEAPON_SINGLE_DIRECTION` | `0` | `1` إذا المطرقة باتجاه واحد فقط |
| `PIN_BATT_ADC` | `34` | قياس جهد البطارية (`-1` للتعطيل) |
| `DRIVE_DEADBAND` | `40` | منطقة ميتة حول الصفر |
| `SLEW_LIMIT` | `0` | 0 = بدون تحديد؛ رفع التدرّج لكل رزمة |

## التمديد الافتراضي | Default wiring (38-pin DevKit)

| الوظيفة | الأرجل |
|---|---|
| محرك يسار (L298N) | IN1=26, IN2=27, ENA=25 (PWM) |
| محرك يمين (L298N) | IN3=14, IN4=12, ENB=33 (PWM) |
| المطرقة (BTS7960) | RPWM=18, LPWM=19, R_EN=5, L_EN=17 |
| مقسوم جهد البطارية | GPIO34 — 10k أعلى / 3.3k أسفل |
| LED الحالة | GPIO2 (المدمجة) |

إذا كان درايفرك BTS7960 للقيادة بدل L298N غيّر `DRIVE_DRIVER` والأرجل في `config.h`.

## البناء والحرق | Build & flash

```bash
pio run -e esp32dev            # build
pio run -e esp32dev -t upload  # flash
pio device monitor             # سيريال @115200
```

## الاختبارات | Tests

الوحدات المنطقية (بروتوكول/mixer/failsafe) تعمل على المضيف مباشرة:

```bash
g++ -std=c++17 -Wall -Wextra -I src \
    test/host_tests.cpp src/protocol.cpp src/mixer.cpp -o /tmp/host_tests && /tmp/host_tests
```

## القنوات | Channels

| # | الوظيفة | المدى |
|---|---|---|
| 0 | Throttle (أمام/خلف) | ‑1000..1000 |
| 1 | Steering (يمين/يسار) | ‑1000..1000 |
| 2 | Hammer | ‑1000..1000 (يحتاج ARM) |
| 3 | Aux1 | ‑1000..1000 (احتياطي) |
| 4 | Aux2 | ‑1000..1000 (احتياطي) |

Flags: `ARMED` (تفعيل السلاح)، `INVERT` (قيادة مقلوبة)، `LOW_SPEED` (وضع دقة 40%).
