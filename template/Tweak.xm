#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <substrate.h>
#include <mach-o/dyld.h>
#include <string.h>
#include <dlfcn.h>
#include <math.h>
#import <objc/runtime.h>

// ============================================================
//  v23.7 - FEW1N MOD MENU
//  DreamRoadMultiplayer | Unity 6 (6000.3.0b1) | Metadata v39
// ------------------------------------------------------------
//  ONEMLI: Oyun Unity 6'ya guncellendi + isim obfuscation eklendi.
//  Tum offsetler YENI dump.cs'ten (metadata v39) cikarilip, uye
//  isimleri karisik oldugu icin YAPIYA/imzaya gore eslendi.
// ============================================================
//  OFFSET TABLE (yeni Unity6 dump, dogrulandi)
// ------------------------------------------------------------
// Time.set_timeScale(float)                -> 0x6771918
// PhotonNetwork.CloseConnection(Player)    -> 0x5938844
// PhotonNetwork.set_NickName(string)       -> 0x5933940
// ChatManager.get_Instance()               -> 0x31A6168
// ChatManager.Send(string)                 -> 0x31A626C
// CarNitro.get_nitroAmount() [obf: fda]    -> 0x54CFE14
// CarNitro.set_nitroAmount(float)[obf: fdb]-> 0x54CFE1C
// CarDriveSystem.Move(f,f,f,f) [obf: fca]  -> 0x54CCAA0
// PlateVariant.Change(PlateHolder)[obf:gal]-> 0x54EA1FC   (c@0x0, t@0x8)
// HR_UI_RoomListLine.Connect() [obf: elv]  -> 0x54B32F4   (password @ self+0x50)
// HR_PhotonLobbyManager.get_Instance()[eke]-> 0x54A8098   (passwordInput@+0x50, passwordOnConnectInput@+0x60)
// TMP_InputField.set_text(string)          -> 0x65F4CC8
// PlayerManager.get_Instance() [obf: ggn]  -> 0x5A2DE20
// PlayerManager.get_Money()    [obf: ggx]  -> 0x5A4346C
// PlayerManager.AddMoney(int)  [obf: ghm]  -> 0x5A43A2C
// PlayerManager.SyncWithServer()[obf: ghj] -> 0x5A2DF80
// PlayerManager.UpdateNicknameInternal(str)[ghn] -> 0x5A3DDD4
// ============================================================

struct PlateHolder { void* c; void* t; };   // c@0x0, t@0x8
typedef struct { float x, y, z; } Vec3;      // Unity Vector3

// ===== PERSIST =====
#define DEF_SUITE @"com.few1n.dreamroadmod"
static NSUserDefaults* defs(void) {
    static NSUserDefaults* d = nil;
    if (!d) d = [[NSUserDefaults alloc] initWithSuiteName:DEF_SUITE] ?: [NSUserDefaults standardUserDefaults];
    return d;
}
static void saveBool(NSString* k, bool v)    { [defs() setBool:v forKey:k]; }
static bool loadBool(NSString* k, bool def)   { return [defs() objectForKey:k] ? [defs() boolForKey:k] : def; }
static void saveInt(NSString* k, int v)       { [defs() setInteger:v forKey:k]; }
static int  loadInt(NSString* k, int def)     { return [defs() objectForKey:k] ? (int)[defs() integerForKey:k] : def; }
static void saveFloat(NSString* k, float v)   { [defs() setFloat:v forKey:k]; }
static float loadFloat(NSString* k, float def) { return [defs() objectForKey:k] ? [defs() floatForKey:k] : def; }
static void saveStr(NSString* k, NSString* v) { if (v) [defs() setObject:v forKey:k]; }
static NSString* loadStr(NSString* k, NSString* def) { NSString* s=[defs() stringForKey:k]; return s?:def; }

// ===== STATE =====
static int  speedMode = 1;
static bool isInfiniteNitroEnabled = false;
static bool isColorChatEnabled = false;
static bool isSpamEnabled = false;
static bool isBypassPasswordEnabled = true;
static bool isCustomPlateEnabled = false;
static bool isAutoMoneyEnabled = false;
static bool isFlyEnabled = false;       // hover (dikey hizi 0 tut -> havada surus)
static bool isLowGravEnabled = false;   // dususu yavaslat (floaty)
static bool isDriftEnabled = false;     // drift modu (kusursuz yan kayma)
static bool isCruiseEnabled = false;    // hiz sabitleyici (cruise control)
static float cruiseSpeedKmh = 180.0f;   // hedef sabit hiz (km/h)
static void* g_rb = NULL;               // arabanin Rigidbody'si (h_driveMove'da yakalanir)
static bool isAsciiAnimEnabled = false; // ASCII animasyon spam
static int  asciiAnimIndex = 0;         // hangi animasyon
static int  asciiFrameIdx = 0;          // mevcut kare
static bool isRoomSpamEnabled = false;  // fake oda spam
static char customRoomName[160] = "\xE3\x80\x90\xE2\x98\x85 \xEF\xBC\xA6\xEF\xBC\xA5\xEF\xBC\xB7\xEF\xBC\x91\xEF\xBC\xAE \xE2\x98\x85\xE3\x80\x91";  // 【★ FEW1N ★】 Unicode (hook gerekmez)
static int  roomSpamPhase = 0;          // 0=kur, 1=cik
static int  roomSpamCount = 0;          // kurulan oda sayaci
static int  roomSpamMaxCount = 0;       // hedef (0 = sinirsiz)
static float roomSpamInterval = 0.4f;   // aralik (sn) - hizli
static int  roomSpamTTL = 300000;       // oda acik kalma (ms)
static bool roomSpamContinuous = true;  // surekli mod
static int  spamStyle = 0;              // 0=duz 1=cerceveli 2=sembol 3=renkli
static char customPlateText[64] = "FEW1N";
static char chatSpamText[128] = "FEW1N MOD MENU!";
static char spamColorHex[8] = "00FFFF";   // chat spam rengi (renkli stilde)
static int  customMoneyAmount = 100000000;
// ==== CHAT OTO-DUYURU (donen banner - herkes gorur) ====
static bool  isAnnounceEnabled = false;
static float announceInterval = 5.0f;
static int   g_announceIdx = 0;
static char  announceText[512] = "FEW1N MOD MENU aktif!\nHerkese selam!\nIyi oyunlar";
// ==== SARKI SOZU -> CHAT (altyazi gibi) ====
static bool isLyricsEnabled = false;
static int  g_lyricsIdx = 0;             // hangi satir
static float lyricsInterval = 2.0f;      // satirlar arasi sn
static bool lyricsColorCycle = true;     // her satiri farkli renk
static bool lyricsLoop = false;          // bitince bastan
static NSMutableArray *g_lyrics = nil;   // satirlar
// ==== ASCII/spam icin renk + isim dongusu (chat spammer gibi) ====
static bool asciiColorCycle = false;     // ASCII spam'i gokkusagi renkte gonder
static int  g_colorIdx = 0;              // donen renk indeksi
// ==== HACKER/PRO MODE ====
static int  nameTrickMode = 0;            // 0=kapali 1=admin 2=mod 3=dev 4=hacker 5=matrix 6=glitch 7=binary
static bool isMatrixChatEnabled = false;  // chat mesajlarini matrix stiline cevir
static bool isGlitchChatEnabled = false;  // chat mesajlarini glitch stiline cevir
static bool isStealthMode = false;        // menuyu gizle, sadece gizli gesture ile ac
static int  stealthTapCount = 0;          // gizli acma icin triple-tap sayaci
static NSDate *stealthLastTap = nil;      // son tap zamani
static bool isRoomMasterHack = false;     // odaya girince master olmaya calis
static int  chatTemplateIdx = 0;          // hazir chat sablonu indeksi

static NSTimer *spamTimer = nil;
static NSTimer *tickTimer = nil;
static NSTimer *asciiTimer = nil;
static NSTimer *lyricsTimer = nil;
static NSTimer *roomSpamTimer = nil;
static NSTimer *nameMarqueeTimer = nil;   // kayan yazi isim / isim dongusu
static NSTimer *announceTimer = nil;      // chat oto-duyuru

// ASCII & Neon Animasyon Setleri (Yuksek Kaliteli Renkli Stiller)
static NSArray* asciiAnims(void) {
    return @[
        // 1. Rainbow FEW1N HACK (Gokkusagi renk degisimi)
        @[@"<color=#FF0000><b>FEW1N HACK</b></color>", @"<color=#FF7F00><b>FEW1N HACK</b></color>",
          @"<color=#FFFF00><b>FEW1N HACK</b></color>", @"<color=#00FF00><b>FEW1N HACK</b></color>",
          @"<color=#00FFFF><b>FEW1N HACK</b></color>", @"<color=#4466FF><b>FEW1N HACK</b></color>",
          @"<color=#FF00FF><b>FEW1N HACK</b></color>"],
        // 2. Neon Matrix (Yesil dijital kod)
        @[@"<color=#00FF00>01001 FEW1N 10110</color>",
          @"<color=#00FF00>10110 FEW1N 01001</color>",
          @"<color=#00FF00>█▓▒░ FEW1N ░▒▓█</color>"],
        // 3. Pulse (Buyuyup kuculen parlak neon)
        @[@"<size=100%><color=#00FFFF><b>FEW1N HACK</b></color></size>",
          @"<size=130%><color=#FF00FF><b>⚡ FEW1N HACK ⚡</b></color></size>",
          @"<size=150%><color=#FFFF00><b>⚡ FEW1N HACK ⚡</b></color></size>",
          @"<size=130%><color=#FF00FF><b>⚡ FEW1N HACK ⚡</b></color></size>"],
        // 4. Ates Efekti (Kirmizi - Turuncu - Sari)
        @[@"<color=#FF0000>🔥 FEW1N 🔥</color>",
          @"<color=#FF6600>🔥 FEW1N HACK 🔥</color>",
          @"<color=#FFCC00>🔥 FEW1N HACK 🔥</color>"],
        // 5. Buz Efekti (Buz mavisi tonlari)
        @[@"<color=#00CCFF>❄ FEW1N ❄</color>",
          @"<color=#66E0FF>❄ FEW1N HACK ❄</color>",
          @"<color=#FFFFFF>❄ FEW1N HACK ❄</color>"],
        // 6. Kalp Atisi (Neon Pembe)
        @[@"<size=90%><color=#FF0055>♥ FEW1N ♥</color></size>",
          @"<size=140%><color=#FF0055>♥ FEW1N HACK ♥</color></size>",
          @"<size=90%><color=#FF0055>♥ FEW1N ♥</color></size>"],
        // 7. Daktilo Neon (Yesil harf harf dolma)
        @[@"<color=#00FF88><b>F</b></color>", @"<color=#00FF88><b>FE</b></color>",
          @"<color=#00FF88><b>FEW</b></color>", @"<color=#00FF88><b>FEW1</b></color>",
          @"<color=#00FF88><b>FEW1N</b></color>", @"<color=#00FF88><b>FEW1N HACK</b></color>"],
        // 8. Glitch Efekti (Mor - Turkuaz - Kirmizi)
        @[@"<color=#FF00FF>F̷E̷W̷1̷N̷</color>", @"<color=#00FFFF>F3W1N HACK</color>", @"<color=#FF0000>FΞW1N HACK</color>", @"<b>FEW1N HACK</b>"],
        // 9. Rainbow Cerceve (Renkli kenarlikli)
        @[@"<color=#FF0000>▐</color><color=#FFFF00> FEW1N HACK </color><color=#00FFFF>▌</color>",
          @"<color=#00FF00>▐</color><color=#FF00FF> FEW1N HACK </color><color=#FF8800>▌</color>"],
        // 10. MEGA EKRAN KAPLAYAN DEV KUTU (Cok satir + Dev Size)
        @[@"<size=160%><color=#FF0000><b>╔══════════════╗\n║  ⚡ FEW1N MOD ⚡  ║\n╚══════════════╝</b></color></size>",
          @"<size=160%><color=#00FFFF><b>╔══════════════╗\n║  ⚡ FEW1N HACK ⚡ ║\n╚══════════════╝</b></color></size>",
          @"<size=160%><color=#FFFF00><b>╔══════════════╗\n║  ⚡ FEW1N MOD ⚡  ║\n╚══════════════╝</b></color></size>"],
        // 11. MEGA MATRIX DUVARI (Ekran kaplayan cok satirli dijital kod)
        @[@"<color=#00FF00><b>0101010101010101010101\n█▓▒░ FEW1N HACK ░▒▓█\n1010101010101010101010</b></color>",
          @"<color=#00FF88><b>1010101010101010101010\n░▒▓█ FEW1N HACK █▓▒░\n0101010101010101010101</b></color>"],
        // 12. FULL MARK RENK KAPLAMA (Arka plani renkli dev banner)
        @[@"<mark=#FF0055AA><size=150%><color=#FFFFFF><b> ★ FEW1N MOD MENU ★ </b></color></size></mark>",
          @"<mark=#00AAFFAA><size=150%><color=#FFFFFF><b> ★ FEW1N MOD MENU ★ </b></color></size></mark>",
          @"<mark=#FFCC00AA><size=150%><color=#000000><b> ★ FEW1N MOD MENU ★ </b></color></size></mark>"],
        // 13. DEV SIMSEKLI NEON KUTU
        @[@"<size=140%><color=#00FFFF><b>⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡\n⚡ FEW1N HACK ⚡\n⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡</b></color></size>",
          @"<size=140%><color=#FF00FF><b>⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡\n⚡ FEW1N HACK ⚡\n⚡⚡⚡⚡⚡⚡⚡⚡⚡⚡</b></color></size>"]
    ];
}

// ===== MATRIX / GLITCH / BINARY ISIM HELPERS =====
static NSString* matrixWrapName(NSString* base) {
    if (!base || base.length == 0) return @"FEW1N";
    NSArray *cols = @[@"#00FF00", @"#00CC00", @"#008800", @"#44FF44", @"#88FF88"];
    NSMutableString *res = [NSMutableString string];
    for (int i = 0; i < (int)base.length; i++) {
        NSString *c = [base substringWithRange:NSMakeRange(i, 1)];
        NSString *col = cols[i % cols.count];
        [res appendFormat:@"<color=%@>%@</color>", col, c];
    }
    return res;
}
static NSString* glitchWrapName(NSString* base) {
    if (!base || base.length == 0) return @"F̷E̷W̷1̷N̷";
    NSArray *glitchChars = @[@"̷", @"̶", @"̲", @"̅", @"̈", @"̇", @"̊", @"̛", @"̣", @"̤"];
    NSMutableString *res = [NSMutableString string];
    for (int i = 0; i < (int)base.length; i++) {
        NSString *c = [base substringWithRange:NSMakeRange(i, 1)];
        [res appendFormat:@"%@%@", c, glitchChars[i % glitchChars.count]];
    }
    return res;
}
static NSString* binaryWrapName(NSString* base) {
    if (!base || base.length == 0) return @"01000110 01000101 01010111 00110001 01001110";
    NSArray *cols = @[@"#00FF00", @"#00FFFF", @"#FF00FF"];
    NSMutableString *res = [NSMutableString string];
    for (int i = 0; i < (int)base.length; i++) {
        unichar ch = [base characterAtIndex:i];
        NSString *bin = @"";
        for (int b = 7; b >= 0; b--) bin = [bin stringByAppendingFormat:@"%d", (ch >> b) & 1];
        NSString *col = cols[i % cols.count];
        [res appendFormat:@"<color=%@>%@</color> ", col, bin];
    }
    return res;
}
static NSString* hackerTagWrap(NSString* base, int mode) {
    switch (mode) {
        case 1: return [NSString stringWithFormat:@"[ADMIN] %@", base];   // Fake Admin
        case 2: return [NSString stringWithFormat:@"[MOD] %@", base];     // Fake Mod
        case 3: return [NSString stringWithFormat:@"[DEV] %@", base];     // Fake Dev
        case 4: return [NSString stringWithFormat:@"⚡ %@ ⚡", base];      // Hacker
        case 5: return matrixWrapName(base);                               // Matrix
        case 6: return glitchWrapName(base);                               // Glitch
        case 7: return binaryWrapName(base);                               // Binary
        default: return base;
    }
}
static NSString* matrixWrapChat(NSString* msg) {
    if (!msg || msg.length == 0) return msg;
    return [NSString stringWithFormat:@"<color=#00FF00><b>[SYSTEM]</b></color> <color=#00CC00>%@</color>", msg];
}
static NSString* glitchWrapChat(NSString* msg) {
    if (!msg || msg.length == 0) return msg;
    return [NSString stringWithFormat:@"<color=#FF00FF><b>[ROOT]</b></color> <color=#00FFFF>%@</color>", msg];
}
static NSArray* chatTemplates(void) {
    return @[
        @"<color=#FF0000><b>SYSTEM BREACH DETECTED</b></color>",
        @"<color=#00FF00><b>HACKED BY FEW1N</b></color>",
        @"<color=#00FFFF><b>ROOT ACCESS GRANTED</b></color>",
        @"<color=#FF00FF><b>INJECTING PAYLOAD...</b></color>",
        @"<color=#FFFF00><b>BACKDOOR ESTABLISHED</b></color>",
        @"<color=#FF0000><size=150%>⚠️ WARNING ⚠️</size></color>",
        @"<color=#00FF00>01000110 01000101 01010111 00110001 01001110</color>",
        @"<color=#00FFFF><b>FEW1N MOD MENU v33.3</b></color>",
        @"<color=#FF00FF><b>PRIVILEGE ESCALATION COMPLETE</b></color>",
        @"<color=#00FF00><b>SERVER UNDER CONTROL</b></color>",
        @"<color=#FF0000><b>UNAUTHORIZED ACCESS</b></color>",
        @"<color=#FFFF00><b>TOP SECRET - CLASSIFIED</b></color>"
    ];
}
static void* (*cached_il2cpp_string_new)(const char*) = NULL;
static uintptr_t global_base = 0;
static int hookSuccessCount = 0;
static int hookFailCount = 0;

// ===== EKRAN LOGU (menude gosterilir) =====
static NSMutableArray<NSString*>* gLog = nil;
static void FLog(NSString* line) {
    if (!line) return;
    NSLog(@"[FEW1N] %@", line);
    if (!gLog) gLog = [NSMutableArray new];
    [gLog addObject:line];
    if (gLog.count > 250) [gLog removeObjectAtIndex:0];
}

// ===== IL2CPP API (iGameGod tarzi - isimle bul, runtime_invoke ile cagir) =====
static void* (*i_domain_get)(void) = NULL;
static void** (*i_domain_get_assemblies)(void*, unsigned long*) = NULL;
static const void* (*i_assembly_get_image)(void*) = NULL;
static void* (*i_class_from_name)(const void*, const char*, const char*) = NULL;
static void* (*i_class_get_method_from_name)(void*, const char*, int) = NULL;
static void* (*i_runtime_invoke)(void*, void*, void**, void**) = NULL;
static void* (*i_thread_attach)(void*) = NULL;
static void* (*i_domain_get_ptr)(void) = NULL;
static void* g_mSetTS = NULL;   // set_timeScale MethodInfo*
static void* g_mGetTS = NULL;   // get_timeScale MethodInfo*
static void* g_mRbGetVel = NULL; // Rigidbody.get_linearVelocity MethodInfo*
static void* g_mRbSetVel = NULL; // Rigidbody.set_linearVelocity MethodInfo*
static void* g_mRbGetPos = NULL; // Rigidbody.get_position MethodInfo*  (isinlanma icin)
static void* g_mRbSetPos = NULL; // Rigidbody.set_position MethodInfo*
static void* g_mSetRichText = NULL; // TMP_Text.set_richText MethodInfo* (oda ismi rich text acigi)
static void* (*i_object_new)(void*) = NULL;   // il2cpp_object_new
static void* g_roomOptionsClass = NULL;       // Photon.Realtime.RoomOptions Il2CppClass*
static bool  g_il2cppReady = false;
// ==== ESP (Camera + tum arabalar) ====
static void* g_mCamGetMain = NULL;     // UnityEngine.Camera.get_main
static void* g_mWorldToScreen = NULL;  // Camera.WorldToScreenPoint(Vector3)->Vector3
static void* g_mFindObjectsPlural = NULL; // Object.FindObjectsOfType(Type)->array (TUM nesneler)
static bool  isEspEnabled = false;
// ==== PLAKA (il2cpp ile zorla - hook olu) ====
static void* g_mTmpSetText = NULL;     // TMP_Text.set_text(string)
static void* g_plateTypeObj = NULL;    // typeof(PlateVariant)
// ==== SIFRE KIRICI (RoomListLine.password client'ta) ====
static void* g_roomLineType = NULL;    // typeof(HR_UI_RoomListLine)
// ==== RIGIDBODY YEDEK YOLU (CarDriveSystem bulunamazsa kameraya en yakin arac) ====
static void* g_rbTypeObj = NULL;       // typeof(UnityEngine.Rigidbody)
static void* g_mCompGetTransform = NULL; // Component.get_transform
static void* g_mTransGetPos = NULL;    // Transform.get_position -> Vector3
static void* g_mGetCompInParent = NULL; // Component.GetComponentInParent(Type,bool)
// ==== PHOTONVIEW.IsMine = KESIN "benim arabam" ayrimi ====
static void* g_photonViewType = NULL;  // typeof(Photon.Pun.PhotonView)
static void* g_mIsMine = NULL;         // PhotonView.get_IsMine -> bool (KULLANILMIYOR - cokuyordu)
static void* g_fIsMine = NULL;         // PhotonView.<IsMine>k__BackingField (FieldInfo)
static int   g_isMineOff = 0;          // IsMine byte offset @0x68 (dogrudan okuma - cokme YOK)
static void* g_fOwner = NULL;          // PhotonView.<Owner>k__BackingField (FieldInfo)
static int   g_pvOwnerOff = 0;         // Owner (Player*) byte offset @0x80 (isim icin)
// ==== GODMODE (HR_PlayerHandler.canCrash=false -> hic kaza yapma) ====
static void* g_playerHandlerType = NULL;   // typeof(HR_PlayerHandler)
static void* g_myPlayerHandler = NULL;     // benim handler (PhotonView@0xB8.IsMine)
static void* g_myRccp = NULL;              // RCCP_CarController (handler@0x20) - ucus girdi (throttle@0x168 steer@0x170)
static bool  isGodmode = false;
// ==== UCUS SURUS (RCCP girdi + forward + acisal hiz) ====
static void* g_mTransGetFwd = NULL;        // Transform.get_forward -> Vector3
static void* g_mRbSetAngVel = NULL;        // Rigidbody.set_angularVelocity(Vector3)
static float flyDriveSpeed = 45.0f;        // ucusta ileri itme hizi
// ==== SELEKTOR (RCCP_Lights.highBeamHeadlights@0x41 hizli ac/kapat) ====
static void* g_rccpLightsType = NULL;      // typeof(RCCP_Lights)
static void* g_myLights = NULL;            // benim RCCP_Lights (g_rb'ye en yakin)
static bool  isSelektor = false;
static int   g_selTick = 0;
static int   g_selFlashRate = 1;   // yariperiyot frame sayisi (1=en hizli strobe, buyudukce yavas)
// ==== YENI HAVALI HACKLER ====
static void* g_mRbSetDetect = NULL;    // Rigidbody.set_detectCollisions (no-clip)
static void* g_mRbUseGrav = NULL;      // Rigidbody.set_useGravity (anti-grav)
// ==== ARAC RENGI (Renderer.material.color) ====
typedef struct { float r, g, b, a; } Color4;
static void* g_rendererType = NULL;    // typeof(UnityEngine.Renderer)
static void* g_mGetCompsChild = NULL;  // Component.GetComponentsInChildren(Type,bool)
static void* g_mRendGetMat = NULL;     // Renderer.get_material
static void* g_mMatSetColor = NULL;    // Material.set_color(Color)
static bool  isCarColorEnabled = false;
static bool  carColorRainbow = true;   // true=RGB dongu, false=sabit renk
static float g_carHue = 0.0f;
static Color4 g_carColor = {1.0f, 0.0f, 0.0f, 1.0f};   // sabit renk (kirmizi)
static void* g_carMats[96]; static int g_carMatCount = 0;  // materyal onbellegi
static bool  isNoClip = false;         // hayalet mod (duvardan gec)
static bool  isAntiGrav = false;       // yercekimi kapali (ay modu)
// ==== ARAC BOYUTU (g_rb transformunu olcekle) ====
static void* g_mTransSetScale = NULL;  // Transform.set_localScale(Vector3)
static bool  isCarSizeEnabled = false;
static float carSizeVal = 1.0f;        // 0.3 - 5.0
static bool  isSpeedHud = false;       // hiz gostergesi HUD
static bool  g_noClipApplied = false;  // durum takibi (surekli set etmemek icin)
static bool  g_antiGravApplied = false;
static float g_hudSpeed = 0, g_hudRPM = 0; static int g_hudGear = 0;
// ==== ARAC DEGISTIRME (hooksuz, il2cpp singleton uzerinden) ====
// HR_MainMenuHandler: static field 'iiz' = singleton
// metodlar: SelectCar / PositiveCarIndex / NegativeCarIndex / BuyCar
static void* (*i_class_get_field_from_name)(void*, const char*) = NULL;
static void  (*i_field_static_get_value)(void*, void*) = NULL;
static size_t (*i_field_get_offset)(void*) = NULL;
static void* g_mmhClass   = NULL;   // HR_MainMenuHandler Il2CppClass*
static void* g_mmhField   = NULL;   // 'iiz' static field
static void* g_mSelectCar = NULL;
static void* g_mNextCar   = NULL;
static void* g_mPrevCar   = NULL;
// ==== HOOKSUZ ARABA BULMA ====
// MSHookFunction bu oyunda calismiyor (0 OK / 17 FAIL) -> hook yerine
// UnityEngine.Object.FindObjectOfType(Type) ile arabayi her saniye ARIYORUZ.
static void* (*i_class_get_type)(void*) = NULL;
static void* (*i_type_get_object)(void*) = NULL;
// Sinif adiyla tarama (namespace tahmini gerektirmez - en saglam yol)
static size_t (*i_image_get_class_count)(const void*) = NULL;
static const void* (*i_image_get_class)(const void*, size_t) = NULL;
static const char* (*i_class_get_name)(void*) = NULL;
// Bir image'da verilen isimdeki sinifi TARAYARAK bul (obfuscation'a dayanikli)
static long g_classScanned = 0;   // teshis: kac sinif tarandi
static void* few1n_findClassByName(const void* img, const char* wantName) {
    if (!i_image_get_class_count || !i_image_get_class || !i_class_get_name) return NULL;
    size_t cnt = 0;
    @try { cnt = i_image_get_class_count(img); } @catch (...) { return NULL; }
    if (cnt == 0 || cnt > 200000) return NULL;
    for (size_t k = 0; k < cnt; k++) {
        // HER sinifi ayri koru: bir bozuk sinif tum taramayi iptal etmesin
        @try {
            void* cls = (void*)i_image_get_class(img, k);
            if (!cls) continue;
            const char* nm = i_class_get_name(cls);
            g_classScanned++;
            if (nm && strcmp(nm, wantName) == 0) return cls;
        } @catch (...) { continue; }
    }
    return NULL;
}
// Sinif -> System.Type nesnesi (FindObjectOfType icin)
static void* few1n_typeObjOf(void* cls) {
    if (!cls || !i_class_get_type || !i_type_get_object) return NULL;
    @try {
        void* t = i_class_get_type(cls);
        if (t) return i_type_get_object(t);
    } @catch (...) {}
    return NULL;
}
static void* g_mFindObjectOfType = NULL;   // UnityEngine.Object.FindObjectOfType(Type)
static void* g_mFindObjInactive  = NULL;   // FindObjectOfType(Type, bool includeInactive)
static void* g_mFindAnyByType    = NULL;   // FindAnyObjectByType(Type)
static void* g_carDriveTypeObj   = NULL;   // typeof(CarDriveSystem)
static void* g_carInputTypeObj   = NULL;   // typeof(CarPlayerInput)

static void few1n_initIl2cpp(void) {
    i_domain_get                = (void*(*)(void))dlsym(RTLD_DEFAULT, "il2cpp_domain_get");
    i_domain_get_assemblies     = (void**(*)(void*,unsigned long*))dlsym(RTLD_DEFAULT, "il2cpp_domain_get_assemblies");
    i_assembly_get_image        = (const void*(*)(void*))dlsym(RTLD_DEFAULT, "il2cpp_assembly_get_image");
    i_class_from_name           = (void*(*)(const void*,const char*,const char*))dlsym(RTLD_DEFAULT, "il2cpp_class_from_name");
    i_class_get_method_from_name= (void*(*)(void*,const char*,int))dlsym(RTLD_DEFAULT, "il2cpp_class_get_method_from_name");
    i_runtime_invoke            = (void*(*)(void*,void*,void**,void**))dlsym(RTLD_DEFAULT, "il2cpp_runtime_invoke");
    i_thread_attach             = (void*(*)(void*))dlsym(RTLD_DEFAULT, "il2cpp_thread_attach");
    i_object_new                = (void*(*)(void*))dlsym(RTLD_DEFAULT, "il2cpp_object_new");
    i_class_get_field_from_name = (void*(*)(void*,const char*))dlsym(RTLD_DEFAULT, "il2cpp_class_get_field_from_name");
    i_field_static_get_value    = (void(*)(void*,void*))dlsym(RTLD_DEFAULT, "il2cpp_field_static_get_value");
    i_field_get_offset          = (size_t(*)(void*))dlsym(RTLD_DEFAULT, "il2cpp_field_get_offset");
    i_class_get_type            = (void*(*)(void*))dlsym(RTLD_DEFAULT, "il2cpp_class_get_type");
    i_type_get_object           = (void*(*)(void*))dlsym(RTLD_DEFAULT, "il2cpp_type_get_object");
    i_image_get_class_count     = (size_t(*)(const void*))dlsym(RTLD_DEFAULT, "il2cpp_image_get_class_count");
    i_image_get_class           = (const void*(*)(const void*,size_t))dlsym(RTLD_DEFAULT, "il2cpp_image_get_class");
    i_class_get_name            = (const char*(*)(void*))dlsym(RTLD_DEFAULT, "il2cpp_class_get_name");
    if (!i_domain_get || !i_domain_get_assemblies || !i_assembly_get_image ||
        !i_class_from_name || !i_class_get_method_from_name || !i_runtime_invoke) {
        FLog(@"il2cpp API bulunamadi!"); return;
    }
    void* domain = i_domain_get();
    if (i_thread_attach && domain) i_thread_attach(domain);   // bu thread'i il2cpp'e bagla
    unsigned long n = 0;
    void** asms = i_domain_get_assemblies(domain, &n);
    FLog([NSString stringWithFormat:@"il2cpp: %lu assembly taraniyor", n]);
    for (unsigned long i = 0; i < n; i++) {
        const void* img = i_assembly_get_image(asms[i]);
        if (!img) continue;
        if (!g_mSetTS) {
            void* timeClass = i_class_from_name(img, "UnityEngine", "Time");
            if (timeClass) {
                g_mSetTS = i_class_get_method_from_name(timeClass, "set_timeScale", 1);
                g_mGetTS = i_class_get_method_from_name(timeClass, "get_timeScale", 0);
                FLog([NSString stringWithFormat:@"Time bulundu! set=%p get=%p", g_mSetTS, g_mGetTS]);
            }
        }
        // UnityEngine.Object.FindObjectOfType(Type) - hooksuz arama icin
        if (!g_mFindObjectOfType) {
            void* oc = i_class_from_name(img, "UnityEngine", "Object");
            if (oc) {
                g_mFindObjectOfType = i_class_get_method_from_name(oc, "FindObjectOfType", 1);
                g_mFindObjInactive  = i_class_get_method_from_name(oc, "FindObjectOfType", 2);
                g_mFindAnyByType    = i_class_get_method_from_name(oc, "FindAnyObjectByType", 1);
                g_mFindObjectsPlural= i_class_get_method_from_name(oc, "FindObjectsOfType", 1); // cogul -> array
                FLog([NSString stringWithFormat:@"Bulucular: tek=%p cogul=%p any=%p",
                      g_mFindObjectOfType, g_mFindObjectsPlural, g_mFindAnyByType]);
            }
        }
        // ESP - Camera metodlari
        if (!g_mCamGetMain) {
            void* cc = i_class_from_name(img, "UnityEngine", "Camera");
            if (cc) {
                g_mCamGetMain    = i_class_get_method_from_name(cc, "get_main", 0);
                g_mWorldToScreen = i_class_get_method_from_name(cc, "WorldToScreenPoint", 1);
                FLog([NSString stringWithFormat:@"Camera: main=%p w2s=%p", g_mCamGetMain, g_mWorldToScreen]);
            }
        }
        // typeof(CarDriveSystem) - once namespace ile, olmazsa SINIF TARAYARAK (obfuscation'a dayanikli)
        if (!g_carDriveTypeObj) {
            void* c = i_class_from_name(img, "TurnTheGameOn.IKAvatarDriver", "CarDriveSystem");
            if (!c) c = i_class_from_name(img, "TurnTheGameOn", "CarDriveSystem");
            if (!c) c = i_class_from_name(img, "", "CarDriveSystem");
            if (!c) c = few1n_findClassByName(img, "CarDriveSystem");   // tam tarama
            if (c) {
                g_carDriveTypeObj = few1n_typeObjOf(c);
                FLog([NSString stringWithFormat:@"CarDriveSystem: sinif=%p tipNesnesi=%p", c, g_carDriveTypeObj]);
            }
        }
        if (!g_carInputTypeObj) {
            void* c = i_class_from_name(img, "TurnTheGameOn.IKAvatarDriver", "CarPlayerInput");
            if (!c) c = i_class_from_name(img, "", "CarPlayerInput");
            if (!c) c = few1n_findClassByName(img, "CarPlayerInput");
            if (c) g_carInputTypeObj = few1n_typeObjOf(c);
        }
        if (!g_mmhClass) {
            void* c = i_class_from_name(img, "", "HR_MainMenuHandler");
            if (c) {
                g_mmhClass   = c;
                g_mSelectCar = i_class_get_method_from_name(c, "SelectCar", 0);
                g_mNextCar   = i_class_get_method_from_name(c, "PositiveCarIndex", 0);
                g_mPrevCar   = i_class_get_method_from_name(c, "NegativeCarIndex", 0);
                if (i_class_get_field_from_name) g_mmhField = i_class_get_field_from_name(c, "iiz");
                FLog([NSString stringWithFormat:@"MainMenuHandler bulundu! sec=%p ileri=%p geri=%p singleton=%p",
                      g_mSelectCar, g_mNextCar, g_mPrevCar, g_mmhField]);
            }
        }
        if (!g_mRbSetVel) {
            void* rbClass = i_class_from_name(img, "UnityEngine", "Rigidbody");
            if (rbClass) {
                // Unity6: linearVelocity (yeni). Eski velocity de denenir.
                g_mRbGetVel = i_class_get_method_from_name(rbClass, "get_linearVelocity", 0);
                g_mRbSetVel = i_class_get_method_from_name(rbClass, "set_linearVelocity", 1);
                if (!g_mRbSetVel) {
                    g_mRbGetVel = i_class_get_method_from_name(rbClass, "get_velocity", 0);
                    g_mRbSetVel = i_class_get_method_from_name(rbClass, "set_velocity", 1);
                }
                g_mRbGetPos = i_class_get_method_from_name(rbClass, "get_position", 0);
                g_mRbSetPos = i_class_get_method_from_name(rbClass, "set_position", 1);
                g_mRbSetAngVel = i_class_get_method_from_name(rbClass, "set_angularVelocity", 1);  // ucus donme
                g_mRbSetDetect = i_class_get_method_from_name(rbClass, "set_detectCollisions", 1);  // no-clip
                g_mRbUseGrav   = i_class_get_method_from_name(rbClass, "set_useGravity", 1);        // anti-grav
                g_rbTypeObj = few1n_typeObjOf(rbClass);   // FindObjectsOfType(Rigidbody) yedek yolu icin
                FLog([NSString stringWithFormat:@"Rigidbody bulundu! get=%p set=%p tip=%p", g_mRbGetVel, g_mRbSetVel, g_rbTypeObj]);
            }
        }
        if (!g_mCompGetTransform) {
            void* cmp = i_class_from_name(img, "UnityEngine", "Component");
            if (cmp) {
                g_mCompGetTransform = i_class_get_method_from_name(cmp, "get_transform", 0);
                g_mGetCompsChild    = i_class_get_method_from_name(cmp, "GetComponentsInChildren", 2); // (Type,bool)
                g_mGetCompInParent  = i_class_get_method_from_name(cmp, "GetComponentInParent", 2);     // (Type,bool)
            }
        }
        if (!g_rendererType) {
            void* rc = i_class_from_name(img, "UnityEngine", "Renderer");
            if (rc) { g_rendererType = few1n_typeObjOf(rc); g_mRendGetMat = i_class_get_method_from_name(rc, "get_material", 0); }
        }
        if (!g_mMatSetColor) {
            void* mc = i_class_from_name(img, "UnityEngine", "Material");
            if (mc) g_mMatSetColor = i_class_get_method_from_name(mc, "set_color", 1);
        }
        if (!g_mTransGetPos) {
            void* tr = i_class_from_name(img, "UnityEngine", "Transform");
            if (tr) { g_mTransGetPos = i_class_get_method_from_name(tr, "get_position", 0);
                      g_mTransSetScale = i_class_get_method_from_name(tr, "set_localScale", 1);
                      g_mTransGetFwd = i_class_get_method_from_name(tr, "get_forward", 0); }
        }
        if (!g_mSetRichText) {
            void* tmpClass = i_class_from_name(img, "TMPro", "TMP_Text");
            if (tmpClass) {
                g_mSetRichText = i_class_get_method_from_name(tmpClass, "set_richText", 1);
                g_mTmpSetText  = i_class_get_method_from_name(tmpClass, "set_text", 1);
                FLog([NSString stringWithFormat:@"TMP_Text bulundu! set_richText=%p set_text=%p", g_mSetRichText, g_mTmpSetText]);
            }
        }
        if (!g_plateTypeObj) {
            void* pc = i_class_from_name(img, "", "PlateVariant");
            if (!pc) pc = few1n_findClassByName(img, "PlateVariant");
            if (pc) { g_plateTypeObj = few1n_typeObjOf(pc); FLog([NSString stringWithFormat:@"PlateVariant tipi=%p", g_plateTypeObj]); }
        }
        if (!g_roomLineType) {
            void* rc = i_class_from_name(img, "", "HR_UI_RoomListLine");
            if (!rc) rc = few1n_findClassByName(img, "HR_UI_RoomListLine");
            if (rc) { g_roomLineType = few1n_typeObjOf(rc); FLog([NSString stringWithFormat:@"RoomListLine tipi=%p", g_roomLineType]); }
        }
        if (!g_photonViewType) {
            void* pv = i_class_from_name(img, "Photon.Pun", "PhotonView");
            if (!pv) pv = few1n_findClassByName(img, "PhotonView");
            if (pv) { g_photonViewType = few1n_typeObjOf(pv);
                      // Field-read: metod cagirmadan alanlari dogrudan hafizadan oku (cokme YOK)
                      if (i_class_get_field_from_name) {
                          g_fIsMine = i_class_get_field_from_name(pv, "<IsMine>k__BackingField");
                          g_fOwner  = i_class_get_field_from_name(pv, "<Owner>k__BackingField");
                      }
                      if (g_fIsMine && i_field_get_offset) g_isMineOff  = (int)i_field_get_offset(g_fIsMine);
                      if (g_fOwner  && i_field_get_offset) g_pvOwnerOff = (int)i_field_get_offset(g_fOwner);
                      FLog([NSString stringWithFormat:@"PhotonView tipi=%p IsMineOff=%d OwnerOff=%d", g_photonViewType, g_isMineOff, g_pvOwnerOff]); }
        }
        if (!g_playerHandlerType) {
            void* ph = i_class_from_name(img, "", "HR_PlayerHandler");
            if (!ph) ph = few1n_findClassByName(img, "HR_PlayerHandler");
            if (ph) { g_playerHandlerType = few1n_typeObjOf(ph); FLog([NSString stringWithFormat:@"HR_PlayerHandler tipi=%p (godmode)", g_playerHandlerType]); }
        }
        if (!g_rccpLightsType) {
            void* rl = i_class_from_name(img, "", "RCCP_Lights");
            if (!rl) rl = few1n_findClassByName(img, "RCCP_Lights");
            if (rl) { g_rccpLightsType = few1n_typeObjOf(rl); FLog([NSString stringWithFormat:@"RCCP_Lights tipi=%p (selektor)", g_rccpLightsType]); }
        }
        if (!g_roomOptionsClass) {
            void* roc = i_class_from_name(img, "Photon.Realtime", "RoomOptions");
            if (roc) { g_roomOptionsClass = roc; FLog([NSString stringWithFormat:@"RoomOptions bulundu! %p", roc]); }
        }
        // ONEMLI: araba tipleri de bulunana kadar DURMA (ayri assembly'de olabilir)
        if (g_mSetTS && g_mRbSetVel && g_mSetRichText && g_roomOptionsClass &&
            g_carDriveTypeObj && g_carInputTypeObj && g_mCamGetMain) break;
    }
    g_il2cppReady = (g_mSetTS != NULL);
    FLog([NSString stringWithFormat:@"il2cpp bitti: carTip=%@ inputTip=%@ (taranan sinif=%ld)",
          g_carDriveTypeObj ? @"VAR" : @"YOK", g_carInputTypeObj ? @"VAR" : @"YOK", g_classScanned]);
    if (!g_il2cppReady) FLog(@"UnityEngine.Time bulunamadi");
}

