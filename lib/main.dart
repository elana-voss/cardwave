import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:cardwave/app_router.dart';
import 'package:cardwave/app_routes_enum.dart';
import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/group/group.dart';
import 'package:cardwave/memory/memory.dart';
import 'package:cardwave/nodes/nodes.dart';
import 'package:cardwave_nodes/cardwave_nodes.dart' as cwn;
import 'package:cardwave_names/cardwave_names.dart';
import 'package:cardwave/search/search.dart';
import 'package:cardwave/search/src/repositories/search_repository.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:cardwave_memory/cardwave_memory.dart' show MemoryDiagnosticEvent;
import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

part 'app_bootstrapper.dart';
part 'my_app.dart';

void main() {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  // Loads the libmpv native backend used by `VideoPlayerInline` and the
  // video-test preview dialog. Must run before any `Player` is constructed
  // or the first `Player()` on Windows/Linux throws a missing-plugin error.
  MediaKit.ensureInitialized();
  // Surface llamadart's Dart-side log records to stdout so model-load
  // events (path, success/failure) and backend-load diagnostics appear in
  // the running console. Native llama.cpp logs (load_tensors offload
  // counts, vulkan device discovery) come from the worker isolate's own
  // default log level — that side is configured per-engine.
  if (kDebugMode) {
    LlamaEngine.configureLogging(level: LlamaLogLevel.info);
  }
  runApp(const AppBootstrapper());
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  bool _initialized = false;
  String? _error;

  late final LoggingService _loggingService;
  late final SettingsService _settingsService;
  late final LlmModelRepository _llmModelRepository;
  late final TaxonomyRepository _taxonomyRepository;
  late final CharacterRepository _characterRepository;
  late final ChatRepository _chatRepository;
  late final PromptRepository _promptRepository;
  late final NavigationService _navigationService;
  late final AppStorage _appStorage;
  late final ThemeNotifier _settingsDisplay;
  late final CharacterService _characterService;
  late final ChatService _chatService;
  late final ChatExecutionService _chatExecutionService;
  late final ToolRegistry _toolRegistry;
  late final ToolDispatcher _toolDispatcher;
  late final NameDatabase _nameDatabase;
  late final ImageGenerationService _imageGenerationService;
  late final CharacterAiService _characterAiService;
  late final LlmPureHelpers _pureHelpers;
  late final LlmManagementService _llmManagementService;
  late final SearchService _searchService;
  late final TextToSpeechService _textToSpeechService;
  late final TextToSpeechController _textToSpeechController;
  late final VideoGenerationService _videoGenerationService;
  late final VideoGenerationController _videoGenerationController;
  late final VideoPromptBuilder _videoPromptBuilder;
  late final CardwaveLlmModule _cardwaveLlmModule;
  late final CardwaveEmbeddingsModule _cardwaveEmbeddingsModule;
  late final MemoryService _memoryService;
  late final CardwaveMemoryModule _cardwaveMemoryModule;
  late final NodesService _nodesService;
  late final CardwaveNodesModule _cardwaveNodesModule;
  late final GroupRepository _groupRepository;
  late final GroupFileService _groupFileService;
  late final GroupChatService _groupChatService;
  late final GroupPromptService _groupPromptService;

  @override
  void initState() {
    super.initState();
    unawaited(_initServices());
  }

  // `bool.fromEnvironment` only accepts the literal strings "true"/"false" —
  // `--dart-define=FRESH=1` would silently evaluate to false. Use String
  // detection so any non-empty value activates the flag.
  static const bool _freshReset =
      bool.hasEnvironment('FRESH') &&
      String.fromEnvironment('FRESH') != '' &&
      String.fromEnvironment('FRESH') != 'false' &&
      String.fromEnvironment('FRESH') != '0';

  /// Debug-only fresh reset: wipes the app data folder and the in-character
  /// cache subfolder so the next launch starts at onboarding. The user's
  /// character folder itself and any PNG/JSON files inside it are never
  /// touched. Release builds ignore this flag entirely.
  ///
  /// Activated by launching with `--dart-define=FRESH=1` (see the
  /// "Flutter Windows (Debug & Fresh)" entry in `.vscode/launch.json`).
  Future<void> _maybeFreshReset(String appDataPath) async {
    if (!kDebugMode || !_freshReset) return;

    debugPrint('[FRESH] resetting app state');

    // 1. Read settings.json directly (without booting SettingsService) to
    //    discover the user's character folder, so we can wipe its cache
    //    subfolder before deleting the settings file itself.
    final settingsFile = File(
      '$appDataPath${Platform.pathSeparator}${AppConstants.settingsFileName}',
    );
    String? characterPath;
    if (settingsFile.existsSync()) {
      try {
        final map =
            jsonDecode(await settingsFile.readAsString())
                as Map<String, dynamic>;
        characterPath = map['character_path'] as String?;
      } on Exception catch (e) {
        debugPrint('[FRESH] failed to read settings.json: $e');
      }
    }

    if (characterPath != null && characterPath.isNotEmpty) {
      final cacheRoot = Directory(
        '$characterPath${Platform.pathSeparator}${AppConstants.customCacheRootPath}',
      );
      if (cacheRoot.existsSync()) {
        debugPrint('[FRESH] deleting cache: ${cacheRoot.path}');
        await cacheRoot.delete(recursive: true);
      }
    }

    final appDataDir = Directory(appDataPath);
    if (appDataDir.existsSync()) {
      debugPrint('[FRESH] deleting app data: ${appDataDir.path}');
      await appDataDir.delete(recursive: true);
    }
  }

  Future<void> _initServices() async {
    try {
      _loggingService = LoggingService();
      _loggingService.captureUnhandledErrors();

      // Routes typed events from the LLM, embeddings, and memory domains to
      // LoggingService.
      Logger.root.level = Level.ALL;
      // App-lifetime logging subscription — never cancelled.
      // ignore: qcheck/avoid_unassigned_stream_subscriptions
      Logger.root.onRecord.listen((record) {
        if (!record.loggerName.startsWith('cardwave.')) return;
        final obj = record.object;
        if (obj is LlmStructuredEvent) {
          _loggingService.logLlm(
            '[${obj.category.label}] ${obj.title}',
            obj.body,
          );
        } else if (obj is LlmDiagnosticEvent) {
          _routeDiag(
            obj.level.name,
            obj.message,
            obj.error,
            obj.stackTrace,
            obj.dataContext,
          );
        } else if (obj is LlmCacheEvent) {
          _loggingService.logCache(obj.message);
        } else if (obj is EmbeddingsDiagnosticEvent) {
          _routeDiag(
            obj.level.name,
            obj.message,
            obj.error,
            obj.stackTrace,
            obj.dataContext,
          );
        } else if (obj is MemoryDiagnosticEvent) {
          _routeDiag(
            obj.level.name,
            obj.message,
            obj.error,
            obj.stackTrace,
            obj.dataContext,
          );
        } else if (obj is cwn.FiringLogEvent) {
          // NODES engine firings — surfaced into the same log viewer as
          // memory/embeddings/LLM so the spec §10 firing-roll log is
          // reachable without a dedicated debug panel. `[NODES]` prefix
          // makes the entries grep-friendly in the viewer's search box.
          switch (obj) {
            case cwn.NodeFiredEvent(:final turn, :final nodeId, :final narrativePayload):
              _loggingService.info(
                '[NODES] turn $turn: fired "$nodeId" → $narrativePayload',
              );
            case cwn.NodeRolledEvent(
                  :final turn,
                  :final nodeId,
                  :final triggerProb,
                  :final pressure,
                  :final draw,
                  :final won,
                ):
              _loggingService.debug(
                '[NODES] turn $turn: rolled "$nodeId" '
                'prob=${triggerProb.toStringAsFixed(2)} '
                '+ pressure=${pressure.toStringAsFixed(2)} '
                'draw=${draw.toStringAsFixed(2)} → ${won ? "won" : "lost"}',
              );
            case cwn.NodeSkippedEvent(:final turn, :final nodeId, :final reason):
              _loggingService.debug(
                '[NODES] turn $turn: skipped "$nodeId" (${reason.name})',
              );
          }
        }
      });

      final nativeDataPath =
          await getNativeAppDataPath(AppConstants.appPackageName);

      await _maybeFreshReset(nativeDataPath);

      _settingsService = SettingsService();
      await _settingsService.init(nativeDataPath);

      UtilsLlm.warmUp();

      _appStorage = AppStorage.instance;
      _llmModelRepository = LlmModelRepository();

      _taxonomyRepository = TaxonomyRepository(loggingService: _loggingService);
      await _taxonomyRepository.init();

      _characterRepository = CharacterRepository(
        loggingService: _loggingService,
        appStorage: _appStorage,
      );
      _chatRepository = ChatRepository(
        loggingService: _loggingService,
        appStorage: _appStorage,
      );
      _promptRepository = PromptRepository();
      _nameDatabase = NameDatabase();
      await _promptRepository.init();

      _navigationService = NavigationService();

      _pureHelpers = LlmPureHelpers(repository: _llmModelRepository);
      _llmManagementService = LlmManagementService(pureHelpers: _pureHelpers);

      _cardwaveEmbeddingsModule = CardwaveEmbeddingsModule();
      _searchService = SearchService(
        repository: SearchRepository(appStorage: _appStorage),
        embedder: _cardwaveEmbeddingsModule.embedder,
      );
      unawaited(_searchService.initEmbedder());
      unawaited(_logLlamadartBackendStatus());

      _memoryService = MemoryService(
        repository: MemoryRepository(
          loggingService: _loggingService,
          appStorage: _appStorage,
        ),
        embedder: _cardwaveEmbeddingsModule.embedder,
        settingsService: _settingsService,
        loggingService: _loggingService,
        pureHelpers: _pureHelpers,
      );
      _cardwaveMemoryModule = CardwaveMemoryModule(
        memoryService: _memoryService,
      );

      _nodesService = NodesService(
        repository: NodesRepository(
          loggingService: _loggingService,
          appStorage: _appStorage,
        ),
        embedder: _cardwaveEmbeddingsModule.embedder,
        loggingService: _loggingService,
        settingsService: _settingsService,
        pureHelpers: _pureHelpers,
      );
      _cardwaveNodesModule = CardwaveNodesModule(
        nodesService: _nodesService,
      );

      _textToSpeechService = const TextToSpeechService();
      _textToSpeechController = TextToSpeechController(
        ttsService: _textToSpeechService,
        pureHelpers: _pureHelpers,
        chatRepository: _chatRepository,
      );

      _maybeRunDailyModelRefresh();
      _populateModelOptionsOnStartup();

      _settingsDisplay = ThemeNotifier();
      _settingsDisplay.themeMode = _settingsService.settings.themeMode;

      _characterService = CharacterService(
        characterRepository: _characterRepository,
        chatRepository: _chatRepository,
        settingsService: _settingsService,
        appStorage: _appStorage,
        loggingService: _loggingService,
        searchService: _searchService,
      );
      _searchService.init(_characterService);

      _chatService = ChatService(
        chatRepository: _chatRepository,
        settingsService: _settingsService,
        characterService: _characterService,
        pureHelpers: _pureHelpers,
      );

      _videoGenerationService = VideoGenerationService(
        promptRepository: _promptRepository,
      );
      _videoGenerationController = VideoGenerationController(
        videoService: _videoGenerationService,
        chatRepository: _chatRepository,
      );

      _videoPromptBuilder = VideoPromptBuilder(
        pureHelpers: _pureHelpers,
        promptRepository: _promptRepository,
      );

      // The tools' lifecycle is owned by ToolRegistry, which disposes every
      // registered tool in its own `dispose()`; the registry is app-lifetime.
      _toolRegistry = ToolRegistry(promptRepository: _promptRepository)
        ..register(
          // ignore: qcheck/avoid_undisposed_instances
          SendSelfieTool(
            promptRepository: _promptRepository,
            maxCallsPerTurn: AppConstants.toolSendSelfieMaxPerTurn,
          ),
        )
        ..register(
          // ignore: qcheck/avoid_undisposed_instances
          SendVideoTool(
            promptRepository: _promptRepository,
            maxCallsPerTurn: AppConstants.toolSendVideoMaxPerTurn,
          ),
        )
        ..register(
          // ignore: qcheck/avoid_undisposed_instances
          FetchWebsiteTool(
            promptRepository: _promptRepository,
            maxCallsPerTurn: AppConstants.toolFetchWebsiteMaxPerTurn,
            requestTimeout: AppConstants.toolFetchWebsiteTimeout,
            maxBodyBytes: AppConstants.toolFetchWebsiteMaxBodyBytes,
            maxResponseChars: AppConstants.toolFetchWebsiteMaxResponseChars,
          ),
        )
        ..register(
          // ignore: qcheck/avoid_undisposed_instances
          SuggestNameTool(
            promptRepository: _promptRepository,
            maxCallsPerTurn: AppConstants.toolSuggestNameMaxPerTurn,
            nameDatabase: _nameDatabase,
          ),
        )
        ..register(
          // ignore: qcheck/avoid_undisposed_instances
          const CardFieldGetTool(
            maxCallsPerTurn: AppConstants.toolCardFieldGetMaxPerTurn,
          ),
        )
        ..register(
          // ignore: qcheck/avoid_undisposed_instances
          const CardFieldSetTool(
            maxCallsPerTurn: AppConstants.toolCardFieldSetMaxPerTurn,
          ),
        )
        ..register(
          // ignore: qcheck/avoid_undisposed_instances
          const CardFieldListGetTool(
            maxCallsPerTurn: AppConstants.toolCardFieldListGetMaxPerTurn,
          ),
        )
        ..register(
          // ignore: qcheck/avoid_undisposed_instances
          const CardFieldListSetTool(
            maxCallsPerTurn: AppConstants.toolCardFieldListSetMaxPerTurn,
          ),
        )
        ..register(
          // ignore: qcheck/avoid_undisposed_instances
          const CardFieldListAppendTool(
            maxCallsPerTurn: AppConstants.toolCardFieldListAppendMaxPerTurn,
          ),
        )
        ..register(
          // ignore: qcheck/avoid_undisposed_instances
          const CardFieldListDeleteTool(
            maxCallsPerTurn: AppConstants.toolCardFieldListDeleteMaxPerTurn,
          ),
        );
      _toolDispatcher = ToolDispatcher(registry: _toolRegistry);

      _chatExecutionService = ChatExecutionService(
        pureHelpers: _pureHelpers,
        settingsService: _settingsService,
        chatService: _chatService,
        promptRepository: _promptRepository,
        toolRegistry: _toolRegistry,
        memoryService: _memoryService,
        nodesService: _nodesService,
      );

      _imageGenerationService = ImageGenerationService(
        pureHelpers: _pureHelpers,
        promptRepository: _promptRepository,
      );

      // Bundle the package's stateless services so the app can hand the
      // module to MCP wrappers / future invoke surfaces. The fields stay
      // independently registered so existing callers keep their typed
      // dependencies — the module is additive.
      _cardwaveLlmModule = CardwaveLlmModule(
        pureHelpers: _pureHelpers,
        modelRepository: _llmModelRepository,
        promptRepository: _promptRepository,
        imageGenerationService: _imageGenerationService,
        videoGenerationService: _videoGenerationService,
        videoPromptBuilder: _videoPromptBuilder,
        textToSpeechService: _textToSpeechService,
        toolRegistry: _toolRegistry,
      );

      _characterAiService = CharacterAiService(
        settingsService: _settingsService,
        promptRepository: _promptRepository,
        characterService: _characterService,
        taxonomyRepository: _taxonomyRepository,
        loggingService: _loggingService,
        pureHelpers: _pureHelpers,
      );

      _groupRepository = GroupRepository(
        loggingService: _loggingService,
        appStorage: _appStorage,
      );
      _groupFileService = GroupFileService(groupRepository: _groupRepository);
      _groupChatService = GroupChatService(
        ioChat: IOChat(
          loggingService: _loggingService,
          appStorage: _appStorage,
        ),
      );
      _groupPromptService = GroupPromptService();

      if (mounted) {
        setState(() {
          _initialized = true;
        });
        FlutterNativeSplash.remove();
      }
    } on Exception catch (e, stack) {
      debugPrint('Initialization error: $e\n$stack');
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
        FlutterNativeSplash.remove();
      }
    }
  }

  /// Populates `optionsTts` and `optionsVideo` on every capable model in
  /// every configured provider. Runs silently at startup so a model
  /// adopted in a prior session — before the app knew how to fetch its
  /// per-model rosters — is fully usable without the user having to hit
  /// "Refresh". Cheap: most providers return hardcoded lists; only Grok
  /// TTS actually hits the network. Profiles run in parallel so one slow
  /// voice fetch doesn't block the others.
  void _populateModelOptionsOnStartup() {
    final settings = _settingsService.settings;
    unawaited(() async {
      await Future.wait([
        for (final profile in settings.providerConfigs)
          _populateProviderMediaOptions(profile),
      ]);
      await _settingsService.saveSettings();
    }());
  }

  Future<void> _populateProviderMediaOptions(LlmProviderConfig profile) async {
    try {
      await _pureHelpers.populateTtsVoices(profile);
      _pureHelpers.populateVideoOptions(profile);
      _pureHelpers.populateImageOptions(profile);
    } on Exception catch (e, st) {
      _loggingService.error(
        'Startup model-option enrichment failed for '
        '${profile.providerEnum.name}',
        e,
        st,
      );
    }
  }

  /// Prints (once, at startup) the list of llamadart backend modules
  /// available on this machine and the backend the embedder loaded onto.
  /// Used to disambiguate "model loads to RAM" between three failure
  /// modes: the vulkan DLL is not detected as a module (available list
  /// has no Vulkan), the DLL is detected but no device is reachable
  /// (embedder also falls back to CPU), or the runtime sees Vulkan but
  /// the localGguf path declines it (embedder is on Vulkan, only the
  /// localGguf model is on CPU).
  Future<void> _logLlamadartBackendStatus() async {
    // Banner makes the probe trivially greppable in long startup logs.
    debugPrint('===== [llamadart] backend probe (start) =====');
    try {
      final embedder = _cardwaveEmbeddingsModule.embedder;
      await embedder.init();
      final backend = embedder.backend;
      if (backend == null) {
        debugPrint('[llamadart] backend probe: embedder backend is null');
        return;
      }
      final active = await backend.getBackendName();
      final available = backend is BackendAvailability
          ? await (backend as BackendAvailability).getAvailableBackends()
          : 'unavailable';
      final layers = backend is BackendRuntimeDiagnostics
          ? await (backend as BackendRuntimeDiagnostics).getResolvedGpuLayers()
          : null;
      debugPrint(
        '[llamadart] available backends: $available; '
        'embedder loaded on: $active (gpu layers: $layers)',
      );
    } on Exception catch (e, st) {
      debugPrint('[llamadart] backend probe failed: $e\n$st');
    }
    debugPrint('===== [llamadart] backend probe (end) =====');
  }

  /// Fans the four diagnostic-level enum members from any package out to
  /// the matching `LoggingService` method. Both `LlmDiagnosticLevel` and
  /// `EmbeddingsDiagnosticLevel` use the same four `.name` strings.
  void _routeDiag(
    String levelName,
    String message,
    Object? error,
    StackTrace? stackTrace,
    String? dataContext,
  ) {
    switch (levelName) {
      case 'info':
        _loggingService.info(message);
      case 'debug':
        _loggingService.debug(message);
      case 'warning':
        _loggingService.warning(message, error, stackTrace);
      case 'error':
        _loggingService.error(message, error, stackTrace, dataContext);
    }
  }

  void _maybeRunDailyModelRefresh() {
    final settings = _settingsService.settings;
    if (settings.refreshPolicy != ModelRefreshPolicyEnum.daily) return;
    final last = settings.lastModelRefreshAtMillis;
    if (last != null) {
      final age = DateTime.now().millisecondsSinceEpoch - last;
      if (age < AppConstants.modelRefreshIntervalDaily.inMilliseconds) return;
    }
    unawaited(() async {
      try {
        await _llmManagementService.refreshAdoptedModelMetadata(
          settings: settings,
          trigger: ModelRefreshTriggerEnum.startupDaily,
        );
        await _settingsService.saveSettings();
      } on Exception catch (e, st) {
        _loggingService.error('Startup model refresh failed', e, st);
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: compactLightTheme,
        darkTheme: compactDarkTheme,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Failed to initialize app:\n\n$_error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    if (!_initialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: compactLightTheme,
        darkTheme: compactDarkTheme,
        home: const Scaffold(body: SizedBox.shrink()),
      );
    }

    return MultiProvider(
      providers: [
        Provider<LoggingService>.value(value: _loggingService),
        ChangeNotifierProvider<SettingsService>.value(value: _settingsService),
        Provider<LlmModelRepository>.value(value: _llmModelRepository),
        Provider<CharacterRepository>.value(value: _characterRepository),
        Provider<ChatRepository>.value(value: _chatRepository),
        Provider<PromptRepository>.value(value: _promptRepository),
        Provider<TaxonomyRepository>.value(value: _taxonomyRepository),
        Provider<NavigationService>.value(value: _navigationService),
        Provider<AppStorage>.value(value: _appStorage),
        ChangeNotifierProvider<ThemeNotifier>.value(value: _settingsDisplay),
        ChangeNotifierProvider<CharacterService>.value(
          value: _characterService,
        ),
        ChangeNotifierProvider<ChatService>.value(value: _chatService),
        Provider<ChatExecutionService>.value(value: _chatExecutionService),
        Provider<ToolRegistry>.value(value: _toolRegistry),
        Provider<ToolDispatcher>.value(value: _toolDispatcher),
        Provider<ImageGenerationService>.value(
          value: _imageGenerationService,
        ),
        ChangeNotifierProvider<CharacterAiService>.value(
          value: _characterAiService,
        ),
        Provider<LlmPureHelpers>.value(value: _pureHelpers),
        Provider<LlmManagementService>.value(value: _llmManagementService),
        Provider<Embedder>.value(value: _cardwaveEmbeddingsModule.embedder),
        ChangeNotifierProvider<SearchService>.value(value: _searchService),
        Provider<CardwaveMemoryModule>.value(value: _cardwaveMemoryModule),
        Provider<CardwaveNodesModule>.value(value: _cardwaveNodesModule),
        ChangeNotifierProvider<TextToSpeechController>.value(
          value: _textToSpeechController,
        ),
        ChangeNotifierProvider<VideoGenerationController>.value(
          value: _videoGenerationController,
        ),
        Provider<VideoPromptBuilder>.value(value: _videoPromptBuilder),
        Provider<CardwaveLlmModule>.value(value: _cardwaveLlmModule),
        ChangeNotifierProvider<GroupFileService>.value(
          value: _groupFileService,
        ),
        ChangeNotifierProvider<GroupChatService>.value(
          value: _groupChatService,
        ),
        Provider<GroupPromptService>.value(value: _groupPromptService),
      ],
      child: const MyApp(),
    );
  }
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // If bootstrap detected a missing settings.json but found the
    // recovery mirror, kick off the parallel model-fetch on the first
    // frame — now that `MyApp` is mounted, the overlay below can show
    // progress. No-ops when the flag is unset.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settingsService = context.read<SettingsService>();
      final mgmt = context.read<LlmManagementService>();
      unawaited(settingsService.rebuildFromRecovery(mgmt));
    });
  }

  @override
  Widget build(BuildContext context) {
    final onboardingComplete = context.select<SettingsService, bool>(
      (s) => s.settings.onboardingComplete,
    );
    final navigationService = context.watch<NavigationService>();
    final settingsDisplay = context.watch<ThemeNotifier>();

    final isFirstLaunch = !onboardingComplete;

    return MaterialApp(
      navigatorKey: navigationService.navigatorKey,
      builder: (context, child) {
        final appContent = kDebugMode
            ? OverlayError(child: child ?? const SizedBox.shrink())
            : child ?? const SizedBox.shrink();

        return Stack(
          children: [
            appContent,
            // Character grid scan / file load after the user lands on
            // home. Consumer (not Selector) because the status text
            // changes during the loading window while `isLoading` stays
            // true.
            Consumer<CharacterService>(
              builder: (context, service, child) {
                if (!service.isLoading) return const SizedBox.shrink();
                return ModalLoadingOverlay(
                  status: service.loadingStatus,
                  progress: service.loadingProgress,
                );
              },
            ),
            // One-shot post-bump rebuild from the recovery mirror. The
            // two overlays never run at the same time — the rebuild
            // completes before `CharacterGridPage` mounts.
            Consumer<SettingsService>(
              builder: (context, service, child) {
                if (!service.isLoading) return const SizedBox.shrink();
                return ModalLoadingOverlay(
                  status: service.loadingStatus,
                  progress: service.loadingProgress,
                );
              },
            ),
          ],
        );
      },
      title: AppConstants.appPackageName,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.unknown,
        },
      ),
      debugShowCheckedModeBanner: false,
      theme: compactLightTheme,
      darkTheme: compactDarkTheme,
      themeMode: settingsDisplay.themeMode,
      initialRoute: isFirstLaunch
          ? AppRoutesEnum.onboarding.name
          : AppRoutesEnum.home.name,
      // routes: {
      //   '/': (context) => const CharacterGridPage(),
      //   '/onboarding': (context) => const OnboardingPage(),
      // },
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}

/// Full-screen scrim with a progress indicator + status line. Stateless
/// over its inputs: each call site supplies [status] and [progress] from
/// whichever service is currently loading (see the two `Consumer`s in
/// [MyApp]). [progress] is null for an indeterminate spinner, 0.0..1.0
/// for a determinate bar.
class ModalLoadingOverlay extends StatelessWidget {
  const ModalLoadingOverlay({
    required this.status,
    required this.progress,
    super.key,
  });

  final String status;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color.fromRGBO(0, 0, 0, 0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 16,
          children: [
            CircularProgressIndicator(value: progress),
            Text(
              status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
