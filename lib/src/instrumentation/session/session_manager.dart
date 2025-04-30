import 'package:clock/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const Duration defaultSessionTimeout = Duration(minutes: 15);

SessionManager? _sessionManager;

Future<String> getSessionId() async {
  return _sessionManager?._session.id ?? '';
}

SessionManager getGlobalSessionManager() {
  assert(_sessionManager != null, 'SessionManager has not been initialized');
  return _sessionManager!;
}

void createSessionManager(SessionIdTimeoutHandler timeoutHandler) {
  final sessionLifetime = Duration(hours: 4);
  _sessionManager = SessionManager.create(
    timeoutHandler: timeoutHandler,
    sessionLifetime: sessionLifetime,
  );
}

class Session {
  final String id;
  final DateTime startTimestamp;

  Session(this.id, this.startTimestamp);

  static final Session none =
      Session('', DateTime.fromMillisecondsSinceEpoch(0));
}

abstract class SessionObserver {
  void onSessionEnded(Session previousSession);
  void onSessionStarted(Session newSession, Session previousSession);
}

enum AppState {
  foreground,
  background,

  /// A temporary state representing the first event after the app has been brought back.
  transitioningToForeground,
}

abstract class ApplicationLifecycleListener {
  void onApplicationForegrounded();
  void onApplicationBackgrounded();
}

class SessionIdTimeoutHandler implements ApplicationLifecycleListener {
  final Duration sessionTimeout;

  AppState appState = AppState.foreground;

  DateTime startTime = clock.now();

  SessionIdTimeoutHandler({
    this.sessionTimeout = defaultSessionTimeout,
  }) {
    // WidgetsBinding.instance.addObserver(this);
  }

  bool hasTimedOut() {
    if (appState == AppState.foreground) {
      return false;
    }
    final elapsedTime = clock.now().difference(startTime);
    return elapsedTime >= sessionTimeout;
  }

  void bump() {
    startTime = clock.now();

    // move from the temporary transition state to foreground after the first span
    if (appState == AppState.transitioningToForeground) {
      appState = AppState.foreground;
    }
  }

  @override
  void onApplicationBackgrounded() {
    appState = AppState.background;
  }

  @override
  void onApplicationForegrounded() {
    appState = AppState.transitioningToForeground;
  }

}

class SessionStorage {
  Session _session = Session.none;

  Session load() => _session;

  void save(Session session) {
    _session = session;
  }
}

class SessionManager {
  final SessionIdTimeoutHandler timeoutHandler;
  final SessionIdGenerator idGenerator;
  final Duration sessionLifetime;
  final SessionStorage sessionStorage;

  final List<SessionObserver> _observers = [];
  Session _session = Session.none;

  SessionManager({
    required this.timeoutHandler,
    SessionStorage? sessionStorage,
    SessionIdGenerator? idGenerator,
    this.sessionLifetime = const Duration(hours: 4),
  })  : sessionStorage = sessionStorage ?? SessionStorage(),
        idGenerator = idGenerator ?? DefaultSessionIdGenerator() {
    _session = this.sessionStorage.load();
  }

  void addObserver(SessionObserver observer) {
    _observers.add(observer);
  }

  get sessionId => _getSessionId();

  String _getSessionId() {
    Session newSession = _session;
    if (_sessionHasExpired() || timeoutHandler.hasTimedOut()) {
      final newId = idGenerator.generateSessionId();
      newSession = Session(newId, clock.now());
      sessionStorage.save(newSession);
    }

    timeoutHandler.bump();

    if (newSession != _session) {
      for (var observer in _observers) {
        observer.onSessionEnded(_session);
        observer.onSessionStarted(newSession, _session);
      }
      _session = newSession;
    }

    SharedPreferences.getInstance().then((prefs) async {
      prefs.setString('sessionId', _session.id);
    });

    return _session.id;
  }

  bool _sessionHasExpired() {
    final elapsedTime = clock.now().difference(_session.startTimestamp);
    return elapsedTime >= sessionLifetime;
  }

  factory SessionManager.create({
    required SessionIdTimeoutHandler timeoutHandler,
    required Duration sessionLifetime,
  }) {
    return SessionManager(
      timeoutHandler: timeoutHandler,
      sessionLifetime: sessionLifetime,
    );
  }
}

abstract class SessionIdGenerator {
  String generateSessionId();
}

class DefaultSessionIdGenerator implements SessionIdGenerator {
  @override
  String generateSessionId() {
    return Uuid().v4();
  }
}
