import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ludo_enums.dart';
import '../models/pawn.dart';
import '../models/player.dart';
import '../models/game_room_model.dart';
import '../logic/ludo_path_provider.dart';
import '../services/online_multiplayer_service.dart';
import '../utils/app_alert.dart';
import '../widgets/winner_dialog.dart';

class LudoController extends GetxController {
  static const String _saveKey = 'saved_ludo_game_v1';

  // Game Configuration
  final Rx<GameMode> _gameMode = GameMode.passAndPlay.obs;
  final RxInt _playerCount = 4.obs;
  final RxList<Player> _players = <Player>[].obs;
  final RxInt _currentTurnIndex = 0.obs;

  // Turn State
  final RxInt _diceValue = 1.obs;
  final RxBool _isDiceRolling = false.obs;
  final RxBool _isDiceRolled = false.obs;
  final RxInt _consecutiveSixes = 0.obs;
  final RxBool _isMoving = false.obs;
  final Rx<GameStateStatus> _gameStatus = GameStateStatus.setup.obs;

  // Selected Pawn for animation/highlighting
  final Rxn<Pawn> _selectedPawn = Rxn<Pawn>();
  final RxList<Pawn> _movablePawns = <Pawn>[].obs;

  // Audio / Sound toggle
  final RxBool _soundEnabled = true.obs;

  // Saved game availability flag
  final RxBool _hasSavedGameAvailable = false.obs;

  // Leaderboard / Winners list
  final RxList<Player> _winners = <Player>[].obs;

  // Online Multiplayer State
  final RxString _onlineRoomCode = ''.obs;
  final RxString _onlineCurrentUid = ''.obs;
  final RxInt _myColorIndex = 0.obs;
  StreamSubscription? _onlineRoomSubscription;

  // Getters
  GameMode get gameMode => _gameMode.value;
  int get playerCount => _playerCount.value;
  List<Player> get players => _players;
  int get currentTurnIndex => _currentTurnIndex.value;
  Player get currentPlayer => _players[_currentTurnIndex.value];
  int get diceValue => _diceValue.value;
  bool get isDiceRolling => _isDiceRolling.value;
  bool get isDiceRolled => _isDiceRolled.value;
  bool get isMoving => _isMoving.value;
  GameStateStatus get gameStatus => _gameStatus.value;
  List<Pawn> get movablePawns => _movablePawns;
  Pawn? get selectedPawn => _selectedPawn.value;
  bool get soundEnabled => _soundEnabled.value;
  bool get hasSavedGameAvailable => _hasSavedGameAvailable.value;
  List<Player> get winners => _winners;

  String get onlineRoomCode => _onlineRoomCode.value;
  String get onlineCurrentUid => _onlineCurrentUid.value;
  int get myColorIndex => _myColorIndex.value;
  bool get isMyTurnInOnlineGame {
    if (_gameMode.value != GameMode.onlineMultiplayer) return true;
    return _currentTurnIndex.value == _myColorIndex.value;
  }

  final Random _random = Random();

  @override
  void onInit() {
    super.onInit();
    checkSavedGameStatus();
  }

  void setGameMode(GameMode mode) {
    _gameMode.value = mode;
    update();
  }

  void setPlayerCount(int count) {
    _playerCount.value = count;
    update();
  }

  void toggleSound() {
    _soundEnabled.value = !_soundEnabled.value;
    update();
  }

