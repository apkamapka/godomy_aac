import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/app_settings.dart';
import '../providers/caregiver_provider.dart';
import 'app_sheet.dart';

/// Próba odblokowania trybu opiekuna wybraną metodą (zadanie / PIN).
/// Metoda „przytrzymaj” jest obsługiwana bezpośrednio przez [LockButton].
Future<bool> requestCaregiverUnlock(BuildContext context, WidgetRef ref) async {
  final settings = ref.read(appSettingsProvider);
  final method = settings.lockMethod;

  if (method == LockMethod.pin && settings.hasPin) {
    final result = await showDialog<_PinResult>(
      context: context,
      builder: (_) => const PinPadDialog(mode: PinPadMode.verify),
    );
    if (result == _PinResult.ok) return true;
    if (result == _PinResult.forgot && context.mounted) {
      final solved = await showMathChallenge(context, hard: true);
      if (solved && context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        showToast(context, l10n.pinResetHint);
      }
      return solved;
    }
    return false;
  }
  return showMathChallenge(context);
}

/// Ustawia tryb opiekuna i (przy wyjściu) wyłącza tryb usuwania.
void setCaregiverMode(WidgetRef ref, bool enabled) {
  ref.read(caregiverModeProvider.notifier).state = enabled;
  if (!enabled) ref.read(deleteModeProvider.notifier).state = false;
}

/// Kłódka w górnym pasku tablicy.
class LockButton extends ConsumerStatefulWidget {
  const LockButton({super.key});

  @override
  ConsumerState<LockButton> createState() => _LockButtonState();
}

class _LockButtonState extends ConsumerState<LockButton> with SingleTickerProviderStateMixin {
  late final AnimationController _hold;
  bool _holding = false;

  /// Po odblokowaniu przytrzymaniem puszczenie palca daje też zwykły „tap” –
  /// trzeba go zignorować, inaczej kłódka od razu by się zamknęła.
  bool _suppressNextTap = false;

