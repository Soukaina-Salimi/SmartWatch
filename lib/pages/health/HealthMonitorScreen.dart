import 'package:flutter/material.dart';

class HealthMonitorScreen extends StatefulWidget {
  static final GlobalKey<HealthMonitorScreenState> globalKey =
      GlobalKey<HealthMonitorScreenState>();

  HealthMonitorScreen({Key? key}) : super(key: globalKey); // ← très important

  @override
  HealthMonitorScreenState createState() => HealthMonitorScreenState();
}

class HealthMonitorScreenState extends State<HealthMonitorScreen> {
  // Tes champs
  String ppgSignal = "";
  String ibi = "";
  String signalQuality = "";
  String accelX = "";
  String accelY = "";
  String accelZ = "";
  String gyroX = "";
  String gyroY = "";
  String gyroZ = "";
  String skinTemp = "";
  String ambientTemp = "";
  String uvIndex = "";
  String timestamp = "";

  // 🔥 Fonction appelée depuis BLE
  void updateDataFields(Map<String, dynamic> data) {
    setState(() {
      ppgSignal = data['ppg']?['raw_signal']?.toString() ?? "";
      ibi = data['ppg']?['ibi']?.toString() ?? "";
      signalQuality = data['ppg']?['signal_quality']?.toString() ?? "";

      accelX = data['movement']?['accel_x']?.toString() ?? "";
      accelY = data['movement']?['accel_y']?.toString() ?? "";
      accelZ = data['movement']?['accel_z']?.toString() ?? "";

      gyroX = data['movement']?['gyro_x']?.toString() ?? "";
      gyroY = data['movement']?['gyro_y']?.toString() ?? "";
      gyroZ = data['movement']?['gyro_z']?.toString() ?? "";

      skinTemp = data['temperature']?['skin_temp']?.toString() ?? "";
      ambientTemp = data['temperature']?['ambient_temp']?.toString() ?? "";

      uvIndex = data['uv']?['uv_index']?.toString() ?? "";

      timestamp = data['ppg']?['timestamp']?.toString() ?? "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Health Monitor")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text("PPG Signal: $ppgSignal"),
            Text("IBI: $ibi"),
            Text("Signal Quality: $signalQuality"),
            Text("Accel X: $accelX"),
            Text("Accel Y: $accelY"),
            Text("Accel Z: $accelZ"),
            Text("Gyro X: $gyroX"),
            Text("Gyro Y: $gyroY"),
            Text("Gyro Z: $gyroZ"),
            Text("Skin Temp: $skinTemp"),
            Text("Ambient Temp: $ambientTemp"),
            Text("UV Index: $uvIndex"),
            Text("Timestamp: $timestamp"),
          ],
        ),
      ),
    );
  }
}
