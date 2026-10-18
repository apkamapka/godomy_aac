# godoMyAAC 1.1.0 - usuwa pliki, ktorych nie ma juz w nowej wersji.
# Uruchom w katalogu repo (po rozpakowaniu zipa):
#   powershell -ExecutionPolicy Bypass -File .\usun_stare_pliki.ps1
Set-Location -LiteralPath $PSScriptRoot

$paths = @(
  # stare ekrany, widgety i providery (zastapione nowymi)
  'lib\data\services\default_categories_service.dart',
  'lib\data\services\default_symbols_service.dart',
  'lib\presentation\providers\categories_provider.dart',
  'lib\presentation\providers\category_symbols_provider.dart',
  'lib\presentation\providers\folder_content_provider.dart',
  'lib\presentation\providers\library_symbols_search_provider.dart',
  'lib\presentation\providers\message_provider.dart',
  'lib\presentation\screens\add_symbol_screen.dart',
  'lib\presentation\screens\categories_screen.dart',
  'lib\presentation\screens\edit_symbol_screen.dart',
  'lib\presentation\screens\library_add_symbol_screen.dart',
  'lib\presentation\screens\library_edit_symbol_screen.dart',
  'lib\presentation\screens\symbols_screen.dart',
  'lib\presentation\widgets\category_card.dart',
  'lib\presentation\widgets\cloud_header.dart',
  'lib\presentation\widgets\message_container.dart',
  'lib\presentation\widgets\profile_card.dart',
  'lib\presentation\widgets\symbol_card.dart',
  'lib\presentation\widgets\symbols_cloud_header.dart',

  # stare obrazki (zastapione przez assets\symbols\*.webp)
  'assets\category_icons',
  'assets\ui_icons',
  'assets\images\drawer_header_bg.png',

  # stare pliki generowane (nie sa w repo, ale zostaja na dysku)
  'lib\core\router\app_router.g.dart',
  'lib\presentation\providers\categories_provider.g.dart',
  'lib\presentation\providers\category_symbols_provider.g.dart',
  'lib\presentation\providers\folder_content_provider.g.dart',
  'lib\presentation\providers\library_symbols_search_provider.g.dart',
  'lib\presentation\providers\message_provider.g.dart'
)

foreach ($p in $paths) {
  if (Test-Path -LiteralPath $p) {
    Remove-Item -LiteralPath $p -Recurse -Force
    Write-Host "usunieto: $p"
  }
}

# Skrypt nie jest czescia aplikacji - na koniec usuwa sam siebie.
Remove-Item -LiteralPath $PSCommandPath -Force
Write-Host 'Gotowe.'
