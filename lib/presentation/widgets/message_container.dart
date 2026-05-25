import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/app_localizations.dart';
import '../providers/message_provider.dart';

class MessageContainer extends ConsumerStatefulWidget {
  const MessageContainer({super.key});

  @override
  ConsumerState<MessageContainer> createState() => _MessageContainerState();
}

class _MessageContainerState extends ConsumerState<MessageContainer> {
  bool _isSpeaking = false; // ✅ NOWY STAN

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final symbols = ref.watch(messageSymbolsProvider);
    final isVisible = ref.watch(messageContainerVisibleProvider);

    if (!isVisible) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Symbol strip - lista symboli
            Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: symbols.isEmpty
                  ? Center(
                child: Text(
                  l10n.noSymbols,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              )
                  : ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: symbols.length,
                itemBuilder: (context, index) {
                  final symbol = symbols[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _MiniSymbolCard(
                      symbol: symbol,
                      onTap: () {
                        _showSymbolOptions(context, ref, index, symbol);
                      },
                    ),
                  );
                },
              ),
            ),

            // Kontrolki
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  // Usuń ostatni
                  IconButton(
                    icon: const Icon(Icons.backspace),
                    onPressed: symbols.isEmpty || _isSpeaking
                        ? null
                        : () {
                      ref
                          .read(messageSymbolsProvider.notifier)
                          .removeLast();
                    },
                    tooltip: 'Usuń ostatni',
                    color: Theme.of(context).colorScheme.error,
                  ),

                  const SizedBox(width: 8),

                  // Wpisz tekst
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSpeaking ? null : () => _showTextInputDialog(),
                      icon: const Icon(Icons.edit),
                      label: const Text('Wpisz tekst'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // ✅ ZAKTUALIZOWANY PRZYCISK MÓW
                  ElevatedButton.icon(
                    onPressed: symbols.isEmpty || _isSpeaking
                        ? null
                        : () => _handleSpeak(),
                    icon: _isSpeaking
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.volume_up),
                    label: Text(_isSpeaking ? 'Mówi...' : 'Mów'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Wyczyść wszystko
                  IconButton(
                    icon: const Icon(Icons.clear_all),
                    onPressed: symbols.isEmpty || _isSpeaking
                        ? null
                        : () {
                      ref.read(messageSymbolsProvider.notifier).clear();
                    },
                    tooltip: 'Wyczyść wszystko',
                    color: Theme.of(context).colorScheme.error,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NOWA METODA: Obsługa przycisku Mów
  Future<void> _handleSpeak() async {
    setState(() => _isSpeaking = true);

    try {
      await ref.read(messageSymbolsProvider.notifier).speakAll();
      // ✅ Usunięto SnackBar - nie pokazuje komunikatu
    } catch (e) {
      print('❌ Błąd podczas wypowiadania: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Błąd: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
    }
  }

  // ✅ POPRAWIONA METODA: Dialog do wpisywania tekstu
  // ✅ POPRAWIONA METODA: Dialog do wpisywania tekstu
  Future<void> _showTextInputDialog() async {
    final textController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wpisz tekst'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'np. Chcę jeść',
            border: OutlineInputBorder(),
          ),
          maxLines: 1,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(context, value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                Navigator.pop(context, textController.text.trim());
              }
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );

    // ✅ KLUCZOWA ZMIANA: Opóźnij dispose żeby dialog miał czas się zamknąć
    Future.delayed(const Duration(milliseconds: 100), () {
      textController.dispose();
    });

    if (result != null && result.isNotEmpty) {
      ref.read(messageSymbolsProvider.notifier).addText(result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✔ Dodano: "$result"'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _showSymbolOptions(
      BuildContext context,
      WidgetRef ref,
      int index,
      MessageSymbol symbol,
      ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Usuń ten symbol'),
              onTap: () {
                Navigator.pop(context);
                ref.read(messageSymbolsProvider.notifier).removeAt(index);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Mini card dla symboli w message container
class _MiniSymbolCard extends StatelessWidget {
  final MessageSymbol symbol;
  final VoidCallback onTap;

  const _MiniSymbolCard({
    required this.symbol,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        decoration: BoxDecoration(
          color: Color(symbol.backgroundColor),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.black.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✅ Ikona mikrofonu jeśli ma nagranie
            if (symbol.voiceRecordingPath != null)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic,
                    size: 8,
                    color: Colors.white,
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: _buildIcon(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Text(
                symbol.name,
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    if (symbol.imagePath != null && symbol.imagePath!.isNotEmpty) {
      final file = File(symbol.imagePath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.contain);
      }
    }

    if (symbol.emoji != null && symbol.emoji!.isNotEmpty) {
      return Text(
        symbol.emoji!,
        style: const TextStyle(fontSize: 32),
      );
    }

    // ✅ TEKST - pokazuj pierwszą literę lub ikonę "T"
    if (symbol.name.isNotEmpty) {
      return Text(
        symbol.name[0].toUpperCase(),
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      );
    }

    return const Icon(Icons.image, size: 32, color: Colors.grey);
  }
}