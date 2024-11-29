import 'package:btcconnectapp/helper/commdata.dart';
import 'package:flutter/material.dart';

class ServerConfigPage extends StatefulWidget {
  const ServerConfigPage({super.key});

  @override
  State<ServerConfigPage> createState() => __ServerConfigPageState();
}

class __ServerConfigPageState extends State<ServerConfigPage> {
  final customServerURLController = TextEditingController();
  bool devMode = false;
  final proxyController = TextEditingController();
  bool testnet = false;

  @override
  void initState() {
    super.initState();

    devMode = CommData.devMode;
    testnet = CommData.testnet;
    customServerURLController.text = CommData.customServerURL;
    proxyController.text = CommData.proxy;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('服务器配置'),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              ListTile(
                title: TextField(
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: '自定义服务地址',
                      hintText: '输入自定义服务地址'),
                  controller: customServerURLController,
                ),
              ),
              Visibility(
                visible: customServerURLController.text == '',
                child: CheckboxListTile(
                  title: const Text('预置本地服务地址'),
                  onChanged: (bool? value) {
                    setState(() {
                      devMode = value!;
                    });
                  },
                  value: devMode,
                ),
              ),
              ListTile(
                title: TextField(
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: '代理',
                      hintText: '输入HTTP或者HTTPS代理地址和端口号'),
                  controller: proxyController,
                ),
              ),
              CheckboxListTile(
                title: const Text('测网'),
                onChanged: (bool? value) {
                  setState(() {
                    testnet = value!;
                  });
                },
                value: testnet,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                      onPressed: () {
                        CommData.devMode = devMode;
                        CommData.testnet = testnet;
                        CommData.customServerURL =
                            customServerURLController.text;
                        CommData.proxy = proxyController.text;
                        Navigator.of(context).pop();
                      },
                      child: const Text('确定')),
                  ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('取消'))
                ],
              )
            ],
          ),
        ));
  }
}
