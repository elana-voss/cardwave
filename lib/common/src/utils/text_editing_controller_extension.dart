import 'package:flutter/material.dart';

extension TextEditingControllerExtension on TextEditingController {
  void onTextChanged(VoidCallback callback) {
    var lastText = text;
    addListener(() {
      if (text != lastText) {
        lastText = text;
        callback();
      }
    });
  }
}
