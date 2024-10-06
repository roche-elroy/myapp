import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the cameras
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  const MyApp({Key? key, required this.camera}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Object Detection App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ObjectDetectionScreen(camera: camera),
    );
  }
}

class ObjectDetectionScreen extends StatefulWidget {
  final CameraDescription camera;

  const ObjectDetectionScreen({Key? key, required this.camera})
      : super(key: key);

  @override
  _ObjectDetectionScreenState createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  late ObjectDetector _objectDetector;
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();

    // Initialize camera controller
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
    );

    _initializeControllerFuture = _controller.initialize();

    // Initialize object detector
    _objectDetector = ObjectDetector(
      options: ObjectDetectorOptions(
        classifyObjects: true,
        multipleObjects: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _objectDetector.close();
    super.dispose();
  }

  // Detect objects in each camera frame
  void detectObjects(CameraImage image) async {
    if (_isDetecting) return;

    _isDetecting = true;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (var plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        inputImageData: InputImageData(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          imageRotation: InputImageRotation.rotation0deg,
          inputImageFormat: InputImageFormat.nv21,
          planeData: image.planes.map(
            (Plane plane) {
              return InputImagePlaneMetadata(
                bytesPerRow: plane.bytesPerRow,
                height: plane.height,
                width: plane.width,
              );
            },
          ).toList(),
        ),
      );

      final objects = await _objectDetector.processImage(inputImage);

      // Print detected objects
      for (DetectedObject detectedObject in objects) {
        final rect = detectedObject.boundingBox;
        final labels =
            detectedObject.labels.map((label) => label.text).toList();
        print('Detected object at rect: $rect with labels: $labels');
      }
    } catch (e) {
      print('Error detecting objects: $e');
    }

    _isDetecting = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Object Detection'),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.camera),
        onPressed: () async {
          try {
            await _initializeControllerFuture;
            // Start capturing frames for detection
            _controller.startImageStream((image) => detectObjects(image));
          } catch (e) {
            print(e);
          }
        },
      ),
    );
  }
}