// TMP_Text.richText = true  (Unity rich text acigini geri ac)
static void setRichTextIl(void* tmp, bool on) {
    if (!i_runtime_invoke || !g_mSetRichText || !tmp) return;
    bool val = on;
    void* params[1] = { &val };
    i_runtime_invoke(g_mSetRichText, tmp, params, NULL);
}

// Rigidbody ham Injected pointer'lari (rbGetVelIl/rbSetVelIl yedegi olarak kullanilir)
static void (*rb_getVel)(void* self, Vec3* out) = NULL;   // get_linearVelocity_Injected
static void (*rb_setVel)(void* self, Vec3* val) = NULL;   // set_linearVelocity_Injected
static void (*rb_getPos)(void* self, Vec3* out) = NULL;   // get_position_Injected
static void (*rb_setPos)(void* self, Vec3* val) = NULL;   // set_position_Injected

// Rigidbody linearVelocity - il2cpp runtime_invoke ile (ham offset degil)
static void rbGetVelIl(void* rb, Vec3* out) {
    out->x = out->y = out->z = 0;
    if (!rb) return;
    if (i_runtime_invoke && g_mRbGetVel) {
        void* box = i_runtime_invoke(g_mRbGetVel, rb, NULL, NULL);   // boxed Vector3
        if (box) { *out = *(Vec3*)((uintptr_t)box + 0x10); return; }
    }
    if (rb_getVel) rb_getVel(rb, out);   // yedek: ham Injected
}
static void rbSetVelIl(void* rb, Vec3* v) {
    if (!rb) return;
    if (i_runtime_invoke && g_mRbSetVel) {
        void* params[1] = { v };
        i_runtime_invoke(g_mRbSetVel, rb, params, NULL);
        return;
    }
    if (rb_setVel) rb_setVel(rb, v);     // yedek: ham Injected
}
static void rbSetAngVelIl(void* rb, Vec3* v) {   // acisal hiz (ucusta yaw donme)
    if (!rb || !i_runtime_invoke || !g_mRbSetAngVel) return;
    void* params[1] = { v };
    i_runtime_invoke(g_mRbSetAngVel, rb, params, NULL);
}

// Rigidbody position - il2cpp runtime_invoke (ham cagri yedek)
static void rbGetPosIl(void* rb, Vec3* out) {
    out->x = out->y = out->z = 0;
    if (!rb) return;
    if (i_runtime_invoke && g_mRbGetPos) {
        void* box = i_runtime_invoke(g_mRbGetPos, rb, NULL, NULL);   // boxed Vector3
        if (box) { *out = *(Vec3*)((uintptr_t)box + 0x10); return; }
    }
    if (rb_getPos) rb_getPos(rb, out);
}
static void rbSetPosIl(void* rb, Vec3* v) {
    if (!rb) return;
    if (i_runtime_invoke && g_mRbSetPos) {
        void* params[1] = { v };
        i_runtime_invoke(g_mRbSetPos, rb, params, NULL);
        return;
    }
    if (rb_setPos) rb_setPos(rb, v);
}

static void setTimeScaleVal(float v) {
    if (!i_runtime_invoke || !g_mSetTS) return;
    float val = v;
    void* params[1] = { &val };
    i_runtime_invoke(g_mSetTS, NULL, params, NULL);
}
static float getTimeScaleVal(void) {
    if (!i_runtime_invoke || !g_mGetTS) return -1.0f;
    void* box = i_runtime_invoke(g_mGetTS, NULL, NULL, NULL);   // boxed float
    if (!box) return -1.0f;
    return *(float*)((uintptr_t)box + 0x10);                    // unbox
}

static void* mkStr(NSString* s) {
    if (!cached_il2cpp_string_new)
        cached_il2cpp_string_new = (void*(*)(const char*))dlsym(RTLD_DEFAULT, "il2cpp_string_new");
    if (!cached_il2cpp_string_new || !s) return NULL;
    return cached_il2cpp_string_new(s.UTF8String);
}
static NSString* readStr(void* il2s) {
    if (!il2s) return @"";
    @try {
        int32_t len = *(int32_t*)((uintptr_t)il2s + 0x10);
        if (len <= 0 || len > 4096) return @"";
        return [NSString stringWithCharacters:(unichar*)((uintptr_t)il2s + 0x14) length:len];
    } @catch (...) { return @""; }
}
// Substrate calisiyor mu? Bagli sembol bos stub olabilir -> dlsym ile gercegini ara.
typedef void (*MSHookFn)(void*, void*, void**);
static MSHookFn g_msHook = NULL;
static bool g_msHookChecked = false;
static void few1n_probeSubstrate(void) {
    if (g_msHookChecked) return;
    g_msHookChecked = true;
    // Substrate / ElleKit / libhooker isimlerini sirayla dene
    g_msHook = (MSHookFn)dlsym(RTLD_DEFAULT, "MSHookFunction");
    if (g_msHook) { FLog([NSString stringWithFormat:@"Substrate VAR: MSHookFunction=%p", (void*)g_msHook]); return; }
    g_msHook = (MSHookFn)dlsym(RTLD_DEFAULT, "LHHookFunctions");   // libhooker
    if (g_msHook) { FLog(@"libhooker bulundu (LHHookFunctions)"); return; }
    void* ek = dlopen("/var/jb/usr/lib/libellekit.dylib", RTLD_LAZY);
    if (!ek) ek = dlopen("/usr/lib/libsubstrate.dylib", RTLD_LAZY);
    if (ek) {
        g_msHook = (MSHookFn)dlsym(ek, "MSHookFunction");
        FLog(g_msHook ? @"ElleKit/Substrate dylib ile yuklendi" : @"dylib acildi ama MSHookFunction yok");
        return;
    }
    FLog(@"SUBSTRATE YOK! Hicbir hook motoru bulunamadi -> il2cpp yolu kullaniliyor");
}

static bool g_hooksDead = false;   // ilk hook yazilamadiysa kalanlari deneme (temiz + hizli acilis)
static void safeHook(void* target, void* replacement, void** original, const char* name) {
    NSString* nm = [NSString stringWithUTF8String:name];
    if (!target) { FLog([@"SKIP (NULL) " stringByAppendingString:nm]); hookFailCount++; return; }
    // Bir kez basarisiz olduysa MSHookFunction'i tekrar cagirma - hepsi ayni motoru kullanir
    if (g_hooksDead) { hookFailCount++; return; }
    if (original) *original = NULL;
    few1n_probeSubstrate();
    // Ilk hookta base'in gercekten Mach-O basi olup olmadigini dogrula.
    // Base yanlissa hedef adres cop olur ve MSHookFunction sessizce basarisiz olur.
    static bool baseChecked = false;
    if (!baseChecked) {
        baseChecked = true;
        @try {
            uint32_t magic = *(uint32_t*)global_base;
            FLog([NSString stringWithFormat:@"Base kontrol: magic=0x%08X %@",
                  magic, (magic == 0xFEEDFACF) ? @"(GECERLI Mach-O)" : @"(GECERSIZ! base yanlis)"]);
            uint32_t insn = *(uint32_t*)target;   // hedefteki ilk ARM64 komutu
            FLog([NSString stringWithFormat:@"Hedef ilk komut: 0x%08X %@",
                  insn, (insn != 0 && insn != 0xFFFFFFFF) ? @"(kod gibi)" : @"(BOS! adres yanlis)"]);
        } @catch (...) { FLog(@"Base/hedef okunamadi - adres gecersiz"); }
    }
    if (g_msHook) g_msHook(target, replacement, original);   // dlsym ile bulunan gercek motor
    else MSHookFunction(target, replacement, original);      // bagli sembol (stub olabilir)
    // GERCEK dogrulama: MSHookFunction basarili olursa *original orijinal koda isaret eder.
    // Sideload'da (Substrate yok) MSHookFunction sessizce hicbir sey yapmaz -> *original NULL kalir.
    if (original && *original == NULL) {
        FLog([NSString stringWithFormat:@"FAIL (hook yazilamadi) %@", nm]);
        hookFailCount++;
        if (!g_hooksDead) { g_hooksDead = true; FLog(@">> Hooklar bu ortamda yazilamiyor, kalanlar atlaniyor. il2cpp yolu aktif."); }
        return;
    }
    FLog([NSString stringWithFormat:@"OK  %@", nm]);
    hookSuccessCount++;
}
static UIWindow* getKeyWindow(void) {
    if (@available(iOS 15.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive &&
                [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                for (UIWindow *win in ws.windows) if (win.isKeyWindow) return win;
                if (ws.windows.count > 0) return ws.windows.firstObject;
            }
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIWindow *w = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
    if (w) return w;
    NSArray<UIWindow *> *wins = [UIApplication sharedApplication].windows;
    for (UIWindow *win in wins) if (win.isKeyWindow) return win;
    return wins.firstObject;
}

// ===== FUNCTION POINTERS =====
static void* (*chatGetInst)(void) = NULL;
static void  (*chatSend)(void* self, void* msg) = NULL;
static void  (*tmp_set_text)(void* self, void* msg) = NULL;
static void* (*tmp_get_text)(void* self) = NULL;   // TMP_InputField.get_text
static void* (*rinfo_getName)(void* self) = NULL;  // RoomInfo.get_Name (ham oda ismi)
static void  (*pn_setNickName)(void* name) = NULL;
static void* (*lobbyGetInst)(void) = NULL;
static void* (*playerManagerGetInst)(void) = NULL;
static void  (*pm_updateNicknameInternal)(void* self, void* newName) = NULL;
static int   (*pm_getMoney)(void* self) = NULL;
static void  (*pm_syncWithServer)(void* self) = NULL;
static void  (*pm_addMoney)(void* self, int amount) = NULL;
static void  (*lobby_createRoom)(void* self) = NULL;   // HR_PhotonLobbyManager.CreateRoomButton
static void  (*lobby_leaveRoom)(void* self) = NULL;    // HR_PhotonLobbyManager.LeaveRoom
static bool  (*pn_createRoom)(void* name, void* opts, void* lobby, void* users) = NULL; // PhotonNetwork.CreateRoom
static bool  (*pn_joinRoom)(void* name, void* users) = NULL;   // PhotonNetwork.JoinRoom 0x593A64C (goz at)
static void* (*pn_getNickName)(void) = NULL;                   // PhotonNetwork.get_NickName 0x59338C0 (isim kaydet)
static bool  (*pn_leaveRoom)(bool) = NULL;                     // PhotonNetwork.LeaveRoom 0x593B2D8 (goz at cikis)
static bool  (*pn_setMasterClient)(void* player) = NULL;       // PhotonNetwork.SetMasterClient 0x5938B3C (oda master al)
static bool  (*pn_joinRoom)(void* name, void* users) = NULL;   // PhotonNetwork.JoinRoom 0x593A64C (goz at)
static void* (*pn_getNickName)(void) = NULL;                   // PhotonNetwork.get_NickName 0x59338C0 (isim kaydet)
static bool  (*pn_leaveRoom)(bool) = NULL;                     // PhotonNetwork.LeaveRoom 0x593B2D8 (goz at cikis)
// ==== ODADAKI OYUNCULAR (script.json dogrulandi) ====
static void* (*pn_getPlayerList)(void) = NULL;      // PhotonNetwork.get_PlayerList -> Player[]  0x59339D0
static void* (*pn_getPlayerListOthers)(void) = NULL; // PhotonNetwork.get_PlayerListOthers (kendisi haric) 0x5933B88
static void* (*ply_getNickName)(void*) = NULL;      // Player.get_NickName          0x5924574
static int   (*ply_getActorNumber)(void*) = NULL;   // Player.get_ActorNumber       0x592455C
static bool  (*ply_getIsMaster)(void*) = NULL;      // Player.get_IsMasterClient    0x5924640
static void* (*ply_getUserId)(void*) = NULL;        // Player.get_UserId            0x5924630
// HR_PhotonLobbyManager.EnableCarSelectionMenu() - oyun ici arac degistirme  0x54ABFD4
static void  (*lobby_carSelectMenu)(void*) = NULL;
// ==== ARAC KONTROL PANELI (CarDriveSystem field offsetleri, il2cpp.h dogrulandi) ====
//  +0x60 overrideBrake(bool)  +0x61 overrideAcceleration(bool)  +0x62 overrideSteering(bool)
//  +0x64 overrideSteeringPower  +0x68 overrideBrakePower  +0x6C overrideAccelerationPower
//  +0x98 topSpeed  +0x9C currentSpeed
static bool  isCarPanelEnabled = false;
static float carAccelPower  = 3.0f;
static float carSteerPower  = 1.0f;
static float carTopSpeed    = 300.0f;
// UserId -> isim gecmisi. ActorNumber odadan cikinca degisir, UserId hesaba bagli kalir.
static NSMutableDictionary *g_playerDB = nil;
static void loadPlayerDB(void) {
    if (g_playerDB) return;
    NSDictionary *d = [[NSUserDefaults standardUserDefaults] objectForKey:@"few1n_playerDB"];
    g_playerDB = d ? [d mutableCopy] : [NSMutableDictionary dictionary];
}
static void savePlayerDB(void) {
    if (g_playerDB) {
        [[NSUserDefaults standardUserDefaults] setObject:g_playerDB forKey:@"few1n_playerDB"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

// ===== HIZ TESHIS / YARDIMCILAR =====
static float (*ts_get)(void) = NULL;     // Time.get_timeScale
static Vec3 g_savedPos = {0,0,0};
static bool g_hasSavedPos = false;
static void* diagDrive = NULL;
static float diagCurSpd = 0, diagTopSpd = 0, diagVel = 0;
static long  fNitro = 0, fDrive = 0, fPlate = 0, fRoomLine = 0, fRccp = 0, fSmRCC = 0, fSmPUN = 0;  // hook tetiklenme sayaclari
static long  fTS = 0, fChat = 0, fCreateBtn = 0, fConn = 0;  // araba-disi hook sayaclari (base testi)
static long  fInput = 0;  // CarPlayerInput.FixedUpdate - GERCEK araba hooku
static float diagNitroVal = 0;
static float g_origTop = 0;

// ===== TIME SCALE =====
static void (*o_setTimeScale)(float) = NULL;
static inline float targetScale(void) {
    if (speedMode == 2) return 2.0f;
    if (speedMode == 3) return 3.0f;
    if (speedMode == 5) return 5.0f;
    return 1.0f;
}
static inline void enforceScale(void) {
    // iGameGod yontemi: il2cpp runtime_invoke ile set_timeScale (ham offset degil!)
    if (speedMode > 1) {
        if (g_il2cppReady) setTimeScaleVal(targetScale());
        else if (o_setTimeScale) o_setTimeScale(targetScale());  // yedek
    }
}
static void h_setTimeScale(float v) {
    fTS++;
    // Oyun timeScale'i 1'e resetlemeye calisirsa bizim degeri zorla
    if (speedMode > 1) v = targetScale();
    if (o_setTimeScale) o_setTimeScale(v);
}

// ===== ANTI-KICK & OYUNCU ATMA =====
static bool g_isManualKick = false;
static bool (*o_closeConnection)(void*) = NULL;
static bool (*pn_closeConnection)(void*) = NULL;   // PhotonNetwork.CloseConnection DIREKT (hook olmadan) 0x5938844
static bool h_closeConnection(void* kickPlayer) {
    fConn++;
    if (g_isManualKick) return o_closeConnection ? o_closeConnection(kickPlayer) : false;
    return false; // Anti-kick: baskalari seni atamasin
}
static void few1n_kickPlayer(void* playerObj) {
    if (!playerObj) return;
    // hook olu -> direkt il2cpp cagrisi kullan (o_closeConnection yedek)
    bool (*fn)(void*) = pn_closeConnection ? pn_closeConnection : o_closeConnection;
    if (!fn) { FLog(@"Kick: CloseConnection pointeri yok"); return; }
    @try {
        g_isManualKick = true;
        fn(playerObj);
        g_isManualKick = false;
        FLog(@"Oyuncu atma istegi gonderildi (sadece MASTER/host isen calisir)");
    } @catch (...) { g_isManualKick = false; }
}

// ===== INFINITE NITRO =====
static float (*o_getNitro)(void*) = NULL;
static float h_getNitro(void* self) {
    // CarNitro -> driveSystem(0x28) -> rigidbody(0x48) : arabanin Rigidbody'sini yakala
    fNitro++;
    if (self) {
        @try {
            void* ds = *(void**)((uintptr_t)self + 0x28);
            if (ds) { void* rb = *(void**)((uintptr_t)ds + 0x48); if (rb) g_rb = rb; }
            diagNitroVal = *(float*)((uintptr_t)self + 0x34);
            if (isInfiniteNitroEnabled) *(float*)((uintptr_t)self + 0x34) = 1.0f;  // nitroAmount backing field'i de doldur
        } @catch (...) {}
    }
    if (isInfiniteNitroEnabled) return 1.0f;
    return o_getNitro ? o_getNitro(self) : 0.0f;
}
static void (*o_setNitro)(void*, float) = NULL;
static void h_setNitro(void* self, float value) {
    if (isInfiniteNitroEnabled) value = 1.0f;
    if (o_setNitro) o_setNitro(self, value);
}

// ===== CarDriveSystem.Move : hiz hilesi (tam gaz + topSpeed) + teshis =====
// a=steering, b=accel(0..1), c=footbrake, d=handbrake
// topSpeed@0x98, currentSpeed@0x9C  (public, isimleri korundu)
static void (*o_driveMove)(void*, float, float, float, float) = NULL;
static void h_driveMove(void* self, float a, float b, float c, float d) {
    fDrive++;
    enforceScale();
    if (self && speedMode > 1) {
        // TAM GAZ (fren yoksa) - kuvvet yok, araba kalkmaz
        if (c <= 0.0f && d <= 0.0f) b = 1.0f;
    }
    if (o_driveMove) o_driveMove(self, a, b, c, d);   // once oyunun fizigi calissin

    if (self) {
        @try {
            diagDrive  = self;
            diagCurSpd = *(float*)((uintptr_t)self + 0x9C);   // currentSpeed
            diagTopSpd = *(float*)((uintptr_t)self + 0x98);   // topSpeed
            // topSpeed cap'ini de yukselt (bazi oyunlar hizi buna clamp eder)
            if (speedMode > 1) {
                if (g_origTop <= 0.0f && diagTopSpd > 0.0f && diagTopSpd < 1000.0f) g_origTop = diagTopSpd;
                float base = (g_origTop > 0.0f) ? g_origTop : 200.0f;
                *(float*)((uintptr_t)self + 0x98) = base * 3.0f;
            } else if (g_origTop > 0.0f) {
                *(float*)((uintptr_t)self + 0x98) = g_origTop; g_origTop = 0.0f;
            }
            // ASIL HIZ: Rigidbody linearVelocity'yi dogrudan olcekle (en kesin yontem)
            void* rb = *(void**)((uintptr_t)self + 0x48);     // CarDriveSystem._rigidbody
            g_rb = rb;                                        // fly/zipla/lowgrav icin sakla
            if (rb && rb_getVel && rb_setVel) {
                Vec3 v = {0,0,0};
                rb_getVel(rb, &v);
                float horiz = sqrtf(v.x*v.x + v.z*v.z);       // yatay hiz (y=dikey, dokunmuyoruz -> ucmaz)
                diagVel = horiz;
                if (speedMode > 1 && horiz > 0.5f) {
                    float cap = (speedMode == 2) ? 90.0f : (speedMode == 3) ? 140.0f : 230.0f;
                    float ns = horiz * 1.06f; if (ns > cap) ns = cap;
                    float k = ns / horiz;
                    v.x *= k; v.z *= k;                        // sadece yatayi buyut
                    rb_setVel(rb, &v);
                }
            }
        } @catch (...) {}
    }
}

// ===== HOOKSUZ ARABA ARAMA (MSHookFunction calismadigi icin tek yol) =====
// Her poll'da FindObjectOfType(CarDriveSystem) cagirip Rigidbody'yi +0x48'den okur.
// Ayrica arac paneli degerlerini de burada yazar.
static long fFind = 0;      // basarili arama sayisi
static void* g_carDrive = NULL;
static void* g_carNitro = NULL;
static int   g_findTick  = 0;   // arama throttle sayaci

// Bir pointer okunabilir/makul mu? (cop pointer dereference crash'ini onler)
static inline bool ptrOk(void* p) {
    uintptr_t v = (uintptr_t)p;
    return v > 0x1000 && v < 0x0000800000000000ULL && (v & 0x7) == 0;
}
// Bir Unity nesnesi hala canli mi? Yok edilince m_CachedPtr (+0x10) NULL olur.
static inline bool unityAlive(void* obj) {
    if (!ptrOk(obj)) return false;
    @try { return *(void**)((uintptr_t)obj + 0x10) != NULL; } @catch (...) { return false; }
}
// Bir tipi 3 farkli Unity API'siyle aramayi dener (aktif olmayanlar dahil)
static void* few1n_findByType(void* typeObj) {
    if (!typeObj || !i_runtime_invoke) return NULL;
    void* r = NULL;
    // Yol 1 - FindObjectOfType Type,true : pasif nesneleri de bulur
    if (g_mFindObjInactive) {
        bool inc = true;
        void* a[2]; a[0] = typeObj; a[1] = &inc;
        @try { r = i_runtime_invoke(g_mFindObjInactive, NULL, a, NULL); } @catch (...) {}
        if (r) return r;
    }
    // Yol 2 - FindObjectOfType Type
    if (g_mFindObjectOfType) {
        void* a[1]; a[0] = typeObj;
        @try { r = i_runtime_invoke(g_mFindObjectOfType, NULL, a, NULL); } @catch (...) {}
        if (r) return r;
    }
    // Yol 3 - FindAnyObjectByType Type : Unity 6 yeni API
    if (g_mFindAnyByType) {
        void* a[1]; a[0] = typeObj;
        @try { r = i_runtime_invoke(g_mFindAnyByType, NULL, a, NULL); } @catch (...) {}
        if (r) return r;
    }
    // Yol 4 - FindObjectsOfType (cogul) -> ilk eleman (tekil bos donerse)
    if (g_mFindObjectsPlural) {
        void* a[1]; a[0] = typeObj;
        @try {
            void* arr = i_runtime_invoke(g_mFindObjectsPlural, NULL, a, NULL);
            if (ptrOk(arr)) {
                int cnt = (int)(*(uintptr_t*)((uintptr_t)arr + 0x18));
                if (cnt > 0 && cnt < 4096) {
                    void** el = (void**)((uintptr_t)arr + 0x20);
                    if (ptrOk(el[0])) return el[0];
                }
            }
        } @catch (...) {}
    }
    return NULL;
}

// ===== ESP YARDIMCILARI (Camera + tum arabalar, il2cpp) =====
static void* few1n_getCamera(void) {
    if (!g_mCamGetMain || !i_runtime_invoke) return NULL;
    @try { return i_runtime_invoke(g_mCamGetMain, NULL, NULL, NULL); } @catch (...) { return NULL; }
}
// Dunya koordinatini ekran koordinatina cevir (x,y=piksel, z=kameraya uzaklik)
static bool few1n_worldToScreen(void* cam, Vec3 world, Vec3* out) {
    if (!ptrOk(cam) || !g_mWorldToScreen || !i_runtime_invoke) return false;
    @try {
        void* args[1]; args[0] = &world;
        void* box = i_runtime_invoke(g_mWorldToScreen, cam, args, NULL);
        if (!ptrOk(box)) return false;
        *out = *(Vec3*)((uintptr_t)box + 0x10);   // boxed Vector3 unbox
        return true;
    } @catch (...) { return false; }
}
// Sahnedeki TUM CarDriveSystem'leri getir (kendi + digerleri). +0x18 sayi, +0x20 elemanlar.
static void* few1n_findAllCars(int* outCount) {
    *outCount = 0;
    if (!g_mFindObjectsPlural || !g_carDriveTypeObj || !i_runtime_invoke) return NULL;
    @try {
        void* args[1]; args[0] = g_carDriveTypeObj;
        void* arr = i_runtime_invoke(g_mFindObjectsPlural, NULL, args, NULL);
        if (!ptrOk(arr)) return NULL;
        int cnt = (int)(*(uintptr_t*)((uintptr_t)arr + 0x18));
        if (cnt < 0 || cnt > 128) return NULL;
        *outCount = cnt;
        return arr;
    } @catch (...) { return NULL; }
}

// TUM oyuncularin arac Rigidbody'lerini topla (UZAK oyuncular DAHIL - onlarda
// CarDriveSystem yok ama Rigidbody var). Yakinlari (ayni aracin tekeri vs) birlestirir.
// out[] doldurulur, return = sayi. Kendi araban (g_rb) haric.
static int g_rawRbCnt = -1;   // teshis: son FindObjectsOfType(Rigidbody) ham sayisi
static int few1n_collectCars(void** out, int maxN) {
    int n = 0;
    g_rawRbCnt = -1;
    if (!g_rbTypeObj) { g_rawRbCnt = -2; return 0; }   // -2 = Rigidbody tipi cozulmedi
    if (!g_mFindObjectsPlural || !i_runtime_invoke) { g_rawRbCnt = -3; return 0; }
    @try {
        void* a[1]; a[0] = g_rbTypeObj;
        void* arr = i_runtime_invoke(g_mFindObjectsPlural, NULL, a, NULL);
        if (!ptrOk(arr)) { g_rawRbCnt = -4; return 0; }   // -4 = FindObjectsOfType null dondu
        int cnt = (int)(*(uintptr_t*)((uintptr_t)arr + 0x18));
        g_rawRbCnt = cnt;
        if (cnt < 0 || cnt > 4096) return 0;
        void** rbs = (void**)((uintptr_t)arr + 0x20);
        Vec3 pos[64]; int pn = 0;
        Vec3 myPos = {0,0,0}; BOOL haveMe = unityAlive(g_rb); if (haveMe) rbGetPosIl(g_rb, &myPos);
        for (int i = 0; i < cnt && n < maxN; i++) {
            void* rb = rbs[i]; if (!unityAlive(rb) || rb == g_rb) continue;
            Vec3 p; rbGetPosIl(rb, &p);
            // SENIN arabani DISLA: g_rb'ye 5m'den yakinsa (govde+teker) senin aracin -> atla.
            // Boylece troll SANA degmez, kendini kontrol edebilirsin.
            if (haveMe) { float dx=p.x-myPos.x,dy=p.y-myPos.y,dz=p.z-myPos.z; if (dx*dx+dy*dy+dz*dz < 25.0f) continue; }
            bool dup = false;   // 4m icindeki Rigidbody'ler ayni arac say (teker/govde)
            for (int k = 0; k < pn; k++) { float dx=p.x-pos[k].x,dy=p.y-pos[k].y,dz=p.z-pos[k].z; if (dx*dx+dy*dy+dz*dz < 16.0f) { dup=true; break; } }
            if (dup) continue;
            if (pn < 64) pos[pn++] = p;
            out[n++] = rb;
        }
    } @catch (...) {}
    return n;
}

// ===== ESP CIZIM VERISI + OZEL VIEW (kutu + cizgi + HUD) =====
typedef struct { float sx, sy, dist, boxH; } EspItem;
static EspItem g_espItems[128];
static int g_espCount = 0;

@interface FEW1NDrawView : UIView @end
@implementation FEW1NDrawView
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext(); if (!ctx) return;
    CGFloat W = rect.size.width, H = rect.size.height;
    if (isEspEnabled) {
        for (int i = 0; i < g_espCount; i++) {
            EspItem e = g_espItems[i];
            CGFloat bh = e.boxH, bw = e.boxH * 0.82;
            CGRect box = CGRectMake(e.sx - bw/2, e.sy - bh/2, bw, bh);
            // snapline: ekran alt-ortasindan kutunun altina
            CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0 green:0.62 blue:1 alpha:0.32].CGColor);
            CGContextSetLineWidth(ctx, 1.0);
            CGContextMoveToPoint(ctx, W/2, H);
            CGContextAddLineToPoint(ctx, e.sx, CGRectGetMaxY(box));
            CGContextStrokePath(ctx);
            // kutu (kose vurgulu)
            CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:0 green:0.85 blue:1 alpha:0.95].CGColor);
            CGContextSetLineWidth(ctx, 1.6);
            CGContextStrokeRect(ctx, box);
            // mesafe etiketi (kutu ustu)
            NSString *txt = [NSString stringWithFormat:@"%.0fm", e.dist];
            NSDictionary *at = @{NSFontAttributeName:[UIFont boldSystemFontOfSize:11], NSForegroundColorAttributeName:[UIColor whiteColor]};
            CGSize ts = [txt sizeWithAttributes:at];
            CGRect lb = CGRectMake(e.sx - ts.width/2 - 3, CGRectGetMinY(box) - ts.height - 3, ts.width + 6, ts.height + 2);
            CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:0 green:0.5 blue:0.9 alpha:0.82].CGColor);
            CGContextFillRect(ctx, lb);
            [txt drawAtPoint:CGPointMake(lb.origin.x + 3, lb.origin.y + 1) withAttributes:at];
        }
    }
}
@end

