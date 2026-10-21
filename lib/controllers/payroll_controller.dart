import 'dart:async';

import 'package:get/get.dart';

import '../network/api_exception.dart';
import '../network/api_service.dart';
import '../network/payroll_live_socket.dart';
import '../utils/persistence_service.dart';
import 'month_payroll_controller.dart';
import 'payroll_trend_controller.dart';

/// Drives the "Endesha Payroll" (Run Payroll) screen. Talks directly to
/// `POST /api/payrolls/generate-payroll` and
/// `POST /api/payrolls/reverse-generate-payroll` (see
/// `tughe/payroll/service.py`) - unlike the Reports screen, which computes
/// its own preview locally and never touches these endpoints.
class PayrollController extends GetxController {
  PayrollController({ApiService? apiService}) : _api = apiService ?? ApiService();

  final ApiService _api;

  final RxBool isRunning = false.obs;
  final RxnString errorMessage = RxnString();

  /// Raw JSON from the last generate/reverse call, kept as-is so the
  /// screen can show whatever shape the backend returned (employeesProcessed
  /// /employeesWithProblems/problems for generate; salarySlipsRemoved/
  /// arrearsPaymentsRemoved/allowancesPaymentsRemoved for reverse).
  final Rxn<Map<String, dynamic>> lastResult = Rxn<Map<String, dynamic>>();

  /// Which of the two actions [lastResult] belongs to - purely so the UI
  /// knows how to label/interpret it.
  final RxString lastAction = ''.obs;

  Future<bool> generate({
    required String monthYear,
    required List<int> employeeIds,
    List<Map<String, dynamic>>? onceArrears,
  }) async {
    isRunning.value = true;
    errorMessage.value = null;
    try {
      final result = await _api.generatePayroll(monthYear,
          employeeIds: employeeIds.isEmpty ? null : employeeIds, onceArrears: onceArrears);
      lastResult.value = result;
      lastAction.value = 'generate';
      _refreshMonthLists();
      return true;
    } catch (error) {
      errorMessage.value = error is ApiException ? error.message : 'Imeshindwa kuendesha payroll.';
      return false;
    } finally {
      isRunning.value = false;
    }
  }


  // ---------------------------------------------------------------------
  // LIVE run (background job on the server + WebSocket progress)
  // ---------------------------------------------------------------------

  /// idle | starting | running | completed | cancelled | failed
  final RxString liveStatus = 'idle'.obs;

  /// websocket | polling | connecting | offline - how the progress reaches us.
  final RxString liveConnection = ''.obs;
  final RxString liveMonth = ''.obs;
  final RxInt liveTotal = 0.obs;
  final RxInt liveIndex = 0.obs;
  final RxInt liveProcessed = 0.obs;
  final RxInt liveSkipped = 0.obs;
  final RxInt liveProblems = 0.obs;
  final RxString liveCurrent = ''.obs;
  final RxDouble liveElapsed = 0.0.obs;
  final RxBool liveCancelRequested = false.obs;

  /// The events shown in the live log (oldest first, capped).
  final RxList<Map<String, dynamic>> liveLog = <Map<String, dynamic>>[].obs;

  static const _jobKey = 'tughe_payroll_live_job';
  static const _maxLog = 400;

  String? _jobId;
  int _lastSeq = 0;
  bool _finished = true;
  int _reconnects = 0;
  DateTime? _startedAt;
  PayrollLiveSocket? _socket;
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  Timer? _pollTimer;
  Timer? _clock;
  Timer? _retryTimer;

  bool get liveRunning => liveStatus.value == 'starting' || liveStatus.value == 'running';

