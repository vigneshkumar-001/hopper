import 'dart:convert';
import 'dart:developer';

import 'dart:io';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Presentation/Authentication/models/loginResponse.dart';
import 'package:hopper/Presentation/Authentication/models/otp_response.dart';
import 'package:hopper/Presentation/DriverScreen/models/get_driver_status.dart';
import 'package:hopper/Presentation/DriverScreen/models/weekly_challenge_models.dart';
import 'package:hopper/Presentation/OnBoarding/controller/chooseservice_controller.dart';
import 'package:hopper/Presentation/OnBoarding/models/baseinfo_response.dart';
import 'package:hopper/Presentation/OnBoarding/models/chooseservice_model.dart';
import 'package:hopper/Presentation/OnBoarding/models/getuserdetails_models.dart';
import 'package:hopper/Presentation/OnBoarding/models/guidelines_Models.dart';
import 'package:hopper/Presentation/OnBoarding/models/stateList_Models.dart';
import 'package:hopper/Presentation/OnBoarding/models/userImage_models.dart';
import 'package:hopper/Presentation/OnBoarding/models/yearandcolor_Models.dart';
import 'package:hopper/Presentation/OnBoarding/screens/chooseService.dart';
import 'package:hopper/api/repository/api_constents.dart';
import 'package:hopper/api/repository/request.dart';
import 'package:hopper/utils/sharedprefsHelper/sharedprefs_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Presentation/Authentication/controller/authController.dart';
import '../../Presentation/Drawer/model/ride_history_response.dart';
import '../../Presentation/DriverScreen/models/booking_accept_model.dart';
import '../../Presentation/DriverScreen/models/driver_online_status_model.dart';
import '../../Presentation/DriverScreen/models/get_todays_activity_models.dart';
import '../../Presentation/DriverScreen/models/today_parcel_activity_response.dart';
import '../repository/failure.dart';
import 'package:dio/dio.dart';
import 'package:dartz/dartz.dart';

abstract class BaseApiDataSource {
  Future<Either<Failure, LoginResponse>> mobileNumberLogin(
    String mobileNumber,
    String countryCode,
  );
}

