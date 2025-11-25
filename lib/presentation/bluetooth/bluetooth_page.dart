import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smartwatch_v2/pages/dashboard/dashboard_page.dart';
import 'package:smartwatch_v2/services/data_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({Key? key}) : super(key: key);

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  List<ScanResult> scanResults = [];
  late StreamSubscription<List<ScanResult>> scanSubscription;

  @override
  void initState() {
    super.initState();
    checkPermissions().then((_) => startScan());
  }

  @override
  void dispose() {
    scanSubscription.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  // -------------------------------
  // 🔹 Vérifie les permissions Android 12+ et localisation
  // -------------------------------
  Future<void> checkPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  // -------------------------------
  // 🔹 Fonction de Scan BLE
  // -------------------------------
  void startScan() async {
    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        scanResults = results;
      });
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
  }

  // -------------------------------
  // 🔹 Connexion à un appareil BLE
  // -------------------------------
  final dataSyncService = DataSyncService(supabase: Supabase.instance.client);
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Connecté à ${device.name}")));

      // Découvrir services
      List<BluetoothService> services = await device.discoverServices();

      const String txUUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"; // notify
      const String rxUUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"; // write

      BluetoothCharacteristic? txCharacteristic;
      BluetoothCharacteristic? rxCharacteristic;

      // Trouver TX et RX
      for (var s in services) {
        for (var c in s.characteristics) {
          final uuid = c.uuid.toString().toUpperCase();
          if (uuid == txUUID) txCharacteristic = c;
          if (uuid == rxUUID) rxCharacteristic = c;
        }
      }

      if (txCharacteristic == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ TX Characteristic non trouvée")),
        );
        return;
      }

      if (rxCharacteristic == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ RX Characteristic non trouvée")),
        );
        return;
      }

      // Activer notifications TX
      await txCharacteristic.setNotifyValue(true);

      // ---------------------------------------------------------
      // 🔥 ENVOYER TIMESTAMP TOUTES LES 1 MINUTE
      // ---------------------------------------------------------
      Timer.periodic(Duration(minutes: 1), (timer) async {
        final timestamp = DateTime.now().toString().substring(0, 16);
        final message = "TS:$timestamp";

        try {
          await rxCharacteristic?.write(message.codeUnits);
          print("📤 Sent timestamp: $message");
        } catch (e) {
          print("❌ Error sending timestamp: $e");
        }
      });
      // ---------------------------------------------------------

      // Ouvrir dashboard AVANT d’écouter
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DashboardPage()),
      );

      // STREAM JSON depuis ESP32
      txCharacteristic.value.listen((bytes) {
        try {
          String jsonString = utf8.decode(bytes);
          Map<String, dynamic> data = jsonDecode(jsonString);

          print("📥 Données reçues : $data");

          final state = DashboardPage.globalKey.currentState;
          state?.updateDataFields(data);
        } catch (e) {
          print("❌ Erreur JSON: $e");
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erreur de connexion : $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bluetooth Devices"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await FlutterBluePlus.stopScan();
              startScan();
            },
          ),
        ],
      ),
      body: scanResults.isEmpty
          ? const Center(child: Text("Aucun appareil trouvé"))
          : ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                final device = scanResults[index].device;
                final advData = scanResults[index].advertisementData;

                // Affichage du nom : device.name > advertisement localName > fallback
                String displayName = device.name.isNotEmpty
                    ? device.name
                    : advData.localName.isNotEmpty
                    ? advData.localName
                    : "Appareil inconnu";

                return Card(
                  child: ListTile(
                    title: Text(displayName),
                    subtitle: Text(device.id.id),
                    trailing: const Icon(Icons.bluetooth),
                    onTap: () async {
                      if (!await Permission.bluetoothConnect.isGranted) return;

                      await FlutterBluePlus.stopScan();
                      await Future.delayed(const Duration(milliseconds: 300));

                      await connectToDevice(device);
                    },
                  ),
                );
              },
            ),
    );
  }
}
