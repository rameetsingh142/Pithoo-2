import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fl_chart/fl_chart.dart';

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

  String status = "Ready to connect";
  String roll = "0.00";
  String pitch = "0.00";
  bool isConnected = false;

  // Data for graphs
  List<FlSpot> rollData = [];
  List<FlSpot> pitchData = [];
  double timeCounter = 0;
  static const int maxDataPoints = 50; // Show last 50 points

  // Calibration variables
  bool isCalibrating = false;
  List<double> calibrationRollData = [];
  List<double> calibrationPitchData = [];
  double calibratedRoll = 0.0;
  double calibratedPitch = 0.0;
  bool isCalibrated = false;
  int calibrationCountdown = 0;
  Timer? calibrationTimer;

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  Future<void> requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
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
    } catch (e) {
      setState(() {
        status = "Connection failed ❌";
      });
      return;
    }

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

                double rollValue = double.tryParse(parts[0]) ?? 0.0;
                double pitchValue = double.tryParse(parts[1]) ?? 0.0;

                // If calibrating, collect data
                if (isCalibrating) {
                  calibrationRollData.add(rollValue);
                  calibrationPitchData.add(pitchValue);
                }

                setState(() {
                  roll = parts[0];
                  pitch = parts[1];

                  // Add new data points
                  rollData.add(FlSpot(timeCounter, rollValue));
                  pitchData.add(FlSpot(timeCounter, pitchValue));

                  // Keep only last maxDataPoints
                  if (rollData.length > maxDataPoints) {
                    rollData.removeAt(0);
                  }
                  if (pitchData.length > maxDataPoints) {
                    pitchData.removeAt(0);
                  }

                  timeCounter += 1;
                });
              }
            });

            setState(() {
              status = "Connected ✅";
              isConnected = true;
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

  Future<void> disconnect() async {
    await notifySub?.cancel();
    await device?.disconnect();
    
    setState(() {
      status = "Disconnected";
      isConnected = false;
      roll = "0.00";
      pitch = "0.00";
      device = null;
      characteristic = null;
      notifySub = null;
      rollData.clear();
      pitchData.clear();
      timeCounter = 0;
    });
  }

  void toggleConnection() {
    if (isConnected) {
      disconnect();
    } else {
      startScan();
    }
  }

  void startCalibration() {
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please connect to device first!")),
      );
      return;
    }

    setState(() {
      isCalibrating = true;
      calibrationRollData.clear();
      calibrationPitchData.clear();
      calibrationCountdown = 5;
    });

    // Countdown timer
    calibrationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        calibrationCountdown--;
      });

      if (calibrationCountdown <= 0) {
        timer.cancel();
        finishCalibration();
      }
    });
  }

  void finishCalibration() {
    if (calibrationRollData.isEmpty || calibrationPitchData.isEmpty) {
      setState(() {
        isCalibrating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Calibration failed - no data received")),
      );
      return;
    }

    // Calculate averages
    double sumRoll = calibrationRollData.reduce((a, b) => a + b);
    double sumPitch = calibrationPitchData.reduce((a, b) => a + b);

    setState(() {
      calibratedRoll = sumRoll / calibrationRollData.length;
      calibratedPitch = sumPitch / calibrationPitchData.length;
      isCalibrated = true;
      isCalibrating = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Calibration complete!\nSamples: ${calibrationRollData.length}"),
        backgroundColor: Colors.green,
      ),
    );

    print("Calibrated Roll: $calibratedRoll");
    print("Calibrated Pitch: $calibratedPitch");
    print("Total samples collected: ${calibrationRollData.length}");
  }

  @override
  void dispose() {
    calibrationTimer?.cancel();
    notifySub?.cancel();
    device?.disconnect();
    super.dispose();
  }

  Widget buildGraph(String title, List<FlSpot> data, Color lineColor) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: data.isEmpty
                ? const Center(child: Text("No data yet"))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: 45,
                        verticalInterval: 10,
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: 45,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      minX: data.first.x,
                      maxX: data.last.x,
                      minY: -180,
                      maxY: 180,
                      lineBarsData: [
                        LineChartBarData(
                          spots: data,
                          isCurved: true,
                          color: lineColor,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: lineColor.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Pithoo")),

      body: SingleChildScrollView(
        child: Column(
          children: [

            const SizedBox(height: 20),

            Text(status, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),

            // Connect/Disconnect Button
            ElevatedButton(
              onPressed: toggleConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected ? Colors.red : Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: Text(
                isConnected ? "Disconnect" : "Connect",
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),

            const SizedBox(height: 15),

            // Calibrate Button
            ElevatedButton(
              onPressed: isCalibrating ? null : startCalibration,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                disabledBackgroundColor: Colors.grey,
              ),
              child: Text(
                isCalibrating ? "Calibrating... $calibrationCountdown" : "Calibrate",
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),

            const SizedBox(height: 30),

            // Current Values Display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    const Text("Roll", style: TextStyle(fontSize: 16)),
                    Text(
                      roll,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text("Pitch", style: TextStyle(fontSize: 16)),
                    Text(
                      pitch,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Calibrated Values Display
            if (isCalibrated)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Calibrated Values",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Text("Roll", style: TextStyle(fontSize: 14)),
                            Text(
                              calibratedRoll.toStringAsFixed(2),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text("Pitch", style: TextStyle(fontSize: 14)),
                            Text(
                              calibratedPitch.toStringAsFixed(2),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 30),

            // Graphs
            buildGraph("Roll (°)", rollData, Colors.blue),
            const SizedBox(height: 20),
            buildGraph("Pitch (°)", pitchData, Colors.orange),
            const SizedBox(height: 20),

          ],
        ),
      ),
    );
  }
}
