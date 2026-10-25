import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class NearbyLocation {
  final String name;
  final String district;
  final double lat;
  final double lng;
  final double? distanceKm;

  const NearbyLocation({
    required this.name,
    required this.district,
    required this.lat,
    required this.lng,
    this.distanceKm,
  });

  NearbyLocation withDistance(double km) {
    return NearbyLocation(
      name: name,
      district: district,
      lat: lat,
      lng: lng,
      distanceKm: km,
    );
  }
}

class LocationNearbyService {
  // ───────────────────────────────────────────────────────────────────────────
  // Comprehensive Offline Geo-Database for:
  // Chennai, Chengalpattu, Kanchipuram, Tiruvallur, Coimbatore
  // (100% Free, 0ms latency, zero internet needed)
  // ───────────────────────────────────────────────────────────────────────────
  static const List<NearbyLocation> _db = [
    // ── CHENNAI ─────────────────────────────────────────────────────────────
    NearbyLocation(name: 'Vadapalani', district: 'Chennai', lat: 13.0500, lng: 80.2120),
    NearbyLocation(name: 'Kodambakkam', district: 'Chennai', lat: 13.0528, lng: 80.2263),
    NearbyLocation(name: 'Saligramam', district: 'Chennai', lat: 13.0556, lng: 80.1989),
    NearbyLocation(name: 'Ashok Nagar', district: 'Chennai', lat: 13.0360, lng: 80.2140),
    NearbyLocation(name: 'KK Nagar', district: 'Chennai', lat: 13.0410, lng: 80.1990),
    NearbyLocation(name: 'Choolaimedu', district: 'Chennai', lat: 13.0640, lng: 80.2240),
    NearbyLocation(name: 'Koyambedu', district: 'Chennai', lat: 13.0694, lng: 80.1948),
    NearbyLocation(name: 'Arumbakkam', district: 'Chennai', lat: 13.0720, lng: 80.2100),
    NearbyLocation(name: 'Virugambakkam', district: 'Chennai', lat: 13.0520, lng: 80.1900),
    NearbyLocation(name: 'West Mambalam', district: 'Chennai', lat: 13.0380, lng: 80.2230),
    NearbyLocation(name: 'T Nagar', district: 'Chennai', lat: 13.0418, lng: 80.2341),
    NearbyLocation(name: 'Nungambakkam', district: 'Chennai', lat: 13.0600, lng: 80.2400),
    NearbyLocation(name: 'Chetpet', district: 'Chennai', lat: 13.0710, lng: 80.2410),
    NearbyLocation(name: 'Kilpauk', district: 'Chennai', lat: 13.0800, lng: 80.2400),
    NearbyLocation(name: 'Aminjikarai', district: 'Chennai', lat: 13.0730, lng: 80.2220),
    NearbyLocation(name: 'Anna Nagar', district: 'Chennai', lat: 13.0850, lng: 80.2100),
    NearbyLocation(name: 'Shenoy Nagar', district: 'Chennai', lat: 13.0780, lng: 80.2260),
    NearbyLocation(name: 'Thirumangalam', district: 'Chennai', lat: 13.0850, lng: 80.1960),
    NearbyLocation(name: 'Guindy', district: 'Chennai', lat: 13.0067, lng: 80.2025),
    NearbyLocation(name: 'Saidapet', district: 'Chennai', lat: 13.0210, lng: 80.2230),
    NearbyLocation(name: 'Ekkatuthangal', district: 'Chennai', lat: 13.0230, lng: 80.2030),
    NearbyLocation(name: 'Velachery', district: 'Chennai', lat: 12.9815, lng: 80.2180),
    NearbyLocation(name: 'Adyar', district: 'Chennai', lat: 13.0012, lng: 80.2565),
    NearbyLocation(name: 'Besant Nagar', district: 'Chennai', lat: 12.9990, lng: 80.2680),
    NearbyLocation(name: 'Thiruvanmiyur', district: 'Chennai', lat: 12.9830, lng: 80.2590),
    NearbyLocation(name: 'Kotturpuram', district: 'Chennai', lat: 13.0180, lng: 80.2400),
    NearbyLocation(name: 'Mylapore', district: 'Chennai', lat: 13.0368, lng: 80.2676),
    NearbyLocation(name: 'Alwarpet', district: 'Chennai', lat: 13.0330, lng: 80.2500),
    NearbyLocation(name: 'Teynampet', district: 'Chennai', lat: 13.0400, lng: 80.2500),
    NearbyLocation(name: 'Royapettah', district: 'Chennai', lat: 13.0540, lng: 80.2610),
    NearbyLocation(name: 'Triplicane', district: 'Chennai', lat: 13.0580, lng: 80.2760),
    NearbyLocation(name: 'Egmore', district: 'Chennai', lat: 13.0780, lng: 80.2600),
    NearbyLocation(name: 'Central', district: 'Chennai', lat: 13.0827, lng: 80.2707),
    NearbyLocation(name: 'Broadway', district: 'Chennai', lat: 13.0900, lng: 80.2850),
    NearbyLocation(name: 'George Town', district: 'Chennai', lat: 13.0950, lng: 80.2880),
    NearbyLocation(name: 'Sowcarpet', district: 'Chennai', lat: 13.0910, lng: 80.2790),
    NearbyLocation(name: 'Perambur', district: 'Chennai', lat: 13.1110, lng: 80.2400),
    NearbyLocation(name: 'Villivakkam', district: 'Chennai', lat: 13.1070, lng: 80.2050),
    NearbyLocation(name: 'Kolathur', district: 'Chennai', lat: 13.1240, lng: 80.2080),
    NearbyLocation(name: 'Ayanavaram', district: 'Chennai', lat: 13.0990, lng: 80.2310),
    NearbyLocation(name: 'Purasawalkam', district: 'Chennai', lat: 13.0880, lng: 80.2550),
    NearbyLocation(name: 'Madhavaram', district: 'Chennai', lat: 13.1480, lng: 80.2310),
    NearbyLocation(name: 'Porur', district: 'Chennai', lat: 13.0382, lng: 80.1565),
    NearbyLocation(name: 'Ramapuram', district: 'Chennai', lat: 13.0310, lng: 80.1800),
    NearbyLocation(name: 'Valasaravakkam', district: 'Chennai', lat: 13.0400, lng: 80.1740),
    NearbyLocation(name: 'Alandur', district: 'Chennai', lat: 13.0030, lng: 80.2010),
    NearbyLocation(name: 'Meenambakkam', district: 'Chennai', lat: 12.9860, lng: 80.1760),
    NearbyLocation(name: 'Sholinganallur', district: 'Chennai', lat: 12.9010, lng: 80.2279),
    NearbyLocation(name: 'Perungudi', district: 'Chennai', lat: 12.9654, lng: 80.2461),
    NearbyLocation(name: 'Thoraipakkam', district: 'Chennai', lat: 12.9400, lng: 80.2360),
    NearbyLocation(name: 'Madipakkam', district: 'Chennai', lat: 12.9647, lng: 80.1961),
    NearbyLocation(name: 'Medavakkam', district: 'Chennai', lat: 12.9180, lng: 80.1920),
    NearbyLocation(name: 'Pallikaranai', district: 'Chennai', lat: 12.9360, lng: 80.2140),
    NearbyLocation(name: 'Mogappair', district: 'Chennai', lat: 13.0837, lng: 80.1750),
    NearbyLocation(name: 'Ambattur', district: 'Chennai', lat: 13.1143, lng: 80.1548),
    NearbyLocation(name: 'Padi', district: 'Chennai', lat: 13.0970, lng: 80.1820),
    NearbyLocation(name: 'Maduravoyal', district: 'Chennai', lat: 13.0680, lng: 80.1600),
    NearbyLocation(name: 'Nolambur', district: 'Chennai', lat: 13.0760, lng: 80.1680),
    NearbyLocation(name: 'Kottivakkam', district: 'Chennai', lat: 12.9690, lng: 80.2580),
    NearbyLocation(name: 'Palavakkam', district: 'Chennai', lat: 12.9550, lng: 80.2550),
    NearbyLocation(name: 'Neelankarai', district: 'Chennai', lat: 12.9480, lng: 80.2560),
    NearbyLocation(name: 'Injambakkam', district: 'Chennai', lat: 12.9230, lng: 80.2490),
    NearbyLocation(name: 'Akkarai', district: 'Chennai', lat: 12.9030, lng: 80.2450),

    // ── CHENGALPATTU ────────────────────────────────────────────────────────
    NearbyLocation(name: 'Tambaram', district: 'Chengalpattu', lat: 12.9249, lng: 80.1000),
    NearbyLocation(name: 'Chromepet', district: 'Chengalpattu', lat: 12.9516, lng: 80.1462),
    NearbyLocation(name: 'Pallavaram', district: 'Chengalpattu', lat: 12.9675, lng: 80.1491),
    NearbyLocation(name: 'Tambaram Sanatorium', district: 'Chengalpattu', lat: 12.9390, lng: 80.1250),
    NearbyLocation(name: 'Perungalathur', district: 'Chengalpattu', lat: 12.9050, lng: 80.0820),
    NearbyLocation(name: 'Vandalur', district: 'Chengalpattu', lat: 12.8910, lng: 80.0810),
    NearbyLocation(name: 'Urapakkam', district: 'Chengalpattu', lat: 12.8670, lng: 80.0710),
    NearbyLocation(name: 'Guduvanchery', district: 'Chengalpattu', lat: 12.8439, lng: 80.0617),
    NearbyLocation(name: 'Maraimalai Nagar', district: 'Chengalpattu', lat: 12.7950, lng: 80.0240),
    NearbyLocation(name: 'Singaperumal Koil', district: 'Chengalpattu', lat: 12.7630, lng: 80.0030),
    NearbyLocation(name: 'Chengalpattu', district: 'Chengalpattu', lat: 12.6841, lng: 79.9836),
    NearbyLocation(name: 'Kelambakkam', district: 'Chengalpattu', lat: 12.7873, lng: 80.2185),
    NearbyLocation(name: 'Thiruporur', district: 'Chengalpattu', lat: 12.7247, lng: 80.1906),
    NearbyLocation(name: 'Mahabalipuram', district: 'Chengalpattu', lat: 12.6269, lng: 80.1927),
    NearbyLocation(name: 'Navalur', district: 'Chengalpattu', lat: 12.8458, lng: 80.2265),
    NearbyLocation(name: 'Siruseri', district: 'Chengalpattu', lat: 12.8250, lng: 80.2180),
    NearbyLocation(name: 'Semmancheri', district: 'Chengalpattu', lat: 12.8710, lng: 80.2270),
    NearbyLocation(name: 'Kovilambakkam', district: 'Chengalpattu', lat: 12.9440, lng: 80.1830),
    NearbyLocation(name: 'Keelkattalai', district: 'Chengalpattu', lat: 12.9570, lng: 80.1800),
    NearbyLocation(name: 'Nanganallur', district: 'Chengalpattu', lat: 12.9810, lng: 80.1890),
    NearbyLocation(name: 'Nemmeli', district: 'Chengalpattu', lat: 12.7000, lng: 80.2240),
    NearbyLocation(name: 'Mamallapuram', district: 'Chengalpattu', lat: 12.6269, lng: 80.1927),

    // ── KANCHIPURAM ─────────────────────────────────────────────────────────
    NearbyLocation(name: 'Kanchipuram', district: 'Kanchipuram', lat: 12.8342, lng: 79.7036),
    NearbyLocation(name: 'Sriperumbudur', district: 'Kanchipuram', lat: 12.9675, lng: 79.9436),
    NearbyLocation(name: 'Oragadam', district: 'Kanchipuram', lat: 12.8396, lng: 79.9535),
    NearbyLocation(name: 'Walajabad', district: 'Kanchipuram', lat: 12.7944, lng: 79.8164),
    NearbyLocation(name: 'Sunguvarchatram', district: 'Kanchipuram', lat: 12.9420, lng: 79.8450),
    NearbyLocation(name: 'Enathur', district: 'Kanchipuram', lat: 12.8550, lng: 79.7420),
    NearbyLocation(name: 'Uthiramerur', district: 'Kanchipuram', lat: 12.6144, lng: 79.7578),
    NearbyLocation(name: 'Padappai', district: 'Kanchipuram', lat: 12.8860, lng: 80.0190),
    NearbyLocation(name: 'Kundrathur', district: 'Kanchipuram', lat: 12.9977, lng: 80.0972),
    NearbyLocation(name: 'Somangalam', district: 'Kanchipuram', lat: 12.9350, lng: 80.0400),
    NearbyLocation(name: 'Manimangalam', district: 'Kanchipuram', lat: 12.9050, lng: 80.0450),

    // ── TIRUVALLUR ──────────────────────────────────────────────────────────
    NearbyLocation(name: 'Tiruvallur', district: 'Tiruvallur', lat: 13.1432, lng: 79.9079),
    NearbyLocation(name: 'Avadi', district: 'Tiruvallur', lat: 13.1147, lng: 80.1018),
    NearbyLocation(name: 'Poonamallee', district: 'Tiruvallur', lat: 13.0489, lng: 80.0945),
    NearbyLocation(name: 'Pattabiram', district: 'Tiruvallur', lat: 13.1180, lng: 80.0630),
    NearbyLocation(name: 'Thiruninravur', district: 'Tiruvallur', lat: 13.1150, lng: 80.0260),
    NearbyLocation(name: 'Thirumazhisai', district: 'Tiruvallur', lat: 13.0560, lng: 80.0600),
    NearbyLocation(name: 'Red Hills', district: 'Tiruvallur', lat: 13.1990, lng: 80.1950),
    NearbyLocation(name: 'Kattupakkam', district: 'Tiruvallur', lat: 13.0430, lng: 80.1280),
    NearbyLocation(name: 'Iyyappanthangal', district: 'Tiruvallur', lat: 13.0370, lng: 80.1380),
    NearbyLocation(name: 'Mangadu', district: 'Tiruvallur', lat: 13.0440, lng: 80.1170),
    NearbyLocation(name: 'Manali', district: 'Tiruvallur', lat: 13.1670, lng: 80.2600),
    NearbyLocation(name: 'Ponneri', district: 'Tiruvallur', lat: 13.3283, lng: 80.1972),
    NearbyLocation(name: 'Gummidipoondi', district: 'Tiruvallur', lat: 13.4072, lng: 80.1289),
    NearbyLocation(name: 'Minjur', district: 'Tiruvallur', lat: 13.2780, lng: 80.2600),
    NearbyLocation(name: 'Tiruttani', district: 'Tiruvallur', lat: 13.1764, lng: 79.6236),

    // ── COIMBATORE ──────────────────────────────────────────────────────────
    NearbyLocation(name: 'Gandhipuram', district: 'Coimbatore', lat: 11.0183, lng: 76.9634),
    NearbyLocation(name: 'RS Puram', district: 'Coimbatore', lat: 11.0093, lng: 76.9507),
    NearbyLocation(name: 'Peelamedu', district: 'Coimbatore', lat: 11.0311, lng: 77.0186),
    NearbyLocation(name: 'Singanallur', district: 'Coimbatore', lat: 10.9994, lng: 77.0253),
    NearbyLocation(name: 'Ukkadam', district: 'Coimbatore', lat: 10.9890, lng: 76.9600),
    NearbyLocation(name: 'Saravanampatti', district: 'Coimbatore', lat: 11.0797, lng: 76.9997),
    NearbyLocation(name: 'Saibaba Colony', district: 'Coimbatore', lat: 11.0269, lng: 76.9450),
    NearbyLocation(name: 'Ganapathy', district: 'Coimbatore', lat: 11.0370, lng: 76.9800),
    NearbyLocation(name: 'Hopes College', district: 'Coimbatore', lat: 11.0260, lng: 77.0100),
    NearbyLocation(name: 'Kuniyamuthur', district: 'Coimbatore', lat: 10.9575, lng: 76.9535),
    NearbyLocation(name: 'Sundarapuram', district: 'Coimbatore', lat: 10.9490, lng: 76.9740),
    NearbyLocation(name: 'Thudiyalur', district: 'Coimbatore', lat: 11.0820, lng: 76.9380),
    NearbyLocation(name: 'Kovaipudur', district: 'Coimbatore', lat: 10.9320, lng: 76.9420),
    NearbyLocation(name: 'Vadavalli', district: 'Coimbatore', lat: 11.0250, lng: 76.9030),
    NearbyLocation(name: 'Sulur', district: 'Coimbatore', lat: 11.0265, lng: 77.1264),
    NearbyLocation(name: 'Ondipudur', district: 'Coimbatore', lat: 11.0020, lng: 77.0500),
    NearbyLocation(name: 'Ramanathapuram', district: 'Coimbatore', lat: 10.9960, lng: 76.9850),
    NearbyLocation(name: 'Kurichi', district: 'Coimbatore', lat: 10.9400, lng: 76.9700),
    NearbyLocation(name: 'Malumichampatti', district: 'Coimbatore', lat: 10.9080, lng: 76.9930),
    NearbyLocation(name: 'Perur', district: 'Coimbatore', lat: 10.9780, lng: 76.9200),
    NearbyLocation(name: 'Kinathukadavu', district: 'Coimbatore', lat: 10.8210, lng: 77.0180),
    NearbyLocation(name: 'Pollachi', district: 'Coimbatore', lat: 10.6580, lng: 77.0080),
    NearbyLocation(name: 'Karumathampatti', district: 'Coimbatore', lat: 11.1060, lng: 77.1820),
    NearbyLocation(name: 'Kalapatti', district: 'Coimbatore', lat: 11.0730, lng: 77.0420),
    NearbyLocation(name: 'Podanur', district: 'Coimbatore', lat: 10.9630, lng: 76.9850),
    NearbyLocation(name: 'Town Hall', district: 'Coimbatore', lat: 10.9970, lng: 76.9610),
    NearbyLocation(name: 'Race Course', district: 'Coimbatore', lat: 11.0010, lng: 76.9750),
    NearbyLocation(name: 'Avarampalayam', district: 'Coimbatore', lat: 11.0270, lng: 76.9830),
    NearbyLocation(name: 'Kavundampalayam', district: 'Coimbatore', lat: 11.0470, lng: 76.9400),
    NearbyLocation(name: 'Narasimhanaickenpalayam', district: 'Coimbatore', lat: 11.1150, lng: 76.9360),
    NearbyLocation(name: 'Chinnavedampatti', district: 'Coimbatore', lat: 11.0660, lng: 76.9880),
    NearbyLocation(name: 'Vellalore', district: 'Coimbatore', lat: 10.9680, lng: 77.0220),
    NearbyLocation(name: 'Madukkarai', district: 'Coimbatore', lat: 10.9030, lng: 76.9630),
    NearbyLocation(name: 'Eachanari', district: 'Coimbatore', lat: 10.9280, lng: 76.9780),
    NearbyLocation(name: 'Neelambur', district: 'Coimbatore', lat: 11.0580, lng: 77.0850),
    NearbyLocation(name: 'Karamadai', district: 'Coimbatore', lat: 11.2430, lng: 76.9580),
    NearbyLocation(name: 'Mettupalayam', district: 'Coimbatore', lat: 11.3000, lng: 76.9500),
    NearbyLocation(name: 'Annur', district: 'Coimbatore', lat: 11.2330, lng: 77.1330),
  ];

