import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import '../models/artwork.dart';
import 'artwork_preview_screen.dart';

class ScanScreen extends StatefulWidget {
  final List<Artwork> artworks;

  const ScanScreen({
    super.key,
    required this.artworks,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {

  CameraController? controller;

  bool isCameraReady = false;

  late AnimationController scanController;

  late final ObjectDetector objectDetector;

  @override
  void initState() {
    super.initState();

    initializeCamera();

    // ✅ ML KIT OBJECT DETECTOR
    objectDetector = ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: true,
        multipleObjects: false,
      ),
    );

    // ✅ SCAN LINE ANIMATION
    scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  // ✅ INITIALIZE CAMERA
  Future<void> initializeCamera() async {

    final cameras = await availableCameras();

    final backCamera = cameras.first;

    controller = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await controller!.initialize();

    if (!mounted) return;

    setState(() {
      isCameraReady = true;
    });
  }

  // ✅ REAL ARTWORK DETECTION
  Future<void> detectArtwork() async {

    if (controller == null ||
        !controller!.value.isInitialized) {
      return;
    }

    try {

      // ✅ TAKE PICTURE
      final XFile picture =
          await controller!.takePicture();

      // ✅ CONVERT IMAGE
      final inputImage = InputImage.fromFile(
        File(picture.path),
      );

      // ✅ PROCESS IMAGE
      final objects =
          await objectDetector.processImage(
        inputImage,
      );

      // ✅ NO OBJECT FOUND
      if (objects.isEmpty) {

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "No artwork detected",
            ),
          ),
        );

        return;
      }

      // ✅ TEMPORARY MATCHING
      // (for now opens first artwork)
      final detectedArtwork =
          widget.artworks.first;

      // ✅ OPEN ARTWORK DETAILS
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ArtworkPreviewScreen(
            artwork: detectedArtwork,
          ),
        ),
      );

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Detection failed: $e",
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    scanController.dispose();
    objectDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.black,

      body: isCameraReady
          ? Stack(
              children: [

                // ✅ LIVE CAMERA
                SizedBox.expand(
                  child: CameraPreview(controller!),
                ),

                // ✅ DARK OVERLAY
                Container(
                  color: Colors.black.withOpacity(0.25),
                ),

                // ✅ TOP BAR
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),

                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,

                      children: [

                        // ✅ BACK BUTTON
                        GestureDetector(
                          onTap: () =>
                              Navigator.pop(context),

                          child: Container(
                            padding:
                                const EdgeInsets.all(10),

                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius:
                                  BorderRadius.circular(
                                      15),
                            ),

                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        // ✅ TITLE
                        const Text(
                          "Scan Artwork",

                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        // ✅ FLASH BUTTON
                        Container(
                          padding:
                              const EdgeInsets.all(10),

                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius:
                                BorderRadius.circular(
                                    15),
                          ),

                          child: const Icon(
                            Icons.flash_off,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ✅ SCAN FRAME
                Center(
                  child: Container(
                    width: 280,
                    height: 350,

                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.amber,
                        width: 3,
                      ),

                      borderRadius:
                          BorderRadius.circular(25),
                    ),

                    child: Stack(
                      children: [

                        // ✅ ANIMATED SCAN LINE
                        AnimatedBuilder(
                          animation: scanController,

                          builder: (context, child) {

                            return Positioned(
                              top:
                                  scanController.value *
                                      300,

                              left: 0,
                              right: 0,

                              child: Container(
                                height: 4,

                                decoration:
                                    BoxDecoration(
                                  gradient:
                                      LinearGradient(
                                    colors: [
                                      Colors
                                          .transparent,

                                      Colors.amber,

                                      Colors
                                          .transparent,
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // ✅ INSTRUCTIONS
                Positioned(
                  bottom: 140,
                  left: 20,
                  right: 20,

                  child: Column(
                    children: [

                      const Text(
                        "Point camera at artwork",

                        textAlign: TextAlign.center,

                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        "AI recognition will identify the artwork",

                        textAlign: TextAlign.center,

                        style: TextStyle(
                          color: Colors.white
                              .withOpacity(0.7),

                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // ✅ DETECT BUTTON
                Positioned(
                  bottom: 50,
                  left: 40,
                  right: 40,

                  child: GestureDetector(
                    onTap: detectArtwork,

                    child: Container(
                      height: 60,

                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius:
                            BorderRadius.circular(20),
                      ),

                      child: const Center(
                        child: Text(
                          "Detect Artwork",

                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )

          : const Center(
              child: CircularProgressIndicator(
                color: Colors.amber,
              ),
            ),
    );
  }
}