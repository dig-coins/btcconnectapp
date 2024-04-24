import 'dart:io';

import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:btcconnectapp/helper/alert.dart';
import 'package:btcconnectapp/helper/netutils.dart';
import 'package:btcconnectapp/pages/model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:simple_tags/simple_tags.dart';

class PayPage extends StatefulWidget {
  const PayPage({super.key});

  @override
  State<PayPage> createState() => __PayPageState();
}

enum SingingCharacter { pay, advancePay }

class __PayPageState extends State<PayPage> {
  List<String> wallets = <String>[];
  String selectWallet = '';
  String balance = '';
  SingingCharacter? payType = SingingCharacter.pay;
  List<String> inputAddresses = [];
  List<Unspent> inputUnspents = [];
  List<String> inputUnspentTags = [];
  List<String> outputs = [];
  TextEditingController inputAddressController = TextEditingController();
  TextEditingController outputAddressController = TextEditingController();
  TextEditingController outputAmountController = TextEditingController();
  TextEditingController changeAddressController = TextEditingController();
  double confirmationTarget = 2;
  TextEditingController feeBtcPerKBController = TextEditingController();
  TextEditingController totalFeeBtcController = TextEditingController();
  String bestBTCPerKB = '';
  bool minTransFlag = false;
  UnsignedTxResponse unsignedTx = UnsignedTxResponse.empty();
  bool inputCustomFlag = false;
  TreeNode<dynamic> unspent = TreeNode<dynamic>.root();

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

  String mBTC2BTC(int v) {
    return "${v.toDouble() / 100000000}";
  }

  int sBTC2mBTC(String v) {
    return (double.parse(v) * 100000000).round();
  }

  void processBalanceUpdate(int newBalance) {
    setState(() {
      balance = "${mBTC2BTC(newBalance)} BTC";
    });

    flushFeeBTCPerKB();
  }

  void removeUnspentTag(String v) {
    inputUnspentTags.removeWhere((element) => element == v);
    inputUnspents.removeWhere((element) => element.key() == v);
    setState(() {});
  }

  void removeInputTag(String v) {
    inputAddresses.removeWhere((element) => element == v);
    setState(() {});
  }

  void removeOutputTag(String v) {
    outputs.removeWhere((element) => element == v);
    setState(() {});
  }

  void addressSelected(String address) {}

  void flushFeeBTCPerKB() {
    NetUtils.requestHttp('/fee',
        method: NetUtils.getMethod,
        onSuccess: (data) => {processFeeBTCPerKB(data)},
        onError: (error) =>
            {AlertUtils.alertDialog(context: context, content: error)});
  }

  void processFeeBTCPerKB(Map<String, dynamic> fees) {
    int mustFee = 0;
    if (fees['coin_ex_fee'] != null && fees['coin_ex_fee'] > 0) {
      mustFee = fees['coin_ex_fee'];
    }
    if (mustFee == 0) {
      mustFee = fees['core_fee_6'];
    }

    setState(() {
      bestBTCPerKB = "${mBTC2BTC(mustFee)} BTC/kB";
    });

    flushUnspent();
  }

