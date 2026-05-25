import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_layout_grid/flutter_layout_grid.dart';
import '../../core/l10n/app_localizations.dart';
import '../../data/models/category_model.dart';
import '../../data/models/category_symbol_model.dart';
import '../../data/models/library_symbol_model.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/category_symbol_repository.dart';
import '../../data/repositories/library_symbol_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/services/default_categories_service.dart';
import '../../data/services/default_symbols_service.dart';
import '../../data/services/tts_service.dart';
import '../../data/services/audio_player_service.dart';
import '../providers/folder_content_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/message_provider.dart';
import '../providers/symbols_grid_config_provider.dart';
import '../widgets/message_container.dart';
import '../widgets/gaze_indicator.dart';
import '../widgets/calibration_overlay.dart';
import '../widgets/dwell_detector.dart';
import '../providers/eye_tracking_provider.dart';
import '../widgets/grid_config_dialog.dart';
import '../../data/services/eye_tracking_service.dart';

class FolderScreen extends ConsumerStatefulWidget {
  final String profileId;
  final String? categoryId;

  const FolderScreen({
    super.key,
    required this.profileId,
    this.categoryId,
  });

  @override
  ConsumerState<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends ConsumerState<FolderScreen> {
  ProfileModel? _profile;
  CategoryModel? _currentCategory;
  bool _isLoading = true;
  bool _isMenuCollapsed = true;
  bool _deleteMode = false;
  bool _showCalibration = false;
  bool _isActivatingEyeTracking = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(FolderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    try {
      final profileRepo = await ref.read(profileRepositoryProvider.future);
      final profile = await profileRepo.getById(widget.profileId);

      CategoryModel? category;
      if (widget.categoryId != null) {
        final categoryRepo = await ref.read(categoryRepositoryProvider.future);
        category = await categoryRepo.getById(widget.categoryId!);
      }

      if (profile != null) {
        if (mounted) {
          setState(() {
            _profile = profile;
            _currentCategory = category;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          context.go('/profiles');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd ładowania: $e')),
        );
        context.go('/profiles');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_profile == null) {
      return const Scaffold(
        body: Center(child: Text('Profil nie znaleziony')),
      );
    }

    final contentAsync = ref.watch(folderContentProvider(widget.profileId, widget.categoryId));
    final keyboardVisible = ref.watch(messageContainerVisibleProvider);

    // Określ kolor tła chmurki
    final headerColor = _currentCategory != null
        ? Color(_currentCategory!.backgroundColor)
        : const Color(0xFF42A5F5);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: isDark ? null : const Color(0xFFE3F2FD),
          appBar: AppBar(
            toolbarHeight: 46,
            title: const SizedBox.shrink(),
            leading: widget.categoryId != null
                ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            )
                : Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, size: 28),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            actions: [
              if (widget.categoryId == null)
                IconButton(
                  icon: const Icon(Icons.person, size: 28),
                  onPressed: () => context.go('/profiles'),
                ),
            ],
          ),
          drawer: widget.categoryId == null ? _buildDrawer(context, l10n) : null,
          body: SafeArea(
            bottom: true,
            child: Column(
              children: [
                // Breadcrumbs NAD chmurką
                if (widget.categoryId != null) _buildBreadcrumbs(context),

                // Cloud Header
                _buildCloudHeader(context, l10n, headerColor, keyboardVisible),

                // Content Grid
                Expanded(
                  child: contentAsync.when(
                    data: (content) {
                      if (content.isEmpty) {
                        return _buildEmptyState(context, l10n);
                      }
                      return _buildGrid(context, content, keyboardVisible);
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(
                      child: Text(l10n.error(error.toString())),
                    ),
                  ),
                ),

                // Message Container (klawiatura)
                const MessageContainer(),
              ],
            ),
          ),
        ),
        // Gaze indicator overlay
        const GazeIndicator(),
        // Calibration overlay - MUSI BYĆ NA KOŃCU (na wierzchu)
        if (_showCalibration)
          CalibrationOverlay(
            onComplete: () {
              setState(() => _showCalibration = false);
            },
            onCancel: () {
              setState(() => _showCalibration = false);
              ref.read(isCalibrationActiveProvider.notifier).stop();
              ref.read(eyeTrackingEnabledProvider.notifier).disable();
            },
          ),
      ],
    );
  }

  // ========== CLOUD HEADER ==========

