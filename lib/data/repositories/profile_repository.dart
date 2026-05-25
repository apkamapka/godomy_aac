import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile_model.dart';
import '../services/isar_service.dart';

part 'profile_repository.g.dart';

@riverpod
Future<ProfileRepository> profileRepository(Ref ref) async {
  final isar = await ref.watch(isarProvider.future);
  return ProfileRepository(isar);
}

class ProfileRepository {
  final Isar _isar;

  ProfileRepository(this._isar);

  // CREATE
  Future<void> create(ProfileModel profile) async {
    await _isar.writeTxn(() async {
      await _isar.profileModels.put(profile);
    });
  }

  // READ - wszystkie profile
  Future<List<ProfileModel>> getAll() async {
    return await _isar.profileModels.where().findAll();
  }

  // READ - stream (live updates)
  Stream<List<ProfileModel>> watchAll() {
    return _isar.profileModels.where().watch(fireImmediately: true);
  }

  // READ - po ID
  Future<ProfileModel?> getById(String id) async {
    return await _isar.profileModels.get(fastHash(id));
  }

  // UPDATE
  Future<void> update(ProfileModel profile) async {
    await _isar.writeTxn(() async {
      await _isar.profileModels.put(profile);
    });
  }

  // DELETE
  Future<void> delete(String id) async {
    await _isar.writeTxn(() async {
      await _isar.profileModels.delete(fastHash(id));
    });
  }

  // DELETE ALL
  Future<void> deleteAll() async {
    await _isar.writeTxn(() async {
      await _isar.profileModels.clear();
    });
  }
}

/// Fast hash function
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