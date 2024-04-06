import 'package:btcconnectapp/helper/alert.dart';
import 'package:btcconnectapp/helper/netutils.dart';
import 'package:flutter/material.dart';

class PayPage extends StatefulWidget {
  const PayPage({super.key});

  @override
  State<PayPage> createState() => __PayPageState();
}

class __PayPageState extends State<PayPage> {
  List<String> wallets = <String>[];
  String selectWallet = '';
  String balance = '';

  @override
  void initState() {
    super.initState();

    flushWallets();
  }

  void flushWallets() {
    NetUtils.requestHttp('/wallets',
        method: NetUtils.getMethod,
        onSuccess: (data) => {processWalletsUpdate(List<String>.from(data))},
        onError: (error) =>
            {AlertUtils.alertDialog(context: context, content: error)});
  }

  void processWalletsUpdate(List<String> newWallets) {
    if (newWallets.isEmpty) {
      setState(() {
        selectWallet = '';
      });

      return;
    }

    wallets = newWallets;
    wallets.insert(0, 'all');

    if (selectWallet == '') {
      selectWallet = newWallets.first;
    }

    setState(() {});

    flushBalance();
  }

  void flushBalance() {
    List<String> wallets = <String>[];
    if (selectWallet != 'all') {
      wallets.add(selectWallet);
    }
    NetUtils.requestHttp('/balance',
        method: NetUtils.postMethod,
        data: {
          "wallets": wallets,
        },
        onSuccess: (data) => {processBalanceUpdate(int.parse(data.toString()))},
        onError: (error) =>
            {AlertUtils.alertDialog(context: context, content: error)});
  }

  void processBalanceUpdate(int newWallets) {
    setState(() {
      balance = "${newWallets}mBTC";
    });
  }

  Widget? mainWidgets() {
    return Column(
      children: [
        Row(
          children: [
            DropdownMenu<String>(
              initialSelection: selectWallet,
              onSelected: (String? value) {
                setState(() {
                  selectWallet = value!;
                });
                flushBalance();
              },
              dropdownMenuEntries:
                  wallets.map<DropdownMenuEntry<String>>((String value) {
                return DropdownMenuEntry<String>(value: value, label: value);
              }).toList(),
            ),
            Text(balance),
          ],
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      appBar: AppBar(title: const Text('Pay')),
      body: mainWidgets(),
    ));
  }
}
