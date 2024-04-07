import 'dart:convert';
import 'package:btcconnectapp/pages/share.dart';
import 'package:crypto/crypto.dart';

class TxInput {
  final String txID;
  final int vOut;
  final String address;
  final int amount;
  final String redeemScript;

  const TxInput({
    required this.txID,
    required this.vOut,
    required this.address,
    required this.amount,
    required this.redeemScript,
  });

  factory TxInput.fromJson(Map<String, dynamic> json) {
    return TxInput(
      txID: json['tx_id'],
      vOut: json['v_out'],
      address: json['address'],
      amount: json['amount'],
      redeemScript: json['redeem_script'],
    );
  }

  factory TxInput.empty() {
    return const TxInput(
        txID: '', vOut: 0, address: '', amount: 0, redeemScript: '');
  }
}

class TxOutput {
  final String address;
  final int amount;
  final bool changeFlag;

  const TxOutput({
    required this.address,
    required this.amount,
    required this.changeFlag,
  });

  factory TxOutput.fromJson(Map<String, dynamic> json) {
    return TxOutput(
      address: json['address'],
      amount: json['amount'],
      changeFlag: json['change_flag'],
    );
  }

  factory TxOutput.empty() {
    return const TxOutput(address: '', amount: 0, changeFlag: false);
  }
}

class UnsignedTx {
  final List<TxInput> inputs;
  final List<TxOutput> outputs;

  const UnsignedTx({
    required this.inputs,
    required this.outputs,
  });

  factory UnsignedTx.fromJson(Map<String, dynamic> json) {
    return UnsignedTx(
      inputs: (json['inputs'] as List).map((e) => TxInput.fromJson(e)).toList(),
      outputs:
          (json['outputs'] as List).map((e) => TxOutput.fromJson(e)).toList(),
    );
  }

  factory UnsignedTx.empty() {
    return const UnsignedTx(inputs: <TxInput>[], outputs: <TxOutput>[]);
  }
}

class UnsignedTxResponse {
  final String unsignedTxHex;
  final UnsignedTx unsignedTx;
  final int feeSatoshiPerKB;
  final int fee;

  const UnsignedTxResponse({
    required this.unsignedTxHex,
    required this.unsignedTx,
    required this.feeSatoshiPerKB,
    required this.fee,
  });

  factory UnsignedTxResponse.fromJson(Map<String, dynamic> json) {
    return UnsignedTxResponse(
      unsignedTxHex: json['unsigned_tx_hex'],
      unsignedTx: UnsignedTx.fromJson(json['unsigned_tx']),
      feeSatoshiPerKB: json['fee_satoshi_per_kb'],
      fee: json['fee'],
    );
  }

  factory UnsignedTxResponse.empty() {
    return UnsignedTxResponse(
        unsignedTxHex: '',
        unsignedTx: UnsignedTx.empty(),
        feeSatoshiPerKB: 0,
        fee: 0);
  }
}

/*

type UnspentVO struct {
	TxID          string  `json:"tx_id"`
	VOut          uint32  `json:"v_out"`
	Label         string  `json:"label"`
	Address       string  `json:"address"`
	Confirmations int     `json:"confirmations"`
	Amount        float64 `json:"amount"`
}
 */

class Unspent {
  final String txID;
  final int vOut;
  final String label;
  final String address;
  final int confirmations;
  final int amount;

  const Unspent({
    required this.txID,
    required this.vOut,
    required this.label,
    required this.address,
    required this.confirmations,
    required this.amount,
  });

  factory Unspent.fromJson(Map<String, dynamic> json) {
    return Unspent(
      txID: json['tx_id'],
      vOut: json['v_out'],
      label: json['label'],
      address: json['address'],
      confirmations: json['confirmations'],
      amount: json['amount'],
    );
  }

  factory Unspent.empty() {
    return const Unspent(
        txID: '', vOut: 0, label: '', address: '', confirmations: 0, amount: 0);
  }

  String key() {
    return '$txID:$vOut ${mBTC2BTC(amount)} BTC';
  }

  String subTitle() {
    return '$txID $vOut';
  }

  bool equal(Unspent oth) {
    return txID == oth.txID && vOut == oth.vOut;
  }
}

class AddressUnspent {
  final String address;
  final String label;
  final List<Unspent> unspent;
  final int amount;

  const AddressUnspent({
    required this.address,
    required this.label,
    required this.unspent,
    required this.amount,
  });

  factory AddressUnspent.fromJson(Map<String, dynamic> json) {
    return AddressUnspent(
      address: json['address'],
      label: json['label'],
      unspent: json['unspent'] == null
          ? <Unspent>[]
          : (json['unspent'] as List).map((e) => Unspent.fromJson(e)).toList(),
      amount: json['amount'],
    );
  }

  factory AddressUnspent.empty() {
    return const AddressUnspent(
        address: '', label: '', unspent: <Unspent>[], amount: 0);
  }
}

class WalletAddressUnspent {
  final String wallet;
  final List<AddressUnspent> unspent;
  final int amount;

  const WalletAddressUnspent({
    required this.wallet,
    required this.unspent,
    required this.amount,
  });

  factory WalletAddressUnspent.fromJson(Map<String, dynamic> json) {
    return WalletAddressUnspent(
      wallet: json['wallet'],
      unspent: json['unspent_list'] == null
          ? <AddressUnspent>[]
          : (json['unspent_list'] as List)
              .map((e) => AddressUnspent.fromJson(e))
              .toList(),
      amount: json['amount'],
    );
  }

  factory WalletAddressUnspent.empty() {
    return const WalletAddressUnspent(
        wallet: '', unspent: <AddressUnspent>[], amount: 0);
  }
}
