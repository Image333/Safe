import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';

import '../../../core/services/audio_history_service.dart';
import '../../../core/theme/app_theme.dart';

class AudioHistoryScreen extends StatefulWidget {
  const AudioHistoryScreen({super.key});

  @override
  State<AudioHistoryScreen> createState() => _AudioHistoryScreenState();
}

class _AudioHistoryScreenState extends State<AudioHistoryScreen> {
  final AudioHistoryService _historyService = AudioHistoryService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<AudioClip> _audioClips = [];
  bool _isLoading = true;
  String? _playingClipId;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadAudioClips();
    
    // Écouter les changements d'état du lecteur
    _audioPlayer.playerStateStream.listen((PlayerState state) {
      setState(() {
        _isPlaying = state.playing;
        if (state.processingState == ProcessingState.completed) {
          _playingClipId = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadAudioClips() async {
    setState(() => _isLoading = true);
    
    final clips = await _historyService.getAudioClips();
    
    setState(() {
      _audioClips = clips;
      _isLoading = false;
    });
  }

  Future<void> _playAudio(AudioClip clip) async {
    if (_playingClipId == clip.id && _isPlaying) {
      await _audioPlayer.pause();
      return;
    }

    await _audioPlayer.stop();
    final source = clip.playSource;
    if (source.isEmpty) return;

    if (clip.isRemote) {
      await _audioPlayer.setUrl(source);
    } else {
      await _audioPlayer.setFilePath(source);
    }
    await _audioPlayer.play();
    setState(() {
      _playingClipId = clip.id;
    });
  }

  Future<void> _deleteClip(AudioClip clip) async {
    if (clip.isRemote) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Suppression cloud non disponible pour le moment'),
            backgroundColor: AppColors.orange,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'enregistrement'),
        content: const Text(
          'Voulez-vous vraiment supprimer cet enregistrement ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (_playingClipId == clip.id) {
        await _audioPlayer.stop();
        setState(() => _playingClipId = null);
      }

      await clip.delete();
      await _loadAudioClips();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enregistrement supprimé'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    }
  }

  Future<void> _deleteAllClips() async {
    if (_audioClips.isEmpty) return;

    final hasRemoteOnly = _audioClips.every((c) => c.isRemote);
    if (hasRemoteOnly) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Suppression cloud non disponible pour le moment'),
            backgroundColor: AppColors.orange,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tout supprimer'),
        content: Text(
          'Voulez-vous vraiment supprimer tous les ${_audioClips.length} enregistrements locaux ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Tout supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _audioPlayer.stop();
      setState(() => _playingClipId = null);

      await _historyService.deleteAllClips();
      await _loadAudioClips();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tous les enregistrements locaux ont été supprimés'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.navy),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Enregistrements',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_audioClips.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: AppColors.red),
              onPressed: _deleteAllClips,
              tooltip: 'Tout supprimer',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _audioClips.isEmpty
              ? _buildEmptyState()
              : _buildAudioList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.blueLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic_none,
                size: 64,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aucun enregistrement',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Appuyez 3 fois sur le bouton volume + pour déclencher un enregistrement d\'urgence de 15 secondes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.grayMid,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _audioClips.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final clip = _audioClips[index];
        final isPlaying = _playingClipId == clip.id && _isPlaying;
        
        return _AudioClipCard(
          clip: clip,
          isPlaying: isPlaying,
          onPlay: () => _playAudio(clip),
          onDelete: () => _deleteClip(clip),
        );
      },
    );
  }
}

class _AudioClipCard extends StatelessWidget {
  final AudioClip clip;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const _AudioClipCard({
    required this.clip,
    required this.isPlaying,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grayLight, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPlay,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Bouton play/pause
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isPlaying ? AppColors.red : AppColors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: AppColors.white,
                    size: 28,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Informations du clip
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clip.getFormattedDateTime(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: AppColors.grayMid,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            clip.getFormattedDuration(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.grayMid,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.emergency,
                            size: 16,
                            color: AppColors.red,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Urgence',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (clip.isRemote) ...[
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.cloud_outlined,
                              size: 16,
                              color: AppColors.blue,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Cloud',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Bouton supprimer (local uniquement)
                if (!clip.isRemote)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.red,
                    onPressed: onDelete,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