  // ───────────────────────────────────────────────────────────────────────────
  // Haversine Distance Formula in Kilometers
  // ───────────────────────────────────────────────────────────────────────────
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // Math.PI / 180
    final double a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R * asin... 12742 = Diameter of Earth in km
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Search Method: Offline First -> Online OSM Fallback (Both 100% Free!)
  // ───────────────────────────────────────────────────────────────────────────
  static Future<List<NearbyLocation>> getNearby(String query, {int limit = 15}) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty || cleanQuery.length < 3) return [];

    // Step 1: Check Offline DB for exact or partial match
    NearbyLocation? centerPoint;
    for (final loc in _db) {
      final nameLower = loc.name.toLowerCase();
      if (nameLower == cleanQuery) {
        centerPoint = loc;
        break;
      }
    }

    if (centerPoint == null) {
      for (final loc in _db) {
        final nameLower = loc.name.toLowerCase();
        if (nameLower.contains(cleanQuery) || cleanQuery.contains(nameLower)) {
          centerPoint = loc;
          break;
        }
      }
    }

    // Step 2: If found in Offline DB, calculate nearby areas instantly (0ms!)
    if (centerPoint != null) {
      return _computeNearbyFromPoint(centerPoint.lat, centerPoint.lng, excludeName: centerPoint.name, limit: limit);
    }

    // Step 3: If NOT in Offline DB, use Free OpenStreetMap Nominatim API (Online Fallback)
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent("$cleanQuery, Tamil Nadu, India")}&format=json&limit=1',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'AutoClickerApp/1.0',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final lat = double.tryParse(data[0]['lat'].toString());
          final lon = double.tryParse(data[0]['lon'].toString());
          if (lat != null && lon != null) {
            return _computeNearbyFromPoint(lat, lon, excludeName: cleanQuery, limit: limit);
          }
        }
      }
    } catch (_) {}

    return [];
  }

  static List<NearbyLocation> _computeNearbyFromPoint(double lat, double lng, {required String excludeName, int limit = 15}) {
    final results = <NearbyLocation>[];
    final excludeLower = excludeName.toLowerCase();

    for (final loc in _db) {
      if (loc.name.toLowerCase() == excludeLower) continue;

      final dist = calculateDistance(lat, lng, loc.lat, loc.lng);
      // Include places within reasonable radius (up to 40 km for suburban/district hubs)
      if (dist <= 40.0) {
        results.add(loc.withDistance(dist));
      }
    }

    // Sort by distance ascending
    results.sort((a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));

    return results.take(limit).toList();
  }
}
