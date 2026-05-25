import 'package:flutter/material.dart';

class CloudHeader extends StatelessWidget {
  final String title;
  final bool collapsed;
  final VoidCallback onToggle;
  final VoidCallback onAddCategory;
  final VoidCallback onGridConfig;

  const CloudHeader({
    super.key,
    required this.title,
    required this.collapsed,
    required this.onToggle,
    required this.onAddCategory,
    required this.onGridConfig,
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
          height: collapsed ? 0 : 160,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: collapsed ? 0 : 1,
            child: collapsed
                ? const SizedBox.shrink()
                : _buildCloud(context),
          ),
        ),

        // Strzałka zwijania (zawsze widoczna)
        _buildCollapseButton(context),
      ],
    );
  }

  Widget _buildCloud(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tytuł profilu
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1565C0), // Niebieski jak na wizualizacji
            ),
          ),
          const SizedBox(height: 12),

          // Przyciski
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Dodaj kategorię
              _buildCircleButton(
                imagePath: 'assets/ui_icons/klawiszdodaj.png',
                onTap: onAddCategory,
                size: 56,
              ),
              const SizedBox(width: 24),

              // Siatka
              _buildCircleButton(
                imagePath: 'assets/ui_icons/klawiszsiatka.png',
                onTap: onGridConfig,
                size: 56,
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
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
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
          width: 36,
          height: 36,
        ),
      ),
    );
  }
}