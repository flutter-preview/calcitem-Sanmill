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

part of './game_page.dart';

class GameResultAlert extends StatelessWidget {
  GameResultAlert({
    required this.winner,
    Key? key,
  }) : super(key: key);

  final GameMode gameMode = MillController().gameInstance.gameMode;
  final PieceColor winner;

  static const _tag = "[Game Over Alert]";

  GameResult? get _gameResult {
    if (gameMode == GameMode.aiVsAi) return null;

    return winner.result;
  }

  @override
  Widget build(BuildContext context) {
    final controller = MillController();
    controller.position.result = _gameResult;

    final String dialogTitle = _gameResult!.winString(context);

    final bool isTopLevel = DB().preferences.skillLevel == 30; // TODO: 30

    final content = StringBuffer(
      controller.position.gameOverReason
          .getName(context, controller.position.winner),
    );

    logger.v("$_tag Game over reason string: $content");

    final List<Widget> actions;
    if (_gameResult == GameResult.win &&
        !isTopLevel &&
        gameMode == GameMode.humanVsAi) {
      content.writeln();
      content.writeln();
      content.writeln(
        S.of(context).challengeHarderLevel(
              DB().preferences.skillLevel + 1,
            ),
      );

      actions = [
        TextButton(
          child: Text(
            S.of(context).yes,
          ),
          onPressed: () async {
            final _pref = DB().preferences;
            DB().preferences = _pref.copyWith(skillLevel: _pref.skillLevel + 1);
            logger.v(
              "[config] skillLevel: ${DB().preferences.skillLevel}",
            );

            Navigator.pop(context);
          },
        ),
        TextButton(
          child: Text(S.of(context).no),
          onPressed: () => Navigator.pop(context),
        ),
      ];
    } else {
      actions = [
        TextButton(
          child: Text(S.of(context).restart),
          onPressed: () {
            Navigator.pop(context);
            controller.reset();
          },
        ),
        TextButton(
          child: Text(S.of(context).cancel),
          onPressed: () => Navigator.pop(context),
        ),
      ];
    }

    return AlertDialog(
      title: Text(
        dialogTitle,
        style: AppTheme.dialogTitleTextStyle,
      ),
      content: Text(content.toString()),
      actions: actions,
    );
  }
}
