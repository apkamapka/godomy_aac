import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/profile_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../models/library_symbol_model.dart';
import '../models/category_symbol_model.dart';

part 'isar_service.g.dart';

@Riverpod(keepAlive: true)
Future<Isar> isar(Ref ref) async {
  final dir = await getApplicationDocumentsDirectory();

  final isar = await Isar.open(
    [
      ProfileModelSchema,
      CategoryModelSchema,
      LibrarySymbolModelSchema,
      CategorySymbolModelSchema,
    ],
    directory: dir.path,
  );

  return isar;
}