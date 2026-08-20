import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sb_audio_manager.dart';

class SbShopData extends ChangeNotifier {
  double _credits;
  final double _initialCredits;
  int _bet;
  final List<Map<String, dynamic>> _items;

  final List<String> _gameSymbols = [
    'assets/sweet_bonanza/images/symbols/symbol1.png',
    'assets/sweet_bonanza/images/symbols/symbol2.png',
    'assets/sweet_bonanza/images/symbols/symbol3.png',
    'assets/sweet_bonanza/images/symbols/symbol4.png',
    'assets/sweet_bonanza/images/symbols/symbol5.png',
    'assets/sweet_bonanza/images/symbols/symbol6.png',
    'assets/sweet_bonanza/images/symbols/symbol7.png',
    'assets/sweet_bonanza/images/symbols/symbol8.png',
    'assets/sweet_bonanza/images/symbols/symbol9.png',
  ];

  bool _ambientMusicOn;
  bool _soundFxOn;

  final SbAudioManager _audioManager = SbAudioManager();
  SbAudioManager get audioManager => _audioManager;

  SbShopData({double initialCoins = 842})
      : _credits = initialCoins,
        _initialCredits = initialCoins,
        _bet = 100,
        _ambientMusicOn = true,
        _soundFxOn = true,
        _items = <Map<String, dynamic>>[
          {
            'name': 'Candy Land',
            'image': 'assets/sweet_bonanza/images/backgrounds/candyice.webp',
            'owned': true,
            'selected': false,
            'price': null,
            'showFruits': true,
          },
          {
            'name': 'Enchanted Confection',
            'image': 'assets/sweet_bonanza/images/backgrounds/candycream.webp',
            'owned': true,
            'selected': true,
            'price': null,
          },
          {
            'name': 'Sugarpunk Forge',
            'image': 'assets/sweet_bonanza/images/backgrounds/candyhot.webp',
            'owned': true,
            'selected': false,
            'price': null,
            'showClouds': true,
          },
          {
            'name': 'Candy Cybercore',
            'image': 'assets/sweet_bonanza/images/backgrounds/candychristmas.webp',
            'owned': false,
            'price': 1600,
          },
          {
            'name': 'Sweet Ruins',
            'image': 'assets/sweet_bonanza/images/backgrounds/candygate.webp',
            'owned': false,
            'price': 2300,
          },
          {
            'name': 'Licorice Noir',
            'image': 'assets/sweet_bonanza/images/backgrounds/candydonut.webp',
            'owned': false,
            'price': 2700,
          },
          {
            'name': 'Jullyverse',
            'image': 'assets/sweet_bonanza/images/backgrounds/friendsbg.webp',
            'owned': false,
            'price': 3100,
          },
          {
            'name': 'Kingdom of Crumble',
            'image': 'assets/sweet_bonanza/images/backgrounds/candyparadise.webp',
            'owned': false,
            'price': 4000,
          },
          {
            'name': 'Neon Nougat Nexus',
            'image': 'assets/sweet_bonanza/images/backgrounds/candyfruits.webp',
            'owned': false,
            'price': 4200,
          },
          {
            'name': 'Deep Sugar Reef',
            'image': 'assets/sweet_bonanza/images/backgrounds/pinkbg.webp',
            'owned': false,
            'price': 5000,
          },
          {
            'name': 'Frosted Hollow',
            'image': 'assets/sweet_bonanza/images/backgrounds/fruitsbg.webp',
            'owned': false,
            'showClouds': true,
            'price': 5500,
          },
          {
            'name': 'Creamy Fruits',
            'image': 'assets/sweet_bonanza/images/backgrounds/candybg.webp',
            'owned': false,
            'showFruits': true,
            'price': 7000,
          },
        ];

  double get credits => _credits;
  int get bet => _bet;
  double _lastWin = 0;
  double get lastWin => _lastWin;
  List<Map<String, dynamic>> get items => _items;
  List<String> get gameSymbols => _gameSymbols;
  bool get ambientMusicOn => _ambientMusicOn;
  bool get soundFxOn => _soundFxOn;

