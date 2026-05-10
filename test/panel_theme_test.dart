import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vnts_panel_windows/main.dart' as app;

void main() {
  test('theme preference resolves stored and legacy values', () {
    expect(
      app.resolveStoredThemeMode(storedMode: null, legacyDarkMode: null),
      ThemeMode.system,
    );
    expect(
      app.resolveStoredThemeMode(storedMode: 'dark', legacyDarkMode: false),
      ThemeMode.dark,
    );
    expect(
      app.resolveStoredThemeMode(storedMode: 'light', legacyDarkMode: true),
      ThemeMode.light,
    );
    expect(
      app.resolveStoredThemeMode(storedMode: 'system', legacyDarkMode: true),
      ThemeMode.system,
    );
    expect(
      app.resolveStoredThemeMode(storedMode: null, legacyDarkMode: true),
      ThemeMode.dark,
    );
    expect(
      app.resolveStoredThemeMode(storedMode: null, legacyDarkMode: false),
      ThemeMode.light,
    );
    expect(app.encodeThemeModePreference(ThemeMode.dark), 'dark');
    expect(app.encodeThemeModePreference(ThemeMode.light), 'light');
    expect(app.encodeThemeModePreference(ThemeMode.system), 'system');
  });

  test('panel light and dark themes expose readable surface colors', () {
    final lightTheme = app.buildPanelLightTheme();
    final darkTheme = app.buildPanelDarkTheme();

    expect(lightTheme.scaffoldBackgroundColor, const Color(0xFFF4F7F9));
    expect(darkTheme.scaffoldBackgroundColor, const Color(0xFF12171D));
    expect(lightTheme.cardTheme.color, const Color(0xFFFFFFFF));
    expect(darkTheme.cardTheme.color, const Color(0xFF1A212A));
    expect(
      lightTheme.inputDecorationTheme.fillColor,
      app.panelInputFillColor(Brightness.light),
    );
    expect(
      darkTheme.inputDecorationTheme.fillColor,
      app.panelInputFillColor(Brightness.dark),
    );
    expect(
      app.sidebarSurfaceColor(Brightness.dark).computeLuminance(),
      lessThan(app.sidebarSurfaceColor(Brightness.light).computeLuminance()),
    );
    expect(
      app.panelLogSurfaceColor(Brightness.dark).computeLuminance(),
      lessThan(app.panelLogSurfaceColor(Brightness.light).computeLuminance()),
    );
  });
}