// Bir Component'in dunya konumu (transform.position)
static bool few1n_objPos(void* obj, Vec3* out) {
    *out = (Vec3){0,0,0};
    if (!ptrOk(obj) || !g_mCompGetTransform || !g_mTransGetPos || !i_runtime_invoke) return false;
    @try {
        void* tr = i_runtime_invoke(g_mCompGetTransform, obj, NULL, NULL);
        if (!ptrOk(tr)) return false;
        void* box = i_runtime_invoke(g_mTransGetPos, tr, NULL, NULL);
        if (!ptrOk(box)) return false;
        *out = *(Vec3*)((uintptr_t)box + 0x10);
        return true;
    } @catch (...) { return false; }
}
// Bir Component'in ileri yonu (transform.forward) - ucus icin
static bool few1n_fwd(void* obj, Vec3* out) {
    *out = (Vec3){0,0,0};
    if (!ptrOk(obj) || !g_mCompGetTransform || !g_mTransGetFwd || !i_runtime_invoke) return false;
    @try {
        void* tr = i_runtime_invoke(g_mCompGetTransform, obj, NULL, NULL);
        if (!ptrOk(tr)) return false;
        void* box = i_runtime_invoke(g_mTransGetFwd, tr, NULL, NULL);
        if (!ptrOk(box)) return false;
        *out = *(Vec3*)((uintptr_t)box + 0x10);
        return true;
    } @catch (...) { return false; }
}
// YEDEK: CarDriveSystem bulunamazsa kameraya en yakin Rigidbody = oyuncunun araci.
// Boylece zipla/isinlan/ucus g_rb'siz kalmaz (hiz/nitro yine CarDriveSystem ister).
// KESIN: PhotonView.IsMine=true olan = SENIN araban. Pozisyonundan Rigidbody'ni bul.
// Uzak oyuncularin PhotonView'i IsMine=false -> asla onlari almaz. Kontrol HEP sende.
static bool few1n_findMyCarPhoton(void) {
    // Field-read yontemi: get_IsMine METODUNU CAGIRMAZ (o cokuyordu). _IsMine byte'ini
    // dogrudan hafizadan okur -> oyun kodu calismaz -> asla cokmez.
    if (!g_photonViewType || g_isMineOff <= 0 || !g_rbTypeObj || !g_mFindObjectsPlural || !i_runtime_invoke) return false;
    @try {
        void* a[1]; a[0] = g_photonViewType;
        void* pvArr = i_runtime_invoke(g_mFindObjectsPlural, NULL, a, NULL);
        if (!ptrOk(pvArr)) return false;
        int pvCnt = (int)(*(uintptr_t*)((uintptr_t)pvArr + 0x18));
        if (pvCnt < 0 || pvCnt > 512) return false;
        void** pvs = (void**)((uintptr_t)pvArr + 0x20);
        Vec3 myPos = {0,0,0}; bool foundMine = false;
        for (int i = 0; i < pvCnt; i++) {
            void* pv = pvs[i]; if (!unityAlive(pv)) continue;
            bool mine = *(bool*)((uintptr_t)pv + g_isMineOff);   // DOGRUDAN oku, metod yok
            if (mine && few1n_objPos(pv, &myPos)) { foundMine = true; break; }
        }
        if (!foundMine) return false;
        void* b[1]; b[0] = g_rbTypeObj;
        void* rbArr = i_runtime_invoke(g_mFindObjectsPlural, NULL, b, NULL);
        if (!ptrOk(rbArr)) return false;
        int rbCnt = (int)(*(uintptr_t*)((uintptr_t)rbArr + 0x18));
        if (rbCnt < 0 || rbCnt > 1024) return false;
        void** rbs = (void**)((uintptr_t)rbArr + 0x20);
        void* best = NULL; float bestD = 1e18f;
        for (int i = 0; i < rbCnt; i++) {
            void* rb = rbs[i]; if (!unityAlive(rb)) continue;
            Vec3 p; rbGetPosIl(rb, &p);
            float dx=p.x-myPos.x,dy=p.y-myPos.y,dz=p.z-myPos.z; float d=dx*dx+dy*dy+dz*dz;
            if (d < bestD) { bestD = d; best = rb; }
        }
        if (ptrOk(best) && bestD < 100.0f) { g_rb = best; return true; }   // 10m icinde eslesti
    } @catch (...) {}
    return false;
}

// Kameraya en yakin (MESAFE SINIRLI) Rigidbody = SENIN araban (chase cam ~5-10m).
// CarDriveSystem bu oyunda il2cpp'den bulunamiyor, o yuzden bu yontem kullaniliyor.
static void few1n_findRbFallback(void) {
    if (!g_rbTypeObj || !g_mFindObjectsPlural || !g_mCamGetMain || !i_runtime_invoke) return;
    @try {
        void* cam = i_runtime_invoke(g_mCamGetMain, NULL, NULL, NULL);
        if (!ptrOk(cam)) return;
        Vec3 camPos; if (!few1n_objPos(cam, &camPos)) return;
        void* a[1]; a[0] = g_rbTypeObj;
        void* arr = i_runtime_invoke(g_mFindObjectsPlural, NULL, a, NULL);
        if (!ptrOk(arr)) return;
        int cnt = (int)(*(uintptr_t*)((uintptr_t)arr + 0x18));
        if (cnt < 0 || cnt > 1024) return;
        void** rbs = (void**)((uintptr_t)arr + 0x20);
        void* best = NULL; float bestD = 1e18f;
        for (int i = 0; i < cnt; i++) {
            void* rb = rbs[i]; if (!unityAlive(rb)) continue;
            Vec3 p; rbGetPosIl(rb, &p);
            float dx=p.x-camPos.x, dy=p.y-camPos.y, dz=p.z-camPos.z;
            float d = dx*dx+dy*dy+dz*dz;
            if (d < bestD) { bestD = d; best = rb; }
        }
        if (ptrOk(best) && bestD < 324.0f) g_rb = best;   // 18m sinir = senin araban
    } @catch (...) {}
}

// SADECE ARAMA - pahali FindObjectOfType burada, seyrek cagrilir (tick, 0.3s).
// Uygulama (nitro/hiz/panel) frameTick'te onbellekten yapilir -> ucuz, her frame.
static void few1n_findCar(void) {
    if (!i_runtime_invoke) return;
    g_findTick++;
    @try {
        // Onbellek gecerliligi: yok edilen nesneyi temizle (crash korumasi)
        if (g_carDrive && !unityAlive(g_carDrive)) { g_carDrive = NULL; g_origTop = 0.0f; }
        if (g_carNitro && !unityAlive(g_carNitro))   g_carNitro = NULL;
        // KRITIK: yedekten gelen g_rb, o obje olunce temizlenmiyordu -> stale pointer crash.
        // Her tick g_rb'yi dogrula, oldayse temizle (yedek yol yeniden bulur).
        if (g_rb && !unityAlive(g_rb)) g_rb = NULL;

        // ===== BIRINCIL: CarPlayerInput = SADECE SENIN araban =====
        // Uzak oyuncularin arabasinda bu bilesen YOK. Her odada seninkini kesin verir.
        bool gotMine = false;
        if (g_carInputTypeObj && ((!g_carDrive) || (!g_carNitro) || (g_findTick % 8 == 0))) {
            void* inp = few1n_findByType(g_carInputTypeObj);
            if (ptrOk(inp)) {
                void* drive = *(void**)((uintptr_t)inp + 0x20);   // jhr -> CarDriveSystem (SENIN)
                if (unityAlive(drive)) {
                    if (drive != g_carDrive) fFind++;
                    g_carDrive = drive; gotMine = true;
                    void* rb = *(void**)((uintptr_t)drive + 0x48); // Rigidbody (SENIN araban)
                    if (ptrOk(rb)) g_rb = rb;
                }
                void* nos = *(void**)((uintptr_t)inp + 0x28);     // jhs -> CarNitro
                if (ptrOk(nos)) g_carNitro = nos;
            }
        }
        // IKINCIL: CarPlayerInput bulunamadiysa CarDriveSystem'i dene (g_carDrive icin)
        if (!gotMine && ((!g_carDrive) || (g_findTick % 12 == 0)) && g_carDriveTypeObj) {
            void* found = few1n_findByType(g_carDriveTypeObj);
            if (ptrOk(found)) {
                g_carDrive = found;
                void* rb = *(void**)((uintptr_t)found + 0x48);
                if (ptrOk(rb)) g_rb = rb;
            }
        }
        // KESIN: PhotonView._IsMine field-read (cokmez). Olmazsa kamera-yedegi (18m).
        if (!unityAlive(g_rb) && (g_findTick % 3 == 0)) {
            if (!few1n_findMyCarPhoton()) few1n_findRbFallback();
        }
        // g_rb VAR ama g_carDrive YOK ise: Rigidbody'nin GameObject'inden CarDriveSystem'i al.
        // Boylece hiz/nitro/super arac/drift/selektor/boyut da calisir (hepsi g_carDrive ister).
        if (unityAlive(g_rb) && !unityAlive(g_carDrive) && g_mGetCompInParent && g_carDriveTypeObj) {
            @try {
                bool inc = true; void* a[2]; a[0] = g_carDriveTypeObj; a[1] = &inc;
                void* cd = i_runtime_invoke(g_mGetCompInParent, g_rb, a, NULL);
                if (unityAlive(cd)) {
                    g_carDrive = cd;
                    void* inp = *(void**)((uintptr_t)cd + 0x20);   // jfs -> CarPlayerInput
                    if (unityAlive(inp)) { void* nos = *(void**)((uintptr_t)inp + 0x28); if (ptrOk(nos)) g_carNitro = nos; }
                }
            } @catch (...) {}
        }
    } @catch (...) {}
}

// HER FRAME UYGULAMA - onbellekteki pointerlari kullanir, arama YAPMAZ (ucuz).
static void few1n_applyCar(void) {
    @try {
        if (isInfiniteNitroEnabled && unityAlive(g_carNitro)) {
            *(float*)((uintptr_t)g_carNitro + 0x34) = 1.0f;   // nitro dolu tut
        }
        // NO-CLIP (hayalet) + ANTI-GRAV - sadece g_rb yeterli (carDrive gerekmez)
        if (unityAlive(g_rb)) {
            if (isNoClip && g_mRbSetDetect) { bool f=false; void* a[1]={&f}; i_runtime_invoke(g_mRbSetDetect, g_rb, a, NULL); g_noClipApplied=true; }
            else if (g_noClipApplied && g_mRbSetDetect) { bool t=true; void* a[1]={&t}; i_runtime_invoke(g_mRbSetDetect, g_rb, a, NULL); g_noClipApplied=false; }
            // Ucus/no-clip'te de yercekimini kapat -> hover sabit kalir, karsiya PURUZSUZ gider
            // (yoksa yercekimi vs velocity.y=0 cakismasi titremeye sebep olur)
            bool gravOff = isAntiGrav || isFlyEnabled || isNoClip;
            if (gravOff && g_mRbUseGrav) { bool f=false; void* a[1]={&f}; i_runtime_invoke(g_mRbUseGrav, g_rb, a, NULL); g_antiGravApplied=true; }
            else if (g_antiGravApplied && g_mRbUseGrav) { bool t=true; void* a[1]={&t}; i_runtime_invoke(g_mRbUseGrav, g_rb, a, NULL); g_antiGravApplied=false; }
            // ARAC BOYUTU: g_rb'nin transformunu olcekle - CarDriveSystem GEREKMEZ (g_rb yeterli)
            if (isCarSizeEnabled && g_mTransSetScale && g_mCompGetTransform) {
                void* tr = i_runtime_invoke(g_mCompGetTransform, g_rb, NULL, NULL);
                if (unityAlive(tr)) { Vec3 sc = { carSizeVal, carSizeVal, carSizeVal }; void* a[1]={&sc}; i_runtime_invoke(g_mTransSetScale, tr, a, NULL); }
            }
        }
        if (!unityAlive(g_carDrive)) return;   // araba oldu -> field yazma (crash korumasi)
        uintptr_t d = (uintptr_t)g_carDrive;
        diagDrive  = g_carDrive;
        diagCurSpd = *(float*)(d + 0x9C);
        g_hudSpeed = fabsf(diagCurSpd);   // HUD icin hiz
        diagTopSpd = *(float*)(d + 0x98);
        if (speedMode > 1) {
            if (g_origTop <= 0.0f && diagTopSpd > 0.0f && diagTopSpd < 1000.0f) g_origTop = diagTopSpd;
            float base = (g_origTop > 0.0f) ? g_origTop : 200.0f;
            *(float*)(d + 0x98) = base * 3.0f;
        } else if (g_origTop > 0.0f && !isCarPanelEnabled) {
            *(float*)(d + 0x98) = g_origTop; g_origTop = 0.0f;
        }
        if (unityAlive(g_rb) && speedMode > 1) {
            Vec3 v = {0,0,0};
            rbGetVelIl(g_rb, &v);
            float horiz = sqrtf(v.x*v.x + v.z*v.z);
            diagVel = horiz;
            if (horiz > 0.5f) {
                float cap = (speedMode == 2) ? 90.0f : (speedMode == 3) ? 140.0f : 230.0f;
                float ns = horiz * 1.06f; if (ns > cap) ns = cap;
                float k = ns / horiz;
                v.x *= k; v.z *= k;
                rbSetVelIl(g_rb, &v);
            }
        }
        if (isCarPanelEnabled) {
            *(unsigned char*)(d + 0x61) = 1;
            *(float*)(d + 0x6C) = carAccelPower;
            *(unsigned char*)(d + 0x62) = 1;
            *(float*)(d + 0x64) = carSteerPower;
            *(float*)(d + 0x98) = carTopSpeed;
        }
    } @catch (...) {}
}

// ===== PLAKA ZORLA (il2cpp, hook olu) =====
// PlateVariant.parts (+0x20) = TMP_Text[]; disableSplit (+0x29). Her karede zorla yaz.
// NOT: sadece SENIN ekranindaki plaka - server/digerleri baska gorebilir.
static void* g_plateEmptyStr = NULL;
static void few1n_forcePlate(void) {
    if (!isCustomPlateEnabled || !g_mTmpSetText || !g_plateTypeObj || !g_mFindObjectsPlural || !i_runtime_invoke) return;
    @try {
        void* a[1]; a[0] = g_plateTypeObj;
        void* arr = i_runtime_invoke(g_mFindObjectsPlural, NULL, a, NULL);
        if (!ptrOk(arr)) return;
        int cnt = (int)(*(uintptr_t*)((uintptr_t)arr + 0x18));
        if (cnt < 0 || cnt > 64) return;
        void** plates = (void**)((uintptr_t)arr + 0x20);
        void* str = mkStr([NSString stringWithUTF8String:customPlateText]);
        if (!str) return;
        if (!g_plateEmptyStr) g_plateEmptyStr = mkStr(@"");
        for (int i = 0; i < cnt; i++) {
            void* pv = plates[i];
            if (!ptrOk(pv)) continue;
            *(unsigned char*)((uintptr_t)pv + 0x29) = 1;        // disableSplit = true (tek parca)
            void* parts = *(void**)((uintptr_t)pv + 0x20);      // TMP_Text[]
            if (!ptrOk(parts)) continue;
            int pc = (int)(*(uintptr_t*)((uintptr_t)parts + 0x18));
            if (pc < 0 || pc > 32) continue;
            void** tp = (void**)((uintptr_t)parts + 0x20);
            for (int k = 0; k < pc; k++) {
                void* t = tp[k];
                if (!ptrOk(t)) continue;
                void* pa[1]; pa[0] = (k == 0) ? str : g_plateEmptyStr;   // ilk parca=metin, digerleri bos
                i_runtime_invoke(g_mTmpSetText, t, pa, NULL);
            }
        }
    } @catch (...) {}
}

// ===== ARAC RENGI (Renderer.material.color, il2cpp) =====
static Color4 hueToRGB(float h) {   // h 0..1 arasi -> gokkusagi
    float f = h*6.0f - floorf(h*6.0f), q = 1.0f - f;
    int ii = ((int)floorf(h*6.0f)) % 6; if (ii < 0) ii += 6;
    switch (ii) {
        case 0: return (Color4){1,f,0,1};
        case 1: return (Color4){q,1,0,1};
        case 2: return (Color4){0,1,f,1};
        case 3: return (Color4){0,q,1,1};
        case 4: return (Color4){f,0,1,1};
        default:return (Color4){1,0,q,1};
    }
}
// Arabanin tum Renderer materyallerini onbellege al
static void few1n_refreshCarMats(void) {
    g_carMatCount = 0;
    if (!ptrOk(g_rb) || !g_mGetCompsChild || !g_rendererType || !g_mRendGetMat || !i_runtime_invoke) return;
    @try {
        bool inc = true;
        void* a[2]; a[0] = g_rendererType; a[1] = &inc;
        void* arr = i_runtime_invoke(g_mGetCompsChild, g_rb, a, NULL);   // g_rb'den (carDrive bulunamiyor)
        if (!ptrOk(arr)) return;
        int cnt = (int)(*(uintptr_t*)((uintptr_t)arr + 0x18));
        if (cnt < 0 || cnt > 96) return;
        void** rends = (void**)((uintptr_t)arr + 0x20);
        for (int i = 0; i < cnt && g_carMatCount < 96; i++) {
            void* rend = rends[i]; if (!ptrOk(rend)) continue;
            void* mat = i_runtime_invoke(g_mRendGetMat, rend, NULL, NULL);
            if (ptrOk(mat)) g_carMats[g_carMatCount++] = mat;
        }
    } @catch (...) {}
}

// Onbellekteki materyallere rengi uygula (her frame - ucuz)
// KRITIK: araba yok edilince materyaller de gecersizlesir -> unityAlive kontrolu (crash korumasi)
static void few1n_applyColor(void) {
    if (!isCarColorEnabled || !g_mMatSetColor || g_carMatCount == 0 || !i_runtime_invoke) return;
    if (!unityAlive(g_rb)) { g_carMatCount = 0; return; }   // araba oldu -> materyaller cop
    @try {
        Color4 c;
        if (carColorRainbow) { g_carHue += 0.012f; if (g_carHue >= 1.0f) g_carHue -= 1.0f; c = hueToRGB(g_carHue); }
        else c = g_carColor;
        void* a[1]; a[0] = &c;
        for (int i = 0; i < g_carMatCount; i++)
            if (unityAlive(g_carMats[i])) i_runtime_invoke(g_mMatSetColor, g_carMats[i], a, NULL);
    } @catch (...) {}
}

// ===== GODMODE: HR_PlayerHandler.canCrash=false -> hic kaza yapma (sonsuz surus) =====
// Benim handler'im: PhotonView(@0xB8).IsMine=true. canCrash@0x38, damage@0x3C.
static void few1n_applyGodmode(void) {
    if (!isGodmode && !isFlyEnabled) return;   // godmode VEYA ucus icin handler+rccp lazim
    if (g_myPlayerHandler && !unityAlive(g_myPlayerHandler)) { g_myPlayerHandler = NULL; g_myRccp = NULL; }
    if (!unityAlive(g_myPlayerHandler)) {
        static int gmTick = 0;
        if ((gmTick++ % 20) != 0) return;   // ~her 20 frame'de bir ara (FindObjects ucuz degil)
        if (!g_playerHandlerType || !g_mFindObjectsPlural || !i_runtime_invoke || g_isMineOff <= 0) return;
        @try {
            void* a[1]; a[0] = g_playerHandlerType;
            void* arr = i_runtime_invoke(g_mFindObjectsPlural, NULL, a, NULL);
            if (!ptrOk(arr)) return;
            int cnt = (int)(*(uintptr_t*)((uintptr_t)arr + 0x18));
            if (cnt < 0 || cnt > 64) return;
            void** hs = (void**)((uintptr_t)arr + 0x20);
            for (int i = 0; i < cnt; i++) {
                void* h = hs[i]; if (!unityAlive(h)) continue;
                void* pv = *(void**)((uintptr_t)h + 0xB8);   // HR_PlayerHandler.PhotonView
                bool mine = unityAlive(pv) ? *(bool*)((uintptr_t)pv + g_isMineOff) : false;
                if (mine) { g_myPlayerHandler = h; g_myRccp = *(void**)((uintptr_t)h + 0x20); break; }
            }
        } @catch (...) {}
        return;
    }
    if (isGodmode) { @try {
        *(unsigned char*)((uintptr_t)g_myPlayerHandler + 0x38) = 0;   // canCrash = false
        *(float*)((uintptr_t)g_myPlayerHandler + 0x3C) = 0.0f;        // damage = 0
    } @catch (...) {} }
}

// ===== SELEKTOR: RCCP_Lights.highBeamHeadlights@0x41 hizli ac/kapat (g_rb'ye en yakin) =====
static void few1n_applySelektor(void) {
    if (!isSelektor) return;
    if (g_myLights && !unityAlive(g_myLights)) g_myLights = NULL;
    if (!unityAlive(g_myLights)) {
        static int sTick = 0;
        if ((sTick++ % 15) != 0) return;
        if (!g_rccpLightsType || !g_mFindObjectsPlural || !i_runtime_invoke || !unityAlive(g_rb)) return;
        @try {
            Vec3 myPos; rbGetPosIl(g_rb, &myPos);
            void* a[1]; a[0] = g_rccpLightsType;
            void* arr = i_runtime_invoke(g_mFindObjectsPlural, NULL, a, NULL);
            if (!ptrOk(arr)) return;
            int cnt = (int)(*(uintptr_t*)((uintptr_t)arr + 0x18));
            if (cnt < 0 || cnt > 256) return;
            void** ls = (void**)((uintptr_t)arr + 0x20);
            void* best = NULL; float bestD = 1e18f;
            for (int i = 0; i < cnt; i++) {
                void* L = ls[i]; if (!unityAlive(L)) continue;
                Vec3 p; if (!few1n_objPos(L, &p)) continue;
                float dx=p.x-myPos.x,dy=p.y-myPos.y,dz=p.z-myPos.z; float d=dx*dx+dy*dy+dz*dz;
                if (d < bestD) { bestD = d; best = L; }
            }
            if (ptrOk(best) && bestD < 100.0f) g_myLights = best;
        } @catch (...) {}
        return;
    }
    @try {
        g_selTick++;
        int rate = (g_selFlashRate >= 1) ? g_selFlashRate : 1;
        unsigned char on = (((g_selTick / rate) % 2) == 0) ? 1 : 0;   // hiz menuden ayarli
        *(unsigned char*)((uintptr_t)g_myLights + 0x41) = on;   // highBeamHeadlights
        *(unsigned char*)((uintptr_t)g_myLights + 0x40) = on;   // lowBeamHeadlights (gorunurluk icin)
    } @catch (...) {}
}

// ===== GERCEK COZUM: CarPlayerInput.FixedUpdate (SADECE YEREL OYUNCU) =====
// script.json + il2cpp.h ile dogrulandi:
//   CarPlayerInput$$FixedUpdate = RVA 0x54D0BC0  (88935360)
//   CarPlayerInput_Fields: +0x20 jhr=CarDriveSystem*, +0x28 jhs=CarNitro*
//   CarDriveSystem_Fields: +0x48 _jfu_k__BackingField = UnityEngine.Rigidbody*
// NOT: CarDriveSystem'de Update/FixedUpdate YOK -> eski hooklar bu yuzden hic tetiklenmedi.
static void (*o_playerInputFixed)(void*) = NULL;
static void h_playerInputFixed(void* self) {
    fInput++;
    if (self) {
        @try {
            void* drive = *(void**)((uintptr_t)self + 0x20);   // jhr -> CarDriveSystem
            if (drive) {
                g_carDrive = drive;
                void* rb = *(void**)((uintptr_t)drive + 0x48); // Rigidbody backing field
                if (rb) g_rb = rb;
            }
            void* nos = *(void**)((uintptr_t)self + 0x28);     // jhs -> CarNitro
            if (nos) g_carNitro = nos;
            // ---- ARAC KONTROL PANELI: oyunun kendi override alanlarini kullan ----
            // timeScale'e dokunmaz -> sadece bu arac etkilenir, digerleri fark etmez
            if (isCarPanelEnabled && g_carDrive) {
                uintptr_t d = (uintptr_t)g_carDrive;
                *(unsigned char*)(d + 0x61) = 1;              // overrideAcceleration
                *(float*)(d + 0x6C) = carAccelPower;          // overrideAccelerationPower
                *(unsigned char*)(d + 0x62) = 1;              // overrideSteering
                *(float*)(d + 0x64) = carSteerPower;          // overrideSteeringPower
                *(float*)(d + 0x98) = carTopSpeed;            // topSpeed
            }
        } @catch (...) {}
    }
    if (o_playerInputFixed) o_playerInputFixed(self);
}

// ===== RCCP araba (oyuncu bunu kullaniyor) - Rigidbody yakala =====
// RCCP_MainComponent Rigidbody @ self+0x48
static void (*o_rccpUpdate)(void*) = NULL;
static void h_rccpUpdate(void* self) {
    fRccp++;
    if (self) {
        @try {
            void* rb = *(void**)((uintptr_t)self + 0x48);   // RCCP Rigidbody
            if (rb) g_rb = rb;
        } @catch (...) {}
    }
    if (o_rccpUpdate) o_rccpUpdate(self);
}

// ===== SmoothSync (AGDAKI TUM ARABALAR - oyuncu dahil) : Rigidbody yakala =====
// SmoothSyncRCC.rb @ 0xF8 (Rigidbody), carController @ 0xF0
static void (*o_smRCC)(void*) = NULL;
static void h_smRCC(void* self) {
    fSmRCC++;
    if (self) {
        @try {
            void* rb = *(void**)((uintptr_t)self + 0xF8);   // SmoothSyncRCC.rb
            if (rb) g_rb = rb;
        } @catch (...) {}
    }
    if (o_smRCC) o_smRCC(self);
}
static void (*o_smPUN)(void*) = NULL;
static void h_smPUN(void* self) {
    fSmPUN++;
    if (o_smPUN) o_smPUN(self);
}

// ===== CUSTOM PLATE =====
static void (*o_plateChange)(void*, struct PlateHolder) = NULL;
static void h_plateChange(void* self, struct PlateHolder holder) {
    fPlate++;
    if (isCustomPlateEnabled && customPlateText[0] != '\0') {
        void* r = mkStr([NSString stringWithUTF8String:customPlateText]);
        if (r) holder.t = r;
    }
    if (o_plateChange) o_plateChange(self, holder);
}

// ===== CHAT =====
static void (*o_chatSend)(void*, void*) = NULL;
static void h_chatSend(void* self, void* msg) {
    fChat++;
    if (msg) {
        NSString *orig = readStr(msg);
        if (orig.length > 0) {
            void* finalMsg = NULL;
            if (isMatrixChatEnabled) {
                void* colored = mkStr(matrixWrapChat(orig));
                if (colored) { if (o_chatSend) o_chatSend(self, colored); return; }
            } else if (isGlitchChatEnabled) {
                void* colored = mkStr(glitchWrapChat(orig));
                if (colored) { if (o_chatSend) o_chatSend(self, colored); return; }
            } else if (isColorChatEnabled) {
                void* colored = mkStr([NSString stringWithFormat:@"<color=cyan><b>[FEW1N]</b></color> %@", orig]);
                if (colored) { if (o_chatSend) o_chatSend(self, colored); return; }
            }
        }
    }
    if (o_chatSend) o_chatSend(self, msg);
}

// ===== PASSWORD BYPASS =====
static void (*o_roomConnect)(void*) = NULL;
static void h_roomConnect(void* self) {
    if (isBypassPasswordEnabled && self) {
        @try {
            void* roomPwd = *(void**)((uintptr_t)self + 0x50);   // RoomListLine.password
            if (lobbyGetInst && roomPwd) {
                void* lobby = lobbyGetInst();
                if (lobby && tmp_set_text) {
                    void* pOnConnect = *(void**)((uintptr_t)lobby + 0x60);
                    if (pOnConnect) tmp_set_text(pOnConnect, roomPwd);
                    void* pInput = *(void**)((uintptr_t)lobby + 0x50);
                    if (pInput) tmp_set_text(pInput, roomPwd);
                }
            }
        } @catch (...) {}
    }
    if (o_roomConnect) o_roomConnect(self);
}

// ===== ODA ISMI RICH TEXT ACIGI + ZORLA RENKLI (CLIENT-SIDE) =====
static bool isColorRoomForce = false;  // TUM oda isimlerini renkli yap (client-side)
static void (*o_roomLineSetup)(void*, void*, void*, unsigned char, unsigned char, void*, void*) = NULL;
static void h_roomLineSetup(void* self, void* a, void* b, unsigned char c, unsigned char d, void* e, void* f) {
    fRoomLine++;
    if (o_roomLineSetup) o_roomLineSetup(self, a, b, c, d, e, f);
    if (self) {
        @try {
            void* nameText = *(void**)((uintptr_t)self + 0x20);
            if (nameText) {
                if (g_mSetRichText) setRichTextIl(nameText, true);
                void* rawName = (f && rinfo_getName) ? rinfo_getName(f) : a;
                if (rawName && tmp_set_text) {
                    // ZORLA RENKLI MOD: TUM oda isimlerini client-side renklendir
                    if (isColorRoomForce) {
                        NSString *name = readStr(rawName) ?: @"";
                        if (name.length > 0) {
                            static int colorIdx = 0;
                            NSArray *forceColors = @[@"#FF0000", @"#00FF00", @"#00FFFF", @"#FF00FF", @"#FFFF00", @"#FF8800", @"#FF0088", @"#88FF00"];
                            NSString *col = forceColors[colorIdx % forceColors.count];
                            colorIdx++;
                            NSString *colored = [NSString stringWithFormat:@"<color=%@><b>%@</b></color>", col, name];
                            void* cs = mkStr(colored);
                            if (cs) { tmp_set_text(nameText, cs); return; }
                        }
                    }
                    tmp_set_text(nameText, rawName);
                }
            }
            void* mapText = *(void**)((uintptr_t)self + 0x28);
            if (mapText && g_mSetRichText) setRichTextIl(mapText, true);
        } @catch (...) {}
    }
}


// ===== ODA KURMA HATASI TESHIS + OTOMATIK RETRY (BRUTE FORCE) =====
static int g_bruteForceIdx = 0;
static bool isBruteForceActive = false;
static NSArray* g_bruteForceNames = nil;
static void (*o_onCreateFail)(void*, short, void*) = NULL;
static void h_onCreateFail(void* self, short code, void* msg) {
    @try { FLog([NSString stringWithFormat:@"ODA KURMA HATASI: kod=%d mesaj=%@", (int)code, readStr(msg)]); } @catch (...) {}
    // BRUTE FORCE: Basarisiz olunca otomatik sonraki teknikle dene
    if (isBruteForceActive && g_bruteForceNames && g_bruteForceIdx < (int)g_bruteForceNames.count) {
        NSString *nextName = g_bruteForceNames[g_bruteForceIdx++];
        strncpy(customRoomName, nextName.UTF8String, sizeof(customRoomName)-1);
        customRoomName[sizeof(customRoomName)-1]='\0';
        FLog([NSString stringWithFormat:@"BRUTE FORCE: Teknik %d/%d deneniyor -> %@", g_bruteForceIdx, (int)g_bruteForceNames.count, nextName]);
        // 0.3sn bekle ve tekrar dene
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[FEW1NMenu shared] createOneRoom];
        });
        return;  // Orijinal hatayi cagirma - brute force devam ediyor
    }
    if (isBruteForceActive) {
        isBruteForceActive = false;
        FLog(@"BRUTE FORCE: Tum teknikler denendi, basarisiz.");
    }
    if (o_onCreateFail) o_onCreateFail(self, code, msg);
}
// OnCreateRoomFailed/OnJoinRoomFailed -> neden reddedildigini loga yaz
static void (*o_onCreateFail)(void*, short, void*) = NULL;
static void h_onCreateFail(void* self, short code, void* msg) {
    @try { FLog([NSString stringWithFormat:@"ODA KURMA HATASI: kod=%d mesaj=%@", (int)code, readStr(msg)]); } @catch (...) {}
    if (o_onCreateFail) o_onCreateFail(self, code, msg);
}
static void (*o_onJoinFail)(void*, short, void*) = NULL;
static void h_onJoinFail(void* self, short code, void* msg) {
    @try { FLog([NSString stringWithFormat:@"ODA GIRIS HATASI: kod=%d mesaj=%@", (int)code, readStr(msg)]); } @catch (...) {}
    if (o_onJoinFail) o_onJoinFail(self, code, msg);
}

// ===== "ODA OLUSTUR" butonu: yazdigin rich text ismi DOGRUDAN pn_createRoom ile kur =====
// Oyunun kendi CreateRoomButton'u rich text ismi reddediyordu; biz dogrulamayi atliyoruz.
static void (*o_createRoomBtn)(void*) = NULL;
static void h_createRoomBtn(void* self) {
    fCreateBtn++;
    @try {
        void* nameInput = *(void**)((uintptr_t)self + 0x48);   // roomNameInput
        NSString *typed = (nameInput && tmp_get_text) ? readStr(tmp_get_text(nameInput)) : @"";
        // SADECE rich text isimlerde bypass yap (normal odalar oyunun akisini kullansin -> harita korunur)
        BOOL isRich = ([typed rangeOfString:@"<"].location != NSNotFound);
        if (isRich && typed.length > 0 && pn_createRoom && i_object_new && g_roomOptionsClass) {
            static int gc = 0; gc++;
            NSString *zwsp = [NSString stringWithFormat:@"%C", (unichar)0x200B];
            NSMutableString *uniq = [NSMutableString stringWithString:typed];
            int reps = (gc % 400) + 1;
            for (int i = 0; i < reps; i++) [uniq appendString:zwsp];
            void* ns = mkStr(uniq);
            void* opts = i_object_new(g_roomOptionsClass);
            if (ns && opts) {
                *(bool*)((uintptr_t)opts + 0x10) = true;
                *(bool*)((uintptr_t)opts + 0x11) = true;
                *(int*) ((uintptr_t)opts + 0x14) = 8;
                *(int*) ((uintptr_t)opts + 0x1C) = roomSpamTTL;
                pn_createRoom(ns, opts, NULL, NULL);
                FLog(@"Oda kuruldu (direkt pn_createRoom, dogrulama atlandi)");
                return;   // orijinali CAGIRMA -> reddi atla
            }
        }
    } @catch (...) {}
    if (o_createRoomBtn) o_createRoomBtn(self);   // yedek: normal akis
}

