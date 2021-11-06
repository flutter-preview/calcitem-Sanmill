/*
  This file is part of Sanmill.
  Copyright (C) 2019-2021 The Sanmill developers (see AUTHORS file)

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

import 'package:flutter/material.dart' show Locale;
import 'package:hive_flutter/adapters.dart';
import 'package:json_annotation/json_annotation.dart' show JsonSerializable;

/// Locale Adapter
///
/// This adapter provides helper functions to be used with [JsonSerializable]
/// and is a general [TypeAdapter] to be used with Hive [Box]es
class LocaleAdapter extends TypeAdapter<Locale?> {
  @override
  final typeId = 7;

  @override
  Locale read(BinaryReader reader) {
    final _value = reader.readString();
    return Locale(_value);
  }

  @override
  void write(BinaryWriter writer, Locale? obj) {
    if (obj != null) {
      writer.writeString(obj.languageCode);
    }
  }

  static String? colorToJson(Locale? locale) => locale?.languageCode;
  static Locale? colorFromJson(String? value) {
    if (value != null) {
      return Locale(value);
    }
  }
}