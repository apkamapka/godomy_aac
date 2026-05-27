import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/category_model.dart';

class CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final bool deleteMode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;  // ✅ DODANE
  final VoidCallback onDelete;

  const CategoryCard({
    super.key,
    required this.category,
    required this.deleteMode,
    required this.onTap,
    this.onLongPress,  // ✅ DODANE
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: deleteMode ? 1 : 4,
      color: Color(category.backgroundColor),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.black.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: deleteMode ? onDelete : onTap,
        onLongPress: deleteMode ? null : onLongPress,  // ✅ DODANE
        child: Stack(
          children: [
            // Główna zawartość
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ikona / Emoji / Obrazek
                  Expanded(
                    flex: 5,
                    child: Center(child: _buildIcon()),
                  ),
                  const SizedBox(height: 2),
                  // Nazwa
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

            // Delete overlay
            if (deleteMode)
              Positioned.fill(
                child: Container(
                  color: Colors.red.withOpacity(0.7),
                  child: const Icon(
                    Icons.delete,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    Widget iconWidget;

    // 1. Własny obrazek — tylko jeśli plik faktycznie istnieje na dysku
    if (category.iconPath != null && category.iconPath!.isNotEmpty) {
      final file = File(category.iconPath!);
      if (file.existsSync()) {
        return FittedBox(
          fit: BoxFit.contain,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Image.file(file, fit: BoxFit.contain),
          ),
        );
      }
      // Plik znikł — spadamy dalej (emoji / iconName / default),
      // NIE pokazujemy folderu jako fallback.
    }

    // 2. Emoji
    if (category.emoji != null && category.emoji!.isNotEmpty) {
      iconWidget = Text(category.emoji!, style: TextStyle(fontSize: 200));
    }
    // 3. Material Icon po nazwie
    else if (category.iconName != null && category.iconName!.isNotEmpty) {
      iconWidget = Icon(_getIconData(category.iconName!), size: 200, color: Color(category.iconColor));
    }
    // 4. Domyślny folder
    else {
      iconWidget = Icon(Icons.category, size: 200, color: Color(category.iconColor));
    }

    return FittedBox(
      fit: BoxFit.contain,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: iconWidget,
      ),
    );
  }

  IconData _getIconData(String iconName) {
    // Mapowanie nazwy ikony na IconData
    final iconMap = {
      'home': Icons.home,
      'restaurant': Icons.restaurant,
      'local_dining': Icons.local_dining,
      'favorite': Icons.favorite,
      'school': Icons.school,
      'sports_soccer': Icons.sports_soccer,
      'sports': Icons.sports,
      'music_note': Icons.music_note,
      'videogame_asset': Icons.videogame_asset,
      'tv': Icons.tv,
      'book': Icons.book,
      'chat_bubble': Icons.chat_bubble,
      'help': Icons.help,
      'settings': Icons.settings,
      'person': Icons.person,
      'star': Icons.star,
      'emoji_emotions': Icons.emoji_emotions,
      'wb_sunny': Icons.wb_sunny,
      'nightlight': Icons.nightlight,
      'pets': Icons.pets,
      'directions_car': Icons.directions_car,
      'local_hospital': Icons.local_hospital,
      'shopping_cart': Icons.shopping_cart,
      'beach_access': Icons.beach_access,
      'park': Icons.park,
      'fastfood': Icons.fastfood,
      'cake': Icons.cake,
      'coffee': Icons.coffee,
    };

    return iconMap[iconName] ?? Icons.category;
  }
}