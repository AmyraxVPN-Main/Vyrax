import 'dart:io';

import 'package:fl_clash/features/pow/coordinator.dart';
import 'package:fl_clash/features/pow/engine.dart';
import 'package:fl_clash/features/pow/provider.dart';
import 'package:fl_clash/features/pow/store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal SOCKS5 stub used to exercise [probeExitSocks] over a real socket.
/// `replies` maps the two expected requests (greeting key `g`, CONNECT key
/// `c`) to the bytes the fake server answers with, in order.
class _FakeSocksServer {
  _FakeSocksServer(this.replies, {this.holdConnectReply});

  final List<List<int>> replies;
  /// Seconds to hold open after answering the greeting without replying to
  /// the CONNECT request (simulates a hung tunnel). Kept name-compatible
  /// with earlier revisions; the byte-stream parser holds untold replies by
  /// itself.
  final double? holdConnectReply;

  static const _greetingLength = 3; // 05 01 00
  static const _connectLength = 10; // IPv4 CONNECT request

  ServerSocket? _server;
  final List<Socket> _clients = [];

  Future<int> start() async {
    _server = await ServerSocket.bind('127.0.0.1', 0);
    _server!.listen((client) {
      _clients.add(client);
      var greeted = false;
      var answered = false;
      final received = <int>[];
      client.listen((chunk) {
        received.addAll(chunk);
        if (!greeted && received.length >= _greetingLength) {
          greeted = true;
          final reply = replies.first;
          if (reply.isEmpty) return;
          client.add(reply);
          // ignore: avoid_print
          print('fakeSocks greeting reply ${reply.length}');
        }
        if (greeted &&
            !answered &&
            received.length >= _greetingLength + _connectLength) {
          answered = true;
          if (replies.length < 2) return;
          final reply = replies[1];
          if (reply.isEmpty) {
            // hold the socket open and never answer — a hung tunnel
            return;
          }
          client.add(reply);
          // ignore: avoid_print
          print('fakeSocks connect reply ${reply.length}');
        }
      });
    });
    return _server!.port;
  }

  Future<void> close() async {
    for (final client in _clients) {
      client.destroy();
    }
    await _server?.close();
  }
}

