// lib/services/nfc_service.dart
// ignore_for_file: non_constant_identifier_names

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:aplicativo_trilha/models/nfc_read_result.dart';

enum TagStatus {
  unknown,
  empty_formatable,
  formatted_valid,
  formatted_invalid,
  not_supported,
}

class TagDiagnosis {
  final TagStatus status;
  final int? logicalId;
  final int recordCount;

  TagDiagnosis({required this.status, this.logicalId, this.recordCount = 0});
}

class NfcService {
  NdefRecord _createManualTextRecord(
    String text, {
    String languageCode = 'en',
  }) {
    final textBytes = utf8.encode(text);
    final langBytes = utf8.encode(languageCode);
    final statusByte = langBytes.length;

    final payloadBytes = Uint8List.fromList(
      [statusByte] + langBytes + textBytes,
    );

    return NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList([0x54]),
      identifier: Uint8List(0),
      payload: payloadBytes,
    );
  }

  Future<bool> writeToTag(
    NfcTag tag, {
    required String userId,
    required String timestamp,
    double? lat,
    double? lon,
  }) async {
    final ndef = Ndef.from(tag);
    if (ndef == null || !ndef.isWritable) {
      print("[NfcService-v4] Tag não é gravável ou não suporta NDEF.");
      return false;
    }

    final Map<String, dynamic> data = {'id': userId, 'ts': timestamp};
    if (lat != null && lon != null) {
      data['lat'] = lat;
      data['lon'] = lon;
    }
    final payload = jsonEncode(data);
    final newRecord = _createManualTextRecord(payload);

    List<NdefRecord> allRecords = [];
    NdefMessage? cachedMessage;
    try {
      cachedMessage = await ndef.read();
    } catch (e) {
      print("[NfcService-v4] Erro leitura (pode estar vazia): $e");
    }

    if (cachedMessage != null && cachedMessage.records.isNotEmpty) {
      print(
        "[NfcService-v4] Adicionando a ${cachedMessage.records.length} registros existentes.",
      );
      allRecords.addAll(cachedMessage.records);
    }

    allRecords.add(newRecord);

    final finalMessage = NdefMessage(records: allRecords);

    try {
      await ndef.write(message: finalMessage);
      print("[NfcService-v4] Sucesso! Tag atualizada.");
      return true;
    } catch (e) {
      print("[NfcService-v4] Erro ao escrever na tag: $e");
      return false;
    }
  }

  Future<NfcReadResult> readTagData(NfcTag tag) async {
    final ndef = Ndef.from(tag);
    if (ndef == null) {
      print("[NfcService-v4] Tag não suporta NDEF.");
      return NfcReadResult(logicalId: null, logs: []);
    }

    NdefMessage? cachedMessage;
    try {
      cachedMessage = await ndef.read();
    } catch (e) {
      print("[NfcService-v4] Erro ao ler a tag: $e");
      return NfcReadResult(logicalId: null, logs: []);
    }

    if (cachedMessage == null || cachedMessage.records.isEmpty) {
      return NfcReadResult(logicalId: null, logs: []);
    }

    int? logicalId;
    List<Map<String, dynamic>> logs = [];

    for (int i = 0; i < cachedMessage.records.length; i++) {
      final record = cachedMessage.records[i];
      try {
        if (record.typeNameFormat == TypeNameFormat.wellKnown &&
            listEquals(record.type, [0x54])) {
          int langCodeLength = record.payload.first & 0x3F;
          int prefixLength = 1 + langCodeLength;
          final jsonString = utf8.decode(record.payload.sublist(prefixLength));
          final data = jsonDecode(jsonString) as Map<String, dynamic>;

          if (i == 0 && data.containsKey('logical_id')) {
            logicalId = data['logical_id'];
          } else if (data.containsKey('id')) {
            logs.add(data);
          }
        }
      } catch (e) {
        print("[NfcService-v4] Erro registro: $e");
      }
    }
    return NfcReadResult(logicalId: logicalId, logs: logs);
  }

  Future<TagDiagnosis> checkTagStatus(NfcTag tag) async {
    final ndef = Ndef.from(tag);
    if (ndef != null) {
      try {
        final message = await ndef.read();
        int? id;
        if (message!.records.isNotEmpty) {
          try {
            final record = message.records.first;
            int prefix = 1 + (record.payload.first & 0x3F);
            final jsonStr = utf8.decode(record.payload.sublist(prefix));
            final data = jsonDecode(jsonStr);
            id = data['logical_id'];
          } catch (_) {}
        }

        if (id != null) {
          return TagDiagnosis(
            status: TagStatus.formatted_valid,
            logicalId: id,
            recordCount: message.records.length,
          );
        } else {
          return TagDiagnosis(
            status: TagStatus.formatted_invalid,
            recordCount: message.records.length,
          );
        }
      } catch (e) {
        return TagDiagnosis(status: TagStatus.unknown);
      }
    }

    final ndefFormatable = NdefFormatableAndroid.from(tag);
    if (ndefFormatable != null) {
      return TagDiagnosis(status: TagStatus.empty_formatable);
    }

    return TagDiagnosis(status: TagStatus.not_supported);
  }

  Future<bool> formatTag(NfcTag tag, int newLogicalId) async {
    final payload = jsonEncode({'logical_id': newLogicalId});
    final masterRecord = _createManualTextRecord(payload);
    final message = NdefMessage(records: [masterRecord]);

    try {
      final ndefFormatable = NdefFormatableAndroid.from(tag);
      if (ndefFormatable != null) {
        await ndefFormatable.format(message);
        print("[NfcService] Tag formatada via NdefFormatable!");
        return true;
      }

      final ndef = Ndef.from(tag);
      if (ndef != null && ndef.isWritable) {
        await ndef.write(message: message);
        print("[NfcService] Tag formatada via Ndef write!");
        return true;
      }

      return false;
    } catch (e) {
      print("[NfcService] Erro ao formatar: $e");
      return false;
    }
  }

  Future<bool> writeOperatorTag(
    NfcTag tag, {
    required String userId,
    required double lat,
    required double lon,
  }) async {
    final String payloadString = "$userId|$lat|$lon";
    print("[NfcService] Preparando gravação de Operador: $payloadString");

    final record = _createManualTextRecord(payloadString);
    final message = NdefMessage(records: [record]);

    try {
      final ndefFormatable = NdefFormatableAndroid.from(tag);
      if (ndefFormatable != null) {
        await ndefFormatable.format(message);
        print("[NfcService] Sucesso via NdefFormatable (Operador).");
        return true;
      }

      final ndef = Ndef.from(tag);
      if (ndef == null || !ndef.isWritable) {
        print("[NfcService] Tag não suporta escrita NDEF.");
        return false;
      }

      await ndef.write(message: message);
      print("[NfcService] Sucesso via Ndef Write (Operador).");
      return true;
    } catch (e) {
      print("[NfcService] Erro na gravação do Operador: $e");
      return false;
    }
  }

  Future<bool> cleanTagData(NfcTag tag) async {
    final result = await readTagData(tag);
    if (result.logicalId == null) return false;

    return await formatTag(tag, result.logicalId!);
  }
}