// ===== MONEY =====
static void (*o_addMoney)(void*, int) = NULL;
static void h_addMoney(void* self, int amount) {
    if (isAutoMoneyEnabled && amount > 0) amount = customMoneyAmount;
    if (o_addMoney) o_addMoney(self, amount);
}

// =============================================================
//  UI
// =============================================================
// ==== BEYAZ ARKA PLAN / BUZ MAVISI NEON TEMA ====
#define C_BG     [UIColor colorWithRed:0.97 green:0.99 blue:1.0 alpha:0.97]   // beyaz panel
#define C_CARD   [UIColor colorWithRed:0.20 green:0.55 blue:0.75 alpha:0.07]  // hafif buz karti
#define C_ON     [UIColor colorWithRed:0.0 green:0.55 blue:0.85 alpha:1.0]    // canli buz mavisi (acik)
#define C_OFF    [UIColor colorWithRed:0.70 green:0.76 blue:0.82 alpha:1.0]   // gri (kapali)
#define C_RED    [UIColor colorWithRed:0.90 green:0.20 blue:0.35 alpha:1.0]
#define C_ACCENT [UIColor colorWithRed:0.0 green:0.60 blue:0.90 alpha:1.0]    // buz mavisi vurgu
#define C_GOLD   [UIColor colorWithRed:0.0 green:0.45 blue:0.70 alpha:1.0]    // koyu buz mavisi
#define C_CYAN   [UIColor colorWithRed:0.10 green:0.62 blue:0.92 alpha:1.0]
#define C_TEXT   [UIColor colorWithRed:0.06 green:0.12 blue:0.20 alpha:1.0]   // koyu lacivert metin
#define C_SUB    [UIColor colorWithRed:0.30 green:0.42 blue:0.52 alpha:0.85]  // gri-mavi alt metin

@interface FEW1NMenu : NSObject
@property (nonatomic, strong) UIButton *fab;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) NSMutableDictionary *toggleViews;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *statusCard;
@property (nonatomic, strong) UIView *espOverlay;
@property (nonatomic, strong) NSMutableArray *espLabels;
@property (nonatomic, strong) NSTimer *espTimer;
@property (nonatomic, strong) UIView *lyricsOverlay;
@property (nonatomic, strong) UITextView *lyricsInput;
@property (nonatomic, strong) UIView *songPicker;
@property (nonatomic, strong) NSMutableDictionary *speedBtns;
@property (nonatomic, strong) UIButton *plateBtn;
@property (nonatomic, strong) UIButton *nameBtn;
@property (nonatomic, strong) UIButton *moneyBtn;
@property (nonatomic, strong) UIView *logOverlay;
@property (nonatomic, strong) UITextView *logText;
@property (nonatomic, strong) CADisplayLink *dl;
+ (instancetype)shared;
- (void)build;
@end

@implementation FEW1NMenu

+ (instancetype)shared {
    static FEW1NMenu *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [[self alloc] init]; });
    return inst;
}

- (void)build {
    UIWindow *w = getKeyWindow();
    if (!w) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (!self.panel) [self build];
        });
        return;
    }
    if (self.panel) return;
    self.toggleViews = [NSMutableDictionary new];
    self.speedBtns = [NSMutableDictionary new];

    // FAB
    self.fab = [UIButton buttonWithType:UIButtonTypeCustom];
    self.fab.frame = CGRectMake(16, 100, 56, 56);
    self.fab.layer.cornerRadius = 28;
    self.fab.clipsToBounds = NO;
    UIView *pulse = [[UIView alloc] initWithFrame:self.fab.bounds];
    pulse.layer.cornerRadius = 28; pulse.backgroundColor = C_CYAN;
    pulse.alpha = 0.4; pulse.userInteractionEnabled = NO;
    [self.fab addSubview:pulse];
    [UIView animateWithDuration:1.8 delay:0 options:UIViewAnimationOptionRepeat|UIViewAnimationOptionCurveEaseOut animations:^{
        pulse.transform = CGAffineTransformMakeScale(1.6,1.6); pulse.alpha = 0.0;
    } completion:nil];
    CAGradientLayer *fg = [CAGradientLayer layer];
    fg.frame = self.fab.bounds; fg.cornerRadius = 28;
    fg.colors = @[(id)C_CYAN.CGColor, (id)C_ACCENT.CGColor];
    fg.startPoint = CGPointMake(0,0); fg.endPoint = CGPointMake(1,1);
    [self.fab.layer insertSublayer:fg atIndex:0];
    self.fab.layer.shadowColor = C_CYAN.CGColor;
    self.fab.layer.shadowRadius = 15; self.fab.layer.shadowOpacity = 0.8;
    self.fab.layer.shadowOffset = CGSizeMake(0,0);
    UILabel *fl = [[UILabel alloc] initWithFrame:self.fab.bounds];
    fl.text = @"F1"; fl.textColor = [UIColor whiteColor];
    fl.textAlignment = NSTextAlignmentCenter;
    fl.font = [UIFont systemFontOfSize:21 weight:UIFontWeightBlack];
    fl.layer.shadowColor = [UIColor blackColor].CGColor;
    fl.layer.shadowRadius = 2; fl.layer.shadowOpacity = 0.25; fl.layer.shadowOffset = CGSizeMake(0,1);
    [self.fab addSubview:fl];
    [self.fab addTarget:self action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside];
    [self.fab addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)]];
    [w addSubview:self.fab];

    // PANEL - ekrana sigacak sekilde dinamik yukseklik (landscape'te tasmasin)
    CGFloat pw = 310;
    CGFloat ph = MIN(600.0, w.bounds.size.height - 30.0);
    if (ph < 260) ph = 260;
    self.panel = [[UIView alloc] initWithFrame:CGRectMake((w.bounds.size.width-pw)/2, (w.bounds.size.height-ph)/2, pw, ph)];
    self.panel.backgroundColor = C_BG;
    self.panel.layer.cornerRadius = 28;
    self.panel.layer.borderWidth = 1.5;
    self.panel.layer.borderColor = [UIColor colorWithRed:0.0 green:0.60 blue:0.90 alpha:0.35].CGColor;
    self.panel.layer.shadowColor = C_CYAN.CGColor;
    self.panel.layer.shadowRadius = 25; self.panel.layer.shadowOpacity = 0.4;
    self.panel.layer.shadowOffset = CGSizeMake(0,0);
    self.panel.clipsToBounds = YES;
    self.panel.hidden = YES; self.panel.alpha = 0;
    self.panel.transform = CGAffineTransformMakeScale(0.85, 0.85);
    UIVisualEffectView *blurV = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight]];
    blurV.frame = self.panel.bounds;
    blurV.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.panel insertSubview:blurV atIndex:0];
    [self.panel addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)]];

    // HEADER - canli mavi baslik bandi (beyaz metin uzerinde parlar)
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0,0,pw,64)];
    header.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:0.85 alpha:1.0];
    CAGradientLayer *hgrad = [CAGradientLayer layer];
    hgrad.frame = CGRectMake(0,0,pw,64);
    hgrad.colors = @[(id)[UIColor colorWithRed:0.05 green:0.62 blue:0.96 alpha:1.0].CGColor,
                     (id)[UIColor colorWithRed:0.0 green:0.40 blue:0.80 alpha:1.0].CGColor];
    hgrad.startPoint = CGPointMake(0,0); hgrad.endPoint = CGPointMake(1,1);
    [header.layer insertSublayer:hgrad atIndex:0];
    // parlak nokta rozeti
    UILabel *dotIcon = [[UILabel alloc] initWithFrame:CGRectMake(16,18,22,26)];
    dotIcon.text = @"\U0001F3CE"; dotIcon.font = [UIFont systemFontOfSize:18];
    [header addSubview:dotIcon];
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(42,12,pw-90,26)];
    title.text = @"FEW1N MOD MENU"; title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBlack];
    [header addSubview:title];
    UILabel *ver = [[UILabel alloc] initWithFrame:CGRectMake(42,37,pw-90,16)];
    ver.text = [NSString stringWithFormat:@"v33.3  •  Base 0x%lX", (unsigned long)global_base];
    ver.textColor = [UIColor colorWithWhite:1 alpha:0.82];
    ver.font = [UIFont fontWithName:@"Menlo-Bold" size:8] ?: [UIFont systemFontOfSize:8 weight:UIFontWeightBold];
    [header addSubview:ver];
    UIButton *cls = [UIButton buttonWithType:UIButtonTypeSystem];
    cls.frame = CGRectMake(pw-48,14,36,36);
    cls.backgroundColor = [UIColor colorWithWhite:1 alpha:0.18];
    cls.layer.cornerRadius = 18;
    [cls setTitle:@"✕" forState:UIControlStateNormal];
    [cls setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    cls.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [cls addTarget:self action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:cls];
    [self.panel addSubview:header];

    // SCROLL
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0,64,pw,ph-64)];
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.panel addSubview:self.scrollView];
    self.contentView = [[UIView alloc] initWithFrame:CGRectMake(0,0,pw,0)];
    [self.scrollView addSubview:self.contentView];

    CGFloat y = 12;

    y = [self header:@"⚡  HIZ (timeScale)" atY:y];
    UIView *sr = [[UIView alloc] initWithFrame:CGRectMake(12,y,pw-24,44)];
    sr.backgroundColor = [UIColor colorWithRed:0.93 green:0.96 blue:0.99 alpha:1.0];
    sr.layer.cornerRadius = 12;
    sr.layer.borderWidth = 1.0;
    sr.layer.borderColor = [UIColor colorWithRed:0.0 green:0.48 blue:0.85 alpha:0.12].CGColor;
    NSArray *labels = @[@"1x", @"2x", @"3x", @"5x"];
    NSArray *vals   = @[@1, @2, @3, @5];
    CGFloat bw = (pw-24-10*3-16)/4;
    for (int i=0;i<4;i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.frame = CGRectMake(8+i*(bw+10),6,bw,32);
        b.layer.cornerRadius = 10;
        [b setTitle:labels[i] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        b.tag = [vals[i] intValue];
        [b addTarget:self action:@selector(speedTap:) forControlEvents:UIControlEventTouchUpInside];
        [sr addSubview:b];
        self.speedBtns[vals[i]] = b;
    }
    [self.contentView addSubview:sr];
    y += 52;
    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(16,y,pw-32,16)];
    hint.text = @"Online icin 2x onerilir";
    hint.textColor = C_SUB; hint.font = [UIFont systemFontOfSize:9];
    [self.contentView addSubview:hint];
    y += 22;

    y = [self header:@"\U0001F3CE  ARAC" atY:y];
    y = [self toggle:@"🌈  Rainbow Araç Boyası" sub:@"il2cpp ile canlı renk değiştiren boya" key:@"carcolor" atY:y action:@selector(tapCarColor)];
    y = [self toggle:@"🧊  Drift Modu (Kusursuz Kayma)" sub:@"il2cpp fizik ile yan kayma koruması" key:@"drift" atY:y action:@selector(tapDrift)];
    y = [self toggle:@"🚗  Hız Sabitleyici (Cruise Control)" sub:@"Gaza basmadan belirlenen hızda git" key:@"cruise" atY:y action:@selector(tapCruise)];
    y = [self actionRow:@"✏️  Sabit Hız Ayarla (km/h)" color:C_CYAN atY:y action:@selector(editCruiseSpeed)];
    y = [self actionRow:@"\U0001F53C  ZIPLA (bas)" color:C_ON atY:y action:@selector(jumpTap)];
    y = [self actionRow:@"\U0001F680  Hiz Patlamasi (boost)" color:C_ON atY:y action:@selector(boostTap)];
    y = [self actionRow:@"\U0001F9CA  Araci Dondur (anlik dur)" color:C_CYAN atY:y action:@selector(freezeTap)];
    y = [self actionRow:@"\U0001F53C  Yukari Isinlan (takildinca)" color:C_CYAN atY:y action:@selector(teleportUp)];
    y = [self actionRow:@"➡️  Ileri Isinlan (+50)" color:C_CYAN atY:y action:@selector(teleportForward)];
    y = [self actionRow:@"\U0001F4CD  Konum Kaydet" color:C_GOLD atY:y action:@selector(saveTeleportPos)];
    y = [self actionRow:@"\U0001F680  Kayitli Konuma Isinlan" color:C_GOLD atY:y action:@selector(teleportSaved)];
    y = [self actionRow:@"\U0001F3AF  Oyuncuya Isinlan (yanina git)" color:C_ON atY:y action:@selector(teleportToPlayer)];

    y = [self header:@"\U0001F4AC  CHAT" atY:y];
    y = [self toggle:@"\U0001F4E2  Chat Spam" sub:@"50ms araligla mesaj" key:@"chatspam" atY:y action:@selector(tapChatSpam)];
    y = [self actionRow:@"✏️  Spam Yazisini Duzenle" color:C_CYAN atY:y action:@selector(editSpam)];
    y = [self actionRow:@"\U0001F3A8  Spam Rengi Sec" color:C_CYAN atY:y action:@selector(pickSpamColor)];
    {
        UIView *ssrow = [[UIView alloc] initWithFrame:CGRectMake(12,y,pw-24,44)];
        ssrow.backgroundColor = C_CARD; ssrow.layer.cornerRadius = 12;
        UIButton *ssb = [UIButton buttonWithType:UIButtonTypeSystem];
        ssb.frame = CGRectMake(0,0,pw-24,44);
        NSArray *nm = @[@"Duz", @"Cerceveli", @"Semboller", @"Renkli", @"Gokkusagi", @"Buyuk+Renk", @"Cerceve+Renk"];
        [ssb setTitle:[NSString stringWithFormat:@"\U0001F3AD Spam Stili: %@", nm[spamStyle % 7]] forState:UIControlStateNormal];
        [ssb setTitleColor:C_ACCENT forState:UIControlStateNormal];
        ssb.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        [ssb addTarget:self action:@selector(pickSpamStyle:) forControlEvents:UIControlEventTouchUpInside];
        [ssrow addSubview:ssb];
        [self.contentView addSubview:ssrow];
        y += 52;
    }
    y = [self toggle:@"\U0001F3AC  ASCII Animasyon Spam" sub:@"Kare kare animasyon chate" key:@"asciianim" atY:y action:@selector(tapAsciiAnim)];
    {
        UIView *arow = [[UIView alloc] initWithFrame:CGRectMake(12,y,pw-24,44)];
        arow.backgroundColor = C_CARD; arow.layer.cornerRadius = 12;
        UIButton *ab = [UIButton buttonWithType:UIButtonTypeSystem];
        ab.frame = CGRectMake(0,0,pw-24,44);
        [ab setTitle:[NSString stringWithFormat:@"\U0001F3AC Animasyon Sec (%d/%d)", asciiAnimIndex + 1, (int)asciiAnims().count] forState:UIControlStateNormal];
        [ab setTitleColor:C_ACCENT forState:UIControlStateNormal];
        ab.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        [ab addTarget:self action:@selector(pickAsciiAnim:) forControlEvents:UIControlEventTouchUpInside];
        [arow addSubview:ab];
        [self.contentView addSubview:arow];
        y += 52;
    }
    y = [self toggle:@"\U0001F308  ASCII Renk Dongusu" sub:@"Her kareyi farkli renkte gonder" key:@"asciicolor" atY:y action:@selector(tapAsciiColor)];
    y = [self actionRow:@"🧪  Exploit Test (Chat Filtresi Atlat)" color:C_RED atY:y action:@selector(exploitChatTest)];
    // YENI: Hacker Chat Modlari
    y = [self toggle:@"🟢  Matrix Chat Modu" sub:@"Mesajlarin yesil sistem stili" key:@"matrixchat" atY:y action:@selector(tapMatrixChat)];
    y = [self toggle:@"💀  Glitch Chat Modu" sub:@"Mesajlarin mor/root stili" key:@"glitchchat" atY:y action:@selector(tapGlitchChat)];
    y = [self actionRow:@"📋  Hacker Chat Sablonu Gonder" color:C_RED atY:y action:@selector(sendChatTemplate)];

    y = [self header:@"\U0001F3B5  SARKI SOZU (altyazi)" atY:y];
    y = [self actionRow:@"\U0001F50D  Sarki Ara (internetten getir)" color:C_ON atY:y action:@selector(fetchLyricsByName)];
    y = [self toggle:@"▶️  Sarki Sozunu Baslat" sub:@"Her satiri sirayla chate yazar" key:@"lyrics" atY:y action:@selector(tapLyrics)];
    y = [self actionRow:@"✏️  Elle Sarki Sozu Gir (cok satir)" color:C_CYAN atY:y action:@selector(editLyrics)];
    y = [self actionRow:@"⏱️  Satir Araligi Ayarla" color:C_CYAN atY:y action:@selector(editLyricsInterval)];
    y = [self toggle:@"\U0001F308  Renkli Satirlar" sub:@"Her satir farkli renk" key:@"lyricsColor" atY:y action:@selector(tapLyricsColor)];
    y = [self toggle:@"\U0001F501  Bitince Basa Sar" sub:@"Sarki sozunu tekrarla" key:@"lyricsLoop" atY:y action:@selector(tapLyricsLoop)];


    y = [self header:@"\U0001F4DB  OYUNCU" atY:y];
    self.nameBtn = [self actionButtonRow:&y];
    [self.nameBtn setTitle:@"\U0001F4DB  Isim Degistir" forState:UIControlStateNormal];
    [self.nameBtn setTitleColor:C_CYAN forState:UIControlStateNormal];
    [self.nameBtn addTarget:self action:@selector(changeName) forControlEvents:UIControlEventTouchUpInside];
    y = [self actionRow:@"\U0001F3AD  Isim Hileleri (rozet/gorunmez/kayan)" color:C_GOLD atY:y action:@selector(nameTricks)];
    y = [self actionRow:@"⚔️  Tum Oyunculari At (SADECE kendi odanda)" color:C_RED atY:y action:@selector(kickAllPlayers)];

    y = [self header:@"\U0001F511  ODA" atY:y];
    y = [self toggle:@"🎨  Zorla Renkli Oda (Client-Side)" sub:@"Tum oda isimlerini renklendir" key:@"colorroomforce" atY:y action:@selector(tapColorRoomForce)];
    y = [self actionRow:@"\U0001F513  Oda Sifrelerini Goster (il2cpp)" color:C_ON atY:y action:@selector(showRoomPasswords)];
    y = [self actionRow:@"\U0001F465  Odadaki Oyuncular (isim kopyala)" color:C_CYAN atY:y action:@selector(showPlayers)];
    y = [self actionRow:@"\U0001F441  Odaya Goz At (isimsiz anlik gir-cik)" color:C_GOLD atY:y action:@selector(peekRoom)];
    y = [self actionRow:@"👑  Oda Master Ol (Fake)" color:C_GOLD atY:y action:@selector(tapRoomMaster)];
    y = [self actionRow:@"🎨  Renkli Oda Kur (Dinamik Stil Paneli)" color:C_GOLD atY:y action:@selector(createColoredRoom)];
    y = [self actionRow:@"🧪  Exploit Ile Oda Kur (30 Yontem)" color:C_RED atY:y action:@selector(exploitCreateRoom)];
    y = [self actionRow:@"🏠  Düz Özel İsimli Oda Kur" color:C_CYAN atY:y action:@selector(createOneRoom)];
    y = [self actionRow:@"\U0001F4A5  300 ODA AC (tek tus, 0.02sn)" color:C_RED atY:y action:@selector(spam300Rooms)];
    y = [self toggle:@"\U0001F4E5  Fake Oda Spam" sub:@"Kalici odalar birikir" key:@"roomspam" atY:y action:@selector(tapRoomSpam)];
    y = [self toggle:@"\U0001F504  Surekli Mod" sub:@"Kapatana kadar spam" key:@"roomcont" atY:y action:@selector(tapRoomContinuous)];
    y = [self actionRow:@"✏️  Oda Ismini Ayarla" color:C_CYAN atY:y action:@selector(editRoomName)];
    y = [self actionRow:@"\U0001F4CA  Oda Sayisi (0=sinirsiz)" color:C_CYAN atY:y action:@selector(editRoomSpamCount)];
    y = [self actionRow:@"⏱️  Oda Acik Kalma Suresi" color:C_CYAN atY:y action:@selector(editRoomTTL)];
    y = [self actionRow:@"⏰  Spam Araligi" color:C_CYAN atY:y action:@selector(editRoomSpamInterval)];

    y = [self header:@"\U0001F4B5  PARA (gecici - server kilitli)" atY:y];
    y = [self toggle:@"\U0001F4B0  Yaris Odulunu Buyut" sub:@"Kazandikca sunucuya yazmayi dener" key:@"automoney" atY:y action:@selector(tapAutoMoney)];
    self.moneyBtn = [self actionButtonRow:&y];
    [self.moneyBtn addTarget:self action:@selector(addMoneyTap) forControlEvents:UIControlEventTouchUpInside];
    y = [self actionRow:@"✏️  Para Miktarini Ayarla" color:C_CYAN atY:y action:@selector(editMoneyAmount)];

    UIView *sc = [[UIView alloc] initWithFrame:CGRectMake(12,y,pw-24,38)];
    UILabel *sl = [[UILabel alloc] initWithFrame:CGRectMake(0,0,pw-24,38)];
    sc.layer.cornerRadius = 11;
    sc.layer.borderWidth = 1.0;
    if (global_base != 0 && g_il2cppReady) {
        sc.backgroundColor = [UIColor colorWithRed:0.0 green:0.55 blue:0.85 alpha:0.10];
        sc.layer.borderColor = [UIColor colorWithRed:0.0 green:0.55 blue:0.85 alpha:0.35].CGColor;
        sl.text = g_rb ? @"\U0001F7E2 il2cpp OK  •  Araba bagli" : @"\U0001F7E1 il2cpp OK  •  Araba araniyor...";
        sl.textColor = C_ON;
    } else {
        sc.backgroundColor = [UIColor colorWithRed:0.90 green:0.20 blue:0.35 alpha:0.10];
        sc.layer.borderColor = [UIColor colorWithRed:0.90 green:0.20 blue:0.35 alpha:0.35].CGColor;
        sl.text = @"\U0001F534 Framework/il2cpp bekleniyor";
        sl.textColor = C_RED;
    }
    self.statusLabel = sl; self.statusCard = sc;
    sl.textAlignment = NSTextAlignmentCenter;
    sl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [sc addSubview:sl];
    [self.contentView addSubview:sc];
    y += 46;

    y = [self actionRow:@"\U0001F504  Modu Yeniden Baslat (araba bulunamazsa)" color:C_ON atY:y action:@selector(restartMod)];
    y = [self actionRow:@"\U0001F4CB  Loglari Goster (hata teshisi)" color:C_CYAN atY:y action:@selector(showLog)];

    UILabel *foot = [[UILabel alloc] initWithFrame:CGRectMake(0,y+4,pw,24)];
    foot.text = @"made by few1n  •  il2cpp engine";
    foot.textColor = [UIColor colorWithRed:0.45 green:0.55 blue:0.65 alpha:1.0];
    foot.textAlignment = NSTextAlignmentCenter;
    foot.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    [self.contentView addSubview:foot];
    y += 36;

    self.contentView.frame = CGRectMake(0,0,pw,y);
    self.scrollView.contentSize = CGSizeMake(pw,y);
    [w addSubview:self.panel];
    [self refreshUI];

    if (tickTimer) { [tickTimer invalidate]; tickTimer = nil; }
    tickTimer = [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    // iGameGod gibi: timeScale'i HER FRAME zorla (oyun resetlese bile tutar)
    if (self.dl) { [self.dl invalidate]; self.dl = nil; }
    self.dl = [CADisplayLink displayLinkWithTarget:self selector:@selector(frameTick)];
    [self.dl addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    if (isSpamEnabled && !spamTimer)
        spamTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(fireSpam) userInfo:nil repeats:YES];
    if (isAsciiAnimEnabled && !asciiTimer)
        asciiTimer = [NSTimer scheduledTimerWithTimeInterval:0.4 target:self selector:@selector(fireAscii) userInfo:nil repeats:YES];
}

- (CGFloat)header:(NSString*)text atY:(CGFloat)y {
    CGFloat pw = self.panel.bounds.size.width;
    // sol aksан cubugu (neon)
    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(12, y+2, 4, 16)];
    bar.backgroundColor = C_CYAN; bar.layer.cornerRadius = 2;
    bar.layer.shadowColor = C_CYAN.CGColor; bar.layer.shadowRadius = 4;
    bar.layer.shadowOpacity = 0.8; bar.layer.shadowOffset = CGSizeMake(0,0);
    [self.contentView addSubview:bar];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(24,y,pw-40,20)];
    l.text = [text uppercaseString]; l.textColor = C_TEXT;
    l.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBlack];
    [self.contentView addSubview:l];
    // ince gradient ayirici cizgi
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(12, y+22, pw-24, 1)];
    CAGradientLayer *lg = [CAGradientLayer layer];
    lg.frame = CGRectMake(0,0,pw-24,1);
    lg.colors = @[(id)C_CYAN.CGColor, (id)[UIColor clearColor].CGColor];
    lg.startPoint = CGPointMake(0,0.5); lg.endPoint = CGPointMake(1,0.5);
    [line.layer addSublayer:lg];
    [self.contentView addSubview:line];
    return y + 30;
}

- (CGFloat)toggle:(NSString*)tl sub:(NSString*)sub key:(NSString*)key atY:(CGFloat)y action:(SEL)action {
    CGFloat pw = self.panel.bounds.size.width;
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(12,y,pw-24,56)];
    card.backgroundColor = [UIColor colorWithRed:0.97 green:0.985 blue:1.0 alpha:1.0];
    card.layer.cornerRadius = 14;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [UIColor colorWithRed:0.0 green:0.48 blue:0.85 alpha:0.14].CGColor;
    card.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.35 blue:0.65 alpha:1.0].CGColor;
    card.layer.shadowRadius = 5; card.layer.shadowOpacity = 0.10;
    card.layer.shadowOffset = CGSizeMake(0,2);
    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(16,8,pw-100,22)];
    t.text = tl; t.textColor = C_TEXT;
    t.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [card addSubview:t];
    UILabel *s = [[UILabel alloc] initWithFrame:CGRectMake(16,30,pw-100,16)];
    s.text = sub; s.textColor = C_SUB;
    s.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    [card addSubview:s];
    UIView *pill = [[UIView alloc] initWithFrame:CGRectMake(pw-24-60,15,44,24)];
    pill.backgroundColor = C_OFF; pill.layer.cornerRadius = 12;
    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(2,2,20,20)];
    dot.backgroundColor = [UIColor whiteColor]; dot.layer.cornerRadius = 10; dot.tag = 101;
    [pill addSubview:dot];
    [card addSubview:pill];
    UIButton *tap = [UIButton buttonWithType:UIButtonTypeCustom];
    tap.frame = card.bounds;
    [tap addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:tap];
    [self.contentView addSubview:card];
    self.toggleViews[key] = pill;
    return y + 64;
}

- (CGFloat)actionRow:(NSString*)text color:(UIColor*)color atY:(CGFloat)y action:(SEL)action {
    CGFloat pw = self.panel.bounds.size.width;
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(12,y,pw-24,44)];
    row.backgroundColor = [UIColor colorWithRed:0.97 green:0.985 blue:1.0 alpha:1.0];
    row.layer.cornerRadius = 12;
    row.layer.borderWidth = 1.0;
    row.layer.borderColor = [UIColor colorWithRed:0.0 green:0.48 blue:0.85 alpha:0.12].CGColor;
    row.layer.shadowColor = [UIColor colorWithRed:0.0 green:0.35 blue:0.65 alpha:1.0].CGColor;
    row.layer.shadowRadius = 4; row.layer.shadowOpacity = 0.08;
    row.layer.shadowOffset = CGSizeMake(0,2);
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(0,0,pw-24,44);
    [b setTitle:text forState:UIControlStateNormal];
    [b setTitleColor:color forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:b];
    [self.contentView addSubview:row];
    return y + 52;
}

- (UIButton*)actionButtonRow:(CGFloat*)y {
    CGFloat pw = self.panel.bounds.size.width;
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(12,*y,pw-24,48)];
    card.backgroundColor = C_CARD; card.layer.cornerRadius = 12;
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(0,0,pw-24,48);
    [b setTitleColor:C_GOLD forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [card addSubview:b];
    [self.contentView addSubview:card];
    *y += 60;
    return b;
}

- (void)setToggle:(NSString*)key on:(BOOL)on {
    UIView *pill = self.toggleViews[key];
    if (!pill) return;
    UIView *dot = [pill viewWithTag:101];
    if (!dot) return;
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.5 options:0 animations:^{
        pill.backgroundColor = on ? C_ON : C_OFF;
        dot.frame = on ? CGRectMake(22,2,20,20) : CGRectMake(2,2,20,20);
        pill.layer.shadowColor = C_ON.CGColor;
        pill.layer.shadowOffset = CGSizeMake(0,0);
        pill.layer.shadowRadius = on ? 8 : 0;
        pill.layer.shadowOpacity = on ? 0.7 : 0.0;
    } completion:nil];
}

- (NSString*)shortNum:(long)n {
    if (n >= 1000000000) return [NSString stringWithFormat:@"%.1fB", n/1000000000.0];
    if (n >= 1000000)    return [NSString stringWithFormat:@"%ldM", n/1000000];
    if (n >= 1000)       return [NSString stringWithFormat:@"%ldK", n/1000];
    return [NSString stringWithFormat:@"%ld", n];
}

- (void)refreshUI {
    for (NSNumber *v in self.speedBtns) {
        UIButton *b = self.speedBtns[v];
        BOOL on = (speedMode == v.intValue);
        b.backgroundColor = on ? C_ON : [UIColor colorWithRed:0.88 green:0.93 blue:0.98 alpha:1.0];
        [b setTitleColor:on ? [UIColor whiteColor] : C_TEXT forState:UIControlStateNormal];
        b.layer.shadowColor = C_ON.CGColor;
        b.layer.shadowOffset = CGSizeMake(0,2);
        b.layer.shadowRadius = on ? 6 : 0;
        b.layer.shadowOpacity = on ? 0.45 : 0.0;
    }
    [self setToggle:@"fly"       on:isFlyEnabled];
    [self setToggle:@"lowgrav"   on:isLowGravEnabled];
    [self setToggle:@"chatspam"  on:isSpamEnabled];
    [self setToggle:@"asciianim" on:isAsciiAnimEnabled];
    [self setToggle:@"bypass"    on:isBypassPasswordEnabled];
    [self setToggle:@"roomspam"  on:isRoomSpamEnabled];
    [self setToggle:@"roomcont"  on:roomSpamContinuous];
    [self setToggle:@"automoney" on:isAutoMoneyEnabled];
    [self setToggle:@"esp"       on:isEspEnabled];
    [self setToggle:@"asciicolor" on:asciiColorCycle];
    [self setToggle:@"noclip"    on:isNoClip];
    [self setToggle:@"godmode"   on:isGodmode];
    [self setToggle:@"selektor"  on:isSelektor];
    [self setToggle:@"antigrav"  on:isAntiGrav];
    [self setToggle:@"carsize"   on:isCarSizeEnabled];
    [self setToggle:@"carcolor"  on:isCarColorEnabled];
    [self setToggle:@"carcolorrainbow" on:carColorRainbow];
    [self setToggle:@"drift"     on:isDriftEnabled];
    [self setToggle:@"cruise"    on:isCruiseEnabled];
    [self setToggle:@"lyrics"    on:isLyricsEnabled];
    [self setToggle:@"lyricsColor" on:lyricsColorCycle];
    [self setToggle:@"lyricsLoop" on:lyricsLoop];

    // canli durum rozeti
    if (self.statusLabel && self.statusCard) {
        if (global_base != 0 && g_il2cppReady) {
            self.statusCard.backgroundColor = [UIColor colorWithRed:0.0 green:0.55 blue:0.85 alpha:0.10];
            self.statusCard.layer.borderColor = [UIColor colorWithRed:0.0 green:0.55 blue:0.85 alpha:0.35].CGColor;
            self.statusLabel.text = g_rb ? @"\U0001F7E2 il2cpp OK  •  Araba bagli" : @"\U0001F7E1 il2cpp OK  •  Araba araniyor...";
            self.statusLabel.textColor = C_ON;
        }
    }

    long m = -1;
    if (playerManagerGetInst && pm_getMoney) {
        @try { void* pm = playerManagerGetInst(); if (pm) m = pm_getMoney(pm); } @catch (...) {}
    }
    if (m >= 0)
        [self.moneyBtn setTitle:[NSString stringWithFormat:@"\U0001F4B5 %@ Ekle | Bakiye:%ld", [self shortNum:customMoneyAmount], m] forState:UIControlStateNormal];
    else
        [self.moneyBtn setTitle:[NSString stringWithFormat:@"\U0001F4B5 %@ Para Ekle", [self shortNum:customMoneyAmount]] forState:UIControlStateNormal];
    [self.moneyBtn setTitleColor:C_GOLD forState:UIControlStateNormal];

    if (isCustomPlateEnabled)
        [self.plateBtn setTitle:[NSString stringWithFormat:@"\U0001F4DD Plaka: %s ✅", customPlateText] forState:UIControlStateNormal];
    else
        [self.plateBtn setTitle:@"\U0001F4DD Ozel Plaka Ayarla" forState:UIControlStateNormal];
    [self.plateBtn setTitleColor:isCustomPlateEnabled ? C_ON : C_GOLD forState:UIControlStateNormal];
}

