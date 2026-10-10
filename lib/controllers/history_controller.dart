import 'package:flutter/foundation.dart';
import '../models/scan_record.dart';
import '../services/storage_service.dart';

/// Manages scan history and computes honest agronomic insights from real records.
class HistoryController extends ChangeNotifier {
  final StorageService _storageService;
  List<ScanRecord> _records = [];

  HistoryController(this._storageService) {
    loadHistory();
  }

  List<ScanRecord> get records => List.unmodifiable(_records);

  void loadHistory() {
    _records = _storageService.getScanHistory();
    notifyListeners();
  }

  Future<void> addScan(ScanRecord record) async {
    _records.insert(0, record);
    await _storageService.saveScanRecord(record);
    notifyListeners();
  }

  Future<void> deleteScan(String id) async {
    _records.removeWhere((r) => r.id == id);
    await _storageService.deleteScanRecord(id);
    notifyListeners();
  }

  Future<void> clearAll() async {
    _records.clear();
    await _storageService.clearAllHistory();
    notifyListeners();
  }

  // --- Genuine Calculated Statistics (Never fake) ---
  int get totalScans => _records.length;

  int get healthyScans => _records.where((r) => r.isHealthy).length;

  double get healthyPercentage =>
      totalScans == 0 ? 0.0 : (healthyScans / totalScans) * 100.0;

  int get diseasedScans => _records.where((r) => !r.isHealthy && r.status == 'SUCCESS').length;

  int get lowConfidenceScans => _records.where((r) => r.isLowConfidence).length;

  Map<String, int> get diseaseDistribution {
    final Map<String, int> counts = {};
    for (final r in _records) {
      counts[r.predictedClass] = (counts[r.predictedClass] ?? 0) + 1;
    }
    return counts;
  }

  String get mostDetectedCondition {
    if (_records.isEmpty) return 'None';
    final dist = diseaseDistribution;
    String top = 'None';
    int maxCount = -1;
    dist.forEach((disease, count) {
      if (count > maxCount) {
        maxCount = count;
        top = disease;
      }
    });
    return top;
  }
}
