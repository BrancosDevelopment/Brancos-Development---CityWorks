/**
 * CITYWORKS - ADVANCED DASHBOARD CONTROLLER
 * Author: Brancos Dev Team
 */

// ==========================================
// SES EFEKT MOTORU (Web Audio API)
// ==========================================
let audioCtx = null;

function getAudioContext() {
    if (!audioCtx) {
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        if (AudioContext) {
            audioCtx = new AudioContext();
        }
    }
    if (audioCtx && audioCtx.state === 'suspended') {
        audioCtx.resume();
    }
    return audioCtx;
}

function playSound(type) {
    try {
        const ctx = getAudioContext();
        if (!ctx) return;
        const now = ctx.currentTime;

        if (type === 'click') {
            const osc = ctx.createOscillator();
            const gain = ctx.createGain();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(800, now);
            osc.frequency.exponentialRampToValueAtTime(400, now + 0.04);
            gain.gain.setValueAtTime(0.08, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.04);
            osc.connect(gain);
            gain.connect(ctx.destination);
            osc.start(now);
            osc.stop(now + 0.04);
        } else if (type === 'tab') {
            const osc = ctx.createOscillator();
            const gain = ctx.createGain();
            osc.type = 'triangle';
            osc.frequency.setValueAtTime(440, now);
            osc.frequency.exponentialRampToValueAtTime(660, now + 0.08);
            gain.gain.setValueAtTime(0.06, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.08);
            osc.connect(gain);
            gain.connect(ctx.destination);
            osc.start(now);
            osc.stop(now + 0.08);
        } else if (type === 'duty_on') {
            const osc1 = ctx.createOscillator();
            const osc2 = ctx.createOscillator();
            const gain = ctx.createGain();
            osc1.type = 'sine';
            osc2.type = 'sine';
            osc1.frequency.setValueAtTime(320, now);
            osc1.frequency.exponentialRampToValueAtTime(540, now + 0.15);
            osc2.frequency.setValueAtTime(480, now);
            osc2.frequency.exponentialRampToValueAtTime(720, now + 0.15);
            gain.gain.setValueAtTime(0.12, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.18);
            osc1.connect(gain);
            osc2.connect(gain);
            gain.connect(ctx.destination);
            osc1.start(now);
            osc2.start(now);
            osc1.stop(now + 0.18);
            osc2.stop(now + 0.18);
        } else if (type === 'duty_off') {
            const osc = ctx.createOscillator();
            const gain = ctx.createGain();
            osc.type = 'sawtooth';
            osc.frequency.setValueAtTime(520, now);
            osc.frequency.exponentialRampToValueAtTime(220, now + 0.16);
            gain.gain.setValueAtTime(0.09, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.16);
            osc.connect(gain);
            gain.connect(ctx.destination);
            osc.start(now);
            osc.stop(now + 0.16);
        } else if (type === 'task_start') {
            const osc = ctx.createOscillator();
            const gain = ctx.createGain();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(750, now);
            osc.frequency.setValueAtTime(950, now + 0.06);
            gain.gain.setValueAtTime(0.1, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.14);
            osc.connect(gain);
            gain.connect(ctx.destination);
            osc.start(now);
            osc.stop(now + 0.14);
        } else if (type === 'error') {
            const osc = ctx.createOscillator();
            const gain = ctx.createGain();
            osc.type = 'square';
            osc.frequency.setValueAtTime(160, now);
            gain.gain.setValueAtTime(0.08, now);
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.1);
            osc.connect(gain);
            gain.connect(ctx.destination);
            osc.start(now);
            osc.stop(now + 0.1);
        }
    } catch (e) {
        // Tarayıcı ses güvenlik kısıtlamalarını sessizce yut
    }
}

// ==========================================
// GENEL DURUM (STATE)
// ==========================================
let currentUIData = {
    onDuty: false,
    dutyStartTime: 0,
    currentTask: "Yok",
    currentTaskType: null,
    currentTaskStep: 0,
    currentTaskMaxSteps: 0,
    level: 1,
    levelTitle: "Stajyer",
    xp: 0,
    baseXP: 0,
    nextXP: 150,
    nextLevelTitle: "İşçi",
    isMax: false,
    tasks: [],
    hasVehicle: false,
    vehicles: [],
    hasUniform: false,
    uniforms: [],
    sessionEarnings: 0,
    sessionCompletedTasks: 0,
    recentRewards: []
};

