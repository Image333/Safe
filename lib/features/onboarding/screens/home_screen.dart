import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/emergency_audio_service.dart';
import '../../../core/services/voice_trigger_service.dart';
import '../../../core/services/volume_trigger_service.dart';
import '../../../core/services/audio_history_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _isProtected = false;
  bool _alertSent = false;
  bool _isRecordingClip = false;
  String? _lastClipPath;
  int _audioClipsCount = 0;

  final VoiceTriggerService _voiceTriggerService = VoiceTriggerService();
  final EmergencyAudioService _emergencyAudioService = EmergencyAudioService();
  final VolumeTriggerService _volumeTriggerService = VolumeTriggerService();
  final AudioHistoryService _audioHistoryService = AudioHistoryService();

  // Animations de pulsation
  late AnimationController _pulseController1;
  late AnimationController _pulseController2;
  late Animation<double> _pulseAnim1;
  late Animation<double> _pulseAnim2;

  // Animation du bouton pressé
  late AnimationController _pressController;
  late Animation<double> _pressAnim;

  // Contacts fictifs pour la démo — à remplacer par les vrais
  final List<Map<String, String>> _contacts = [
    {'name': 'Maman', 'phone': '06 12 34 56 78'},
    {'name': 'Léa', 'phone': '07 98 76 54 32'},
  ];

  @override
  void initState() {
    super.initState();

    _pulseController1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: false);

    _pulseController2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: false);

    // Décalage de la 2e vague
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _pulseController2.forward();
    });

    _pulseAnim1 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController1, curve: Curves.easeOut),
    );
    _pulseAnim2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController2, curve: Curves.easeOut),
    );

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _pressAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );

    _loadAudioClipsCount();
  }

  @override
  void dispose() {
    _pulseController1.dispose();
    _pulseController2.dispose();
    _pressController.dispose();
    _volumeTriggerService.dispose();
    _emergencyAudioService.dispose();
    super.dispose();
  }

  Future<void> _loadAudioClipsCount() async {
    final count = await _audioHistoryService.getAudioClipsCount();
    if (mounted) {
      setState(() => _audioClipsCount = count);
    }
  }
  Future<void> _toggleProtection(bool enabled) async {
    setState(() => _isProtected = enabled);

    if (enabled) {
      try {
        await _volumeTriggerService.startListening(
          callback: () {
            // Appelé quand une triple pression est détectée
            if (mounted) {
              _triggerAlert();
            }
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: const Row(children: [
                Icon(Icons.shield_outlined, color: AppColors.white),
                SizedBox(width: 10),
                Text(
                  'Protection activée - Appuyez 3× sur Volume +',
                  style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProtected = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Text(
                'Erreur: $e',
                style: const TextStyle(color: AppColors.white),
              ),
            ),
          );
        }
      }
    } else {
      await _volumeTriggerService.stopListening();
    }
  }



  void _onAlertPressed() async {
    // Animation pression
    await _pressController.forward();
    await _pressController.reverse();

    if (!_alertSent) {
      _showCountdown();
    }
  }

  void _showCountdown() {
    int countdown = 3;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          // Lance le compte à rebours
          Future.delayed(const Duration(seconds: 1), () {
            if (!ctx.mounted) return;
            setLocal(() => countdown--);
            if (countdown <= 0) {
              Navigator.of(ctx).pop();
              _triggerAlert();
            }
          });

          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                countdown > 0 ? '$countdown' : '!',
                style: const TextStyle(fontSize: 96, fontWeight: FontWeight.bold, color: AppColors.white),
              ),
              const SizedBox(height: 12),
              const Text('Alerte dans…', style: TextStyle(fontSize: 20, color: AppColors.white)),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppColors.white.withOpacity(0.4)),
                  ),
                  child: const Text('Annuler', style: TextStyle(fontSize: 16, color: AppColors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          );
        });
      },
    );
  }

  void _triggerAlert() {
    setState(() => _alertSent = true);
    _recordEmergencyClip();

    // TODO : appel backend Go + GPS
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Row(children: [
          Icon(Icons.check_circle, color: AppColors.white),
          SizedBox(width: 10),
          Text('Alerte envoyée à vos contacts', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600)),
        ]),
      ),
    );

    // Reset après 5 secondes
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _alertSent = false);
    });
  }

  Future<void> _recordEmergencyClip() async {
    if (_isRecordingClip) return;

    setState(() => _isRecordingClip = true);

    try {
      final config = await _voiceTriggerService.getConfig();
      final durationSec = config.recordingDurationSec;

      final path = await _emergencyAudioService.recordClip(
        durationSec: durationSec,
      );

      if (!mounted) return;
      setState(() => _lastClipPath = path);

      // Recharger le compteur d'enregistrements
      await _loadAudioClipsCount();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.navy,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.mic, color: AppColors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Clip audio enregistré (${_formatDuration(durationSec)}).',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(
            'Échec enregistrement audio : $e',
            style: const TextStyle(color: AppColors.white),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRecordingClip = false);
      }
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    if (remaining == 0) return '${minutes}min';
    return '${minutes}min ${remaining}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          _buildStatusBanner(),
          const Spacer(),
          _buildPulseButton(),
          const SizedBox(height: 16),
          _buildAlertLabel(),
          const Spacer(),
          _buildContactsSection(),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.shield_outlined, color: AppColors.white, size: 20),
        ),
        const SizedBox(width: 10),
        const Text('Safe', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
        const Spacer(),
        // Bouton historique audio
        Stack(
          children: [
            IconButton(
              onPressed: () async {
                await Navigator.pushNamed(context, AppRouter.audioHistory);
                _loadAudioClipsCount();
              },
              icon: const Icon(Icons.mic_none, color: AppColors.grayMid),
              tooltip: 'Enregistrements',
            ),
            if (_audioClipsCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    _audioClipsCount > 9 ? '9+' : '$_audioClipsCount',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        // Bouton camouflage
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.remove_red_eye_outlined, color: AppColors.grayMid),
          tooltip: 'Mode camouflage',
        ),
        // Paramètres
        IconButton(
          onPressed: () => Navigator.pushNamed(context, AppRouter.settings),
          icon: const Icon(Icons.settings_outlined, color: AppColors.grayMid),
        ),
      ]),
    );
  }

  // ── Bannière statut ───────────────────────────────────────────────────────
  Widget _buildStatusBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isProtected ? AppColors.greenLight : AppColors.redLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isProtected ? AppColors.green.withOpacity(0.4) : AppColors.red.withOpacity(0.4),
        ),
      ),
      child: Row(children: [
        Icon(
          _isProtected ? Icons.shield : Icons.shield_outlined,
          color: _isProtected ? AppColors.green : AppColors.red,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            _isProtected ? 'Protection active' : 'Protection désactivée',
            style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: _isProtected ? AppColors.green : AppColors.red,
            ),
          ),
          Text(
            _isProtected
              ? 'Safe fonctionne en arrière-plan'
              : 'Appuyez pour activer la protection',
            style: TextStyle(fontSize: 12, color: (_isProtected ? AppColors.green : AppColors.red).withOpacity(0.8)),
          ),
        ])),
        Switch(
          value: _isProtected,
          onChanged: _toggleProtection,
          activeColor: AppColors.green,
        ),
      ]),
    );
  }

  // ── Bouton pulsant ────────────────────────────────────────────────────────
  Widget _buildPulseButton() {
    final color = _alertSent ? AppColors.red : (_isProtected ? AppColors.navy : AppColors.grayMid);

    return GestureDetector(
      onTap: _isProtected ? _onAlertPressed : null,
      child: SizedBox(
        width: 240, height: 240,
        child: Stack(alignment: Alignment.center, children: [
          // Vague 1
          if (_isProtected && !_alertSent)
            AnimatedBuilder(
              animation: _pulseAnim1,
              builder: (_, __) => _buildWave(_pulseAnim1.value, color),
            ),
          // Vague 2
          if (_isProtected && !_alertSent)
            AnimatedBuilder(
              animation: _pulseAnim2,
              builder: (_, __) => _buildWave(_pulseAnim2.value, color),
            ),
          // Bouton central
          ScaleTransition(
            scale: _pressAnim,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _alertSent ? AppColors.red : color,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(
                  _alertSent ? Icons.check : Icons.notifications_active_outlined,
                  color: AppColors.white,
                  size: 44,
                ),
                const SizedBox(height: 6),
                Text(
                  _alertSent ? 'Envoyé' : 'SOS',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildWave(double value, Color color) {
    return Container(
      width: 160 + (80 * value),
      height: 160 + (80 * value),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity((1 - value) * 0.15),
      ),
    );
  }

  // ── Label sous le bouton ──────────────────────────────────────────────────
  Widget _buildAlertLabel() {
    return Column(children: [
      Text(
        _alertSent
          ? 'Vos contacts ont été alertés'
          : (_isProtected ? 'Appuyez pour déclencher une alerte' : 'Activez la protection pour utiliser Safe'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          color: _alertSent ? AppColors.red : AppColors.grayMid,
          fontWeight: _alertSent ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      if (_isProtected && !_alertSent) ...[
        const SizedBox(height: 6),
        const Text(
          'Ou appuyez 3× sur le bouton volume',
          style: TextStyle(fontSize: 13, color: AppColors.grayMid),
        ),
      ],
      if (_isRecordingClip) ...[
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text(
              'Enregistrement audio en cours…',
              style: TextStyle(fontSize: 12, color: AppColors.grayMid),
            ),
          ],
        ),
      ] else if (_lastClipPath != null) ...[
        const SizedBox(height: 10),
        const Text(
          'Dernier clip audio enregistré localement.',
          style: TextStyle(fontSize: 12, color: AppColors.grayMid),
          textAlign: TextAlign.center,
        ),
      ],
    ]);
  }

  // ── Section contacts ──────────────────────────────────────────────────────
  Widget _buildContactsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Contacts de confiance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.gray)),
          const Spacer(),
          GestureDetector(
            onTap: () {}, // TODO : naviguer vers settings contacts
            child: const Text('Modifier', style: TextStyle(fontSize: 13, color: AppColors.blue, fontWeight: FontWeight.w500)),
          ),
        ]),
        const SizedBox(height: 12),
        if (_contacts.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.redLight, borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.warning_amber_outlined, color: AppColors.red, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text('Aucun contact configuré — l\'alerte ne sera pas envoyée.', style: TextStyle(fontSize: 13, color: AppColors.red))),
            ]),
          )
        else
          Row(
            children: _contacts.map((c) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: c == _contacts.last ? 0 : 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.blueLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.blue.withOpacity(0.2)),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.navy,
                    child: Text(
                      c['name']![0].toUpperCase(),
                      style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c['name']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy), overflow: TextOverflow.ellipsis),
                    Text(c['phone']!, style: const TextStyle(fontSize: 11, color: AppColors.grayMid), overflow: TextOverflow.ellipsis),
                  ])),
                ]),
              ),
            )).toList(),
          ),
      ]),
    );
  }
}