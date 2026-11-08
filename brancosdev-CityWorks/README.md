# 🏗️ CityWorks – Belediye Meslek Sistemi

**Brancos Development** tarafından geliştirilen, FiveM için seviye tabanlı, modern arayüzlü legal meslek scripti.

Oyuncular CityWorks merkezinden görev alır, araçlarını çıkarır, şehirde çöp toplama, yol bakımı ve elektrik arızası görevlerini yaparak XP kazanır ve seviye atlar.

---

## ✨ Özellikler

- 🧩 **Çoklu altyapı desteği:** QBCore, Qbox ve Standalone (FiveM License). `auto` modu kurulu altyapıyı kendisi algılar.
- 📈 **Seviye / XP sistemi:** 5 seviye (Stajyer → Uzman), yeni seviyelerde yeni görev ve araçlar açılır.
- 🛠️ **3 farklı görev türü:**
  - 🗑️ Çöp Toplama (Seviye 1)
  - 🚧 Yol Bakımı: duba yerleştirme ve çukur onarma (Seviye 2)
  - ⚡ Elektrik Arızası (Seviye 3)
- 🚚 **Seviyeye göre araçlar:** Her görev türüne özel meslek aracı.
- 👷 **Kıyafet sistemi:** Seviyeye göre açılan iş üniformaları.
- 🖥️ **Modern NUI arayüzü:** Profil, ilerleme ve görev seçimi tek panelde.
- 🎯 **Etkileşim desteği:** `ox_target`, `qb-target` veya DrawText (E tuşu). Otomatik algılama.
- 🔔 **Bildirim desteği:** `ox_lib`, QBCore, Qbox, native veya scriptin kendi bildirimleri.
- ⚙️ **Kolay yapılandırma:** Her şey `config.lua` içinde.

---

## 📦 Gereksinimler

- [oxmysql](https://github.com/overextended/oxmysql)
- *(İsteğe bağlı)* QBCore veya Qbox
- *(İsteğe bağlı)* ox_target / qb-target, ox_lib

---

## 🔧 Kurulum

1. Klasörü `resources` dizinine atın (`brancosdev-CityWorks`).
2. `install.sql` dosyasını veritabanınıza aktarın.
3. `server.cfg` dosyanıza ekleyin (oxmysql'den **sonra**):
   ```cfg
   ensure oxmysql
   ensure brancosdev-CityWorks
   ```
4. `config.lua` dosyasını isteğinize göre düzenleyin.
5. Sunucuyu yeniden başlatın.

---

## ⚙️ Temel Ayarlar (`config.lua`)

| Ayar | Açıklama | Değerler |
|------|----------|----------|
| `Config.Framework` | Kullanılan altyapı | `auto`, `qbcore`, `qbox`, `standalone` |
| `Config.MoneyAccount` | Ödülün yatacağı hesap | `cash`, `bank` |
| `Config.NotifySystem` | Bildirim sistemi | `auto`, `native`, `qbcore`, `qbox`, `ox_lib`, `custom` |
| `Config.InteractionType` | Etkileşim sistemi | `auto`, `drawtext`, `qb-target`, `ox_target` |

Seviyeler, araçlar, üniformalar, görev noktaları, NPC konumu ve blip ayarları da aynı dosyadan değiştirilebilir.

---

## 💬 Destek

Soru, öneri ve hata bildirimleri için Discord sunucumuza katılın:

👉 **[discord.gg/8GhcFHmQVr](https://discord.gg/8GhcFHmQVr)**