  /// Net coin change since game was opened (positive = win, negative = loss).
  int get netChange => (_credits - _initialCredits).round();

  String get selectedBackgroundImage =>
      _selectedItem?['image'] as String? ??
      'assets/sweet_bonanza/images/backgrounds/candybg.webp';
  bool get showClouds => _selectedItem?['showClouds'] == true;
  bool get showFruits => _selectedItem?['showFruits'] == true;

  Map<String, dynamic>? get _selectedItem {
    try {
      return _items.firstWhere(
        (item) => item['selected'] == true && item['owned'] == true,
        orElse: () => _items.firstWhere((item) => item['owned'] == true),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> loadEconomy() async {
    final prefs = await SharedPreferences.getInstance();
    _bet = prefs.getInt('sb_bet') ?? 100;
    notifyListeners();
  }

  Future<void> _saveBet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sb_bet', _bet);
  }

  void increaseBet() {
    if (_bet == 1) { _bet = 5; }
    else if (_bet == 5) { _bet = 10; }
    else if (_bet == 10) { _bet = 25; }
    else if (_bet == 25) { _bet = 50; }
    else if (_bet == 50) { _bet = 100; }
    _saveBet();
    notifyListeners();
  }

  void decreaseBet() {
    if (_bet == 100) { _bet = 50; }
    else if (_bet == 50) { _bet = 25; }
    else if (_bet == 25) { _bet = 10; }
    else if (_bet == 10) { _bet = 5; }
    else if (_bet == 5) { _bet = 1; }
    _saveBet();
    notifyListeners();
  }

  void spinGame() {
    if (_credits >= _bet) {
      _credits -= _bet;
      _lastWin = 0;
      notifyListeners();
    }
  }

  void winCredits(double amount) {
    _credits += amount;
    _lastWin = amount;
    notifyListeners();
  }

  void toggleAmbientMusic() {
    _ambientMusicOn = !_ambientMusicOn;
    if (_ambientMusicOn) {
      _audioManager.toggleMusic(true);
      _audioManager.playBackgroundMusic('assets/sweet_bonanza/sound/sweet_music.mp3');
    } else {
      _audioManager.toggleMusic(false);
    }
    notifyListeners();
  }

  void toggleSoundFx() {
    _soundFxOn = !_soundFxOn;
    _audioManager.toggleSound(_soundFxOn);
    notifyListeners();
  }

  void playTapSound() {
    if (_soundFxOn) _audioManager.playSfx('assets/sweet_bonanza/sound/button_tap.mp3');
  }

  void playWheelSpinSound() {
    if (_soundFxOn) _audioManager.playSfx('assets/sweet_bonanza/sound/playing_wheel.mp3');
  }

  void playWheelStopSound() {
    if (_soundFxOn) _audioManager.playSfx('assets/sweet_bonanza/sound/stop_wheel.mp3');
  }

  void playSymbolSound() {
    if (_soundFxOn) _audioManager.playSfx('assets/sweet_bonanza/sound/playing_symbol.mp3');
  }

  void playBackgroundMusic(String path) {
    if (_ambientMusicOn && !_audioManager.isMusicPlaying) {
      _audioManager.playBackgroundMusic(path);
    }
  }

  Future<void> loadAudioSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _ambientMusicOn = prefs.getBool('sb_ambientMusic') ?? true;
    _soundFxOn = prefs.getBool('sb_soundFx') ?? true;
    _audioManager.toggleSound(_soundFxOn);
    _audioManager.toggleMusic(_ambientMusicOn);
    notifyListeners();
  }

  void buyItem(int index) {
    if (index >= 0 && index < _items.length) {
      final item = _items[index];
      final int? price = item['price'];
      if (price != null && !item['owned'] && _credits >= price) {
        _credits -= price;
        item['owned'] = true;
        item['price'] = null;
        notifyListeners();
      }
    }
  }

  void selectItem(int index) {
    if (index >= 0 && index < _items.length) {
      final item = _items[index];
      if (item['owned'] == true) {
        for (final i in _items) {
          i['selected'] = false;
        }
        item['selected'] = true;
        notifyListeners();
      }
    }
  }
}