- (void)frameTick {
    enforceScale();          // her ekran frame'inde timeScale'i zorla
    few1n_applyCar();        // onbellekten nitro/hiz/panel uygula (arama YAPMAZ - ucuz)
    few1n_applyColor();      // arac rengini uygula (onbellek materyaller - ucuz)
    few1n_applyGodmode();    // godmode: canCrash=false (hic kaza yapma)
    few1n_applySelektor();   // selektor: RCCP high/low beam hizli cakma
    // ===== UCUS: havada GERCEK surus (gaz=ileri, fren=geri, direksiyon=don) - PURUZSUZ =====
    // Hepsi hiz/acisal-hiz (fizik) ile -> Photon dogal senkronlar -> baskalarinda titremez.
    if (isFlyEnabled && unityAlive(g_rb)) {
        @try {
            Vec3 v = {0,0,0}; rbGetVelIl(g_rb, &v);
            Vec3 fwd; bool haveFwd = few1n_fwd(g_rb, &fwd);
            float thr = 0.0f, brk = 0.0f, str = 0.0f;
            if (unityAlive(g_myRccp)) {
                thr = *(float*)((uintptr_t)g_myRccp + 0x168);   // throttleInput_V
                brk = *(float*)((uintptr_t)g_myRccp + 0x16C);   // brakeInput_V (geri)
                str = *(float*)((uintptr_t)g_myRccp + 0x170);   // steerInput_V
            }
            float drive = thr - brk;   // gaz ileri, fren geri (-1..1)
            if (haveFwd && fabsf(drive) > 0.05f) {
                float tx = fwd.x * drive * flyDriveSpeed, tz = fwd.z * drive * flyDriveSpeed;
                v.x += (tx - v.x) * 0.35f;   // yumusak gecis (ani degil -> titremez)
                v.z += (tz - v.z) * 0.35f;
                v.y *= 0.80f;                // surerken dikey yumusak asili kal
            } else {
                // DURURKEN tam sifir hiz -> HR_PhotonSync uzak kopyada hareket/dusme tahmin etmez -> en az titreme
                v.x = 0.0f; v.z = 0.0f; v.y = 0.0f;
            }
            rbSetVelIl(g_rb, &v);
            Vec3 av = {0.0f, str * 2.2f, 0.0f};   // direksiyon -> yaw donme (fizik, puruzsuz)
            rbSetAngVelIl(g_rb, &av);
        } @catch (...) {}
    } else if ((isLowGravEnabled || isNoClip || isAntiGrav) && unityAlive(g_rb)) {
        @try {
            Vec3 v = {0,0,0}; rbGetVelIl(g_rb, &v);
            if (isNoClip || isAntiGrav) v.y *= 0.80f;              // no-clip/anti-grav: yumusak asili kal (titremez)
            else if (isLowGravEnabled && v.y < 0.0f) v.y *= 0.25f; // floaty dusus
            rbSetVelIl(g_rb, &v);
        } @catch (...) {}
    }

    // ===== HIZ SABITLEYICI (CRUISE CONTROL - il2cpp) =====
    if (isCruiseEnabled && unityAlive(g_rb)) {
        @try {
            Vec3 fwd;
            if (few1n_fwd(g_rb, &fwd)) {
                float targetMps = cruiseSpeedKmh / 3.6f;   // km/h -> m/s cevir
                Vec3 v = {0,0,0}; rbGetVelIl(g_rb, &v);
                v.x = fwd.x * targetMps;
                v.z = fwd.z * targetMps;
                rbSetVelIl(g_rb, &v);
            }
        } @catch (...) {}
    }

    // ===== DRIFT MODU (KUSURSIZ KAYMA - il2cpp) =====
    if (isDriftEnabled && unityAlive(g_rb)) {
        @try {
            Vec3 v = {0,0,0}; rbGetVelIl(g_rb, &v);
            // Donuslerde yanal ivmeyi artirarak yumusak drift yaptir
            v.x *= 1.015f; v.z *= 1.015f;
            rbSetVelIl(g_rb, &v);
        } @catch (...) {}
    }
}

- (void)jumpTap {
    FLog(unityAlive(g_rb) ? @"ZIPLA: rb VAR, uygulaniyor" : @"ZIPLA: rb YOK (mod arabayi henuz bulamadi)");
    if (unityAlive(g_rb)) {
        @try {
            Vec3 v = {0,0,0};
            rbGetVelIl(g_rb, &v);
            v.y = 14.0f;                          // yukari itme (zipla)
            rbSetVelIl(g_rb, &v);
        } @catch (NSException *e) { FLog([@"ZIPLA hata: " stringByAppendingString:e.reason ?: @"?"]); }
    }
}

// ===== YENI: HIZ PATLAMASI (anlik) - yatay hizi 2.5x it =====
- (void)boostTap {
    if (!unityAlive(g_rb)) { FLog(@"Boost: araba araniyor (birkac saniye bekle)"); return; }
    @try {
        Vec3 v = {0,0,0};
        rbGetVelIl(g_rb, &v);
        float horiz = sqrtf(v.x*v.x + v.z*v.z);
        if (horiz < 1.0f) { v.x = 0; v.z = 40.0f; }   // duruyorsa ileri firlat
        else { v.x *= 2.5f; v.z *= 2.5f; }
        rbSetVelIl(g_rb, &v);
        FLog(@"Hiz patlamasi uygulandi");
    } @catch (...) { FLog(@"Boost hatasi"); }
}

// ===== YENI: ARACI DONDUR - hizi sifirla (anlik dur) =====
- (void)freezeTap {
    if (!unityAlive(g_rb)) { FLog(@"Dondur: araba araniyor (birkac saniye bekle)"); return; }
    @try {
        Vec3 z = {0,0,0};
        rbSetVelIl(g_rb, &z);
        FLog(@"Arac donduruldu (hiz=0)");
    } @catch (...) { FLog(@"Dondur hatasi"); }
}

// ===== YENI: ESP - diger oyuncularin ekranda mesafesi/kutusu =====
- (void)tapESP {
    isEspEnabled = !isEspEnabled;
    saveBool(@"esp", isEspEnabled);
    if (isEspEnabled && (!g_mWorldToScreen || !g_mFindObjectsPlural)) { FLog(@"ESP: Camera/bulucu hazir degil"); isEspEnabled = false; }
    [self syncDrawOverlay];
    [self refreshUI];
}
// ESP acikken cizim overlay'i + timer'i yonet
- (void)syncDrawOverlay {
    BOOL need = isEspEnabled;
    if (need) {
        UIWindow *w = getKeyWindow();
        if (w && !self.espOverlay) {
            FEW1NDrawView *dv = [[FEW1NDrawView alloc] initWithFrame:w.bounds];
            dv.userInteractionEnabled = NO;
            dv.backgroundColor = [UIColor clearColor];
            dv.opaque = NO;
            [w addSubview:dv];
            self.espOverlay = dv;
        }
        if (!self.espTimer) self.espTimer = [NSTimer scheduledTimerWithTimeInterval:0.10 target:self selector:@selector(updateESP) userInfo:nil repeats:YES];
        FLog(@"Overlay acildi (ESP/HUD)");
    } else {
        if (self.espTimer) { [self.espTimer invalidate]; self.espTimer = nil; }
        if (self.espOverlay) { [self.espOverlay removeFromSuperview]; self.espOverlay = nil; }
        g_espCount = 0;
    }
}

- (void)updateESP {
    if (!self.espOverlay) return;
    @try {
        UIWindow *w = getKeyWindow();
        if (w) self.espOverlay.frame = w.bounds;
        [w bringSubviewToFront:self.espOverlay];

        g_espCount = 0;
        if (isEspEnabled) {
            void* cam = few1n_getCamera();
            int cnt = 0;
            void* arr = ptrOk(cam) ? few1n_findAllCars(&cnt) : NULL;
            if (arr && cnt > 0) {
                void** cars = (void**)((uintptr_t)arr + 0x20);
                CGFloat scale = [UIScreen mainScreen].scale;
                CGFloat viewH = self.espOverlay.bounds.size.height;
                CGFloat viewW = self.espOverlay.bounds.size.width;
                Vec3 myPos = {0,0,0};
                BOOL haveMe = unityAlive(g_rb); if (haveMe) rbGetPosIl(g_rb, &myPos);
                for (int i = 0; i < cnt && g_espCount < 128; i++) {
                    void* car = cars[i];
                    if (!unityAlive(car)) continue;
                    void* rb = *(void**)((uintptr_t)car + 0x48);
                    if (!unityAlive(rb) || rb == g_rb) continue;
                    Vec3 wp = {0,0,0}; rbGetPosIl(rb, &wp);
                    Vec3 sp = {0,0,0};
                    if (!few1n_worldToScreen(cam, wp, &sp) || sp.z <= 0.0f) continue;
                    CGFloat sx = sp.x / scale;
                    CGFloat sy = viewH - (sp.y / scale);
                    if (sx < -60 || sx > viewW+60 || sy < -60 || sy > viewH+60) continue;
                    // kutu yuksekligi: aracin ustunu de projekte et (2.2m yukari)
                    Vec3 wpTop = { wp.x, wp.y + 2.2f, wp.z };
                    Vec3 spTop = {0,0,0};
                    CGFloat boxH = 40;
                    if (few1n_worldToScreen(cam, wpTop, &spTop) && spTop.z > 0) {
                        CGFloat syTop = viewH - (spTop.y / scale);
                        boxH = fabs(sy - syTop); if (boxH < 14) boxH = 14; if (boxH > 220) boxH = 220;
                    }
                    float dist = 0;
                    if (haveMe) { float dx=wp.x-myPos.x, dy=wp.y-myPos.y, dz=wp.z-myPos.z; dist = sqrtf(dx*dx+dy*dy+dz*dz); }
                    g_espItems[g_espCount++] = (EspItem){ (float)sx, (float)sy, dist, (float)boxH };
                }
            }
        }
        [self.espOverlay setNeedsDisplay];   // kutu/cizgi/HUD yeniden ciz
    } @catch (...) {}
}

// ===== ISINLANMA (kendi araban - Rigidbody.position) =====
- (void)saveTeleportPos {
    if (unityAlive(g_rb)) {
        @try {
            rbGetPosIl(g_rb, &g_savedPos);
            g_hasSavedPos = true;
            FLog([NSString stringWithFormat:@"Konum kaydedildi: %.1f, %.1f, %.1f", g_savedPos.x, g_savedPos.y, g_savedPos.z]);
        } @catch (...) {}
    }
}
- (void)teleportSaved {
    if (unityAlive(g_rb) && g_hasSavedPos) {
        @try {
            Vec3 p = g_savedPos;
            rbSetPosIl(g_rb, &p);
            Vec3 z = {0,0,0}; rbSetVelIl(g_rb, &z);   // hizi sifirla
        } @catch (...) {}
    }
}
- (void)teleportForward {
    if (unityAlive(g_rb)) {
        @try {
            Vec3 p = {0,0,0};
            rbGetPosIl(g_rb, &p);
            p.z += 50.0f;   // 50 birim ileri (harita eksenine gore)
            p.y += 3.0f;
            rbSetPosIl(g_rb, &p);
        } @catch (...) {}
    }
}
- (void)teleportUp {
    if (unityAlive(g_rb)) {
        @try {
            Vec3 p = {0,0,0};
            rbGetPosIl(g_rb, &p);
            p.y += 30.0f;   // 30 birim yukari (takildiginda kurtul)
            rbSetPosIl(g_rb, &p);
        } @catch (...) {}
    }
}

// ===== SIFRE KIRICI: odalarin sifresini oku ve goster (il2cpp) =====
// HR_UI_RoomListLine: +0x50 password, +0x58 roomInfo -> rinfo_getName
// ===== MASS KICK: odadaki tum DIGER oyunculari at (SADECE MASTER/host isen calisir) =====
- (void)kickAllPlayers {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"⚔️ Tum Oyunculari At?"
        message:@"SADECE kendi odanda (host/master) calisir. Baskasinin odasinda Photon sunucusu yok sayar." preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"Evet, At" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a2){
        if (!pn_getPlayerListOthers) { FLog(@"PlayerListOthers pointeri yok"); return; }
        @try {
            void* pa = pn_getPlayerListOthers();   // kendisi HARIC diger oyuncular
            if (!ptrOk(pa)) { FLog(@"Odada baska oyuncu yok"); return; }
            int cnt = (int)(*(uintptr_t*)((uintptr_t)pa + 0x18));
            if (cnt <= 0 || cnt > 64) { FLog([NSString stringWithFormat:@"Oyuncu sayisi anormal (%d)", cnt]); return; }
            void** ps = (void**)((uintptr_t)pa + 0x20);
            int kicked = 0;
            for (int i = 0; i < cnt; i++) {
                void* p = ps[i]; if (!ptrOk(p)) continue;
                few1n_kickPlayer(p); kicked++;
            }
            FLog([NSString stringWithFormat:@"%d oyuncuya kick gonderildi (master isen dustuler, degilsen sunucu yok saydi)", kicked]);
        } @catch (...) { FLog(@"Mass kick hatasi"); }
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}

// ===== ODAYA GOZ AT: isimsiz anlik gir, oyuncularu oku, cik, ismi geri yukle =====
- (void)peekRoom {
    if (!g_roomLineType || !g_mFindObjectsPlural || !i_runtime_invoke || !pn_joinRoom) { FLog(@"Goz at hazir degil (oda listesine gir)"); return; }
    @try {
        void* a[1]; a[0] = g_roomLineType;
        void* arr = i_runtime_invoke(g_mFindObjectsPlural, NULL, a, NULL);
        if (!ptrOk(arr)) { FLog(@"Oda listesi yok"); return; }
        int cnt = (int)(*(uintptr_t*)((uintptr_t)arr + 0x18));
        if (cnt < 0 || cnt > 128) { FLog(@"Oda sayisi anormal"); return; }
        void** lines = (void**)((uintptr_t)arr + 0x20);
        NSMutableArray *rooms = [NSMutableArray array];   // @[gorunenAd, gercekAd]
        for (int i = 0; i < cnt; i++) {
            void* ln = lines[i]; if (!unityAlive(ln)) continue;
            void* rinfo = *(void**)((uintptr_t)ln + 0x58);
            NSString *real = (ptrOk(rinfo) && rinfo_getName) ? readStr(rinfo_getName(rinfo)) : @"";
            if (real.length == 0) continue;
            NSString *disp = [real stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (disp.length == 0) disp = [NSString stringWithFormat:@"Oda %d", i+1];
            [rooms addObject:@[disp, real]];
        }
        if (rooms.count == 0) { FLog(@"Oda bulunamadi"); return; }
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F441 Odaya Goz At"
            message:@"Sec: isimsiz anlik girer, oyuncularu gosterir, cikar" preferredStyle:UIAlertControllerStyleAlert];
        for (NSArray *r in rooms) {
            NSString *real = r[1];
            [ac addAction:[UIAlertAction actionWithTitle:r[0] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a2){ [self doPeek:real]; }]];
        }
        [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
        [self present:ac];
    } @catch (...) { FLog(@"Goz at hatasi"); }
}
- (void)doPeek:(NSString*)roomName {
    @try {
        NSString *savedNick = (pn_getNickName) ? readStr(pn_getNickName()) : nil;   // ismi kaydet
        if (pn_setNickName) { void* inv = mkStr(@"isimsiz"); if (inv) pn_setNickName(inv); }   // "isimsiz" yaz (bos calismiyor)
        void* ns = mkStr(roomName); if (!ns) { FLog(@"Isim olusmadi"); return; }
        pn_joinRoom(ns, NULL);   // odaya katil
        FLog(@"Odaya goz atiliyor...");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @try {
                NSMutableString *list = [NSMutableString string]; int n = 0;
                if (pn_getPlayerList) {
                    void* pa = pn_getPlayerList();
                    if (ptrOk(pa)) {
                        int c = (int)(*(uintptr_t*)((uintptr_t)pa + 0x18));
                        if (c > 0 && c <= 64) {
                            void** ps = (void**)((uintptr_t)pa + 0x20);
                            for (int i = 0; i < c; i++) {
                                void* p = ps[i]; if (!ptrOk(p)) continue;
                                NSString *nick = (ply_getNickName) ? readStr(ply_getNickName(p)) : @"";
                                if (nick.length == 0) nick = @"(isimsiz)";
                                [list appendFormat:@"• %@\n", nick]; n++;
                            }
                        }
                    }
                }
                if (pn_leaveRoom) pn_leaveRoom(false);   // PhotonNetwork.LeaveRoom (guvenilir cikis)
                if (lobbyGetInst && lobby_leaveRoom) { void* lob = lobbyGetInst(); if (lob) lobby_leaveRoom(lob); }   // yedek cikis
                if (pn_setNickName && savedNick.length) { void* rs = mkStr(savedNick); if (rs) pn_setNickName(rs); }   // ismi geri yukle
                UIAlertController *res = [UIAlertController alertControllerWithTitle:@"\U0001F441 Odadaki Oyuncular"
                    message:(n>0 ? list : @"Oyuncu okunamadi (oda dolu/kapali/sifreli olabilir)") preferredStyle:UIAlertControllerStyleAlert];
                [res addAction:[UIAlertAction actionWithTitle:@"Panoya Kopyala" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ [UIPasteboard generalPasteboard].string = list; }]];
                [res addAction:[UIAlertAction actionWithTitle:@"Kapat" style:UIAlertActionStyleCancel handler:nil]];
                [self present:res];
                FLog([NSString stringWithFormat:@"Goz at: %d oyuncu", n]);
            } @catch (...) { FLog(@"Goz at okuma hatasi"); }
        });
    } @catch (...) { FLog(@"Goz at hatasi"); }
}

- (void)showRoomPasswords {
    if (!g_roomLineType || !g_mFindObjectsPlural || !i_runtime_invoke) { FLog(@"Sifre kirici hazir degil (oda listesine gir)"); return; }
    @try {
        void* a[1]; a[0] = g_roomLineType;
        void* arr = i_runtime_invoke(g_mFindObjectsPlural, NULL, a, NULL);
        if (!ptrOk(arr)) { FLog(@"Oda listesi bulunamadi"); return; }
        int cnt = (int)(*(uintptr_t*)((uintptr_t)arr + 0x18));
        if (cnt < 0 || cnt > 128) { FLog(@"Oda sayisi anormal"); return; }
        void** lines = (void**)((uintptr_t)arr + 0x20);
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F513 Oda Sifreleri"
                                                                   message:@"Sifreli odalarin sifresi:" preferredStyle:UIAlertControllerStyleAlert];
        NSMutableString *list = [NSMutableString string];
        int shown = 0;
        for (int i = 0; i < cnt; i++) {
            void* ln = lines[i]; if (!unityAlive(ln)) continue;
            NSString *pw = readStr(*(void**)((uintptr_t)ln + 0x50));   // password
            NSString *nm = @"?";
            void* rinfo = *(void**)((uintptr_t)ln + 0x58);
            if (ptrOk(rinfo) && rinfo_getName) nm = readStr(rinfo_getName(rinfo));
            if (pw.length > 0) { [list appendFormat:@"\U0001F512 %@\n     sifre: %@\n\n", nm, pw]; shown++; }
        }
        ac.message = shown ? list : @"Sifreli oda yok (ya da liste bos).";
        [ac addAction:[UIAlertAction actionWithTitle:@"Panoya Kopyala" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
            [UIPasteboard generalPasteboard].string = list; FLog(@"Sifreler panoya kopyalandi");
        }]];
        [ac addAction:[UIAlertAction actionWithTitle:@"Kapat" style:UIAlertActionStyleCancel handler:nil]];
        [self present:ac];
        FLog([NSString stringWithFormat:@"%d sifreli oda bulundu", shown]);
    } @catch (...) { FLog(@"Sifre okuma hatasi"); }
}

- (void)teleportToPlayer {
    if (!unityAlive(g_rb)) { FLog(@"Once arabana bin"); return; }
    @try {
        Vec3 myPos = {0,0,0}; rbGetPosIl(g_rb, &myPos);
        NSMutableArray *rows = [NSMutableArray array];   // @[isim, mesafe, x,y,z]

        // ONCELIK: PhotonView ile ISIMLI liste. Owner(Player*)@0x80 -> nickname.
        // Field-read (metod cagirmaz) -> cokme YOK. IsMine@0x68 ile kendi araban elenir.
        if (g_photonViewType && g_isMineOff > 0 && g_pvOwnerOff > 0 && g_mFindObjectsPlural && i_runtime_invoke) {
            void* a[1]; a[0] = g_photonViewType;
            void* arr = i_runtime_invoke(g_mFindObjectsPlural, NULL, a, NULL);
            if (ptrOk(arr)) {
                int n = (int)(*(uintptr_t*)((uintptr_t)arr + 0x18));
                if (n > 0 && n <= 512) {
                    void** pvs = (void**)((uintptr_t)arr + 0x20);
                    NSMutableArray *seen = [NSMutableArray array];   // owner pointer dedupe
                    for (int i = 0; i < n; i++) {
                        void* pv = pvs[i]; if (!unityAlive(pv)) continue;
                        bool mine = *(bool*)((uintptr_t)pv + g_isMineOff);
                        if (mine) continue;                                     // kendi arabam -> atla
                        void* owner = *(void**)((uintptr_t)pv + g_pvOwnerOff);   // Player*
                        if (!ptrOk(owner)) continue;                            // sahipsiz obje -> atla
                        NSValue *ov = [NSValue valueWithPointer:owner];
                        if ([seen containsObject:ov]) continue;                 // ayni oyuncu tekrari
                        Vec3 p; if (!few1n_objPos(pv, &p)) continue;
                        [seen addObject:ov];
                        NSString *nm = (ply_getNickName) ? readStr(ply_getNickName(owner)) : nil;
                        if (nm.length == 0) nm = @"(isimsiz)";
                        float dx=p.x-myPos.x, dy=p.y-myPos.y, dz=p.z-myPos.z;
                        [rows addObject:@[nm, @(sqrtf(dx*dx+dy*dy+dz*dz)), @(p.x), @(p.y), @(p.z)]];
                    }
                }
            }
        }
        // YEDEK: PhotonView cozulemezse eski Rigidbody yontemi (isimsiz).
        if (rows.count == 0) {
            void* rbs[48]; int n = few1n_collectCars(rbs, 48);
            for (int i = 0; i < n; i++) {
                void* rb = rbs[i]; if (!unityAlive(rb)) continue;
                Vec3 p; rbGetPosIl(rb, &p);
                float dx=p.x-myPos.x, dy=p.y-myPos.y, dz=p.z-myPos.z;
                [rows addObject:@[[NSString stringWithFormat:@"Arac %d", i+1], @(sqrtf(dx*dx+dy*dy+dz*dz)), @(p.x), @(p.y), @(p.z)]];
            }
        }

        if (rows.count == 0) { FLog(@"Baska oyuncu yok (yarista dene)"); return; }
        [rows sortUsingComparator:^NSComparisonResult(NSArray *a, NSArray *b){ return [a[1] compare:b[1]]; }];
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F680 Oyuncuya Isinlan"
                                                                   message:[NSString stringWithFormat:@"%lu oyuncu - yanina isinlan", (unsigned long)rows.count] preferredStyle:UIAlertControllerStyleAlert];
        for (NSArray *r in rows) {
            NSString *nm = r[0];
            float dist = [r[1] floatValue], x = [r[2] floatValue], yy = [r[3] floatValue], z = [r[4] floatValue];
            [ac addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"\U0001F697 %@  (%.0fm)", nm, dist]
                style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
                if (!unityAlive(g_rb)) return;
                Vec3 t = { x, yy + 2.0f, z - 4.0f };   // hafif ustunde ve arkasinda (icine girme)
                rbSetPosIl(g_rb, &t);
                Vec3 zero = {0,0,0}; rbSetVelIl(g_rb, &zero);
                FLog([NSString stringWithFormat:@"%@ yanina isinlanildi (%.0fm)", nm, dist]);
            }]];
        }
        [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
        [self present:ac];
    } @catch (...) { FLog(@"Isinlanma hatasi"); }
}

- (void)tick {
    enforceScale();
    few1n_findCar();   // sadece arama (throttle'li); uygulama frameTick'te
    few1n_forcePlate(); // ozel plaka acikken il2cpp ile zorla (hook olu)
    // arac rengi acikken materyalleri BIR KEZ al (tekrar fetch instance sizdirir/coker)
    if (isCarColorEnabled && unityAlive(g_rb) && g_carMatCount == 0) few1n_refreshCarMats();
    // OTOMATIK TIP ARAMA: araba tipi yoksa periyodik yeniden coz.
    // Araba assembly'si sadece yarisa girince yuklenir -> aciliste bulunamayabilir.
    static int retryTick = 0, retryCount = 0;
    if (!g_carDriveTypeObj && retryCount < 40) {   // ~40 deneme (yaklasik 2 dk)
        if (++retryTick >= 6) {                    // her ~1.8 sn
            retryTick = 0; retryCount++;
            few1n_initIl2cpp();                    // guard'li: sadece eksikleri arar
            if (g_carDriveTypeObj) FLog(@"Araba tipi BULUNDU (otomatik yeniden arama)");
        }
    }
    // ~6 sn'de bir tek satir teshis (log spam azaltildi)
    static int tc = 0;
    if (++tc >= 20) {
        tc = 0;
        float ts = g_il2cppReady ? getTimeScaleVal() : -1.0f;
        FLog([NSString stringWithFormat:@"[DIAG] ARAMA=%ld carDrive=%@ rb=%@ TS=%.2f tip=%@ il2cpp=%@",
              fFind, g_carDrive ? @"VAR" : @"YOK", g_rb ? @"VAR" : @"YOK", ts,
              g_carDriveTypeObj ? @"VAR" : @"YOK", g_il2cppReady ? @"OK" : @"YOK"]);
    }
}

- (void)toggle {
    // Stealth Mode: triple-tap ile gizli acma
    NSDate *now = [NSDate date];
    if (stealthLastTap && [now timeIntervalSinceDate:stealthLastTap] < 0.5) {
        stealthTapCount++;
    } else {
        stealthTapCount = 1;
    }
    stealthLastTap = now;
    if (stealthTapCount >= 3) {
        isStealthMode = !isStealthMode;
        stealthTapCount = 0;
        FLog(isStealthMode ? @"STEALTH MODE ACIK - Menu gizli" : @"STEalth MODE KAPALI - Menu gorunur");
        self.fab.hidden = isStealthMode;
        if (!isStealthMode) {
            // Stealth kapandiginda FAB'i goster
            self.fab.hidden = NO;
            self.fab.alpha = 0;
            [UIView animateWithDuration:0.3 animations:^{ self.fab.alpha = 1; }];
        }
        // Panelleri gizle/ac
        self.panel.hidden = YES;
        return;
    }
    if (isStealthMode) {
        // Stealth moddayken normal toggle calismaz, sadece triple-tap ile acilir
        return;
    }
    if (self.panel.hidden) {
        [self refreshUI];
        self.panel.hidden = NO;
        [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:0 animations:^{
            self.panel.alpha = 1; self.panel.transform = CGAffineTransformIdentity;
        } completion:nil];
    } else {
        [UIView animateWithDuration:0.2 animations:^{
            self.panel.alpha = 0; self.panel.transform = CGAffineTransformMakeScale(0.9,0.9);
        } completion:^(BOOL f){ self.panel.hidden = YES; }];
    }
}

- (void)drag:(UIPanGestureRecognizer*)g {
    UIView *v = g.view; if (!v) return;
    CGPoint t = [g translationInView:v.superview];
    v.center = CGPointMake(v.center.x + t.x, v.center.y + t.y);
    [g setTranslation:CGPointZero inView:v.superview];
}

- (void)speedTap:(UIButton*)s {
    speedMode = (int)s.tag;
    saveInt(@"speedMode", speedMode);
    [self refreshUI];
    enforceScale();
}

- (void)tapDrift   { isDriftEnabled = !isDriftEnabled; saveBool(@"drift", isDriftEnabled); FLog(isDriftEnabled ? @"Drift Modu ACIK" : @"Drift Modu KAPALI"); [self refreshUI]; }
- (void)tapCruise  { isCruiseEnabled = !isCruiseEnabled; saveBool(@"cruise", isCruiseEnabled); FLog(isCruiseEnabled ? @"Cruise Control ACIK" : @"Cruise Control KAPALI"); [self refreshUI]; }
- (void)editCruiseSpeed {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"🚗 Sabit Hiz (Cruise Control)"
                                                               message:@"Hedef hizi km/h cinsinden secin:" preferredStyle:UIAlertControllerStyleAlert];
    NSArray *speeds = @[@120, @160, @200, @250, @300, @350];
    for (NSNumber *s in speeds) {
        int v = [s intValue];
        [ac addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%d km/h", v] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
            cruiseSpeedKmh = (float)v; saveFloat(@"cruiseSpeed", cruiseSpeedKmh);
            FLog([NSString stringWithFormat:@"Sabit hiz ayarlandi: %d km/h", v]);
            [self refreshUI];
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}
- (void)tapAntiGrav  { isAntiGrav = !isAntiGrav; saveBool(@"antigrav", isAntiGrav); [self refreshUI]; }
- (void)tapGodmode   { isGodmode = !isGodmode; saveBool(@"godmode", isGodmode); if(!isGodmode) g_myPlayerHandler = NULL; FLog(isGodmode ? @"GODMODE acik - kaza yapmazsin" : @"Godmode kapali"); [self refreshUI]; }
- (void)tapSelektor  { isSelektor = !isSelektor; saveBool(@"selektor", isSelektor); if(!isSelektor) g_myLights = NULL; FLog(isSelektor ? @"Selektor acik - far cakiyor" : @"Selektor kapali"); [self refreshUI]; }
- (void)editSelektorSpeed {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F4A1 Selektor Hizi"
        message:@"Cakma hizini sec (kucuk = hizli)" preferredStyle:UIAlertControllerStyleAlert];
    NSArray *opts = @[@[@"⚡ Cok Hizli (strobe)", @1], @[@"\U0001F525 Hizli", @2], @[@"➡️ Orta", @4], @[@"\U0001F422 Yavas", @8], @[@"\U0001F40C Cok Yavas", @14]];
    for (NSArray *o in opts) {
        int r = [o[1] intValue];
        [ac addAction:[UIAlertAction actionWithTitle:o[0] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
            g_selFlashRate = r; saveInt(@"selRate", r); FLog([NSString stringWithFormat:@"Selektor hizi ayarlandi: %d frame", r]); [self refreshUI];
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}
- (void)tapCarSize   { isCarSizeEnabled = !isCarSizeEnabled; saveBool(@"carsize", isCarSizeEnabled); [self refreshUI]; }
- (void)editCarSize {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F4CF Arac Boyutu"
        message:@"Kat (0.3 = minik, 1 = normal, 3 = dev)" preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){ tf.keyboardType = UIKeyboardTypeDecimalPad; tf.text = [NSString stringWithFormat:@"%.1f", carSizeVal]; }];
    [ac addAction:[UIAlertAction actionWithTitle:@"Uygula" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        float v = [ac.textFields.firstObject.text floatValue];
        if (v >= 0.3f && v <= 5.0f) { carSizeVal = v; saveFloat(@"carSize", v); isCarSizeEnabled = true; saveBool(@"carsize", true); }
        [self refreshUI];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}
- (void)tapCarColor  { isCarColorEnabled = !isCarColorEnabled; saveBool(@"carcolor", isCarColorEnabled); if (isCarColorEnabled) few1n_refreshCarMats(); [self refreshUI]; }
- (void)tapCarColorRainbow { carColorRainbow = !carColorRainbow; saveBool(@"carrainbow", carColorRainbow); [self refreshUI]; }
- (void)pickCarColor {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F3A8 Sabit Renk" message:@"Renk sec (RGB dongu kapaliyken)" preferredStyle:UIAlertControllerStyleActionSheet];
    void (^add)(NSString*, float, float, float) = ^(NSString *nm, float r, float g, float b){
        [ac addAction:[UIAlertAction actionWithTitle:nm style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
            g_carColor = (Color4){r,g,b,1.0f}; carColorRainbow = false;
            saveBool(@"carrainbow", false); saveFloat(@"carR", r); saveFloat(@"carG", g); saveFloat(@"carB", b);
            isCarColorEnabled = true; saveBool(@"carcolor", true); few1n_refreshCarMats(); [self refreshUI];
        }]];
    };
    add(@"\U0001F534 Kirmizi", 1,0,0); add(@"\U0001F7E0 Turuncu", 1,0.5f,0); add(@"\U0001F7E1 Sari", 1,1,0);
    add(@"\U0001F7E2 Yesil", 0,1,0); add(@"\U0001F535 Mavi", 0,0.4f,1); add(@"\U0001F7E3 Mor", 0.6f,0,1);
    add(@"⚫ Siyah", 0.02f,0.02f,0.02f); add(@"⚪ Beyaz", 1,1,1);
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    if (ac.popoverPresentationController) { ac.popoverPresentationController.sourceView = self.panel; ac.popoverPresentationController.sourceRect = CGRectMake(self.panel.bounds.size.width/2, self.panel.bounds.size.height/2, 1, 1); }
    [self present:ac];
}
- (void)tapFly       { isFlyEnabled            = !isFlyEnabled;            saveBool(@"fly", isFlyEnabled);                  [self refreshUI]; }
- (void)tapLowGrav   { isLowGravEnabled        = !isLowGravEnabled;        saveBool(@"lowgrav", isLowGravEnabled);          [self refreshUI]; }
- (void)tapBypass    { isBypassPasswordEnabled  = !isBypassPasswordEnabled; saveBool(@"bypass", isBypassPasswordEnabled);    [self refreshUI]; }
- (void)tapAutoMoney { isAutoMoneyEnabled        = !isAutoMoneyEnabled;      saveBool(@"automoney", isAutoMoneyEnabled);      [self refreshUI]; }

- (void)tapChatSpam {
    isSpamEnabled = !isSpamEnabled;
    saveBool(@"chatspam", isSpamEnabled);
    if (spamTimer) { [spamTimer invalidate]; spamTimer = nil; }
    if (isSpamEnabled)
        spamTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(fireSpam) userInfo:nil repeats:YES];
    [self refreshUI];
}

// YENI: Matrix / Glitch Chat Modlari
- (void)tapMatrixChat {
    isMatrixChatEnabled = !isMatrixChatEnabled;
    if (isMatrixChatEnabled) isGlitchChatEnabled = false;
    saveBool(@"matrixchat", isMatrixChatEnabled);
    saveBool(@"glitchchat", false);
    FLog(isMatrixChatEnabled ? @"Matrix Chat Modu ACIK" : @"Matrix Chat Modu KAPALI");
    [self refreshUI];
}
- (void)tapGlitchChat {
    isGlitchChatEnabled = !isGlitchChatEnabled;
    if (isGlitchChatEnabled) isMatrixChatEnabled = false;
    saveBool(@"glitchchat", isGlitchChatEnabled);
    saveBool(@"matrixchat", false);
    FLog(isGlitchChatEnabled ? @"Glitch Chat Modu ACIK" : @"Glitch Chat Modu KAPALI");
    [self refreshUI];
}
- (void)sendChatTemplate {
    if (!chatGetInst || !chatSend) { FLog(@"Chat pointeri yok - odaya gir"); return; }
    NSArray *templates = chatTemplates();
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"📋 Hacker Chat Sablonlari"
                                                               message:@"Sec - chate gonderilir" preferredStyle:UIAlertControllerStyleAlert];
    for (int i = 0; i < (int)templates.count; i++) {
        NSString *t = templates[i];
        [ac addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%d. %@", i+1, t] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
            @try { void* mgr = chatGetInst(); void* s = mkStr(t); if (mgr && s) chatSend(mgr, s); } @catch (...) {}
            FLog([NSString stringWithFormat:@"Chat sablonu gonderildi: %d", i+1]);
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}

- (void)fireSpam {
    if (!chatGetInst || !chatSend) return;
    @try {
        void* mgr = chatGetInst();
        if (!mgr) return;
        NSString *base = [NSString stringWithUTF8String:chatSpamText];
        NSString *col = [NSString stringWithUTF8String:spamColorHex];
        NSString *msg;
        static int rbIdx = 0;
        if (spamStyle == 1)      msg = [NSString stringWithFormat:@"═══ %@ ═══", base];
        else if (spamStyle == 2) msg = [NSString stringWithFormat:@"★彡 %@ 彡★", base];
        else if (spamStyle == 3) msg = [NSString stringWithFormat:@"<color=#%@><b>%@</b></color>", col, base];       // secili renk
        else if (spamStyle == 4) msg = rainbowWrap(base, rbIdx++);                                                    // gokkusagi
        else if (spamStyle == 5) msg = [NSString stringWithFormat:@"<size=150%%><color=#%@><b>%@</b></color></size>", col, base]; // buyuk+renk
        else if (spamStyle == 6) msg = [NSString stringWithFormat:@"<color=#%@>『 %@ 』</color>", col, base];          // cerceve+renk
        else if (spamStyle == 7) msg = [NSString stringWithFormat:@"<size=200%%>%@</size>", base];                    // BUYUK yazi (renksiz)
        else                     msg = base;
        void* s = mkStr(msg);
        if (s) chatSend(mgr, s);
    } @catch (...) {}
}

- (void)pickSpamStyle:(UIButton*)b {
    spamStyle = (spamStyle + 1) % 8;
    saveInt(@"spamStyle", spamStyle);
    NSArray *names = @[@"Duz", @"Cerceveli", @"Semboller", @"Renkli", @"Gokkusagi", @"Buyuk+Renk", @"Cerceve+Renk", @"BUYUK"];
    [b setTitle:[NSString stringWithFormat:@"\U0001F3AD Spam Stili: %@", names[spamStyle % 8]] forState:UIControlStateNormal];
}
- (void)pickSpamColor {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F3A8 Spam Rengi" message:@"Renkli stiller icin" preferredStyle:UIAlertControllerStyleActionSheet];
    void (^add)(NSString*, const char*) = ^(NSString *nm, const char *hex){
        [ac addAction:[UIAlertAction actionWithTitle:nm style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
            strncpy(spamColorHex, hex, sizeof(spamColorHex)-1); spamColorHex[sizeof(spamColorHex)-1]='\0';
            saveStr(@"spamColor", [NSString stringWithUTF8String:hex]); [self refreshUI];
        }]];
    };
    add(@"\U0001F534 Kirmizi", "FF3B30"); add(@"\U0001F7E0 Turuncu", "FF9500"); add(@"\U0001F7E1 Sari", "FFCC00");
    add(@"\U0001F7E2 Yesil", "34C759"); add(@"\U0001F535 Mavi", "007AFF"); add(@"\U0001F7E3 Mor", "AF52DE");
    add(@"\U0001F338 Pembe", "FF2D55"); add(@"⚪ Cyan", "00FFFF");
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    if (ac.popoverPresentationController) { ac.popoverPresentationController.sourceView = self.panel; ac.popoverPresentationController.sourceRect = CGRectMake(self.panel.bounds.size.width/2, self.panel.bounds.size.height/2, 1, 1); }
    [self present:ac];
}

// Metni donen gokkusagi renkle sar (chat'te richText render edilir -> renkli gorunur)
static NSString* rainbowWrap(NSString* text, int idx) {
    static NSArray *cols = nil;
    if (!cols) cols = @[@"FF3B30",@"FF9500",@"FFCC00",@"34C759",@"00C7BE",@"007AFF",@"AF52DE",@"FF2D55"];
    NSString *c = cols[((idx % (int)cols.count) + (int)cols.count) % (int)cols.count];
    return [NSString stringWithFormat:@"<color=#%@><b>%@</b></color>", c, text];
}

// ===== SARKI SOZU -> CHAT (altyazi gibi her satiri sirayla gonder) =====
- (void)stopLyrics {
    isLyricsEnabled = false;
    if (lyricsTimer) { [lyricsTimer invalidate]; lyricsTimer = nil; }
    [self refreshUI];
}
- (void)fireLyrics {
    if (!chatGetInst || !chatSend || !g_lyrics || g_lyrics.count == 0) { [self stopLyrics]; return; }
    @try {
        if (g_lyricsIdx >= (int)g_lyrics.count) {
            if (lyricsLoop) { g_lyricsIdx = 0; }
            else { FLog(@"Sarki sozu bitti"); [self stopLyrics]; return; }
        }
        NSString *line = g_lyrics[g_lyricsIdx];
        g_lyricsIdx++;
        if (line.length == 0) return;   // bos satiri atla (zamanlamayi korur)
        NSString *msg = lyricsColorCycle ? rainbowWrap(line, g_colorIdx++) : line;
        void* mgr = chatGetInst();
        void* s = mkStr(msg);
        if (mgr && s) chatSend(mgr, s);
    } @catch (...) {}
}
- (void)tapLyrics {
    if (!isLyricsEnabled) {
        if (!g_lyrics || g_lyrics.count == 0) {
            UIAlertController *w = [UIAlertController alertControllerWithTitle:@"\U0001F3B5 Once sarki sozu gerek"
                message:@"Sozu once getir:\n• 'Sarki Ara' ile internetten\n• ya da 'Elle Sarki Sozu Gir'" preferredStyle:UIAlertControllerStyleAlert];
            [w addAction:[UIAlertAction actionWithTitle:@"\U0001F50D Sarki Ara" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ [self fetchLyricsByName]; }]];
            [w addAction:[UIAlertAction actionWithTitle:@"Kapat" style:UIAlertActionStyleCancel handler:nil]];
            [self present:w];
            [self refreshUI]; return;
        }
        if (!chatGetInst || !chatSend) { FLog(@"Chat pointeri yok - odaya gir"); [self refreshUI]; return; }
        isLyricsEnabled = true;
        g_lyricsIdx = 0; g_colorIdx = 0;
        if (lyricsTimer) [lyricsTimer invalidate];
        lyricsTimer = [NSTimer scheduledTimerWithTimeInterval:lyricsInterval target:self selector:@selector(fireLyrics) userInfo:nil repeats:YES];
        FLog([NSString stringWithFormat:@"Sarki sozu basladi (%lu satir, %.1fs aralik)", (unsigned long)g_lyrics.count, lyricsInterval]);
    } else {
        [self stopLyrics];
    }
    [self refreshUI];
}
- (void)tapLyricsColor { lyricsColorCycle = !lyricsColorCycle; saveBool(@"lyricsColor", lyricsColorCycle); [self refreshUI]; }
- (void)tapLyricsLoop  { lyricsLoop = !lyricsLoop; saveBool(@"lyricsLoop", lyricsLoop); [self refreshUI]; }