  @override
  void initState() {
    super.initState();
    _hold = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _holding = false;
          _suppressNextTap = true;
          _hold.reset();
          HapticFeedback.mediumImpact();
          setCaregiverMode(ref, true);
        }
      });
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (_suppressNextTap) {
      _suppressNextTap = false;
      return;
    }
    final unlocked = ref.read(caregiverModeProvider);
    if (unlocked) {
      setCaregiverMode(ref, false);
      return;
    }
    final method = ref.read(appSettingsProvider).lockMethod;
    if (method == LockMethod.hold) {
      showToast(context, AppLocalizations.of(context)!.lockHoldHint);
      return;
    }
    final ok = await requestCaregiverUnlock(context, ref);
    if (ok && mounted) {
      HapticFeedback.mediumImpact();
      setCaregiverMode(ref, true);
    }
  }

  void _startHold() {
    if (ref.read(caregiverModeProvider)) return;
    if (ref.read(appSettingsProvider).lockMethod != LockMethod.hold) return;
    _holding = true;
    _hold.forward(from: 0);
  }

  void _stopHold() {
    if (!_holding) return;
    _holding = false;
    if (_hold.isAnimating) {
      _hold.stop();
      _hold.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = ref.watch(caregiverModeProvider);
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;

    return Listener(
      onPointerDown: (_) {
        // Nowe dotknięcie – poprzednie „przytrzymanie” już nie blokuje tapnięcia
        // (np. gdy palec zjechał z kłódki i tap się nie wydarzył).
        _suppressNextTap = false;
        _startHold();
      },
      onPointerUp: (_) => _stopHold(),
      onPointerCancel: (_) => _stopHold(),
      child: Semantics(
        button: true,
        label: unlocked ? l10n.lockTooltipLock : l10n.lockTooltipUnlock,
        child: GestureDetector(
          onTap: _onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: unlocked ? AppColors.sky : palette.surface,
                    boxShadow: [
                      BoxShadow(
                        color: unlocked ? AppColors.skyDeep : palette.line,
                        offset: const Offset(0, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                    color: unlocked ? Colors.white : palette.ink,
                    size: 22,
                  ),
                ),
                AnimatedBuilder(
                  animation: _hold,
                  builder: (context, _) {
                    if (_hold.value == 0) return const SizedBox.shrink();
                    return SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        value: _hold.value,
                        strokeWidth: 4,
                        color: AppColors.sky,
                        backgroundColor: palette.line,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Zadanie matematyczne
// =============================================================================

Future<bool> showMathChallenge(BuildContext context, {bool hard = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => MathChallengeDialog(hard: hard),
  );
  return result ?? false;
}

class MathChallengeDialog extends StatefulWidget {
  final bool hard;
  const MathChallengeDialog({super.key, this.hard = false});

  @override
  State<MathChallengeDialog> createState() => _MathChallengeDialogState();
}

class _MathChallengeDialogState extends State<MathChallengeDialog> {
  final _random = Random();
  late String _question;
  late int _answer;
  String _input = '';
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    _newQuestion();
  }

  void _newQuestion() {
    if (widget.hard || _random.nextBool()) {
      final a = 12 + _random.nextInt(18); // 12–29
      final b = 3 + _random.nextInt(7); // 3–9
      _question = '$a × $b';
      _answer = a * b;
    } else {
      final a = 23 + _random.nextInt(57); // 23–79
      final b = 18 + _random.nextInt(61); // 18–78
      _question = '$a + $b';
      _answer = a + b;
    }
    _input = '';
  }

  void _press(String key) {
    setState(() {
      _wrong = false;
      if (key == '⌫') {
        if (_input.isNotEmpty) _input = _input.substring(0, _input.length - 1);
      } else if (_input.length < 4) {
        _input += key;
      }
    });
  }

  void _check() {
    if (_input.isEmpty) return;
    if (int.tryParse(_input) == _answer) {
      Navigator.pop(context, true);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _wrong = true;
        _newQuestion();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, size: 34, color: AppColors.sky),
              const SizedBox(height: 8),
              Text(l10n.caregiverModeTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                l10n.mathChallengeHint,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.inkSoft, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Text(
                '$_question = ?',
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              _AnswerBox(text: _input, wrong: _wrong),
              if (_wrong)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l10n.mathChallengeWrong,
                    style: const TextStyle(color: AppColors.coralDeep, fontWeight: FontWeight.w800),
                  ),
                ),
              const SizedBox(height: 14),
              NumberPad(onKey: _press),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _input.isEmpty ? null : _check,
                      child: Text(l10n.unlock),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerBox extends StatelessWidget {
  final String text;
  final bool wrong;
  const _AnswerBox({required this.text, required this.wrong});

  @override
  Widget build(BuildContext context) {
    final palette = context.aac;
    return Container(
      width: 160,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: wrong ? AppColors.coralDeep : palette.line, width: 2),
      ),
      child: Text(
        text.isEmpty ? '–' : text,
        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 2),
      ),
    );
  }
}

/// Klawiatura numeryczna z dużymi przyciskami.
class NumberPad extends StatelessWidget {
  final ValueChanged<String> onKey;
  const NumberPad({super.key, required this.onKey});

  static const _keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];

  @override
  Widget build(BuildContext context) {
    final palette = context.aac;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.9,
      children: [
        for (final k in _keys)
          if (k.isEmpty)
            const SizedBox.shrink()
          else
            Material(
              color: palette.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onKey(k);
                },
                child: Center(
                  child: k == '⌫'
                      ? Icon(Icons.backspace_rounded, color: palette.ink)
                      : Text(k, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
      ],
    );
  }
}

// =============================================================================
// PIN
// =============================================================================

enum PinPadMode { verify, set }

enum _PinResult { ok, forgot }

/// Dialog PIN-u. W trybie `set` zwraca nowy PIN (String), w trybie `verify`
/// zwraca wynik sprawdzenia.
class PinPadDialog extends ConsumerStatefulWidget {
  final PinPadMode mode;
  const PinPadDialog({super.key, required this.mode});

  @override
  ConsumerState<PinPadDialog> createState() => _PinPadDialogState();
}

class _PinPadDialogState extends ConsumerState<PinPadDialog> {
  String _pin = '';
  String? _first;
  bool _error = false;
  // Po wpisaniu 4. cyfry klawiatura jest zablokowana do czasu sprawdzenia,
  // żeby szybkie dotknięcia nie wywołały sprawdzenia (i zamknięcia) dwa razy.
  bool _locked = false;

  void _press(String key) {
    if (_locked) return;
    if (key == '⌫') {
      if (_pin.isEmpty) return;
      setState(() {
        _error = false;
        _pin = _pin.substring(0, _pin.length - 1);
      });
      return;
    }
    if (_pin.length >= 4) return;
    setState(() {
      _error = false;
      _pin += key;
    });
    if (_pin.length == 4) {
      _locked = true;
      Future.delayed(const Duration(milliseconds: 120), _complete);
    }
  }

  void _complete() {
    if (!mounted) return;
    if (widget.mode == PinPadMode.verify) {
      final ok = ref.read(appSettingsProvider.notifier).checkPin(_pin);
      if (ok) {
        Navigator.pop(context, _PinResult.ok);
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _locked = false;
          _error = true;
          _pin = '';
        });
      }
      return;
    }
    // Ustawianie: wpisz dwa razy.
    if (_first == null) {
      setState(() {
        _locked = false;
        _first = _pin;
        _pin = '';
      });
    } else if (_first == _pin) {
      Navigator.pop(context, _pin);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _locked = false;
        _error = true;
        _first = null;
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = context.aac;
    final title = widget.mode == PinPadMode.verify
        ? l10n.pinEnter
        : (_first == null ? l10n.pinSetNew : l10n.pinRepeat);
    final error = widget.mode == PinPadMode.verify ? l10n.pinWrong : l10n.pinMismatch;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pin_rounded, size: 34, color: AppColors.sky),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 4; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _pin.length
                            ? (_error ? AppColors.coralDeep : AppColors.sky)
                            : palette.line,
                      ),
                    ),
                ],
              ),
              SizedBox(
                height: 30,
                child: _error
                    ? Center(
                        child: Text(
                          error,
                          style: const TextStyle(color: AppColors.coralDeep, fontWeight: FontWeight.w800),
                        ),
                      )
                    : null,
              ),
              NumberPad(onKey: _press),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  if (widget.mode == PinPadMode.verify)
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, _PinResult.forgot),
                        child: Text(l10n.pinForgot, textAlign: TextAlign.center),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ustawienie nowego PIN-u. Zwraca true, jeśli zapisano.
Future<bool> setNewPin(BuildContext context, WidgetRef ref) async {
  final pin = await showDialog<String>(
    context: context,
    builder: (_) => const PinPadDialog(mode: PinPadMode.set),
  );
  if (pin == null || pin.length != 4) return false;
  await ref.read(appSettingsProvider.notifier).setPin(pin);
  return true;
}
