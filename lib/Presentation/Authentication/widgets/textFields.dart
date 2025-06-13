import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../Core/Constants/Colors.dart';
import '../controller/authController.dart';
import 'package:intl/intl.dart';

class CustomTextfield {
  static final CustomTextfield _singleton = CustomTextfield._internal();

  CustomTextfield._internal();

  static CustomTextfield get instance => _singleton;

  static textField({
    required String tittle,
    GlobalKey<FormState>? formKey,
    required String hintText,
    TextEditingController? controller,
    TextInputType? type,
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,

    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tittle,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        TextFormField(
          cursorColor: Colors.black,

          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: (value) {
            // Call the passed onChanged if exists
            // if (onChanged != null) onChanged(value);
            // // Then trigger form validation if formKey is provided
            // formKey?.currentState?.validate();
          },
          inputFormatters: inputFormatters,
          keyboardType: type,
          controller: controller,
          readOnly: readOnly,
          style: TextStyle(
            color: Color(0xff111111),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Color(0xff666666)),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xffF1F1F1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.black,
                width: 1.5,
              ), // BLACK BORDER
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.errorRed, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.errorRed, width: 1.5),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  static dropDown({
    required String title,
    String? Function(String?)? validator,
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
    required String hintText,
    VoidCallback? onTap,
    bool isReadOnly = true,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        TextFormField(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: validator,
          controller: controller,
          style: TextStyle(
            color: Color(0xff111111),
            fontWeight: FontWeight.w500,
          ),
          readOnly: isReadOnly,
          onTap: onTap,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Color(0xff666666)),
            suffixIcon: suffixIcon,
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.black),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.black, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  static datePickerField({
    required GlobalKey<FormState> formKey,
    String? Function(String?)? validator,
    required BuildContext context,
    required String title,
    ValueChanged<String>? onChanged,
    required String hintText,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        TextFormField(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: onChanged,
          style: TextStyle(
            color: Color(0xff111111),
            fontWeight: FontWeight.w500,
          ),
          controller: controller,
          readOnly: true,
          validator: validator,
          decoration: InputDecoration(
            errorBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.black),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.black, width: 2),
            ),
            hintText: hintText,
            hintStyle: TextStyle(color: Color(0xff666666)),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xffF1F1F1)),
            ),
            suffixIcon: Icon(Icons.calendar_today, size: 20),
          ),
          onTap: () async {
            DateTime? pickedDate = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: ThemeData.light().copyWith(
                    primaryColor: Colors.blue, // Header color
                    colorScheme: const ColorScheme.light(
                      onPrimary: AppColors.commonWhite,
                    ),
                    dialogBackgroundColor:
                        AppColors.commonWhite, // Background color
                  ),
                  child: child!,
                );
              },
            );

            if (pickedDate != null) {
              DateTime today = DateTime.now();
              int age = today.year - pickedDate.year;
              if (today.month < pickedDate.month ||
                  (today.month == pickedDate.month &&
                      today.day < pickedDate.day)) {
                age--;
              }

              if (age < 18) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: Duration(seconds: 2),
                    backgroundColor: Colors.red,
                    content: Text('You must be at least 18 years old'),
                  ),
                );
                controller.clear();
                formKey.currentState?.validate(); // ✅ forces re-validation
              } else {
                String formattedDate = DateFormat(
                  'd-MMMM-yyyy',
                ).format(pickedDate);
                controller.text = formattedDate;
                formKey.currentState?.validate(); // ✅ clears error
                if (onChanged != null) {
                  onChanged(formattedDate);
                }
              }
            }
          },
        ),
      ],
    );
  }

  static mobileNumber({
    VoidCallback? onTap,
    Widget? suffixIcon,
    String? initialValue,
    bool readOnly = false,
    Widget? prefixIcon,
    required String title,
    TextEditingController? controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: Color(0xffF1F1F1)),
                child: TextField(
                  readOnly: true,

                  onTap: onTap,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    prefixIcon: prefixIcon,
                    suffixIcon: suffixIcon,
                  ),
                ),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: Container(
                decoration: BoxDecoration(color: Color(0xffF1F1F1)),
                child: TextFormField(
                  controller: controller,
                  initialValue: initialValue,
                  readOnly: readOnly,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    // focusedBorder: OutlineInputBorder(
                    //   borderSide: BorderSide(color: Colors.black, width: 1.5),
                    //   borderRadius: BorderRadius.circular(4),
                    // ),
                    hintText: getMobileNumber,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static concatenateText({required String title}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontSize: 16, height: 1.5)),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xff333333),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
