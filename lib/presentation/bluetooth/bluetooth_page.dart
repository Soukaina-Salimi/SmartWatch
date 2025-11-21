import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smartwatch_v2/pages/health/HealthMonitorScreen.dart';

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
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Connecté à ${device.name}")));

      // Découvrir les services BLE
      List<BluetoothService> services = await device.discoverServices();

      // UUID TX de l'ESP32 (notify)
      final String txUUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";

      BluetoothCharacteristic? txCharacteristic;

      // Recherche de la characteristic TX
      for (var service in services) {
        for (var char in service.characteristics) {
          if (char.uuid.toString().toUpperCase() == txUUID) {
            txCharacteristic = char;
            break;
          }
        }
      }

      if (txCharacteristic == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ TX Characteristic non trouvée")),
        );
        return;
      }

      // Activer les notifications
      await txCharacteristic.setNotifyValue(true);

      // 🔥 NAVIGATION vers l’écran HealthMonitor
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HealthMonitorScreen()),
      );

      // 🔥 STREAM : chaque notification JSON → parse → update UI
      txCharacteristic.value.listen((value) {
        try {
          String jsonString = utf8.decode(value);
          Map<String, dynamic> data = jsonDecode(jsonString);

          print("📥 Données reçues : $data");

          // 👉 Rappelle l’écran actif et met à jour ses champs
          HealthMonitorScreenState? state =
              HealthMonitorScreen.globalKey.currentState;

          if (state != null) {
            state.updateDataFields(data);
          }
        } catch (e) {
          print("Erreur JSON: $e");
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

                      if (device.state != BluetoothDeviceState.connected) {
                        try {
                          await device
                              .connect(autoConnect: false)
                              .timeout(const Duration(seconds: 25));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Connecté à $displayName")),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Erreur de connexion : $e")),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("$displayName est déjà connecté"),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
