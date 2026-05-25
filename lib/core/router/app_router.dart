import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/profiles_screen.dart';
import '../../presentation/screens/profile_editor_screen.dart';
import '../../presentation/screens/folder_screen.dart';
import '../../presentation/screens/category_editor_screen.dart';
import '../../presentation/screens/add_symbol_screen.dart';
import '../../presentation/screens/edit_symbol_screen.dart';
import '../../presentation/screens/library_screen.dart';
import '../../presentation/screens/library_add_symbol_screen.dart';
import '../../presentation/screens/library_edit_symbol_screen.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      // Splash Screen
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Profiles Screen
      GoRoute(
        path: '/profiles',
        name: 'profiles',
        builder: (context, state) => const ProfilesScreen(),
      ),

      // Profile Editor Screen
      GoRoute(
        path: '/profile-editor',
        name: 'profile-editor',
        builder: (context, state) {
          final profileId = state.uri.queryParameters['id'];
          return ProfileEditorScreen(profileId: profileId);
        },
      ),

      // === FOLDER ROUTES (nowa hierarchia) ===

      // Folder Screen - root level
      GoRoute(
        path: '/folder/:profileId',
        name: 'folder',
        builder: (context, state) {
          final profileId = state.pathParameters['profileId'];
          if (profileId == null) {
            return const Scaffold(
              body: Center(child: Text('Brak ID profilu')),
            );
          }
          return FolderScreen(
            profileId: profileId,
            categoryId: null,
          );
        },
      ),

      // Folder Screen - inside category
      GoRoute(
        path: '/folder/:profileId/c/:categoryId',
        name: 'folder-category',
        builder: (context, state) {
          final profileId = state.pathParameters['profileId'];
          final categoryId = state.pathParameters['categoryId'];
          if (profileId == null) {
            return const Scaffold(
              body: Center(child: Text('Brak ID profilu')),
            );
          }
          return FolderScreen(
            profileId: profileId,
            categoryId: categoryId,
          );
        },
      ),

      // Category Editor - create/edit
      GoRoute(
        path: '/folder/:profileId/category-editor',
        name: 'folder-category-editor',
        builder: (context, state) {
          final profileId = state.pathParameters['profileId'];
          final categoryId = state.uri.queryParameters['categoryId']; // edit mode
          final parentId = state.uri.queryParameters['parentId']; // for new subcategory

          if (profileId == null) {
            return const Scaffold(
              body: Center(child: Text('Brak ID profilu')),
            );
          }

          return CategoryEditorScreen(
            profileId: profileId,
            categoryId: categoryId,
            parentId: parentId,
          );
        },
      ),

      // Add Symbol
      GoRoute(
        path: '/folder/:profileId/add-symbol',
        name: 'folder-add-symbol',
        builder: (context, state) {
          final profileId = state.pathParameters['profileId'];
          final categoryId = state.uri.queryParameters['categoryId']; // null = root

          if (profileId == null) {
            return const Scaffold(
              body: Center(child: Text('Brak ID profilu')),
            );
          }

          return AddSymbolScreen(
            profileId: profileId,
            categoryId: categoryId,
          );
        },
      ),

      // Edit Symbol
      GoRoute(
        path: '/folder/:profileId/edit-symbol/:symbolId',
        name: 'folder-edit-symbol',
        builder: (context, state) {
          final profileId = state.pathParameters['profileId'];
          final symbolId = state.pathParameters['symbolId'];
          final categoryId = state.uri.queryParameters['categoryId'];

          if (profileId == null || symbolId == null) {
            return const Scaffold(
              body: Center(child: Text('Brak wymaganych parametrów')),
            );
          }

          return EditSymbolScreen(
            profileId: profileId,
            categoryId: categoryId,
            symbolId: symbolId,
          );
        },
      ),

      // === LIBRARY ROUTES (bez zmian) ===

      GoRoute(
        path: '/library',
        name: 'library',
        builder: (context, state) => const LibraryScreen(),
      ),

      GoRoute(
        path: '/library/add',
        name: 'library-add-symbol',
        builder: (context, state) => const LibraryAddSymbolScreen(),
      ),

      GoRoute(
        path: '/library/edit/:symbolId',
        name: 'library-edit-symbol',
        builder: (context, state) {
          final symbolId = state.pathParameters['symbolId'];
          if (symbolId == null) {
            return const Scaffold(
              body: Center(child: Text('Brak ID symbolu')),
            );
          }
          return LibraryEditSymbolScreen(symbolId: symbolId);
        },
      ),
    ],
  );
}