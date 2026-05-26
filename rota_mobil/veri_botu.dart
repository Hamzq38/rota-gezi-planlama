import 'dart:convert';
import 'package:http/http.dart' as http;

// --- 1. SUPABASE AYARLARI ---
const String supabaseUrl = 'https://vwjxgggznzbtnhtaxzqv.supabase.co';
const String supabaseKey = 'sb_publishable_LlWXkSSwKusx715JIgLaEw_7crUTKc2';
const String adminId = 'd02b28c8-1234-5678-abcd-1234567890ab';

// --- 2. KUSURSUZ KATEGORİ ZEKASI (Sadece Wikipedia Türlerine Bakar) ---
int kategoriBelirle(List<dynamic> wikiKategorileri) {
  // Mekanın Wikipedia'daki tüm kategorilerini tek bir küçük harfli metne çeviriyoruz
  String catString = wikiKategorileri
      .map((c) => c['title'].toString().toLowerCase())
      .join(" ");

  // Artık "Çeşme Sokak" buraya takılmaz çünkü kategorisinde "Sokaklar" yazar.
  // "Alman Çeşmesi" ise kategorisinde "İstanbul'daki çeşmeler" yazdığı için direkt 4 numara olur.

  if (catString.contains('camiler') ||
      catString.contains('mescitler') ||
      catString.contains('kiliseler') ||
      catString.contains('sinagoglar')) {
    return 1; // İbadethane
  }
  if (catString.contains('müzeler') ||
      catString.contains('saraylar') ||
      catString.contains('medreseler') ||
      catString.contains('kaleler') ||
      catString.contains('türbeler')) {
    return 2; // Tarihi Eser & Müze
  }
  if (catString.contains('parklar') ||
      catString.contains('bahçeler') ||
      catString.contains('korular') ||
      catString.contains('ormanlar') ||
      catString.contains('meydanlar')) {
    return 3; // Doğa & Park
  }
  if (catString.contains('sarnıçlar') ||
      catString.contains('çeşmeler') ||
      catString.contains('hamamlar') ||
      catString.contains('su kemerleri')) {
    return 4; // Su Yapısı
  }
  if (catString.contains('üniversiteler') ||
      catString.contains('kütüphaneler') ||
      catString.contains('liseler')) {
    return 5; // Eğitim
  }

  return 6; // Hiçbirine uymazsa Genel Kategori
}

void main() async {
  print("🚀 ROTA Veri Botu v6.0 (Geosearch + Kategori Analizi) başlatıldı...");

  // Sultanahmet merkezli 5 km yarıçapında 100 adet GERÇEK (koordinatı olan) mekan buluyoruz
  final searchUrl = Uri.parse(
    'https://tr.wikipedia.org/w/api.php?action=query&list=geosearch&gscoord=41.0082|28.9784&gsradius=5000&gslimit=100&format=json',
  );

  final headers = {'User-Agent': 'RotaMobilApp/6.0 (admin@rota.com) Dart/3.11'};

  try {
    final searchRes = await http.get(searchUrl, headers: headers);
    final places = jsonDecode(searchRes.body)['query']['geosearch'] as List;

    print(
      "🎯 ${places.length} adet garantili mekan bulundu. Detay ve Tür analizi başlıyor...\n",
    );

    int eklenenSayi = 0;

    for (var place in places) {
      final pageId = place['pageid'];
      final isim = place['title'];
      final enlem = place['lat'];
      final boylam = place['lon'];

      // Mekanın açıklamasını, resmini ve KATEGORİLERİNİ çekiyoruz
      final detailUrl = Uri.parse(
        'https://tr.wikipedia.org/w/api.php?action=query&prop=extracts|pageimages|categories&cllimit=max&pageids=$pageId&exintro=1&explaintext=1&pithumbsize=1000&format=json',
      );

      final detailRes = await http.get(detailUrl, headers: headers);

      if (detailRes.statusCode != 200) {
        print("⚠️ Limit uyarısı. 10 saniye mola...");
        await Future.delayed(const Duration(seconds: 10));
        continue;
      }

      if (!detailRes.body.startsWith('{')) continue;

      final pageInfo = jsonDecode(
        detailRes.body,
      )['query']['pages'][pageId.toString()];
      String? resimUrl = pageInfo.containsKey('thumbnail')
          ? pageInfo['thumbnail']['source']
          : null;
      String aciklama = pageInfo['extract'] ?? 'Açıklama bulunamadı.';
      List<dynamic> rawCategories = pageInfo['categories'] ?? [];

      // Eğer resim yoksa veya kalitesizse veritabanımızı kirletmiyoruz
      if (resimUrl == null || aciklama.length < 50) {
        continue;
      }

      // İŞTE ZEKANIN ÇALIŞTIĞI YER: İsme değil, listeye bakıp ID'yi al!
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
        print("✅ EKLENDİ: $isim (Kategori: $kategoriId)");
        eklenenSayi++;
      } else {
        print("❌ HATA ($isim): ${response.body}");
      }

      await Future.delayed(
        const Duration(milliseconds: 1500),
      ); // Hız sınırı için kısa bekleme
    }

    print(
      "\n🎉 İŞLEM TAMAMLANDI! Toplam $eklenenSayi adet kusursuz veri eklendi.",
    );
  } catch (e) {
    print("❌ Kritik Hata: $e");
  }
}
