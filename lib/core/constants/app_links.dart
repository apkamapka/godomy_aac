/// Zewnętrzne linki używane w aplikacji (strona autora, dokumenty prawne).
///
/// Trzymane w jednym miejscu, żeby łatwo było je podmienić bez szukania po kodzie.
class AppLinks {
  AppLinks._();

  /// Strona autora aplikacji (akApp).
  static const String website = 'https://akappstudio.pl/';

  /// Polityka prywatności (wymagana przez Google Play).
  static const String privacyPolicy =
      'https://akappstudio.pl/GodoMyAAC/polityka-prywatnosci/';

  /// Regulamin / warunki korzystania.
  static const String terms = 'https://akappstudio.pl/GodoMyAAC/regulamin/';
}