let shiftTimerInterval = null;
let shiftSecondsElapsed = 0;

// ==========================================
// BAŞLANGIÇ & DİNLİYİCİLER (DOM LISTENERS)
// ==========================================
document.addEventListener("DOMContentLoaded", () => {
    // Navigasyon Butonları
    const navButtons = document.querySelectorAll('.nav-btn');
    navButtons.forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.preventDefault();
            const targetTab = btn.getAttribute('data-tab');
            switchTab(targetTab);
        });
    });

    // Kapat Butonu
    const closeBtn = document.getElementById("closeBtn");
    if (closeBtn) {
        closeBtn.addEventListener("click", () => {
            playSound('click');
            CloseMenu();
        });
    }

    // ESC Tuşu ile Kapatma
    document.addEventListener("keydown", (e) => {
        if (e.key === "Escape" || e.keyCode === 27) {
            CloseMenu();
        }
    });

    // Mesai Başlat / Bitir Butonu
    const btnToggleDuty = document.getElementById("btnToggleDuty");
    if (btnToggleDuty) {
        btnToggleDuty.addEventListener("click", () => {
            ToggleDutyAction();
        });
    }

    // Araç İade Butonu
    const btnReturnVehicle = document.getElementById("btnReturnVehicle");
    if (btnReturnVehicle) {
        btnReturnVehicle.addEventListener("click", () => {
            playSound('click');
            ReturnVehicleAction();
        });
    }

    // Üniforma İade Butonu
    const btnReturnUniform = document.getElementById("btnReturnUniform");
    if (btnReturnUniform) {
        btnReturnUniform.addEventListener("click", () => {
            playSound('click');
            ReturnUniformAction();
        });
    }

    // Aktif Görevi İptal Et Butonu
    const btnCancelActiveTask = document.getElementById("btnCancelActiveTask");
    if (btnCancelActiveTask) {
        btnCancelActiveTask.addEventListener("click", () => {
            playSound('click');
            CancelActiveTaskAction();
        });
    }
});

// Tab Değiştirme Fonksiyonu
function switchTab(tabId) {
    const navButtons = document.querySelectorAll('.nav-btn');
    const tabPanes = document.querySelectorAll('.tab-pane');

    navButtons.forEach(b => b.classList.remove('active'));
    tabPanes.forEach(p => p.classList.remove('active'));

    const activeBtn = document.querySelector(`[data-tab="${tabId}"]`);
    const activePane = document.getElementById(tabId);

    if (activeBtn) activeBtn.classList.add('active');
    if (activePane) activePane.classList.add('active');

    playSound('tab');
}

// ==========================================
// MESAİ SÜREÇ SAYACI
// ==========================================
function startShiftTimer() {
    stopShiftTimer();
    updateTimerDisplay();
    shiftTimerInterval = setInterval(() => {
        shiftSecondsElapsed++;
        updateTimerDisplay();
    }, 1000);
}

function stopShiftTimer() {
    if (shiftTimerInterval) {
        clearInterval(shiftTimerInterval);
        shiftTimerInterval = null;
    }
    shiftSecondsElapsed = 0;
    updateTimerDisplay();
}

