-- Tüm eski tabloları temizle
DROP TABLE IF EXISTS aktiviteler CASCADE;
DROP TABLE IF EXISTS ziyaretler CASCADE;
DROP TABLE IF EXISTS rota_duraklari CASCADE;
DROP TABLE IF EXISTS rotalar CASCADE;
DROP TABLE IF EXISTS mekan_fotograflari CASCADE;
DROP TABLE IF EXISTS favoriler CASCADE;
DROP TABLE IF EXISTS degerlendirmeler CASCADE;
DROP TABLE IF EXISTS kullanici_rozetleri CASCADE;
DROP TABLE IF EXISTS rozetler CASCADE;
DROP TABLE IF EXISTS mekanlar CASCADE;
DROP TABLE IF EXISTS kategoriler CASCADE;
DROP TABLE IF EXISTS kullanicilar CASCADE;

-- Kullanıcılar Tablosu
CREATE TABLE kullanicilar (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    ad_soyad VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    rol VARCHAR(50) DEFAULT 'standart_kullanici',
    toplam_puan INT DEFAULT 0,
    kayit_tarihi TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Kategoriler (İkon Kodları Buradan Gelecek)
CREATE TABLE kategoriler (
    id SERIAL PRIMARY KEY,
    kategori_adi VARCHAR(100) NOT NULL,
    ikon_kodu VARCHAR(50)
);

-- Mekanlar Tablosu
CREATE TABLE mekanlar (
    id SERIAL PRIMARY KEY,
    kategori_id INT REFERENCES kategoriler(id),
    ekleyen_id UUID REFERENCES kullanicilar(id),
    sahip_id UUID REFERENCES kullanicilar(id),
    isim VARCHAR(255) NOT NULL,
    aciklama TEXT,
    resim_url TEXT,
    enlem DOUBLE PRECISION,
    boylam DOUBLE PRECISION,
    adres TEXT,
    olusturulma_tarihi TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Diğer İlişkisel Tablolar
CREATE TABLE rotalar (
    id SERIAL PRIMARY KEY,
    olusturan_id UUID REFERENCES kullanicilar(id) ON DELETE CASCADE,
    baslik VARCHAR(255) NOT NULL,
    rota_tipi VARCHAR(50),
    herkese_acik_mi BOOLEAN DEFAULT TRUE,
    olusturulma_tarihi TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE rota_duraklari (
    id SERIAL PRIMARY KEY,
    rota_id INT REFERENCES rotalar(id) ON DELETE CASCADE,
    mekan_id INT REFERENCES mekanlar(id) ON DELETE CASCADE,
    sira_no INT NOT NULL
);

-- Temel Verilerin Enjeksiyonu
INSERT INTO kullanicilar (id, email, ad_soyad, rol, toplam_puan) 
VALUES ('d02b28c8-1234-5678-abcd-1234567890ab', 'admin@rota.com', 'Hamza Okur', 'admin', 500);

-- Uygulama İkonlarıyla Uyumlu Kategoriler
INSERT INTO kategoriler (id, kategori_adi, ikon_kodu) VALUES 
(1, 'İbadethane', 'mosque'),
(2, 'Tarihi Eser', 'museum'),
(3, 'Doğa & Park', 'park'),
(4, 'Su Yapısı', 'water'),
(5, 'Eğitim & Medrese', 'school'),
(6, 'Genel & Sokak', 'location');