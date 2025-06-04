import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/log.dart';

import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/OnBoarding/models/stateList_Models.dart';
import 'package:hopper/Presentation/OnBoarding/screens/completedScreens.dart';
import 'package:hopper/Presentation/OnBoarding/screens/docUploadPic.dart';
import 'package:hopper/Presentation/OnBoarding/screens/ninScreens.dart';

import 'package:hopper/api/dataSource/apiDataSource.dart';

import 'chooseservice_controller.dart' show ChooseServiceController;

class StateListController extends GetxController {
  String accessToken = '';
  ApiDataSource apiDataSource = ApiDataSource();
  RxBool isLoading = false.obs;
  final RxList<String> cities = <String>[].obs;
  final RxList<String> states = <String>[].obs;
  final RxList<String> brands = <String>[].obs;
  final RxList<String> models = <String>[].obs;
  final RxList<String> year = <String>[].obs;
  final RxList<String> color = <String>[].obs;
  final Map<String, List<String>> _modelCache = {};
  final Map<String, List<int>> _yearCache = {};
  final Map<String, List<String>> _colorCache = {};

  @override
  void onInit() {
    super.onInit();
    getStateList();
    getBrandList();
  }

  Future<StateListModels?> getStateList() async {
    isLoading.value = true;

    try {
      final results = await apiDataSource.fetchCities();

      return results.fold(
        (failure) {
          isLoading.value = false;
          CustomSnackBar.showError(failure.message);
          return null;
        },
        (response) {
          isLoading.value = false;

          states.assignAll(response.data);
          return response;
        },
      );
    } catch (e) {
      isLoading.value = false;
      CustomSnackBar.showError("An error occurred");
      return null;
    }
  }

  Future<void> getCityList(String state) async {
    final result = await apiDataSource.getCityList(state);
    result.fold(
      (failure) {
        isLoading.value = false;
        CustomSnackBar.showError(failure.message);
      },
      (response) {
        cities.assignAll(response.data);
        isLoading.value = false;
      },
    );
  }

  Future<void> getBrandList() async {
    final profile = Get.find<ChooseServiceController>().userProfile.value;
    final isCar = profile?.serviceType == 'Car';
    final serviceType = isCar ? 'Car' : 'Bike';
    final result = await apiDataSource.getBrandList(serviceType);

    result.fold(
      (failure) {
        isLoading.value = false;
        CustomSnackBar.showError(failure.message);
      },
      (response) {
        brands.assignAll(response.data);
        isLoading.value = false;
      },
    );
  }

  Future<void> getModel(String brand) async {
    final profile = Get.find<ChooseServiceController>().userProfile.value;
    final isCar = profile?.serviceType == 'Car';
    final serviceType = isCar ? 'Car' : 'Bike';
    if (_modelCache.containsKey(brand)) {
      models.assignAll(_modelCache[brand]!);
      isLoading.value = false;
      return;
    }

    final result = await apiDataSource.getModel(brand, serviceType);
    result.fold(
      (failure) {
        isLoading.value = false;
        CustomSnackBar.showError(failure.message);
      },
      (response) {
        _modelCache[brand] = response.data; // Save to cache
        models.assignAll(response.data);

        isLoading.value = false;
      },
    );
  }

  Future<void> getYear(String brand, String model) async {
    if (_yearCache.containsKey(brand) && _colorCache.containsKey(brand)) {
      year.assignAll(_yearCache[brand]!.map((e) => e.toString()).toList());
      color.assignAll(_colorCache[brand]!);
      isLoading.value = false;
      return;
    }
    final profile = Get.find<ChooseServiceController>().userProfile.value;
    final isCar = profile?.serviceType == 'Car';
    final serviceType = isCar ? 'Car' : 'Bike';
    final result = await apiDataSource.getYear(brand, model, serviceType);

    result.fold(
      (failure) {
        isLoading.value = false;
        CustomSnackBar.showError(failure.message);
      },
      (response) {
        _yearCache[brand] = response.data.years;
        _colorCache[brand] = response.data.colors;

        // Assign to RxList<String> by converting ints to strings
        year.assignAll(response.data.years.map((e) => e.toString()).toList());
        color.assignAll(response.data.colors);

        isLoading.value = false;
      },
    );
  }

  Future<void> sendVerification(BuildContext context) async {
    isLoading.value = true;
    final result = await apiDataSource.fullConfirmation();
    result.fold(
      (failure) {
        isLoading.value = false;
        CustomSnackBar.showError(failure.message);
      },
      (response) {
        isLoading.value = false;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CompletedScreens()),
        );
        // CustomSnackBar.showSuccess( response.data);
        isLoading.value = false;
      },
    );
  }
}
