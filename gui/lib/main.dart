import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:reboot_common/common.dart';
import 'package:reboot_launcher/src/controller/matchmaker_controller.dart';
import 'package:reboot_launcher/src/controller/update_controller.dart';
import 'package:reboot_launcher/src/dialog/abstract/info_bar.dart';
import 'package:reboot_launcher/src/dialog/implementation/error.dart';
import 'package:reboot_launcher/src/controller/build_controller.dart';
import 'package:reboot_launcher/src/controller/game_controller.dart';
import 'package:reboot_launcher/src/controller/hosting_controller.dart';
import 'package:reboot_launcher/src/controller/authenticator_controller.dart';
import 'package:reboot_launcher/src/controller/settings_controller.dart';
import 'package:reboot_launcher/src/dialog/implementation/server.dart';
import 'package:reboot_launcher/src/page/home_page.dart';
import 'package:reboot_launcher/src/util/watch.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:system_theme/system_theme.dart';
import 'package:url_protocol/url_protocol.dart';
import 'package:window_manager/window_manager.dart';

const double kDefaultWindowWidth = 1536;
const double kDefaultWindowHeight = 1024;
const String kCustomUrlSchema = "reboot";

void main() async {
  runZonedGuarded(() async {
    await installationDirectory.create(recursive: true);
    await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey
    );
    WidgetsFlutterBinding.ensureInitialized();
    await SystemTheme.accentColor.load();
    var storageError = await _initStorage();
    var urlError = await _initUrlHandler();
    var windowError = await _initWindow();
    var observerError = _initObservers();
    runApp(const RebootApplication());
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) => _handleErrors([urlError, storageError, windowError, observerError]));
  },
  (error, stack) => onError(error, stack, false),
  zoneSpecification: ZoneSpecification(
      handleUncaughtError: (self, parent, zone, error, stacktrace) => onError(error, stacktrace, false)
  ));
}

void _handleErrors(List<Object?> errors) => errors.where((element) => element != null).forEach((element) => onError(element, null, false));

Future<Object?> _initUrlHandler() async {
  try {
    registerProtocolHandler(kCustomUrlSchema, arguments: ['%s']);
    var appLinks = AppLinks();
    var initialUrl = await appLinks.getInitialAppLink();
    if(initialUrl != null) {
      _joinServer(initialUrl);
    }

    appLinks.uriLinkStream.listen(_joinServer);
    return null;
  }catch(error) {
    return error;
  }
}

void _joinServer(Uri uri) {
  var gameController = Get.find<GameController>();
  var matchmakerController = Get.find<MatchmakerController>();
  var uuid = _parseCustomUrl(uri);
  var server = gameController.findServerById(uuid);
  if(server != null) {
    matchmakerController.joinServer(server);
  }else {
    showInfoBar(
        "No server found: invalid or expired link",
        duration: snackbarLongDuration,
        severity: InfoBarSeverity.error
    );
  }
}

String _parseCustomUrl(Uri uri) => uri.host;

Future<Object?> _initWindow() async {
  try {
    await windowManager.ensureInitialized();
    await Window.initialize();
    var settingsController = Get.find<SettingsController>();
    var size = Size(settingsController.width, settingsController.height);
    appWindow.size = size;
    var offsetX = settingsController.offsetX;
    var offsetY = settingsController.offsetY;
    if(offsetX != null && offsetY != null){
      appWindow.position = Offset(
          offsetX,
          offsetY
      );
    }else {
      appWindow.alignment = Alignment.center;
    }

    await Window.setEffect(
      effect: WindowEffect.acrylic,
      color: Colors.transparent,
      dark: true
    );
    return null;
  }catch(error) {
    return error;
  }
}

Object? _initObservers() {
  try {
    var gameController = Get.find<GameController>();
    var gameInstance = gameController.instance.value;
    gameInstance?.startObserver();
    gameController.saveInstance();
    var hostingController = Get.find<HostingController>();
    var hostingInstance = hostingController.instance.value;
    hostingInstance?.startObserver();
    hostingController.saveInstance();
    return null;
  }catch(error) {
    return error;
  }
}

Future<Object?> _initStorage() async {
  try {
    await GetStorage("reboot_game", settingsDirectory.path).initStorage;
    await GetStorage("reboot_authenticator", settingsDirectory.path).initStorage;
    await GetStorage("reboot_matchmaker", settingsDirectory.path).initStorage;
    await GetStorage("reboot_update", settingsDirectory.path).initStorage;
    await GetStorage("reboot_settings", settingsDirectory.path).initStorage;
    await GetStorage("reboot_hosting", settingsDirectory.path).initStorage;
    Get.put(GameController());
    Get.put(AuthenticatorController());
    Get.put(MatchmakerController());
    Get.put(BuildController());
    Get.put(SettingsController());
    Get.put(HostingController());
    var updateController = UpdateController();
    Get.put(updateController);
    updateController.update();
    return null;
  }catch(error) {
    return error;
  }
}

class RebootApplication extends StatefulWidget {
  const RebootApplication({Key? key}) : super(key: key);

  @override
  State<RebootApplication> createState() => _RebootApplicationState();
}

class _RebootApplicationState extends State<RebootApplication> {
  @override
  Widget build(BuildContext context) => FluentApp(
      title: "Reboot Launcher",
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      color: SystemTheme.accentColor.accent.toAccentColor(),
      darkTheme: _createTheme(Brightness.dark),
      theme: _createTheme(Brightness.light),
      home: const HomePage()
  );

  FluentThemeData _createTheme(Brightness brightness) => FluentThemeData(
      brightness: brightness,
      accentColor: SystemTheme.accentColor.accent.toAccentColor(),
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: Colors.transparent
  );
}