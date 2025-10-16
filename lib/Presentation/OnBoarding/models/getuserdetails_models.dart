import '../../../Core/Constants/log.dart';

class StatusModel {
  final int? status;
  final List<String>? rejectedReason;
  final List<String>? rejectedComment;

  StatusModel({this.status, this.rejectedReason, this.rejectedComment});

  factory StatusModel.fromJson(Map<String, dynamic> json) {
    return StatusModel(
      status: json['status'],
      rejectedReason: (json['rejected_reason'] as List?)?.cast<String>(),
      rejectedComment: (json['rejected_comment'] as List?)?.cast<String>(),
    );
  }
}

class GetUserProfileModel {
  final String? id;
  final String? serviceType;
  final String? firstName;
  final String? lastName;
  final String? dob;
  final String? gender;
  final String? email;
  final String? mobileNumber;
  final String? address;
  final String? city;
  final String? state;
  final String? countryCode;
  final int? completed;
  final String? bankVerificationNumber;
  final String? nationalIdNumber;
  final String? frontIdCardBvn;
  final String? frontIdCardDln;
  final String? backIdCardDln;
  final String? profilePic;
  final String? backIdCardBvn;
  final String? frontIdCardNin;
  final String? backIdCardNin;
  final String? driverLicenseNumber;
  final String? carOwnership;
  final String? carOwnerName;
  final String? carPlateNumber;
  final String? carBrand;
  final String? carModel;
  final int? carYear;
  final String? carColor;
  final String? carRoadWorthinessCertificate;
  final String? carRegistrationNumber;
  final String? bikeRoadWorthinessCertificate;
  final String? carInsuranceDocument;
  final String? bikeInsuranceDocument;
  final List<String>? carDocuments;
  final List<String>? carExteriorPhotos;
  final List<String>? carInteriorPhotos;
  final String? bikeOwnership;
  final String? bikeOwnerName;
  final String? bikePlateNumber;
  final String? bikeRegistrationNumber;
  final String? bikeBrand;
  final String? bikeModel;
  final int? bikeYear;
  final List<String>? bikeDocuments;
  final List<String>? bikePhotos;
  final bool? mobileNumberVerified;
  final bool? emailVerified;
  final String? postalCode;
  final int? landingPage;
  final int? formStatus;

  final StatusModel? basicInfoStatus;
  final StatusModel? profilePhotoStatus;
  final StatusModel? ninVerificationStatus;
  final StatusModel? bankVerificationStatus;
  final StatusModel? bikeDetailsStatus;
  final StatusModel? carDetailsStatus;
  final StatusModel? carExteriorPhotosStatus;
  final StatusModel? carInteriorPhotosStatus;
  final StatusModel? driverAddressStatus;
  final StatusModel? driversLicenseStatus;
  final StatusModel? bikeOwnershipStatus;
  final StatusModel? carOwnershipStatus;
  final StatusModel? bikePhotosStatus;
  final String? DriverStarRating;


  GetUserProfileModel({
    this.id,
    this.frontIdCardDln,
    this.backIdCardDln,
    this.serviceType,
    this.firstName,
    this.lastName,
    this.dob,
    this.gender,
    this.email,
    this.mobileNumber,
    this.address,
    this.city,
    this.state,
    this.countryCode,
    this.completed,
    this.bankVerificationNumber,
    this.carRegistrationNumber,
    this.nationalIdNumber,
    this.frontIdCardBvn,
    this.backIdCardBvn,
    this.frontIdCardNin,
    this.backIdCardNin,
    this.profilePic,
    this.driverLicenseNumber,
    this.carOwnership,
    this.carOwnerName,
    this.bikeRoadWorthinessCertificate,

    this.bikeRegistrationNumber,
    this.carPlateNumber,
    this.carBrand,
    this.carModel,
    this.carYear,
    this.carColor,
    this.carDocuments,
    this.carExteriorPhotos,
    this.carInteriorPhotos,
    this.bikeInsuranceDocument,
    this.carRoadWorthinessCertificate,
    this.carInsuranceDocument,
    this.bikeOwnership,
    this.bikeOwnerName,
    this.bikePlateNumber,
    this.bikeBrand,
    this.bikeModel,
    this.bikeYear,
    this.bikeDocuments,
    this.bikePhotos,
    this.mobileNumberVerified,
    this.emailVerified,
    this.postalCode,
    this.landingPage,
    this.formStatus,
    this.basicInfoStatus,
    this.profilePhotoStatus,
    this.ninVerificationStatus,
    this.bankVerificationStatus,
    this.bikeDetailsStatus,
    this.carDetailsStatus,
    this.carExteriorPhotosStatus,
    this.carInteriorPhotosStatus,
    this.driverAddressStatus,
    this.driversLicenseStatus,
    this.bikeOwnershipStatus,
    this.carOwnershipStatus,
    this.bikePhotosStatus,
    this.DriverStarRating,
  });

