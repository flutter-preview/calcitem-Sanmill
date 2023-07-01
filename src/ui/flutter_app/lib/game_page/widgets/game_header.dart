// This file is part of Sanmill.
// Copyright (C) 2019-2023 The Sanmill developers (see AUTHORS file)
//
// Sanmill is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Sanmill is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

part of 'game_page.dart';

@visibleForTesting
class GameHeader extends StatefulWidget implements PreferredSizeWidget {
  GameHeader({super.key});

  @override
  final Size preferredSize = Size.fromHeight(
    kToolbarHeight + DB().displaySettings.boardTop + AppTheme.boardMargin,
  );

  @override
  State<GameHeader> createState() => _GameHeaderState();
}

class _GameHeaderState extends State<GameHeader> {
  ScrollNotificationObserverState? _scrollNotificationObserver;
  bool _scrolledUnder = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scrollNotificationObserver != null) {
      _scrollNotificationObserver!.removeListener(_handleScrollNotification);
    }
    _scrollNotificationObserver = ScrollNotificationObserver.of(context);
    if (_scrollNotificationObserver != null) {
      _scrollNotificationObserver!.addListener(_handleScrollNotification);
    }
  }

  @override
  void dispose() {
    if (_scrollNotificationObserver != null) {
      _scrollNotificationObserver!.removeListener(_handleScrollNotification);
      _scrollNotificationObserver = null;
    }
    super.dispose();
  }

  void _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final bool oldScrolledUnder = _scrolledUnder;
      _scrolledUnder = notification.depth == 0 &&
          notification.metrics.extentBefore > 0 &&
          notification.metrics.axis == Axis.vertical;
      if (_scrolledUnder != oldScrolledUnder) {
        setState(() {
          // React to a change in MaterialState.scrolledUnder
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int value =
        GameController().value == null ? 0 : int.parse(GameController().value!);
    value *= 2;
    if (value > 90) {
      value = 90;
    }
    if (value < -90) {
      value = -90;
    }
    final num dividerWhiteLength = 90 + value;
    final num dividerBlackLength = 90 - value;

    final Widget divider = Container(
      height: 2,
      width: 180,
      margin: const EdgeInsets.only(bottom: AppTheme.boardMargin),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 2,
            width: dividerWhiteLength.toDouble(),
            color: DB().colorSettings.whitePieceColor,
          ),
          Container(
            height: 2,
            width: dividerBlackLength.toDouble(),
            color: DB().colorSettings.blackPieceColor,
          ),
        ],
      ),
    );

    final BlockSemantics appBar = BlockSemantics(
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(top: DB().displaySettings.boardTop),
          child: Column(
            children: <Widget>[
              const HeaderIcons(),
              divider,
              const HeaderTip(),
            ],
          ),
        ),
      ),
    );

    return Align(
      alignment: Alignment.topCenter,
      child: appBar,
    );
  }
}

@visibleForTesting
class HeaderTip extends StatefulWidget {
  const HeaderTip({super.key});

  @override
  HeaderTipState createState() => HeaderTipState();
}

class HeaderTipState extends State<HeaderTip> {
  final ValueNotifier<String> _messageNotifier = ValueNotifier<String>("");

  void showTip() {
    final HeaderTipNotifier headerTipNotifier =
        GameController().headerTipNotifier;

    if (headerTipNotifier.showSnackBar) {
      rootScaffoldMessengerKey.currentState!
          .showSnackBarClear(headerTipNotifier.message);
    }

    _messageNotifier.value = headerTipNotifier.message;
  }

  @override
  void initState() {
    super.initState();
    GameController().headerTipNotifier.addListener(showTip);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: _messageNotifier,
      builder: (BuildContext context, String value, Widget? child) {
        return Semantics(
            enabled: true,
            child: SizedBox(
              height: 20 * DB().displaySettings.fontScale,
              child: Text(
                value == "" ? S.of(context).welcome : value,
                maxLines: 1,
                style: TextStyle(
                  color: DB().colorSettings.messageColor,
                  // ignore: always_specify_types
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ));
      },
    );
  }

  @override
  void dispose() {
    GameController().headerTipNotifier.removeListener(showTip);
    super.dispose();
  }
}

@visibleForTesting
class HeaderIcons extends StatefulWidget {
  const HeaderIcons({super.key});

  @override
  HeaderStateIcons createState() => HeaderStateIcons();
}

class HeaderStateIcons extends State<HeaderIcons> {
  final ValueNotifier<IconData> _iconDataNotifier =
      ValueNotifier<IconData>(GameController().gameInstance.sideToMove.icon);

  void showIcons() {
    _iconDataNotifier.value = GameController().gameInstance.sideToMove.icon;
  }

  @override
  void initState() {
    super.initState();
    GameController().headerIconsNotifier.addListener(showIcons);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<IconData>(
      valueListenable: _iconDataNotifier,
      builder: (BuildContext context, IconData value, Widget? child) {
        return IconTheme(
          data: IconThemeData(
            color: DB().colorSettings.messageColor,
          ),
          child: Row(
            key: const Key("HeaderIconRow"),
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Header Icons
              Icon(GameController().gameInstance.gameMode.leftHeaderIcon),
              Icon(value),
              Icon(GameController().gameInstance.gameMode.rightHeaderIcon),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    GameController().headerIconsNotifier.removeListener(showIcons);
    super.dispose();
  }
}
