import 'package:flutter/material.dart';

class SymbolsCloudHeader extends StatelessWidget {
  final String title;
  final Color backgroundColor;
  final bool collapsed;
  final bool deleteMode;
  final bool keyboardVisible;
  final VoidCallback onToggle;
  final VoidCallback onAddSymbol;
  final VoidCallback onDeleteToggle;
  final VoidCallback onGridConfig;
  final VoidCallback onKeyboardToggle;

  const SymbolsCloudHeader({
    super.key,
    required this.title,
    required this.backgroundColor,
    required this.collapsed,
    required this.deleteMode,
    required this.keyboardVisible,
    required this.onToggle,
    required this.onAddSymbol,
    required this.onDeleteToggle,
    required this.onGridConfig,
    required this.onKeyboardToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Chmurka z przyciskami
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: collapsed ? 0 : 140,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: collapsed ? 0 : 1,
            child: collapsed
                ? const SizedBox.shrink()
                : _buildCloud(context),
          ),
        ),

        // Strzałka zwijania
        _buildCollapseButton(context),
      ],
    );
  }

  Widget _buildCloud(BuildContext context) {
    // Dopasuj jasność koloru tła
    final hsl = HSLColor.fromColor(backgroundColor);
    final cloudColor = hsl.withLightness((hsl.lightness + 0.85) / 2).toColor();

    return Container(
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
          // Tytuł kategorii
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _getTextColor(backgroundColor),
            ),
          ),
          const SizedBox(height: 10),

          // Przyciski
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Dodaj symbol
              _buildCircleButton(
                imagePath: 'assets/ui_icons/klawiszdodaj.png',
                onTap: onAddSymbol,
                size: 48,
              ),
              const SizedBox(width: 16),

              // Usuń (toggle)
              _buildCircleButton(
                imagePath: 'assets/ui_icons/klawiszusun.png',
                onTap: onDeleteToggle,
                size: 48,
                isActive: deleteMode,
              ),
              const SizedBox(width: 16),

              // Siatka
              _buildCircleButton(
                imagePath: 'assets/ui_icons/klawiszsiatka.png',
                onTap: onGridConfig,
                size: 48,
              ),
              const SizedBox(width: 16),

              // Klawiatura
              _buildCircleButton(
                imagePath: 'assets/ui_icons/klawiszklawiatura.png',
                onTap: onKeyboardToggle,
                size: 48,
                isActive: keyboardVisible,
              ),
            ],
          ),
        ],
      ),
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
          border: isActive
              ? Border.all(color: Colors.white, width: 3)
              : null,
        ),
        child: ClipOval(
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseButton(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: Image.asset(
          collapsed
              ? 'assets/ui_icons/klawiszdol.png'
              : 'assets/ui_icons/klawiszgora.png',
          width: 32,
          height: 32,
        ),
      ),
    );
  }

  Color _getTextColor(Color bgColor) {
    // Ciemniejszy wariant koloru tła dla tekstu
    final hsl = HSLColor.fromColor(bgColor);
    return hsl.withLightness(0.25).withSaturation(0.8).toColor();
  }
}