// lib/main.dart
import 'package:flutter/material.dart' hide Path;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path_lib;
import 'dart:math' as math;

void main() {
  WidgetsFlutterBinding.ensureInitialized();  
  runApp(const AquariumApp());
}

class AquariumApp extends StatelessWidget {
  const AquariumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virtual Aquarium',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AquariumScreen(),
    );
  }
}

class Fish {
  Offset position;
  Color color;
  double speed;
  double direction;
  
  Fish({
    required this.color,
    required this.speed,
    Offset? initialPosition,
  }) : position = initialPosition ?? const Offset(150, 150),
       direction = math.Random().nextDouble() * 2 * math.pi;
}

class AquariumScreen extends StatefulWidget {
  const AquariumScreen({super.key});

  @override
  State<AquariumScreen> createState() => _AquariumScreenState();
}

class _AquariumScreenState extends State<AquariumScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<Fish> fishList = [];
  Color selectedColor = Colors.blue;
  double selectedSpeed = 2.0;
  late Database database;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_updateFishPositions);
    _controller.repeat();
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    database = await openDatabase(
      path_lib.join(await getDatabasesPath(), 'aquarium.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE settings(id INTEGER PRIMARY KEY, fishCount INTEGER, speed REAL, color INTEGER)',
        );
      },
      version: 1,
    );
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final List<Map<String, dynamic>> settings = await database.query('settings');
    if (settings.isNotEmpty) {
      setState(() {
        selectedSpeed = settings.first['speed'];
        selectedColor = Color(settings.first['color']);
        final fishCount = settings.first['fishCount'];
        for (var i = 0; i < fishCount; i++) {
          _addFish();
        }
      });
    }
  }

  Future<void> _saveSettings() async {
    await database.delete('settings');
    await database.insert(
      'settings',
      {
        'fishCount': fishList.length,
        'speed': selectedSpeed,
        'color': selectedColor.value,
      },
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully!')),
      );
    }
  }

  void _updateFishPositions() {
    if (mounted) {
      setState(() {
        for (var fish in fishList) {
          double dx = math.cos(fish.direction) * fish.speed;
          double dy = math.sin(fish.direction) * fish.speed;
          
          double newX = fish.position.dx + dx;
          double newY = fish.position.dy + dy;
          
         
          if (newX < 0 || newX > 280) {
            fish.direction = math.pi - fish.direction;
          }
          if (newY < 0 || newY > 280) {
            fish.direction = -fish.direction;
          }
          
          
          newX = newX.clamp(0, 280);
          newY = newY.clamp(0, 280);
          
          fish.position = Offset(newX, newY);
        }
      });
    }
  }

  void _addFish() {
    if (fishList.length < 10) {
      setState(() {
        fishList.add(Fish(
          color: selectedColor,
          speed: selectedSpeed,
          initialPosition: Offset(
            150 + math.Random().nextDouble() * 100 - 50,
            150 + math.Random().nextDouble() * 100 - 50,
          ),
        ));
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum number of fish reached!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Virtual Aquarium'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 300,
                height: 300,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.lightBlue[100],
                  border: Border.all(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    for (var fish in fishList)
                      Positioned(
                        left: fish.position.dx,
                        top: fish.position.dy,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: fish.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _addFish,
                          child: const Text('Add Fish'),
                        ),
                        ElevatedButton(
                          onPressed: _saveSettings,
                          child: const Text('Save Settings'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Speed: '),
                        Expanded(
                          child: Slider(
                            value: selectedSpeed,
                            min: 0.5,
                            max: 5.0,
                            onChanged: (value) {
                              setState(() {
                                selectedSpeed = value;
                                for (var fish in fishList) {
                                  fish.speed = value;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Color: '),
                        Expanded(
                          child: DropdownButton<Color>(
                            value: selectedColor,
                            items: [
                              Colors.blue,
                              Colors.red,
                              Colors.green,
                              Colors.yellow,
                              Colors.purple,
                            ].map((Color color) {
                              return DropdownMenuItem<Color>(
                                value: color,
                                child: Container(
                                  width: 50,
                                  height: 20,
                                  color: color,
                                ),
                              );
                            }).toList(),
                            onChanged: (Color? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  selectedColor = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    database.close();
    super.dispose();
  }
}