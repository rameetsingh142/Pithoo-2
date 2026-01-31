import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// Good Posture Calibration Screen
class GoodPostureCalibrationScreen extends StatefulWidget {
  final BluetoothCharacteristic characteristic;
  final Function(double, double) onCalibrationComplete;
  final Function(double, double) onBadPostureComplete;

  const GoodPostureCalibrationScreen({
    super.key,
    required this.characteristic,
    required this.onCalibrationComplete,
    required this.onBadPostureComplete,
  });

  @override
  State<GoodPostureCalibrationScreen> createState() => _GoodPostureCalibrationScreenState();
}

class _GoodPostureCalibrationScreenState extends State<GoodPostureCalibrationScreen> {
  bool isCalibrating = false;
  int countdown = 0;
  bool isComplete = false;
  List<double> rollData = [];
  List<double> pitchData = [];
  StreamSubscription<List<int>>? dataSub;
  Timer? countdownTimer;

  double calibratedRoll = 0.0;
  double calibratedPitch = 0.0;

  @override
  void initState() {
    super.initState();
    dataSub = widget.characteristic.value.listen((value) {
      String data = String.fromCharCodes(value).trim();
      List<String> parts = data.split(",");

      if (parts.length == 2 && isCalibrating) {
        double rollValue = double.tryParse(parts[0]) ?? 0.0;
        double pitchValue = double.tryParse(parts[1]) ?? 0.0;
        rollData.add(rollValue);
        pitchData.add(pitchValue);
      }
    });
  }

