import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar/isar.dart';

part 'category_model.freezed.dart';
part 'category_model.g.dart';

// Enum dla trybu komunikacji z adnotacją Isar
@enumerated  // ← NAPRAWIONE: dodano @enumerated dla Isar
enum CommunicationMode {
  text,      // Dodaje do pola tekstowego, wymaga kliknięcia "Mów"
  direct,    // Natychmiast mówi po kliknięciu
  combined   // Dodaje do pola + opcja natychmiastowego wypowiedzenia
}

// Konfiguracja siatki
@embedded
class GridConfig {
  late int columns;
  late int rows;

  GridConfig({this.columns = 3, this.rows = 4});

  // Dodajemy pomocnicze metody dla json serialization
  Map<String, dynamic> toJson() => {
    'columns': columns,
    'rows': rows,
  };

  factory GridConfig.fromJson(Map<String, dynamic> json) => GridConfig(
    columns: json['columns'] as int,
    rows: json['rows'] as int,
  );
}

@freezed
@Collection(ignore: {'copyWith'})
class CategoryModel with _$CategoryModel {
  const CategoryModel._();

  @JsonSerializable(explicitToJson: true)  // ← NAPRAWIONE: dodano explicitToJson
  const factory CategoryModel({
    required String id,
    required String name,
    String? iconName,                 // Nazwa Material Icon (np. "home", "restaurant")
    String? iconPath,                 // Ścieżka do własnego obrazka/emoji
    String? emoji,                    // Emoji jako tekst (np. "🍕", "❤️")
    required int backgroundColor,     // Kolor tła jako int (hex)
    required int textColor,           // Kolor tekstu jako int (hex)
    required int iconColor,           // Kolor ikony jako int (hex)
    @enumerated  // ← NAPRAWIONE: dodano @enumerated również tutaj
    required CommunicationMode communicationMode,
    required GridConfig gridConfig,
    required bool scrollLocked,
    required int position,            // Kolejność wyświetlania
    required String profileId,        // Do którego profilu należy
    String? parentId,       // Do którego profilu należy
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _CategoryModel;

  // Isar ID - używamy hash z String ID
  Id get isarId => fastHash(id);

  factory CategoryModel.fromJson(Map<String, dynamic> json) =>
      _$CategoryModelFromJson(json);
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