  /// Starts payroll in the background and follows it live. Returns false when the
  /// run could not even be started (the message is in [errorMessage]).
  Future<bool> generateLive({
    required String monthYear,
    required List<int> employeeIds,
    List<Map<String, dynamic>>? onceArrears,
  }) async {
    _resetLive();
    liveStatus.value = 'starting';
    liveMonth.value = monthYear;
    isRunning.value = true;
    errorMessage.value = null;
    lastResult.value = null;
    _finished = false;
    try {
      final job = await _api.startPayrollJob(monthYear,
          employeeIds: employeeIds.isEmpty ? null : employeeIds, onceArrears: onceArrears);
      _jobId = job['jobId'] as String;
      unawaited(PersistenceService().writeJson(_jobKey, _jobId!));
      _startedAt = DateTime.now();
      _startClock();
      liveStatus.value = 'running';
      _connect(job['ticket'] as String, job['wsPath'] as String);
      return true;
    } catch (error) {
      errorMessage.value = error is ApiException ? error.message : 'Imeshindwa kuanza payroll.';
      liveStatus.value = 'idle';
      isRunning.value = false;
      _finished = true;
      return false;
    }
  }

  /// After a page refresh: re-attach to a run that is still going on the server.
  Future<void> resumeIfRunning() async {
    if (liveRunning || liveStatus.value != 'idle') return;
    final saved = await PersistenceService().readJson(_jobKey);
    if (saved is! String || saved.isEmpty) return;
    try {
      final snap = await _api.payrollJobSnapshot(saved);
      if (snap['status'] != 'running') {
        await PersistenceService().remove(_jobKey);
        return;
      }
      _resetLive();
      _jobId = saved;
      _finished = false;
      isRunning.value = true;
      liveStatus.value = 'running';
      liveMonth.value = (snap['monthYear'] as String?) ?? '';
      _startedAt = DateTime.now().subtract(Duration(milliseconds: (((snap['elapsedSeconds'] as num?) ?? 0) * 1000).round()));
      _startClock();
      final ticket = await _api.payrollJobTicket(saved);
      _connect(ticket['ticket'] as String, ticket['wsPath'] as String);
    } catch (_) {
      await PersistenceService().remove(_jobKey); // job expired / not ours
    }
  }

  /// Asks the server to stop after the employee it is processing now.
  Future<void> cancelLive() async {
    final id = _jobId;
    if (id == null || !liveRunning) return;
    liveCancelRequested.value = true;
    if (_socket?.isOpen ?? false) {
      _socket!.send('cancel');
    } else {
      try {
        await _api.cancelPayrollJob(id);
      } catch (_) {}
    }
  }

  /// Hides the live panel once a run has finished.
  void dismissLive() {
    if (liveRunning) return;
    _resetLive();
  }

  void _connect(String ticket, String wsPath) {
    _closeSocket();
    liveConnection.value = 'connecting';
    final socket = PayrollLiveSocket(_api.payrollWebSocketUrl(wsPath, ticket));
    _socket = socket;
    _socketSub = socket.events.listen((e) {
      final type = e['type'];
      if (type == '_open') {
        liveConnection.value = 'websocket';
        _reconnects = 0;
        _pollTimer?.cancel();
      } else if (type == '_closed') {
        if (!_finished) _onSocketLost();
      } else {
        _onEvent(e);
      }
    });
    socket.connect();
  }

