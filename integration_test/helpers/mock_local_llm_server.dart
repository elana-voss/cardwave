import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// In-process HTTP server that mimics the OpenAI-compatible endpoints used
/// by Cardwave's "Local (OpenAI-compatible)" provider. Lives entirely in
/// the test's Dart isolate — when used from an `integration_test` on an
/// Android emulator, the app code in the same process reaches this server
/// at `127.0.0.1:<port>` directly (same isolate, same loopback).
///
/// Two endpoints:
///   - `GET  /v1/models`             — always on; returns one canned model.
///   - `POST /v1/chat/completions`   — only when [enableChatCompletions]
///     is true; returns an OpenAI SSE stream with two content deltas and
///     a `[DONE]` terminator. When the flag is false, returns 501 so a
///     test that didn't expect chat traffic fails loudly instead of
///     silently.
///
/// Anything else returns 404 — any unexpected path the app hits will
/// surface as an obvious failure rather than passing the test by accident.
class MockLocalLlmServer {
  MockLocalLlmServer({this.enableChatCompletions = false});

  final bool enableChatCompletions;

  HttpServer? _server;
  int _requestCount = 0;

  /// Bind to an OS-assigned loopback port. Returns when the server is
  /// listening.
  Future<void> start() async {
    if (_server != null) {
      throw StateError('MockLocalLlmServer already started');
    }
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = s;
    s.listen(_handle);
  }

  /// Idempotent shutdown. Force-closes any in-flight connections so a
  /// hung response doesn't block test teardown.
  Future<void> stop() async {
    final s = _server;
    if (s == null) return;
    _server = null;
    await s.close(force: true);
  }

  /// Base URL the app should hit, e.g. `http://127.0.0.1:51234/v1`.
  /// Throws if [start] hasn't been called yet.
  String get baseUrl {
    final s = _server;
    if (s == null) {
      throw StateError('MockLocalLlmServer not started');
    }
    return 'http://${s.address.host}:${s.port}/v1';
  }

  /// Total HTTP requests this server has received since [start]. Useful
  /// for a test to assert "the app actually hit me" rather than passing
  /// because nothing happened.
  int get requestCount => _requestCount;

  Future<void> _handle(HttpRequest req) async {
    _requestCount++;

    if (req.method == 'GET' && req.uri.path == '/v1/models') {
      await _serveModels(req);
      return;
    }

    if (req.method == 'POST' && req.uri.path == '/v1/chat/completions') {
      if (!enableChatCompletions) {
        req.response.statusCode = HttpStatus.notImplemented;
        await req.response.close();
        return;
      }
      await _serveChatStream(req);
      return;
    }

    req.response.statusCode = HttpStatus.notFound;
    await req.response.close();
  }

  Future<void> _serveModels(HttpRequest req) async {
    req.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(
        jsonEncode({
          'object': 'list',
          'data': [
            {
              'id': 'mock-llama-3.1-8b',
              'object': 'model',
              'owned_by': 'mock',
            },
          ],
        }),
      );
    await req.response.close();
  }

  Future<void> _serveChatStream(HttpRequest req) async {
    // Drain the request body — mock doesn't parse it, just returns a
    // canned reply. Skipping the drain leaves the connection half-open
    // on some clients.
    await req.drain<void>();

    req.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      )
      ..headers.set('Cache-Control', 'no-cache')
      ..headers.set('Connection', 'keep-alive');

    const chunks = [
      {
        'id': 'mock',
        'object': 'chat.completion.chunk',
        'choices': [
          {
            'index': 0,
            'delta': {'role': 'assistant', 'content': 'hello'},
            'finish_reason': null,
          },
        ],
      },
      {
        'id': 'mock',
        'object': 'chat.completion.chunk',
        'choices': [
          {
            'index': 0,
            'delta': {'content': ' world'},
            'finish_reason': null,
          },
        ],
      },
      {
        'id': 'mock',
        'object': 'chat.completion.chunk',
        'choices': [
          {
            'index': 0,
            'delta': <String, dynamic>{},
            'finish_reason': 'stop',
          },
        ],
      },
    ];

    for (final c in chunks) {
      req.response.write('data: ${jsonEncode(c)}\n\n');
    }
    req.response.write('data: [DONE]\n\n');
    await req.response.close();
  }
}
