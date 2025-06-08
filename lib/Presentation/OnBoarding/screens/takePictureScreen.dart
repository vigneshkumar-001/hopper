import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import '../../../Core/Constants/texts.dart';
import '../../Authentication/widgets/textFields.dart';
import '../controller/userprofile_controller.dart';
import '../widgets/bottomNavigation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';

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
  String frontImage = '';
    bool _isDetecting = false;

  late UserProfileController controller;
  @override
  void initState() {
    super.initState();
    _initializeCamera();
    controller = Get.find<UserProfileController>(); // ✅ Safe
   _faceDetector = FaceDetector(
  options: FaceDetectorOptions(
    enableContours: true,
    enableLandmarks: true,
    enableClassification: true,
    performanceMode: FaceDetectorMode.accurate,
  ),
);

  }

  Future<void> _retakePicture() async {
    _capturedImage = null;
    _isFaceDetected = false;
    await _initializeCamera();
    setState(() {});
  }


 Future<void> _initializeCamera() async {
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
      setState(() {
        _isCameraInitialized = true;
      });
          _cameraController!.startImageStream(_processCameraImage);

    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera permission denied')),
      );
    }
  }

  
  void _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize =
          Size(image.width.toDouble(), image.height.toDouble());

      final InputImageRotation imageRotation =
          InputImageRotationValue.fromRawValue(
                  _cameraController!.description.sensorOrientation) ??
              InputImageRotation.rotation0deg;

      final inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
              InputImageFormat.nv21;

      // final planeData = image.planes.map(
      //   (Plane plane) {
      //     return InputImagePlaneMetadata(
      //       bytesPerRow: plane.bytesPerRow,
      //       height: plane.height,
      //       width: plane.width,
      //     );
      //   },
      // ).toList();

      final inputImageData = InputImageMetadata (
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: 60,
      );

      final inputImage =
          InputImage.fromBytes(bytes: bytes, metadata: inputImageData);

      final faces = await _faceDetector.processImage(inputImage);

      setState(() {
        _isFaceDetected = faces.isNotEmpty;
      });
    } catch (e) {
      print("Error in face detection: $e");
    } finally {
      _isDetecting = false;
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      final XFile picture = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(picture.path);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;
        final boundingBox = face.boundingBox;
        final imageWidth = _cameraController!.value.previewSize!.height;
        final imageHeight = _cameraController!.value.previewSize!.width;

        bool isFaceWellCentered =
            boundingBox.left > imageWidth * 0.1 &&
            boundingBox.right < imageWidth * 0.9 &&
            boundingBox.top > imageHeight * 0.2 &&
            boundingBox.bottom < imageHeight * 0.8;

        bool isFaceBigEnough =
            boundingBox.height > imageHeight * 0.4 &&
            boundingBox.width > imageWidth * 0.4;

        if (isFaceWellCentered && isFaceBigEnough) {
          setState(() {
            _capturedImage = File(picture.path);
            _isFaceDetected = true;
          });
          _cameraController!.dispose();
        } else {
          File(picture.path).delete();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: Duration(seconds: 2),
              content: Text(
                'Ensure your full face is visible and properly centered.',
              ),
            ),
          );
        }
      } else {
        File(picture.path).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No face detected. Please try again.')),
        );
      }
    }
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
                ? Center(
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 24,
                        ),
                        child: Column(
                          children: [
                            Text(
                              AppTexts.avoidRejection,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 24),
                            CustomTextfield.concatenateText(
                              title: AppTexts.avoidRejectionContent1,
                            ),
                            CustomTextfield.concatenateText(
                              title: AppTexts.avoidRejectionContent2,
                            ),
                            CustomTextfield.concatenateText(
                              title: AppTexts.avoidRejectionContent3,
                            ),
                            SizedBox(height: 32),
                            Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(150),
                                child: Image.file(
                                  _capturedImage!,
                                  width: 300,
                                  height: 300,
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                            SizedBox(height: 32),
                            TextButton(
                              onPressed: () {
                                _retakePicture();
                              },
                              child: Text(
                                'Retake Photo',
                                style: TextStyle(
                                  color: Color(0xff357AE9),
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            // Spacer(),
                            // Buttons.button(
                            //   buttonColor: AppColors.commonBlack,
                            //   onTap: () {
                            //     Navigator.push(
                            //       context,
                            //       MaterialPageRoute(
                            //         builder: (context) => NinScreens(),
                            //       ),
                            //     );
                            //   },
                            //   text: 'Upload',
                            // ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                : _isCameraInitialized
                ? Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 300,
                                height: 300,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 4),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    150,
                                  ), // Circle
                                  child:
                                  Transform(
                                            alignment: Alignment.center,
                                            transform: Matrix4.rotationY(math.pi),
                                            child:  CameraPreview(_cameraController!),
                                          )
                                  
                                ),
                              ),
                                 if (_isFaceDetected)
      Positioned.fill(
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.greenAccent, width: 3),
            // Optional: glowing effect
            boxShadow: [
              BoxShadow(
                color: Colors.greenAccent.withOpacity(0.6),
                blurRadius: 12,
                spreadRadius: 4,
              ),
            ],
          ),
        ),),
                            ],
                          ),

                          SizedBox(height: 10),
                          Text(
                            'Position yourself within the frame',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Positioned(
                    //   bottom: 30,
                    //   left: 0,
                    //   right: 0,
                    //   child: Center(
                    //     child: Buttons.button(
                    //       buttonColor: AppColors.commonBlack,
                    //       onTap: () {
                    //         _takePicture();
                    //       },
                    //       text: 'Take photo',
                    //     ),
                    //   ),
                    // ),
                  ],
                )
                : const Center(child: CircularProgressIndicator()),
      ),
      bottomNavigationBar: CustomBottomNavigation.bottomNavigation(
        title: _capturedImage != null ? 'Upload Photo' : 'Take Photo',
        onTap: () async {
          if (_capturedImage != null) {
            // await Navigator.push(
            //   context,
            //   MaterialPageRoute(builder: (context) => NinScreens()),
            // );
            await controller.userProfileUpload(context, _capturedImage!);
          } else {
            _takePicture();
          }
        },
      ),
    );
  }
}