  factory GetUserProfileModel.fromJson(Map<String, dynamic> json) {
    CommonLogger.log.i(json);
    return GetUserProfileModel(
      id: json['_id'],
      serviceType: json['serviceType'] ?? '',
      firstName: json['firstName'],
      lastName: json['lastName'],
      dob: json['dob'],
      gender: json['gender'],
      email: json['email'],
      mobileNumber: json['mobileNumber'],
      address: json['address'],
      city: json['city'],
      state: json['state'],
      countryCode: json['countryCode'],
      completed: json['completed'],
      bankVerificationNumber: json['bankVerificationNumber'],
      nationalIdNumber: json['nationalIdNumber'],
      frontIdCardBvn: json['frontIdCardBvn'],
      backIdCardBvn: json['backIdCardBvn'],
      profilePic: json['profilePic'],
      frontIdCardNin: json['frontIdCardNin'],
      frontIdCardDln: json['frontIdCardDln'],
      backIdCardDln: json['backIdCardDln'],
      backIdCardNin: json['backIdCardNin'],
      driverLicenseNumber: json['driverLicenseNumber'],
      carOwnership: json['carOwnership'] ?? '',
      carOwnerName: json['carOwnerName'],
      carPlateNumber: json['carPlateNumber'],
      carBrand: json['carBrand'],
      carModel: json['carModel'],
      carYear: json['carYear'],
      carColor: json['carColor'],
      bikeRegistrationNumber: json['bikeRegistrationNumber'],
      carRegistrationNumber: json['carRegistrationNumber'],
      carRoadWorthinessCertificate: json['carRoadWorthinessCertificate'],
      carInsuranceDocument: json['carInsuranceDocument'],
      carDocuments: (json['carDocuments'] as List?)?.cast<String>(),
      carExteriorPhotos: (json['carExteriorPhotos'] as List?)?.cast<String>(),
      carInteriorPhotos: (json['carInteriorPhotos'] as List?)?.cast<String>(),
      bikeRoadWorthinessCertificate: json['bikeRoadWorthinessCertificate'],
      bikeInsuranceDocument: json['bikeInsuranceDocument'],
      bikeOwnership: json['bikeOwnership'],
      bikeOwnerName: json['bikeOwnerName'],
      bikePlateNumber: json['bikePlateNumber'],
      bikeBrand: json['bikeBrand'],
      bikeModel: json['bikeModel'],
      bikeYear: json['bikeYear'],
      bikeDocuments: (json['bikeDocuments'] as List?)?.cast<String>(),
      bikePhotos: (json['bikePhotos'] as List?)?.cast<String>(),
      mobileNumberVerified: json['MobileNumberverified'],
      emailVerified: json['EmailVerified'],
      postalCode: json['postalCode'],
      landingPage: json['landingPage'],
      formStatus: json['formStatus'],
      DriverStarRating: json['DriverStarRating'],
      basicInfoStatus:
          json['basicInfoStatus'] != null
              ? StatusModel.fromJson(json['basicInfoStatus'])
              : null,
      profilePhotoStatus:
          json['profilePhotoStatus'] != null
              ? StatusModel.fromJson(json['profilePhotoStatus'])
              : null,
      ninVerificationStatus:
          json['ninVerificationStatus'] != null
              ? StatusModel.fromJson(json['ninVerificationStatus'])
              : null,
      bankVerificationStatus:
          json['bankVerificationStatus'] != null
              ? StatusModel.fromJson(json['bankVerificationStatus'])
              : null,
      bikeDetailsStatus:
          json['bikeDetailsStatus'] != null
              ? StatusModel.fromJson(json['bikeDetailsStatus'])
              : null,
      carDetailsStatus:
          json['carDetailsStatus'] != null
              ? StatusModel.fromJson(json['carDetailsStatus'])
              : null,
      carExteriorPhotosStatus:
          json['carExteriorPhotosStatus'] != null
              ? StatusModel.fromJson(json['carExteriorPhotosStatus'])
              : null,
      carInteriorPhotosStatus:
          json['carInteriorPhotosStatus'] != null
              ? StatusModel.fromJson(json['carInteriorPhotosStatus'])
              : null,
      driverAddressStatus:
          json['driverAddressStatus'] != null
              ? StatusModel.fromJson(json['driverAddressStatus'])
              : null,
      driversLicenseStatus:
          json['driversLicenseStatus'] != null
              ? StatusModel.fromJson(json['driversLicenseStatus'])
              : null,
      bikeOwnershipStatus:
          json['bikeOwnershipStatus'] != null
              ? StatusModel.fromJson(json['bikeOwnershipStatus'])
              : null,
      carOwnershipStatus:
          json['carOwnershipStatus'] != null
              ? StatusModel.fromJson(json['carOwnershipStatus'])
              : null,
      bikePhotosStatus:
          json['bikePhotosStatus'] != null
              ? StatusModel.fromJson(json['bikePhotosStatus'])
              : null,
    );
  }
}