class ApiDataSource extends BaseApiDataSource {
  @override
  // Future<Either<Failure, LoginResponse>> mobileNumberLogin(
  //   String mobileNumber,
  // ) async {
  //   try {
  //     String url = ApiConstents.loginApi;
  //
  //     dynamic response = await Request.sendRequest(
  //       url,
  //       {"mobileNumber": mobileNumber},
  //       'Post',
  //       false,
  //     );
  //     if (response is! DioException && response.statusCode == 200) {
  //       if (response.data['status'] == "200") {
  //         return Right(LoginResponse.fromJson(response.data));
  //       } else {
  //         return Left(ServerFailure(response.data['message']));
  //       }
  //     } else {
  //       return Left(ServerFailure((response as DioException).message ?? ""));
  //     }
  //   } catch (e) {
  //     CommonLogger.log.e(e);
  //     return Left(ServerFailure(''));
  //   }
  // }
  Future<Either<Failure, LoginResponse>> mobileNumberLogin(
    String mobileNumber,
    String countryCode,
  ) async {
    try {
      String url = ApiConstents.loginApi;

      dynamic response = await Request.sendRequest(
        url,
        {
          "mobileNumber": mobileNumber,
          "type": "Mobile",
          "countryCode": countryCode,
        },
        'Post',
        false,
      );

      if (response.statusCode == 200) {
        if (response.data['status'] == 200) {
          return Right(LoginResponse.fromJson(response.data));
        } else {
          return Left(
            ServerFailure(response.data['message'] ?? "Login failed"),
          );
        }
      } else if (response is Response) {
        return Left(
          ServerFailure(response.data['message'] ?? "Unexpected error"),
        );
      } else {
        return Left(ServerFailure("Unknown error occurred"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, LoginResponse>> emailLogin(String emailId) async {
    try {
      String url = ApiConstents.resendOTP;

      dynamic response = await Request.sendRequest(
        url,
        {"type": "email", "email": emailId},
        'Post',
        false,
      );

      if (response.statusCode == 200) {
        if (response.data['status'] == 200) {
          return Right(LoginResponse.fromJson(response.data));
        } else {
          return Left(
            ServerFailure(response.data['message'] ?? "Login failed"),
          );
        }
      } else if (response is Response) {
        return Left(
          ServerFailure(response.data['message'] ?? "Unexpected error"),
        );
      } else {
        return Left(ServerFailure("Unknown error occurred"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, OtpResponse>> googleSignInWithFirebase({
    required String uniqueId,
    required String email,
  }) async {
    try {
      String url = ApiConstents.loginApi;

      dynamic response = await Request.sendRequest(
        url,
        {
          "uniqueId":
              uniqueId, // e.g., Google sub, Apple user ID, or email //Mandatory
          "provider": "google", // or "apple", "email"
          "type": "social",
          "email": email,
        },
        'Post',
        false,
      );

      if (response.statusCode == 200) {
        if (response.data['status'] == 200) {
          return Right(OtpResponse.fromJson(response.data));
        } else {
          return Left(
            ServerFailure(response.data['message'] ?? "Login failed"),
          );
        }
      } else if (response is Response) {
        return Left(
          ServerFailure(response.data['message'] ?? "Unexpected error"),
        );
      } else {
        return Left(ServerFailure("Unknown error occurred"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, OtpResponse>> verifyOtp(String otp) async {
    try {
      String url = ApiConstents.verifyOtp;

      dynamic response = await Request.sendRequest(
        url,

        {
          "mobileNumber": getMobileNumber,
          "type": "Mobile",
          "countryCode": countryCodes,
          "otp": otp,
        },
        'Post',
        false,
      );
      CommonLogger.log.i(response);
      if (response is Response && response.statusCode == 200) {
        if (response.data['status'] == 200) {
          return Right(OtpResponse.fromJson(response.data));
        } else {
          return Left(
            ServerFailure(response.data['message'] ?? "Login failed"),
          );
        }
      } else if (response is Response) {
        return Left(
          ServerFailure(response.data['message'] ?? "Unexpected error"),
        );
      } else {
        return Left(ServerFailure("Unknown error occurred"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, OtpResponse>> emailOtp({
    required String otp,
    required String email,
    required String type,
  }) async {
    try {
      String url = ApiConstents.verifyOtpProtect;

      Map<String, dynamic> data;

      if (type == "email") {
        data = {"email": email, "otp": otp, "type": "email"};
      } else {
        data = {
          "countryCode": countryCodes,
          "mobileNumber": getMobileNumber,
          "otp": otp,
          "type": "Mobile",
        };
      }

      dynamic response = await Request.sendRequest(url, data, 'Post', true);
      CommonLogger.log.i(response);
      if (response is Response && response.statusCode == 200) {
        if (response.data['status'] == 200) {
          return Right(OtpResponse.fromJson(response.data));
        } else {
          return Left(
            ServerFailure(response.data['message'] ?? "Login failed"),
          );
        }
      } else if (response is Response) {
        return Left(
          ServerFailure(response.data['message'] ?? "Unexpected error"),
        );
      } else {
        return Left(ServerFailure("Unknown error occurred"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, OtpResponse>> resendOtp(
    String mobileNumber, {
    String? type,
    required String email,
    // String otp,
  }) async {
    try {
      String url = ApiConstents.resendOTP;
      Map<String, dynamic> data;

      if (type == "Email") {
        data = {"type": "email", "email": email};
      } else {
        data = {
          "type": "Mobile", //or email,
          "mobileNumber": mobileNumber, //email:"nnxnx@mml.com",
          "countryCode": countryCodes,
        };
      }
      dynamic response = await Request.sendRequest(url, data, 'Post', false);
      if (response is Response && response.statusCode == 200) {
        if (response.data['status'] == 200) {
          final result = OtpResponse.fromJson(response.data);
          return Right(result);
        } else {
          return Left(ServerFailure(response.data['message']));
        }
      } else {
        return Left(ServerFailure((response as DioException).message ?? ""));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure(''));
    }
  }

  Future<Either<Failure, ChooseServiceModel>> chooseService({
    required String serviceType,
  }) async {
    try {
      String url = ApiConstents.updateUserDetails;

      final response = await Request.sendRequest(
        url,
        {"serviceType": serviceType, "type": "Service"},
        'Post',
        true,
      );

      if (response is Response && response.statusCode == 200) {
        if (response.data['status'] == 200) {
          final result = ChooseServiceModel.fromJson(response.data);
          return Right(result);
        } else {
          return Left(ServerFailure(response.data['message']));
        }
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message']));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, GetUserProfileModel>> getUserDetails() async {
    try {
      String url =
          "https://hoppr-backend-3d2b7f783917.herokuapp.com/api/users/getUserDetailsById";

      // Send GET request with the token in the header
      final response = await Request.sendGetRequest(url, {}, 'GET', true);

      if (response is Response && response.statusCode == 200) {
        // Parse the response data into your model
        final result = GetUserProfileModel.fromJson(response.data['data']);

        // Debugging the response to check if data is correctly fetched

        // Return success with the result wrapped in `Right`
        return Right(result);
      } else if (response is Response && response.statusCode == 409) {
        // Server-specific error with message
        return Left(ServerFailure(response.data['message']));
      } else if (response is Response) {
        // General error with message
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        // In case of an unexpected response type
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      // Catching any exception and logging it
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, BasicInfoResponse>> basicInfo({
    required String mobileNumber,
    required String dateOfBirth,
    required String name,
    required String lastName,
    required String gender,
    required String email,
    required String countryCode,
  }) async {
    try {
      String url = ApiConstents.updateUserDetails;
      CommonLogger.log.i('selectedCountryCodes = $countryCodes');

      final response = await Request.sendRequest(
        url,

        {
          "type": "Basic Info",
          "data": {
            "firstName": name,
            "lastName": lastName,
            "dob": dateOfBirth,
            "mobileNumber": mobileNumber,
            "countryCode": countryCode,
            "gender": gender,
            "email": email,
          },
          "reVerify": true,
        },

        'Post',
        true,
      );

      if (response is Response && response.statusCode == 200) {
        if (response.data['status'] == 200) {
          final result = BasicInfoResponse.fromJson(response.data);
          return Right(result);
        } else {
          return Left(ServerFailure(response.data['message']));
        }
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message']));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, BasicInfoResponse>> driverAddress({
    required String address,
    required String city,
    required String state,
    required String postCode,
  }) async {
    try {
      String? userId = await SharedPrefHelper.getUserId();
      String url = ApiConstents.updateUserDetails;

      final response = await Request.sendRequest(
        url,
        {
          "type": "Driver Address Details",

          "data": {
            "address": address,
            "city": city,
            "state": state,
            "postalCode": postCode,
          },
        },

        'Post',
        true,
      );

      if (response is Response && response.statusCode == 200) {
        if (response.data['status'] == 200) {
          final result = BasicInfoResponse.fromJson(response.data);
          return Right(result);
        } else {
          return Left(ServerFailure(response.data['message']));
        }
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message']));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, UserImageModels>> userProfileUpload({
    required File imageFile,
  }) async {
    try {
      if (!await imageFile.exists()) {
        return Left(ServerFailure('Image file does not exist.'));
      }

      String url = ApiConstents.userImageUpload;
      FormData formData = FormData.fromMap({
        'images': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last,
        ),
      });

      final response = await Request.formData(url, formData, 'POST', true);
      Map<String, dynamic> responseData =
          jsonDecode(response.data) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        if (responseData['status'] == true) {
          return Right(UserImageModels.fromJson(responseData));
        } else {
          return Left(ServerFailure(responseData['message']));
        }
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(responseData['message']));
      } else if (response is Response) {
        return Left(ServerFailure(responseData['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, ChooseServiceModel>> carOwnerShip({
    required String carOwnership,
    required String carOwnerName,
    required String carOwnerPlateNumber,
    required String serviceType,
  }) async {
    try {
      String url = ApiConstents.updateUserDetails;

      Map<String, dynamic> data;

      if (serviceType == "Car") {
        data = {
          "type": "Car Ownership Details",
          "serviceType": "Car",
          "data": {
            "carOwnership": carOwnership,
            "carOwnerName": carOwnerName,
            "carPlateNumber": carOwnerPlateNumber,
          },
        };
      } else if (serviceType == "Bike") {
        data = {
          "type": "Bike Ownership Details",
          "serviceType": "Bike",
          "data": {
            "bikeOwnership": carOwnership,
            "bikeOwnerName": carOwnerName,
            "bikePlateNumber": carOwnerPlateNumber,
          },
        };
      } else {
        return Left(ServerFailure("Invalid service type"));
      }
      CommonLogger.log.i(data);
      final response = await Request.sendRequest(url, data, 'Post', true);

      if (response is Response && response.statusCode == 200) {
        if (response.data['status'] == 200) {
          final result = ChooseServiceModel.fromJson(response.data);
          return Right(result);
        } else {
          return Left(ServerFailure(response.data['message']));
        }
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message']));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, ChooseServiceModel>> ninVerification({
    required String ninNumber,
    required String frontImage,
    required String binNumber,
    required String backImage,
  }) async {
    try {
      String url = ApiConstents.updateUserDetails;

      final response = await Request.sendRequest(
        url,
        {
          "type": "NIN Verification",
          "data": {
            "bankVerificationNumber": binNumber,
            "nationalIdNumber": ninNumber,
            "frontIdCardNin": frontImage,
            "backIdCardNin": backImage,
          },
        },

        'Post',
        true,
      );

      if (response is Response && response.statusCode == 200) {
        if (response.data['status'] == 200) {
          final result = ChooseServiceModel.fromJson(response.data);
          return Right(result);
        } else {
          return Left(ServerFailure(response.data['message']));
        }
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message']));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, ChooseServiceModel>> driverLicense({
    required String licenseNumber,
    required String frontImage,
    required String backImage,
  }) async {
    try {
      String url = ApiConstents.updateUserDetails;

      final response = await Request.sendRequest(
        url,
        {
          "type": "Driver License",
          "data": {
            "driverLicenseNumber": licenseNumber,
            "frontIdCardDln": frontImage,
            "backIdCardDln": backImage,
          },
        },

        'Post',
        true,
      );

      if (response is Response && response.statusCode == 200) {
        if (response.data['status'] == 200) {
          final result = ChooseServiceModel.fromJson(response.data);
          return Right(result);
        } else {
          return Left(ServerFailure(response.data['message']));
        }
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message']));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, ChooseServiceModel>> userImageUpload({
    required String frontImage,
  }) async {
    try {
      String url = ApiConstents.updateUserDetails;

      final response = await Request.sendRequest(
        url,
        {
          "type": "Profile Photo",
          "data": {"profilePic": frontImage},
        },

        'Post',
        true,
      );

      if (response is Response && response.statusCode == 200) {
        if (response.data['status'] == 200) {
          final result = ChooseServiceModel.fromJson(response.data);
          return Right(result);
        } else {
          return Left(ServerFailure(response.data['message']));
        }
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message']));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, ChooseServiceModel>> vehicleDetails({
    required String carBrand,
    required String carModel,
    required String carYear,
    required String carColor,
    required String registerNumber,
    required String frontImageFile,
    required String backImageFile,
    required String serviceType,
  }) async {
    try {
      String url = ApiConstents.updateUserDetails;

      Map<String, dynamic> data;

      if (serviceType == "Car") {
        data = {
          "type": "Car Details",
          "data": {
            "carBrand": carBrand,
            "carModel": carModel,
            "carYear": carYear,
            "carColor": carColor,
            "carRegistrationNumber": registerNumber,
            "carRoadWorthinessCertificate": frontImageFile,
            "carInsuranceDocument": backImageFile,
          },
        };
      } else if (serviceType == "Bike") {
        data = {
          "type": "Bike Details",
          "data": {
            "bikeBrand": carBrand,
            "bikeModel": carModel,
            "bikeYear": carYear,
            "bikeColor": carColor,
            "bikeRegistrationNumber": registerNumber,
            "bikeRoadWorthinessCertificate": frontImageFile,
            "bikeInsuranceDocument": backImageFile,
          },
        };
      } else {
        return Left(ServerFailure("Invalid service type"));
      }
      CommonLogger.log.i(data);
      final response = await Request.sendRequest(url, data, 'Post', true);

      if (response is Response && response.statusCode == 200) {
        if (response.data['status'] == 200) {
          final result = ChooseServiceModel.fromJson(response.data);
          return Right(result);
        } else {
          return Left(ServerFailure(response.data['message']));
        }
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message']));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, ChooseServiceModel>> uploadExteriorImage({
    required List<String> imageUrls,
    required String serviceType,
  }) async {
    try {
      String url = ApiConstents.updateUserDetails;
      // {
      //   "type": "Bike Photos",
      //   "data": {
      //     "bikePhotos": [
      //       "https://example.com/uploads/bike-front.jpg",
      //       "https://example.com/uploads/bike-front.jpg",
      //       "https://example.com/uploads/bike-front.jpg",
      //       "https://example.com/uploads/bike-front.jpg",
      //       "https://example.com/uploads/bike-front.jpg",
      //       "https://example.com/uploads/bike-side.jpg"
      //     ]
      //   }
      // }
      Map<String, dynamic> data;

      if (serviceType == "Car") {
        data = {
          "type": "Exterior Photos",
          "data": {"carExteriorPhotos": imageUrls},
        };
      } else if (serviceType == "Bike") {
        data = {
          "type": "Bike Photos",
          "data": {"bikePhotos": imageUrls},
        };
      } else {
        return Left(ServerFailure("Invalid service type"));
      }
      CommonLogger.log.i(data);
      final response = await Request.sendRequest(url, data, 'Post', true);

      if (response is Response && response.statusCode == 200) {
        if (response.data['status'] == 200) {
          final result = ChooseServiceModel.fromJson(response.data);
          return Right(result);
        } else {
          return Left(ServerFailure(response.data['message']));
        }
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message']));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, ChooseServiceModel>> uploadInteriorImage({
    required List<String> imageUrls,
  }) async {
    try {
      String url = ApiConstents.updateUserDetails;

      final response = await Request.sendRequest(
        url,
        {
          "type": "Interior Photos",
          "data": {"carInteriorPhotos": imageUrls},
        },

        'Post',
        true,
      );

      if (response is Response && response.statusCode == 200) {
        if (response.data['status'] == 200) {
          final result = ChooseServiceModel.fromJson(response.data);
          return Right(result);
        } else {
          return Left(ServerFailure(response.data['message']));
        }
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message']));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, StateListModels>> fetchCities() async {
    try {
      String url = ApiConstents.states;

      final response = await Request.sendGetRequest(url, {}, 'GET', true);

      if (response is Response && response.statusCode == 200) {
        final result = StateListModels.fromJson(response.data);
        CommonLogger.log.i(response.data);
        return Right(result);
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message']));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, StateListModels>> getCityList(String state) async {
    try {
      String url =
          'https://hoppr-backend-3d2b7f783917.herokuapp.com/api/users/districts?state=$state';

      final response = await Request.sendGetRequest(url, {}, 'GET', true);

      if (response is Response && response.statusCode == 200) {
        final result = StateListModels.fromJson(response.data);
        CommonLogger.log.i(response.data);
        return Right(result);
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message']));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, StateListModels>> getBrandList(
    String selectedService,
  ) async {
    try {
      String url =
          'https://hoppr-backend-3d2b7f783917.herokuapp.com/api/users/brands?type=$selectedService';

      final response = await Request.sendGetRequest(url, {}, 'GET', true);

      if (response is Response && response.statusCode == 200) {
        final result = StateListModels.fromJson(response.data);
        CommonLogger.log.i(response.data);
        return Right(result);
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message']));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, StateListModels>> getModel(
    String brand,
    String selectedService,
  ) async {
    try {
      String url =
          'https://hoppr-backend-3d2b7f783917.herokuapp.com/api/users/models/$brand?type=$selectedService';

      final response = await Request.sendGetRequest(url, {}, 'GET', true);

      if (response is Response && response.statusCode == 200) {
        final result = StateListModels.fromJson(response.data);
        CommonLogger.log.i(response.data);
        return Right(result);
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message']));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, StateListModels>> fullConfirmation() async {
    try {
      String url = ApiConstents.updateUserDetails;

      final response = await Request.sendRequest(
        url,
        {"type": "Send Verification", "data": {}},
        'Post',
        true,
      );

      if (response is Response && response.statusCode == 200) {
        final result = StateListModels.fromJson(response.data);
        CommonLogger.log.i(response.data);
        return Right(result);
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message']));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, YearAndColorModels>> getYear(
    String brand,
    String model,
    String selectedService,
  ) async {
    try {
      String url =
          'https://hoppr-backend-3d2b7f783917.herokuapp.com/api/users/details/$brand/$model?type=$selectedService';

      final response = await Request.sendGetRequest(url, {}, 'GET', true);

      if (response is Response && response.statusCode == 200) {
        final result = YearAndColorModels.fromJson(response.data);
        CommonLogger.log.i(response.data);
        return Right(result);
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message']));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, GuideLinesResponse>> guideLines(String type) async {
    try {
      String url =
          'https://hoppr-backend-3d2b7f783917.herokuapp.com/api/users/guidelines/$type';

      final response = await Request.sendGetRequest(url, {}, 'GET', true);

      if (response is Response && response.statusCode == 200) {
        final result = GuideLinesResponse.fromJson(response.data);
        CommonLogger.log.i(response.data);
        return Right(result);
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message']));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, BookingAcceptModel>> bookingAccept({
    required String bookingId,
    required String status,
  }) async {
    try {
      final driverId = await SharedPrefHelper.getDriverId();
      String url =
          'https://hoppr-face-two-dbe557472d7f.herokuapp.com/api/users/driver-response';

      final response = await Request.sendRequest(
        url,
        {"driverId": driverId, "bookingId": bookingId, "response": status},
        'Post',
        false,
      );

      if (response is Response && response.statusCode == 200) {
        final result = BookingAcceptModel.fromJson(response.data);
        CommonLogger.log.i(response.data);
        return Right(result);
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message']));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, BookingAcceptModel>> otpRequest({
    required String bookingId,
  }) async {
    try {
      String url = ApiConstents.generateOtp;

      final response = await Request.sendRequest(
        url,
        {"bookingId": bookingId},
        'Post',
        false,
      );

      if (response is Response && response.statusCode == 200) {
        if (response.data != null && response.data is Map<String, dynamic>) {
          final result = BookingAcceptModel.fromJson(response.data);
          return Right(result);
        } else {
          return Left(ServerFailure("Invalid or empty response"));
        }
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message'] ?? 'Conflict'));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, BookingAcceptModel>> completeRideRequest({
    required String bookingId,
  }) async {
    try {
      String url = ApiConstents.completeRide(booking: bookingId);

      final response = await Request.sendRequest(url, {}, 'Post', false);

      if (response is Response && response.statusCode == 200) {
        if (response.data != null && response.data is Map<String, dynamic>) {
          final result = BookingAcceptModel.fromJson(response.data);
          return Right(result);
        } else {
          return Left(ServerFailure("Invalid or empty response"));
        }
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message'] ?? 'Conflict'));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, BookingAcceptModel>> otpInsert({
    required String bookingId,
    required String enteredOtp,
  }) async {
    try {
      String url = ApiConstents.rideVerifyOtp;

      final response = await Request.sendRequest(
        url,
        {"bookingId": bookingId, "enteredOtp": enteredOtp},
        'Post',
        false,
      );

      if (response is Response && response.statusCode == 200) {
        if (response.data != null && response.data is Map<String, dynamic>) {
          final result = BookingAcceptModel.fromJson(response.data);
          return Right(result);
        } else {
          return Left(ServerFailure("Invalid or empty response"));
        }
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message'] ?? 'Conflict'));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, DriverOnlineStatusModel>> driverOnlineStatus({
    required bool onlineStatus,
  }) async {
    try {
      final driverId = await SharedPrefHelper.getDriverId();

      String url = ApiConstents.driverOnlineStatus(driverId: driverId ?? '');

      final response = await Request.sendRequest(
        url,
        {"onlineStatus": onlineStatus},
        'Post',
        false,
      );

      if (response is Response && response.statusCode == 200) {
        if (response.data != null && response.data is Map<String, dynamic>) {
          final result = DriverOnlineStatusModel.fromJson(response.data);
          return Right(result);
        } else {
          return Left(ServerFailure("Invalid or empty response"));
        }
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message'] ?? 'Conflict'));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, GetTodayActivityModels>> todayActivity() async {
    try {
      final driverId = await SharedPrefHelper.getDriverId();
      String url = ApiConstents.todayStatus();

      final response = await Request.sendGetRequest(url, {}, 'Get', false);

      if (response is Response && response.statusCode == 200) {
        if (response.data != null && response.data is Map<String, dynamic>) {
          CommonLogger.log.i("Parsing response data: ${response.data}");
          final result = GetTodayActivityModels.fromJson(response.data);
          return Right(result);
        } else {
          return Left(ServerFailure("Invalid or empty response"));
        }
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message'] ?? 'Conflict'));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, WeeklyChallengeModels>> weeklyChallenge() async {
    try {
      final driverId = await SharedPrefHelper.getDriverId();
      String url = ApiConstents.weeklyChallenge();

      final response = await Request.sendGetRequest(url, {}, 'Get', false);

      if (response is Response && response.statusCode == 200) {
        if (response.data != null && response.data is Map<String, dynamic>) {
          CommonLogger.log.i("Parsing response data: ${response.data}");
          final result = WeeklyChallengeModels.fromJson(response.data);
          return Right(result);
        } else {
          return Left(ServerFailure("Invalid or empty response"));
        }
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message'] ?? 'Conflict'));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, BookingAcceptModel>> cancelBooking({
    required String reason,
    required String bookingId,
  }) async {
    try {
      final driverId = await SharedPrefHelper.getDriverId();
      String url = ApiConstents.cancelBooking(bookingId: bookingId);

      final response = await Request.sendRequest(
        url,
        {"rejectedReason": reason, "driverId": driverId},
        'Post',
        false,
      );

      if (response is Response && response.statusCode == 200) {
        if (response.data != null && response.data is Map<String, dynamic>) {
          CommonLogger.log.i("Parsing response data: ${response.data}");
          final result = BookingAcceptModel.fromJson(response.data);
          return Right(result);
        } else {
          return Left(ServerFailure("Invalid or empty response"));
        }
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message'] ?? 'Conflict'));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, BookingAcceptModel>> driverArrived({
    required String bookingId,
  }) async {
    try {
      String url = ApiConstents.driverArrived(booking: bookingId);

      final response = await Request.sendRequest(url, {}, 'Post', false);

      if (response is Response && response.statusCode == 200) {
        if (response.data != null && response.data is Map<String, dynamic>) {
          CommonLogger.log.i("Parsing response data: ${response.data}");
          final result = BookingAcceptModel.fromJson(response.data);
          return Right(result);
        } else {
          return Left(ServerFailure("Invalid or empty response"));
        }
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message'] ?? 'Conflict'));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, GetDriverStatus>> getDriverStatus() async {
    try {
      String url = ApiConstents.driverStatus;

      final response = await Request.sendGetRequest(url, {}, 'get', false);

      if (response is Response && response.statusCode == 200) {
        if (response.data != null && response.data is Map<String, dynamic>) {
          CommonLogger.log.i("Parsing response data: ${response.data}");
          final result = GetDriverStatus.fromJson(response.data);
          return Right(result);
        } else {
          return Left(ServerFailure("Invalid or empty response"));
        }
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message'] ?? 'Conflict'));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, TodayParcelActivityResponse>>
  todayPackageActivity() async {
    try {
      String url = ApiConstents.todayParcel;

      final response = await Request.sendGetRequest(url, {}, 'Get', false);

      if (response is Response && response.statusCode == 200) {
        if (response.data != null && response.data is Map<String, dynamic>) {
          CommonLogger.log.i("Parsing response data: ${response.data}");
          final result = TodayParcelActivityResponse.fromJson(response.data);
          return Right(result);
        } else {
          return Left(ServerFailure("Invalid or empty response"));
        }
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message'] ?? 'Conflict'));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }

  Future<Either<Failure, RideActivityHistoryResponse>> rideHistory() async {
    try {
      String url = ApiConstents.rideHistory;

      final response = await Request.sendGetRequest(url, {}, 'Get', false);

      if (response is Response && response.statusCode == 200) {
        if (response.data != null && response.data is Map<String, dynamic>) {
          CommonLogger.log.i("Parsing response data: ${response.data}");
          final result = RideActivityHistoryResponse.fromJson(response.data);
          return Right(result);
        } else {
          return Left(ServerFailure("Invalid or empty response"));
        }
      } else if (response is Response && response.statusCode == 409) {
        return Left(ServerFailure(response.data['message'] ?? 'Conflict'));
      } else if (response is Response) {
        return Left(ServerFailure(response.data['message'] ?? "Unknown error"));
      } else {
        return Left(ServerFailure("Unexpected error"));
      }
    } catch (e) {
      CommonLogger.log.e(e);
      return Left(ServerFailure('Something went wrong'));
    }
  }
}