  Widget _buildCloudHeader(
      BuildContext context,
      AppLocalizations l10n,
      Color backgroundColor,
      bool keyboardVisible,
      ) {
    final hsl = HSLColor.fromColor(backgroundColor);
    final cloudColor = hsl.withLightness((hsl.lightness + 0.85) / 2).toColor();
    final textColor = hsl.withLightness(0.25).withSaturation(0.8).toColor();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Chmurka z przyciskami
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: _isMenuCollapsed ? 0 : 140,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(), // wymagane dla clipBehavior
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isMenuCollapsed ? 0 : 1,
            child: _isMenuCollapsed
                ? const SizedBox.shrink()
                : Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: cloudColor,
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: backgroundColor.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: backgroundColor.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tytuł
                  Text(
                    _currentCategory?.name ?? _profile!.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Przyciski
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Dodaj
                      _buildCircleButton(
                        imagePath: 'assets/ui_icons/klawiszdodaj.png',
                        onTap: () => _showAddDialog(context, l10n),
                        size: 39,
                      ),
                      const SizedBox(width: 16),

                      // Usuń (toggle)
                      _buildCircleButton(
                        imagePath: 'assets/ui_icons/klawiszusun.png',
                        onTap: () => setState(() => _deleteMode = !_deleteMode),
                        size: 39,
                        isActive: _deleteMode,
                      ),
                      const SizedBox(width: 16),

                      // Siatka
                      _buildCircleButton(
                        imagePath: 'assets/ui_icons/klawiszsiatka.png',
                        onTap: () => _showGridConfigDialog(context),
                        size: 39,
                      ),
                      const SizedBox(width: 16),

                      // Klawiatura
                      _buildCircleButton(
                        imagePath: 'assets/ui_icons/klawiszklawiatura.png',
                        onTap: () => ref.read(messageContainerVisibleProvider.notifier).toggle(),
                        size: 39,
                        isActive: keyboardVisible,
                      ),
                      const SizedBox(width: 16),

                      // Kolejność
                      _buildCircleButton(
                        imagePath: 'assets/ui_icons/klawiszkolejnosc.png',
                        onTap: () => _showReorderSheet(context),
                        size: 39,
                      ),
                      const SizedBox(width: 16),

                      // Eye Tracking
                      Consumer(
                        builder: (context, ref, child) {
                          final isEnabled = ref.watch(eyeTrackingEnabledProvider);
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              _buildCircleButton(
                                imagePath: isEnabled
                                    ? 'assets/ui_icons/eye_on.png'
                                    : 'assets/ui_icons/eye_off.png',
                                onTap: () => _handleEyeTrackingButtonPress(),
                                size: 39,
                                isActive: isEnabled,
                              ),
                              if (_isActivatingEyeTracking)
                                SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Strzałka zwijania
        GestureDetector(
          onTap: () => setState(() => _isMenuCollapsed = !_isMenuCollapsed),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: Image.asset(
              _isMenuCollapsed
                  ? 'assets/ui_icons/klawiszdol.png'
                  : 'assets/ui_icons/klawiszgora.png',
              width: 32,
              height: 32,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required String imagePath,
    required VoidCallback onTap,
    required double size,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          border: isActive ? Border.all(color: Colors.white, width: 3) : null,
        ),
        child: ClipOval(
          child: Image.asset(imagePath, fit: BoxFit.cover),
        ),
      ),
    );
  }

  // ========== EYE TRACKING ==========

  Future<void> _toggleEyeTracking() async {
    final notifier = ref.read(eyeTrackingEnabledProvider.notifier);
    final isCurrentlyEnabled = ref.read(eyeTrackingEnabledProvider);

    if (isCurrentlyEnabled) {
      // Wyłącz
      await notifier.disable();
    } else {
      // Włącz i pokaż kalibrację
      final result = await notifier.enable();
      if (result.success && mounted) {
        setState(() {
          _showCalibration = true;
          _isMenuCollapsed = true;
        });
      } else if (mounted) {
        // Pokaż odpowiedni komunikat błędu
        String message;
        switch (result.error) {
          case EyeTrackingError.noInternet:
            message = 'Brak połączenia z internetem. Eye tracking wymaga internetu do aktywacji.';
            break;
          case EyeTrackingError.noPermission:
            message = 'Brak uprawnień do kamery. Włącz uprawnienia w ustawieniach.';
            break;
          case EyeTrackingError.expiredKey:
            message = 'Licencja eye tracking wygasła. Skontaktuj się z deweloperem.';
            break;
          case EyeTrackingError.invalidKey:
            message = 'Nieprawidłowy klucz licencji eye tracking.';
            break;
          default:
            message = 'Nie udało się włączyć eye tracking. Spróbuj ponownie.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _handleEyeTrackingButtonPress() async {
    // Uruchom efekt wizualny
    setState(() => _isActivatingEyeTracking = true);

    // Równolegle uruchom normalną aktywację eye tracking
    _toggleEyeTracking();

    // Po 5 sekundach wyłącz efekt wizualny
    await Future.delayed(const Duration(seconds: 5));
    if (mounted) {
      setState(() => _isActivatingEyeTracking = false);
    }
  }

  // ========== BREADCRUMBS ==========

  Widget _buildBreadcrumbs(BuildContext context) {
    final breadcrumbsAsync = ref.watch(categoryBreadcrumbsProvider(widget.categoryId));

    return breadcrumbsAsync.when(
      data: (breadcrumbs) {
        if (breadcrumbs.isEmpty) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? Colors.grey[800] : const Color(0xFFE3F2FD),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    // Wróć do root
                    while (context.canPop()) {
                      context.pop();
                    }
                  },
                  child: const Icon(Icons.home, size: 20, color: Colors.blue),
                ),
                ...breadcrumbs.map((category) {
                  final isLast = category == breadcrumbs.last;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                      ),
                      GestureDetector(
                        onTap: isLast ? null : () => context.pop(),
                        child: Text(
                          category.name,
                          style: TextStyle(
                            color: isLast
                                ? (isDark ? Colors.white : Colors.black87)
                                : Colors.blue,
                            fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ========== GRID ==========

  Widget _buildGrid(BuildContext context, FolderContent content, bool keyboardVisible) {
    // Pobierz konfigurację siatki
    final gridConfigs = ref.watch(symbolsGridConfigsProvider);
    final defaultConfig = _currentCategory?.gridConfig ?? GridConfig(columns: 3, rows: 3);
    final categoryId = widget.categoryId ?? 'root_${widget.profileId}';

    final gridConfig = gridConfigs[categoryId] ?? SymbolsGridConfig(
      columns: defaultConfig.columns,
      rows: defaultConfig.rows,
    );

    final columns = gridConfig.columns;
    final rows = gridConfig.rows;
    final totalCells = columns * rows;

    // Połącz kategorie i symbole i posortuj po pozycji
    final items = <dynamic>[...content.categories, ...content.symbols];

    print('📊 === PRZED SORTOWANIEM ===');
    for (var item in items) {
      if (item is CategoryModel) {
        print('📁 ${item.name}: position=${item.position}');
      } else if (item is CategorySymbolModel) {
        print('🖼️ ${item.nameOverride ?? item.id}: position=${item.position}');
      }
    }

    items.sort((a, b) {
      final posA = a is CategoryModel ? a.position : (a as CategorySymbolModel).position;
      final posB = b is CategoryModel ? b.position : (b as CategorySymbolModel).position;
      return posA.compareTo(posB);
    });

    print('📊 === PO SORTOWANIU ===');
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is CategoryModel) {
        print('[$i] 📁 ${item.name}: position=${item.position}');
      } else if (item is CategorySymbolModel) {
        print('[$i] 🖼️ ${item.nameOverride ?? item.id}: position=${item.position}');
      }
    }

    // Sprawdź czy scroll jest zablokowany (dla kategorii)
    final scrollLocked = _currentCategory?.scrollLocked ?? false;
    final displayItems = scrollLocked ? items.take(totalCells).toList() : items;

    // Buduj komórki
    final allCells = <Widget>[];

    if (scrollLocked) {
      // Tryb bez scrolla - wypełnij pustymi komórkami
      for (int i = 0; i < totalCells; i++) {
        if (i < displayItems.length) {
          allCells.add(_buildItemCard(context, displayItems[i]));
        } else {
          allCells.add(_buildEmptyCell());
        }
      }

      return Padding(
        padding: EdgeInsets.only(
          left: 4,
          right: 4,
          top: 4,
          bottom: keyboardVisible ? 200 : 4,
        ),
        child: LayoutGrid(
          columnSizes: List.filled(columns, 1.fr),
          rowSizes: List.filled(rows, 1.fr),
          columnGap: 4,
          rowGap: 4,
          children: allCells,
        ),
      );
    } else {
      // Tryb ze scrollem
      final totalRows = (displayItems.length / columns).ceil();
      final totalCellsWithScroll = totalRows * columns;

      for (int i = 0; i < totalCellsWithScroll; i++) {
        if (i < displayItems.length) {
          allCells.add(_buildItemCard(context, displayItems[i]));
        } else {
          allCells.add(_buildEmptyCell());
        }
      }

      final screenHeight = MediaQuery.of(context).size.height;
      final availableHeight = screenHeight -
          MediaQuery.of(context).padding.top -
          kToolbarHeight -
          60 -
          180;
      final minRowHeight = availableHeight / rows;

      return SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 4,
          right: 4,
          top: 4,
          bottom: keyboardVisible ? 200 : 4,
        ),
        child: LayoutGrid(
          columnSizes: List.filled(columns, 1.fr),
          rowSizes: List.filled(totalRows > 0 ? totalRows : 1, minRowHeight.px),
          columnGap: 4,
          rowGap: 4,
          children: allCells,
        ),
      );
    }
  }

  Widget _buildEmptyCell() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, dynamic item) {
    if (item is CategoryModel) {
      return _buildCategoryCard(context, item);
    } else if (item is CategorySymbolModel) {
      return _buildSymbolCard(context, item);
    }
    return const SizedBox.shrink();
  }

  // ========== CATEGORY CARD ==========

  Widget _buildCategoryCard(BuildContext context, CategoryModel category) {
    final itemKey = GlobalKey();

    final card = GestureDetector(
      onTap: _deleteMode
          ? () => _confirmDeleteCategory(context, category)
          : () => context.push('/folder/${widget.profileId}/c/${category.id}'),
      onLongPress: () => _showCategoryMenu(context, category),
      child: Container(
        key: itemKey,
        decoration: BoxDecoration(
          color: Color(category.backgroundColor),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 5,
                    child: Center(child: _buildCategoryIcon(category)),
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(category.textColor),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Folder badge
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.folder, size: 16, color: Color(category.iconColor)),
              ),
            ),
            // Delete badge
            if (_deleteMode)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );

    // Obuduj w DwellDetector jeśli nie jesteśmy w trybie usuwania
    if (_deleteMode) {
      return card;
    }

    return DwellDetector(
      itemKey: itemKey,
      onDwellComplete: () {
        context.push('/folder/${widget.profileId}/c/${category.id}');
      },
      child: card,
    );
  }

  Widget _buildCategoryIcon(CategoryModel category) {
    Widget iconWidget;
    if (category.iconPath != null && category.iconPath!.isNotEmpty) {
      final file = File(category.iconPath!);
      if (file.existsSync()) {
        iconWidget = Image.file(file, fit: BoxFit.contain);
      } else {
        iconWidget = Icon(Icons.folder, size: 200, color: Color(category.iconColor));
      }
    } else if (category.emoji != null && category.emoji!.isNotEmpty) {
      iconWidget = Text(category.emoji!, style: const TextStyle(fontSize: 200));
    } else {
      iconWidget = Icon(Icons.folder, size: 200, color: Color(category.iconColor));
    }
    return FittedBox(
      fit: BoxFit.contain,
      child: Padding(padding: const EdgeInsets.all(4.0), child: iconWidget),
    );
  }

  // ========== SYMBOL CARD ==========

  Widget _buildSymbolCard(BuildContext context, CategorySymbolModel symbol) {
    final librarySymbolAsync = ref.watch(_librarySymbolProvider(symbol.librarySymbolId));
    final itemKey = GlobalKey();

    return librarySymbolAsync.when(
      data: (librarySymbol) {
        if (librarySymbol == null) return const SizedBox.shrink();

        final name = symbol.nameOverride ?? librarySymbol.name;
        final emoji = symbol.emojiOverride ?? librarySymbol.emoji;
        final imagePath = symbol.imagePathOverride ?? librarySymbol.imagePath;

        final card = GestureDetector(
          onTap: _deleteMode
              ? () => _confirmDeleteSymbol(context, symbol, name)
              : () => _handleSymbolTap(symbol, librarySymbol),
          onLongPress: () => _showSymbolInfo(context, symbol, librarySymbol),
          child: Container(
            key: itemKey,
            decoration: BoxDecoration(
              color: Color(symbol.backgroundColor),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withOpacity(0.1), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Center(child: _buildSymbolIcon(emoji, imagePath)),
                      ),
                      const SizedBox(height: 2),
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Voice recording indicator
                if (symbol.voiceRecordingPath != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mic, size: 12, color: Colors.white),
                    ),
                  ),
                // Delete badge
                if (_deleteMode)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        );

        // Obuduj w DwellDetector jeśli nie jesteśmy w trybie usuwania
        if (_deleteMode) {
          return card;
        }

        return DwellDetector(
          itemKey: itemKey,
          onDwellComplete: () => _handleSymbolTap(symbol, librarySymbol),
          child: card,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSymbolIcon(String? emoji, String? imagePath) {
    Widget iconWidget;
    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.startsWith('assets/')) {
        iconWidget = Image.asset(imagePath, fit: BoxFit.contain);
      } else {
        final file = File(imagePath);
        if (file.existsSync()) {
          iconWidget = Image.file(file, fit: BoxFit.contain);
        } else {
          iconWidget = const Icon(Icons.image, size: 64, color: Colors.grey);
        }
      }
    } else if (emoji != null && emoji.isNotEmpty) {
      iconWidget = FittedBox(
        fit: BoxFit.contain,
        child: Text(emoji, style: const TextStyle(fontSize: 64)),
      );
    } else {
      iconWidget = const Icon(Icons.image, size: 64, color: Colors.grey);
    }
    return Padding(padding: const EdgeInsets.all(4.0), child: iconWidget);
  }

  // ========== SYMBOL TAP - TTS/AUDIO ==========

  void _handleSymbolTap(CategorySymbolModel categorySymbol, LibrarySymbolModel librarySymbol) async {
    // 1. Dodaj symbol do message container
    final messageSymbol = MessageSymbol.fromCategorySymbol(categorySymbol, librarySymbol);
    ref.read(messageSymbolsProvider.notifier).add(messageSymbol);

    // 2. Odtwórz dźwięk
    try {
      if (categorySymbol.voiceRecordingPath != null) {
        final audioPlayer = ref.read(audioPlayerServiceProvider);
        await audioPlayer.play(categorySymbol.voiceRecordingPath!);
      } else {
        final ttsService = ref.read(ttsServiceProvider);
        final name = categorySymbol.nameOverride ?? librarySymbol.name;
        await ttsService.speak(name);
      }
    } catch (e) {
      print('❌ Error playing audio/TTS: $e');
    }
  }

  // ========== SYMBOL INFO DIALOG ==========

  void _showSymbolInfo(
      BuildContext context,
      CategorySymbolModel categorySymbol,
      LibrarySymbolModel librarySymbol,
      ) {
    final name = categorySymbol.nameOverride ?? librarySymbol.name;
    final emoji = categorySymbol.emojiOverride ?? librarySymbol.emoji;
    final imagePath = categorySymbol.imagePathOverride ?? librarySymbol.imagePath;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Color(categorySymbol.backgroundColor),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildSymbolPreview(emoji, imagePath),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              if (categorySymbol.voiceRecordingPath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic, size: 16, color: Colors.green[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Ma nagranie głosu',
                        style: TextStyle(fontSize: 12, color: Colors.green[600]),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Zamknij', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push('/folder/${widget.profileId}/edit-symbol/${categorySymbol.id}?categoryId=${widget.categoryId ?? ''}');
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Edytuj', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSymbolPreview(String? emoji, String? imagePath) {
    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.startsWith('assets/')) {
        return Image.asset(imagePath, fit: BoxFit.cover);
      } else {
        return Image.file(
          File(imagePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.broken_image, size: 48, color: Colors.grey);
          },
        );
      }
    } else if (emoji != null && emoji.isNotEmpty) {
      return Center(child: Text(emoji, style: const TextStyle(fontSize: 64)));
    } else {
      return const Icon(Icons.image, size: 48, color: Colors.grey);
    }
  }

  // ========== CATEGORY MENU ==========

  void _showCategoryMenu(BuildContext context, CategoryModel category) {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                category.name,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildMenuButton(
                      icon: Icons.edit,
                      label: l10n.editCategory,
                      color: const Color(0xFFFDD835),
                      onTap: () {
                        Navigator.pop(ctx);
                        context.push('/folder/${widget.profileId}/category-editor?categoryId=${category.id}');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMenuButton(
                      icon: Icons.delete,
                      label: l10n.deleteCategory,
                      color: const Color(0xFFE53935),
                      iconColor: Colors.white,
                      textColor: Colors.white,
                      onTap: () {
                        Navigator.pop(ctx);
                        _confirmDeleteCategory(context, category);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required Color color,
    Color iconColor = Colors.black87,
    Color textColor = Colors.black87,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: iconColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  // ========== DELETE CONFIRMATIONS ==========

  Future<void> _confirmDeleteCategory(BuildContext context, CategoryModel category) async {
    final l10n = AppLocalizations.of(context)!;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteCategory),
        content: Text('Usunąć "${category.name}" wraz z całą zawartością?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final repository = await ref.read(categoryRepositoryProvider.future);
      await repository.deleteWithChildren(category.id);

      setState(() => _deleteMode = false);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.categoryDeleted), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.error(e.toString())), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmDeleteSymbol(BuildContext context, CategorySymbolModel symbol, String name) async {
    final l10n = AppLocalizations.of(context)!;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteSymbol),
        content: Text('Usunąć symbol "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final repository = await ref.read(categorySymbolRepositoryProvider.future);
      await repository.delete(symbol.id);

      setState(() => _deleteMode = false);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.symbolDeleted), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.error(e.toString())), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ========== ADD DIALOG ==========

  void _showAddDialog(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Co chcesz dodać?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildAddButton(
                      icon: Icons.create_new_folder,
                      label: l10n.addCategory,
                      color: const Color(0xFF42A5F5),
                      onTap: () {
                        Navigator.pop(ctx);
                        final parentParam = widget.categoryId != null
                            ? '&parentId=${widget.categoryId}'
                            : '';
                        context.push('/folder/${widget.profileId}/category-editor?$parentParam');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAddButton(
                      icon: Icons.add_photo_alternate,
                      label: l10n.addSymbol,
                      color: const Color(0xFF66BB6A),
                      onTap: () {
                        Navigator.pop(ctx);
                        final categoryParam = widget.categoryId != null
                            ? '?categoryId=${widget.categoryId}'
                            : '';
                        context.push('/folder/${widget.profileId}/add-symbol$categoryParam');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ========== GRID CONFIG DIALOG ==========

  Future<void> _showGridConfigDialog(BuildContext context) async {
    final gridConfigsNotifier = ref.read(symbolsGridConfigsProvider.notifier);
    final categoryId = widget.categoryId ?? 'root_${widget.profileId}';
    final defaultConfig = _currentCategory?.gridConfig ?? GridConfig(columns: 3, rows: 3);

    final currentConfig = gridConfigsNotifier.getConfig(categoryId, defaultConfig);

    final result = await showDialog<(int, int)>(
      context: context,
      builder: (context) => GridConfigDialog(
        initialColumns: currentConfig.columns,
        initialRows: currentConfig.rows,
        title: 'Siatka',
      ),
    );

    if (result != null) {
      final (columns, rows) = result;

      await gridConfigsNotifier.setConfig(
        categoryId,
        SymbolsGridConfig(columns: columns, rows: rows),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✔ Siatka: $columns × $rows'),
            duration: const Duration(seconds: 2),
          ),
        );

        setState(() {});
      }
    }
  }

  void _showReorderSheet(BuildContext context) {
    final contentAsync = ref.read(folderContentProvider(widget.profileId, widget.categoryId));

    contentAsync.whenData((content) {
      // Połącz i POSORTUJ po pozycji!
      final items = <dynamic>[...content.categories, ...content.symbols];
      items.sort((a, b) {
        final posA = a is CategoryModel ? a.position : (a as CategorySymbolModel).position;
        final posB = b is CategoryModel ? b.position : (b as CategorySymbolModel).position;
        return posA.compareTo(posB);
      });

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brak elementów do sortowania')),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => _ReorderBottomSheet(
          items: items,
          onSave: (reorderedItems) => _saveNewOrder(reorderedItems),
        ),
      );
    });
  }

  Future<void> _saveNewOrder(List<dynamic> reorderedItems) async {
    try {
      print('🔄 === SAVING NEW ORDER ===');

      for (int i = 0; i < reorderedItems.length; i++) {
        final item = reorderedItems[i];
        if (item is CategoryModel) {
          print('📁 [$i] Kategoria: ${item.name} (stara pozycja: ${item.position})');
        } else if (item is CategorySymbolModel) {
          print('🖼️ [$i] Symbol: ${item.nameOverride ?? item.id} (stara pozycja: ${item.position})');
        }
      }

      final catRepo = await ref.read(categoryRepositoryProvider.future);
      final symRepo = await ref.read(categorySymbolRepositoryProvider.future);

      // Zapisz każdy element z nową pozycją BEZPOŚREDNIO (nie przez updatePositions!)
      for (int i = 0; i < reorderedItems.length; i++) {
        final item = reorderedItems[i];
        if (item is CategoryModel) {
          final updated = item.copyWith(position: i);
          await catRepo.update(updated);
          print('📁 Zapisano kategorię "${item.name}" na pozycję $i');
        } else if (item is CategorySymbolModel) {
          final updated = item.copyWith(position: i);
          await symRepo.update(updated);
          print('🖼️ Zapisano symbol "${item.nameOverride ?? item.id}" na pozycję $i');
        }
      }

      print('✅ Zapisano ${reorderedItems.length} elementów');

      // Wymuś odświeżenie
      ref.invalidate(folderContentProvider(widget.profileId, widget.categoryId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Kolejność zapisana'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Błąd zapisywania: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ========== EMPTY STATE ==========

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.categoryId == null ? Icons.category_outlined : Icons.grid_view,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            widget.categoryId == null ? l10n.noCategories : 'Ten folder jest pusty',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.addFirstCategory,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddDialog(context, l10n),
            icon: const Icon(Icons.add),
            label: const Text('Dodaj'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ========== DRAWER ==========

  Widget _buildDrawer(BuildContext context, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[800] : Colors.white;
    final bgColor = isDark ? Colors.grey[900] : Colors.grey[50];
    final textColor = isDark ? Colors.white : Colors.black87;

    return Drawer(
      child: Container(
        color: bgColor,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.grey[200],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Opacity(
                        opacity: isDark ? 0.12 : 0.25,
                        child: Image.asset('assets/images/app_icon.png', fit: BoxFit.cover),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: isDark
                                ? [
                              Colors.grey[900]!.withOpacity(0.8),
                              Colors.grey[850]!.withOpacity(0.9)
                            ]
                                : [
                              Colors.white.withOpacity(0.8),
                              Colors.grey[100]!.withOpacity(0.9)
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF7E57C2),
                              border: Border.all(
                                color: isDark ? Colors.grey[700]! : Colors.white,
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _profile?.photoPath != null &&
                                _profile!.photoPath!.isNotEmpty &&
                                File(_profile!.photoPath!).existsSync()
                                ? ClipOval(
                              child: Image.file(
                                File(_profile!.photoPath!),
                                fit: BoxFit.cover,
                                width: 90,
                                height: 90,
                              ),
                            )
                                : Center(
                              child: Text(
                                _profile?.name.isNotEmpty == true
                                    ? _profile!.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _profile?.name ?? '',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.appTitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Menu items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildDrawerItem(
                      icon: Icons.library_books,
                      label: l10n.library,
                      color: const Color(0xFF7E57C2),
                      cardColor: cardColor!,
                      textColor: textColor,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/library');
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildThemeToggle(context, cardColor, textColor),
                    const SizedBox(height: 12),
                    Divider(color: isDark ? Colors.grey[700] : Colors.grey[300]),
                    const SizedBox(height: 12),
                    _buildDrawerItem(
                      icon: Icons.refresh,
                      label: 'Dodaj domyślne kategorie',
                      color: const Color(0xFFFFB74D),
                      cardColor: cardColor,
                      textColor: textColor,
                      onTap: () {
                        Navigator.pop(context);
                        _showAddDefaultCategoriesDialog(context);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDrawerItem(
                      icon: Icons.add_photo_alternate,
                      label: 'Dodaj domyślne symbole',
                      color: const Color(0xFF42A5F5),
                      cardColor: cardColor,
                      textColor: textColor,
                      onTap: () {
                        Navigator.pop(context);
                        _showAddDefaultSymbolsDialog(context);
                      },
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Wersja 1.0.0',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required Color color,
    required Color cardColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context, Color cardColor, Color textColor) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return GestureDetector(
      onTap: () => ref.read(themeModeProvider.notifier).toggleTheme(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF5C6BC0), const Color(0xFF3949AB)]
                      : [const Color(0xFFFFB74D), const Color(0xFFFFA726)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                isDark ? 'Tryb ciemny' : 'Tryb jasny',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            Container(
              width: 52,
              height: 28,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF5C6BC0) : Colors.grey[300],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    left: isDark ? 26 : 2,
                    top: 2,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== DEFAULT CATEGORIES/SYMBOLS ==========

  Future<void> _showAddDefaultCategoriesDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final repository = await ref.read(categoryRepositoryProvider.future);
    final existingCategories = await repository.getByProfileId(widget.profileId);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dodać domyślne kategorie?'),
        content: Text(existingCategories.isNotEmpty
            ? 'Nowe kategorie zostaną dodane na końcu listy.'
            : 'Zostaną dodane podstawowe kategorie.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final defaultCategories =
      await DefaultCategoriesService.createDefaultCategories(widget.profileId);
      for (final category in defaultCategories) {
        await repository.create(category);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Kategorie zostały dodane'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showAddDefaultSymbolsDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final categoryRepository = await ref.read(categoryRepositoryProvider.future);
    final categories = await categoryRepository.getByProfileId(widget.profileId);

    if (categories.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Najpierw dodaj kategorie!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dodać domyślne symbole?'),
        content: const Text(
            'Zostaną dodane podstawowe symbole do wszystkich istniejących kategorii.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final libraryRepo = await ref.read(librarySymbolRepositoryProvider.future);
      final categorySymbolRepo =
      await ref.read(categorySymbolRepositoryProvider.future);

      final (librarySymbols, categorySymbols) =
      await DefaultSymbolsService.createDefaultSymbolsForAllCategories(
        categories,
            () async => await libraryRepo.getAll(),
            (categoryId) async => await categorySymbolRepo.getByCategoryId(categoryId),
      );

      await libraryRepo.createMany(librarySymbols);
      await categorySymbolRepo.createMany(categorySymbols);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Symbole zostały dodane'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// Provider pomocniczy dla symboli z biblioteki
final _librarySymbolProvider = FutureProvider.family<LibrarySymbolModel?, String>(
      (ref, librarySymbolId) async {
    final repository = await ref.watch(librarySymbolRepositoryProvider.future);
    return await repository.getById(librarySymbolId);
  },
);

// ========== REORDER BOTTOM SHEET WIDGET ==========

class _ReorderBottomSheet extends ConsumerStatefulWidget {
  final List<dynamic> items;
  final Function(List<dynamic>) onSave;

  const _ReorderBottomSheet({
    required this.items,
    required this.onSave,
  });

  @override
  ConsumerState<_ReorderBottomSheet> createState() => _ReorderBottomSheetState();
}

class _ReorderBottomSheetState extends ConsumerState<_ReorderBottomSheet> {
  late List<dynamic> _items;
  final Map<String, LibrarySymbolModel> _librarySymbolsCache = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
    _loadLibrarySymbols();
  }

  Future<void> _loadLibrarySymbols() async {
    final libraryRepo = await ref.read(librarySymbolRepositoryProvider.future);

    for (final item in _items) {
      if (item is CategorySymbolModel) {
        final libSymbol = await libraryRepo.getById(item.librarySymbolId);
        if (libSymbol != null) {
          _librarySymbolsCache[item.librarySymbolId] = libSymbol;
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: bottomPadding + 16),
      child: Column(
        children: [
          // Uchwyt
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Tytuł
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.swap_vert, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Zmień kolejność',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Przytrzymaj i przeciągnij element',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 16),

          // Lista z ReorderableListView
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ReorderableListView.builder(
              itemCount: _items.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final item = _items.removeAt(oldIndex);
                  _items.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final item = _items[index];
                return _buildReorderItem(item, index);
              },
            ),
          ),

          const SizedBox(height: 16),

          // Przyciski
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Anuluj'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    widget.onSave(_items);
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF66BB6A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Zapisz'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReorderItem(dynamic item, int index) {
    String name;
    Color bgColor;
    Widget icon;
    bool isCategory;

    if (item is CategoryModel) {
      name = item.name;
      bgColor = Color(item.backgroundColor);
      isCategory = true;
      if (item.emoji != null && item.emoji!.isNotEmpty) {
        icon = Text(item.emoji!, style: const TextStyle(fontSize: 24));
      } else if (item.iconPath != null && item.iconPath!.isNotEmpty && File(item.iconPath!).existsSync()) {
        icon = Image.file(File(item.iconPath!), width: 32, height: 32, fit: BoxFit.contain);
      } else {
        icon = Icon(Icons.folder, color: Color(item.iconColor), size: 28);
      }
    } else if (item is CategorySymbolModel) {
      bgColor = Color(item.backgroundColor);
      isCategory = false;

      // Pobierz dane z cache
      final libSymbol = _librarySymbolsCache[item.librarySymbolId];
      name = item.nameOverride ?? libSymbol?.name ?? 'Symbol';

      final emoji = item.emojiOverride ?? libSymbol?.emoji;
      final imagePath = item.imagePathOverride ?? libSymbol?.imagePath;

      if (imagePath != null && imagePath.isNotEmpty) {
        if (imagePath.startsWith('assets/')) {
          icon = Image.asset(imagePath, width: 32, height: 32, fit: BoxFit.contain);
        } else if (File(imagePath).existsSync()) {
          icon = Image.file(File(imagePath), width: 32, height: 32, fit: BoxFit.contain);
        } else {
          icon = const Icon(Icons.image, size: 28, color: Colors.grey);
        }
      } else if (emoji != null && emoji.isNotEmpty) {
        icon = Text(emoji, style: const TextStyle(fontSize: 24));
      } else {
        icon = const Icon(Icons.image, size: 28, color: Colors.grey);
      }
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      key: ValueKey('${isCategory ? 'cat' : 'sym'}_${item.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: icon),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          isCategory ? '📁 Kategoria' : '🖼️ Symbol',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${index + 1}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.drag_handle, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}