import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

const String deviceName = "ESP32_IMU";

final Guid serviceId = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
final Guid charId = Guid("beb5483e-36e1-4688-b7f5-ea07361b26a8");

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: BlePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BlePage extends StatefulWidget {
  const BlePage({super.key});

  @override
  State<BlePage> createState() => _BlePageState();
}

class _BlePageState extends State<BlePage> {

  BluetoothDevice? device;
  BluetoothCharacteristic? characteristic;
  StreamSubscription<List<int>>? notifySub;

  String status = "Starting...";
  String roll = "0.00";
  String pitch = "0.00";

  @override
  void initState() {
    super.initState();
    initBle();
  }

  Future<void> initBle() async {

    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        startScan();
      }
    });
  }

  void startScan() {

    setState(() {
      status = "Scanning...";
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));

    FlutterBluePlus.scanResults.listen((results) {

      for (var r in results) {

        if (r.device.platformName == deviceName) {

          FlutterBluePlus.stopScan();
          connectToDevice(r.device);
          break;
        }
      }
    });
  }

  Future<void> connectToDevice(BluetoothDevice d) async {

    setState(() {
      status = "Connecting...";
    });

    device = d;

    try {
      await device!.connect(timeout: const Duration(seconds: 10));
    } catch (_) {}

    setState(() {
      status = "Discovering services...";
    });

    List<BluetoothService> services = await device!.discoverServices();

    for (var s in services) {

      if (s.uuid == serviceId) {

        for (var c in s.characteristics) {

          if (c.uuid == charId) {

            characteristic = c;

            await characteristic!.setNotifyValue(true);
            await characteristic!.read();

            notifySub = characteristic!.value.listen((value) {

              String data = String.fromCharCodes(value).trim();

              print("RAW DATA: $data");

              List<String> parts = data.split(",");

              if (parts.length == 2) {

                setState(() {
                  roll = parts[0];
                  pitch = parts[1];
                });
              }
            });

            setState(() {
              status = "Connected ✅";
            });

            return;
          }
        }
      }
    }

    setState(() {
      status = "Characteristic not found ❌";
    });
  }

  @override
  void dispose() {
    notifySub?.cancel();
    device?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("ESP32 IMU Monitor")),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            Text(status, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 30),

            const Text("Roll"),
            Text(
              roll,
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            const Text("Pitch"),
            Text(
              pitch,
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