// Cok satirli sarki sozu giris ekrani (her satir ayri chat mesaji olur)
- (void)editLyrics {
    UIWindow *w = getKeyWindow(); if (!w) return;
    if (self.lyricsOverlay) { [self.lyricsOverlay removeFromSuperview]; self.lyricsOverlay = nil; }
    CGFloat W = w.bounds.size.width, H = w.bounds.size.height;
    CGFloat ow = MIN(560.0, W-20), oh = MIN(400.0, H-20);
    self.lyricsOverlay = [[UIView alloc] initWithFrame:CGRectMake((W-ow)/2,(H-oh)/2,ow,oh)];
    self.lyricsOverlay.backgroundColor = [UIColor colorWithRed:0.97 green:0.99 blue:1.0 alpha:0.99];
    self.lyricsOverlay.layer.cornerRadius = 16;
    self.lyricsOverlay.layer.borderWidth = 1.5;
    self.lyricsOverlay.layer.borderColor = C_ACCENT.CGColor;

    UILabel *tl = [[UILabel alloc] initWithFrame:CGRectMake(14,10,ow-28,22)];
    tl.text = @"\U0001F3B5 Sarki Sozu (her satir ayri chat mesaji)";
    tl.textColor = C_TEXT; tl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [self.lyricsOverlay addSubview:tl];

    self.lyricsInput = [[UITextView alloc] initWithFrame:CGRectMake(10,38,ow-20,oh-96)];
    self.lyricsInput.backgroundColor = [UIColor colorWithRed:0.93 green:0.96 blue:0.99 alpha:1.0];
    self.lyricsInput.textColor = C_TEXT;
    self.lyricsInput.font = [UIFont systemFontOfSize:14];
    self.lyricsInput.layer.cornerRadius = 8;
    if (g_lyrics.count) self.lyricsInput.text = [g_lyrics componentsJoinedByString:@"\n"];
    else self.lyricsInput.text = @"";
    [self.lyricsOverlay addSubview:self.lyricsInput];

    UIButton *save = [UIButton buttonWithType:UIButtonTypeSystem];
    save.frame = CGRectMake(10, oh-46, (ow-30)/2, 34);
    save.backgroundColor = C_ON; save.layer.cornerRadius = 8;
    [save setTitle:@"Kaydet" forState:UIControlStateNormal];
    [save setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    save.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [save addTarget:self action:@selector(saveLyrics) forControlEvents:UIControlEventTouchUpInside];
    [self.lyricsOverlay addSubview:save];

    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
    cancel.frame = CGRectMake(ow/2+5, oh-46, (ow-30)/2, 34);
    cancel.backgroundColor = [UIColor colorWithRed:0.85 green:0.88 blue:0.92 alpha:1.0]; cancel.layer.cornerRadius = 8;
    [cancel setTitle:@"Iptal" forState:UIControlStateNormal];
    [cancel setTitleColor:C_TEXT forState:UIControlStateNormal];
    cancel.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [cancel addTarget:self action:@selector(closeLyrics) forControlEvents:UIControlEventTouchUpInside];
    [self.lyricsOverlay addSubview:cancel];

    [w addSubview:self.lyricsOverlay];
    [self.lyricsInput becomeFirstResponder];
}
- (void)saveLyrics {
    NSString *txt = self.lyricsInput.text ?: @"";
    NSArray *raw = [txt componentsSeparatedByString:@"\n"];
    g_lyrics = [NSMutableArray array];
    for (NSString *l in raw) {
        NSString *t = [l stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        [g_lyrics addObject:t];   // bos satirlari da tut (zamanlama duraklamasi olur)
    }
    saveStr(@"lyricsText", txt);
    FLog([NSString stringWithFormat:@"Sarki sozu kaydedildi: %lu satir", (unsigned long)g_lyrics.count]);
    [self closeLyrics];
    [self refreshUI];
}
- (void)closeLyrics {
    if (self.lyricsInput) [self.lyricsInput resignFirstResponder];
    if (self.lyricsOverlay) { [self.lyricsOverlay removeFromSuperview]; self.lyricsOverlay = nil; }
}
- (void)editLyricsInterval {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F3B5 Satir Araligi"
                                                               message:@"Her satir arasi saniye (0.3 - 10)" preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){ tf.keyboardType = UIKeyboardTypeDecimalPad; tf.text = [NSString stringWithFormat:@"%.1f", lyricsInterval]; }];
    [ac addAction:[UIAlertAction actionWithTitle:@"Kaydet" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        float v = [ac.textFields.firstObject.text floatValue];
        if (v >= 0.3f && v <= 10.0f) { lyricsInterval = v; saveFloat(@"lyricsInterval", v); }
        [self refreshUI];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}

// ===== SARKI ARA + SEC + SOZU GETIR (arama cubugu, sen yazmazsin) =====
// api.lyrics.ovh: ucretsiz, anahtarsiz. /suggest -> arama, /v1 -> sozler
// NOT: YT/Spotify URL'si sarki adina cevrilemez -> sarki ADINI yaz (link degil).
- (void)fetchLyricsByName {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F3B5 Sarki Ara"
                                                               message:@"Sarki adi yaz, listeden sec\n(URL degil, isim: orn 'kuzu kuzu')" preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){
        tf.placeholder = @"Sarki / sanatci adi";
        NSString *last = loadStr(@"lastSong", @"");
        if (last.length) tf.text = last;
    }];
    [ac addAction:[UIAlertAction actionWithTitle:@"\U0001F50D Ara" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSString *q = ac.textFields.firstObject.text ?: @"";
        if (q.length < 2) { FLog(@"Arama cok kisa"); return; }
        saveStr(@"lastSong", q);
        [self doSearchLyrics:q];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}
// Aramayi yap, eslesen sarkilari liste halinde goster
- (void)doSearchLyrics:(NSString*)q {
    NSString *eq = [q stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]] ?: @"";
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.lyrics.ovh/suggest/%@", eq]];
    if (!url) { FLog(@"Gecersiz arama"); return; }
    FLog([NSString stringWithFormat:@"Araniyor: %@ ...", q]);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err){
        NSMutableArray *results = [NSMutableArray array];   // her eleman: @[artist, title]
        if (data && !err) {
            @try {
                NSDictionary *j = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSArray *arr = j[@"data"];
                if ([arr isKindOfClass:[NSArray class]]) {
                    for (NSDictionary *song in arr) {
                        if (![song isKindOfClass:[NSDictionary class]]) continue;
                        NSString *title = song[@"title"];
                        NSString *artist = @"";
                        if ([song[@"artist"] isKindOfClass:[NSDictionary class]]) artist = song[@"artist"][@"name"];
                        NSString *cover = @"";
                        if ([song[@"album"] isKindOfClass:[NSDictionary class]]) {
                            NSDictionary *alb = song[@"album"];
                            cover = alb[@"cover_small"] ?: (alb[@"cover_medium"] ?: (alb[@"cover"] ?: @""));
                        }
                        if ([title isKindOfClass:[NSString class]]) {
                            [results addObject:@[artist ?: @"", title, cover ?: @""]];
                            if (results.count >= 10) break;
                        }
                    }
                }
            } @catch (...) {}
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (results.count == 0) { FLog(@"Sonuc bulunamadi, baska ara"); return; }
            [self showSongPicker:results];
        });
    }];
    [task resume];
}
// Album resimli sarki secim ekrani (kaydirilabilir, resimler async yuklenir)
- (void)showSongPicker:(NSArray*)results {
    UIWindow *w = getKeyWindow(); if (!w) return;
    if (self.songPicker) { [self.songPicker removeFromSuperview]; self.songPicker = nil; }
    CGFloat W = w.bounds.size.width, H = w.bounds.size.height;
    CGFloat ow = MIN(460.0, W-20), oh = MIN(440.0, H-20);
    UIView *ov = [[UIView alloc] initWithFrame:CGRectMake((W-ow)/2,(H-oh)/2,ow,oh)];
    ov.backgroundColor = [UIColor colorWithRed:0.97 green:0.99 blue:1.0 alpha:0.99];
    ov.layer.cornerRadius = 16; ov.layer.borderWidth = 1.5; ov.layer.borderColor = C_ACCENT.CGColor;
    self.songPicker = ov;
    UILabel *tl = [[UILabel alloc] initWithFrame:CGRectMake(14,10,ow-60,24)];
    tl.text = @"\U0001F3B5 Sarki Sec"; tl.textColor = C_TEXT; tl.font = [UIFont boldSystemFontOfSize:15];
    [ov addSubview:tl];
    UIButton *x = [UIButton buttonWithType:UIButtonTypeSystem];
    x.frame = CGRectMake(ow-42,8,32,32); [x setTitle:@"✕" forState:UIControlStateNormal];
    [x setTitleColor:C_TEXT forState:UIControlStateNormal]; x.titleLabel.font = [UIFont systemFontOfSize:18];
    [x addTarget:self action:@selector(closeSongPicker) forControlEvents:UIControlEventTouchUpInside];
    [ov addSubview:x];
    UIScrollView *sc = [[UIScrollView alloc] initWithFrame:CGRectMake(8,40,ow-16,oh-48)];
    [ov addSubview:sc];
    CGFloat yy = 0;
    for (NSArray *r in results) {
        NSString *artist = r[0], *title = r[1], *cover = r[2];
        UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0,yy,ow-16,60)];
        row.backgroundColor = [UIColor colorWithRed:0.93 green:0.96 blue:0.99 alpha:1.0];
        row.layer.cornerRadius = 10;
        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(6,6,48,48)];
        iv.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1]; iv.layer.cornerRadius = 6; iv.clipsToBounds = YES;
        iv.contentMode = UIViewContentModeScaleAspectFill;
        [row addSubview:iv];
        if (cover.length) {
            NSURL *cu = [NSURL URLWithString:cover];
            if (cu) { [[[NSURLSession sharedSession] dataTaskWithURL:cu completionHandler:^(NSData *d, NSURLResponse *rp, NSError *e){
                if (d) { UIImage *im = [UIImage imageWithData:d]; if (im) dispatch_async(dispatch_get_main_queue(), ^{ iv.image = im; }); }
            }] resume]; }
        }
        UILabel *lb = [[UILabel alloc] initWithFrame:CGRectMake(62,8,ow-16-70,44)];
        lb.numberOfLines = 2;
        NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n%@", title, artist]];
        [s addAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:13], NSForegroundColorAttributeName:C_TEXT} range:NSMakeRange(0, title.length)];
        [s addAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:11], NSForegroundColorAttributeName:C_SUB} range:NSMakeRange(title.length, s.length-title.length)];
        lb.attributedText = s;
        [row addSubview:lb];
        UIButton *tap = [UIButton buttonWithType:UIButtonTypeCustom];
        tap.frame = row.bounds;
        objc_setAssociatedObject(tap, "sartist", artist, OBJC_ASSOCIATION_RETAIN);
        objc_setAssociatedObject(tap, "stitle", title, OBJC_ASSOCIATION_RETAIN);
        [tap addTarget:self action:@selector(songPicked:) forControlEvents:UIControlEventTouchUpInside];
        [row addSubview:tap];
        [sc addSubview:row];
        yy += 66;
    }
    sc.contentSize = CGSizeMake(ow-16, yy);
    [w addSubview:ov];
}
- (void)songPicked:(UIButton*)b {
    NSString *artist = objc_getAssociatedObject(b, "sartist");
    NSString *title = objc_getAssociatedObject(b, "stitle");
    [self closeSongPicker];
    [self doFetchLyricsArtist:artist title:title];
}
- (void)closeSongPicker { if (self.songPicker) { [self.songPicker removeFromSuperview]; self.songPicker = nil; } }
- (void)doFetchLyricsArtist:(NSString*)artist title:(NSString*)title {
    [self doFetchLyrics:[NSString stringWithFormat:@"%@ - %@", artist ?: @"", title ?: @""]];
}
- (void)doFetchLyrics:(NSString*)q {
    NSString *artist = @"", *title = q;
    NSRange dash = [q rangeOfString:@" - "];
    if (dash.location != NSNotFound) { artist = [q substringToIndex:dash.location]; title = [q substringFromIndex:dash.location + 3]; }
    artist = [artist stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    title  = [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    FLog([NSString stringWithFormat:@"Sarki sozu araniyor (LRCLIB): %@ ...", q]);
    // Adim 1 - LRCLIB : genis kapsamli, bedava
    NSString *lq = [[NSString stringWithFormat:@"%@ %@", artist, title] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]] ?: @"";
    NSURL *lrc = [NSURL URLWithString:[NSString stringWithFormat:@"https://lrclib.net/api/search?q=%@", lq]];
    if (!lrc) { [self fetchOvhFallback:artist title:title]; return; }
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:lrc];
    [req setValue:@"FEW1NMod/1.0 (iOS)" forHTTPHeaderField:@"User-Agent"];
    NSString *ac = artist, *tc = title;
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err){
        NSString *lyr = nil;
        if (data && !err) {
            @try {
                id arr = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([arr isKindOfClass:[NSArray class]]) {
                    for (NSDictionary *it in (NSArray*)arr) {
                        if (![it isKindOfClass:[NSDictionary class]]) continue;
                        NSString *pl = it[@"plainLyrics"];
                        if ([pl isKindOfClass:[NSString class]] && pl.length > 0) { lyr = pl; break; }
                    }
                }
            } @catch (...) {}
        }
        if (lyr.length) dispatch_async(dispatch_get_main_queue(), ^{ [self fillLyrics:lyr]; });
        else [self fetchOvhFallback:ac title:tc];   // Adim 2 - LRCLIB bulamadi, lyrics.ovh yedek
    }] resume];
}
- (void)fetchOvhFallback:(NSString*)artist title:(NSString*)title {
    NSCharacterSet *set = [NSCharacterSet URLPathAllowedCharacterSet];
    NSString *ea = [artist stringByAddingPercentEncodingWithAllowedCharacters:set] ?: @"";
    NSString *et = [title stringByAddingPercentEncodingWithAllowedCharacters:set] ?: @"";
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.lyrics.ovh/v1/%@/%@", ea, et]];
    if (!url) { dispatch_async(dispatch_get_main_queue(), ^{ FLog(@"Sarki sozu bulunamadi"); }); return; }
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err){
        NSString *lyr = nil;
        if (data && !err) { @try { NSDictionary *j = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil]; if ([j isKindOfClass:[NSDictionary class]] && [j[@"lyrics"] isKindOfClass:[NSString class]]) lyr = j[@"lyrics"]; } @catch (...) {} }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (lyr.length) [self fillLyrics:lyr];
            else FLog(@"Sarki sozu hicbir kaynakta yok (baska sarki/yazim dene)");
        });
    }] resume];
}
- (void)fillLyrics:(NSString*)lyr {
    NSArray *lines = [lyr componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    g_lyrics = [NSMutableArray array];
    for (NSString *l in lines) [g_lyrics addObject:[l stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
    saveStr(@"lyricsText", [g_lyrics componentsJoinedByString:@"\n"]);
    FLog([NSString stringWithFormat:@"✓ Sarki sozu geldi: %lu satir. Artik 'Baslat'a basabilirsin.", (unsigned long)g_lyrics.count]);
    [self refreshUI];
}

- (void)fireAscii {
    if (!chatGetInst || !chatSend) return;
    @try {
        NSArray *anims = asciiAnims();
        if (anims.count == 0) return;
        if (asciiAnimIndex < 0 || asciiAnimIndex >= (int)anims.count) asciiAnimIndex = 0;
        NSArray *frames = anims[asciiAnimIndex];
        if (frames.count == 0) return;
        if (asciiFrameIdx < 0 || asciiFrameIdx >= (int)frames.count) asciiFrameIdx = 0;
        NSString *frame = frames[asciiFrameIdx];
        asciiFrameIdx++;
        if (asciiColorCycle) frame = rainbowWrap(frame, g_colorIdx++);   // gokkusagi renk dongusu
        void* mgr = chatGetInst();
        if (!mgr) return;
        void* s = mkStr(frame);
        if (s) chatSend(mgr, s);
    } @catch (...) {}
}
- (void)tapAsciiColor { asciiColorCycle = !asciiColorCycle; saveBool(@"asciiColor", asciiColorCycle); [self refreshUI]; }

- (void)tapAsciiAnim {
    isAsciiAnimEnabled = !isAsciiAnimEnabled;
    saveBool(@"asciianim", isAsciiAnimEnabled);
    if (asciiTimer) { [asciiTimer invalidate]; asciiTimer = nil; }
    if (isAsciiAnimEnabled) {
        asciiFrameIdx = 0;
        asciiTimer = [NSTimer scheduledTimerWithTimeInterval:0.4 target:self selector:@selector(fireAscii) userInfo:nil repeats:YES];
    }
    [self refreshUI];
}

- (void)pickAsciiAnim:(UIButton*)b {
    asciiAnimIndex = (asciiAnimIndex + 1) % (int)asciiAnims().count;
    asciiFrameIdx = 0;
    saveInt(@"asciiIdx", asciiAnimIndex);
    [b setTitle:[NSString stringWithFormat:@"\U0001F3AC Animasyon Sec (%d/%d)", asciiAnimIndex + 1, (int)asciiAnims().count] forState:UIControlStateNormal];
}

- (void)addMoneyTap {
    if (playerManagerGetInst && pm_addMoney) {
        @try {
            void* pm = playerManagerGetInst();
            if (pm) {
                pm_addMoney(pm, customMoneyAmount);
                if (pm_syncWithServer) { @try { pm_syncWithServer(pm); } @catch (...) {} }
                [self.moneyBtn setTitle:[NSString stringWithFormat:@"\U0001F4B5 %@ Eklendi ✅", [self shortNum:customMoneyAmount]] forState:UIControlStateNormal];
                [self.moneyBtn setTitleColor:C_ON forState:UIControlStateNormal];
            } else {
                [self.moneyBtn setTitle:@"\U0001F4B5 Oyuna gir!" forState:UIControlStateNormal];
                [self.moneyBtn setTitleColor:C_RED forState:UIControlStateNormal];
            }
        } @catch (...) {}
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ [self refreshUI]; });
}

- (void)changeName {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F4DB Isim Degistir" message:@"Yeni ismin:" preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){ tf.placeholder = @"FEW1N"; tf.clearButtonMode = UITextFieldViewModeAlways; }];
    [ac addAction:[UIAlertAction actionWithTitle:@"Degistir" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSString *name = ac.textFields.firstObject.text;
        if (name.length > 0 && pn_setNickName) {
            void* ns = mkStr(name);
            if (ns) {
                pn_setNickName(ns);
                if (playerManagerGetInst && pm_updateNicknameInternal) {
                    @try { void* pm = playerManagerGetInst(); if (pm) pm_updateNicknameInternal(pm, ns); } @catch (...) {}
                }
                [self.nameBtn setTitle:[NSString stringWithFormat:@"\U0001F4DB Isim: %@ ✅", name] forState:UIControlStateNormal];
                [self.nameBtn setTitleColor:C_ON forState:UIControlStateNormal];
            }
        }
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}

// Her harfe rainbow renk verir (Unity TMP rich text acigi)
- (void)rainbowName {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F308 Rainbow Isim"
                                                               message:@"Isim yaz - her harf rainbow olur:" preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){ tf.text = @"FEW1N"; tf.clearButtonMode = UITextFieldViewModeAlways; }];
    [ac addAction:[UIAlertAction actionWithTitle:@"Uygula" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSString *src = ac.textFields.firstObject.text;
        if (src.length == 0 || !pn_setNickName) return;
        NSArray *cols = @[@"#FF0000",@"#FF7F00",@"#FFFF00",@"#00FF00",@"#00FFFF",@"#4466FF",@"#FF00FF"];
        NSMutableString *rich = [NSMutableString string];
        for (NSUInteger i = 0; i < src.length; i++) {
            NSString *ch = [src substringWithRange:NSMakeRange(i,1)];
            [rich appendFormat:@"<color=%@><b>%@</b></color>", cols[i % cols.count], ch];
        }
        void* ns = mkStr(rich);
        if (ns) {
            pn_setNickName(ns);
            if (playerManagerGetInst && pm_updateNicknameInternal) {
                @try { void* pm = playerManagerGetInst(); if (pm) pm_updateNicknameInternal(pm, ns); } @catch (...) {}
            }
            [self.nameBtn setTitle:@"\U0001F308 Rainbow isim aktif ✅" forState:UIControlStateNormal];
            [self.nameBtn setTitleColor:C_ON forState:UIControlStateNormal];
        }
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}

// ===== FAKE ODA SPAM =====
- (void)createOneRoom {
    @try {
        // BENZERSIZ isim: Photon oda isimleri UNIQUE olmali. Gorunmez zero-width space (​)
        // ekle -> her oda benzersiz, ekranda GORUNMEZ ve buyuk harfe cevrilse bile kalir.
        static int g_roomCounter = 0;
        g_roomCounter++;
        NSMutableString *uniqName = [NSMutableString stringWithUTF8String:customRoomName];
        int reps = (g_roomCounter % 400) + 1;
        for (int i = 0; i < reps; i++) [uniqName appendString:@"​"];
        void* nameStr = mkStr(uniqName);
        if (!nameStr) return;
        // KALICI oda: RoomOptions.EmptyRoomTtl ver -> sen cikinca oda silinmez, listede kalir
        if (pn_createRoom && i_object_new && g_roomOptionsClass) {
            void* opts = i_object_new(g_roomOptionsClass);
            if (opts) {
                *(bool*)((uintptr_t)opts + 0x10) = true;     // isVisible
                *(bool*)((uintptr_t)opts + 0x11) = true;     // isOpen
                *(int*) ((uintptr_t)opts + 0x14) = 8;        // MaxPlayers
                *(int*) ((uintptr_t)opts + 0x1C) = roomSpamTTL;   // EmptyRoomTtl (ayarlanabilir)
                pn_createRoom(nameStr, opts, NULL, NULL);
                return;
            }
        }
        // yedek: oyunun kendi butonu (oda kalici olmayabilir)
        if (lobbyGetInst && lobby_createRoom) {
            void* lobby = lobbyGetInst();
            if (!lobby) return;
            if (tmp_set_text) {
                void* nameInput = *(void**)((uintptr_t)lobby + 0x48);   // roomNameInput
                if (nameInput) tmp_set_text(nameInput, nameStr);
            }
            lobby_createRoom(lobby);
        }
    } @catch (...) {}
}

// ===== GELISMIS RENKLI ODA KURUCU =====
- (void)createColoredRoom {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"🎨 Renkli Oda Kurucu (Zero-Day Bypass)"
                                                               message:@"Server filtrelerini atlatmak icin zero-day teknikleri. Oda adini gir:"
                                                        preferredStyle:UIAlertControllerStyleAlert];

    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){
        tf.text = @"FEW1N";
        tf.placeholder = @"Oda Ismi Girin";
        tf.clearButtonMode = UITextFieldViewModeAlways;
    }];

    void (^buildAndCreate)(NSString*, NSString*) = ^(NSString *prefix, NSString *suffix){
        NSString *input = ac.textFields.firstObject.text;
        if (!input || input.length == 0) input = @"FEW1N";
        NSString *formatted = [NSString stringWithFormat:@"%@%@%@", prefix, input, suffix];
        strncpy(customRoomName, formatted.UTF8String, sizeof(customRoomName)-1);
        customRoomName[sizeof(customRoomName)-1]='\0';
        saveStr(@"roomName", formatted);
        FLog([NSString stringWithFormat:@"Renkli oda kuruluyor: %@", formatted]);
        [self createOneRoom];
    };

    // ==== STANDART RENKLER (Kisa Hex) ====
    [ac addAction:[UIAlertAction actionWithTitle:@"🔴 Kirmizi (<#FF0000>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ buildAndCreate(@"<#FF0000><b>", @"</b>"); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"🟢 Yesil (<#00FF00>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ buildAndCreate(@"<#00FF00><b>", @"</b>"); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"🔵 Mavi (<#00FFFF>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ buildAndCreate(@"<#00FFFF><b>", @"</b>"); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"🟡 Sari (<#FFFF00>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ buildAndCreate(@"<#FFFF00><b>", @"</b>"); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"🟣 Mor (<#FF00FF>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ buildAndCreate(@"<#FF00FF><b>", @"</b>"); }]];

    // ==== ZERO-DAY BYPASS TEKNIKLERI ====
    // 1. Zero-Width Space Injection - server "color" kelimesini arayamaz
    [ac addAction:[UIAlertAction actionWithTitle:@"🛡️ ZWS Bypass (c\\u200Bolor)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        buildAndCreate(@"<c\u200Bolor=#FF0000><b>", @"</b></c\u200Bolor>");
    }]];
    // 2. Soft Hyphen Bypass
    [ac addAction:[UIAlertAction actionWithTitle:@"🛡️ Soft Hyphen (c\\u00ADolor)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        buildAndCreate(@"<c\u00ADolor=#FF0000><b>", @"</b></c\u00ADolor>");
    }]];
    // 3. ToUpper Bypass - zaten buyuk harf, server ToUpper() yapsa da bozulmaz
    [ac addAction:[UIAlertAction actionWithTitle:@"🛡️ ToUpper Bypass (<COLOR=...>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        buildAndCreate(@"<COLOR=#FF0000><b>", @"</b></COLOR>");
    }]];
    // 4. RTL Mark Bypass - metin yonunu degistir, filtreler kafasini karistirir
    [ac addAction:[UIAlertAction actionWithTitle:@"🛡️ RTL Mark Bypass" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        buildAndCreate(@"\u200F<#FF0000><b>", @"</b>");
    }]];
    // 5. Full Combo - tum bypass'lari birlestir
    [ac addAction:[UIAlertAction actionWithTitle:@"💀 MEGA BYPASS (Combo)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        buildAndCreate(@"<C\u200BOLOR=#FF0000><mark=#FF000044><b>", @"</b></mark></C\u200BOLOR>");
    }]];

    // ==== OZEL EFEKTLER ====
    [ac addAction:[UIAlertAction actionWithTitle:@"🔥 Vurgulu Kirmizi (<mark>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ buildAndCreate(@"<mark=#FF0000AA><b>", @"</b></mark>"); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"⚡ Dev Yazili (<size=160%>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ buildAndCreate(@"<size=160%><#FF0000><b>", @"</b></size>"); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"✂️ Ic Ice Tag (<col<color...>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ buildAndCreate(@"<col<color=#FF0000>or=#FF0000><b>", @"</b>"); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"🔴 Renkli Emoji Daireleri" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ buildAndCreate(@"🔴🟡🔵 ", @" 🔵🟡🔴"); }]];
    // Gizli oda adi - bir kismi gorunmez
    [ac addAction:[UIAlertAction actionWithTitle:@"👻 Yarim Gizli (<alpha>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        buildAndCreate(@"<alpha=#FF>FEW1N</alpha><alpha=#00>.....</alpha><alpha=#FF>🔥</alpha>", @"");
    }]];

    // ==== BRUTE FORCE: TUM TEKNIKLERI TEK SEFERDE DENE ====
    [ac addAction:[UIAlertAction actionWithTitle:@"🚀 BRUTE FORCE (20+ Teknik)" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a){
        NSString *input = ac.textFields.firstObject.text;
        if (!input || input.length == 0) input = @"FEW1N";
        g_bruteForceNames = @[
            [NSString stringWithFormat:@"<#FF0000><b>%@</b>", input],
            [NSString stringWithFormat:@"<#00FF00><b>%@</b>", input],
            [NSString stringWithFormat:@"<#00FFFF><b>%@</b>", input],
            [NSString stringWithFormat:@"<#FFFF00><b>%@</b>", input],
            [NSString stringWithFormat:@"<#FF00FF><b>%@</b>", input],
            [NSString stringWithFormat:@"<COLOR=#FF0000><b>%@</b></COLOR>", input],
            [NSString stringWithFormat:@"<CoLoR=#FF0000><b>%@</b></CoLoR>", input],
            [NSString stringWithFormat:@"<c\u200Bolor=#FF0000><b>%@</b></c\u200Bolor>", input],
            [NSString stringWithFormat:@"<c\u00ADolor=#FF0000><b>%@</b></c\u00ADolor>", input],
            [NSString stringWithFormat:@"<#F00><b>%@</b>", input],
            [NSString stringWithFormat:@"<mark=#FF0000AA><b>%@</b></mark>", input],
            [NSString stringWithFormat:@"<size=160%><#FF0000><b>%@</b></size>", input],
            [NSString stringWithFormat:@"<col<color=#FF0000>or=#FF0000><b>%@</b>", input],
            [NSString stringWithFormat:@"\u200F<#FF0000><b>%@</b>", input],
            [NSString stringWithFormat:@"<C\u200BOLOR=#FF0000><mark=#FF000044><b>%@</b></mark></C\u200BOLOR>", input],
            [NSString stringWithFormat:@"🔴🟡🔵 %@ 🔵🟡🔴", input],
            [NSString stringWithFormat:@"【★ %@ ★】", input],
            [NSString stringWithFormat:@"▬▬ %@ ▬▬", input],
            [NSString stringWithFormat:@"<alpha=#FF>%@</alpha><alpha=#00>...</alpha>", input],
            [NSString stringWithFormat:@"<#0F0><b>%@</b>", input],
            [NSString stringWithFormat:@"<#FF0000FF><b>%@</b>", input],
        ];
        g_bruteForceIdx = 0;
        isBruteForceActive = true;
        FLog([NSString stringWithFormat:@"BRUTE FORCE BASLADI: %d teknik denenecek", (int)g_bruteForceNames.count]);
        NSString *first = g_bruteForceNames[0];
        strncpy(customRoomName, first.UTF8String, sizeof(customRoomName)-1);
        customRoomName[sizeof(customRoomName)-1]='\0';
        g_bruteForceIdx = 1;
        [self createOneRoom];
    }]];

    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}
