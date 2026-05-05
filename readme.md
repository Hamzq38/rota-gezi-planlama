# ROTA Akıllı Gezi Planlama Sistemi

Bu proje, konum tabanlı ilgi çekici nokta (POI) verilerini kullanarak çoklu durak optimizasyonu sağlayan, modüler ve ticari vizyona sahip bir gezi planlama sisteminin arka plan (Back-end) ve veritabanı mimarisini içermektedir.

## 🚀 Proje Mimarisindeki Öne Çıkan Özellikler
 Rol Tabanlı Erişim Kontrolü (RBAC) Admin, İşletme Sahibi ve Standart Kullanıcı yetkilendirmeleri veritabanı seviyesinde ayrılmıştır.
 İşletme Sahipliği (B2B Modülü) Mekanlar tablosundaki `sahip_id` yapısı sayesinde işletmelerin kendi vitrinlerini yönetebilmesine olanak tanır.
 Genişletilebilir Veritabanı `rota_duraklari` gibi köprü tablolar ve zincirleme silme (Cascade) kısıtlamalarıyla veri bütünlüğü sağlanmıştır.
 Güvenlik Evrensel Benzersiz Tanımlayıcılar (UUID) kullanılarak IDOR zafiyetleri engellenmiştir.

## 🛠️ Kullanılan Teknolojiler
 Veritabanı PostgreSQL (Supabase tabanlı)
 Algoritma Altyapısı Gezgin Satıcı Problemi (TSP) ve Çizge Teorisi (Geliştirme Aşamasında)

Not Bu proje şu an aktif geliştirme aşamasındadır.