  Future<void> loadUnsignedTx() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result == null) {
      return;
    }

    PlatformFile file = result.files.first;
    file.xFile.readAsString().then((value) => {unsignedTxLoad(value)});
  }

  void resetAll() {
    inputAddresses = [];
    inputUnspents = [];
    inputUnspentTags = [];
    outputs = [];
    inputAddressController.text = '';
    outputAddressController.text = '';
    outputAmountController.text = '';
    changeAddressController.text = '';
    confirmationTarget = 2;
    feeBtcPerKBController.text = '';
    bestBTCPerKB = '';
    minTransFlag = false;
    unsignedTx = UnsignedTxResponse.empty();
    inputCustomFlag = false;
    unspent = TreeNode<dynamic>.root();
    setState(() {});
    flushWallets();
  }

  void flushUnsignedTx() {
    var changeAddress = changeAddressController.text;

    if (outputs.isEmpty && changeAddress == '') {
      AlertUtils.alertDialog(
          context: context,
          content: '请增加输出或找零地址',
          title: '错误',
          hideCancelButton: true);
      return;
    }

    List<String> wallets = <String>[];
    if (selectWallet != 'all') {
      wallets.add(selectWallet);
    }

    var txOutputs = [];
    for (int i = 0; i < outputs.length; i++) {
      var ps = outputs[i].split(':');
      txOutputs.add({'address': ps[0], 'amount': sBTC2mBTC(ps[1])});
    }

    var data = {
      'outputs': txOutputs,
      'change_address': changeAddress,
    };

    if (totalFeeBtcController.text != '') {
      data['total_fee'] = sBTC2mBTC(totalFeeBtcController.text);
    } else {
      if (feeBtcPerKBController.text != '') {
        data['fee_satoshi_per_kb'] = sBTC2mBTC(feeBtcPerKBController.text);
      } else {
        data['confirmation_target'] = confirmationTarget.round();
      }
    }

    data['min_trans_flag'] = minTransFlag;

    if (payType == SingingCharacter.pay) {
      if (!inputCustomFlag || inputAddresses.isEmpty) {
        data['wallets'] = wallets;
        NetUtils.requestHttp('/pay/simple',
            method: NetUtils.postMethod,
            data: data,
            onSuccess: (data) => {
                  setState(() {
                    unsignedTx = UnsignedTxResponse.fromJson(data);
                  })
                },
            onError: (error) =>
                {AlertUtils.alertDialog(context: context, content: error)});
      } else {
        var inputs = [];
        inputs.add({
          'addresses': inputAddresses,
        });

        data['inputs'] = inputs;

        NetUtils.requestHttp('/pay',
            method: NetUtils.postMethod,
            data: data,
            onSuccess: (data) => {
                  setState(() {
                    unsignedTx = UnsignedTxResponse.fromJson(data);
                  })
                },
            onError: (error) =>
                {AlertUtils.alertDialog(context: context, content: error)});
      }
    } else {
      if (inputUnspents.isEmpty) {
        AlertUtils.alertDialog(
            context: context,
            content: '请增加输入',
            title: '错误',
            hideCancelButton: true);
        return;
      }

      var txs = [];
      for (var unspent in inputUnspents) {
        txs.add({
          'id': unspent.txID,
          'v_out': unspent.vOut,
        });
      }

      var inputs = [];
      inputs.add({
        'pay_txs': txs,
      });

      data['inputs'] = inputs;

      NetUtils.requestHttp('/pay',
          method: NetUtils.postMethod,
          data: data,
          onSuccess: (data) => {
                setState(() {
                  unsignedTx = UnsignedTxResponse.fromJson(data);
                })
              },
          onError: (error) =>
              {AlertUtils.alertDialog(context: context, content: error)});
    }
  }

  void flushUnspent() {
    List<String> wallets = <String>[];
    if (selectWallet != 'all') {
      wallets.add(selectWallet);
    }
    NetUtils.requestHttp('/unspent/group_wallet_address',
        method: NetUtils.postMethod,
        data: {
          "wallets": wallets,
        },
        onSuccess: (data) => {processUnspent(data)},
        onError: (error) =>
            {AlertUtils.alertDialog(context: context, content: error)});
  }

  void processUnspent(List<dynamic> data) {
    var walletUnspents =
        data.map((e) => WalletAddressUnspent.fromJson(e)).toList();

    var newUnspent = TreeNode<dynamic>.root();

    for (var element in walletUnspents) {
      var walletAddressNode = TreeNode(key: element.wallet, data: element);

      for (var element in element.unspent) {
        var addressNode = TreeNode(key: element.address, data: element);

        for (var element in element.unspent) {
          addressNode.add(TreeNode(
              key: element.txID + element.vOut.toString(), data: element));
        }

        walletAddressNode.add(addressNode);
      }

      newUnspent.add(walletAddressNode);
    }

    setState(() {
      unspent = newUnspent;
    });
  }

  void unsignedTxLoad(String unsignedTxHex) {
    var data = {};
    data['unsigned_tx'] = unsignedTxHex;

    NetUtils.requestHttp('/unsigned-tx/load',
        method: NetUtils.postMethod,
        data: data,
        onSuccess: (data) => {
              setState(() {
                unsignedTx = UnsignedTxResponse.fromJson(data);
              })
            },
        onError: (error) =>
            {AlertUtils.alertDialog(context: context, content: error)});
  }

  void reUnsignTx(String unsignedTxHex) {
    var data = {};
    data['unsigned_tx'] = unsignedTxHex;

    if (totalFeeBtcController.text != '') {
      data['total_fee'] = sBTC2mBTC(totalFeeBtcController.text);
    } else {
      if (feeBtcPerKBController.text != '') {
        data['fee_satoshi_per_kb'] = sBTC2mBTC(feeBtcPerKBController.text);
      } else {
        data['confirmation_target'] = confirmationTarget.round();
      }
    }

    NetUtils.requestHttp('/re-unsigned-tx',
        method: NetUtils.postMethod,
        data: data,
        onSuccess: (data) => {
              setState(() {
                unsignedTx = UnsignedTxResponse.fromJson(data);
              })
            },
        onError: (error) =>
            {AlertUtils.alertDialog(context: context, content: error)});
  }

  Widget unsignedTxUI() {
    if (unsignedTx.unsignedTxHex == '') {
      return Container();
    }

    List<String> inputs = <String>[];
    for (int i = 0; i < unsignedTx.unsignedTx.inputs.length; i++) {
      var input = unsignedTx.unsignedTx.inputs[i];
      inputs.add(
          '${mBTC2BTC(input.amount)} BTC 来自\n${input.address}\n${input.txID}:${input.vOut}');
    }

    List<String> outputs = <String>[];
    for (int i = 0; i < unsignedTx.unsignedTx.outputs.length; i++) {
      var output = unsignedTx.unsignedTx.outputs[i];
      String changeInfo = '';
      if (output.changeFlag) {
        changeInfo = '  - 找零地址';
      }
      outputs.add(
          '${mBTC2BTC(output.amount)} BTC 到\n${output.address}\n$changeInfo');
    }

    return SizedBox(
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Flexible(
          flex: 1,
          child: SimpleTags(
            content: inputs,
            wrapSpacing: 4,
            wrapRunSpacing: 4,
            tagContainerPadding: const EdgeInsets.all(10),
            tagTextStyle: const TextStyle(color: Colors.deepPurple),
            tagIcon: const Icon(Icons.inbox, size: 12),
            tagContainerDecoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey),
              borderRadius: const BorderRadius.all(
                Radius.circular(20),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(139, 139, 142, 0.16),
                  spreadRadius: 1,
                  blurRadius: 1,
                  offset: Offset(1.75, 3.5),
                )
              ],
            ),
            onTagDoubleTap: (tag) => {removeOutputTag(tag)},
          ),
        ),
        const Icon(Icons.arrow_forward),
        Flexible(
          flex: 1,
          child: SimpleTags(
            content: outputs,
            wrapSpacing: 4,
            wrapRunSpacing: 4,
            tagContainerPadding: const EdgeInsets.all(10),
            tagTextStyle: const TextStyle(color: Colors.deepPurple),
            tagIcon: const Icon(Icons.outbox, size: 12),
            tagContainerDecoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey),
              borderRadius: const BorderRadius.all(
                Radius.circular(20),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(139, 139, 142, 0.16),
                  spreadRadius: 1,
                  blurRadius: 1,
                  offset: Offset(1.75, 3.5),
                )
              ],
            ),
            onTagDoubleTap: (tag) => {removeOutputTag(tag)},
          ),
        ),
      ]),
    );
  }

  String txFeeInfo() {
    if (unsignedTx.unsignedTxHex == '') {
      return '';
    }

    return 'BTC/kB: ${mBTC2BTC(unsignedTx.feeSatoshiPerKB)},  Fee: ${mBTC2BTC(unsignedTx.fee)} BTC';
  }

  Widget dividerUI() {
    return const Padding(
      padding: EdgeInsets.all(8.0),
      child: Divider(
        thickness: 6,
        color: Colors.blueAccent,
      ),
    );
  }

  String inputAddressText(String address) {
    if (inputAddresses.contains(address)) {
      return '从付款地址中移除';
    }

    return '添加地址到付款';
  }

  String inputUnspentTxText(Unspent unspent) {
    if (inputUnspentTags.contains(unspent.key())) {
      return '从付款输入移除';
    }

    return '添加到付款输入';
  }

  Widget unspentTitle(dynamic v) {
    if (v is WalletAddressUnspent) {
      return Text((v).wallet);
    }

    if (v is AddressUnspent) {
      return Row(
        children: [
          Expanded(child: Text('${(v).label} ${mBTC2BTC((v).amount)} BTC')),
          Visibility(
              visible: payType == SingingCharacter.pay,
              child: OutlinedButton(
                onPressed: () => {
                  if (!inputAddresses.contains((v).address))
                    {inputAddresses.add((v).address), setState(() {})}
                  else
                    {removeInputTag(v.address)}
                },
                child: Text(inputAddressText(v.address)),
              )),
          const SizedBox(width: 20),
        ],
      );
      //return Text((v).label);
    }

    if (v is Unspent) {
      return Row(
        children: [
          Expanded(
              child: Text(
                  '${mBTC2BTC((v).amount)} BTC   ${(v).confirmations} confirmations')),
          Visibility(
              visible: payType == SingingCharacter.advancePay,
              child: OutlinedButton(
                  onPressed: () => {
                        if (!inputUnspentTags.contains(v.key()))
                          {
                            inputUnspentTags.add((v).key()),
                            inputUnspents.add(v),
                            setState(() {})
                          }
                        else
                          {removeUnspentTag(v.key())}
                      },
                  child: Text(inputUnspentTxText(v)))),
          const SizedBox(width: 20),
        ],
      );
    }

    return const Text('');
  }

  String unspentSubTitle(dynamic v) {
    if (v is WalletAddressUnspent) {
      return ('\t${mBTC2BTC((v).amount)} BTC');
    }

    if (v is AddressUnspent) {
      return (v).address;
    }

    if (v is Unspent) {
      return (v).subTitle();
    }

    return '';
  }

  Future<void> saveUnsigndTx(String content, commandJSON) async {
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: '请选择未签名交易保存文件',
      fileName: 'unsigned-tx.txt',
    );

    if (outputFile != null) {
      File file = File(outputFile);
      file.writeAsString(content);
    }

    outputFile = await FilePicker.platform.saveFile(
      dialogTitle: '请选择未签名交易命令JSON版本保存文件',
      fileName: 'unsigned-tx.json',
    );

    if (outputFile != null) {
      File file = File(outputFile);
      file.writeAsString(commandJSON);
    }
  }

  Widget? mainWidgets() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '钱包',
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 10),
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
              const SizedBox(width: 20),
              Text(
                balance,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          dividerUI(),
          Row(children: [
            Flexible(
              child: ListTile(
                title: const Text('付款'),
                leading: Radio<SingingCharacter>(
                  value: SingingCharacter.pay,
                  groupValue: payType,
                  onChanged: (SingingCharacter? value) {
                    setState(() {
                      payType = value;
                    });
                  },
                ),
              ),
            ),
            Flexible(
              child: ListTile(
                title: const Text('付款(专业模式)'),
                leading: Radio<SingingCharacter>(
                  value: SingingCharacter.advancePay,
                  groupValue: payType,
                  onChanged: (SingingCharacter? value) {
                    setState(() {
                      payType = value;
                      inputCustomFlag = true;
                    });
                  },
                ),
              ),
            ),
          ]),
          dividerUI(),
          CheckboxListTile(
              value: inputCustomFlag,
              onChanged: (value) => {
                    setState(() {
                      if (value != null && payType == SingingCharacter.pay) {
                        inputCustomFlag = value;
                      }
                    })
                  },
              title: const Text('输入')),
          Visibility(
            visible: inputCustomFlag,
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: TreeView.simple(
                    tree: unspent,
                    showRootNode: false,
                    expansionIndicatorBuilder: (context, node) =>
                        ChevronIndicator.rightDown(
                      tree: node,
                      color: Colors.blue[700],
                      padding: const EdgeInsets.all(8),
                    ),
                    indentation:
                        const Indentation(style: IndentStyle.squareJoint),
                    onItemTap: (item) {},
                    onTreeReady: (controller) {},
                    builder: (context, node) => Card(
                      child: ListTile(
                        title: unspentTitle(node.data),
                        subtitle: Text(unspentSubTitle(node.data)),
                      ),
                    ),
                  ),
                ),
                Visibility(
                  visible: payType == SingingCharacter.pay,
                  child: Container(
                    margin: const EdgeInsets.all(15.0),
                    padding: const EdgeInsets.all(3.0),
                    child: SimpleTags(
                      content: inputAddresses,
                      wrapSpacing: 4,
                      wrapRunSpacing: 4,
                      tagContainerPadding: const EdgeInsets.all(6),
                      tagTextStyle: const TextStyle(color: Colors.deepPurple),
                      tagIcon:
                          const Icon(Icons.currency_bitcoin_rounded, size: 12),
                      tagContainerDecoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(20),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(139, 139, 142, 0.16),
                            spreadRadius: 1,
                            blurRadius: 1,
                            offset: Offset(1.75, 3.5),
                          )
                        ],
                      ),
                      onTagDoubleTap: (tag) => {removeInputTag(tag)},
                    ),
                  ),
                ),
                Visibility(
                  visible: payType == SingingCharacter.pay,
                  child: Row(
                    children: [
                      Flexible(
                        child: TextField(
                          controller: inputAddressController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: '付款地址',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          if (inputAddressController.text == '') {
                            AlertUtils.alertDialog(
                                context: context,
                                content: 'address or input is null');

                            return;
                          }

                          inputAddresses.add(inputAddressController.text);

                          setState(() {
                            inputAddressController.text = '';
                          });
                        },
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
                Visibility(
                  visible: payType == SingingCharacter.advancePay,
                  child: Container(
                    margin: const EdgeInsets.all(15.0),
                    padding: const EdgeInsets.all(3.0),
                    child: SimpleTags(
                      content: inputUnspentTags,
                      wrapSpacing: 4,
                      wrapRunSpacing: 4,
                      tagContainerPadding: const EdgeInsets.all(6),
                      tagTextStyle: const TextStyle(color: Colors.deepPurple),
                      tagIcon:
                          const Icon(Icons.currency_bitcoin_rounded, size: 12),
                      tagContainerDecoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(20),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(139, 139, 142, 0.16),
                            spreadRadius: 1,
                            blurRadius: 1,
                            offset: Offset(1.75, 3.5),
                          )
                        ],
                      ),
                      onTagDoubleTap: (tag) => {removeUnspentTag(tag)},
                    ),
                  ),
                ),
              ],
            ),
          ),
          dividerUI(),
          ListTile(title: const Text('输出'), onTap: () => {}),
          Container(
            margin: const EdgeInsets.all(15.0),
            padding: const EdgeInsets.all(3.0),
            child: SimpleTags(
              content: outputs,
              wrapSpacing: 4,
              wrapRunSpacing: 4,
              tagContainerPadding: const EdgeInsets.all(6),
              tagTextStyle: const TextStyle(color: Colors.deepPurple),
              tagIcon: const Icon(Icons.currency_bitcoin_rounded, size: 12),
              tagContainerDecoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey),
                borderRadius: const BorderRadius.all(
                  Radius.circular(20),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(139, 139, 142, 0.16),
                    spreadRadius: 1,
                    blurRadius: 1,
                    offset: Offset(1.75, 3.5),
                  )
                ],
              ),
              onTagDoubleTap: (tag) => {removeOutputTag(tag)},
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Flexible(
                child: TextField(
                  controller: outputAddressController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '收款地址',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: outputAmountController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '金额(BTC)',
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  if (outputAddressController.text == '' ||
                      outputAmountController.text == '') {
                    AlertUtils.alertDialog(
                        context: context, content: 'address or output is null');

                    return;
                  }

                  outputs.add(
                      "${outputAddressController.text}:${outputAmountController.text}");

                  setState(() {
                    outputAddressController.text = '';
                    outputAmountController.text = '';
                  });
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          dividerUI(),
          ListTile(title: const Text('其他'), onTap: () => {}),
          Row(
            children: [
              Flexible(
                flex: 3,
                child: TextField(
                  controller: changeAddressController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '找零地址',
                  ),
                ),
              ),
              Flexible(
                child: CheckboxListTile(
                    value: minTransFlag,
                    title: const Text('尽量少引用Input'),
                    onChanged: (value) => {
                          if (value != null)
                            {
                              setState(() {
                                minTransFlag = value;
                              })
                            }
                        }),
              )
            ],
          ),
          dividerUI(),
          ListTile(title: const Text('未签名'), onTap: () => {}),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 4, children: [
            SizedBox(
              width: 150,
              child: TextField(
                onChanged: (value) => {setState(() {})},
                controller: totalFeeBtcController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '固定总费用(BTC)',
                ),
              ),
            ),
            Visibility(
              visible: totalFeeBtcController.text == '',
              child: SizedBox(
                width: 120,
                child: TextField(
                  onChanged: (value) => {setState(() {})},
                  controller: feeBtcPerKBController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '费率:BTC/kB',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text('最佳:$bestBTCPerKB'),
            IconButton(
                onPressed: () {
                  flushFeeBTCPerKB();
                },
                icon: const Icon(Icons.refresh)),
            Visibility(
              visible: feeBtcPerKBController.text == '' &&
                  totalFeeBtcController.text == '',
              child: Row(
                children: [
                  Slider(
                    value: confirmationTarget,
                    min: 1,
                    max: 20,
                    divisions: 20,
                    label: confirmationTarget.toInt().toString(),
                    onChanged: (double value) {
                      setState(() {
                        confirmationTarget = value.round().toDouble();
                      });
                    },
                  ),
                  Text('预计确认区块数 ${confirmationTarget.toInt()}'),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ElevatedButton(
                onPressed: () {
                  flushUnsignedTx();
                },
                child: const Text('生成')),
            const SizedBox(width: 10),
            ElevatedButton(
                onPressed: () {
                  resetAll();
                },
                child: const Text('重置')),
            const SizedBox(width: 10),
            ElevatedButton(
                onPressed: () {
                  loadUnsignedTx();
                },
                child: const Text('加载未签名交易')),
            const SizedBox(width: 10),
            Visibility(
              visible: unsignedTx.unsignedTxHex != '',
              child: ElevatedButton(
                  onPressed: () {
                    saveUnsigndTx(
                        unsignedTx.unsignedTxHex, unsignedTx.commandJSON);
                  },
                  child: const Text('保存未签名交易')),
            ),
            const SizedBox(width: 10),
            Visibility(
              visible: unsignedTx.unsignedTxHex != '',
              child: ElevatedButton(
                  onPressed: () {
                    reUnsignTx(unsignedTx.unsignedTxHex);
                  },
                  child: const Text('根据费用设置重新生成')),
            )
          ]),
          dividerUI(),
          const SizedBox(height: 10),
          Text(txFeeInfo()),
          const SizedBox(height: 10),
          unsignedTxUI(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      appBar: AppBar(title: const Text('付款')),
      body: SingleChildScrollView(child: mainWidgets()),
    ));
  }
}
