import 'mock_local_llm_server.dart';

/// Switchable backend for local-provider integration tests.
///
/// - When `--dart-define=LOCAL_LLM_BASE_URL=...` is supplied (set by the
///   wrapper script that launches a real KoboldCpp/Ollama/etc.), tests
///   point at that URL. The wrapper is responsible for translating
///   `localhost:<port>` on the host into `10.0.2.2:<port>` for the
///   Android emulator.
/// - When the env var is empty (default), spins up an in-process
///   [MockLocalLlmServer] on a loopback port and uses that. Same test
///   code, no branching.
///
/// Usage in a test:
/// ```dart
/// final backend = LocalLlmTestBackend(enableChat: true);
/// await backend.setUp();
/// addTearDown(backend.tearDown);
/// // ... use backend.baseUrl ...
/// ```
class LocalLlmTestBackend {
  LocalLlmTestBackend({required this.enableChat});

  final bool enableChat;

  static const _envBaseUrl = String.fromEnvironment('LOCAL_LLM_BASE_URL');

  MockLocalLlmServer? _mock;
  String? _baseUrl;

  /// True when this run targets a real local server (env var was set),
  /// false when running against the in-process mock. Tests can use this
  /// to skip mock-only assertions like `mock.requestCount`.
  bool get isReal => _envBaseUrl.isNotEmpty;

  /// The base URL (e.g. `http://127.0.0.1:51234/v1`) to plug into the
  /// "Server URL" field of `DialogLocalProviderConfig`. Throws if
  /// [setUp] hasn't been called yet.
  String get baseUrl {
    final url = _baseUrl;
    if (url == null) {
      throw StateError('LocalLlmTestBackend not set up');
    }
    return url;
  }

  /// Optional handle to the in-process mock server (null in real-server
  /// mode). Tests can use this to assert `mock.requestCount` and prove
  /// the app actually hit the mock rather than passing by accident.
  MockLocalLlmServer? get mock => _mock;

  Future<void> setUp() async {
    if (isReal) {
      _baseUrl = _envBaseUrl;
      return;
    }
    final server = MockLocalLlmServer(enableChatCompletions: enableChat);
    await server.start();
    _mock = server;
    _baseUrl = server.baseUrl;
  }

  Future<void> tearDown() async {
    final m = _mock;
    _mock = null;
    _baseUrl = null;
    if (m != null) await m.stop();
  }
}
