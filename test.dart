import 'package:flutter/material.dart';
import 'package:web_socket/widgets/audio_widget.dart';

class AudioTest extends StatefulWidget {
  const AudioTest({super.key});

  @override
  State<AudioTest> createState() => _AudioTestState();
}

class _AudioTestState extends State<AudioTest> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: AudioRecorderWidget()),
    );
  }
}
// ==========================
// import 'dart:async';
// import 'dart:convert';
// import 'dart:developer';
// import 'dart:io';
// import 'package:audio_waveforms/audio_waveforms.dart';
// import 'package:audioplayers/audioplayers.dart';
// import 'package:flutter/material.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';

// class AudioRecorderWidget extends StatefulWidget {
//   const AudioRecorderWidget({super.key});

//   @override
//   AudioRecorderWidgetState createState() => AudioRecorderWidgetState();
// }

// class AudioRecorderWidgetState extends State<AudioRecorderWidget> {
//   late AudioPlayer _audioPlayer;
//   late RecorderController _recorderController; // Added RecorderController
//   bool isRecording = false;
//   String? filePath;
//   String? base64String;
//   StreamSubscription? _playerSubscription;
//   bool isPlaying = false;

//   @override
//   void initState() {
//     super.initState();
//     _audioPlayer = AudioPlayer();
//     _recorderController = RecorderController(); // Initialize the recorder controller
//   }

//   Future<void> _checkAndRequestPermissions() async {
//     // Check microphone permission
//     var status = await Permission.microphone.status;

//     if (status.isDenied) {
//       // Request permission
//       status = await Permission.microphone.request();
//     }
//   }

//   Future<void> _startRecording() async {
//     await _checkAndRequestPermissions(); // Check and request permissions

//     // Check if permission is granted
//     if (await Permission.microphone.isGranted) {
//       Directory tempDir = await getTemporaryDirectory();
//       filePath = '${tempDir.path}/recorded_audio.aac';

//       setState(() {
//         isRecording = true;
//       });

//       // Start recording
//       await _recorderController.record(path: filePath!);
//     }
//   }

//   Future<void> _stopRecording() async {
//     setState(() {
//       isRecording = false;
//     });

//     // Stop the recording
//     await _recorderController.stop();

//     // Convert audio to base64
//     if (filePath != null) {
//       File audioFile = File(filePath!);
//       List<int> fileBytes = await audioFile.readAsBytes();
//       base64String = base64Encode(fileBytes);
//       log("Base64 Encoded String: $base64String");
//     }
//   }

//   Future<void> _playAudio() async {
//     log('Play called');
//     if (base64String != null) {
//       List<int> audioBytes = base64Decode(base64String!);
//       String tempPath = '${(await getTemporaryDirectory()).path}/temp_audio.aac';
//       File tempFile = File(tempPath);
//       await tempFile.writeAsBytes(audioBytes);
//       await _audioPlayer.play(DeviceFileSource(tempFile.path));

//       setState(() {
//         isPlaying = true;
//       });

//       _playerSubscription = _audioPlayer.onPlayerComplete.listen((event) {
//         setState(() {
//           isPlaying = false;
//         });
//       });
//     }
//   }

//   Widget _buildWaveform() {
//     return StreamBuilder(
//       stream: _audioPlayer.onPositionChanged,
//       builder: (context, snapshot) {
//         return AudioWaveforms(
//           waveStyle: const WaveStyle(
//             waveColor: Colors.blue,
//             middleLineColor: Colors.blueAccent,
//           ),
//           recorderController: _recorderController, // Use the initialized recorder controller
//           size: const Size(double.infinity, 10),
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         _buildWaveform(), // Display the waveform
//         isRecording
//             ? IconButton(
//                 icon: const Icon(Icons.stop, color: Colors.red),
//                 onPressed: () {
//                   _stopRecording();
//                 })
//             : IconButton(
//                 icon: const Icon(Icons.mic, color: Colors.black),
//                 onPressed: () {
//                   _startRecording();
//                 },
//               ),
//         if (!isRecording && base64String != null)
//           IconButton(
//             icon: const Icon(Icons.play_arrow, color: Colors.green),
//             onPressed: () {
//               _playAudio();
//             },
//           ),
//       ],
//     );
//   }

//   @override
//   void dispose() {
//     _audioPlayer.dispose();
//     _playerSubscription?.cancel();
//     _recorderController.dispose(); // Dispose the recorder controller
//     super.dispose();
//   }
// }
