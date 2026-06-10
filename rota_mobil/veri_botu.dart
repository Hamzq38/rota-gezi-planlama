import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dotenv/dotenv.dart'; // Artık flutter_dotenv değil, saf dotenv

// --- KATEGORİ ZEKASI ---
int kategoriBelirle(List<dynamic> wikiKategorileri) {
  String catString = wikiKategorileri
      .map((c) => c['title'].toString().toLowerCase())
      .join(" ");
  if (catString.contains('camiler') ||
      catString.contains('mescitler') ||
      catString.contains('kiliseler') ||
      catString.contains('sinagoglar'))
    return 1;
  if (catString.contains('müzeler') ||
      catString.contains('saraylar') ||
      catString.contains('medreseler') ||
      catString.contains('kaleler') ||
      catString.contains('türbeler'))
    return 2;
  if (catString.contains('parklar') ||
      catString.contains('bahçeler') ||
      catString.contains('korular') ||
      catString.contains('ormanlar') ||
      catString.contains('meydanlar'))
    return 3;
  if (catString.contains('sarnıçlar') ||
      catString.contains('çeşmeler') ||
      catString.contains('hamamlar') ||
      catString.contains('su kemerleri'))
    return 4;
  if (catString.contains('üniversiteler') ||
      catString.contains('kütüphaneler') ||
      catString.contains('liseler'))
    return 5;
  return 6;
}

void main() async {
  print("🚀 ROTA Veri Botu v6.3 (Saf Dart Modu) başlatılıyor...");

  // dotenv yükle
  final env = DotEnv()..load(['.env']);

  // Değişkenleri çek
  final supabaseUrl = env['SUPABASE_URL'];
  final supabaseKey = env['SUPABASE_ANON_KEY'];
  final adminId = env['ADMIN_ID'] ?? 'd02b28c8-1234-5678-abcd-1234567890ab';

  if (supabaseUrl == null || supabaseKey == null) {
    print("❌ HATA: .env dosyasındaki anahtarlar okunamadı!");
    return;
  }
  print("✅ Anahtarlar yüklendi, Wikipedia taranıyor...");

  final searchUrl = Uri.parse(
    'https://tr.wikipedia.org/w/api.php?action=query&list=geosearch&gscoord=41.0082|28.9784&gsradius=10000&gslimit=300&format=json',
  );

  final headers = {'User-Agent': 'RotaMobilApp/6.3 (admin@rota.com)'};

  try {
    final searchRes = await http.get(searchUrl, headers: headers);
    final places = jsonDecode(searchRes.body)['query']['geosearch'] as List;

    print("🎯 ${places.length} mekan bulundu, Supabase'e işleniyor...\n");

    for (var place in places) {
      final pageId = place['pageid'];
      final isim = place['title'];
      final enlem = place['lat'];
      final boylam = place['lon'];

      final detailUrl = Uri.parse(
        'https://tr.wikipedia.org/w/api.php?action=query&prop=extracts|pageimages|categories&cllimit=max&pageids=$pageId&exintro=1&explaintext=1&pithumbsize=1000&format=json',
      );

      final detailRes = await http.get(detailUrl, headers: headers);
      if (detailRes.statusCode != 200 || !detailRes.body.startsWith('{'))
        continue;

      final pageInfo = jsonDecode(
        detailRes.body,
      )['query']['pages'][pageId.toString()];
      String? resimUrl = pageInfo.containsKey('thumbnail')
          ? pageInfo['thumbnail']['source']
          : null;
      String aciklama = pageInfo['extract'] ?? 'Açıklama bulunamadı.';
      List<dynamic> rawCategories = pageInfo['categories'] ?? [];

      if (resimUrl == null || aciklama.length < 50) continue;

      int kategoriId = kategoriBelirle(rawCategories);

      final response = await http.post(
        Uri.parse('$supabaseUrl/rest/v1/mekanlar'),
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: jsonEncode({
          "kategori_id": kategoriId,
          "ekleyen_id": adminId,
          "isim": isim,
          "aciklama": aciklama.substring(
            0,
            aciklama.length > 600 ? 600 : aciklama.length,
          ),
          "resim_url": resimUrl,
          "enlem": enlem,
          "boylam": boylam,
          "adres": "İstanbul, Türkiye",
        }),
      );

      if (response.statusCode == 201) {
        print("✅ EKLENDİ: $isim");
      } else {
        print("❌ HATA ($isim): ${response.statusCode}");
      }
      await Future.delayed(const Duration(milliseconds: 1500));
    }
  } catch (e) {
    print("❌ Kritik Hata: $e");
  }
}