void main() {
  tearDown(() async {});

  group('probeExitSocks', () {
    test('healthy tunnel reports true even though the socket stays open', () async {
      // Answers the greeting, answers CONNECT success, and then keeps the
      // tunnel open (matches a real working SOCKS exit) — a probe that
      // drains the stream would wrongly time out here.
      final server = _FakeSocksServer([
        [0x05, 0x00],
        [0x05, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x01, 0xBB],
      ]);
      final port = await server.start();
      addTearDown(server.close);
      final ok = await probeExitSocks(
        port,
        timeout: const Duration(milliseconds: 1500),
      );
      expect(ok, isTrue);
    });

    test('connected reply code 5 (upstream refused) reports false', () async {
      final server = _FakeSocksServer([
        [0x05, 0x00],
        [0x05, 0x05, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x01, 0xBB],
      ]);
      final port = await server.start();
      addTearDown(server.close);
      final ok = await probeExitSocks(
        port,
        timeout: const Duration(milliseconds: 1500),
      );
      expect(ok, isFalse);
    });

    test('hung upstream (CONNECT never answered) reports false within the timeout', () async {
      // Echoes the greeting but then answers nothing: the reply slot is an
      // empty list, so the fake holds the socket open, like a dead server.
      final server = _FakeSocksServer([
        [0x05, 0x00],
        const <int>[],
      ], holdConnectReply: 2);
      final port = await server.start();
      addTearDown(server.close);
      final watch = Stopwatch()..start();
      final ok = await probeExitSocks(
        port,
        timeout: const Duration(milliseconds: 1200),
      );
      watch.stop();
      expect(ok, isFalse);
      // Returns by its own timeout, not hung for the full fake hold window.
      expect(watch.elapsed, lessThan(const Duration(milliseconds: 1900)));
    });

    test('port with nothing listening reports false', () async {
      final server = _FakeSocksServer(const []);
      final port = await server.start();
      await server.close();
      final ok = await probeExitSocks(
        port,
        timeout: const Duration(milliseconds: 500),
      );
      expect(ok, isFalse);
    });
  });

  group('adoptOrphanTunnel', () {
    late Directory tempDir;
    late PowStore store;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('pow-adopt');
      store = PowStore(tempDir);
    });
    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    PowCoordinator newCoordinator() => PowCoordinator(
          tempDir,
          store,
          logger: (_) {},
        );

    test('adopts a healthy SOCKS exit left by a previous session', () async {
      final server = _FakeSocksServer([
        [0x05, 0x00],
        [0x05, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x01, 0xBB],
      ]);
      final port = await server.start();
      addTearDown(server.close);
      final coordinator = newCoordinator();
      final adopted = await coordinator.adoptOnPort(port, chain: true);
      expect(adopted, isTrue);
      expect(coordinator.exitPort, port);
      expect(coordinator.connected, isTrue);
      expect(coordinator.exitRegion, isEmpty);
    });

    test('ignores a dead leftover listener and keeps the state idle', () async {
      final server = _FakeSocksServer([
        [0x05, 0x00],
        const <int>[],
      ]);
      final port = await server.start();
      addTearDown(server.close);
      final coordinator = newCoordinator();
      final adopted = await coordinator.adoptOnPort(port, chain: true);
      expect(adopted, isFalse);
      expect(coordinator.connected, isFalse);
      expect(coordinator.exitPort, 0);
    });

    test('nothing listening leaves the coordinator idle', () async {
      final server = _FakeSocksServer(const []);
      final port = await server.start();
      await server.close();
      final coordinator = newCoordinator();
      final adopted = await coordinator.adoptOnPort(port, chain: false);
      expect(adopted, isFalse);
      expect(coordinator.connected, isFalse);
    });
  });

  group('powRunNeedsConnectFlow', () {
    const otherProfileId = 123456789;
    test('a non-Vyrax profile keeps the plain toggle', () {
      expect(
        powRunNeedsConnectFlow(
          profileId: otherProfileId,
          hasServerSlot: true,
          tunnelUp: false,
          busy: false,
        ),
        isFalse,
      );
      expect(
        powRunNeedsConnectFlow(
          profileId: null,
          hasServerSlot: true,
          tunnelUp: false,
          busy: false,
        ),
        isFalse,
      );
    });

    test('the Vyrax profile with a dead tunnel opens the flow', () {
      expect(
        powRunNeedsConnectFlow(
          profileId: 3,
          hasServerSlot: true,
          tunnelUp: false,
          busy: false,
        ),
        isTrue,
      );
    });

    test('a live tunnel keeps the plain toggle', () {
      expect(
        powRunNeedsConnectFlow(
          profileId: 3,
          hasServerSlot: true,
          tunnelUp: true,
          busy: false,
        ),
        isFalse,
      );
      expect(
        powRunNeedsConnectFlow(
          profileId: 3,
          hasServerSlot: true,
          tunnelUp: true,
          busy: true,
        ),
        isFalse,
      );
    });

    test('a dead tunnel opens the flow even while a recovery is running', () {
      expect(
        powRunNeedsConnectFlow(
          profileId: 3,
          hasServerSlot: true,
          tunnelUp: false,
          busy: true,
        ),
        isTrue,
      );
    });

    test('no server slot means there is nothing to raise', () {
      expect(
        powRunNeedsConnectFlow(
          profileId: 3,
          hasServerSlot: false,
          tunnelUp: false,
          busy: false,
        ),
        isFalse,
      );
    });
  });

  group('powBackoffFor', () {
    test('ladder doubles from the base and is capped', () {
      expect(
        powBackoffFor(1),
        const Duration(minutes: 2),
      );
      expect(
        powBackoffFor(2),
        const Duration(minutes: 4),
      );
      expect(
        powBackoffFor(3),
        const Duration(minutes: 8),
      );
      expect(
        powBackoffFor(4),
        const Duration(minutes: 10),
        reason: 'the cap holds the retry loop from spreading unbounded',
      );
      expect(
        powBackoffFor(40),
        const Duration(minutes: 10),
      );
      expect(
        powBackoffFor(0),
        const Duration(minutes: 2),
      );
    });

    test('custom base and cap scale the ladder', () {
      expect(
        powBackoffFor(1, base: const Duration(seconds: 3)),
        const Duration(seconds: 3),
      );
      expect(
        powBackoffFor(3, base: const Duration(seconds: 3)),
        const Duration(seconds: 12),
      );
      expect(
        powBackoffFor(3, base: const Duration(seconds: 3), cap: const Duration(seconds: 6)),
        const Duration(seconds: 6),
      );
    });
  });
}