function formatTime(seconds) {
    const hrs = Math.floor(seconds / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    return `${String(hrs).padStart(2, '0')}:${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
}

function updateTimerDisplay() {
    const formatted = formatTime(shiftSecondsElapsed);
    const headerTimer = document.getElementById("headerDutyTimer");
    const metricDuration = document.getElementById("metricShiftDuration");
    
    if (headerTimer) headerTimer.innerText = formatted;
    if (metricDuration) metricDuration.innerText = formatted;
}

// ==========================================
// NUI MESAJ DİNLEYİCİSİ (FiveM -> HTML)
// ==========================================
window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) return;

    if (data.action === "open") {
        currentUIData = Object.assign({}, currentUIData, data);
        document.getElementById("app").style.display = "flex";
        
        if (currentUIData.onDuty) {
            startShiftTimer();
        } else {
            stopShiftTimer();
        }

        RenderAllUI();
    }
    else if (data.action === "updateDuty") {
        currentUIData.onDuty = data.onDuty;
        if (data.onDuty) {
            startShiftTimer();
            playSound('duty_on');
        } else {
            stopShiftTimer();
            playSound('duty_off');
        }
        RenderDutyState();
        RenderTasks();
        RenderVehicles();
        RenderUniforms();
    }
    else if (data.action === "updateVehicle") {
        currentUIData.hasVehicle = data.hasVehicle;
        RenderVehicles();
    }
    else if (data.action === "updateUniform") {
        currentUIData.hasUniform = data.hasUniform;
        RenderUniforms();
    }
    else if (data.action === "updateTaskState") {
        currentUIData.currentTask = data.currentTask || "Yok";
        currentUIData.currentTaskType = data.currentTaskType || null;
        currentUIData.currentTaskStep = data.currentTaskStep || 0;
        currentUIData.currentTaskMaxSteps = data.currentTaskMaxSteps || 0;
        RenderActiveTask();
    }
    else if (data.action === "updateStats") {
        currentUIData.sessionEarnings = data.sessionEarnings || 0;
        currentUIData.sessionCompletedTasks = data.sessionCompletedTasks || 0;
        if (data.recentRewards) currentUIData.recentRewards = data.recentRewards;
        RenderStats();
        RenderRecentRewards();
    }
    else if (data.action === "notify") {
        ShowToastNotification(data.text, data.type);
    }
    else if (data.action === "levelUp") {
        currentUIData.level = data.level;
        currentUIData.levelTitle = data.levelTitle;
        RenderAllUI();
    }
});

// ==========================================
// RENDER MOTORU
// ==========================================
function RenderAllUI() {
    RenderDutyState();
    RenderStats();
    RenderActiveTask();
    RenderRecentRewards();
    RenderTasks();
    RenderVehicles();
    RenderUniforms();
    RenderCareer();
}

// 1. Mesai Durumu Render
function RenderDutyState() {
    const headerDutyPill = document.getElementById("headerDutyPill");
    const headerDutyText = document.getElementById("headerDutyText");
    const btnToggleDuty = document.getElementById("btnToggleDuty");
    const dutyBtnMainText = document.getElementById("dutyBtnMainText");
    const dutyBtnSubText = document.getElementById("dutyBtnSubText");

    if (currentUIData.onDuty) {
        if (headerDutyPill) headerDutyPill.className = "header-status-pill on-duty";
        if (headerDutyText) headerDutyText.innerText = "AKTİF MESAİ";
        
        if (btnToggleDuty) btnToggleDuty.className = "btn-primary-duty off-duty-active";
        if (dutyBtnMainText) dutyBtnMainText.innerText = "MESAİYİ BİTİR";
        if (dutyBtnSubText) dutyBtnSubText.innerText = "Mesaiyi sonlandır ve dinlenmeye geç";
    } else {
        if (headerDutyPill) headerDutyPill.className = "header-status-pill";
        if (headerDutyText) headerDutyText.innerText = "MESAİ DIŞI";
        
        if (btnToggleDuty) btnToggleDuty.className = "btn-primary-duty";
        if (dutyBtnMainText) dutyBtnMainText.innerText = "MESAİYE BAŞLA";
        if (dutyBtnSubText) dutyBtnSubText.innerText = "Saha görevlerini aktifleştir";
    }
}

// 2. İstatistikler & Üst Bilgiler Render
function RenderStats() {
    const topRankTitle = document.getElementById("topRankTitle");
    const topEarnings = document.getElementById("topEarnings");
    const sidebarLevelBadge = document.getElementById("sidebarLevelBadge");
    const sidebarXpCur = document.getElementById("sidebarXpCur");
    const sidebarXpMax = document.getElementById("sidebarXpMax");
    const sidebarXpFill = document.getElementById("sidebarXpFill");

    const metricSessionMoney = document.getElementById("metricSessionMoney");
    const metricTaskCount = document.getElementById("metricTaskCount");
    const metricTotalXp = document.getElementById("metricTotalXp");

    if (topRankTitle) topRankTitle.innerText = `Lvl ${currentUIData.level} - ${currentUIData.levelTitle}`;
    if (topEarnings) topEarnings.innerText = `$${currentUIData.sessionEarnings.toLocaleString()}`;
    if (sidebarLevelBadge) sidebarLevelBadge.innerText = `Seviye ${currentUIData.level} - ${currentUIData.levelTitle}`;
    if (metricSessionMoney) metricSessionMoney.innerText = `$${currentUIData.sessionEarnings.toLocaleString()}`;
    if (metricTaskCount) metricTaskCount.innerText = `${currentUIData.sessionCompletedTasks} Görev`;
    if (metricTotalXp) metricTotalXp.innerText = `${currentUIData.xp} XP`;

    // XP İlerleme Yüzdesi
    let pct = 0;
    const base = currentUIData.baseXP || 0;
    const target = currentUIData.nextXP || 150;

    if (currentUIData.isMax) {
        pct = 100;
        if (sidebarXpMax) sidebarXpMax.innerText = "MAX";
    } else {
        const earnedInTier = Math.max(0, currentUIData.xp - base);
        const requiredInTier = Math.max(1, target - base);
        pct = Math.min(100, Math.max(0, Math.floor((earnedInTier / requiredInTier) * 100)));
        if (sidebarXpMax) sidebarXpMax.innerText = target;
    }

    if (sidebarXpCur) sidebarXpCur.innerText = currentUIData.xp;
    if (sidebarXpFill) sidebarXpFill.style.width = `${pct}%`;

    // Kullanıcı Adı ve Anlık Yüz Portresi (Mugshot)
    const sidebarUserName = document.getElementById("sidebarUserName");
    if (sidebarUserName && currentUIData.playerName) {
        sidebarUserName.innerText = currentUIData.playerName;
    }

    const userAvatarWrap = document.getElementById("userAvatarWrap");
    if (userAvatarWrap) {
        if (currentUIData.avatarUrl) {
            userAvatarWrap.innerHTML = `<img src="${currentUIData.avatarUrl}" alt="Avatar" class="avatar-headshot-img" onerror="this.onerror=null; this.parentElement.innerHTML='<i class=\\'fa-solid fa-user-helmet-safety\\'></i>';">`;
        } else {
            userAvatarWrap.innerHTML = `<i class="fa-solid fa-user-helmet-safety"></i>`;
        }
    }
}

// 3. Aktif Görev Paneli Render
function RenderActiveTask() {
    const activeTaskBadge = document.getElementById("activeTaskBadge");
    const emptyPlaceholder = document.getElementById("emptyTaskPlaceholder");
    const runningDetails = document.getElementById("runningTaskDetails");
    const rtTaskName = document.getElementById("rtTaskName");
    const rtProgressStep = document.getElementById("rtProgressStep");
    const rtProgressFill = document.getElementById("rtProgressFill");

    const hasActiveTask = (currentUIData.currentTask && currentUIData.currentTask !== "Yok" && currentUIData.currentTaskType);

    if (hasActiveTask) {
        if (activeTaskBadge) {
            activeTaskBadge.innerText = "DEVAM EDİYOR";
            activeTaskBadge.className = "task-badge active-mode";
        }
        if (emptyPlaceholder) emptyPlaceholder.style.display = "none";
        if (runningDetails) runningDetails.style.display = "flex";

        if (rtTaskName) rtTaskName.innerText = currentUIData.currentTask;
        
        const curStep = currentUIData.currentTaskStep || 1;
        const maxStep = currentUIData.currentTaskMaxSteps || 3;
        if (rtProgressStep) rtProgressStep.innerText = `Nokta ${curStep} / ${maxStep}`;

        const fillPct = Math.min(100, Math.floor((curStep / maxStep) * 100));
        if (rtProgressFill) rtProgressFill.style.width = `${fillPct}%`;
    } else {
        if (activeTaskBadge) {
            activeTaskBadge.innerText = "BOŞTA";
            activeTaskBadge.className = "task-badge";
        }
        if (emptyPlaceholder) emptyPlaceholder.style.display = "flex";
        if (runningDetails) runningDetails.style.display = "none";
    }
}

// 4. Son Ödüller & Aktivite Akışı Render
function RenderRecentRewards() {
    const feed = document.getElementById("recentRewardsFeed");
    if (!feed) return;

    const list = currentUIData.recentRewards || [];
    if (list.length === 0) {
        feed.innerHTML = `
            <div class="empty-feed-placeholder">
                <i class="fa-solid fa-inbox"></i>
                <p>Bu oturumda henüz tamamlanmış görev kaydı bulunmuyor.</p>
            </div>
        `;
        return;
    }

    feed.innerHTML = "";
    list.forEach(item => {
        const row = document.createElement("div");
        row.className = "feed-item";
        row.innerHTML = `
            <div class="feed-item-left">
                <div class="feed-icon"><i class="fa-solid fa-check"></i></div>
                <div>
                    <div class="feed-name">${item.taskName}</div>
                    <div class="feed-time">Saat: ${item.time || 'Şimdi'}</div>
                </div>
            </div>
            <div class="feed-item-right">
                <span class="feed-cash">+$${(item.money || 0).toLocaleString()}</span>
                <span class="feed-xp">+${item.xp || 0} XP</span>
            </div>
        `;
        feed.appendChild(row);
    });
}

// 5. Görevler Sekmesi Render
function RenderTasks() {
    const tasksGrid = document.getElementById("tasksListGrid");
    if (!tasksGrid) return;
    tasksGrid.innerHTML = "";

    const taskMetaMap = {
        trash: {
            icon: 'fa-solid fa-recycle text-emerald',
            bg: 'bg-emerald-subtle',
            tag: 'Temizlik & Çevre',
            desc: 'Mahalle konteynerlerini ve cadde kenarlarındaki atıkları temizleyerek şehre katkı sağlayın.'
        },
        road: {
            icon: 'fa-solid fa-road-barrier text-gold',
            bg: 'bg-gold-subtle',
            tag: 'Yol Güvenliği & Bakım',
            desc: 'Çukur onarımı ve duba yerleştirerek yol güvenliğini sağlayın.'
        },
        electric: {
            icon: 'fa-solid fa-bolt-lightning text-cyan',
            bg: 'bg-cyan-subtle',
            tag: 'Yüksek Gerilim & Enerji',
            desc: 'Trafolarda, aydınlatma direklerinde ve panolardaki kritik elektrik arızalarına müdahale edin.'
        }
    };

    const tasks = Array.isArray(currentUIData.tasks) ? currentUIData.tasks : [];
    tasks.forEach(t => {
        const meta = taskMetaMap[t.type] || {
            icon: 'fa-solid fa-wrench text-gold',
            bg: 'bg-gold-subtle',
            tag: 'Kamu Hizmeti',
            desc: 'Belediye tarafından tahsis edilen saha görevini eksiksiz tamamlayın.'
        };

        const isCurrentActive = (currentUIData.currentTaskType === t.type);

        const card = document.createElement("div");
        card.className = `task-card ${isCurrentActive ? 'is-active-task' : ''}`;

        let reqBadge = isCurrentActive
            ? `<span class="task-card-req active-badge"><i class="fa-solid fa-circle-dot"></i> ŞU AN AKTİF</span>`
            : (t.unlocked
                ? `<span class="task-card-req unlocked"><i class="fa-solid fa-lock-open"></i> Seviye ${t.reqLevel}</span>`
                : `<span class="task-card-req locked"><i class="fa-solid fa-lock"></i> Seviye ${t.reqLevel}</span>`);

        let actionBtn = "";
        if (!t.unlocked) {
            actionBtn = `<button class="btn-card-action disabled-locked" disabled><i class="fa-solid fa-lock"></i> Seviye Yetersiz</button>`;
        } else if (isCurrentActive) {
            actionBtn = `<button class="btn-card-action" style="background: var(--cyan); color: #0f141f;" onclick="CancelActiveTaskAction()"><i class="fa-solid fa-ban"></i> Görevi Bırak</button>`;
        } else {
            actionBtn = `<button class="btn-card-action" onclick="StartTaskAction('${t.type}')"><i class="fa-solid fa-play"></i> Göreve Başla</button>`;
        }

        card.innerHTML = `
            <div class="task-card-top">
                <div class="task-card-icon ${meta.bg}">
                    <i class="${meta.icon}"></i>
                </div>
                ${reqBadge}
            </div>

            <div class="task-card-body">
                <h3>${t.name}</h3>
                <p>${meta.desc}</p>
            </div>

            <div class="task-card-specs">
                <div class="spec-chip">
                    <span class="spec-label">Ödül Aralığı</span>
                    <span class="spec-val text-emerald">$${t.rewardMin} - $${t.rewardMax}</span>
                </div>
                <div class="spec-chip">
                    <span class="spec-label">Deneyim</span>
                    <span class="spec-val text-gold">+${t.xpMin}-${t.xpMax} XP</span>
                </div>
                <div class="spec-chip">
                    <span class="spec-label">Nokta Sayısı</span>
                    <span class="spec-val">${t.pointCount || 3} Lokasyon</span>
                </div>
            </div>

            ${actionBtn}
        `;

        tasksGrid.appendChild(card);
    });
}

// 6. Araç Filosu Sekmesi Render
function RenderVehicles() {
    const vehiclesGrid = document.getElementById("vehiclesListGrid");
    const activeVehicleAlert = document.getElementById("activeVehicleAlert");
    if (!vehiclesGrid) return;

    if (currentUIData.hasVehicle) {
        if (activeVehicleAlert) activeVehicleAlert.style.display = "flex";
    } else {
        if (activeVehicleAlert) activeVehicleAlert.style.display = "none";
    }

    vehiclesGrid.innerHTML = "";

    const vehMeta = {
        trash:       { icon: 'fa-solid fa-truck-moving',  bg: 'bg-emerald-subtle', typeText: 'Çöp Toplama',  desc: 'Mahalle konteynerlerini ve cadde kenarlarındaki atıkları toplamak için ağır hizmet kamyonu.' },
        bison:       { icon: 'fa-solid fa-truck-pickup',  bg: 'bg-gold-subtle',    typeText: 'Yol Bakımı',   desc: 'Yollardaki çatlak ve çukur tamirat ekipmanlarıyla donatılmış saha pikabı.' },
        utillitruck: { icon: 'fa-solid fa-truck-monster', bg: 'bg-cyan-subtle',    typeText: 'Elektrik Arızası', desc: 'Hidrolik sepetli yüksek gerilim hat ve aydınlatma direk müdahale kamyonu.' }
    };

    const taskTypeMap = { trash: 'text-emerald', bison: 'text-gold', utillitruck: 'text-cyan' };

    const vehicles = Array.isArray(currentUIData.vehicles) ? currentUIData.vehicles : [];
    vehicles.forEach(veh => {
        const meta = vehMeta[veh.model] || { icon: 'fa-solid fa-truck', bg: 'bg-gold-subtle', typeText: 'Hizmet Aracı', desc: 'Belediye hizmet aracı.' };
        const textColor = taskTypeMap[veh.model] || 'text-gold';

        const isActiveVehicle = currentUIData.hasVehicle;

        const card = document.createElement("div");
        card.className = `task-card ${isActiveVehicle && veh.unlocked ? 'is-active-task' : ''}`;

        let reqBadge = (isActiveVehicle && veh.unlocked)
            ? `<span class="task-card-req active-badge"><i class="fa-solid fa-circle-dot"></i> ŞU AN KULLANIMDA</span>`
            : (veh.unlocked
                ? `<span class="task-card-req unlocked"><i class="fa-solid fa-circle-check"></i> Yetki Var</span>`
                : `<span class="task-card-req locked"><i class="fa-solid fa-lock"></i> Seviye ${veh.reqLevel}</span>`);

        let actionBtn = "";
        if (!veh.unlocked) {
            actionBtn = `<button class="btn-card-action disabled-locked" disabled><i class="fa-solid fa-lock"></i> Seviye Yetersiz</button>`;
        } else if (isActiveVehicle) {
            actionBtn = `<button class="btn-card-action disabled-locked" disabled><i class="fa-solid fa-ban"></i> Araç Kullanımda</button>`;
        } else {
            actionBtn = `<button class="btn-card-action" onclick="SpawnVehicleAction('${veh.model}')"><i class="fa-solid fa-key"></i> Aracı Teslim Al</button>`;
        }

        card.innerHTML = `
            <div class="task-card-top">
                <div class="task-card-icon ${meta.bg}">
                    <i class="${meta.icon} ${textColor}"></i>
                </div>
                ${reqBadge}
            </div>

            <div class="task-card-body">
                <h3>${veh.name}</h3>
                <p>${meta.desc}</p>
            </div>

            <div class="task-card-specs">
                <div class="spec-chip">
                    <span class="spec-label">Görev Türü</span>
                    <span class="spec-val">${meta.typeText}</span>
                </div>
                <div class="spec-chip">
                    <span class="spec-label">Min. Seviye</span>
                    <span class="spec-val">Seviye ${veh.reqLevel}</span>
                </div>
            </div>

            ${actionBtn}
        `;

        vehiclesGrid.appendChild(card);
    });
}


// 7. Kıyafet Odası Sekmesi Render
function RenderUniforms() {
    const uniformsGrid = document.getElementById("uniformsListGrid");
    const activeUniformAlert = document.getElementById("activeUniformAlert");
    if (!uniformsGrid) return;

    if (currentUIData.hasUniform) {
        if (activeUniformAlert) activeUniformAlert.style.display = "flex";
    } else {
        if (activeUniformAlert) activeUniformAlert.style.display = "none";
    }

    uniformsGrid.innerHTML = "";

    const uniMeta = {
        standart: {
            icon: 'fa-solid fa-vest text-gold',
            desc: 'Yüksek görünürlüklü reflektif yelek ve dayanıklı iş tulumu takımı.'
        },
        teknik: {
            icon: 'fa-solid fa-helmet-safety text-cyan',
            desc: 'Teknik donanım kemeri, güvenlik baretli koruyucu saha üniforması.'
        },
        uzman: {
            icon: 'fa-solid fa-user-tie text-purple',
            desc: 'Belediye başmühendis ve uzman kadrosuna özel resmi amirli kıyafeti.'
        }
    };

    const uniforms = Array.isArray(currentUIData.uniforms) ? currentUIData.uniforms : [];
    uniforms.forEach(uni => {
        const meta = uniMeta[uni.id] || {
            icon: 'fa-solid fa-shirt text-gold',
            desc: 'Resmi standart kamu iş kıyafeti.'
        };

        const card = document.createElement("div");
        card.className = "uniform-card";

        let reqBadge = uni.unlocked
            ? `<span class="task-card-req unlocked"><i class="fa-solid fa-circle-check"></i> Yetki Var</span>`
            : `<span class="task-card-req locked"><i class="fa-solid fa-lock"></i> Seviye ${uni.reqLevel}</span>`;

        let actionBtn = "";
        if (!currentUIData.onDuty) {
            actionBtn = `<button class="btn-card-action disabled-locked" disabled><i class="fa-solid fa-clock"></i> Önce Mesaiye Başlayın</button>`;
        } else if (!uni.unlocked) {
            actionBtn = `<button class="btn-card-action disabled-locked" disabled><i class="fa-solid fa-lock"></i> Kilitli</button>`;
        } else if (currentUIData.hasUniform) {
            actionBtn = `<button class="btn-card-action disabled-locked" disabled><i class="fa-solid fa-circle-check"></i> Üniforma Giyili</button>`;
        } else {
            actionBtn = `<button class="btn-card-action" onclick="WearUniformAction('${uni.id}')"><i class="fa-solid fa-person"></i> Üniformayı Kuşan</button>`;
        }

        card.innerHTML = `
            <div class="task-card-top">
                <span class="vc-meta-badge">Resmi Teçhizat</span>
                ${reqBadge}
            </div>

            <div class="vc-icon-wrap">
                <i class="${meta.icon}"></i>
            </div>

            <div class="vc-details">
                <h3>${uni.name}</h3>
                <p style="font-size: 11.5px; color: var(--text-tertiary);">${meta.desc}</p>
            </div>

            ${actionBtn}
        `;

        uniformsGrid.appendChild(card);
    });
}

// 8. Kariyer & Rütbe Yol Haritası Render
function RenderCareer() {
    const heroTitle = document.getElementById("careerHeroTitle");
    const heroCurXp = document.getElementById("careerHeroCurXp");
    const heroTargetXp = document.getElementById("careerHeroTargetXp");
    const heroProgressFill = document.getElementById("careerHeroProgressFill");
    const heroPercent = document.getElementById("careerHeroPercent");
    const heroRemaining = document.getElementById("careerHeroRemainingText");
    const roadmapContainer = document.getElementById("rankRoadmapContainer");

    const base = currentUIData.baseXP || 0;
    const target = currentUIData.nextXP || 150;
    let pct = 0;

    if (currentUIData.isMax) {
        pct = 100;
        if (heroTitle) heroTitle.innerText = `Seviye ${currentUIData.level} - ${currentUIData.levelTitle}`;
        if (heroCurXp) heroCurXp.innerText = currentUIData.xp;
        if (heroTargetXp) heroTargetXp.innerText = "MAKSİMUM";
        if (heroPercent) heroPercent.innerText = "%100 Maksimum Seviye";
        if (heroRemaining) heroRemaining.innerText = "Tüm rütbe ve yetkiler açıldı";
    } else {
        const earned = Math.max(0, currentUIData.xp - base);
        const req = Math.max(1, target - base);
        pct = Math.min(100, Math.max(0, Math.floor((earned / req) * 100)));
        const rem = Math.max(0, target - currentUIData.xp);

        if (heroTitle) heroTitle.innerText = `Seviye ${currentUIData.level} - ${currentUIData.levelTitle}`;
        if (heroCurXp) heroCurXp.innerText = currentUIData.xp;
        if (heroTargetXp) heroTargetXp.innerText = target;
        if (heroPercent) heroPercent.innerText = `%${pct} Tamamlandı`;
        if (heroRemaining) heroRemaining.innerText = `Sonraki kadroya (${currentUIData.nextLevelTitle || 'Terfi'}) ${rem} XP kaldı`;
    }

    if (heroProgressFill) heroProgressFill.style.width = `${pct}%`;

    // 5 Aşamalı Yol Haritası
    if (!roadmapContainer) return;
    roadmapContainer.innerHTML = "";

    const allTiers = [
        { level: 1, xp: 0, title: "Stajyer", desc: "Çöp & Temizlik" },
        { level: 2, xp: 150, title: "İşçi", desc: "Yol & Asfalt" },
        { level: 3, xp: 500, title: "Teknik Personel", desc: "Elektrik Şebekesi" },
        { level: 4, xp: 1200, title: "Kıdemli Personel", desc: "Usta Kadrosu" },
        { level: 5, xp: 2500, title: "Uzman", desc: "Başmühendis" }
    ];

    allTiers.forEach(t => {
        const isCurrent = (t.level === currentUIData.level);
        const isUnlocked = (t.level < currentUIData.level);

        let stateClass = "";
        let iconHtml = `<i class="fa-solid fa-lock"></i>`;

        if (isCurrent) {
            stateClass = "current";
            iconHtml = `<i class="fa-solid fa-star"></i>`;
        } else if (isUnlocked) {
            stateClass = "unlocked";
            iconHtml = `<i class="fa-solid fa-check"></i>`;
        }

        const node = document.createElement("div");
        node.className = `roadmap-node ${stateClass}`;
        node.innerHTML = `
            <div class="node-icon-circle">${iconHtml}</div>
            <span class="node-level-tag">SEVİYE ${t.level}</span>
            <div class="node-title">${t.title}</div>
            <div class="node-xp-req">${t.xp} XP</div>
        `;
        roadmapContainer.appendChild(node);
    });
}

// ==========================================
// AKSİYONLAR VE NUI ÇAĞRILARI
// ==========================================
function CloseMenu() {
    document.getElementById("app").style.display = "none";
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    });
}

function ToggleDutyAction() {
    fetch(`https://${GetParentResourceName()}/toggleDuty`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    });
}

function StartTaskAction(type) {
    playSound('task_start');
    fetch(`https://${GetParentResourceName()}/startTask`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ type: type })
    });
}

