import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ESP32 BLE Control',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const BLEControlPage(),
      );
}

class BLEControlPage extends StatefulWidget {
  const BLEControlPage({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _BLEControlPageState createState() => _BLEControlPageState();
}

class _BLEControlPageState extends State<BLEControlPage> {
  final _ble = FlutterReactiveBle();
  final _serviceUuid = Uuid.parse("12345678-1234-5678-1234-56789abcdef0");
  final _characteristicUuid =
      Uuid.parse("87654321-4321-6789-4321-6789abcdef01");
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  StreamSubscription<DiscoveredDevice>? _scanStreamSubscription;
  final List<DiscoveredDevice> _foundBleDevices = [];
  DiscoveredDevice? _connectedDevice;
  QualifiedCharacteristic? _qualifiedCharacteristic;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      var bluetoothStatus = await Permission.bluetooth.status;
      if (!bluetoothStatus.isGranted) {
        await Permission.bluetooth.request();
      }

      var bluetoothScanStatus = await Permission.bluetoothScan.status;
      if (!bluetoothScanStatus.isGranted) {
        await Permission.bluetoothScan.request();
      }

      var bluetoothConnectStatus = await Permission.bluetoothConnect.status;
      if (!bluetoothConnectStatus.isGranted) {
        await Permission.bluetoothConnect.request();
      }

      var locationStatus = await Permission.location.status;
      if (!locationStatus.isGranted) {
        await Permission.location.request();
      }
    } else {
      // Non-Android platforms go here (iOS, etc.)
      // For iOS, you'll need to request the location permission for BLE operations
      var locationStatus = await Permission.location.status;
      if (!locationStatus.isGranted) {
        await Permission.location.request();
      }
    }
  }

  void startScan() {
    _scanStreamSubscription = _ble.scanForDevices(
      withServices: [_serviceUuid],
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      if (!_foundBleDevices.any((d) => d.id == device.id)) {
        setState(() {
          _foundBleDevices.add(device);
        });
      }
    }, onError: (Object error) {
      if (kDebugMode) {
        print('Scan Error: $error');
      }
      setState(() {});
    });
  }

  Future<void> _connectToDevice(DiscoveredDevice device) async {
    _connectionSubscription = _ble
        .connectToDevice(
      id: device.id,
      servicesWithCharacteristicsToDiscover: {
        _serviceUuid: [_characteristicUuid]
      },
      connectionTimeout: const Duration(seconds: 5),
    )
        .listen((connectionState) {
      if (connectionState.connectionState == DeviceConnectionState.connected) {
        setState(() {
          _isConnected = true;
          _connectedDevice =
              device; // Store the device object passed to the method
        });
        // Retrieve and store the QualifiedCharacteristic
        _qualifiedCharacteristic = QualifiedCharacteristic(
          serviceId: _serviceUuid,
          characteristicId: _characteristicUuid,
          deviceId: device.id,
        );
      } else if (connectionState.connectionState ==
          DeviceConnectionState.disconnected) {
        setState(() {
          _isConnected = false;
          _connectedDevice = null;
          _qualifiedCharacteristic = null;
        });
      }
    }, onError: (dynamic error) {
      setState(() {});
    });
  }

  void _disconnectFromDevice() {
    _connectionSubscription?.cancel();
    setState(() {
      _isConnected = false;
      _connectedDevice = null;
      _qualifiedCharacteristic = null;
    });
  }

  Future<void> _sendCommand(String command) async {
    if (_qualifiedCharacteristic == null) return;

    await _ble.writeCharacteristicWithResponse(
      _qualifiedCharacteristic!,
      value: command.codeUnits,
    );
  }

  @override
  void dispose() {
    _scanStreamSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 BLE Control'),
        actions: [
          if (_isConnected)
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: _disconnectFromDevice,
            ),
        ],
      ),
      body: _isConnected
          ? _buildConnectedDeviceInterface()
          : _buildScanningInterface(),
      floatingActionButton: _isConnected
          ? null
          : FloatingActionButton(
              onPressed: startScan,
              child: const Icon(Icons.bluetooth_searching),
            ),
    );
  }

  Widget _buildConnectedDeviceInterface() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Connected to ${_connectedDevice?.name ?? _connectedDevice?.id}'),
        ElevatedButton(
          onPressed: () => _sendCommand('on'),
          child: const Text('Turn ON LED'),
        ),
        ElevatedButton(
          onPressed: () => _sendCommand('off'),
          child: const Text('Turn OFF LED'),
        ),
      ],
    );
  }

  Widget _buildScanningInterface() {
    return ListView.builder(
      itemCount: _foundBleDevices.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(_foundBleDevices[index].name),
          subtitle: Text(_foundBleDevices[index].id),
          onTap: () => _connectToDevice(_foundBleDevices[index]),
        );
      },
    );
  }
}
