import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class ArtworkPrediction {
  final String label;
  final double confidence;
  final double secondConfidence;
  final double unknownConfidence;
  final double agreement;
  final double sceneQuality;
  final bool isUnknown;
  final List<String> topLabels;

  const ArtworkPrediction({
    required this.label,
    required this.confidence,
    required this.secondConfidence,
    this.unknownConfidence = 0,
    this.agreement = 0,
    this.sceneQuality = 0,
    this.isUnknown = false,
    required this.topLabels,
  });
}

class ArtworkDetectionService {
  Interpreter? _interpreter;
  List<String> _labels = [];

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset(
      'assets/model/model_unquant.tflite',
    );

    final labelsData = await rootBundle.loadString('assets/model/labels.txt');

    _labels = labelsData
        .split('\n')
        .map((label) => label.trim())
        .map((label) => label.replaceFirst(RegExp(r'^\d+\s+'), ''))
        .where((label) => label.isNotEmpty)
        .toList();

    debugPrint('MODEL LOADED');
    debugPrint('Labels loaded: ${_labels.length}');
    debugPrint('Input tensor: ${_interpreter!.getInputTensor(0).shape}');
    debugPrint('Output tensor: ${_interpreter!.getOutputTensor(0).shape}');
    debugPrint(_labels.toString());
  }

  Future<String> predict(Uint8List imageBytes) async {
    final result = await predictWithConfidence(imageBytes);
    return result.label;
  }

  Future<ArtworkPrediction> predictWithConfidence(Uint8List imageBytes) async {
    final interpreter = _interpreter;

    if (interpreter == null) {
      throw StateError('Artwork model is not loaded.');
    }

    final decodedImage = img.decodeImage(imageBytes);

    if (decodedImage == null) {
      return const ArtworkPrediction(
        label: 'Unknown',
        confidence: 0,
        secondConfidence: 0,
        unknownConfidence: 0,
        agreement: 0,
        sceneQuality: 0,
        isUnknown: true,
        topLabels: ['Unknown'],
      );
    }

    final orientedImage = img.bakeOrientation(decodedImage);
    final sceneQuality = _artworkSceneQuality(orientedImage);
    final outputShape = interpreter.getOutputTensor(0).shape;
    final outputLength = outputShape.last;

    if (_labels.length != outputLength) {
      debugPrint(
        'WARNING: labels count ${_labels.length} does not match model output $outputLength',
      );
    }

    final crops = _candidateCrops(orientedImage);
    final accumulatedScores = List<double>.filled(outputLength, 0);
    final cropVotes = <int, int>{};

    for (final crop in crops) {
      final scores = _runModelOnImage(interpreter, crop, outputLength);
      final topIndex = _highestIndex(scores);

      cropVotes[topIndex] = (cropVotes[topIndex] ?? 0) + 1;

      for (var i = 0; i < outputLength; i++) {
        accumulatedScores[i] += scores[i];
      }
    }

    final averagedScores = accumulatedScores
        .map((score) => score / crops.length)
        .toList(growable: false);

    final scored = List.generate(averagedScores.length, (index) {
      return MapEntry(index, averagedScores[index]);
    })..sort((a, b) => b.value.compareTo(a.value));

    final highestIndex = scored.first.key;
    final highest = scored.first.value;
    final secondHighest = scored.length > 1 ? scored[1].value : 0.0;
    final label = highestIndex < _labels.length
        ? _labels[highestIndex]
        : 'class_$highestIndex';
    final unknownIndex = _labels.indexWhere(_isUnknownLabel);
    final unknownConfidence =
        unknownIndex >= 0 && unknownIndex < averagedScores.length
        ? averagedScores[unknownIndex]
        : 0.0;
    final agreement = (cropVotes[highestIndex] ?? 0) / crops.length;
    final isUnknown = _isUnknownLabel(label);
    final topLabels = scored.take(3).map((entry) {
      final name = entry.key < _labels.length
          ? _labels[entry.key]
          : 'class_${entry.key}';
      return '$name ${(entry.value * 100).toStringAsFixed(1)}%';
    }).toList();

    debugPrint('Prediction index: $highestIndex');
    debugPrint('Prediction: $label');
    debugPrint('Confidence: $highest');
    debugPrint('Unknown confidence: $unknownConfidence');
    debugPrint('Crop agreement: $agreement');
    debugPrint('Scene quality: $sceneQuality');
    debugPrint('Top predictions: ${topLabels.join(', ')}');

    return ArtworkPrediction(
      label: label,
      confidence: highest,
      secondConfidence: secondHighest,
      unknownConfidence: unknownConfidence,
      agreement: agreement,
      sceneQuality: sceneQuality,
      isUnknown: isUnknown,
      topLabels: topLabels,
    );
  }

  List<img.Image> _candidateCrops(img.Image image) {
    return [
      _cropAround(image, scale: 1, offsetX: 0, offsetY: 0),
      _cropAround(image, scale: 0.88, offsetX: 0, offsetY: 0),
      _cropAround(image, scale: 0.80, offsetX: -0.08, offsetY: 0),
      _cropAround(image, scale: 0.80, offsetX: 0.08, offsetY: 0),
    ];
  }

  img.Image _cropAround(
    img.Image image, {
    required double scale,
    required double offsetX,
    required double offsetY,
  }) {
    final baseSize = image.width < image.height ? image.width : image.height;
    final cropSize = (baseSize * scale).round().clamp(1, baseSize).toInt();
    final centerX = (image.width / 2) + (offsetX * baseSize);
    final centerY = (image.height / 2) + (offsetY * baseSize);
    final maxX = image.width - cropSize;
    final maxY = image.height - cropSize;
    final x = (centerX - (cropSize / 2)).round().clamp(0, maxX).toInt();
    final y = (centerY - (cropSize / 2)).round().clamp(0, maxY).toInt();

    return img.copyCrop(image, x: x, y: y, width: cropSize, height: cropSize);
  }

  List<double> _runModelOnImage(
    Interpreter interpreter,
    img.Image sourceImage,
    int outputLength,
  ) {
    final resizedImage = img.copyResize(
      sourceImage,
      width: 224,
      height: 224,
      interpolation: img.Interpolation.linear,
    );

    final input = List.generate(
      1,
      (_) => List.generate(
        224,
        (y) => List.generate(224, (x) {
          final pixel = resizedImage.getPixel(x, y);

          return [
            (pixel.r / 127.5) - 1.0,
            (pixel.g / 127.5) - 1.0,
            (pixel.b / 127.5) - 1.0,
          ];
        }),
      ),
    );

    final output = List.generate(1, (_) => List.filled(outputLength, 0.0));

    interpreter.run(input, output);

    return List<double>.from(output.first);
  }

  int _highestIndex(List<double> scores) {
    var bestIndex = 0;
    var bestScore = scores.first;

    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > bestScore) {
        bestIndex = i;
        bestScore = scores[i];
      }
    }

    return bestIndex;
  }

  bool _isUnknownLabel(String label) {
    final normalized = label
        .toLowerCase()
        .replaceFirst(RegExp(r'^\d+\s+'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '');

    return normalized == 'unknown';
  }

  double _artworkSceneQuality(img.Image image) {
    final crop = _cropAround(image, scale: 0.82, offsetX: 0, offsetY: 0);
    final sample = img.copyResize(crop, width: 64, height: 64);
    final luminance = List<double>.filled(64 * 64, 0);
    var luminanceSum = 0.0;
    var saturationSum = 0.0;

    for (var y = 0; y < 64; y++) {
      for (var x = 0; x < 64; x++) {
        final pixel = sample.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();
        final luma = (0.299 * r) + (0.587 * g) + (0.114 * b);
        final maxChannel = math.max(r, math.max(g, b));
        final minChannel = math.min(r, math.min(g, b));
        final index = (y * 64) + x;

        luminance[index] = luma;
        luminanceSum += luma;
        saturationSum += (maxChannel - minChannel) / 255.0;
      }
    }

    final mean = luminanceSum / luminance.length;
    var variance = 0.0;
    var edgeCount = 0;
    var edgeTotal = 0;
    final quadrantSums = List<double>.filled(4, 0);
    final quadrantSquares = List<double>.filled(4, 0);
    final quadrantCounts = List<int>.filled(4, 0);

    for (var y = 0; y < 64; y++) {
      for (var x = 0; x < 64; x++) {
        final index = (y * 64) + x;
        final luma = luminance[index];
        final delta = luma - mean;
        final quadrant = (x >= 32 ? 1 : 0) + (y >= 32 ? 2 : 0);

        variance += delta * delta;
        quadrantSums[quadrant] += luma;
        quadrantSquares[quadrant] += luma * luma;
        quadrantCounts[quadrant]++;

        if (x < 63) {
          edgeTotal++;
          if ((luma - luminance[index + 1]).abs() > 18) {
            edgeCount++;
          }
        }

        if (y < 63) {
          edgeTotal++;
          if ((luma - luminance[index + 64]).abs() > 18) {
            edgeCount++;
          }
        }
      }
    }

    final contrastScore = (math.sqrt(variance / luminance.length) / 64.0)
        .clamp(0.0, 1.0)
        .toDouble();
    final edgeScore = ((edgeCount / edgeTotal) / 0.30)
        .clamp(0.0, 1.0)
        .toDouble();
    final saturationScore = ((saturationSum / luminance.length) / 0.24)
        .clamp(0.0, 1.0)
        .toDouble();
    final quadrantScores = List.generate(4, (index) {
      final count = quadrantCounts[index];
      final quadrantMean = quadrantSums[index] / count;
      final quadrantVariance =
          (quadrantSquares[index] / count) - (quadrantMean * quadrantMean);

      return (math.sqrt(quadrantVariance.clamp(0.0, double.infinity)) / 52.0)
          .clamp(0.0, 1.0)
          .toDouble();
    });
    final fillScore = quadrantScores.reduce(math.min);

    return ((contrastScore * 0.34) +
            (edgeScore * 0.34) +
            (saturationScore * 0.20) +
            (fillScore * 0.12))
        .clamp(0.0, 1.0)
        .toDouble();
  }
}
