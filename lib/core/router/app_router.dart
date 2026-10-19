import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/screens/category_editor_screen.dart';
import '../../presentation/screens/folder_screen.dart';
import '../../presentation/screens/frequent_screen.dart';
import '../../presentation/screens/library_screen.dart';
import '../../presentation/screens/library_symbol_editor_screen.dart';
import '../../presentation/screens/partner_view_screen.dart';
import '../../presentation/screens/profile_editor_screen.dart';
import '../../presentation/screens/profiles_screen.dart';
import '../../presentation/screens/schedule_screen.dart';
import '../../presentation/screens/sentences_screen.dart';
import '../../presentation/screens/settings_screen.dart';
import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/symbol_editor_screen.dart';
import '../../presentation/screens/welcome_screen.dart';
import '../../presentation/screens/yes_no_screen.dart';

String? _param(String? value) => (value == null || value.isEmpty) ? null : value;

/// Nawigacja (zwykły Provider – bez generowania kodu).
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/profiles',
        builder: (context, state) => const ProfilesScreen(),
      ),
      GoRoute(
        path: '/profile-editor',
        builder: (context, state) => ProfileEditorScreen(
          profileId: _param(state.uri.queryParameters['id']),
          firstRun: state.uri.queryParameters['first'] == '1',
        ),
      ),

      // === Tablica i foldery ===
      GoRoute(
        path: '/folder/:profileId',
        builder: (context, state) => FolderScreen(
          key: ValueKey('board_${state.pathParameters['profileId']}'),
          profileId: state.pathParameters['profileId']!,
        ),
      ),
      GoRoute(
        path: '/folder/:profileId/c/:categoryId',
        builder: (context, state) => FolderScreen(
          key: ValueKey('board_${state.pathParameters['profileId']}_${state.pathParameters['categoryId']}'),
          profileId: state.pathParameters['profileId']!,
          categoryId: state.pathParameters['categoryId'],
        ),
      ),
      GoRoute(
        path: '/folder/:profileId/category-editor',
        builder: (context, state) => CategoryEditorScreen(
          profileId: state.pathParameters['profileId']!,
          categoryId: _param(state.uri.queryParameters['categoryId']),
          parentId: _param(state.uri.queryParameters['parentId']),
        ),
      ),
      GoRoute(
        path: '/folder/:profileId/add-symbol',
        builder: (context, state) => SymbolEditorScreen(
          profileId: state.pathParameters['profileId']!,
          categoryId: _param(state.uri.queryParameters['categoryId']),
        ),
      ),
      GoRoute(
        path: '/folder/:profileId/edit-symbol/:symbolId',
        builder: (context, state) => SymbolEditorScreen(
          profileId: state.pathParameters['profileId']!,
          symbolId: state.pathParameters['symbolId'],
        ),
      ),
      GoRoute(
        path: '/folder/:profileId/frequent',
        builder: (context, state) => FrequentScreen(profileId: state.pathParameters['profileId']!),
      ),
      GoRoute(
        path: '/folder/:profileId/schedule',
        builder: (context, state) => ScheduleScreen(profileId: state.pathParameters['profileId']!),
      ),
      GoRoute(
        path: '/folder/:profileId/yes-no',
        builder: (context, state) => YesNoScreen(profileId: state.pathParameters['profileId']!),
      ),
      GoRoute(
        path: '/folder/:profileId/sentences',
        builder: (context, state) => SentencesScreen(profileId: state.pathParameters['profileId']!),
      ),
      GoRoute(
        path: '/folder/:profileId/show',
        builder: (context, state) => PartnerViewScreen(profileId: state.pathParameters['profileId']!),
      ),
      GoRoute(
        path: '/folder/:profileId/settings',
        builder: (context, state) => SettingsScreen(profileId: state.pathParameters['profileId']!),
      ),

      // === Biblioteka ===
      GoRoute(
        path: '/library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/library/add',
        builder: (context, state) => const LibrarySymbolEditorScreen(),
      ),
      GoRoute(
        path: '/library/edit/:symbolId',
        builder: (context, state) => LibrarySymbolEditorScreen(symbolId: state.pathParameters['symbolId']),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
