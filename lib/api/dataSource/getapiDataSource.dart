import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Presentation/Authentication/models/loginResponse.dart';
import 'package:hopper/Presentation/OnBoarding/models/getuserdetails_models.dart';
import 'package:hopper/api/repository/api_constents.dart';
import 'package:hopper/api/repository/request.dart';
import '../../Presentation/Authentication/controller/authController.dart';
import '../repository/failure.dart';
import 'package:dio/dio.dart';
import 'package:dartz/dartz.dart';

abstract class GetApiDataSource {
  Future<Either<Failure, LoginResponse>> mobileNumberLogin(
    String mobileNumber,
    String countryCode,
  );
}

class ApiDataSource extends GetApiDataSource {
  @override
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

  Future<Either<Failure, GetUserProfileModel>> getUserDetail(String otp) async {
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
        'get',
        false,
      );
      CommonLogger.log.i(response);
      if (response is Response && response.statusCode == 200) {
        if (response.data['status'] == 200) {
          return Right(GetUserProfileModel.fromJson(response.data));
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
}
