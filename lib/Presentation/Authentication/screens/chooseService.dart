// import 'package:flutter/material.dart';
// import 'package:hopper/Core/Constants/Colors.dart';
// import 'package:hopper/Core/Constants/texts.dart';
// import 'package:hopper/Core/Utility/images.dart';
// import 'package:hopper/Presentation/Authentication/widgets/customContainer.dart';
//
// class ChooseService extends StatefulWidget {
//   const ChooseService({super.key});
//
//   @override
//   State<ChooseService> createState() => _ChooseServiceState();
// }
//
// class _ChooseServiceState extends State<ChooseService> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: SingleChildScrollView(
//         child: SafeArea(
//           child: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 25),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Choose your service',
//                   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
//                 ),
//                 SizedBox(height: 16),
//                 Text(
//                   'Select one service to begin your onboarding',
//                   style: TextStyle(color: AppColors.textColor),
//                 ),
//                 SizedBox(height: 32),
//
//                 CustomContainer.container(
//
//
//                   onTap: () {},
//                   serviceType: 'Car',
//                   serviceTypeImage: AppImages.apple,
//                   serviceText: 'Ride Passenger',
//                   content: AppTexts.carText, isSelected: null,
//                 ),
//                 SizedBox(height: 32),
//                 CustomContainer.container(
//                   onTap: () {},
//                   serviceType: 'Bike',
//                   serviceTypeImage: AppImages.google,
//                   serviceText: 'Package Delivery',
//                   content: AppTexts.bikeText,
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
