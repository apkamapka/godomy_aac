import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';

/// Otwiera podany [url] w zewnętrznej przeglądarce.
///
/// W razie problemu (brak przeglądarki, błędny adres) pokazuje krótki
/// komunikat zamiast wywracać aplikację wyjątkiem.
Future<void> openExternalUrl(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      _showError(context);
    }
  } catch (_) {
    if (context.mounted) {
      _showError(context);
    }
  }
}

void _showError(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(l10n.linkOpenError),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