  // Check if saved game exists in SharedPreferences
  Future<void> checkSavedGameStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasSavedGameAvailable.value = prefs.containsKey(_saveKey);
      update();
    } catch (_) {
      _hasSavedGameAvailable.value = false;
    }
  }

  // Save current game state locally
  Future<void> saveGameSession() async {
    if (_gameStatus.value != GameStateStatus.playing) return;
    if (_gameMode.value == GameMode.onlineMultiplayer) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final gameData = {
        'gameMode': _gameMode.value.index,
        'playerCount': _playerCount.value,
        'currentTurnIndex': _currentTurnIndex.value,
        'diceValue': _diceValue.value,
        'isDiceRolled': _isDiceRolled.value,
        'consecutiveSixes': _consecutiveSixes.value,
        'players': _players.map((p) => p.toJson()).toList(),
        'winners': _winners.map((p) => p.toJson()).toList(),
      };
      await prefs.setString(_saveKey, jsonEncode(gameData));
      _hasSavedGameAvailable.value = true;
      update();
    } catch (e) {
      debugPrint('Failed to save game session: $e');
    }
  }

  // Restore game state from SharedPreferences
  Future<bool> loadSavedGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_saveKey)) return false;

      final jsonStr = prefs.getString(_saveKey);
      if (jsonStr == null) return false;

      final Map<String, dynamic> data = jsonDecode(jsonStr);

      _gameMode.value = GameMode.values[data['gameMode'] as int];
      _playerCount.value = data['playerCount'] as int;
      _currentTurnIndex.value = data['currentTurnIndex'] as int;
      _diceValue.value = data['diceValue'] as int;
      _isDiceRolled.value = data['isDiceRolled'] as bool? ?? false;
      _consecutiveSixes.value = data['consecutiveSixes'] as int? ?? 0;

      _players.clear();
      final playerList = (data['players'] as List<dynamic>?)
              ?.map((p) => Player.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [];
      _players.addAll(playerList);

      _winners.clear();
      final winnerList = (data['winners'] as List<dynamic>?)
              ?.map((p) => Player.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [];
      _winners.addAll(winnerList);

      _isMoving.value = false;
      _gameStatus.value = GameStateStatus.playing;

      _calculateMovablePawns();
      update();

      if (currentPlayer.isBot && !_isDiceRolled.value) {
        scheduleMicrotask(() => triggerBotTurn());
      }
      return true;
    } catch (e) {
      debugPrint('Failed to load saved game: $e');
      return false;
    }
  }

  // Clear saved game from storage
  Future<void> clearSavedGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_saveKey);
      _hasSavedGameAvailable.value = false;
      update();
    } catch (_) {}
  }

  // Initialize new game session
  void startNewGame({GameMode? mode, int? count, List<String>? customNames}) {
    if (mode != null) _gameMode.value = mode;
    if (count != null) _playerCount.value = count;

    _onlineRoomSubscription?.cancel();
    _onlineRoomCode.value = '';
    clearSavedGame();

    _players.clear();
    _winners.clear();
    _consecutiveSixes.value = 0;
    _isDiceRolled.value = false;
    _isMoving.value = false;
    _diceValue.value = 1;
    _movablePawns.clear();
    _selectedPawn.value = null;

    List<PlayerColor> activeColors = [];
    if (_playerCount.value == 2) {
      activeColors = [PlayerColor.red, PlayerColor.yellow];
    } else if (_playerCount.value == 3) {
      activeColors = [PlayerColor.red, PlayerColor.green, PlayerColor.yellow];
    } else {
      activeColors = [
        PlayerColor.red,
        PlayerColor.green,
        PlayerColor.yellow,
        PlayerColor.blue
      ];
    }

    for (int i = 0; i < activeColors.length; i++) {
      final color = activeColors[i];
      final defaultName = customNames != null && i < customNames.length
          ? customNames[i]
          : '${color.name} Player';
      final isBot = (_gameMode.value == GameMode.vsComputer) && (i > 0);

      _players.add(
        Player(
          color: color,
          name: isBot ? '${color.name} Bot' : defaultName,
          isBot: isBot,
        ),
      );
    }

    _currentTurnIndex.value = 0;
    _gameStatus.value = GameStateStatus.playing;
    saveGameSession();
    update();

    if (currentPlayer.isBot) {
      scheduleMicrotask(() => triggerBotTurn());
    }
  }

  // Online Multiplayer Session Initialization
  void startOnlineGameSession({
    required GameRoom room,
    required String currentUid,
  }) {
    _gameMode.value = GameMode.onlineMultiplayer;
    _onlineRoomCode.value = room.roomCode;
    _onlineCurrentUid.value = currentUid;
    _playerCount.value = room.players.length;

    _players.clear();
    _winners.clear();
    _consecutiveSixes.value = 0;
    _isDiceRolled.value = false;
    _isMoving.value = false;
    _diceValue.value = 1;
    _movablePawns.clear();
    _selectedPawn.value = null;

    final myPlayer = room.players.firstWhere(
      (p) => p.uid == currentUid,
      orElse: () => room.players.first,
    );
    _myColorIndex.value = myPlayer.colorIndex;

    List<PlayerColor> activeColors = [
      PlayerColor.red,
      PlayerColor.green,
      PlayerColor.yellow,
      PlayerColor.blue
    ];

    for (int i = 0; i < room.players.length; i++) {
      final roomP = room.players[i];
      final color = activeColors[roomP.colorIndex];

      _players.add(
        Player(
          color: color,
          name: roomP.name,
          photoUrl: roomP.photoUrl,
          isBot: false,
        ),
      );
    }

    _currentTurnIndex.value = 0;
    _gameStatus.value = GameStateStatus.playing;
    _listenToOnlineRoom();
    update();
  }

  void _listenToOnlineRoom() {
    _onlineRoomSubscription?.cancel();
    if (_onlineRoomCode.value.isEmpty) return;

    _onlineRoomSubscription = OnlineMultiplayerService.streamRoom(_onlineRoomCode.value)
        .listen((room) {
      if (room == null || _gameMode.value != GameMode.onlineMultiplayer) return;

      if (room.gameStateData != null) {
        _applyRemoteStateData(
          room.gameStateData!,
          room.currentTurnIndex,
          room.diceValue,
          room.isDiceRolled,
          room.isMoving,
        );
      }
    });
  }

  void _applyRemoteStateData(
    Map<String, dynamic> stateData,
    int turnIndex,
    int dVal,
    bool dRolled,
    bool moving,
  ) {
    if (_isMoving.value || _isDiceRolling.value) return;

    _currentTurnIndex.value = turnIndex;
    _diceValue.value = dVal;
    _isDiceRolled.value = dRolled;

    if (stateData.containsKey('players')) {
      final playerList = (stateData['players'] as List<dynamic>?)
          ?.map((p) => Player.fromJson(p as Map<String, dynamic>))
          .toList();
      if (playerList != null && playerList.length == _players.length) {
        for (int i = 0; i < _players.length; i++) {
          _players[i].name = playerList[i].name;
          _players[i].photoUrl = playerList[i].photoUrl;
          _players[i].rank = playerList[i].rank;
          for (int j = 0; j < _players[i].pawns.length; j++) {
            _players[i].pawns[j].step = playerList[i].pawns[j].step;
            _players[i].pawns[j].state = playerList[i].pawns[j].state;
          }
        }
      }
    }
    _calculateMovablePawns();
    update();
  }

  void _syncOnlineState() {
    if (_gameMode.value != GameMode.onlineMultiplayer || _onlineRoomCode.value.isEmpty) return;

    final gameStateData = {
      'players': _players.map((p) => p.toJson()).toList(),
    };

    OnlineMultiplayerService.updateGameAction(
      _onlineRoomCode.value,
      currentTurnIndex: _currentTurnIndex.value,
      diceValue: _diceValue.value,
      isDiceRolled: _isDiceRolled.value,
      isMoving: _isMoving.value,
      consecutiveSixes: _consecutiveSixes.value,
      gameStateData: gameStateData,
    );
  }

  // Roll Dice Action
  Future<void> rollDice() async {
    if (_isDiceRolling.value || _isDiceRolled.value || _isMoving.value) return;
    if (_gameStatus.value != GameStateStatus.playing) return;
    if (_gameMode.value == GameMode.onlineMultiplayer && !isMyTurnInOnlineGame) return;

    _isDiceRolling.value = true;
    update();

    for (int i = 0; i < 8; i++) {
      _diceValue.value = _random.nextInt(6) + 1;
      update();
      await Future.delayed(const Duration(milliseconds: 60));
    }

    _diceValue.value = _random.nextInt(6) + 1;
    _isDiceRolling.value = false;
    _isDiceRolled.value = true;
    saveGameSession();
    _syncOnlineState();
    update();

    if (_diceValue.value == 6) {
      _consecutiveSixes.value++;
      if (_consecutiveSixes.value >= 3) {
        AppAlert.showWarning(
          '${currentPlayer.name} rolled three 6s in a row! Turn forfeited.',
          title: '3 Sixes Penalty!',
        );
        await Future.delayed(const Duration(milliseconds: 1000));
        _consecutiveSixes.value = 0;
        nextTurn();
        return;
      }
    } else {
      _consecutiveSixes.value = 0;
    }

    _calculateMovablePawns();

    if (_movablePawns.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 900));
      nextTurn();
    } else if (_movablePawns.length == 1) {
      await Future.delayed(const Duration(milliseconds: 400));
      movePawn(_movablePawns.first);
    } else if (currentPlayer.isBot) {
      await Future.delayed(const Duration(milliseconds: 800));
      _executeBotMove();
    }
  }

  void _calculateMovablePawns() {
    _movablePawns.clear();
    final steps = _diceValue.value;

    for (var pawn in currentPlayer.pawns) {
      if (pawn.isFinished) continue;

      if (pawn.isInBase) {
        if (steps == 6) {
          _movablePawns.add(pawn);
        }
      } else {
        if (pawn.step + steps <= 57) {
          _movablePawns.add(pawn);
        }
      }
    }
    update();
  }

  // Move Pawn
  Future<void> movePawn(Pawn pawn) async {
    if (!_isDiceRolled.value || _isMoving.value) return;
    if (!_movablePawns.contains(pawn)) return;
    if (_gameMode.value == GameMode.onlineMultiplayer && !isMyTurnInOnlineGame) return;

    _isMoving.value = true;
    _selectedPawn.value = null;
    update();

    bool bonusTurnGranted = false;

    if (pawn.isInBase) {
      pawn.step = 1;
      pawn.state = PawnState.onTrack;
      update();
      await Future.delayed(const Duration(milliseconds: 300));
      bonusTurnGranted = true;
    } else {
      final targetStep = pawn.step + _diceValue.value;

      while (pawn.step < targetStep) {
        pawn.step++;
        if (pawn.step >= 52 && pawn.step <= 56) {
          pawn.state = PawnState.inHomePath;
        } else if (pawn.step == 57) {
          pawn.state = PawnState.finished;
        }
        update();
        await Future.delayed(const Duration(milliseconds: 160));
      }

      if (pawn.step == 57) {
        bonusTurnGranted = true;
        _checkPlayerVictory(currentPlayer);
      } else {
        final captured = await _checkAndExecuteCapture(pawn);
        if (captured) {
          bonusTurnGranted = true;
        }
      }
    }

    _isMoving.value = false;

    if (_diceValue.value == 6) {
      bonusTurnGranted = true;
    }

    saveGameSession();

    if (bonusTurnGranted && !currentPlayer.hasWon) {
      _isDiceRolled.value = false;
      _movablePawns.clear();
      _syncOnlineState();
      update();

      if (currentPlayer.isBot) {
        await Future.delayed(const Duration(milliseconds: 800));
        triggerBotTurn();
      }
    } else {
      nextTurn();
    }
  }

  // Capture Logic
  Future<bool> _checkAndExecuteCapture(Pawn attacker) async {
    final attackerCoords = LudoPathProvider.getPawnCoordinates(
        attacker.color, attacker.step, attacker.id);
    final attackerGridPoint = Point(
        attackerCoords.x.round(), attackerCoords.y.round());

    // 1. Safe Tiles (Starting Cells + Star Safe Spots): Immune to capture
    if (LudoPathProvider.isSafeTile(attackerGridPoint)) {
      return false;
    }

    // 2. Only pawns on the common outer track can participate in captures
    if (!attacker.isOnTrack) {
      return false;
    }

    bool capturedAny = false;

    for (var player in _players) {
      if (player.color == attacker.color) continue;

      // Find all opponent pawns of this player on the exact landing cell
      final defendersOnCell = player.pawns.where((defender) {
        if (!defender.isOnTrack) return false;
        final defenderCoords = LudoPathProvider.getPawnCoordinates(
            defender.color, defender.step, defender.id);
        final defenderGridPoint = Point(
            defenderCoords.x.round(), defenderCoords.y.round());
        return attackerGridPoint == defenderGridPoint;
      }).toList();

      // BLOCKADE RULE (Specification Sections 14, 15, 32):
      // If the opponent has 2 or more own tokens on the same cell, they form a blockade.
      // A single attacker token CANNOT capture a blockade of 2+ tokens.
      if (defendersOnCell.length >= 2) {
        AppAlert.showInfo(
          '${player.name} has a 2-token blockade here! Tokens cannot be captured.',
          title: 'Blockade Protected',
        );
        continue;
      }

      // If exactly 1 opponent token is on the cell, capture it
      if (defendersOnCell.length == 1) {
        final defender = defendersOnCell.first;
        defender.reset();
        capturedAny = true;
        update();

        AppAlert.showSuccess(
          '${attacker.color.name} captured ${player.name}\'s token!',
          title: 'Token Captured!',
        );
      }
    }

    return capturedAny;
  }

  void _checkPlayerVictory(Player player) {
    if (player.hasWon && player.rank == null) {
      _winners.add(player);
      player.rank = _winners.length;
      update();

      AppAlert.showSuccess(
        '${player.name} finished in Rank #${player.rank}!',
        title: '🏆 Player Finished!',
      );

      final remainingPlayers = _players.where((p) => !p.hasWon).toList();
      if (remainingPlayers.length <= 1) {
        _gameStatus.value = GameStateStatus.gameOver;
        clearSavedGame();
        update();

        Get.dialog(
          const WinnerDialog(),
          barrierDismissible: false,
        );
      }
    }
  }

  void nextTurn() {
    _isDiceRolled.value = false;
    _movablePawns.clear();
    _selectedPawn.value = null;

    if (_gameStatus.value != GameStateStatus.playing) return;

    int attempts = 0;
    do {
      _currentTurnIndex.value =
          (_currentTurnIndex.value + 1) % _players.length;
      attempts++;
    } while (currentPlayer.hasWon && attempts <= _players.length);

    _consecutiveSixes.value = 0;
    saveGameSession();
    _syncOnlineState();
    update();

    if (currentPlayer.isBot) {
      scheduleMicrotask(() => triggerBotTurn());
    }
  }

  // AI Bot Logic
  Future<void> triggerBotTurn() async {
    if (!currentPlayer.isBot || _isDiceRolling.value || _isMoving.value) return;
    await Future.delayed(const Duration(milliseconds: 600));
    await rollDice();
  }

  void _executeBotMove() {
    if (_movablePawns.isEmpty) return;

    Pawn bestPawn = _movablePawns.first;
    double maxScore = -9999.0;

    for (var pawn in _movablePawns) {
      double score = 0.0;

      if (pawn.isInBase) {
        score += 120.0;
      } else {
        final targetStep = pawn.step + _diceValue.value;

        if (targetStep == 57) {
          score += 200.0;
        }

        final targetCoords = LudoPathProvider.getPawnCoordinates(
            pawn.color, targetStep, pawn.id);
        final targetGridPoint = Point(
            targetCoords.x.round(), targetCoords.y.round());

        if (!LudoPathProvider.isSafeTile(targetGridPoint)) {
          for (var otherPlayer in _players) {
            if (otherPlayer.color == pawn.color) continue;
            for (var oppPawn in otherPlayer.pawns) {
              if (oppPawn.isOnTrack) {
                final oppCoords = LudoPathProvider.getPawnCoordinates(
                    oppPawn.color, oppPawn.step, oppPawn.id);
                final oppGridPoint = Point(
                    oppCoords.x.round(), oppCoords.y.round());
                if (targetGridPoint == oppGridPoint) {
                  score += 250.0;
                }
              }
            }
          }
        }

        if (LudoPathProvider.isSafeTile(targetGridPoint)) {
          score += 80.0;
        }

        score += targetStep * 2.0;
      }

      if (score > maxScore) {
        maxScore = score;
        bestPawn = pawn;
      }
    }

    movePawn(bestPawn);
  }

  @override
  void onClose() {
    _onlineRoomSubscription?.cancel();
    super.onClose();
  }
}
