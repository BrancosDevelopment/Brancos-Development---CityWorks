Config = {}

-- ==========================================
-- FRAMEWORK AYARLARI
-- ==========================================
-- Desteklenen altyapılar: "auto", "qbcore", "qbox", "standalone"
-- "auto" seçilirse sunucunuzdaki kurulu altyapıyı (qbx_core / qb-core) otomatik algılar, altyapı yoksa Standalone (License) moduna geçer.
-- Belirli bir altyapı seçerseniz (örn: "qbcore") ve sunucuda o paket kurulu değilse, script veri bütünlüğünü korumak için durdurulur ve konsola net uyarı verir.
Config.Framework = "auto"

-- Görev ödülünün yatacağı hesap ("cash" veya "bank")
Config.MoneyAccount = "cash"

-- ==========================================
-- BİLDİRİM (NOTIFICATION) AYARLARI
-- ==========================================
-- Desteklenen sistemler: "auto", "native", "qbcore", "qbox", "ox_lib", "custom"
-- "auto" seçilirse kurulu bildirim sistemini otomatik bulur.
-- "custom" seçerseniz CityWorks'ün kendi UI bildirimini kullanır.
Config.NotifySystem = "auto"

-- ==========================================
-- ETKİLEŞİM (INTERACTION) AYARLARI
-- ==========================================
-- Kullanabileceğiniz sistemler: "auto", "drawtext", "qb-target", "ox_target"
-- "auto" seçildiğinde sunucudaki hedef sistemini (ox_target veya qb-target) otomatik algılar, ikisi de yoksa drawtext'e (E tuşu) döner.
Config.InteractionType = "auto"

-- ==========================================
-- CITYWORKS MERKEZ AYARLARI
-- ==========================================
Config.Center = {
    NPC = {
        Enabled = true,
        Model = "s_m_y_construct_01",
        Coords = vector3(-545.3112, -203.8011, 38.2151), -- Sadece X, Y, Z
        Heading = 216.5490,                              -- Yön (0-360)
        DrawDistance = 10.0,
        InteractDistance = 2.0
    },
    
    Blip = {
        Enabled = true,
        Sprite = 566,
        Color = 3,
        Scale = 0.8,
        Name = "CityWorks"
    }
}

-- ==========================================
-- SEVİYE (LEVEL) AYARLARI
-- ==========================================
Config.Levels = {
    [1] = { XP = 0,    Title = "Stajyer" },
    [2] = { XP = 150,  Title = "İşçi" },
    [3] = { XP = 500,  Title = "Teknik Personel" },
    [4] = { XP = 1200, Title = "Kıdemli Personel" },
    [5] = { XP = 2500, Title = "Uzman" }
}

-- ==========================================
-- İŞ KIYAFETİ (UNIFORM) AYARLARI
-- ==========================================
Config.Uniforms = {
    {
        ID = "standart",
        Name = "Standart CityWorks",
        RequiredLevel = 1,
        Male = {
            Components = {
                [3] = { drawable = 0, texture = 0 }, -- Kollar
                [4] = { drawable = 36, texture = 0 }, -- Pantolon
                [6] = { drawable = 25, texture = 0 }, -- Ayakkabı
                [8] = { drawable = 59, texture = 0 }, -- İç Tişört
                [11] = { drawable = 56, texture = 0 }  -- Ceket/Üst
            },
            Props = {
                [0] = { drawable = 0, texture = 0 } -- Şapka
            }
        },
        Female = {
            Components = {
                [3] = { drawable = 14, texture = 0 },
                [4] = { drawable = 35, texture = 0 },
                [6] = { drawable = 25, texture = 0 },
                [8] = { drawable = 36, texture = 0 },
                [11] = { drawable = 49, texture = 0 }
            },
            Props = {
                [0] = { drawable = 0, texture = 0 }
            }
        }
    },
    {
        ID = "teknik",
        Name = "Teknik Personel",
        RequiredLevel = 3,
        Male = {
            Components = {
                [3] = { drawable = 1, texture = 0 },
                [4] = { drawable = 39, texture = 1 },
                [6] = { drawable = 25, texture = 0 },
                [8] = { drawable = 59, texture = 0 },
                [11] = { drawable = 66, texture = 1 }
            },
            Props = {}
        },
        Female = {
            Components = {
                [3] = { drawable = 14, texture = 0 },
                [4] = { drawable = 39, texture = 1 },
                [6] = { drawable = 25, texture = 0 },
                [8] = { drawable = 36, texture = 0 },
                [11] = { drawable = 60, texture = 1 }
            },
            Props = {}
        }
    },
    {
        ID = "uzman",
        Name = "Uzman Personel",
        RequiredLevel = 5,
        Male = {
            Components = {
                [3] = { drawable = 0, texture = 0 },
                [4] = { drawable = 47, texture = 0 },
                [6] = { drawable = 25, texture = 0 },
                [8] = { drawable = 15, texture = 0 },
                [11] = { drawable = 50, texture = 0 }
            },
            Props = {}
        },
        Female = {
            Components = {
                [3] = { drawable = 14, texture = 0 },
                [4] = { drawable = 49, texture = 0 },
                [6] = { drawable = 25, texture = 0 },
                [8] = { drawable = 2, texture = 0 },
                [11] = { drawable = 43, texture = 0 }
            },
            Props = {}
        }
    }
}

