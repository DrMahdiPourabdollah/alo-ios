import 'premium_effects.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/entry.dart';
import '../domain/parser.dart';
import '../domain/financial_book.dart';
import '../voice/voice.dart';
import 'theme.dart';
import '../models/model_manager.dart';

enum _Stage { idle, installing, recording, processing }

class ComposePage extends StatefulWidget {
  const ComposePage({
    super.key,
    required this.space,
    this.startWithVoice = false,
    this.financialBatch = false,
  });
  final Space space;
  final bool startWithVoice;
  final bool financialBatch;
  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _voice = VoiceService();
  final _text = TextEditingController();
  late final AnimationController _animation;
  Timer? _timer;
  _Stage _stage = _Stage.idle;
  int _seconds = 0, _progress = 0;
  double _level = 0;
  String? _error, _rawTranscript;
  bool _starting = false;
  bool get _working => _stage != _Stage.idle || _starting;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.startWithVoice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _begin();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.detached) &&
        _stage == _Stage.recording) {
      _timer?.cancel();
      _animation.stop();
      setState(() => _stage = _Stage.processing);
      unawaited(_cancelInterruptedRecording());
    }
  }

  Future<void> _cancelInterruptedRecording() async {
    try {
      await _voice.cancel();
    } catch (_) {
      // The recorder may already have stopped after an OS interruption.
    } finally {
      if (mounted) {
        setState(() {
          _stage = _Stage.idle;
          _error = 'ضبط متوقف شد. دوباره بگویید یا بنویسید.';
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    if (_stage == _Stage.installing) ModelManager.cancelDownload();
    _animation.dispose();
    _text.dispose();
    unawaited(
      _voice.dispose().catchError((Object _) {
        // Widget teardown must not emit an unhandled platform exception.
      }),
    );
    super.dispose();
  }

  Future<void> _begin() async {
    if (_working) return;
    if (!_voice.supported) {
      setState(
        () =>
            _error =
                'ثبت صوت در نسخهٔ موبایل فعال است. در این پیش‌نمایش متن را وارد کنید.',
      );
      return;
    }
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      if (!await _voice.ready()) {
        if (!mounted) return;
        setState(() => _stage = _Stage.installing);
        await ModelManager.downloadAsr((v) {
          if (mounted) setState(() => _progress = (v * 100).round());
        });
        if (!await _voice.ready()) return;
      }
      await _voice.start();
      if (!mounted) {
        await _voice.cancel();
        return;
      }
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        await _voice.cancel();
        if (mounted) {
          setState(() => _error = 'ضبط متوقف شد. دوباره بگویید یا بنویسید.');
        }
        return;
      }
      _animation.repeat();
      HapticFeedback.lightImpact();
      setState(() {
        _stage = _Stage.recording;
        _seconds = 0;
        _progress = 0;
      });
      _timer = Timer.periodic(const Duration(milliseconds: 250), (t) async {
        if (!mounted || _stage != _Stage.recording) return;
        setState(() => _seconds = t.tick ~/ 4);
        // Enforce the limit even when amplitude reporting fails or stalls.
        if (t.tick >= 240) {
          unawaited(_finish());
          return;
        }
        try {
          final amp = await _voice.amplitude();
          if (!mounted || _stage != _Stage.recording) return;
          setState(() {
            _level = ((amp + 60) / 60).clamp(0, 1);
          });
        } catch (_) {
          /* Microphone amplitude is advisory; actual stop handles errors. */
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
          if (_stage == _Stage.installing) _stage = _Stage.idle;
        });
      }
    }
  }

  String _friendly(Object e) =>
      e is StateError
          ? e.message
          : 'این بار صدا بررسی نشد. دوباره تلاش کنید یا بنویسید.';
  Future<void> _finish() async {
    if (_stage != _Stage.recording) return;
    _timer?.cancel();
    _animation.stop();
    // The real VAD below checks speech. A dB threshold must not discard
    // quiet speech before recognition or race with a second stop tap.
    setState(() => _stage = _Stage.processing);
    try {
      final text = await _voice.finish((p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!mounted) return;
      setState(() {
        _stage = _Stage.idle;
        _text.text = text;
        _rawTranscript = text;
      });
      _error = null;
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = _Stage.idle;
          _error = _friendly(e);
        });
      }
    }
  }

  void _returnDraft(String text) {
    if (text.trim().isEmpty) {
      setState(() => _error = 'اول بگو یا بنویس چه اتفاقی افتاده.');
      return;
    }
    HapticFeedback.selectionClick();
    if (widget.financialBatch) {
      Navigator.pop(
        context,
        FinancialBatch.parse(text, widget.space, rawTranscript: _rawTranscript),
      );
      return;
    }
    final draft = NoteParser().parse(text, widget.space);
    Navigator.pop(
      context,
      Entry.fromJson({...draft.toJson(), 'rawTranscript': _rawTranscript}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final recording = _stage == _Stage.recording,
        processing = _stage == _Stage.processing;
    final busy = processing || _stage == _Stage.installing || _starting;
    final prompt =
        widget.space == Space.personal
            ? 'امروز توی فروشگاه امید ۸۵۰ هزار تومن کارت کشیدم.'
            : 'امروز ۲۰ کارتن آب‌معدنی از احمدی آوردم، هر کارتن ۱۸۰ هزار تومن.';
    return Scaffold(
      backgroundColor: pine,
      appBar: AppBar(
        backgroundColor: pine,
        foregroundColor: cream,
        leading: IconButton(
          tooltip: 'بستن',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(
          'دفتر ${widget.space.label}',
          style: const TextStyle(fontSize: 16, color: cream),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(left: 24),
            child: Brand(light: true, size: 28),
          ),
        ],
      ),
      body: CustomPaint(
        painter: const AmbientPainter(dark: true),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      recording
                          ? 'دارم گوش می‌دم…'
                          : processing
                          ? 'در حال تشخیص گفتار…'
                          : widget.financialBatch
                          ? 'تراکنش‌ها را\nبیان کنید.'
                          : 'راحت بگو،\nمرتب ثبتش می‌کنیم.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: cream,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      recording
                          ? 'وقتی تمام شد، دکمه پایان را بزن.'
                          : processing
                          ? 'می‌توانی این صفحه را ببندی؛ چیزی خودکار ثبت نمی‌شود.'
                          : 'مثلاً: «$prompt»',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFFD0DFD5),
                        height: 1.8,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: AnimatedBuilder(
                          animation: _animation,
                          builder:
                              (c, child) => CustomPaint(
                                painter: _HaloPainter(
                                  phase: reduced ? 0 : _animation.value,
                                  active: recording,
                                  level: _level,
                                ),
                                child: Center(
                                  child: Semantics(
                                    button: true,
                                    label: recording ? 'پایان ضبط' : 'شروع ضبط',
                                    child: AloPress(
                                      enabled: !busy,
                                      child: Material(
                                        color: cream,
                                        shape: const CircleBorder(),
                                        clipBehavior: Clip.antiAlias,
                                        child: InkWell(
                                          onTap:
                                              busy
                                                  ? null
                                                  : recording
                                                  ? _finish
                                                  : _begin,
                                          customBorder: const CircleBorder(),
                                          child: SizedBox(
                                            width: 116,
                                            height: 116,
                                            child:
                                                busy
                                                    ? const Padding(
                                                      padding: EdgeInsets.all(
                                                        36,
                                                      ),
                                                      child:
                                                          CircularProgressIndicator(
                                                            color: ink,
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                    : Icon(
                                                      recording
                                                          ? Icons.stop_rounded
                                                          : Icons
                                                              .mic_none_rounded,
                                                      size: 48,
                                                      color: ink,
                                                    ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recording
                          ? 'پایان ضبط · ${digits('$_seconds')} ثانیه'
                          : processing
                          ? 'تشخیص دقیق فارسی روی گوشی${_progress > 0 ? ' · ${digits('$_progress')}٪' : ''}'
                          : _stage == _Stage.installing
                          ? 'آماده‌سازی مدل داخل برنامه…'
                          : 'برای شروع لمس کن',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: cream),
                    ),
                    const SizedBox(height: 24),
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6E9D7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded, color: ink),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: ink,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!_working) ...[
                      const Row(
                        children: [
                          Expanded(child: Divider(color: Color(0xFF47715F))),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'یا بنویس',
                              style: TextStyle(
                                color: Color(0xFFD0DFD5),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Color(0xFF47715F))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'متن تشخیص‌داده‌شده · قابل اصلاح',
                        style: TextStyle(
                          color: Color(0xFFD0DFD5),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _text,
                        maxLines: 4,
                        minLines: 3,
                        maxLength: 2000,
                        style: const TextStyle(color: ink, fontSize: 16),
                        decoration: const InputDecoration(
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                          hintText:
                              'مثلاً بیست عدد دفتر، هر کدام پنجاه هزار تومان',
                          counterStyle: TextStyle(color: Color(0xFFD0DFD5)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: cream,
                          foregroundColor: ink,
                        ),
                        onPressed: () => _returnDraft(_text.text),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: Text(
                          widget.financialBatch
                              ? 'استخراج اطلاعات مالی'
                              : 'ببین چی فهمیدم',
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          color: Color(0xFFD0DFD5),
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'صدایت به سرور ارسال نمی‌شود.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFFD0DFD5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HaloPainter extends CustomPainter {
  const _HaloPainter({
    required this.phase,
    required this.active,
    required this.level,
  });
  final double phase, level;
  final bool active;
  @override
  void paint(Canvas c, Size s) {
    final center = Offset(s.width / 2, s.height / 2);
    for (var i = 0; i < 3; i++) {
      final radius =
          67 +
          i * 12 +
          (active ? math.sin(phase * math.pi * 2 + i) * 4 + level * 6 : 0);
      c.drawCircle(
        center,
        radius.toDouble(),
        Paint()
          ..color = const Color(0xFFBCD8B5).withValues(alpha: .2 - i * .04)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    if (active) {
      for (var i = 0; i < 28; i++) {
        final angle = i * math.pi * 2 / 28;
        final from = center + Offset(math.cos(angle), math.sin(angle)) * 92;
        final to =
            center +
            Offset(math.cos(angle), math.sin(angle)) *
                (96 + level * 8 * math.sin(phase * math.pi * 2 + i).abs());
        c.drawLine(
          from,
          to,
          Paint()
            ..color = cream.withValues(alpha: .6)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HaloPainter old) =>
      phase != old.phase || active != old.active || level != old.level;
}
