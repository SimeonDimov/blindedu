// ignore_for_file: library_private_types_in_public_api

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ESP32 BLE Control',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const BLEControlPage(),
      );
}

class BLEControlPage extends StatefulWidget {
  const BLEControlPage({super.key});

  @override
  _BLEControlPageState createState() => _BLEControlPageState();
}

class _BLEControlPageState extends State<BLEControlPage> {
  bool _awaitingResponse = false;

  final _ble = FlutterReactiveBle();
  final _serviceUuid = Uuid.parse("12345678-1234-5678-1234-56789abcdef0");
  final _characteristicUuid =
      Uuid.parse("87654321-4321-6789-4321-6789abcdef01");
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  StreamSubscription<DiscoveredDevice>? _scanStreamSubscription;
  StreamSubscription<List<int>>? _feedbackSubscription;

  final List<DiscoveredDevice> _foundBleDevices = [];
  DiscoveredDevice? _connectedDevice;
  QualifiedCharacteristic? _qualifiedCharacteristic;
  bool _isConnected = false;
  bool _isScanning = false;
  String _statusMessage = ''; // Add this line to define the variable
  Color _connectionStatusColor = Colors.red;
  @override
  @override
  void initState() {
    super.initState();
    _requestPermissions().then((_) {
      // Start scanning for devices as soon as the app starts and permissions are granted
      startScan();
    });
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
    if (_isScanning) return; // Prevent multiple scans at the same time
    _foundBleDevices.clear(); // Clear the list each time you start scanning
    setState(() {
      _statusMessage = 'Scanning for devices...';
      _isScanning = true;
    });

    _scanStreamSubscription?.cancel(); // Cancel any existing scan
    _scanStreamSubscription = _ble.scanForDevices(
      withServices: [_serviceUuid],
      scanMode: ScanMode.lowLatency,
    ).listen(
      (device) {
        if (!_foundBleDevices.any((d) => d.id == device.id)) {
          setState(() {
            _foundBleDevices.add(device);
          });
        }
      },
      onError: (Object error) {
        setState(() {
          _statusMessage = 'Error occurred while scanning. Please try again.';
          _isScanning = false;
        });
      },
    );
  }

  void stopScan() {
    _scanStreamSubscription?.cancel();
    setState(() {
      _isScanning = false;
      _statusMessage = 'Scan completed';
      // Optionally clear the list if you want to start fresh next time
      // _foundBleDevices.clear();
    });
  }

  Future<void> _connectToDevice(DiscoveredDevice device) async {
    _connectionSubscription?.cancel(); // Cancel previous subscription if any
    _connectionSubscription = _ble
        .connectToDevice(
      id: device.id,
      servicesWithCharacteristicsToDiscover: {
        _serviceUuid: [_characteristicUuid],
      },
      connectionTimeout: const Duration(seconds: 5),
    )
        .listen(
      (connectionState) {
        if (connectionState.connectionState ==
            DeviceConnectionState.connected) {
          _qualifiedCharacteristic = QualifiedCharacteristic(
            serviceId: _serviceUuid,
            characteristicId: _characteristicUuid,
            deviceId: device.id,
          );

          // Call _listenToFeedback here to start listening for feedback
          _listenToFeedback();

          setState(() {
            _isConnected = true;
            _connectedDevice = device;
            _statusMessage = 'Connected to ${device.name}';
            _connectionStatusColor = Colors.green;
          });
        } else if (connectionState.connectionState ==
            DeviceConnectionState.disconnected) {
          setState(() {
            _isConnected = false;
            _connectedDevice = null;
            _qualifiedCharacteristic = null;
            _statusMessage = 'Disconnected';
            _connectionStatusColor = Colors.red;
          });
        }
      },
      onError: (dynamic error) {
        setState(() {
          _isConnected = false;
          _connectedDevice = null;
          _qualifiedCharacteristic = null;
          _statusMessage = 'Connection error: ${error.toString()}';
          _connectionStatusColor = Colors.red;
        });
      },
    );
  }

// Add the _listenToFeedback function
  void _listenToFeedback() {
    if (_qualifiedCharacteristic == null) {
      setState(() {
        _statusMessage = 'Device not connected for feedback.';
        _connectionStatusColor = Colors.red;
      });
      return;
    }

    _feedbackSubscription?.cancel(); // Cancel any existing subscription
    _feedbackSubscription = _ble
        .subscribeToCharacteristic(_qualifiedCharacteristic!)
        .listen((data) {
      if (!_awaitingResponse) {
        return; // Ignore the data if we are not expecting a response
      }

      final responseValue = String.fromCharCodes(data);
      if (responseValue.contains('LED ON') ||
          responseValue.contains('LED OFF')) {
        setState(() {
          _statusMessage = 'ESP32 says: $responseValue';
          _connectionStatusColor = Colors.green;
        });
        _awaitingResponse = false; // Reset the flag after getting a response
      }
    }, onError: (dynamic error) {
      setState(() {
        _statusMessage = 'Feedback error: $error';
        _connectionStatusColor = Colors.red;
      });
      _awaitingResponse = false; // Reset the flag if there's an error
    });
  }

  Future<void> _sendCommand(String command) async {
    if (_qualifiedCharacteristic == null) {
      setState(() {
        _statusMessage = 'Device not connected.';
        _connectionStatusColor = Colors.red;
      });
      return;
    }

    try {
      _awaitingResponse = true; // We are now awaiting a response

      await _ble.writeCharacteristicWithResponse(
        _qualifiedCharacteristic!,
        value: command.codeUnits,
      );

      // No need to subscribe here again if we're already listening for feedback elsewhere
    } catch (e) {
      setState(() {
        _statusMessage = 'Error sending command: $e';
        _connectionStatusColor = Colors.red;
      });
    }
  }

  @override
  void dispose() {
    _scanStreamSubscription?.cancel();
    _connectionSubscription?.cancel();
    _feedbackSubscription?.cancel(); // Add this line
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
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _isConnected = false;
                  _connectedDevice = null;
                  _qualifiedCharacteristic = null;
                });
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Centered status bar
            Container(
              padding: const EdgeInsets.all(8.0),
              color: _connectionStatusColor,
              child: Center(
                // Center widget added here
                child: Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            Expanded(
              child: _isConnected
                  ? _buildConnectedDeviceInterface()
                  : _buildScanningInterface(),
            ),
          ],
        ),
      ),
      floatingActionButton: _isScanning || _foundBleDevices.isNotEmpty
          ? null // Hide the button if scanning or devices are found
          : FloatingActionButton(
              onPressed: startScan,
              backgroundColor: Theme.of(context).primaryColor,
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
    if (_foundBleDevices.isEmpty) {
      return Center(child: Text(_statusMessage)); // Display the status message
    }
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
