import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TorchController extends StatefulWidget {
  @override
  _TorchControllerState createState() => _TorchControllerState();
}

class _TorchControllerState extends State<TorchController>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _isOn = false;

  static const _channel = MethodChannel('com.example.torch/foreground');

  late AnimationController _glowController;
  late AnimationController _pulseController;
  late Animation<double> _glowAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnim = CurvedAnimation(parent: _glowController, curve: Curves.easeOut);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onTorchStopped') {
        setState(() => _isOn = false);
        _glowController.reverse();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      // INACTIVE = tout début de sortie (avant paused)
      // On passe immédiatement le contrôle au service natif
      _channel.invokeMethod('startForeground', {'isOn': _isOn});
    } else if (state == AppLifecycleState.resumed) {
      // L'app reprend — le service rend la main à Flutter
      _channel.invokeMethod('stopForeground').then((_) {
        // Resynchroniser l'état de la torche côté Flutter
        _channel.invokeMethod('setTorch', {'isOn': _isOn});
      });
    }
  }

  Future<void> _toggle() async {
    try {
      final newState = !_isOn;
      await _channel.invokeMethod('setTorch', {'isOn': newState});
      setState(() => _isOn = newState);
      if (newState) {
        _glowController.forward();
      } else {
        _glowController.reverse();
      }
    } catch (_) {
      _showSnack('Erreur lors du contrôle de la torche.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(fontFamily: 'Courier', letterSpacing: 1)),
        backgroundColor: const Color(0xFF1E1E2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _glowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: Stack(
          children: [
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.3),
                      radius: 1.2,
                      colors: [
                        const Color(0xFFFFF9E6).withOpacity(0.12 * _glowAnim.value),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TORCHE',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 13,
                            letterSpacing: 6,
                            color: Colors.white.withOpacity(0.35),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _glowAnim,
                          builder: (_, __) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: _isOn
                                  ? const Color(0xFFFFF3B0).withOpacity(0.15)
                                  : Colors.white.withOpacity(0.05),
                              border: Border.all(
                                color: _isOn
                                    ? const Color(0xFFFFF3B0).withOpacity(0.4)
                                    : Colors.white.withOpacity(0.08),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _isOn ? 'ALLUMÉE' : 'ÉTEINTE',
                              style: TextStyle(
                                fontFamily: 'Courier',
                                fontSize: 11,
                                letterSpacing: 3,
                                color: _isOn
                                    ? const Color(0xFFFFF3B0)
                                    : Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 2),
                  GestureDetector(
                    onTap: _toggle,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_glowAnim, _pulseAnim]),
                      builder: (_, __) {
                        final glow = _glowAnim.value;
                        final pulse = _isOn ? _pulseAnim.value : 1.0;
                        return Transform.scale(
                          scale: pulse,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (glow > 0)
                                Container(
                                  width: 260,
                                  height: 260,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFFF3B0).withOpacity(0.06 * glow),
                                        blurRadius: 80,
                                        spreadRadius: 40,
                                      ),
                                    ],
                                  ),
                                ),
                              Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFF3B0).withOpacity(0.15 * glow),
                                      blurRadius: 50,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: _isOn
                                        ? [
                                            const Color(0xFFFFF9E6),
                                            const Color(0xFFFFE066),
                                            const Color(0xFFE6A817),
                                          ]
                                        : [
                                            const Color(0xFF2A2A3E),
                                            const Color(0xFF1A1A28),
                                            const Color(0xFF12121C),
                                          ],
                                  ),
                                  border: Border.all(
                                    color: _isOn
                                        ? const Color(0xFFFFF3B0).withOpacity(0.6)
                                        : Colors.white.withOpacity(0.06),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _isOn
                                          ? const Color(0xFFFFD700).withOpacity(0.4 * glow)
                                          : Colors.black.withOpacity(0.5),
                                      blurRadius: _isOn ? 30 : 20,
                                      spreadRadius: _isOn ? 5 : 0,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _isOn
                                      ? Icons.flashlight_on_rounded
                                      : Icons.flashlight_off_rounded,
                                  size: 64,
                                  color: _isOn
                                      ? const Color(0xFF7A4800)
                                      : Colors.white.withOpacity(0.25),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Appuyez pour ${_isOn ? 'éteindre' : 'allumer'}',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12,
                      letterSpacing: 2,
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  const Spacer(flex: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_active_outlined,
                            size: 13, color: Colors.white.withOpacity(0.18)),
                        const SizedBox(width: 6),
                        Text(
                          'Reste active en arrière-plan',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 10,
                            letterSpacing: 1.2,
                            color: Colors.white.withOpacity(0.18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
