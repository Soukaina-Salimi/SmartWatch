// FILE: device_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DevicePage extends StatefulWidget {
  final BluetoothDevice device;

  const DevicePage({super.key, required this.device});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  StreamSubscription<BluetoothConnectionState>? _stateSub;
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  bool _isLoading = false;
  String _connectionMessage = "";

  @override
  void initState() {
    super.initState();
    _listenToConnection();
    _connectToDevice();
  }

  void _listenToConnection() {
    _stateSub = widget.device.connectionState.listen((state) {
      print("🔌 État de connexion: $state");
      setState(() => _connectionState = state);

      if (state == BluetoothConnectionState.connected) {
        _discoverServices();
        setState(() => _connectionMessage = "Connecté avec succès!");
      } else if (state == BluetoothConnectionState.connecting) {
        setState(() => _connectionMessage = "Connexion en cours...");
      } else if (state == BluetoothConnectionState.disconnected) {
        setState(() => _connectionMessage = "Déconnecté");
      }
    });
  }

  Future<void> _connectToDevice() async {
    try {
      setState(() {
        _isLoading = true;
        _connectionMessage = "Tentative de connexion...";
      });

      print("🔄 Connexion à ${widget.device.remoteId}");

      await widget.device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );
    } catch (e) {
      print("❌ Erreur connexion: $e");
      setState(() => _connectionMessage = "Erreur: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _discoverServices() async {
    try {
      setState(() => _connectionMessage = "Découverte des services...");

      print("🔍 Recherche des services...");
      final services = await widget.device.discoverServices();

      setState(() {
        _services = services;
        _connectionMessage = "${services.length} services trouvés";
      });

      print("✅ ${services.length} services découverts");
    } catch (e) {
      print("❌ Erreur services: $e");
      setState(() => _connectionMessage = "Erreur découverte services: $e");
    }
  }

  Future<void> _disconnect() async {
    try {
      await widget.device.disconnect();
      setState(() => _connectionMessage = "Déconnexion...");
    } catch (e) {
      print("Erreur déconnexion: $e");
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.device.platformName.isEmpty
              ? "Périphérique ${widget.device.remoteId.str}"
              : widget.device.platformName,
        ),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled),
            onPressed: _disconnect,
            tooltip: "Déconnecter",
          ),
        ],
      ),
      body: Column(
        children: [
          // Statut de connexion
          Container(
            padding: const EdgeInsets.all(16),
            color: _getStatusColor(),
            child: Row(
              children: [
                Icon(_getStatusIcon(), color: _getStatusIconColor()),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "État: $_connectionState",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getStatusTextColor(),
                        ),
                      ),
                      if (_connectionMessage.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _connectionMessage,
                          style: TextStyle(
                            fontSize: 12,
                            color: _getStatusTextColor(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          // Services découverts
          Expanded(child: _buildServicesList()),
        ],
      ),
    );
  }

  Widget _buildServicesList() {
    if (_services.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.device_hub, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _connectionState == BluetoothConnectionState.connected
                  ? "Aucun service détecté"
                  : "En attente de connexion...",
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            "Services disponibles (${_services.length})",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _services.length,
            itemBuilder: (context, index) {
              final service = _services[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.device_hub, color: Colors.blue),
                  title: Text(
                    "Service: ${service.uuid.toString().substring(4, 8).toUpperCase()}",
                    style: const TextStyle(fontFamily: 'Monospace'),
                  ),
                  subtitle: Text(
                    "${service.characteristics.length} caractéristiques",
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (_connectionState) {
      case BluetoothConnectionState.connected:
        return Colors.green[50]!;
      case BluetoothConnectionState.connecting:
        return Colors.orange[50]!;
      case BluetoothConnectionState.disconnected:
        return Colors.red[50]!;
      case BluetoothConnectionState.disconnecting:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  Color _getStatusTextColor() {
    switch (_connectionState) {
      case BluetoothConnectionState.connected:
        return Colors.green[800]!;
      case BluetoothConnectionState.connecting:
        return Colors.orange[800]!;
      case BluetoothConnectionState.disconnected:
        return Colors.red[800]!;
      case BluetoothConnectionState.disconnecting:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  Color _getStatusIconColor() {
    switch (_connectionState) {
      case BluetoothConnectionState.connected:
        return Colors.green;
      case BluetoothConnectionState.connecting:
        return Colors.orange;
      case BluetoothConnectionState.disconnected:
        return Colors.red;
      case BluetoothConnectionState.disconnecting:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  IconData _getStatusIcon() {
    switch (_connectionState) {
      case BluetoothConnectionState.connected:
        return Icons.bluetooth_connected;
      case BluetoothConnectionState.connecting:
        return Icons.bluetooth_searching;
      case BluetoothConnectionState.disconnected:
        return Icons.bluetooth_disabled;
      case BluetoothConnectionState.disconnecting:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }
}
