import 'package:flutter_test/flutter_test.dart';
import 'package:mirrora_app/models/store_model.dart';
import 'package:mirrora_app/services/location_service.dart';

void main() {
  group('BeautyStore & LocationService Tests', () {
    test('sampleStores should return non-empty list of stores', () {
      final stores = BeautyStore.sampleStores();
      expect(stores.isNotEmpty, isTrue);

      final localStores = stores.where((s) => s.isLocalStore).toList();
      expect(localStores.isNotEmpty, isTrue);

      // Pastikan toko lokal favorit Jogja ada
      final hasMutiara = stores.any((s) => s.name.contains('Mutiara'));
      expect(hasMutiara, isTrue);
    });

    test('BeautyStore.distanceText formats correctly', () {
      expect(BeautyStore.distanceText(0.45), '450 m');
      expect(BeautyStore.distanceText(1.23), '1.2 km');
      expect(BeautyStore.distanceText(5.0), '5.0 km');
    });

    test('LocationService.calculateDistance calculates expected distance', () {
      final service = LocationService();
      // Jarak antara Malioboro (-7.7925, 110.3658) dan Tugu Jogja (-7.7829, 110.3671) ~ 1.07 km
      final dist = service.calculateDistance(-7.7925, 110.3658, -7.7829, 110.3671);
      expect(dist, greaterThan(0.9));
      expect(dist, lessThan(1.5));
    });
  });
}
