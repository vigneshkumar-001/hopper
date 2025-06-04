import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';
import 'package:hopper/Presentation/OnBoarding/controller/userprofile_controller.dart';
import 'package:hopper/Presentation/OnBoarding/screens/face_detection.dart';
import 'package:hopper/Presentation/OnBoarding/widgets/bottomNavigation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class TakePicture extends StatefulWidget {
  final bool fromCompleteScreens;
  const TakePicture({super.key, this.fromCompleteScreens = false});

  @override
  State<TakePicture> createState() => _TakePictureState();
}

class _TakePictureState extends State<TakePicture> {
  File? _capturedImage;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  late FaceDetector _faceDetector;
  bool _isFaceDetected = false;
  late UserProfileController controller;

  Size? _imageSize;
  List<Face> _detectedFaces = [];

  @override
  void initState() {
    super.initState();
    controller = Get.find<UserProfileController>();
    _initCameraAndDetector();
  }

  Future<void> _initCameraAndDetector() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
      );
      await _cameraController!.initialize();
      setState(() => _isCameraInitialized = true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Camera permission denied')));
    }

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(enableContours: true, enableLandmarks: true),
    );
  }

  Future<void> _retakePicture() async {
    _capturedImage = null;
    _isFaceDetected = false;
    await _initCameraAndDetector();
    setState(() {});
  }

  Future<void> _takePicture() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      final XFile picture = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(picture.path);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;
        final boundingBox = face.boundingBox;

        final imageSize = _cameraController!.value.previewSize!;
        final imageWidth = imageSize.height;
        final imageHeight = imageSize.width;

        bool isFaceCentered =
            boundingBox.left > imageWidth * 0.1 &&
            boundingBox.right < imageWidth * 0.9 &&
            boundingBox.top > imageHeight * 0.2 &&
            boundingBox.bottom < imageHeight * 0.8;

        bool isFaceBigEnough =
            boundingBox.height > imageHeight * 0.4 &&
            boundingBox.width > imageWidth * 0.4;

        if (isFaceCentered && isFaceBigEnough) {
          setState(() {
            _capturedImage = File(picture.path);
            _isFaceDetected = true;
          });
          _cameraController?.dispose();
        } else {
          File(picture.path).delete();
          _showSnackBar(
            'Ensure your full face is visible and properly centered.',
          );
        }
      } else {
        File(picture.path).delete();
        _showSnackBar('No face detected. Please try again.');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(duration: Duration(seconds: 2), content: Text(message)),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.white),
      body: Obx(
        () =>
            controller.isLoading.value
                ? Center(child: CircularProgressIndicator())
                : _capturedImage != null
                ? _buildCapturedImageView()
                : _isCameraInitialized
                ? _buildCameraView()
                : Center(child: CircularProgressIndicator()),
      ),
      bottomNavigationBar: CustomBottomNavigation.bottomNavigation(
        title: _capturedImage != null ? 'Upload Photo' : 'Take Photo',
        onTap: () async {
          if (_capturedImage != null) {
            await controller.userProfileUpload(context, _capturedImage!);
          } else {
            _takePicture();
          }
        },
      ),
    );
  }

  Widget _buildCapturedImageView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          Text(
            AppTexts.avoidRejection,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 24),
          ...[
            AppTexts.avoidRejectionContent1,
            AppTexts.avoidRejectionContent2,
            AppTexts.avoidRejectionContent3,
          ].map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: CustomTextfield.concatenateText(title: text),
            ),
          ),
          SizedBox(height: 32),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(150),
              child: Image.file(
                _capturedImage!,
                width: 300,
                height: 300,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(height: 32),
          TextButton(
            onPressed: _retakePicture,
            child: Text(
              'Retake Photo',
              style: TextStyle(color: Color(0xff357AE9), fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(150),
              child: Stack(
                children: [
                  CameraPreview(_cameraController!),
                  if (_imageSize != null && _detectedFaces.isNotEmpty)
                    CustomPaint(
                      painter: FacePainter(
                        faces: _detectedFaces,
                        imageSize: _imageSize!,
                        isFrontCamera: true,
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Position yourself within the frame',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
/*  */