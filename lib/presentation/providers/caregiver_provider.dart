import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tryb opiekuna – odblokowany kłódką. Pokazuje narzędzia edycji.
/// Trzymany tylko w pamięci: po ponownym uruchomieniu aplikacja startuje
/// zablokowana (bezpieczna dla dziecka).
final caregiverModeProvider = StateProvider<bool>((ref) => false);

/// Tryb usuwania kafelków (tylko w trybie opiekuna).
final deleteModeProvider = StateProvider<bool>((ref) => false);
