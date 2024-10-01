import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class WaveBubble extends StatefulWidget {
  final String audioBytes;
  final PlayerController audioController;

  const WaveBubble({
    super.key,
    required this.audioBytes,
    required this.audioController,
  });

  @override
  State<WaveBubble> createState() => _WaveBubbleState();
}

class _WaveBubbleState extends State<WaveBubble> {
  // late PlayerController controller;
  late StreamSubscription<PlayerState> playerStateSubscription;
  String? tempAudioFilePath;
  final playerWaveStyle = const PlayerWaveStyle(
    fixedWaveColor: Colors.white54,
    liveWaveColor: Colors.white,
    spacing: 6,
  );

  @override
  void initState() {
    super.initState();
    _saveAndPreparePlayer();
    // controller = PlayerController();
    playerStateSubscription = widget.audioController.onPlayerStateChanged.listen((_) {
      setState(() {});
    });
  }

  Future<void> _saveAndPreparePlayer() async {
    try {
      final uniqueFileName = "${const Uuid().v4()}.m4a";
      final tempDir = await getTemporaryDirectory();
      tempAudioFilePath = "${tempDir.path}/$uniqueFileName";
      // tempAudioFilePath = "${tempDir.path}/temp_audio.m4a";
      // Decode the audio bytes and write them to a temporary file
      final file = File(tempAudioFilePath!); // Safely unwrap the nullable variable
      await file.writeAsBytes(base64.decode(widget.audioBytes)); // Convert to bytes
      // setState(() {});
      // Prepare player with the temp file
      await widget.audioController.preparePlayer(
        path: tempAudioFilePath!,
        shouldExtractWaveform: true,
        noOfSamples: 30,
      );
    } catch (e) {
      debugPrint('Error saving audio file: $e');
      tempAudioFilePath = null; // Set to null if there's an error
    }
  }

  @override
  void dispose() {
    playerStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return tempAudioFilePath != null
        ? Container(
            padding: const EdgeInsets.only(
              bottom: 6,
              top: 6,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [
                  Colors.blue,
                  Color.fromARGB(255, 253, 3, 48),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!widget.audioController.playerState.isStopped)
                  IconButton(
                    onPressed: () async {
                      widget.audioController.playerState.isPlaying
                          ? await widget.audioController.pausePlayer()
                          : await widget.audioController.startPlayer(
                              finishMode: FinishMode.pause,
                            );
                    },
                    icon: Icon(
                      widget.audioController.playerState.isPlaying ? Icons.stop : Icons.play_arrow,
                    ),
                    color: Colors.white,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                AudioFileWaveforms(
                  size: Size(MediaQuery.of(context).size.width / 2, 40),
                  playerController: widget.audioController,
                  // waveformType: widget.index?.isOdd ?? false ? WaveformType.fitWidth : WaveformType.long,
                  waveformType: WaveformType.fitWidth,
                  playerWaveStyle: playerWaveStyle,
                ),
                const SizedBox(width: 10),
              ],
            ),
          )
        : const SizedBox.shrink();
  }
}
