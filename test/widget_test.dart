import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cottonguard/constants/canonical_classes.dart';
import 'package:cottonguard/models/prediction_result.dart';
import 'package:cottonguard/models/server_health.dart';
import 'package:cottonguard/models/scan_record.dart';
import 'package:cottonguard/services/storage_service.dart';
import 'package:cottonguard/controllers/history_controller.dart';
import 'package:cottonguard/widgets/status_badge.dart';
import 'package:cottonguard/widgets/custom_button.dart';
import 'package:cottonguard/widgets/glass_card.dart';
import 'package:cottonguard/models/user_profile.dart';
import 'package:cottonguard/models/weather_data.dart';
import 'package:cottonguard/data/indian_locations.dart';
import 'package:cottonguard/services/indian_time_service.dart';
import 'package:cottonguard/screens/main_navigation_shell.dart';
import 'package:cottonguard/screens/disease_library/disease_library_screen.dart';
import 'package:flutter/services.dart';
import 'package:cottonguard/services/google_auth_service.dart';
import 'package:cottonguard/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cotton Guard - Unit & Domain Tests', () {
    test('Canonical Classes list has exactly 7 conditions without typos', () {
      expect(CanonicalClasses.all.length, 7);
      expect(CanonicalClasses.all.contains('Bacterial Blight'), isTrue);
      expect(CanonicalClasses.all.contains('Cotton Leaf Curl Virus'), isTrue);
      expect(CanonicalClasses.all.contains('Healthy Leaf'), isTrue);
      expect(CanonicalClasses.all.contains('Herbicide Growth Damage'), isTrue);
      expect(CanonicalClasses.all.contains('Leaf Hopper / Jassids'), isTrue);
      expect(CanonicalClasses.all.contains('Leaf Reddening'), isTrue);
      expect(CanonicalClasses.all.contains('Leaf Variegation'), isTrue);
    });

    test('All canonical classes have verified asset paths and details', () {
      for (final cls in CanonicalClasses.all) {
        final details = CanonicalClasses.diseaseDetails[cls];
        expect(details, isNotNull);
        expect(details!['scientificName'], isNotNull);
        expect(details['symptoms'], isNotEmpty);
        expect(details['treatment'], isNotEmpty);
        expect(details['prevention'], isNotEmpty);

        final sampleAssets = CanonicalClasses.getSampleAssetImages(cls);
        expect(sampleAssets.length, 4);
      }
    });

    test('PredictionResult parses JSON response correctly', () {
      final json = {
        'success': true,
        'predicted_class': 'Bacterial Blight',
        'confidence': 0.9842,
        'is_low_confidence': false,
        'severity': 'Moderate to High',
        'severity_level': 3,
        'is_healthy': false,
        'scientific_name': 'Xanthomonas citri pv. malvacearum',
        'summary': 'Water-soaked angular leaf spots',
        'symptoms': ['Angular spots', 'Vein blight'],
        'treatment': ['Copper Oxychloride spray'],
        'prevention': ['Seed treatment'],
        'advisory': ['Copper Oxychloride spray', 'Seed treatment'],
        'favorable_conditions': 'High humidity',
        'latency_ms': 32.5,
        'model_name': 'MobileNetV2',
        'engine': 'ONNX Runtime',
      };

      final result = PredictionResult.fromJson(json);
      expect(result.predictedClass, 'Bacterial Blight');
      expect(result.confidence, 0.9842);
      expect(result.isLowConfidence, isFalse);
      expect(result.severityLevel, 3);
      expect(result.isHealthy, isFalse);
      expect(result.symptoms.length, 2);
    });

    test('ServerHealth handles connected and disconnected states', () {
      final connectedJson = {
        'status': 'CONNECTED',
        'version': '1.0.0',
        'uptime_seconds': 120.5,
        'model_loaded': true,
        'model_name': 'MobileNetV2',
        'inference_engine': 'ONNX Runtime',
        'cotton_validation_ready': true,
        'disease_model_ready': true,
        'supported_classes': CanonicalClasses.all,
        'timestamp': '2026-10-08T18:00:00Z',
      };

      final connected = ServerHealth.fromJson(connectedJson, latencyMs: 25);
      expect(connected.isConnected, isTrue);
      expect(connected.latencyMs, 25);

      final disconnected = ServerHealth.disconnected();
      expect(disconnected.isConnected, isFalse);
      expect(disconnected.status, 'DISCONNECTED');

      final stoppedJson = {
        'status': 'STOPPED',
        'version': '1.0.0',
        'uptime_seconds': 0.0,
        'model_loaded': false,
        'model_name': 'MobileNetV3',
        'inference_engine': 'ONNX Runtime',
        'cotton_validation_ready': true,
        'disease_model_ready': false,
        'supported_classes': CanonicalClasses.all,
        'timestamp': '2026-10-10T18:00:00Z',
      };
      final stopped = ServerHealth.fromJson(stoppedJson);
      expect(stopped.isConnected, isFalse);
      expect(stopped.isStopped, isTrue);
      expect(stopped.isTransitioning, isFalse);
      expect(stopped.status, 'STOPPED');

      final startingJson = Map<String, dynamic>.from(stoppedJson)..['status'] = 'STARTING';
      final starting = ServerHealth.fromJson(startingJson);
      expect(starting.isTransitioning, isTrue);
      expect(starting.isStopped, isFalse);
    });

    test('HistoryController accurately computes statistics', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);
      final history = HistoryController(storage);

      expect(history.totalScans, 0);
      expect(history.healthyPercentage, 0.0);

      // Add healthy scan
      await history.addScan(ScanRecord(
        id: '1',
        timestamp: DateTime.now(),
        imagePath: 'assets/sample.jpg',
        predictedClass: 'Healthy Leaf',
        confidence: 0.95,
        isLowConfidence: false,
        severity: 'None',
        severityLevel: 0,
        isHealthy: true,
        symptoms: [],
        treatment: [],
        prevention: [],
        advisory: [],
      ));

      // Add diseased scan
      await history.addScan(ScanRecord(
        id: '2',
        timestamp: DateTime.now(),
        imagePath: 'assets/sample2.jpg',
        predictedClass: 'Bacterial Blight',
        confidence: 0.92,
        isLowConfidence: false,
        severity: 'Moderate',
        severityLevel: 3,
        isHealthy: false,
        symptoms: [],
        treatment: [],
        prevention: [],
        advisory: [],
      ));

      expect(history.totalScans, 2);
      expect(history.healthyScans, 1);
      expect(history.diseasedScans, 1);
      expect(history.healthyPercentage, 50.0);
      expect(history.diseaseDistribution['Bacterial Blight'], 1);
      expect(history.diseaseDistribution['Healthy Leaf'], 1);
    });
  });

  group('Cotton Guard - Widget Component Tests', () {
    testWidgets('StatusBadge renders server status and severity properly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge.serverStatus('CONNECTED', latencyMs: 35),
                StatusBadge.severity('Critical', 4),
                StatusBadge.confidence(0.88),
              ],
            ),
          ),
        ),
      );

      expect(find.text('AI Online (35ms)'), findsOneWidget);
      expect(find.text('Critical'), findsOneWidget);
      expect(find.text('88.0% Confidence'), findsOneWidget);
    });

    testWidgets('CustomButton renders and triggers callback', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomButton(
              text: 'Scan Leaf',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Scan Leaf'), findsOneWidget);
      await tester.tap(find.text('Scan Leaf'));
      expect(tapped, isTrue);
    });

    testWidgets('GlassCard renders child content', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassCard(
              child: Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('CottonGuardApp boots with splash screen branding', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'cotton_guard_has_seen_onboarding': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      await tester.pumpWidget(CottonGuardApp(storageService: storage));
      await tester.pump();

      expect(find.text('Cotton Guard'), findsOneWidget);
      expect(find.text('Smart Crop Protection & Advisory'), findsOneWidget);

      // Advance clock past splash timer so no pending timers remain
      await tester.pump(const Duration(milliseconds: 3000));
      await tester.pumpAndSettle();
    });
  });

  group('Cotton Guard - Dashboard, Navigation, Profile, Location & Disease Library Refinements', () {
    test('IndianTimeService produces accurate greetings across all IST periods', () {
      // 05:00 - 11:59 IST (07:00 IST is 01:30 UTC)
      final morning = DateTime.utc(2026, 10, 9, 1, 30);
      expect(IndianTimeService.getGreeting(morning), 'Good morning');

      // 12:00 - 16:59 IST (14:00 IST is 08:30 UTC)
      final afternoon = DateTime.utc(2026, 10, 9, 8, 30);
      expect(IndianTimeService.getGreeting(afternoon), 'Good afternoon');

      // 17:00 - 20:59 IST (18:30 IST is 13:00 UTC)
      final evening = DateTime.utc(2026, 10, 9, 13, 0);
      expect(IndianTimeService.getGreeting(evening), 'Good evening');

      // 21:00 - 04:59 IST (22:30 IST is 17:00 UTC)
      final night = DateTime.utc(2026, 10, 9, 17, 0);
      expect(IndianTimeService.getGreeting(night), 'Good night');

      // 03:00 IST is 21:30 UTC previous day
      final lateNight = DateTime.utc(2026, 10, 8, 21, 30);
      expect(IndianTimeService.getGreeting(lateNight), 'Good night');
    });

    test('IndianLocations database provides 780+ districts across 28 states & 8 UTs with coordinates', () {
      expect(IndianLocations.all.length, greaterThanOrEqualTo(780));
      expect(IndianLocations.states.length, 36);
      expect(IndianLocations.states.contains('Telangana'), isTrue);
      expect(IndianLocations.states.contains('Maharashtra'), isTrue);
      expect(IndianLocations.states.contains('Gujarat'), isTrue);
      expect(IndianLocations.states.contains('Jammu and Kashmir'), isTrue);
      expect(IndianLocations.states.contains('Delhi'), isTrue);

      final searchResults = IndianLocations.search('Warangal');
      expect(searchResults.isNotEmpty, isTrue);
      final w = searchResults.first;
      expect(w.cityOrTown, 'Warangal');
      expect(w.state, 'Telangana');
      expect(w.latitude, closeTo(17.9784, 0.01));
      expect(w.longitude, closeTo(79.5941, 0.01));

      final byState = IndianLocations.byState('Gujarat');
      expect(byState.isNotEmpty, isTrue);
      expect(byState.any((l) => l.cityOrTown == 'Rajkot'), isTrue);
    });

    test('WeatherData formats units, tracks observation time, and handles caching freshness', () {
      final now = DateTime.now();
      final liveWeather = WeatherData(
        temperature: 28.4,
        relativeHumidity: 65.0,
        windSpeed: 12.3,
        weatherCondition: 'Clear Sky',
        locationName: 'Warangal, Telangana',
        isAvailable: true,
        observationTime: now,
        isCached: false,
      );

      expect(liveWeather.temperatureFormatted, '28°C');
      expect(liveWeather.humidityFormatted, '65%');
      expect(liveWeather.windSpeedFormatted, '12 km/h');
      expect(liveWeather.freshnessLabel, 'Live');

      final cachedWeather = liveWeather.asCachedCopy();
      expect(cachedWeather.isCached, isTrue);
      expect(cachedWeather.freshnessLabel.contains('Cached'), isTrue);
    });

    test('UserProfile persists profileImagePath, coordinates, and copyWith handles removal', () {
      final profile = UserProfile(
        id: 'usr_99',
        fullName: 'Kishan Patel',
        email: 'kishan@cottonguard.org',
        location: 'Nagpur, Maharashtra',
        latitude: 21.1458,
        longitude: 79.0882,
        profileImagePath: '/data/user/0/avatar.jpg',
        createdAt: DateTime(2026, 10, 1),
      );

      final json = profile.toJson();
      final restored = UserProfile.fromJson(json);

      expect(restored.fullName, 'Kishan Patel');
      expect(restored.profileImagePath, '/data/user/0/avatar.jpg');
      expect(restored.latitude, 21.1458);
      expect(restored.longitude, 79.0882);

      // Verify removal
      final removed = restored.copyWith(clearProfileImage: true);
      expect(removed.profileImagePath, isNull);
      expect(removed.fullName, 'Kishan Patel');
    });

    testWidgets('MainNavigationShell displays exactly 4 destinations without central Scan button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({
        'cotton_guard_is_logged_in': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      await tester.pumpWidget(MaterialApp(
        home: MainNavigationShell(storageService: storage),
      ));
      await tester.pumpAndSettle();

      // Verify 4 tabs
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Verify no Scan button in bottom bar
      expect(find.byIcon(Icons.center_focus_strong_rounded), findsNothing);

      // Verify dashboard has Start Scan button and tapping it with offline backend shows clear dialog
      expect(find.text('Start Scan'), findsOneWidget);
      await tester.tap(find.text('Start Scan'));
      await tester.pumpAndSettle();

      expect(find.text('AI Server Offline'), findsOneWidget);
      expect(find.text('Server Settings'), findsOneWidget);
    });

    testWidgets('DiseaseLibraryScreen lists 7 conditions without any severity badges on cards', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(
        home: DiseaseLibraryScreen(),
      ));
      await tester.pumpAndSettle();

      // Verify all 7 diseases are rendered
      for (final cls in CanonicalClasses.all) {
        expect(find.text(cls), findsOneWidget);
      }

      // Verify no severity badges appear on cards
      expect(find.text('High to Critical'), findsNothing);
      expect(find.text('Moderate to High'), findsNothing);
      expect(find.text('Critical'), findsNothing);
    });

    test('GoogleAuthService extracts numeric status codes accurately', () {
      // Direct numeric code
      final eDirect10 = PlatformException(code: '10', message: 'DEVELOPER_ERROR');
      expect(GoogleAuthService.extractStatusCode(eDirect10), 10);

      // Embedded ApiException in message
      final eApi10 = PlatformException(
        code: 'sign_in_failed',
        message: 'com.google.android.gms.common.api.ApiException: 10: ',
      );
      expect(GoogleAuthService.extractStatusCode(eApi10), 10);

      final eApi12500 = PlatformException(
        code: 'sign_in_failed',
        message: 'com.google.android.gms.common.api.ApiException: 12500: ',
      );
      expect(GoogleAuthService.extractStatusCode(eApi12500), 12500);

      final eApi7 = PlatformException(
        code: 'network_error',
        message: 'com.google.android.gms.common.api.ApiException: 7: Network error',
      );
      expect(GoogleAuthService.extractStatusCode(eApi7), 7);

      // Status code in key-value pattern
      final eKv = PlatformException(
        code: 'sign_in_failed',
        message: 'Google sign in failed with statusCode: 8',
      );
      expect(GoogleAuthService.extractStatusCode(eKv), 8);

      // Minified R8 exception in release mode on physical phone
      final eMinified10 = PlatformException(
        code: 'sign_in_failed',
        message: 'ql: 10',
      );
      expect(GoogleAuthService.extractStatusCode(eMinified10), 10);

      // Non-numeric code
      final eUnknown = PlatformException(code: 'unknown_error', message: 'Something broke');
      expect(GoogleAuthService.extractStatusCode(eUnknown), isNull);
    });

    test('GoogleAuthException stores message, code, and status code', () {
      final exc = GoogleAuthException(
        'Configuration error',
        code: '10',
        statusCode: 10,
        isConfigurationError: true,
      );
      expect(exc.message, 'Configuration error');
      expect(exc.code, '10');
      expect(exc.statusCode, 10);
      expect(exc.isConfigurationError, isTrue);
      expect(exc.toString(), 'Configuration error');
    });
  });
}

