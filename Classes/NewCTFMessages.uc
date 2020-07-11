class NewCTFMessages extends LocalMessage;

const Version = 1;

var Object SettingsHelper;
var NewCTFClientSettings Settings;

var NewCTFAnnouncer Announcer;
var bool bInitialized;

static function ClientReceive(
	PlayerPawn P,
	optional int ID,
	optional PlayerReplicationInfo PRI1,
	optional PlayerReplicationInfo PRI2,
	optional Object O
) {
    if (default.bInitialized == false)
        InitAnnouncements(P, P);

    if (default.Settings.Debug) Log("["$P.Level.TimeSeconds$"] ClientReceive"@P@ID@PRI1@PRI2@O, 'NewCTF');

    if (default.Settings.bEnabled == false || default.Announcer == none) return;

    if ((PRI1 == none) || (PRI1 != none && P.PlayerReplicationInfo != PRI1)) {
        if (TeamInfo(O) != none)
            default.Announcer.Announce(ID, TeamInfo(O).TeamIndex);
        else
            default.Announcer.Announce(ID);
    }
}

static function UpgradeConfiguration() {
    if (default.Settings._Version < Version) {
        if (default.Settings.Debug) Log("UpgradeConfiguration from"@default.Settings._Version@"to"@Version, 'NewCTF');
        // Upgrade logic
        // all cases should fall through
        switch(default.Settings._Version) {
            case 0:
                if (default.Settings.AnnouncerVolume > 6)
                    default.Settings.AnnouncerVolume = 1.5;
        }

        default.Settings._Version = Version;
    }

    default.Settings.SaveConfig(); // create default configuration
}

static function PlayerPawn GetLocalPlayer(actor Ctx) {
    local Pawn P;

    for (P = Ctx.Level.PawnList; P != none; P = P.NextPawn)
        if ((PlayerPawn(P) != none) && Viewport(PlayerPawn(P).Player) != none)
            return PlayerPawn(P);

    return none;
}

static function CreateAnnouncer(actor Ctx, PlayerPawn LP) {
    local PlayerPawn P;
    local class<NewCTFAnnouncer> C;

    if (default.Settings.bEnabled == false) return;

    P = LP;
    if (P == none) {
        P = GetLocalPlayer(Ctx);
        if (P == none) return;
    }

    C = class<NewCTFAnnouncer>(DynamicLoadObject(default.Settings.CTFAnnouncerClass, class'class'));
    if (C == none) return;

    default.Announcer = P.Spawn(C);
    if (default.Announcer == none) return;

    default.Announcer.LocalPlayer = P;
    default.Announcer.AnnouncerVolume = default.Settings.AnnouncerVolume;
    default.Announcer.InitAnnouncer();
}

static function InitAnnouncements(actor Ctx, optional PlayerPawn LP) {
    if (default.bInitialized) return;

    default.SettingsHelper = new(LP, 'NewCTF') class'Object';
    default.Settings = new(default.SettingsHelper, 'ClientSettings') class'NewCTFClientSettings';
    Log("Created ClientSettings Object, saving ...", 'NewCTF');
    default.Settings.SaveConfig();

    if (default.Settings.Debug) Log("["$Ctx.Level.TimeSeconds$"] InitAnnouncements", 'NewCTF');
    UpgradeConfiguration();
    CreateAnnouncer(Ctx, LP);

    default.bInitialized = true;
}
