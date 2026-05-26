# godoMyAAC

**godoMyAAC** to darmowa aplikacja AAC (Augmentative and Alternative Communication)
napisana w Flutterze. Pomaga w komunikacji osobom, które nie posługują się mową —
przez dotykanie symboli/obrazków układanych w wypowiedzi, odczytywanych głosem (TTS)
lub własnymi nagraniami.

Aplikacja jest **darmowa, bez reklam i działa offline** — dane (profile, tablice,
symbole, nagrania) przechowywane są wyłącznie lokalnie na urządzeniu.

## Funkcje

- Profile użytkowników i własne tablice komunikacyjne (kategorie + symbole)
- Wbudowana biblioteka symboli + dodawanie własnych (galeria / aparat)
- Odczyt mowy (TTS) oraz własne nagrania głosowe dla symboli
- Konfigurowalna siatka (kolumny/wiersze), kolory, motyw jasny/ciemny
- Pełna lokalna baza danych (Isar), brak wysyłki danych na serwer

## Stos technologiczny

- Flutter + Riverpod (stan), go_router (nawigacja)
- Isar (lokalna baza), flutter_tts / record / audioplayers (mowa i dźwięk)
- Lokalizacja przez flutter_localizations + ARB

## Uruchomienie

```bash
flutter pub get
flutter run
```

Budowanie wydania (App Bundle dla Google Play):

```bash
flutter build appbundle
```

## Grafiki

Część grafik wygenerowano przy użyciu narzędzi AI (Gemini / Meta) oraz darmowych
zasobów z Canvy.

## Licencja

Aplikacja darmowa. (Określ docelową licencję kodu, np. MIT, jeśli repo ma pozostać publiczne.)
