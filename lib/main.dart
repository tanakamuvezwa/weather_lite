import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const WeatherLiteApp());
}

class WeatherLiteApp extends StatelessWidget {
  const WeatherLiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Weather Lite',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const WeatherHomePage(),
    );
  }
}

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  final TextEditingController _cityController = TextEditingController(text: 'London');
  String? _statusMessage;
  String? _temperatureText;
  bool _isLoading = false;

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _fetchWeather() async {
    final String cityName = _cityController.text.trim();
    if (cityName.isEmpty) {
      setState(() {
        _statusMessage = 'Enter a city name';
        _temperatureText = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _temperatureText = null;
    });

    try {
      // 1) Geocode city -> latitude/longitude (Open-Meteo geocoding, no API key)
      final Uri geocodeUrl = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=' + Uri.encodeComponent(cityName) + '&count=1',
      );
      final http.Response geoResp = await http.get(geocodeUrl);
      if (geoResp.statusCode != 200) {
        throw Exception('Geocoding failed: ' + geoResp.statusCode.toString());
      }
      final Map<String, dynamic> geoData = jsonDecode(geoResp.body) as Map<String, dynamic>;
      final List<dynamic>? results = geoData['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        setState(() {
          _statusMessage = 'City not found';
        });
        return;
      }
      final Map<String, dynamic> place = results.first as Map<String, dynamic>;
      final double latitude = (place['latitude'] as num).toDouble();
      final double longitude = (place['longitude'] as num).toDouble();

      // 2) Fetch current weather
      final Uri weatherUrl = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=' + latitude.toString() + '&longitude=' + longitude.toString() + '&current_weather=true',
      );
      final http.Response weatherResp = await http.get(weatherUrl);
      if (weatherResp.statusCode != 200) {
        throw Exception('Weather fetch failed: ' + weatherResp.statusCode.toString());
      }
      final Map<String, dynamic> weatherData = jsonDecode(weatherResp.body) as Map<String, dynamic>;
      final Map<String, dynamic>? current = weatherData['current_weather'] as Map<String, dynamic>?;
      if (current == null) {
        setState(() {
          _statusMessage = 'No current weather data';
        });
        return;
      }

      final double temperatureC = (current['temperature'] as num).toDouble();
      final String windKph = ((current['windspeed'] as num).toDouble()).toStringAsFixed(0);

      setState(() {
        _temperatureText = temperatureC.toStringAsFixed(1) + '°C, Wind ' + windKph + ' km/h';
        _statusMessage = 'in ' + (place['name']?.toString() ?? cityName);
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ' + e.toString();
        _temperatureText = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Lite'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _cityController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _fetchWeather(),
              decoration: const InputDecoration(
                labelText: 'City',
                hintText: 'e.g. London',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _fetchWeather,
              icon: const Icon(Icons.cloud_outlined),
              label: const Text('Get Weather'),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),
            if (!_isLoading && _temperatureText != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _temperatureText!,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (_statusMessage != null)
                    Text(
                      _statusMessage!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ),
            if (!_isLoading && _temperatureText == null && _statusMessage != null)
              Text(
                _statusMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