-- ==========================================
-- ARAÇ (VEHICLE) AYARLARI
-- ==========================================
Config.VehicleSpawn = {
    coords = vector3(-502.8932, -258.4778, 35.5439), -- Araç çıkarma alanı
    heading = 110.5778
}

Config.Vehicles = {
    { Model = "trash", Name = "Çöp Toplama Aracı", RequiredLevel = 1, TaskType = "trash" },
    { Model = "bison", Name = "Yol Bakım Aracı", RequiredLevel = 2, TaskType = "road" },
    { Model = "utillitruck", Name = "Teknik Bakım Aracı", RequiredLevel = 3, TaskType = "electric" }
}

-- ==========================================
-- GÖREV (TASK) AYARLARI
-- ==========================================
Config.TaskTypes = {
    "trash",
    "road",
    "electric"
}

Config.Tasks = {
    -- ======================================
    -- ELEKTRİK ARIZASI GÖREVİ
    -- ======================================
    electric = {
        RequiredLevel = 3,
        Name = "Elektrik Arızası",
        Reward = {
            MoneyMin = 300,
            MoneyMax = 500,
            XPMin = 75,
            XPMax = 100
        },
        Marker = {
            Type = 2,
            Size = vector3(0.4, 0.4, 0.4),
            Color = {r = 255, g = 255, b = 0, a = 150}, -- Sarı
            DrawDistance = 15.0
        },
        Blip = {
            Sprite = 354, -- Şimşek / Enerji
            Color = 5,  -- Sarı
            Scale = 0.8,
            Name = "Elektrik Arızası"
        },
        Locations = {
            {
                {coords = vector3(714.2561, 125.9341, 80.9044), heading = 189.7077},
                {coords = vector3(712.4304, 122.0044, 80.9170), heading = 348.3050},
                {coords = vector3(706.3405, 124.3434, 80.9037), heading = 2.2564},
                {coords = vector3(707.4507, 128.4771, 80.9055), heading = 171.2297}
            }
        }
    },
    -- ======================================
    -- YOL BAKIMI GÖREVİ
    -- ======================================
    road = {
        RequiredLevel = 2,
        Name = "Yol Bakımı",
        Reward = {
            MoneyMin = 150,
            MoneyMax = 250,
            XPMin = 30,
            XPMax = 50
        },
        Marker = {
            Type = 2,
            Size = vector3(0.4, 0.4, 0.4),
            Color = {r = 255, g = 0, b = 0, a = 150}, -- Kırmızı
            DrawDistance = 15.0
        },
        Blip = {
            Sprite = 380, -- İnşaat / Tamirat
            Color = 1,  -- Kırmızı
            Scale = 0.8,
            Name = "Yol Bakım Noktası"
        },
        Locations = {
            {
                {coords = vector3(-1395.6814, -773.8342, 20.4864), heading = 46.9789},
                {coords = vector3(-526.3793, -1041.4993, 22.5181), heading = 15.5634},
                {coords = vector3(547.0381, -1719.1747, 28.9900), heading = 240.7836}
            }
        }
    },
    -- ======================================
    -- ÇÖP TOPLAMA GÖREVİ
    -- ======================================
    trash = {
        RequiredLevel = 1,
        Name = "Çöp Toplama",
        Reward = {
            MoneyMin = 50,
            MoneyMax = 100,
            XPMin = 10,
            XPMax = 25
        },
        Marker = {
            Type = 2,
            Size = vector3(0.4, 0.4, 0.4),
            Color = {r = 255, g = 100, b = 0, a = 150}, -- Turuncu
            DrawDistance = 15.0
        },
        Blip = {
            Sprite = 318, -- Çöp / Temizlik
            Color = 5,  -- Sarı
            Scale = 0.8,
            Name = "Çöp Toplama Noktası"
        },
        Locations = {
            {
                {coords = vector4(-1300.0735, -804.0127, 18.9808, 332.2384)},
                {coords = vector4(-1301.5691, -805.9534, 19.0287, 358.3174)},
                {coords = vector4(-1306.4425, -799.4781, 18.9200, 250.6963)},
                {coords = vector4(-1308.6694, -796.9097, 18.9740, 248.6847)},
                {coords = vector4(-1321.9651, -776.0298, 21.4412, 304.5751)},
                {coords = vector4(-1323.6139, -771.5728, 21.6678, 256.5417)}
            }
        }
    }
}
