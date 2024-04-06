import 'package:flutter/material.dart';

class AlertUtils {
  static Future alertDialog(
      {required BuildContext context,
      String title = '消息',
      okButtonText = '确定',
      cancelButtonText = '取消',
      hideCancelButton = false,
      required content}) async {
    if (!context.mounted) {
      return;
    }
    return showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop("ok");
                  },
                  child: Text(okButtonText)),
              Visibility(
                visible: !hideCancelButton,
                child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop("cancel");
                    },
                    child: Text(cancelButtonText)),
              )
            ],
          );
        });
  }
}
