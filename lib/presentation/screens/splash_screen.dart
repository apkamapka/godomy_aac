import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/category_symbol_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/services/app_settings.dart';
import '../../data/services/migration_service.dart';

/// Start bez sztucznego czekania: od razu otwiera tablicę ostatniego
/// profilu (albo powitanie / wybór profilu).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    String target = '/profiles';
    try {
      final profileRepo = await ref.read(profileRepositoryProvider.future);
      final symbolRepo = await ref.read(categorySymbolRepositoryProvider.future);
      await MigrationService.run(profiles: profileRepo, symbols: symbolRepo);

      final profiles = await profileRepo.getAll();
      final settings = ref.read(appSettingsProvider);

      if (profiles.isEmpty) {
        target = settings.onboardingDone ? '/profiles' : '/welcome';
      } else {
        final lastId = settings.lastProfileId;
        final hasLast = lastId != null && profiles.any((p) => p.id == lastId);
        if (hasLast) {
          target = '/folder/$lastId';
        } else if (profiles.length == 1) {
          target = '/folder/${profiles.first.id}';
        }
      }
    } catch (_) {
      target = '/profiles';
    }
    if (mounted) context.go(target);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 120,
          height: 120,
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: ClipOval(child: Image.asset('assets/images/app_icon.png', fit: BoxFit.cover)),
        ),
      ),
    );
  }
}
