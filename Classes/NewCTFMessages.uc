class NewCTFMessages extends LocalMessage
    config(User);

var(Announcer)   config bool   bEnabled;
var(Announcer)   config float  AnnouncerVolume;
var(Announcer)   config string CTFAnnouncerClass;
var NewCTFAnnouncer Announcer;

static function ClientReceive(
	PlayerPawn P,
	optional int ID,
	optional PlayerReplicationInfo PRI1,
	optional PlayerReplicationInfo PRI2,
	optional Object O
) {
    local sound S;
    local class<NewCTFAnnouncer> C;

    if (default.bEnabled == false) return;

    if (default.Announcer == none) {
        C = class<NewCTFAnnouncer>(DynamicLoadObject(default.CTFAnnouncerClass, class'class'));
        if (C != none) {
            default.Announcer = P.Spawn(C);
            default.Announcer.LocalPlayer = P;
            default.Announcer.AnnouncerVolume = default.AnnouncerVolume;
        }
    }

    if ((PRI1 == none) || (PRI1 != none && P.PlayerReplicationInfo != PRI1)) {
        if (default.Announcer != none) {
            if (TeamInfo(O) != none)
                default.Announcer.Announce(ID, TeamInfo(O).TeamIndex);
            else
                default.Announcer.Announce(ID);
        }
    }
}

defaultproperties {
    bEnabled=True
    AnnouncerVolume=16.0
    CTFAnnouncerClass="NewCTF.NewCTFAnnouncer"
}