  void startCalibration() {
    setState(() {
      isCalibrating = true;
      countdown = 5;
      rollData.clear();
      pitchData.clear();
    });

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        countdown--;
      });

      if (countdown <= 0) {
        timer.cancel();
        finishCalibration();
      }
    });
  }

  void finishCalibration() {
    if (rollData.isEmpty || pitchData.isEmpty) {
      setState(() {
        isCalibrating = false;
      });
      return;
    }

    double sumRoll = rollData.reduce((a, b) => a + b);
    double sumPitch = pitchData.reduce((a, b) => a + b);

    calibratedRoll = sumRoll / rollData.length;
    calibratedPitch = sumPitch / pitchData.length;

    widget.onCalibrationComplete(calibratedRoll, calibratedPitch);

    setState(() {
      isCalibrating = false;
      isComplete = true;
    });
  }

  void goToNextScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => BadPostureCalibrationScreen(
          characteristic: widget.characteristic,
          onCalibrationComplete: widget.onBadPostureComplete,
          goodPostureRoll: calibratedRoll,
          goodPosturePitch: calibratedPitch,
        ),
      ),
    );
  }

  @override
  void dispose() {
    dataSub?.cancel();
    countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Good Posture Calibration"),
        backgroundColor: Colors.green,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  "Step 1 of 2",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 20),

                Container(
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/images/g.png',  // Add your image to assets folder
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                
                // Hide stick figure visualization
                // Container(
                //   height: 200,
                //   width: 200,
                //   decoration: BoxDecoration(
                //     color: Colors.green.shade50,
                //     borderRadius: BorderRadius.circular(20),
                //     border: Border.all(color: Colors.green, width: 2),
                //   ),
                //   child: CustomPaint(
                //     painter: GoodPosturePainter(),
                //   ),
                // ),
                
                SizedBox.shrink(),

                const SizedBox(height: 30),

                const Text(
                  "Good Posture Instructions:",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),

                _buildInstruction("✓ Sit up straight"),
                _buildInstruction("✓ Keep your back against the chair"),
                _buildInstruction("✓ Shoulders relaxed and level"),
                _buildInstruction("✓ Look straight ahead"),
                _buildInstruction("✓ Feet flat on the floor"),

                const SizedBox(height: 40),

                if (isCalibrating)
                  Column(
                    children: [
                      Text(
                        "Calibrating in $countdown",
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      const SizedBox(height: 10),
                      CircularProgressIndicator(
                        value: (5 - countdown) / 5,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ],
                  )
                else if (isComplete)
                  Column(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 60),
                      const SizedBox(height: 10),
                      const Text(
                        "Good Posture Calibrated!",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: goToNextScreen,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                        ),
                        child: const Text(
                          "Next",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  )
                else
                  ElevatedButton(
                    onPressed: startCalibration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    ),
                    child: const Text(
                      "Start Calibration",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstruction(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Text(
            text,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// Bad Posture Calibration Screen
class BadPostureCalibrationScreen extends StatefulWidget {
  final BluetoothCharacteristic characteristic;
  final Function(double, double) onCalibrationComplete;
  final double goodPostureRoll;
  final double goodPosturePitch;

  const BadPostureCalibrationScreen({
    super.key,
    required this.characteristic,
    required this.onCalibrationComplete,
    required this.goodPostureRoll,
    required this.goodPosturePitch,
  });

  @override
  State<BadPostureCalibrationScreen> createState() => _BadPostureCalibrationScreenState();
}

class _BadPostureCalibrationScreenState extends State<BadPostureCalibrationScreen> {
  bool isCalibrating = false;
  int countdown = 0;
  bool isComplete = false;
  List<double> rollData = [];
  List<double> pitchData = [];
  StreamSubscription<List<int>>? dataSub;
  Timer? countdownTimer;

  double calibratedRoll = 0.0;
  double calibratedPitch = 0.0;

  @override
  void initState() {
    super.initState();
    dataSub = widget.characteristic.value.listen((value) {
      String data = String.fromCharCodes(value).trim();
      List<String> parts = data.split(",");

      if (parts.length == 2 && isCalibrating) {
        double rollValue = double.tryParse(parts[0]) ?? 0.0;
        double pitchValue = double.tryParse(parts[1]) ?? 0.0;
        rollData.add(rollValue);
        pitchData.add(pitchValue);
      }
    });
  }

  void startCalibration() {
    setState(() {
      isCalibrating = true;
      countdown = 5;
      rollData.clear();
      pitchData.clear();
    });

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        countdown--;
      });

      if (countdown <= 0) {
        timer.cancel();
        finishCalibration();
      }
    });
  }

  void finishCalibration() {
    if (rollData.isEmpty || pitchData.isEmpty) {
      setState(() {
        isCalibrating = false;
      });
      return;
    }

    double sumRoll = rollData.reduce((a, b) => a + b);
    double sumPitch = pitchData.reduce((a, b) => a + b);

    calibratedRoll = sumRoll / rollData.length;
    calibratedPitch = sumPitch / pitchData.length;

    widget.onCalibrationComplete(calibratedRoll, calibratedPitch);

    setState(() {
      isCalibrating = false;
      isComplete = true;
    });
  }

  void goToCompleteScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CalibrationCompleteScreen(
          goodPostureRoll: widget.goodPostureRoll,
          goodPosturePitch: widget.goodPosturePitch,
          badPostureRoll: calibratedRoll,
          badPosturePitch: calibratedPitch,
        ),
      ),
    );
  }

  @override
  void dispose() {
    dataSub?.cancel();
    countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bad Posture Calibration"),
        backgroundColor: Colors.red,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  "Step 2 of 2",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                
        
                Container(
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/images/b.png', // Add your image to assets folder
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                // Hide stick figure visualization
                // Container(
                //   height: 200,
                //   width: 200,
                //   decoration: BoxDecoration(
                //     color: Colors.red.shade50,
                //     borderRadius: BorderRadius.circular(20),
                //     border: Border.all(color: Colors.red, width: 2),
                //   ),
                //   child: CustomPaint(
                //     painter: BadPosturePainter(),
                //   ),
                // ),

                SizedBox.shrink(),

                const SizedBox(height: 30),

                const Text(
                  "Bad Posture Instructions:",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),

                _buildInstruction("✗ Slouch forward naturally"),
                _buildInstruction("✗ Round your shoulders"),
                _buildInstruction("✗ Look down slightly"),
                _buildInstruction("✗ Lean back away from desk"),
                _buildInstruction("✗ Sit as you normally do when tired"),

                const SizedBox(height: 40),

                if (isCalibrating)
                  Column(
                    children: [
                      Text(
                        "Calibrating in $countdown",
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      const SizedBox(height: 10),
                      CircularProgressIndicator(
                        value: (5 - countdown) / 5,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                    ],
                  )
                else if (isComplete)
                  Column(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.red, size: 60),
                      const SizedBox(height: 10),
                      const Text(
                        "Bad Posture Calibrated!",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: goToCompleteScreen,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                        ),
                        child: const Text(
                          "Finish",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  )
                else
                  ElevatedButton(
                    onPressed: startCalibration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    ),
                    child: const Text(
                      "Start Calibration",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstruction(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Text(
            text,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// Calibration Complete Screen
class CalibrationCompleteScreen extends StatelessWidget {
  final double goodPostureRoll;
  final double goodPosturePitch;
  final double badPostureRoll;
  final double badPosturePitch;

  const CalibrationCompleteScreen({
    super.key,
    required this.goodPostureRoll,
    required this.goodPosturePitch,
    required this.badPostureRoll,
    required this.badPosturePitch,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Calibration Complete"),
        backgroundColor: Colors.blue,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 100,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Calibration Successful!",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Your posture profiles have been saved",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),

                // Good Posture Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Good Posture ✅",
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
                                goodPostureRoll.toStringAsFixed(2),
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
                                goodPosturePitch.toStringAsFixed(2),
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

                const SizedBox(height: 20),

                // Bad Posture Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Bad Posture ⚠️",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
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
                                badPostureRoll.toStringAsFixed(2),
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
                                badPosturePitch.toStringAsFixed(2),
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

                const SizedBox(height: 60),

                ElevatedButton(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 15),
                  ),
                  child: const Text(
                    "Back to Home",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom Painter for Good Posture
class GoodPosturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.green.shade200
      ..style = PaintingStyle.fill;

    // Head
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.2), 20, fillPaint);
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.2), 20, paint);

    // Straight back
    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.25),
      Offset(size.width / 2, size.height * 0.7),
      paint,
    );

    // Shoulders (level)
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.35),
      Offset(size.width * 0.7, size.height * 0.35),
      paint,
    );

    // Chair back (support)
    canvas.drawLine(
      Offset(size.width * 0.45, size.height * 0.35),
      Offset(size.width * 0.45, size.height * 0.7),
      Paint()
        ..color = Colors.grey
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom Painter for Bad Posture
class BadPosturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.red.shade200
      ..style = PaintingStyle.fill;

    // Head (tilted forward)
    canvas.drawCircle(Offset(size.width / 2 + 15, size.height * 0.2), 20, fillPaint);
    canvas.drawCircle(Offset(size.width / 2 + 15, size.height * 0.2), 20, paint);

    // Curved/slouched back
    final path = Path();
    path.moveTo(size.width / 2 + 10, size.height * 0.25);
    path.quadraticBezierTo(
      size.width / 2 + 20,
      size.height * 0.5,
      size.width / 2,
      size.height * 0.7,
    );
    canvas.drawPath(path, paint);

    // Shoulders (uneven/rounded)
    canvas.drawLine(
      Offset(size.width * 0.35, size.height * 0.4),
      Offset(size.width * 0.65, size.height * 0.35),
      paint,
    );

    // Chair back (gap showing no support)
    canvas.drawLine(
      Offset(size.width * 0.35, size.height * 0.35),
      Offset(size.width * 0.35, size.height * 0.7),
      Paint()
        ..color = Colors.grey
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
