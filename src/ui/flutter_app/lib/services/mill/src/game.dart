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

part of '../mill.dart';

class _Game {
  static const String _tag = "[game]";

  _Game();

  PieceColor sideToMove = PieceColor.white;

  bool get _isAiToMove {
    assert(sideToMove == PieceColor.white || sideToMove == PieceColor.black);
    return _isAi[sideToMove]!;
  }

  int? focusIndex;
  int? blurIndex;

  // TODO: [Leptopoda] give a game two players (new class) to hold a player. A player can have a color, be ai ...
  Map<PieceColor, bool> _isAi = {
    PieceColor.white: false,
    PieceColor.black: true,
  };

  final Map<PieceColor, bool> _isSearching = {
    PieceColor.white: false,
    PieceColor.black: false
  };

  // TODO: [Leptopoda] this is very suspicious.
  //[_isSearching] is private and only used by it's getter. Seems like this is somehow redundant ...
  bool get _aiIsSearching {
    logger.i(
      "$_tag White is searching? ${_isSearching[PieceColor.white]}\n"
      "$_tag Black is searching? ${_isSearching[PieceColor.black]}\n",
    );

    return _isSearching[PieceColor.white]! || _isSearching[PieceColor.black]!;
  }

  // TODO: [Leptopoda] make gameMode final and set it through the constructor.
  GameMode _gameMode = GameMode.none;
  GameMode get gameMode => _gameMode;

  set gameMode(GameMode type) {
    _gameMode = type;

    logger.i("$_tag Engine type: $type");

    _isAi = type.whoIsAI;

    logger.i(
      "$_tag White is AI? ${_isAi[PieceColor.white]}\n"
      "$_tag Black is AI? ${_isAi[PieceColor.black]}\n",
    );
  }

  void _select(int pos) {
    focusIndex = pos;
    blurIndex = null;
  }

  Future<bool> _doMove(ExtMove extMove) async {
    assert(MillController().position.phase != Phase.ready);

    logger.i("$_tag AI do move: $extMove");

    if (!(await MillController().position._doMove(extMove.move))) {
      return false;
    }

    sideToMove = MillController().position.sideToMove;

    _logStat();

    return true;
  }

  void _logStat() {
    final int total = MillController().position.score[PieceColor.white]! +
        MillController().position.score[PieceColor.black]! +
        MillController().position.score[PieceColor.draw]!;

    double whiteWinRate = 0;
    double blackWinRate = 0;
    double drawRate = 0;
    if (total != 0) {
      whiteWinRate =
          MillController().position.score[PieceColor.white]! * 100 / total;
      blackWinRate =
          MillController().position.score[PieceColor.black]! * 100 / total;
      drawRate =
          MillController().position.score[PieceColor.draw]! * 100 / total;
    }

    final String scoreInfo =
        "Score: ${MillController().position.score[PieceColor.white]} :"
        " ${MillController().position.score[PieceColor.black]} :"
        " ${MillController().position.score[PieceColor.draw]}\ttotal:"
        " $total\n$whiteWinRate% : $blackWinRate% : $drawRate%\n";

    logger.i("$_tag $scoreInfo");
  }
}
