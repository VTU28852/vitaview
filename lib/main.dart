import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  runApp(const VitaViewApp());
}

// ================= DATABASE =================

class DatabaseHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await openDatabase(
      'vitaview.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE health_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            height REAL,
            weight REAL,
            age INTEGER,
            sleep REAL,
            water REAL,
            activity TEXT
          )
        ''');
      },
    );

    return _database!;
  }

  static Future<void> saveHealthData({
    required double height,
    required double weight,
    required int age,
    required double sleep,
    required double water,
    required String activity,
  }) async {
    final db = await database;

    await db.insert(
      'health_data',
      {
        'height': height,
        'weight': weight,
        'age': age,
        'sleep': sleep,
        'water': water,
        'activity': activity,
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getHealthData() async {
    final db = await database;

    return await db.query(
      'health_data',
      orderBy: 'id DESC',
    );
  }
}

// ================= WELLNESS SCORE =================

int calculateWellnessScore({
  required double bmi,
  required double sleep,
  required double water,
  required String activity,
}) {
  int bmiScore = 0;
  int sleepScore = 0;
  int waterScore = 0;
  int activityScore = 0;

  // BMI - 25 points
  if (bmi >= 18.5 && bmi <= 24.9) {
    bmiScore = 25;
  } else if ((bmi >= 17 && bmi < 18.5) ||
      (bmi > 24.9 && bmi <= 29.9)) {
    bmiScore = 18;
  } else {
    bmiScore = 10;
  }

  // Sleep - 25 points
  if (sleep >= 7 && sleep <= 9) {
    sleepScore = 25;
  } else if ((sleep >= 6 && sleep < 7) ||
      (sleep > 9 && sleep <= 10)) {
    sleepScore = 18;
  } else {
    sleepScore = 10;
  }

  // Water - 25 points
  if (water >= 2) {
    waterScore = 25;
  } else if (water >= 1.5) {
    waterScore = 18;
  } else {
    waterScore = 10;
  }

  // Activity - 25 points
  if (activity == 'High') {
    activityScore = 25;
  } else if (activity == 'Moderate') {
    activityScore = 18;
  } else {
    activityScore = 10;
  }

  return bmiScore + sleepScore + waterScore + activityScore;
}

// ================= APP =================

class VitaViewApp extends StatelessWidget {
  const VitaViewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VitaView',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const LoginScreen(),
    );
  }
}

// ================= LOGIN =================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController nameController = TextEditingController();

  void continueToDashboard() {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name'),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DashboardScreen(name: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VitaView'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.health_and_safety,
              size: 80,
              color: Colors.teal,
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome to VitaView',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your offline visual health companion',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Enter your name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: continueToDashboard,
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= DASHBOARD =================

class DashboardScreen extends StatefulWidget {
  final String name;

  const DashboardScreen({
    super.key,
    required this.name,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double? latestBMI;
  int? latestWellnessScore;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadLatestHealthData();
  }

  Future<void> loadLatestHealthData() async {
    final records = await DatabaseHelper.getHealthData();

    if (records.isEmpty) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });
      return;
    }

    final latest = records.first;

    final height = (latest['height'] as num).toDouble();
    final weight = (latest['weight'] as num).toDouble();
    final sleep = (latest['sleep'] as num).toDouble();
    final water = (latest['water'] as num).toDouble();
    final activity = latest['activity'] as String;

    final heightInMeters = height / 100;
    final bmi = weight / (heightInMeters * heightInMeters);

    final score = calculateWellnessScore(
      bmi: bmi,
      sleep: sleep,
      water: water,
      activity: activity,
    );

    if (!mounted) return;

    setState(() {
      latestBMI = bmi;
      latestWellnessScore = score;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VitaView Dashboard'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: loadLatestHealthData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Hello, ${widget.name}!',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            // WELLNESS SCORE CARD
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: loading
                    ? const Center(
                  child: CircularProgressIndicator(),
                )
                    : latestWellnessScore == null
                    ? const Column(
                  children: [
                    Icon(
                      Icons.favorite,
                      size: 50,
                      color: Colors.teal,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Wellness Score',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Enter health data to calculate',
                    ),
                  ],
                )
                    : Column(
                  children: [
                    const Icon(
                      Icons.favorite,
                      size: 50,
                      color: Colors.teal,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Wellness Score',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${latestWellnessScore!} / 100',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // BMI CARD
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: latestBMI == null
                    ? const Column(
                  children: [
                    Icon(
                      Icons.monitor_heart,
                      size: 50,
                      color: Colors.teal,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'BMI',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Enter health data to calculate',
                    ),
                  ],
                )
                    : Column(
                  children: [
                    const Icon(
                      Icons.monitor_heart,
                      size: 50,
                      color: Colors.teal,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'BMI',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      latestBMI!.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3D BODY
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.accessibility_new,
                  color: Colors.teal,
                  size: 40,
                ),
                title: const Text(
                  '3D Body Visualization',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text('Coming soon'),
              ),
            ),

            const SizedBox(height: 12),

            // STEPS
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.directions_walk,
                  color: Colors.teal,
                  size: 40,
                ),
                title: const Text(
                  'Steps Today',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'Sensor integration coming soon',
                ),
              ),
            ),

            const SizedBox(height: 12),

            // OCR
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.upload_file,
                  color: Colors.teal,
                  size: 40,
                ),
                title: const Text(
                  'Upload Medical Report',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'OCR feature coming soon',
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ENTER HEALTH DATA
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                      const HealthInputScreen(),
                    ),
                  );

                  loadLatestHealthData();
                },
                icon: const Icon(Icons.add),
                label: const Text('Enter Health Data'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= HEALTH INPUT =================

class HealthInputScreen extends StatefulWidget {
  const HealthInputScreen({super.key});

  @override
  State<HealthInputScreen> createState() =>
      _HealthInputScreenState();
}

class _HealthInputScreenState extends State<HealthInputScreen> {
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final ageController = TextEditingController();
  final sleepController = TextEditingController();
  final waterController = TextEditingController();

  String activity = 'Moderate';

  double? calculatedBMI;
  int? wellnessScore;

  Future<void> saveData() async {
    final height = double.tryParse(heightController.text);
    final weight = double.tryParse(weightController.text);
    final age = int.tryParse(ageController.text);
    final sleep = double.tryParse(sleepController.text);
    final water = double.tryParse(waterController.text);

    if (height == null ||
        weight == null ||
        age == null ||
        sleep == null ||
        water == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid values in all fields'),
        ),
      );
      return;
    }

    if (height <= 0 || weight <= 0 || age <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter positive values'),
        ),
      );
      return;
    }

    final heightInMeters = height / 100;
    final bmi = weight / (heightInMeters * heightInMeters);

    final score = calculateWellnessScore(
      bmi: bmi,
      sleep: sleep,
      water: water,
      activity: activity,
    );

    try {
      await DatabaseHelper.saveHealthData(
        height: height,
        weight: weight,
        age: age,
        sleep: sleep,
        water: water,
        activity: activity,
      );

      setState(() {
        calculatedBMI = bmi;
        wellnessScore = score;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Health data saved locally'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving data: $e'),
        ),
      );
    }
  }

  Future<void> viewSavedData() async {
    try {
      final records = await DatabaseHelper.getHealthData();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Saved Health Data'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: records.isEmpty
                  ? const Center(
                child: Text('No saved data found'),
              )
                  : ListView.builder(
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];

                  final height =
                  (record['height'] as num).toDouble();
                  final weight =
                  (record['weight'] as num).toDouble();
                  final sleep =
                  (record['sleep'] as num).toDouble();
                  final water =
                  (record['water'] as num).toDouble();
                  final activity =
                  record['activity'] as String;

                  final heightInMeters = height / 100;
                  final bmi =
                      weight / (heightInMeters * heightInMeters);

                  final score = calculateWellnessScore(
                    bmi: bmi,
                    sleep: sleep,
                    water: water,
                    activity: activity,
                  );

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Record ${index + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Height: $height cm'),
                          Text('Weight: $weight kg'),
                          Text('Age: ${record['age']}'),
                          Text('Sleep: $sleep hours'),
                          Text('Water: $water L'),
                          Text('Activity: $activity'),
                          Text(
                            'BMI: ${bmi.toStringAsFixed(2)}',
                          ),
                          Text(
                            'Wellness Score: $score / 100',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reading data: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Input'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: heightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Height (cm)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Age',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: sleepController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Sleep Hours',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: waterController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Water Intake (litres)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: activity,
              decoration: const InputDecoration(
                labelText: 'Daily Activity',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Low',
                  child: Text('Low'),
                ),
                DropdownMenuItem(
                  value: 'Moderate',
                  child: Text('Moderate'),
                ),
                DropdownMenuItem(
                  value: 'High',
                  child: Text('High'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  activity = value ?? 'Moderate';
                });
              },
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: saveData,
                icon: const Icon(Icons.save),
                label: const Text('Save Health Data'),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: viewSavedData,
                icon: const Icon(Icons.history),
                label: const Text('View Saved Data'),
              ),
            ),

            const SizedBox(height: 20),

            if (calculatedBMI != null)
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.monitor_heart,
                    color: Colors.teal,
                  ),
                  title: const Text('Your BMI'),
                  subtitle: Text(
                    calculatedBMI!.toStringAsFixed(2),
                  ),
                ),
              ),

            if (wellnessScore != null)
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.favorite,
                    color: Colors.teal,
                  ),
                  title: const Text('Wellness Score'),
                  subtitle: Text(
                    '$wellnessScore / 100',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}