// ===== OYUN ICI ARAC DEGISTIRME =====
// HR_MainMenuHandler singleton'ini il2cpp static field uzerinden al
static void* few1n_getMainMenu(void) {
    if (!g_mmhField || !i_field_static_get_value) return NULL;
    void* inst = NULL;
    @try { i_field_static_get_value(g_mmhField, &inst); } @catch (...) { return NULL; }
    return inst;
}
// Parametresiz bir MethodInfo'yu il2cpp uzerinden cagir
static bool few1n_invoke0(void* method, void* obj, const char* label) {
    if (!method || !i_runtime_invoke) { FLog([NSString stringWithFormat:@"%s: metod yok", label]); return false; }
    if (!obj) { FLog([NSString stringWithFormat:@"%s: nesne yok", label]); return false; }
    @try { i_runtime_invoke(method, obj, NULL, NULL); FLog([NSString stringWithFormat:@"%s: calisti", label]); return true; }
    @catch (...) { FLog([NSString stringWithFormat:@"%s: cagri hatasi", label]); return false; }
}

- (void)openCarSelect {
    // Her adim loglanir ki "tepki yok" durumunda nerede takildigi gorulsun
    FLog(@"--- Arac degistirme denemesi ---");
    // Adim 1 - Lobi yolu: HR_PhotonLobbyManager.EnableCarSelectionMenu
    if (!lobbyGetInst)         FLog(@"Adim1:lobbyGetInst pointeri YOK");
    else if (!lobby_carSelectMenu) FLog(@"Adim1:EnableCarSelectionMenu pointeri YOK");
    else {
        void* lobby = NULL;
        @try { lobby = lobbyGetInst(); } @catch (...) {}
        if (!lobby) FLog(@"Adim1:Lobi nesnesi YOK (yaris sahnesinde lobi olmayabilir)");
        else {
            @try { lobby_carSelectMenu(lobby); FLog(@"Adim1:Lobi yoluyla acildi"); return; }
            @catch (...) { FLog(@"Adim1:Lobi cagrisi hata verdi"); }
        }
    }
    // Adim 2 - Ana menu yolu: HR_MainMenuHandler singleton + il2cpp
    void* mm = few1n_getMainMenu();
    if (!mm) { FLog(@"Adim2:MainMenuHandler bulunamadi - bu sahnede arac degistirilemiyor"); return; }
    FLog(@"Adim2:MainMenuHandler bulundu, arac menusu kullanilabilir");
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F504 Arac Degistir"
                                                               message:@"Araclar arasinda gez, sonra sec"
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"➡️ Sonraki Arac" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        few1n_invoke0(g_mNextCar, few1n_getMainMenu(), "Sonraki arac");
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"⬅️ Onceki Arac" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        few1n_invoke0(g_mPrevCar, few1n_getMainMenu(), "Onceki arac");
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"✅ Bu Araci Sec" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        few1n_invoke0(g_mSelectCar, few1n_getMainMenu(), "Arac secildi");
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Kapat" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}

// ===== ARAC KONTROL PANELI =====
- (void)tapCarPanel {
    isCarPanelEnabled = !isCarPanelEnabled;
    saveBool(@"carpanel", isCarPanelEnabled);
    if (!isCarPanelEnabled && g_carDrive) {
        @try {   // kapatinca oyunun kendi kontroluna geri birak
            uintptr_t d = (uintptr_t)g_carDrive;
            *(unsigned char*)(d + 0x61) = 0;
            *(unsigned char*)(d + 0x62) = 0;
        } @catch (...) {}
    }
    FLog([NSString stringWithFormat:@"Arac paneli: %@", isCarPanelEnabled ? @"ACIK" : @"KAPALI"]);
    [self refreshUI];
}

- (void)editCarPanel {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F3CE Arac Ayarlari"
                                                               message:@"Motor gucu / direksiyon / maks hiz"
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){
        tf.placeholder = @"Motor gucu (normal 1.0)";
        tf.text = [NSString stringWithFormat:@"%.1f", carAccelPower];
        tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){
        tf.placeholder = @"Direksiyon (normal 1.0)";
        tf.text = [NSString stringWithFormat:@"%.1f", carSteerPower];
        tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){
        tf.placeholder = @"Maks hiz";
        tf.text = [NSString stringWithFormat:@"%.0f", carTopSpeed];
        tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [ac addAction:[UIAlertAction actionWithTitle:@"Kaydet" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        float v1 = [ac.textFields[0].text floatValue];
        float v2 = [ac.textFields[1].text floatValue];
        float v3 = [ac.textFields[2].text floatValue];
        if (v1 > 0.1f && v1 <= 50.0f)   carAccelPower = v1;
        if (v2 > 0.1f && v2 <= 20.0f)   carSteerPower = v2;
        if (v3 > 10.0f && v3 <= 2000.0f) carTopSpeed  = v3;
        saveFloat(@"caraccel", carAccelPower);
        saveFloat(@"carsteer", carSteerPower);
        saveFloat(@"cartop",   carTopSpeed);
        FLog([NSString stringWithFormat:@"Arac ayari: guc=%.1f direksiyon=%.1f maksHiz=%.0f", carAccelPower, carSteerPower, carTopSpeed]);
        [self refreshUI];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Varsayilana Don" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a){
        carAccelPower = 1.0f; carSteerPower = 1.0f; carTopSpeed = 150.0f;
        saveFloat(@"caraccel", carAccelPower);
        saveFloat(@"carsteer", carSteerPower);
        saveFloat(@"cartop",   carTopSpeed);
        FLog(@"Arac ayarlari sifirlandi");
        [self refreshUI];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}

// ===== ODADAKI OYUNCULARI LISTELE + ISIM KOPYALA =====
// il2cpp dizi yerlesimi: +0x18 = eleman sayisi, +0x20 = ilk eleman
- (void)showPlayers {
    if (!pn_getPlayerList) { FLog(@"Oyuncu listesi pointeri yok"); return; }
    loadPlayerDB();
    NSMutableArray<NSDictionary*> *rows = [NSMutableArray array];   // her satir: nick/uid/etiket/gecmis
    int changedCount = 0;
    @try {
        void* arr = pn_getPlayerList();
        if (!arr) { FLog(@"Odada degilsin (PlayerList bos)"); return; }
        int cnt = (int)(*(uintptr_t*)((uintptr_t)arr + 0x18));
        if (cnt < 0 || cnt > 64) { FLog([NSString stringWithFormat:@"Oyuncu sayisi anormal: %d", cnt]); return; }
        void** elems = (void**)((uintptr_t)arr + 0x20);
        for (int i = 0; i < cnt; i++) {
            void* p = elems[i];
            if (!p) continue;
            NSString *nick = (ply_getNickName) ? readStr(ply_getNickName(p)) : @"";
            if (nick.length == 0) nick = @"(isimsiz)";
            NSString *uid  = (ply_getUserId) ? readStr(ply_getUserId(p)) : @"";
            int actor = (ply_getActorNumber) ? ply_getActorNumber(p) : 0;
            BOOL master = (ply_getIsMaster) ? ply_getIsMaster(p) : NO;

            // ---- UserId ile isim degisikligi tespiti ----
            NSString *flag = @"";
            NSArray *hist = @[];
            if (uid.length > 0) {
                NSDictionary *rec = g_playerDB[uid];
                NSString *last = rec[@"last"];
                NSMutableArray *all = rec[@"all"] ? [rec[@"all"] mutableCopy] : [NSMutableArray array];
                if (last && ![last isEqualToString:nick]) {
                    flag = @"  ⚠️";
                    changedCount++;
                    FLog([NSString stringWithFormat:@"ISIM DEGISTI: %@ -> %@ (uid %@)", last, nick, uid]);
                }
                if (![all containsObject:nick]) [all addObject:nick];
                g_playerDB[uid] = @{@"last": nick, @"all": all};
                hist = all;
            }
            [rows addObject:@{@"title": [NSString stringWithFormat:@"%@%@  #%d%@", master ? @"\U0001F451 " : @"", nick, actor, flag],
                              @"nick": nick, @"uid": uid, @"hist": hist, @"playerObj": [NSValue valueWithPointer:p]}];
        }
        savePlayerDB();
    } @catch (...) { FLog(@"Oyuncu listesi okunamadi"); return; }

    if (rows.count == 0) { FLog(@"Odada oyuncu bulunamadi"); return; }
    FLog([NSString stringWithFormat:@"Odada %lu oyuncu, %d isim degisikligi", (unsigned long)rows.count, changedCount]);

    NSString *msg = (changedCount > 0)
        ? [NSString stringWithFormat:@"%lu kisi - ⚠️ %d kisi ismini degistirmis", (unsigned long)rows.count, changedCount]
        : [NSString stringWithFormat:@"%lu kisi - detay icin sec", (unsigned long)rows.count];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F465 Odadaki Oyuncular"
                                                               message:msg preferredStyle:UIAlertControllerStyleAlert];
    for (NSDictionary *r in rows) {
        [ac addAction:[UIAlertAction actionWithTitle:r[@"title"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
            [self showPlayerDetail:r];
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"Kapat" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}

// Secilen oyuncunun kimligi + bu UserId ile gorulmus tum isimler
- (void)showPlayerDetail:(NSDictionary*)r {
    NSString *nick = r[@"nick"];
    NSString *uid  = r[@"uid"];
    NSArray  *hist = r[@"hist"];

    NSMutableString *m = [NSMutableString string];
    [m appendFormat:@"Su anki isim: %@\n", nick];
    if (uid.length > 0) {
        [m appendFormat:@"UserId: %@\n", uid];
        if (hist.count > 1) {
            [m appendFormat:@"\n⚠️ Bu kisi %lu farkli isim kullanmis:\n", (unsigned long)hist.count];
            for (NSString *n in hist) [m appendFormat:@"  • %@\n", n];
        } else {
            [m appendString:@"\nBu kisi hep ayni ismi kullanmis."];
        }
    } else {
        [m appendString:@"UserId bos - oyun kimlik dogrulama kullanmiyor,\nbu kisi isim degisikligi icin takip edilemez."];
    }

    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F50D Oyuncu Detayi"
                                                               message:m preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"\U0001F4CB Ismi Kopyala" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        [UIPasteboard generalPasteboard].string = nick;
        FLog([NSString stringWithFormat:@"Isim kopyalandi: %@", nick]);
    }]];
    if (uid.length > 0) {
        [ac addAction:[UIAlertAction actionWithTitle:@"\U0001F511 UserId Kopyala" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
            [UIPasteboard generalPasteboard].string = uid;
            FLog([NSString stringWithFormat:@"UserId kopyalandi: %@", uid]);
        }]];
    }
    NSValue *pVal = r[@"playerObj"];
    if (pVal) {
        void* pObj = [pVal pointerValue];
        [ac addAction:[UIAlertAction actionWithTitle:@"⛔ Oyuncuyu Odadan At (CloseConnection)" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a){
            few1n_kickPlayer(pObj);
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"Kapat" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}

- (void)fireRoomSpam {
    if (!isRoomSpamEnabled || !lobbyGetInst) return;
    @try {
        // Hedef sayiya ulasildiysa ve surekli mod kapaliysa dur
        if (!roomSpamContinuous && roomSpamMaxCount > 0 && roomSpamCount >= roomSpamMaxCount) {
            isRoomSpamEnabled = false;
            if (roomSpamTimer) { [roomSpamTimer invalidate]; roomSpamTimer = nil; }
            [self refreshUI];
            return;
        }
        void* lobby = lobbyGetInst();
        if (!lobby) return;
        if (roomSpamPhase == 0) { [self createOneRoom]; roomSpamCount++; roomSpamPhase = 1; }
        else { if (lobby_leaveRoom) lobby_leaveRoom(lobby); roomSpamPhase = 0; }
        [self refreshUI];   // durum etiketini guncelle
    } @catch (...) {}
}

- (void)tapRoomSpam {
    isRoomSpamEnabled = !isRoomSpamEnabled;
    saveBool(@"roomspam", isRoomSpamEnabled);
    if (roomSpamTimer) { [roomSpamTimer invalidate]; roomSpamTimer = nil; }
    if (isRoomSpamEnabled) {
        roomSpamPhase = 0;
        roomSpamCount = 0;   // sayaci sifirla
        float iv = roomSpamInterval >= 0.02f ? roomSpamInterval : 0.3f;
        roomSpamTimer = [NSTimer scheduledTimerWithTimeInterval:iv target:self selector:@selector(fireRoomSpam) userInfo:nil repeats:YES];
    }
    [self refreshUI];
}

- (void)spam300Rooms {
    roomSpamMaxCount = 300; roomSpamContinuous = false; roomSpamInterval = 0.02f;
    saveInt(@"roomMax", 300); saveBool(@"roomcont", false); saveInt(@"roomIv", 2);
    if (roomSpamTimer) { [roomSpamTimer invalidate]; roomSpamTimer = nil; }
    isRoomSpamEnabled = true; saveBool(@"roomspam", true);
    roomSpamPhase = 0; roomSpamCount = 0;
    roomSpamTimer = [NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(fireRoomSpam) userInfo:nil repeats:YES];
    FLog(@"300 oda spam basladi (0.04sn/adim) - liste dolacak, odalar ~5dk yasar");
    [self refreshUI];
}

- (void)editRoomSpamCount {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F4CA Oda Sayisi" message:@"Kac oda? (0 = sinirsiz)" preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){ tf.keyboardType = UIKeyboardTypeNumberPad; tf.text = [NSString stringWithFormat:@"%d", roomSpamMaxCount]; }];
    [ac addAction:[UIAlertAction actionWithTitle:@"Kaydet" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        int v = [ac.textFields.firstObject.text intValue];
        if (v >= 0) { roomSpamMaxCount = v; roomSpamContinuous = (v == 0); saveInt(@"roomMax", v); [self refreshUI]; }
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}

- (void)editRoomTTL {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"⏱️ Oda Acik Kalma"
        message:@"Kac DAKIKA acik kalsin? (max 59)\nNot: Photon sunucusu genelde 5dk'da sinirlar" preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){ tf.keyboardType = UIKeyboardTypeNumberPad; tf.text = [NSString stringWithFormat:@"%d", roomSpamTTL/60000]; tf.placeholder = @"dakika (1-59)"; }];
    [ac addAction:[UIAlertAction actionWithTitle:@"Kaydet" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        int mins = [ac.textFields.firstObject.text intValue];
        if (mins > 0) { if (mins > 59) mins = 59; roomSpamTTL = mins * 60000; saveInt(@"roomTTL", roomSpamTTL);
            FLog([NSString stringWithFormat:@"Oda suresi: %d dk (%d ms) - Photon clamp'leyebilir", mins, roomSpamTTL]); }
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}

- (void)editRoomSpamInterval {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"⏰ Spam Araligi" message:@"Kac saniyede bir? (0.1 = cok hizli, 5 = yavas)" preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){ tf.keyboardType = UIKeyboardTypeDecimalPad; tf.text = [NSString stringWithFormat:@"%.1f", roomSpamInterval]; }];
    [ac addAction:[UIAlertAction actionWithTitle:@"Kaydet" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        float v = [ac.textFields.firstObject.text floatValue];
        if (v >= 0.02f && v <= 5.0f) { roomSpamInterval = v; saveInt(@"roomIv", (int)(v*100)); }
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}

- (void)tapColorRoomForce {
    isColorRoomForce = !isColorRoomForce;
    saveBool(@"colorroomforce", isColorRoomForce);
    FLog(isColorRoomForce ? @"Zorla Renkli Oda ACIK - Tum odalar renkli" : @"Zorla Renkli Oda KAPALI");
    [self refreshUI];
}

- (void)tapRoomContinuous {
    roomSpamContinuous = !roomSpamContinuous;
    saveBool(@"roomcont", roomSpamContinuous);
    [self refreshUI];
}

// YENI: Oda Master Ol (Fake / Hack)
- (void)tapRoomMaster {
    if (!pn_getPlayerList || !ply_getIsMaster || !ply_getNickName) { FLog(@"Oda master fonksiyonlari hazir degil"); return; }
    @try {
        void* arr = pn_getPlayerList();
        if (!arr) { FLog(@"Oyuncu listesi alinamadi - odaya gir"); return; }
        int cnt = (int)(*(uintptr_t*)((uintptr_t)arr + 0x18));
        void** elems = (void**)((uintptr_t)arr + 0x20);
        void* me = NULL;
        void* currentMaster = NULL;
        // Kendi nickName'ini al (en guvenli kendini bulma yontemi)
        NSString *myNick = @"";
        if (pn_getNickName) {
            void* nn = pn_getNickName();
            if (nn) myNick = readStr(nn) ?: @"";
        }
        for (int i = 0; i < cnt; i++) {
            void* p = elems[i];
            if (!p) continue;
            if (ply_getIsMaster(p)) currentMaster = p;
            // Kendini bul: NickName eslesmesi (en guvenli)
            NSString *pNick = readStr(ply_getNickName(p)) ?: @"";
            if ([pNick isEqualToString:myNick] && myNick.length > 0) me = p;
        }
        // NickName bulunamazsa ActorNumber == 1 dene (yedek)
        if (!me) {
            for (int i = 0; i < cnt; i++) {
                void* p = elems[i];
                if (!p) continue;
                if (ply_getActorNumber && ply_getActorNumber(p) == 1) { me = p; break; }
            }
        }
        if (!me) { FLog(@"Kendinizi bulamadim - odaya gir"); return; }
        BOOL alreadyMaster = ply_getIsMaster(me);
        if (alreadyMaster) {
            FLog(@"Zaten siz bu odanin master'isiniz 👑");
            UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"👑 Oda Master"
                                                                       message:@"Zaten bu odanin sahibisiniz!" preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
            [self present:ac];
            return;
        }
        // Gercek SetMasterClient cagrisi - IL2CPP ile (hook olmadan)
        if (pn_setMasterClient) {
            BOOL success = pn_setMasterClient(me);
            if (success) {
                FLog(@"👑 ODA MASTER ALINDI! Artik siz bu odanin sahibisiniz.");
                UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"👑 ODA MASTER ALINDI!"
                                                                           message:@"Artik bu odanin sahibisiniz! Tum yetkiler sizde." preferredStyle:UIAlertControllerStyleAlert];
                [ac addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
                [self present:ac];
            } else {
                FLog(@"Oda master alma BASARISIZ - sunucu reddetti veya zaten master degilsiniz");
                UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"👑 Oda Master"
                                                                           message:@"Master olma BASARISIZ.\nNedenler:\n- Zaten master olabilirsiniz\n- Sunucu reddetti\n- Photon baglantisi aktif degil" preferredStyle:UIAlertControllerStyleAlert];
                [ac addAction:[UIAlertAction actionWithTitle:@"Kapat" style:UIAlertActionStyleCancel handler:nil]];
                [self present:ac];
            }
        } else {
            FLog(@"pn_setMasterClient pointeri hazir degil - il2cpp init bekleniyor");
            UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"👑 Oda Master"
                                                                       message:@"IL2CPP init bekleniyor - oyuna yeniden girin." preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"Kapat" style:UIAlertActionStyleCancel handler:nil]];
            [self present:ac];
        }
    } @catch (...) { FLog(@"Oda master olma hatasi"); }
}

- (void)editRoomName {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F3E0 Oda Ismi (Rich Text)"
                                                               message:@"Rich text kodu da girebilirsin:" preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){ tf.text = [NSString stringWithUTF8String:customRoomName]; tf.clearButtonMode = UITextFieldViewModeAlways; }];
    [ac addAction:[UIAlertAction actionWithTitle:@"Kaydet" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSString *t = ac.textFields.firstObject.text;
        if (t.length > 0) { strncpy(customRoomName, t.UTF8String, sizeof(customRoomName)-1); customRoomName[sizeof(customRoomName)-1]='\0'; saveStr(@"roomName", t); }
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}

// Gradient isim: 2 renk arasi gecis (kirmizi->mavi)
- (void)gradientName {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F3A8 Gradient Isim"
                                                               message:@"Isim yaz - kirmizidan maviye:" preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){ tf.text = @"FEW1N"; tf.clearButtonMode = UITextFieldViewModeAlways; }];
    [ac addAction:[UIAlertAction actionWithTitle:@"Uygula" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSString *src = ac.textFields.firstObject.text;
        if (src.length == 0 || !pn_setNickName) return;
        NSUInteger n = src.length;
        NSMutableString *rich = [NSMutableString string];
        for (NSUInteger i = 0; i < n; i++) {
            float t = (n > 1) ? (float)i/(n-1) : 0.0f;
            int r = (int)(255*(1-t)), g = 0, bl = (int)(255*t);
            NSString *ch = [src substringWithRange:NSMakeRange(i,1)];
            [rich appendFormat:@"<color=#%02X%02X%02X><b>%@</b></color>", r, g, bl, ch];
        }
        void* ns = mkStr(rich);
        if (ns) {
            pn_setNickName(ns);
            if (playerManagerGetInst && pm_updateNicknameInternal) {
                @try { void* pm = playerManagerGetInst(); if (pm) pm_updateNicknameInternal(pm, ns); } @catch (...) {}
            }
            [self.nameBtn setTitle:@"\U0001F3A8 Gradient isim aktif ✅" forState:UIControlStateNormal];
            [self.nameBtn setTitleColor:C_ON forState:UIControlStateNormal];
        }
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}

// ===== ISIM HILELERI (Photon nickname - HERKES gorur) =====
// Duz unicode kullaniyoruz (renk etiketi degil) -> baskalari kesin gorur.
- (void)fireNameMarquee {
    if (!pn_setNickName) return;
    static int idx = 0;
    NSString *base = @"★ FEW1N MOD MENU ★ ";   // ★ ... ★
    NSUInteger n = base.length; if (n == 0) return;
    NSMutableString *win = [NSMutableString string];
    for (int k = 0; k < 12; k++) [win appendString:[base substringWithRange:NSMakeRange((idx + k) % n, 1)]];
    idx = (idx + 1) % n;
    void* ns = mkStr(win);
    if (ns) { pn_setNickName(ns);
        if (playerManagerGetInst && pm_updateNicknameInternal) { @try { void* pm = playerManagerGetInst(); if (pm) pm_updateNicknameInternal(pm, ns); } @catch (...) {} } }
}
- (void)fireNameCycle {
    static int ci = 0;
    NSArray *names = @[@"FEW1N 🔥", @"FEW1N ⚡", @"FEW1N 🇹🇷", @"👑 FEW1N", @"Lv.999 FEW1N", @"FEW1N 💎", @"🏎️ FEW1N 💨"];
    [self applyPlainNick:names[(ci++) % names.count]];
}
- (void)applyPlainNick:(NSString*)s {
    if (!pn_setNickName || s.length == 0) return;
    void* ns = mkStr(s);
    if (ns) { pn_setNickName(ns);
        if (playerManagerGetInst && pm_updateNicknameInternal) { @try { void* pm = playerManagerGetInst(); if (pm) pm_updateNicknameInternal(pm, ns); } @catch (...) {} } }
}
- (void)nameTricks {
    if (!pn_setNickName) { FLog(@"Isim ayari hazir degil (odaya gir)"); return; }
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F3AD Isim Hileleri"
        message:@"Herkes bu ismi gorur (Photon senkron)" preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"✔️ Sahte Dogrulama Rozeti" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        if (nameMarqueeTimer) { [nameMarqueeTimer invalidate]; nameMarqueeTimer = nil; }
        nameTrickMode = 0; [self applyPlainNick:@"FEW1N ✔️"]; FLog(@"Rozet ismi ayarlandi");
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"👻 Gorunmez Isim" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        if (nameMarqueeTimer) { [nameMarqueeTimer invalidate]; nameMarqueeTimer = nil; }
        nameTrickMode = 0; [self applyPlainNick:@"⠀⠀⠀"]; FLog(@"Gorunmez isim ayarlandi");
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"📏 Suslu Uzun Isim" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        if (nameMarqueeTimer) { [nameMarqueeTimer invalidate]; nameMarqueeTimer = nil; }
        nameTrickMode = 0; [self applyPlainNick:@"▬▬ໜ۩ FEW1N ۩ໜ▬▬"]; FLog(@"Suslu isim ayarlandi");
    }]];
    // YENI HACKER/PRO MODLARI
    [ac addAction:[UIAlertAction actionWithTitle:@"🛡️ [ADMIN] Rozeti (Fake)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        if (nameMarqueeTimer) { [nameMarqueeTimer invalidate]; nameMarqueeTimer = nil; }
        nameTrickMode = 1; [self applyPlainNick:@"[ADMIN] FEW1N"]; FLog(@"Fake Admin rozetli isim ayarlandi");
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"🔧 [DEV] Rozeti (Fake)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        if (nameMarqueeTimer) { [nameMarqueeTimer invalidate]; nameMarqueeTimer = nil; }
        nameTrickMode = 3; [self applyPlainNick:@"[DEV] FEW1N"]; FLog(@"Fake Dev rozetli isim ayarlandi");
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"⚡ Hacker Isim (Animasyonlu)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        if (nameMarqueeTimer) { [nameMarqueeTimer invalidate]; nameMarqueeTimer = nil; }
        nameTrickMode = 4; nameMarqueeTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(fireHackerName) userInfo:nil repeats:YES];
        FLog(@"Hacker isim animasyonu basladi");
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"🟢 Matrix Isim (Binary)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        if (nameMarqueeTimer) { [nameMarqueeTimer invalidate]; nameMarqueeTimer = nil; }
        nameTrickMode = 5; [self applyPlainNick:matrixWrapName(@"FEW1N")]; FLog(@"Matrix isim ayarlandi");
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"💀 Glitch Isim" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        if (nameMarqueeTimer) { [nameMarqueeTimer invalidate]; nameMarqueeTimer = nil; }
        nameTrickMode = 6; [self applyPlainNick:glitchWrapName(@"FEW1N")]; FLog(@"Glitch isim ayarlandi");
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"🔢 Binary Isim (0/1)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        if (nameMarqueeTimer) { [nameMarqueeTimer invalidate]; nameMarqueeTimer = nil; }
        nameTrickMode = 7; [self applyPlainNick:binaryWrapName(@"FEW1N")]; FLog(@"Binary isim ayarlandi");
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"🎞️ Kayan Yazi (marquee)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        if (nameMarqueeTimer) { [nameMarqueeTimer invalidate]; nameMarqueeTimer = nil; }
        nameTrickMode = 0; nameMarqueeTimer = [NSTimer scheduledTimerWithTimeInterval:0.4 target:self selector:@selector(fireNameMarquee) userInfo:nil repeats:YES];
        FLog(@"Kayan yazi ismi basladi");
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"🔄 Isim Dongusu (emoji/bayrak/level)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        if (nameMarqueeTimer) { [nameMarqueeTimer invalidate]; nameMarqueeTimer = nil; }
        nameTrickMode = 0; nameMarqueeTimer = [NSTimer scheduledTimerWithTimeInterval:0.7 target:self selector:@selector(fireNameCycle) userInfo:nil repeats:YES];
        FLog(@"Isim dongusu basladi");
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"⏹️ Efekti Durdur" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a){
        if (nameMarqueeTimer) { [nameMarqueeTimer invalidate]; nameMarqueeTimer = nil; } nameTrickMode = 0; FLog(@"Kayan yazi durdu");
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}

// Hacker isim animasyonu (yanip-sonen, renk degisen)
- (void)fireHackerName {
    static int hi = 0;
    NSArray *hackerNames = @[
        @"<color=#FF0000><b>[ROOT] FEW1N</b></color>",
        @"<color=#00FF00><b>[ROOT] FEW1N</b></color>",
        @"<color=#00FFFF><b>[ROOT] FEW1N</b></color>",
        @"<color=#FF00FF><b>[ROOT] FEW1N</b></color>",
        @"<color=#FFFF00><b>[ROOT] FEW1N</b></color>",
        @"<color=#FF0000>⚡ FEW1N ⚡</color>",
        @"<color=#00FF00>⚡ FEW1N ⚡</color>",
        @"<color=#00FFFF>⚡ FEW1N ⚡</color>"
    ];
    [self applyPlainNick:hackerNames[hi % hackerNames.count]];
    hi++;
}
    if (!pn_setNickName) { FLog(@"Isim ayari hazir degil (odaya gir)"); return; }
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F3AD Isim Hileleri"
        message:@"Herkes bu ismi gorur (Photon senkron)" preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"✔️ Sahte Dogrulama Rozeti" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        if (nameMarqueeTimer) { [nameMarqueeTimer invalidate]; nameMarqueeTimer = nil; }
        [self applyPlainNick:@"FEW1N ✔️"]; FLog(@"Rozet ismi ayarlandi");
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"👻 Gorunmez Isim" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        if (nameMarqueeTimer) { [nameMarqueeTimer invalidate]; nameMarqueeTimer = nil; }
        [self applyPlainNick:@"⠀⠀⠀"]; FLog(@"Gorunmez isim ayarlandi");   // Braille blank
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"📏 Suslu Uzun Isim" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        if (nameMarqueeTimer) { [nameMarqueeTimer invalidate]; nameMarqueeTimer = nil; }
        [self applyPlainNick:@"▬▬ໜ۩ FEW1N ۩ໜ▬▬"]; FLog(@"Suslu isim ayarlandi");
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"🎞️ Kayan Yazi (marquee)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        if (nameMarqueeTimer) { [nameMarqueeTimer invalidate]; nameMarqueeTimer = nil; }
        nameMarqueeTimer = [NSTimer scheduledTimerWithTimeInterval:0.4 target:self selector:@selector(fireNameMarquee) userInfo:nil repeats:YES];
        FLog(@"Kayan yazi ismi basladi");
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"🔄 Isim Dongusu (emoji/bayrak/level)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        if (nameMarqueeTimer) { [nameMarqueeTimer invalidate]; nameMarqueeTimer = nil; }
        nameMarqueeTimer = [NSTimer scheduledTimerWithTimeInterval:0.7 target:self selector:@selector(fireNameCycle) userInfo:nil repeats:YES];
        FLog(@"Isim dongusu basladi");
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"⏹️ Efekti Durdur" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a){
        if (nameMarqueeTimer) { [nameMarqueeTimer invalidate]; nameMarqueeTimer = nil; } FLog(@"Kayan yazi durdu");
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];

// Rich text test: cesitli etiketleri chate gonder, hangileri render oluyor gor
- (void)richTextTest {
    if (!chatGetInst || !chatSend) return;
    NSArray *tests = @[
        @"<i>italik</i> <u>alti-cizili</u> <s>ustu-cizili</s>",
        @"<mark=#FFFF0044>vurgu</mark> <sup>ust</sup><sub>alt</sub>",
        @"<size=200%>DEV</size> normal <size=50%>kucuk</size>",
        @"gizli:<alpha=#00>gizliyazi</alpha><alpha=#FF>-son",
        @"<voffset=1em>yukari</voffset> <cspace=10>aralikli</cspace>"
    ];
    __block int i = 0;
    for (NSString *t in tests) {
        double delay = (i++) * 0.6;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @try { void* mgr = chatGetInst(); void* s = mkStr(t); if (mgr && s) chatSend(mgr, s); } @catch (...) {}
        });
    }
}

// ===== EXPLOIT TEST (CHAT FILTRESI ATLATMA - 30 YONTEM) =====
- (void)exploitChatTest {
    if (!chatGetInst || !chatSend) { FLog(@"Chat hazir degil"); return; }
    NSArray *exploits = @[
        @"1. Kisa Hex 6: <#FF0000>FEW1N RED",
        @"2. Kisa Hex 8: <#00FF00FF>FEW1N GREEN",
        @"3. Kisa Hex 3: <#00F>FEW1N BLUE",
        @"4. Kisa Hex 4: <#F00F>FEW1N ALPHA",
        @"5. Hashsiz Hex: <color=FF0000>FEW1N NOHASH</color>",
        @"6. Buyuk Harf: <COLOR=#FF0000>FEW1N</COLOR>",
        @"7. Karma Harf: <CoLoR=#00FFFF>FEW1N</CoLoR>",
        @"8. Cift Tirnak: <color=\"yellow\">FEW1N</color>",
        @"9. Tek Tirnak: <color='orange'>FEW1N</color>",
        @"10. Bosluklu Tag: <color = #FF0000>FEW1N SPACE</color>",
        @"11. Cift Katman: <col<color=#FF00FF>or=#FF00FF>FEW1N DBL",
        @"12. Uc Katman: <col<col<color=#FF0000>or=#FF0000>or=#FF0000>FEW1N TRPL",
        @"13. Mark Vurgu: <mark=#FF8800AA>FEW1N MARK</mark>",
        @"14. Alpha Opaklik: <alpha=#FF><#00FFFF>FEW1N ALPHA",
        @"15. Dev+Renk: <size=160%><#00FF00>FEW1N DEV</size>",
        @"16. ZeroWidth Split: c\u200Bolor=#FF0000>FEW1N ZW",
        @"17. Soft Hyphen: c\u00ADolor=#FF0000>FEW1N SH",
        @"18. Word Joiner: c\u2060olor=#FF0000>FEW1N WJ",
        @"19. RTL Mark: \u200F<#FF0000>FEW1N RTL",
        @"20. UTF BOM: \uFEFF<#FF0000>FEW1N BOM",
        @"21. HTML Entity: &lt;color=#FF0000&gt;FEW1N",
        @"22. Decimal Entity: &#60;color=#FF0000&#62;FEW1N",
        @"23. Sprite Inject: <sprite index=0><#FF0000>FEW1N",
        @"24. Full Combo: <size=140%><mark=#000000AA><#FF0000>FEW1N</mark></size>",
        @"25. Gradient Tag: <gradient=\"RedYellow\"><#FF0000>FEW1N GRAD",
        @"26. Font Inject: <font=\"Arial\"><#00FF00>FEW1N FONT",
        @"27. Underline Color: <u><#00FFFF>FEW1N ULINE</u>",
        @"28. Italic Color: <i><#FF00FF>FEW1N ITALIC</i>",
        @"29. Superscript: <sup><#FFFF00>FEW1N SUP</sup>",
        @"30. Line Height: <line-height=120%><#FF0000>FEW1N LINE"
    ];
    __block int idx = 0;
    for (NSString *exp in exploits) {
        double delay = (idx++) * 0.45;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @try {
                void* mgr = chatGetInst();
                void* str = mkStr(exp);
                if (mgr && str) chatSend(mgr, str);
            } @catch (...) {}
        });
    }
    FLog(@"30 Exploit payload chate gonderiliyor...");
}

