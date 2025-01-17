/*
  This file is part of Sanmill.
  Copyright (C) 2019-2023 The Sanmill developers (see AUTHORS file)

  Sanmill is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Sanmill is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

part of 'package:sanmill/appearance_settings/widgets/appearance_settings_page.dart';

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({
    required this.currentLanguageLocale,
    required this.onLanguageChange,
  });

  final Locale? currentLanguageLocale;
  final Function(Locale?) onLanguageChange;

  @override
  Widget build(BuildContext context) {
    final Column languageColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        RadioListTile<Locale?>(
          title: Text(
            S.of(context).defaultLanguage,
            textScaleFactor: DB().displaySettings.fontScale,
          ),
          groupValue: currentLanguageLocale,
          value: null,
          onChanged: onLanguageChange,
        ),
        const Divider(),
        for (Locale locale in localeToLanguageName.keys)
          RadioListTile<Locale>(
            title: Text(
              localeToLanguageName[locale]!,
              textScaleFactor: DB().displaySettings.fontScale,
            ),
            groupValue: currentLanguageLocale,
            value: locale,
            onChanged: onLanguageChange,
          ),
      ],
    );

    return AlertDialog(
      scrollable: true,
      content: languageColumn,
    );
  }
}
