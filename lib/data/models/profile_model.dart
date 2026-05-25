import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar/isar.dart';

part 'profile_model.freezed.dart';
part 'profile_model.g.dart';

@freezed
@Collection(ignore: {'copyWith'})
class ProfileModel with _$ProfileModel {
  const ProfileModel._();

  const factory ProfileModel({
    required String id,
    required String name,
    String? photoPath,

    // ✅ NOWE: Ustawienia TTS
    @Default('pl-PL') String ttsLanguage,
    String? ttsVoiceId,
    @Default(0.5) double ttsRate,      // 0.0 - 1.0 (wolniej - szybciej)
    @Default(1.0) double ttsPitch,     // 0.5 - 2.0 (niżej - wyżej)
    @Default(1.0) double ttsVolume,    // 0.0 - 1.0 (ciszej - głośniej)

    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ProfileModel;

  // Isar ID - używamy hash z String ID
  Id get isarId => fastHash(id);

  factory ProfileModel.fromJson(Map<String, dynamic> json) =>
      _$ProfileModelFromJson(json);
}

/// Fast hash function dla String -> int (Isar ID)
int fastHash(String string) {
  var hash = 0xcbf29ce484222325;
  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }
  return hash;
}