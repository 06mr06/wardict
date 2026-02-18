# Practice Mode ve Puan Sistemi Geliştirmeleri

## 1. Practice Modda Soru Bilgisi Gösterimi
**Dosya**: `lib/screens/game/practice_screen.dart`
- [ ] Header'a soru numarası ekle (örn: "Soru 3/10")
- [ ] Seviye bilgisi göster (örn: "Seviye: B1")
- [ ] Progress bar ekle

## 2. Kullanıcı Adı ile Giriş
**Dosya**: `lib/screens/auth/login_screen.dart`
- [ ] Email/şifre yerine sadece kullanıcı adı input'u
- [ ] "Devam Et" butonu
- [ ] Kullanıcı adını SharedPreferences'a kaydet
- [ ] AuthService'i güncelle

## 3. Practice'te Ana Menüye Dönüş
**Dosya**: `lib/screens/game/practice_screen.dart`
- [ ] AppBar'a geri butonu ekle
- [ ] Onay dialogu göster ("Oyundan çıkmak istediğinize emin misiniz?")
- [ ] Session'ı iptal et

## 4. İlk 5 Oyun Seviye Testi + Puan Sistemi
**Dosya**: `lib/providers/practice_provider.dart`, `lib/models/user_level.dart`
- [ ] İlk 5 oyun sayacı ekle
- [ ] 5. oyun bitince seviye testi yap
- [ ] Seviyeye göre başlangıç puanı ver:
  - A1: 800 puan
  - A2: 1000 puan
  - B1: 1200 puan
  - B2: 1400 puan
  - C1: 1600 puan
  - C2: 1800 puan

## 5. Tek Puan Sistemi (Lig Puanları Kaldırma)
**Dosya**: `lib/models/user_level.dart`, `lib/models/league.dart`
- [ ] LeagueScores modelini kaldır
- [ ] UserProfile'da tek `eloRating` field'ı bırak
- [ ] ProfileScreenNew'de lig puanları bölümünü kaldır
- [ ] Tek puan göster

## 6. Duel Puan Kazanma/Kaybetme
**Dosya**: `lib/screens/game/duel_screen.dart`, `lib/providers/game_provider.dart`
- [ ] Kazanınca: +20 puan
- [ ] Kaybedince: -15 puan
- [ ] Berabere: değişiklik yok
- [ ] Puan değişimini results ekranında göster

## Değiştirilecek Dosyalar
1. `lib/screens/game/practice_screen.dart`
2. `lib/screens/auth/login_screen.dart`
3. `lib/providers/practice_provider.dart`
4. `lib/models/user_level.dart`
5. `lib/models/league.dart`
6. `lib/screens/profile/profile_screen_new.dart`
7. `lib/screens/game/duel_screen.dart`
8. `lib/providers/game_provider.dart`
9. `lib/services/user_profile_service.dart`

## Öncelik Sırası
1. Tek puan sistemi (model değişiklikleri)
2. Practice'te soru bilgisi
3. Ana menüye dönüş
4. İlk 5 oyun sistemi
5. Kullanıcı adı girişi
6. Duel puan sistemi
