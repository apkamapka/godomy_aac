import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gif_view/gif_view.dart';
import 'package:google_fonts/google_fonts.dart';

class SymbolCard extends StatefulWidget {
  final String? emoji;
  final String? imagePath;
  final String name;
  final int backgroundColor;
  final bool deleteMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onDelete;

  const SymbolCard({
    super.key,
    this.emoji,
    this.imagePath,
    required this.name,
    required this.backgroundColor,
    required this.deleteMode,
    required this.onTap,
    required this.onLongPress,
    this.onDelete,
  });

  @override
  State<SymbolCard> createState() => _SymbolCardState();
}

class _SymbolCardState extends State<SymbolCard> {
  Uint8List? _cachedGifBytes;
  bool _isLoadingGif = false;

  @override
  void initState() {
    super.initState();
    _loadGifIfNeeded();
  }

  @override
  void didUpdateWidget(SymbolCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Jeśli ścieżka się zmieniła, wyczyść cache i przeładuj GIF
    if (oldWidget.imagePath != widget.imagePath) {
      setState(() {
        _cachedGifBytes = null; // ✅ Wyczyść cache
        _isLoadingGif = false;
      });
      _loadGifIfNeeded();
    }
  }

  @override
  void dispose() {
    _cachedGifBytes = null; // ✅ Wyczyść cache przy usuwaniu widgetu
    super.dispose();
  }

  Future<void> _loadGifIfNeeded() async {
    if (widget.imagePath != null &&
        widget.imagePath!.isNotEmpty &&
        widget.imagePath!.toLowerCase().endsWith('.gif')) {

      final file = File(widget.imagePath!);
      if (file.existsSync()) {
        setState(() => _isLoadingGif = true);

        try {
          final bytes = await file.readAsBytes();
          if (mounted) {
            setState(() {
              _cachedGifBytes = bytes;
              _isLoadingGif = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isLoadingGif = false);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(widget.backgroundColor),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: Colors.black.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: widget.deleteMode ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: InkWell(
          onTap: widget.deleteMode ? widget.onDelete : widget.onTap,
          onLongPress: widget.onLongPress,
          child: Stack(
            children: [
              // Główna zawartość
              Padding(
                padding: const EdgeInsets.all(0.5), // ✅ ZMIENIONE z 1.0 na 0.5
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Ikona / Emoji / Obrazek
                    Expanded(
                      flex: 4,
                      child: Center(child: _buildIcon()),
                    ),
                    const SizedBox(height: 2), // ✅ ZMIENIONE z 4 na 2
                    // Nazwa
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3), // ✅ ZMIENIONE z (4,6) na (2,3)
                      child: Text(
                        widget.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Delete overlay
              if (widget.deleteMode)
                Positioned.fill(
                  child: Container(
                    color: Colors.red.withOpacity(0.7),
                    child: const Icon(
                      Icons.delete,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    Widget iconWidget;

    if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
      final file = File(widget.imagePath!);
      if (file.existsSync()) {
        final isGif = widget.imagePath!.toLowerCase().endsWith('.gif');

        if (isGif) {
          // ✅ Animowany GIF - używam Image.memory zamiast GifView
          if (_isLoadingGif) {
            iconWidget = const Center(child: CircularProgressIndicator());
          } else if (_cachedGifBytes != null) {
            iconWidget = Image.memory(
              _cachedGifBytes!,
              key: UniqueKey(), // ✅ ZAWSZE unikalny klucz
              height: double.infinity,
              width: double.infinity,
              fit: BoxFit.contain,
              gaplessPlayback: false, // ✅ Wymusza przeładowanie
            );
          } else {
            iconWidget = const Icon(Icons.broken_image, size: 64, color: Colors.red);
          }
        } else {
          // ✅ Zwykły obrazek
          iconWidget = Image.file(
            file,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.broken_image, size: 64, color: Colors.red);
            },
          );
        }
      } else {
        iconWidget = const Icon(Icons.image, size: 64, color: Colors.grey);
      }
    } else if (widget.emoji != null && widget.emoji!.isNotEmpty) {
      iconWidget = LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxHeight < constraints.maxWidth
              ? constraints.maxHeight
              : constraints.maxWidth;

          return Center(
            child: Text(
              widget.emoji!,
              style: GoogleFonts.notoColorEmoji(
                fontSize: size * 0.7,
                height: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
          );
        },
      );
    } else {
      iconWidget = const Icon(Icons.image, size: 64, color: Colors.grey);
    }

    return Padding(
      padding: const EdgeInsets.all(3.0), // ✅ ZMIENIONE z 8.0 na 3.0
      child: iconWidget,
    );
  }
}