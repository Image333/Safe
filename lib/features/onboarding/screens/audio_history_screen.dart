import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:safeg/core/services/audio_history_service.dart';
import 'package:safeg/core/theme/app_theme.dart';

class AudioHistoryScreen extends StatefulWidget {
  const AudioHistoryScreen({super.key});

  @override
  State<AudioHistoryScreen> createState() => _AudioHistoryScreenState();
}

class _AudioHistoryScreenState extends State<AudioHistoryScreen> {
  final AudioHistoryService _audioHistoryService = AudioHistoryService();
  late final AudioPlayer _audioPlayer;
  String? _currentPlayingPath;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio(String filePath) async {
    try {
      if (_currentPlayingPath == filePath && _audioPlayer.playing) {
        // Si on clique sur le même clip, pause
        await _audioPlayer.pause();
        if (mounted) {
          setState(() {
            _currentPlayingPath = null;
          });
        }
      } else {
        // Sinon, joue le nouveau clip
        await _audioPlayer.setFilePath(filePath);
        await _audioPlayer.play();

        if (mounted) {
          setState(() {
            _currentPlayingPath = filePath;
          });
        }

        // Écoute la fin de la lecture
        _audioPlayer.playerStateStream.listen((playerState) {
          if (!playerState.playing && playerState.processingState == ProcessingState.completed) {
            if (mounted) {
              setState(() {
                _currentPlayingPath = null;
              });
            }
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de lecture : $e'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  Future<void> _deleteClip(AudioClip clip) async {
    // Arrête la lecture si c'est le clip en cours
    if (_currentPlayingPath == clip.filePath) {
      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _currentPlayingPath = null;
        });
      }
    }

    // Supprime le fichier
    await clip.delete();

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enregistrement supprimé'),
          backgroundColor: AppColors.green,
        ),
      );
    }
  }

  Future<void> _deleteAllClips() async {
    await _audioPlayer.stop();
    if (mounted) {
      setState(() {
        _currentPlayingPath = null;
      });
    }

    await _audioHistoryService.deleteAllClips();

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tous les enregistrements ont été supprimés'),
          backgroundColor: AppColors.green,
        ),
      );
    }
  }

  void _showDeleteConfirmation(AudioClip clip) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Supprimer l\'enregistrement ?'),
        content: Text('${clip.getFormattedDateTime()} (${clip.getFormattedDuration()})'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteClip(clip);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAllConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Supprimer tous les enregistrements ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteAllClips();
            },
            child: const Text('Supprimer tous', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Historique audio',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: FutureBuilder<List<AudioClip>>(
        future: _audioHistoryService.getAudioClips(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.navy),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erreur : ${snapshot.error}',
                style: const TextStyle(color: AppColors.red),
              ),
            );
          }

          final clips = snapshot.data ?? [];

          if (clips.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.mic_none,
                    size: 64,
                    color: AppColors.grayLight,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Aucun enregistrement',
                    style: TextStyle(
                      color: AppColors.grayMid,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // En-tête avec info et bouton supprimer tout
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${clips.length} enregistrement${clips.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: AppColors.gray,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (clips.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.red),
                        tooltip: 'Supprimer tous les enregistrements',
                        onPressed: _showDeleteAllConfirmation,
                      ),
                  ],
                ),
              ),
              // Liste des clips
              Expanded(
                child: ListView.builder(
                  itemCount: clips.length,
                  itemBuilder: (context, index) {
                    final clip = clips[index];
                    final isPlaying = _currentPlayingPath == clip.filePath;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isPlaying ? AppColors.blueLight : AppColors.grayLight,
                        borderRadius: BorderRadius.circular(12),
                        border: isPlaying
                            ? Border.all(color: AppColors.blue, width: 2)
                            : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        leading: GestureDetector(
                          onTap: () => _playAudio(clip.filePath),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isPlaying ? AppColors.blue : AppColors.navy,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: AppColors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        title: Text(
                          clip.getFormattedDateTime(),
                          style: const TextStyle(
                            color: AppColors.gray,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'Durée : ${clip.getFormattedDuration()}',
                          style: const TextStyle(
                            color: AppColors.grayMid,
                            fontSize: 12,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: AppColors.red),
                          onPressed: () => _showDeleteConfirmation(clip),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
