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

CREATE TABLE kullanicilar (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    ad_soyad VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    rol VARCHAR(50) DEFAULT 'standart_kullanici',
    toplam_puan INT DEFAULT 0,
    kayit_tarihi TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE kategoriler (
    id SERIAL PRIMARY KEY,
    kategori_adi VARCHAR(100) NOT NULL,
    ikon_kodu VARCHAR(50)
);

CREATE TABLE rozetler (
    id SERIAL PRIMARY KEY,
    rozet_adi VARCHAR(100) NOT NULL,
    ikon_url TEXT
);

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

CREATE TABLE degerlendirmeler (
    id SERIAL PRIMARY KEY,
    mekan_id INT REFERENCES mekanlar(id) ON DELETE CASCADE,
    kullanici_id UUID REFERENCES kullanicilar(id) ON DELETE CASCADE,
    puan INT CHECK (puan >= 1 AND puan <= 5),
    yorum_metni TEXT,
    tarih TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE favoriler (
    id SERIAL PRIMARY KEY,
    mekan_id INT REFERENCES mekanlar(id) ON DELETE CASCADE,
    kullanici_id UUID REFERENCES kullanicilar(id) ON DELETE CASCADE,
    eklenme_tarihi TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE mekan_fotograflari (
    id SERIAL PRIMARY KEY,
    mekan_id INT REFERENCES mekanlar(id) ON DELETE CASCADE,
    foto_url TEXT NOT NULL
);

CREATE TABLE ziyaretler (
    id SERIAL PRIMARY KEY,
    kullanici_id UUID REFERENCES kullanicilar(id) ON DELETE CASCADE,
    mekan_id INT REFERENCES mekanlar(id) ON DELETE CASCADE,
    check_in_zamani TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE aktiviteler (
    id SERIAL PRIMARY KEY,
    kullanici_id UUID REFERENCES kullanicilar(id) ON DELETE CASCADE,
    rota_id INT REFERENCES rotalar(id) ON DELETE SET NULL,
    mesafe_km DOUBLE PRECISION,
    sure_dakika INT,
    gps_rotasi JSONB,
    baslangic_zamani TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE kullanici_rozetleri (
    id SERIAL PRIMARY KEY,
    kullanici_id UUID REFERENCES kullanicilar(id) ON DELETE CASCADE,
    rozet_id INT REFERENCES rozetler(id) ON DELETE CASCADE,
    kazanma_tarihi TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO kullanicilar (id, email, ad_soyad, rol, toplam_puan) 
VALUES ('d02b28c8-1234-5678-abcd-1234567890ab', 'admin@rota.com', 'Hamza Okur', 'admin', 500);

INSERT INTO kategoriler (kategori_adi, ikon_kodu) VALUES 
('Kurumsal Bina', 'blue_building_pin'),
('Tarihi & Turistik', 'brown_museum_pin'),
('Eğitim Kurumu', 'green_school_pin');

INSERT INTO rozetler (rozet_adi, ikon_url) VALUES 
('İlk Keşif', 'rozet_kesif.png'), 
('Gece Kuşu', 'rozet_gece.png');

INSERT INTO mekanlar (kategori_id, ekleyen_id, sahip_id, isim, enlem, boylam, adres) VALUES 
(2, 'd02b28c8-1234-5678-abcd-1234567890ab', 'd02b28c8-1234-5678-abcd-1234567890ab', 'Ayasofya-i Kebir Cami-i Şerifi', 41.0086, 28.9802, 'Sultan Ahmet, Fatih/İstanbul'),
(2, 'd02b28c8-1234-5678-abcd-1234567890ab', NULL, 'Topkapı Sarayı', 41.0115, 28.9833, 'Cankurtaran, Fatih/İstanbul');

INSERT INTO rotalar (olusturan_id, baslik, rota_tipi) VALUES 
('d02b28c8-1234-5678-abcd-1234567890ab', 'Tarihi Yarımada Yürüyüşü', 'Gezi');

INSERT INTO rota_duraklari (rota_id, mekan_id, sira_no) VALUES 
(1, 1, 1), 
(1, 2, 2);