// ===== EXPLOIT ILE ODA KURMA (30 YONTEM) =====
- (void)exploitCreateRoom {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"🧪 Exploit Oda Kurma (30 Yontem)"
                                                               message:@"Oda adini girin ve uygulanacak 30 exploit tekniginden birini secin:"
                                                        preferredStyle:UIAlertControllerStyleAlert];

    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){
        tf.text = @"FEW1N";
        tf.placeholder = @"Oda Ismini Girin";
        tf.clearButtonMode = UITextFieldViewModeAlways;
    }];

    void (^runExp)(NSString*, NSString*) = ^(NSString *prefix, NSString *suffix){
        NSString *inp = ac.textFields.firstObject.text;
        if (!inp || inp.length == 0) inp = @"FEW1N";
        NSString *full = [NSString stringWithFormat:@"%@%@%@", prefix, inp, suffix];
        strncpy(customRoomName, full.UTF8String, sizeof(customRoomName)-1);
        customRoomName[sizeof(customRoomName)-1]='\0';
        saveStr(@"roomName", full);
        FLog([NSString stringWithFormat:@"Exploit oda ismi kuruluyor: %@", full]);
        [self createOneRoom];
    };

    [ac addAction:[UIAlertAction actionWithTitle:@"1. Kisa Hex 6 (<#FF0000>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<#FF0000>", @""); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"2. Kisa Hex 8 (<#00FF00FF>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<#00FF00FF>", @""); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"3. Kisa Hex 3 (<#00F>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<#00F>", @""); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"4. Kisa Hex 4 (<#F00F>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<#F00F>", @""); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"5. Hashsiz Hex (<color=FF0000>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<color=FF0000>", @"</color>"); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"6. Buyuk Harf (<COLOR=#FF0000>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<COLOR=#FF0000>", @"</COLOR>"); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"7. Karma Harf (<CoLoR=#00FFFF>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<CoLoR=#00FFFF>", @"</CoLoR>"); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"8. Cift Tirnak (<color=\"yellow\">)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<color=\"yellow\">", @"</color>"); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"9. Tek Tirnak (<color='orange'>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<color='orange'>", @"</color>"); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"10. Bosluklu Tag (<color = #FF0000>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<color = #FF0000>", @"</color>"); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"11. Cift Katman (<col<color...>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<col<color=#FF00FF>or=#FF00FF>", @""); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"12. Uc Katman (<col<col<color...>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<col<col<color=#FF0000>or=#FF0000>or=#FF0000>", @""); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"13. Mark Vurgu (<mark=#FF8800AA>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<mark=#FF8800AA>", @"</mark>"); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"14. Alpha Tag (<alpha=#FF><#00FF>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<alpha=#FF><#00FFFF>", @""); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"15. Dev Yazili (<size=160%><#00FF>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<size=160%><#00FF00>", @"</size>"); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"16. ZeroWidth Split (c\\u200Bolor)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"c\u200Bolor=#FF0000>", @""); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"17. Soft Hyphen Split (c\\u00ADolor)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"c\u00ADolor=#FF0000>", @""); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"18. Word Joiner (c\\u2060olor)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"c\u2060olor=#FF0000>", @""); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"19. RTL Control Mark (\\u200F)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"\u200F<#FF0000>", @""); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"20. UTF-8 BOM Prefix (\\uFEFF)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"\uFEFF<#FF0000>", @""); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"21. HTML Entity (&lt;color...)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"&lt;color=#FF0000&gt;", @""); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"22. Decimal Entity (&#60;color...)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"&#60;color=#FF0000&#62;", @""); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"23. Sprite Injection (<sprite=0>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<sprite index=0><#FF0000>", @""); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"24. Full Combo Overlay" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<size=140%><mark=#000000AA><#FF0000>", @"</mark></size>"); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"25. Gradient Tag (<gradient=...>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<gradient=\"RedYellow\"><#FF0000>", @"</gradient>"); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"26. Font Swap Inject (<font=...>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<font=\"Arial\"><#00FF00>", @"</font>"); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"27. Alt Cizgili Renk (<u>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<u><#00FFFF>", @"</u>"); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"28. Italik Renk (<i>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<i><#FF00FF>", @"</i>"); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"29. Ust Indis Renk (<sup>)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<sup><#FFFF00>", @"</sup>"); }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"30. Satir Yuksekligi Enjeksiyonu" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ runExp(@"<line-height=120%><#FF0000>", @""); }]];

    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}

- (void)editSpam {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F4AC Spam Yazisi" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){ tf.text = [NSString stringWithUTF8String:chatSpamText]; tf.clearButtonMode = UITextFieldViewModeAlways; }];
    [ac addAction:[UIAlertAction actionWithTitle:@"Kaydet" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSString *t = ac.textFields.firstObject.text;
        if (t.length > 0) { strncpy(chatSpamText, t.UTF8String, sizeof(chatSpamText)-1); chatSpamText[sizeof(chatSpamText)-1]='\0'; saveStr(@"spamText", t); }
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}

- (void)chatArt {
    if (!chatGetInst || !chatSend) { FLog(@"Chat pointeri yok - odaya gir"); return; }
    NSArray *arts = @[ @"¯\\_(ツ)_/¯", @"( ͡° ͜ʖ ͡°)", @"ʕ•ᴥ•ʔ", @"(⌐■_■)", @"▄︻デ══━一 💥", @"（╯°□°）╯︵ ┻━┻", @"༼ つ ◕_◕ ༽つ" ];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F3A8 Chat ASCII Sanat"
        message:@"Sec - chate gonderilir (odadaki herkes gorur)" preferredStyle:UIAlertControllerStyleAlert];
    for (NSString *art in arts) {
        [ac addAction:[UIAlertAction actionWithTitle:art style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
            @try { void* mgr = chatGetInst(); void* s = mkStr(art); if (mgr && s) chatSend(mgr, s); } @catch (...) {}
            FLog(@"ASCII sanat gonderildi");
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"🏁 FEW1N Banner (3 satir)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSArray *lines = @[ @"█▀▀ █▀▀ █░█░█ ▄█ █▄░█", @"█▀░ ██▄ ▀▄▀▄▀ ░█ █░▀█", @"▬▬▬ MOD MENU ▬▬▬" ];
        __block int i = 0;
        for (NSString *ln in lines) {
            double delay = (i++) * 0.4;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try { void* mgr = chatGetInst(); void* s = mkStr(ln); if (mgr && s) chatSend(mgr, s); } @catch (...) {}
            });
        }
        FLog(@"FEW1N banner gonderildi");
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}

- (void)fireAnnounce {
    if (!isAnnounceEnabled || !chatGetInst || !chatSend) return;
    @try {
        NSArray *lines = [[NSString stringWithUTF8String:announceText] componentsSeparatedByString:@"\n"];
        if (lines.count == 0) return;
        NSString *msg = [lines[g_announceIdx % lines.count] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        g_announceIdx++;
        if (msg.length > 0) { void* mgr = chatGetInst(); void* s = mkStr(msg); if (mgr && s) chatSend(mgr, s); }
    } @catch (...) {}
}
- (void)tapAnnounce {
    isAnnounceEnabled = !isAnnounceEnabled;
    saveBool(@"announce", isAnnounceEnabled);
    if (announceTimer) { [announceTimer invalidate]; announceTimer = nil; }
    if (isAnnounceEnabled) {
        g_announceIdx = 0;
        float iv = announceInterval >= 1.0f ? announceInterval : 5.0f;
        announceTimer = [NSTimer scheduledTimerWithTimeInterval:iv target:self selector:@selector(fireAnnounce) userInfo:nil repeats:YES];
        FLog(@"Chat oto-duyuru basladi");
    } else FLog(@"Oto-duyuru durdu");
    [self refreshUI];
}
- (void)editAnnounce {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"📢 Duyuru Mesajlari"
        message:@"Her satir ayri mesaj (sirayla doner):" preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){ tf.text = [NSString stringWithUTF8String:announceText]; tf.clearButtonMode = UITextFieldViewModeAlways; }];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){ tf.keyboardType = UIKeyboardTypeDecimalPad; tf.text = [NSString stringWithFormat:@"%.0f", announceInterval]; tf.placeholder = @"aralik (sn, min 1)"; }];
    [ac addAction:[UIAlertAction actionWithTitle:@"Kaydet" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSString *t = ac.textFields[0].text;
        if (t.length > 0) { strncpy(announceText, t.UTF8String, sizeof(announceText)-1); announceText[sizeof(announceText)-1]='\0'; saveStr(@"announceText", t); }
        float iv = [ac.textFields[1].text floatValue]; if (iv >= 1.0f && iv <= 60.0f) { announceInterval = iv; saveInt(@"announceIv", (int)iv); }
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}
- (void)fakeServerMsg {
    if (!chatGetInst || !chatSend) { FLog(@"Chat pointeri yok - odaya gir"); return; }
    NSArray *presets = @[
        @"[SERVER] Bakim 5 dakika sonra basliyor",
        @"[SERVER] Etkinlik basladi! 2x odul",
        @"[SERVER] Hile tespiti aktif 👀",
        @"[SERVER] Yeni guncelleme yayinlandi",
        @"[DUYURU] FEW1N odaya katildi"
    ];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"📡 Sahte SERVER Mesaji"
        message:@"Sec veya kendin yaz. Not: yaninda kendi ismin de gorunur - Gorunmez isim ile birlestir." preferredStyle:UIAlertControllerStyleAlert];
    for (NSString *p in presets) {
        [ac addAction:[UIAlertAction actionWithTitle:p style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
            @try { void* mgr = chatGetInst(); void* s = mkStr(p); if (mgr && s) chatSend(mgr, s); } @catch (...) {}
            FLog(@"Sahte server mesaji gonderildi");
        }]];
    }
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){ tf.placeholder = @"[SERVER] kendi mesajin"; tf.text = @"[SERVER] "; }];
    [ac addAction:[UIAlertAction actionWithTitle:@"Kendi Mesajimi Gonder" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSString *t = ac.textFields.firstObject.text;
        if (t.length > 0) { @try { void* mgr = chatGetInst(); void* s = mkStr(t); if (mgr && s) chatSend(mgr, s); } @catch (...) {} FLog(@"Ozel server mesaji gonderildi"); }
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}

- (void)editMoneyAmount {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F4B5 Para Miktari" message:@"Eklenecek miktar:" preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){ tf.keyboardType = UIKeyboardTypeNumberPad; tf.text = [NSString stringWithFormat:@"%d", customMoneyAmount]; tf.clearButtonMode = UITextFieldViewModeAlways; }];
    [ac addAction:[UIAlertAction actionWithTitle:@"Kaydet" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        long long v = [ac.textFields.firstObject.text longLongValue];
        if (v > 0) { if (v > 2000000000LL) v = 2000000000LL; customMoneyAmount = (int)v; saveInt(@"moneyAmount", customMoneyAmount); [self refreshUI]; }
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Iptal" style:UIAlertActionStyleCancel handler:nil]];
    [self present:ac];
}

- (void)editPlate {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F522 Ozel Plaka" message:@"Plakada gorunecek yazi:" preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf){ tf.placeholder = @"FEW1N"; if (isCustomPlateEnabled) tf.text = [NSString stringWithUTF8String:customPlateText]; tf.clearButtonMode = UITextFieldViewModeAlways; }];
    [ac addAction:[UIAlertAction actionWithTitle:@"Uygula" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSString *t = ac.textFields.firstObject.text;
        if (t.length > 0) { strncpy(customPlateText, t.UTF8String, sizeof(customPlateText)-1); customPlateText[sizeof(customPlateText)-1]='\0'; isCustomPlateEnabled = true; saveStr(@"plateText", t); saveBool(@"plateEnabled", true); [self refreshUI]; }
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Kapat" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a){ isCustomPlateEnabled = false; saveBool(@"plateEnabled", false); [self refreshUI]; }]];
    [self present:ac];
}

// ===== MODU YENIDEN BASLAT (oyunu kapatmadan il2cpp cozumunu tekrar calistir) =====
// Araba ilk aciliste bulunamadiysa (sahne gec yuklendiyse) bu buton her seyi yeniden arar.
- (void)restartMod {
    FLog(@"=== MOD YENIDEN BASLATILIYOR ===");
    // araba onbellegini temizle
    g_carDrive = NULL; g_carNitro = NULL; g_rb = NULL; g_origTop = 0.0f; g_classScanned = 0;
    // il2cpp cozumunu tekrar calistir - araba assembly'si sonradan yuklendiyse simdi bulunur
    few1n_initIl2cpp();
    few1n_findCar();
    NSString *sonuc = [NSString stringWithFormat:@"Yeniden baslatildi: carTip=%@ araba=%@ rb=%@",
                       g_carDriveTypeObj?@"VAR":@"YOK", g_carDrive?@"VAR":@"YOK", g_rb?@"VAR":@"YOK"];
    FLog(sonuc);
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"\U0001F504 Mod Yeniden Baslatildi"
                                                               message:sonuc preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
    [self present:ac];
    [self refreshUI];
}

- (void)showLog {
    UIWindow *w = getKeyWindow(); if (!w) return;
    if (self.logOverlay) { [self.logOverlay removeFromSuperview]; self.logOverlay = nil; }

    CGFloat W = w.bounds.size.width, H = w.bounds.size.height;
    CGFloat ow = MIN(640.0, W - 20), oh = MIN(440.0, H - 20);
    self.logOverlay = [[UIView alloc] initWithFrame:CGRectMake((W-ow)/2, (H-oh)/2, ow, oh)];
    self.logOverlay.backgroundColor = [UIColor colorWithRed:0.97 green:0.99 blue:1.0 alpha:0.99];
    self.logOverlay.layer.cornerRadius = 16;
    self.logOverlay.layer.borderWidth = 1.5;
    self.logOverlay.layer.borderColor = C_CYAN.CGColor;

    UILabel *tl = [[UILabel alloc] initWithFrame:CGRectMake(14,10,ow-28,20)];
    tl.text = @"FEW1N LOG"; tl.textColor = C_CYAN;
    tl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [self.logOverlay addSubview:tl];

    self.logText = [[UITextView alloc] initWithFrame:CGRectMake(10,36,ow-20,oh-86)];
    self.logText.backgroundColor = [UIColor colorWithRed:0.93 green:0.96 blue:0.99 alpha:1.0];
    self.logText.textColor = [UIColor colorWithRed:0.05 green:0.20 blue:0.32 alpha:1.0];
    self.logText.font = [UIFont fontWithName:@"Menlo" size:9] ?: [UIFont systemFontOfSize:9];
    self.logText.editable = NO;
    self.logText.layer.cornerRadius = 8;
    // === KAPSAMLI DURUM OZETI ===
    NSMutableString *st = [NSMutableString string];
    [st appendString:@"══════ FEW1N DURUM ══════\n"];
    [st appendFormat:@"Base: 0x%lX | il2cpp: %@\n", (unsigned long)global_base, g_il2cppReady ? @"OK" : @"YOK"];
    [st appendFormat:@"Hook: %d OK / %d FAIL\n", hookSuccessCount, hookFailCount];
    [st appendString:@"── il2cpp metodlari ──\n"];
    [st appendFormat:@"Time:%@ RB-vel:%@ RB-pos:%@\n", g_mSetTS?@"✓":@"✗", g_mRbSetVel?@"✓":@"✗", rb_setPos?@"✓":@"✗"];
    [st appendFormat:@"TMP-rich:%@ RoomOpt:%@ CreateRoom:%@ RoomName:%@\n", g_mSetRichText?@"✓":@"✗", g_roomOptionsClass?@"✓":@"✗", pn_createRoom?@"✓":@"✗", rinfo_getName?@"✓":@"✗"];
    [st appendString:@"── araba hook tetiklenme ──\n"];
    [st appendFormat:@"*ANA* CarPlayerInput.FixedUpdate: %ld\n", fInput];
    [st appendFormat:@"CarDriveSystem:%@ CarNitro:%@\n", g_carDrive?@"✓":@"✗", g_carNitro?@"✓":@"✗"];
    [st appendFormat:@"AracPanel:%@ guc=%.1f dir=%.1f maks=%.0f\n", isCarPanelEnabled?@"A":@"K", carAccelPower, carSteerPower, carTopSpeed];
    [st appendFormat:@"nitro:%ld drive:%ld plate:%ld\nRCCP:%ld smRCC:%ld smPUN:%ld\n", fNitro, fDrive, fPlate, fRccp, fSmRCC, fSmPUN];
    [st appendFormat:@"Rigidbody(g_rb): %@  %@\n", g_rb?@"YAKALANDI ✓":@"YOK ✗", g_rb?@"(zipla/ucus/isinla calisir)":@"(mod arabayi ariyor - sur)"];
    [st appendString:@"── BASE TESTI (araba disi hook) ──\n"];
    [st appendFormat:@"timeScale:%ld chat:%ld odaSatir:%ld odaKurBtn:%ld baglanti:%ld\n", fTS, fChat, fRoomLine, fCreateBtn, fConn];
    long nonCar = fTS + fChat + fRoomLine + fCreateBtn + fConn;
    [st appendFormat:@"SONUC: %@\n", nonCar > 0 ? @"HOOKLAR CALISIYOR -> sorun araba sinifi" : @"HICBIR HOOK CALISMIYOR -> OFFSET/BASE OLU"];
    [st appendString:@"── ozellik durumlari ──\n"];
    [st appendFormat:@"Hiz:%dx Nitro:%@ Ucus:%@ DusukG:%@\n", speedMode, isInfiniteNitroEnabled?@"A":@"K", isFlyEnabled?@"A":@"K", isLowGravEnabled?@"A":@"K"];
    [st appendFormat:@"RenkliChat:%@ Spam:%@ ASCII:%@ Sifre:%@\n", isColorChatEnabled?@"A":@"K", isSpamEnabled?@"A":@"K", isAsciiAnimEnabled?@"A":@"K", isBypassPasswordEnabled?@"A":@"K"];
    [st appendFormat:@"OdaSpam:%@ (kurulan:%d) SurekliMod:%@\n", isRoomSpamEnabled?@"A":@"K", roomSpamCount, roomSpamContinuous?@"A":@"K"];
    // ═══════ GENIS HATA TARAMASI (otomatik tespit) ═══════
    [st appendString:@"────── HATA TARAMASI ──────\n"];
    int problems = 0;
    if (global_base == 0)            { [st appendString:@"[X] Base bulunamadi (UnityFramework yok)\n"]; problems++; }
    else {
        @try {
            uint32_t mg = *(uint32_t*)global_base;
            if (mg != 0xFEEDFACF) { [st appendFormat:@"[X] Base GECERSIZ (magic=0x%08X)\n", mg]; problems++; }
        } @catch (...) { [st appendString:@"[X] Base okunamiyor (adres cop)\n"]; problems++; }
    }
    if (!g_il2cppReady)              { [st appendString:@"[X] il2cpp API hazir degil\n"]; problems++; }
    // NOT: Bu cihazda hook (MSHookFunction) calismiyor - bu NORMAL, hata degil.
    // Mod il2cpp yolunu kullaniyor. Sadece bilgi olarak gosterilir, sorun sayilmaz.
    if (hookFailCount > 0 && hookSuccessCount == 0)
                                     { [st appendString:@"[i] Hooklar kapali (normal) - il2cpp yolu aktif\n"]; }
    if (!g_mSetTS)                   { [st appendString:@"[X] Time.set_timeScale metodu yok\n"]; problems++; }
    if (!g_mRbSetVel)                { [st appendString:@"[X] Rigidbody.set_velocity metodu yok\n"]; problems++; }
    if (!g_mFindObjectOfType && !g_mFindObjInactive && !g_mFindAnyByType)
                                     { [st appendString:@"[X] FindObjectOfType bulucu yok - araba aranamaz\n"]; problems++; }
    if (!g_carDriveTypeObj)          { [st appendString:@"[!] CarDriveSystem tipi yok - araba hileleri kapali\n"]; problems++; }
    if (!g_rb && (isFlyEnabled || isLowGravEnabled || speedMode > 1))
                                     { [st appendString:@"[!] Rigidbody yok - mod arabayi henuz yakalamadi\n"]; problems++; }
    if (!pn_createRoom)              { [st appendString:@"[!] Oda kurma pointeri yok\n"]; problems++; }
    if (!pn_getPlayerList)           { [st appendString:@"[!] Oyuncu listesi pointeri yok\n"]; problems++; }
    if (problems == 0) [st appendString:@"[OK] Kritik hata bulunamadi\n"];
    else               [st appendFormat:@"Toplam %d sorun tespit edildi\n", problems];
    [st appendString:@"════════════════════════\n\n"];
    NSString *joined = gLog.count ? [gLog componentsJoinedByString:@"\n"] : @"(log yok - henuz calismadi)";
    self.logText.text = [st stringByAppendingString:joined];
    [self.logOverlay addSubview:self.logText];

    UIButton *copyB = [UIButton buttonWithType:UIButtonTypeSystem];
    copyB.frame = CGRectMake(10, oh-42, (ow-30)/2, 32);
    copyB.backgroundColor = C_CARD; copyB.layer.cornerRadius = 8;
    [copyB setTitle:@"\U0001F4CB Panoya Kopyala" forState:UIControlStateNormal];
    [copyB setTitleColor:C_CYAN forState:UIControlStateNormal];
    copyB.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [copyB addTarget:self action:@selector(copyLog) forControlEvents:UIControlEventTouchUpInside];
    [self.logOverlay addSubview:copyB];

    UIButton *closeB = [UIButton buttonWithType:UIButtonTypeSystem];
    closeB.frame = CGRectMake(20+(ow-30)/2, oh-42, (ow-30)/2, 32);
    closeB.backgroundColor = C_CARD; closeB.layer.cornerRadius = 8;
    [closeB setTitle:@"Kapat" forState:UIControlStateNormal];
    [closeB setTitleColor:C_RED forState:UIControlStateNormal];
    closeB.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [closeB addTarget:self action:@selector(closeLog) forControlEvents:UIControlEventTouchUpInside];
    [self.logOverlay addSubview:closeB];
    [w addSubview:self.logOverlay];
}

- (void)copyLog {
    // ekrandaki her seyi kopyala (durum ozeti + loglar)
    NSString *full = self.logText.text ?: @"";
    [UIPasteboard generalPasteboard].string = full;
    self.logText.text = [full stringByAppendingString:@"\n\n>>> PANOYA KOPYALANDI <<<"];
}

- (void)closeLog {
    if (self.logOverlay) { [self.logOverlay removeFromSuperview]; self.logOverlay = nil; }
}

- (void)present:(UIAlertController*)ac {
    UIWindow *w = getKeyWindow(); if (!w) return;
    UIViewController *vc = w.rootViewController; if (!vc) return;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    if (vc.isBeingDismissed || vc.isBeingPresented) return;
    [vc presentViewController:ac animated:YES completion:nil];
}

@end

static void restoreSettings(void) {
    speedMode              = loadInt(@"speedMode", 1);
    isInfiniteNitroEnabled = false;   // ozellik kaldirildi (kalici kapali)
    isCarPanelEnabled      = loadBool(@"carpanel", false);
    isEspEnabled           = false;   // ESP her aciliste kapali baslar (overlay guvenligi)
    isSpeedHud             = false;   // HUD da kapali baslar
    isNoClip               = loadBool(@"noclip", false);
    isAntiGrav             = loadBool(@"antigrav", false);
    isCarSizeEnabled       = false;   // boyut her aciliste kapali baslar
    carSizeVal             = loadFloat(@"carSize", 1.0f);
    isCarColorEnabled      = false;   // renk her aciliste kapali (materyal onbellegi bos)
    carColorRainbow        = loadBool(@"carrainbow", true);
    g_carColor             = (Color4){ loadFloat(@"carR",1.0f), loadFloat(@"carG",0.0f), loadFloat(@"carB",0.0f), 1.0f };
    asciiColorCycle        = loadBool(@"asciiColor", false);
    lyricsColorCycle       = loadBool(@"lyricsColor", true);
    lyricsLoop             = loadBool(@"lyricsLoop", false);
    lyricsInterval         = loadFloat(@"lyricsInterval", 2.0f);
    { NSString *lt = loadStr(@"lyricsText", @"");
      if (lt.length) { g_lyrics = [[NSMutableArray alloc] init];
        for (NSString *l in [lt componentsSeparatedByString:@"\n"]) [g_lyrics addObject:[l stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]]; } }
    isAnnounceEnabled      = false;
    isGodmode              = false;   // godmode her aciliste kapali (guvenlik)
    isSelektor             = false;   // selektor her aciliste kapali
    g_selFlashRate         = loadInt(@"selRate", 1);
    announceInterval       = (float)loadInt(@"announceIv", 5);
    { NSString *at = loadStr(@"announceText", @""); if (at.length) { strncpy(announceText, at.UTF8String, sizeof(announceText)-1); announceText[sizeof(announceText)-1]='\0'; } }
    carAccelPower          = loadFloat(@"caraccel", 3.0f);
    carSteerPower          = loadFloat(@"carsteer", 1.0f);
    carTopSpeed            = loadFloat(@"cartop",   300.0f);
    isColorChatEnabled     = false;   // ozellik kaldirildi (kalici kapali)
    isSpamEnabled          = loadBool(@"chatspam", false);
    isBypassPasswordEnabled= loadBool(@"bypass", true);
    isFlyEnabled           = loadBool(@"fly", false);
    isLowGravEnabled       = loadBool(@"lowgrav", false);
    isAsciiAnimEnabled     = loadBool(@"asciianim", false);
    asciiAnimIndex         = loadInt(@"asciiIdx", 0);
    isRoomSpamEnabled      = false;   // spam her acilista kapali baslasin (guvenlik)
    roomSpamMaxCount       = loadInt(@"roomMax", 0);
    roomSpamTTL            = loadInt(@"roomTTL", 300000);
    roomSpamInterval       = loadInt(@"roomIv", 40) / 100.0f;
    roomSpamContinuous     = loadBool(@"roomcont", true);
    spamStyle              = loadInt(@"spamStyle", 0);
    NSString* rn = loadStr(@"roomName", @"<b><color=#FF0000>FEW1N</color></b>");
    strncpy(customRoomName, rn.UTF8String, sizeof(customRoomName)-1); customRoomName[sizeof(customRoomName)-1]='\0';
    isCustomPlateEnabled   = loadBool(@"plateEnabled", false);
    isAutoMoneyEnabled     = loadBool(@"automoney", false);
    customMoneyAmount      = loadInt(@"moneyAmount", 100000000);
    NSString* pt = loadStr(@"plateText", @"FEW1N");
    strncpy(customPlateText, pt.UTF8String, sizeof(customPlateText)-1); customPlateText[sizeof(customPlateText)-1]='\0';
    NSString* stx = loadStr(@"spamText", @"FEW1N MOD MENU!");
    strncpy(chatSpamText, stx.UTF8String, sizeof(chatSpamText)-1); chatSpamText[sizeof(chatSpamText)-1]='\0';
    NSString* sc = loadStr(@"spamColor", @"00FFFF");
    strncpy(spamColorHex, sc.UTF8String, sizeof(spamColorHex)-1); spamColorHex[sizeof(spamColorHex)-1]='\0';
}

static uintptr_t GetUnityFrameworkBase(void) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i=0;i<count;i++) {
        const char *n = _dyld_get_image_name(i);
        if (n && strstr(n, "UnityFramework")) return _dyld_get_image_vmaddr_slide(i);
    }
    for (uint32_t i=0;i<count;i++) {
        const char *n = _dyld_get_image_name(i);
        if (n && strstr(n, "DreamRoadMultiplayer.app/DreamRoadMultiplayer")) return _dyld_get_image_vmaddr_slide(i);
    }
    return 0;
}

static void InstallEverything(uintptr_t b) {
    global_base = b;
    FLog([NSString stringWithFormat:@"Base bulundu: 0x%lX", (unsigned long)b]);
    few1n_initIl2cpp();

    chatGetInst               = (void*(*)(void))(b + 0x31A6168);
    chatSend                  = (void(*)(void*,void*))(b + 0x31A626C);
    tmp_set_text              = (void(*)(void*,void*))(b + 0x65F4CC8);
    tmp_get_text              = (void*(*)(void*))(b + 0x65F4CC0);
    rinfo_getName             = (void*(*)(void*))(b + 0x59293A4);   // RoomInfo.get_Name
    pn_setNickName            = (void(*)(void*))(b + 0x5933940);
    pn_joinRoom               = (bool(*)(void*,void*))(b + 0x593A64C);
    pn_getNickName            = (void*(*)(void))(b + 0x59338C0);
    pn_leaveRoom              = (bool(*)(bool))(b + 0x593B2D8);
    pn_closeConnection        = (bool(*)(void*))(b + 0x5938844);   // kick direkt (hook olmadan)
    lobbyGetInst              = (void*(*)(void))(b + 0x54A8098);
    playerManagerGetInst      = (void*(*)(void))(b + 0x5A2DE20);
    pm_updateNicknameInternal = (void(*)(void*,void*))(b + 0x5A3DDD4);
    pm_getMoney               = (int(*)(void*))(b + 0x5A4346C);
    pm_syncWithServer         = (void(*)(void*))(b + 0x5A2DF80);
    pm_addMoney               = (void(*)(void*,int))(b + 0x5A43A2C);
    ts_get                    = (float(*)(void))(b + 0x67718D8);
    rb_getVel                 = (void(*)(void*,Vec3*))(b + 0x6837B7C);
    rb_setVel                 = (void(*)(void*,Vec3*))(b + 0x6837C88);
    rb_getPos                 = (void(*)(void*,Vec3*))(b + 0x6838E24);   // get_position_Injected
    rb_setPos                 = (void(*)(void*,Vec3*))(b + 0x6838F30);   // set_position_Injected
    lobby_createRoom          = (void(*)(void*))(b + 0x54A94A4);
    lobby_leaveRoom           = (void(*)(void*))(b + 0x54A9F1C);
    pn_createRoom             = (bool(*)(void*,void*,void*,void*))(b + 0x5939B4C);
    pn_setMasterClient        = (bool(*)(void*))(b + 0x5938B3C);   // YENI: Oda master alma
    pn_getPlayerList          = (void*(*)(void))(b + 0x59339D0);
    pn_getPlayerListOthers    = (void*(*)(void))(b + 0x5933B88);
    ply_getNickName           = (void*(*)(void*))(b + 0x5924574);
    ply_getActorNumber        = (int(*)(void*))(b + 0x592455C);
    ply_getIsMaster           = (bool(*)(void*))(b + 0x5924640);
    ply_getUserId             = (void*(*)(void*))(b + 0x5924630);
    lobby_carSelectMenu       = (void(*)(void*))(b + 0x54ABFD4);

    safeHook((void*)(b + 0x6771918), (void*)h_setTimeScale,  (void**)&o_setTimeScale,     "set_timeScale");
    safeHook((void*)(b + 0x5938844), (void*)h_closeConnection,(void**)&o_closeConnection, "CloseConnection");
    safeHook((void*)(b + 0x54CFE14), (void*)h_getNitro,       (void**)&o_getNitro,        "get_nitroAmount");
    safeHook((void*)(b + 0x54CFE1C), (void*)h_setNitro,       (void**)&o_setNitro,        "set_nitroAmount");
    safeHook((void*)(b + 0x54CCAA0), (void*)h_driveMove,      (void**)&o_driveMove,       "CarDriveSystem.Move");
    safeHook((void*)(b + 0x54D0BC0), (void*)h_playerInputFixed,(void**)&o_playerInputFixed,"CarPlayerInput.FixedUpdate *ANA*");
    safeHook((void*)(b + 0x59C4BCC), (void*)h_rccpUpdate,     (void**)&o_rccpUpdate,      "RCCP.Update(rb yakala)");
    safeHook((void*)(b + 0x5A57390), (void*)h_smRCC,          (void**)&o_smRCC,           "SmoothSyncRCC.Update(rb!)");
    safeHook((void*)(b + 0x5A4F72C), (void*)h_smPUN,          (void**)&o_smPUN,           "SmoothSyncPUN2.Update");
    safeHook((void*)(b + 0x54EA1FC), (void*)h_plateChange,    (void**)&o_plateChange,     "PlateVariant.Change");
    safeHook((void*)(b + 0x31A626C), (void*)h_chatSend,       (void**)&o_chatSend,        "ChatManager.Send");
    safeHook((void*)(b + 0x54B32F4), (void*)h_roomConnect,    (void**)&o_roomConnect,     "RoomListLine.Connect");
    safeHook((void*)(b + 0x54B33E0), (void*)h_roomLineSetup,  (void**)&o_roomLineSetup,   "RoomListLine.Setup(richtext)");
    safeHook((void*)(b + 0x54A9A30), (void*)h_onCreateFail,   (void**)&o_onCreateFail,    "OnCreateRoomFailed(teshis)");
    safeHook((void*)(b + 0x54A9498), (void*)h_onJoinFail,     (void**)&o_onJoinFail,      "OnJoinRoomFailed(teshis)");
    safeHook((void*)(b + 0x54A94A4), (void*)h_createRoomBtn,  (void**)&o_createRoomBtn,   "CreateRoomButton(richtext)");
    safeHook((void*)(b + 0x5A43A2C), (void*)h_addMoney,       (void**)&o_addMoney,        "PlayerManager.AddMoney");

    FLog([NSString stringWithFormat:@"Bitti: %d hook OK, %d fail", hookSuccessCount, hookFailCount]);
    [[FEW1NMenu shared] build];
}

static int few1n_attempts = 0;
static void few1n_poll(void) {
    few1n_attempts++;
    uintptr_t b = GetUnityFrameworkBase();
    if (b != 0) { InstallEverything(b); return; }
    if (few1n_attempts >= 80) { FLog(@"UnityFramework BULUNAMADI (80 deneme)"); [[FEW1NMenu shared] build]; return; }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ few1n_poll(); });
}

%ctor {
    FLog(@"v33.3 basladi, UnityFramework araniyor...");
    restoreSettings();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ few1n_poll(); });
}