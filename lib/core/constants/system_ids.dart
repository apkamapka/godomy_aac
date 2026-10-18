/// Specjalne identyfikatory używane w bazie bez zmiany schematu Isar.
///
/// * Tablice systemowe (słowa kluczowe, Pilne, Plan dnia) to zwykłe kategorie,
///   których `parentId` ma wartość-znacznik – dzięki temu nie pokazują się
///   jako foldery na żadnej tablicy, a ich symbole edytuje się tak samo jak
///   w każdym folderze.
/// * Symbole leżące bezpośrednio na tablicy startowej mają `categoryId`
///   ustawione na `root:<id profilu>` (wcześniej było to `null`, przez co
///   symbole z tablicy startowej były wspólne dla wszystkich profili).
class SystemIds {
  SystemIds._();

  static const coreParent = '__core__';
  static const urgentParent = '__urgent__';
  static const scheduleParent = '__schedule__';

  static const _rootPrefix = 'root:';

  /// Czy `parentId` oznacza tablicę systemową.
  static bool isSystemParent(String? parentId) =>
      parentId == coreParent || parentId == urgentParent || parentId == scheduleParent;

  /// `categoryId` symboli leżących na tablicy startowej danego profilu.
  static String rootOf(String profileId) => '$_rootPrefix$profileId';

  static bool isRoot(String? categoryId) => categoryId != null && categoryId.startsWith(_rootPrefix);

  /// Id profilu z `root:<id>` (albo null).
  static String? profileOfRoot(String? categoryId) =>
      isRoot(categoryId) ? categoryId!.substring(_rootPrefix.length) : null;
}
