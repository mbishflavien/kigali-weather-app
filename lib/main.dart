import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'weather.dart';

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue),
      home: const WeatherScreen(),
    );
  }
}

IconData iconFor(int code) {
  if (code == 0) return Icons.wb_sunny;
  if (code <= 3) return Icons.cloud;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 95) return Icons.thunderstorm;
  if (code >= 51) return Icons.water_drop;
  return Icons.help_outline;
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  City city = cities.first;
  Weather? weather;
  bool loading = true;
  bool offline = false;
  String? error;

  @override
  void initState() {
    super.initState();
    start();
  }

  // Step 7: open on the city saved last time (Kigali the first time).
  Future<void> start() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('city');
    final found = cities.where((c) => c.name == savedName);
    if (found.isNotEmpty) {
      setState(() {
        city = found.first;
      });
    }
    await load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final result = await fetchWeather(city);
      // Step 8: keep the last weather of this city.
      await prefs.setString('weather_${city.name}', jsonEncode(result.toJson()));
      setState(() {
        weather = result;
        loading = false;
        offline = false;
        error = null;
      });
    } catch (e) {
      final saved = prefs.getString('weather_${city.name}');
      setState(() {
        loading = false;
        if (saved != null) {
          weather = Weather.fromJson(jsonDecode(saved) as Map<String, dynamic>);
          offline = true;
          error = null;
        } else {
          error = 'Could not load the weather. Check your internet connection.';
        }
      });
    }
  }

  void retry() {
    setState(() {
      loading = true;
      error = null;
    });
    load();
  }

  Future<void> choose(City newCity) async {
    setState(() {
      city = newCity;
      loading = true;
      offline = false;
      error = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('city', newCity.name);
    load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${city.name} Weather')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final c in cities)
                  ChoiceChip(
                    label: Text(c.name),
                    selected: c.name == city.name,
                    onSelected: (_) => choose(c),
                  ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off, size: 48),
                        const SizedBox(height: 12),
                        Text(error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: retry, child: const Text('Retry')),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (offline)
                          Container(
                            color: Colors.yellow,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Offline: showing the weather saved at ${weather!.time.substring(11)}',
                            ),
                          ),
                        WeatherCard(weather: weather!),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key, required this.weather});

  final Weather weather;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(iconFor(weather.code), size: 72),
            Text(
              '${weather.temperature.round()}°C',
              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
            ),
            Text(describe(weather.code), style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 16),
            Text('Humidity: ${weather.humidity}%'),
            Text('Wind: ${weather.wind} km/h'),
            const SizedBox(height: 8),
            Text('Updated at ${weather.time.substring(11)}'),
          ],
        ),
      ),
    );
  }
}