  /// The WebSocket dropped (or is blocked): keep following the run by polling the
  /// same job over HTTP and try to get the WebSocket back a few times.
  void _onSocketLost() {
    liveConnection.value = 'polling';
    _closeSocket();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) => _poll());
    _poll();
    if (_reconnects < 3) {
      _reconnects++;
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 4), () async {
        if (_finished || _jobId == null) return;
        try {
          final t = await _api.payrollJobTicket(_jobId!);
          if (!_finished) _connect(t['ticket'] as String, t['wsPath'] as String);
        } catch (_) {}
      });
    }
  }

  Future<void> _poll() async {
    final id = _jobId;
    if (_finished || id == null) return;
    try {
      final snap = await _api.payrollJobSnapshot(id, after: _lastSeq);
      for (final raw in (snap['events'] as List? ?? const [])) {
        _onEvent(Map<String, dynamic>.from(raw as Map));
      }
      if (!_finished && liveConnection.value == 'offline') liveConnection.value = 'polling';
    } catch (_) {
      liveConnection.value = 'offline';
    }
  }

  void _onEvent(Map<String, dynamic> e) {
    final type = e['type'] as String? ?? '';
    if (type == 'ping') return;
    final seq = (e['seq'] as num?)?.toInt();
    if (seq != null) {
      if (seq <= _lastSeq) return; // already seen (replay / polling overlap)
      _lastSeq = seq;
    }
    switch (type) {
      case 'plan':
        liveTotal.value = (e['total'] as num?)?.toInt() ?? 0;
        break;
      case 'employee_started':
        liveIndex.value = (e['index'] as num?)?.toInt() ?? liveIndex.value;
        liveCurrent.value = (e['name'] as String?) ?? '';
        break;
      case 'employee_done':
        liveProcessed.value++;
        _log(e);
        break;
      case 'employee_skipped':
        liveSkipped.value++;
        _log(e);
        break;
      case 'employee_problem':
        liveProblems.value++;
        _log(e);
        break;
      case 'cancel_requested':
        liveCancelRequested.value = true;
        break;
      case 'job_finished':
        _finish(e);
        break;
    }
  }

  void _log(Map<String, dynamic> e) {
    liveLog.add(e);
    if (liveLog.length > _maxLog) liveLog.removeAt(0);
  }

  void _finish(Map<String, dynamic> e) {
    _finished = true;
    final status = (e['status'] as String?) ?? 'completed';
    final summary = Map<String, dynamic>.from((e['summary'] as Map?) ?? const {});
    liveElapsed.value = ((e['elapsedSeconds'] as num?) ?? liveElapsed.value).toDouble();
    liveCurrent.value = '';
    liveStatus.value = status;
    if (status == 'failed') {
      errorMessage.value = (summary['error'] as String?) ?? 'Payroll imeshindwa.';
    } else {
      lastResult.value = summary;
      lastAction.value = 'generate';
    }
    isRunning.value = false;
    _stopTimers();
    _closeSocket();
    unawaited(PersistenceService().remove(_jobKey));
    _refreshMonthLists();
  }

  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      final started = _startedAt;
      if (started != null && !_finished) {
        liveElapsed.value = DateTime.now().difference(started).inMilliseconds / 1000;
      }
    });
  }

  void _stopTimers() {
    _clock?.cancel();
    _pollTimer?.cancel();
    _retryTimer?.cancel();
  }

  void _closeSocket() {
    _socketSub?.cancel();
    _socketSub = null;
    _socket?.dispose();
    _socket = null;
  }

  void _resetLive() {
    _stopTimers();
    _closeSocket();
    _jobId = null;
    _lastSeq = 0;
    _reconnects = 0;
    _startedAt = null;
    _finished = true;
    liveStatus.value = 'idle';
    liveConnection.value = '';
    liveMonth.value = '';
    liveTotal.value = 0;
    liveIndex.value = 0;
    liveProcessed.value = 0;
    liveSkipped.value = 0;
    liveProblems.value = 0;
    liveCurrent.value = '';
    liveElapsed.value = 0;
    liveCancelRequested.value = false;
    liveLog.clear();
  }

  Future<bool> reverse({required String monthYear, required List<int> employeeIds}) async {
    isRunning.value = true;
    errorMessage.value = null;
    try {
      final result = await _api.reverseGeneratePayroll(monthYear, employeeIds: employeeIds.isEmpty ? null : employeeIds);
      lastResult.value = result;
      lastAction.value = 'reverse';
      _refreshMonthLists();
      return true;
    } catch (error) {
      errorMessage.value = error is ApiException ? error.message : 'Imeshindwa kubatilisha payroll.';
      return false;
    } finally {
      isRunning.value = false;
    }
  }

  /// A payroll run/reversal changes who is "processed" for that month, so the
  /// cached list used by the Salary Slip and Reports screens must be reloaded.
  void _refreshMonthLists() {
    if (Get.isRegistered<MonthPayrollController>()) {
      Get.find<MonthPayrollController>().invalidate();
    }
    if (Get.isRegistered<PayrollTrendController>()) {
      Get.find<PayrollTrendController>().invalidate();
    }
  }

  void clearResult() {
    lastResult.value = null;
    errorMessage.value = null;
  }
}
