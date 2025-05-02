import 'package:flutter/material.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:intl/intl.dart';

class CustomTextfield {
  static final CustomTextfield _singleton = CustomTextfield._internal();

  CustomTextfield._internal();

  static CustomTextfield get instance => _singleton;

  static textField({required String tittle, required String hintText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tittle,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        TextField(
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
          ),
        ),
      ],
    );
  }

  static dropDown({
    required String title,
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
        TextField(
          style: TextStyle(
            color: Color(0xff111111),
            fontWeight: FontWeight.w500,
          ),
          readOnly: isReadOnly,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Color(0xff666666)),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xffF1F1F1)),
            ),
            suffixIcon: suffixIcon, // Optional
          ),
        ),
      ],
    );
  }

  static datePickerField({
    required BuildContext context,
    required String title,
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
        TextField(
          style: TextStyle(
            color: Color(0xff111111),
            fontWeight: FontWeight.w500,
          ),
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
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
            );
            if (pickedDate != null) {
              String formattedDate = DateFormat(
                'd MMMM yyyy',
              ).format(pickedDate);
              controller.text = formattedDate;
            }
          },
        ),
      ],
    );
  }

  static mobileNumber({
    VoidCallback? onTap,
    Widget? suffixIcon,
    required String title,
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
                  onTap: onTap,
                  decoration: InputDecoration(
                    border: InputBorder.none,

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
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    hintText: '0000 0000 0000',
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
