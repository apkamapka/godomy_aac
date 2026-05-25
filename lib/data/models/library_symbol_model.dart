import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar/isar.dart';

part 'library_symbol_model.freezed.dart';
part 'library_symbol_model.g.dart';

@freezed
@Collection(ignore: {'copyWith'})
class LibrarySymbolModel with _$LibrarySymbolModel {
  const LibrarySymbolModel._();

  @JsonSerializable(explicitToJson: true)
  const factory LibrarySymbolModel({
    required String id,
    required String name,
    String? imagePath,              // Ścieżka do obrazka/GIF
    String? emoji,                  // Emoji jako tekst
    @Default(null) int? backgroundColor, // ✅ DODANE: Kolor tła (jako int ARGB)
    @Default([]) List<String> tags, // Tagi do wyszukiwania
    @Default(false) bool isSystemDefault, // Czy to symbol systemowy (nie można usunąć)
    @Default(false) bool isAnimated,      // Czy to GIF
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(0) int usageCount,           // Ile razy użyty (dla sortowania)
  }) = _LibrarySymbolModel;

  // Isar ID - używamy hash z String ID
  Id get isarId => fastHash(id);

  factory LibrarySymbolModel.fromJson(Map<String, dynamic> json) =>
      _$LibrarySymbolModelFromJson(json);
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