function CancelActiveTaskAction() {
    fetch(`https://${GetParentResourceName()}/cancelCurrentTask`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    });
}

function SpawnVehicleAction(model) {
    playSound('click');
    fetch(`https://${GetParentResourceName()}/spawnVehicle`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ model: model })
    });
}

function ReturnVehicleAction() {
    fetch(`https://${GetParentResourceName()}/returnVehicle`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    });
}

function WearUniformAction(id) {
    playSound('click');
    fetch(`https://${GetParentResourceName()}/wearUniform`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ id: id })
    });
}

function ReturnUniformAction() {
    fetch(`https://${GetParentResourceName()}/returnUniform`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    });
}

// ==========================================
// TOAST BİLDİRİM SİSTEMİ
// ==========================================
function ShowToastNotification(text, type) {
    const container = document.getElementById("notifications-container");
    if (!container) return;

    const toast = document.createElement("div");
    toast.className = "toast-item";

    let iconClass = "fa-solid fa-circle-info text-cyan";
    let title = "BİLGİLENDİRME";
    let borderColor = "var(--cyan)";

    if (type === "success") {
        iconClass = "fa-solid fa-circle-check text-emerald";
        title = "BAŞARILI";
        borderColor = "var(--emerald)";
    } else if (type === "error") {
        iconClass = "fa-solid fa-circle-exclamation text-rose";
        title = "UYARI";
        borderColor = "var(--rose)";
    } else if (type === "warning") {
        iconClass = "fa-solid fa-triangle-exclamation text-gold";
        title = "DİKKAT";
        borderColor = "var(--gold)";
    }

    toast.style.borderLeftColor = borderColor;
    toast.innerHTML = `
        <div class="toast-icon"><i class="${iconClass}"></i></div>
        <div class="toast-text-wrap">
            <div class="toast-title" style="color: ${borderColor}">${title}</div>
            <div>${text}</div>
        </div>
    `;

    container.appendChild(toast);

    setTimeout(() => {
        toast.style.animation = "toastFadeOut 0.3s cubic-bezier(0.16, 1, 0.3, 1) forwards";
        setTimeout(() => toast.remove(), 300);
    }, 4500);
}
