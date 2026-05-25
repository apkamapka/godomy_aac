import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar/isar.dart';

part 'category_symbol_model.freezed.dart';
part 'category_symbol_model.g.dart';

@freezed
@Collection(ignore: {'copyWith'})
class CategorySymbolModel with _$CategorySymbolModel {
  const CategorySymbolModel._();

  @JsonSerializable(explicitToJson: true)
  const factory CategorySymbolModel({
    required String id,
    required String librarySymbolId,  // Link do symbolu w bibliotece
    String? categoryId,     // Do której kategorii należy

    // Overrides - jeśli null, bierze z LibrarySymbol
    String? nameOverride,             // Własna nazwa (override)
    String? imagePathOverride,        // Własny obrazek (override)
    String? emojiOverride,            // Własne emoji (override)

    required int backgroundColor,     // Kolor tła kafelka
    String? voiceRecordingPath,       // Ścieżka do nagrania głosu
    required int position,            // Pozycja w siatce
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _CategorySymbolModel;

  // Isar ID - używamy hash z String ID
  Id get isarId => fastHash(id);

  factory CategorySymbolModel.fromJson(Map<String, dynamic> json) =>
      _$CategorySymbolModelFromJson(json);
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