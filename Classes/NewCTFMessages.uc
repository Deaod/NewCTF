class NewCTFMessages extends LocalMessage
    config(User);

const Version = 1;

var(Announcer) config bool   bEnabled;
var(Announcer) config float  AnnouncerVolume;
var(Announcer) config string CTFAnnouncerClass;
var()          config int    _Version;
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

    if (default.bEnabled == false || default.Announcer == none) return;

    if ((PRI1 == none) || (PRI1 != none && P.PlayerReplicationInfo != PRI1)) {
        if (TeamInfo(O) != none)
            default.Announcer.Announce(ID, TeamInfo(O).TeamIndex);
        else
            default.Announcer.Announce(ID);
    }
}

static function UpgradeConfiguration() {
    if (default._Version < Version) {
        // Upgrade logic
        // all cases should fall through
        switch(default._Version) {
            case 0:
                if (default.AnnouncerVolume > 6)
                    default.AnnouncerVolume = 1.5;
        }

        default._Version = Version;
    }

    StaticSaveConfig(); // create default configuration in User.ini
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

    if (default.bEnabled == false) return;

    P = LP;
    if (P == none) {
        P = GetLocalPlayer(Ctx);
        if (P == none) return;
    }

    C = class<NewCTFAnnouncer>(DynamicLoadObject(default.CTFAnnouncerClass, class'class'));
    if (C == none) return;

    default.Announcer = P.Spawn(C);
    if (default.Announcer == none) return;

    default.Announcer.LocalPlayer = P;
    default.Announcer.AnnouncerVolume = default.AnnouncerVolume;
    default.Announcer.InitAnnouncer();
}

static function InitAnnouncements(actor Ctx, optional PlayerPawn LP) {
    if (default.bInitialized) return;

    Log("InitAnnouncements");
    UpgradeConfiguration();
    CreateAnnouncer(Ctx, LP);

    default.bInitialized = true;
}

defaultproperties
{
    bEnabled=True
    AnnouncerVolume=1.5
    CTFAnnouncerClass="NewCTF.DefaultAnnouncer"
    _Version=0

    bInitialized=false
}