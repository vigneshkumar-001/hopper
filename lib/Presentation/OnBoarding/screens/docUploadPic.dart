import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/texts.dart';
import 'package:hopper/Core/Utility/Buttons.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/Presentation/OnBoarding/screens/ninScreens.dart';
import 'package:hopper/Presentation/OnBoarding/screens/profilePicAccess.dart'
    show ProfilePicAccess;
import 'package:hopper/Presentation/Authentication/widgets/textFields.dart';

class DocUpLoadPic extends StatefulWidget {
  const DocUpLoadPic({super.key});

  @override
  State<DocUpLoadPic> createState() => _DocUpLoadPicState();
}

class _DocUpLoadPicState extends State<DocUpLoadPic> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.commonWhite),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                maxLines: 2,
                AppTexts.documentsUpload,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28),
              ),
              SizedBox(height: 24),
              Image.asset(AppImages.docUpload),
              SizedBox(height: 24),
              Row(
                children: [
                  Image.asset(AppImages.tick),
                  SizedBox(width: 10),
                  Text(
                    AppTexts.requirements,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              SizedBox(height: 24),
              CustomTextfield.concatenateText(
                title: AppTexts.requirementsContents1,
              ),
              CustomTextfield.concatenateText(
                title: AppTexts.requirementsContents2,
              ),
              CustomTextfield.concatenateText(
                title: AppTexts.requirementsContents3,
              ),
              SizedBox(height: 20),
              Divider(),
              SizedBox(height: 20),
              Row(
                children: [
                  Image.asset(AppImages.close),
                  SizedBox(width: 10),
                  Text(
                    AppTexts.thinksToAvoid,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              SizedBox(height: 24),
              CustomTextfield.concatenateText(
                title: AppTexts.thinksToAvoidContents1,
              ),
              CustomTextfield.concatenateText(
                title: AppTexts.thinksToAvoidContents2,
              ),
              // Spacer(),
              // Buttons.button(
              //   buttonColor: AppColors.commonBlack,
              //   onTap: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(builder: (context) => ProfilePicAccess()),
              //     );
              //   },
              //   text: 'Take a Photo',
              // ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: AppColors.commonWhite,
        child: Column(
          children: [
            Buttons.button(
              buttonColor: AppColors.commonBlack,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfilePicAccess()),
                );
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(builder: (context) => NinScreens()),
                // );
              },
              text: 'Take a Photo',
            ),
          ],
        ),
      ),
    );
  }
}
