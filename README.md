# godoMyAAC

**godoMyAAC** to darmowa aplikacja AAC (Augmentative and Alternative Communication)
napisana w Flutterze. Pomaga w komunikacji osobom, które nie posługują się mową —
przez dotykanie symboli/obrazków układanych w wypowiedzi, odczytywanych głosem (TTS)
lub własnymi nagraniami.

Aplikacja jest **darmowa, bez reklam i działa offline** — dane (profile, tablice,
symbole, nagrania) przechowywane są wyłącznie lokalnie na urządzeniu.

## Funkcje

- Tablica startowa ze **słowami kluczowymi** (chcę, nie, tak, jeszcze, pomóż…) na stałych miejscach
- **Pasek zdania** w kształcie dymka: dotykane obrazki układają się w zdanie, przycisk „Mów” czyta je
  na głos i podświetla czytane słowo
- **Pilne** – przycisk w górnym pasku z dużymi kafelkami mówionymi od razu (toaleta, boli, pić…)
- **Plan dnia** z obrazków („Teraz” / „Potem”, odhaczanie kroków)
- **Częste** – najczęściej używane słowa danego profilu
- **Moje zdania** – gotowe zdania przygotowane przez opiekuna + **historia** wypowiedzianych zdań
- **Tak / Nie** – ekran z dwoma dużymi przyciskami
- **Pokaż rozmówcy** – zdanie na cały ekran dużymi literami (z obrotem o 180°)
- **Zapis zdania jako kafelka** (kolaż obrazków)
- **Wydruk tablicy do PDF** (A4) – papierowa tablica na basen, kąpiel, wyjazd
- **Dostępność**: przytrzymanie kafelka, ignorowanie powtórnych dotknięć, **skanowanie**
  (dotyk ekranu albo przełącznik Bluetooth – spacja / Enter)
- Każdą funkcję można włączyć lub wyłączyć osobno dla każdego profilu
- **Tryb opiekuna** za kłódką – do wyboru: zadanie dla dorosłego, PIN albo przytrzymanie
- Kolory kafelków wg **klucza Fitzgeralda**, zdjęcie dziecka na kafelku „ja”
- Profile użytkowników, własne foldery i obrazki (galeria / aparat / emoji), własne nagrania głosu
- Ustawienia głosu (wybór polskiego głosu, tempo, wysokość), tryb jasny/ciemny, tablety i poziom
- Kopia zapasowa profilu do pliku ZIP; wszystko lokalnie, bez konta i bez internetu

## Stos technologiczny

- Flutter + Riverpod (stan), go_router (nawigacja), font Nunito (SIL OFL, w `assets/fonts`)
- Isar (lokalna baza), flutter_tts / record / audioplayers (mowa i dźwięk)
- Lokalizacja przez flutter_localizations + ARB

## Uruchomienie

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Budowanie wydania (App Bundle dla Google Play):

```bash
flutter build appbundle
```

## Grafiki

Część grafik wygenerowano przy użyciu narzędzi AI (Gemini / Meta) oraz darmowych
zasobów z Canvy. Obrazki „chcę”, „koniec” i „potrzebuję przerwy” pochodzą z
[Noto Emoji](https://github.com/googlefonts/noto-emoji) (Apache 2.0, licencja w
`assets/licenses`).

## Licencja

Aplikacja darmowa. (Określ docelową licencję kodu, np. MIT, jeśli repo ma pozostać publiczne.)
