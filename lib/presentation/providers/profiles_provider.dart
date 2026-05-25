import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/profile_repository.dart';

part 'profiles_provider.g.dart';

// Stream provider - automatyczne updates z Isar
@riverpod
Stream<List<ProfileModel>> profiles(Ref ref) async* {
  final repository = await ref.watch(profileRepositoryProvider.future);
  yield* repository.watchAll();
}

// Selected profile provider
@riverpod
class SelectedProfile extends _$SelectedProfile {
  @override
  ProfileModel? build() => null;

  void select(ProfileModel profile) {
    state = profile;
  }

  void clear() {
    state = null;
  }
}