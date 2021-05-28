class NewCTFAnnouncer extends INewCTFAnnouncer;

#exec AUDIO IMPORT FILE="Sounds/Red_Flag_Dropped.wav" NAME="RedFlagDropped"
#exec AUDIO IMPORT FILE="Sounds/Red_Flag_Returned.wav" NAME="RedFlagReturned"
#exec AUDIO IMPORT FILE="Sounds/Red_Flag_Taken.wav" NAME="RedFlagTaken"
#exec AUDIO IMPORT FILE="Sounds/Red_Team_Scores.wav" NAME="RedTeamScores"

#exec AUDIO IMPORT FILE="Sounds/Blue_Flag_Dropped.wav" NAME="BlueFlagDropped"
#exec AUDIO IMPORT FILE="Sounds/Blue_Flag_Returned.wav" NAME="BlueFlagReturned"
#exec AUDIO IMPORT FILE="Sounds/Blue_Flag_Taken.wav" NAME="BlueFlagTaken"
#exec AUDIO IMPORT FILE="Sounds/Blue_Team_Scores.wav" NAME="BlueTeamScores"

#exec AUDIO IMPORT FILE="Sounds/flagalarm.wav" name="FlagAlarm"
#exec AUDIO IMPORT FILE="Sounds/overtime.wav" NAME="Overtime"
#exec AUDIO IMPORT FILE="Sounds/Draw_Game.wav" NAME="Draw"
#exec AUDIO IMPORT FILE="Sounds/gotflag.wav" NAME="GotFlag"
#exec AUDIO IMPORT FILE="Sounds/advantage.wav" name="AdvantageGeneric"

const QueueSize = 16;

// Internal variables to make announcements overlap less
struct Announcement {
    var byte AnnID;
    var byte Team;
};

var PlayerPawn LocalPlayer;
var Announcement AnnouncementQueue[QueueSize]; // QueueSize
var AnnouncementPlayer Team[MaxNumTeams];
var AnnouncementPlayer General;
var bool AnnouncementPlaying;
var float AnnouncerVolume;
var class<INewCTFAnnouncer> AnnouncerClass;

function AnnouncementContent GetAnnouncementContent(byte Ann, optional byte Team) {
    local AnnouncementContent Def;
    switch (Ann) {
    case 0: // dont ever use 0 for anything, it is reserved to mean "No Announcement"
        return Def;
    case 1:
        return FlagDropped[Team];
    case 2:
        return FlagReturned[Team];
    case 3:
        return FlagTaken[Team];
    case 4:
        return FlagScored[Team];
    case 5:
        return Overtime;
    case 6:
        return AdvantageGeneric;
    case 7:
        return Draw;
    case 8:
        return GotFlag;
    }
    return Def;
}

static function InitAnnouncements(INewCTFAnnouncer Announcer) {
    Announcer.FlagDropped[0].Slots[0].Snd = sound'RedFlagDropped';
    Announcer.FlagDropped[0].Slots[0].Section = ANNS_Team;
    Announcer.FlagDropped[0].Duration = 0;
    Announcer.FlagDropped[1].Slots[0].Snd = sound'BlueFlagDropped';
    Announcer.FlagDropped[1].Slots[0].Section = ANNS_Team;
    Announcer.FlagDropped[1].Duration = 0;

    Announcer.FlagReturned[0].Slots[0].Snd = sound'RedFlagReturned';
    Announcer.FlagReturned[0].Slots[0].Section = ANNS_Team;
    Announcer.FlagReturned[0].Duration = 0;
    Announcer.FlagReturned[1].Slots[0].Snd = sound'BlueFlagReturned';
    Announcer.FlagReturned[1].Slots[0].Section = ANNS_Team;
    Announcer.FlagReturned[1].Duration = 0;

    Announcer.FlagTaken[0].Slots[0].Snd = sound'RedFlagTaken';
    Announcer.FlagTaken[0].Slots[0].Section = ANNS_Team;
    Announcer.FlagTaken[0].Duration = 0;
    Announcer.FlagTaken[1].Slots[0].Snd = sound'BlueFlagTaken';
    Announcer.FlagTaken[1].Slots[0].Section = ANNS_Team;
    Announcer.FlagTaken[1].Duration = 0;

    Announcer.FlagScored[0].Slots[0].Snd = sound'RedTeamScores';
    Announcer.FlagScored[0].Slots[0].Section = ANNS_Team;
    Announcer.FlagScored[0].Duration = 0;
    Announcer.FlagScored[1].Slots[0].Snd = sound'BlueTeamScores';
    Announcer.FlagScored[1].Slots[0].Section = ANNS_Team;
    Announcer.FlagScored[1].Duration = 0;

    Announcer.Overtime.Slots[0].Snd = sound'Overtime';
    Announcer.Overtime.Duration = 0;
    Announcer.AdvantageGeneric.Slots[0].Snd = sound'AdvantageGeneric';
    Announcer.AdvantageGeneric.Duration = 0;
    Announcer.Draw.Slots[0].Snd = sound'Draw';
    Announcer.Draw.Duration = 0;
    Announcer.GotFlag.Slots[0].Snd = sound'GotFlag';
    Announcer.GotFlag.Duration = 0;
}

function InitSections() {
    local PlayerPawn P;
    local int i;
    P = GetLocalPlayer();

    if (P == none) return;

    General = P.Spawn(class'AnnouncementPlayer', P);

    for (i = 0; i < MaxNumTeams; i++) {
        Team[i] = P.Spawn(class'AnnouncementPlayer', P);
    }
}

function InitAnnouncer() {
    InitSections();
    AnnouncerClass.static.InitAnnouncements(self);
}

function bool CanPlayAnnouncement(PlayerPawn P, byte Team, EAnnouncementCondition ACond) {
    switch (ACond) {
        case ANNC_All:
            return true;

        case ANNC_Team:
            return (P.PlayerReplicationInfo.Team == Team);

        case ANNC_NotTeam:
            return (P.PlayerReplicationInfo.Team != Team);
    }
    return true;
}

function PlayAnnouncementSound(
    AnnouncementPlayer AP,
    PlayerPawn P,
    sound ASound,
    float Loudness,
    optional bool bInterrupt,
    optional bool bVolumeControl
) {
    local actor SoundPlayer;
    local int Volume;
    local TournamentPlayer TP;
    local int nbrPlays;
    local float volPerPlay;

    TP = TournamentPlayer(P);

    if (TP != none) {
        if (TP.b3DSound)
            Volume = Clamp(TP.AnnouncerVolume, 0, 1);
        else if (bVolumeControl)
            Volume = Clamp(TP.AnnouncerVolume, 0, 4);
    } else {
        Volume = 4;
    }

    if (P.ViewTarget != none)
        SoundPlayer = P.ViewTarget;
    else
        SoundPlayer = P;

    if (Volume > 0 && AP != none) {
        nbrPlays = Clamp(int(Loudness + 0.99999), 0, 6);
        volPerPlay = Loudness / nbrPlays;
        switch(nbrPlays) {
            case 6: AP.PlayOwnedSound(ASound, SLOT_Ambient, volPerPlay, bInterrupt);
            case 5: AP.PlayOwnedSound(ASound, SLOT_Interact, volPerPlay, bInterrupt);
            case 4: AP.PlayOwnedSound(ASound, SLOT_Pain, volPerPlay, bInterrupt);
            case 3: AP.PlayOwnedSound(ASound, SLOT_Talk, volPerPlay, bInterrupt);
            case 2: AP.PlayOwnedSound(ASound, SLOT_Misc, volPerPlay, bInterrupt);
            case 1: AP.PlayOwnedSound(ASound, SLOT_Interface, volPerPlay, bInterrupt);
        }
    }
}

function AnnouncementPlayer GetAnnouncementPlayer(EAnnouncementSection AS, byte T) {
    switch(AS) {
        case ANNS_General:
            return General;
        case ANNS_Team:
            return Team[T];
    }
    return none;
}

// Returns the longest duration of all sounds associated with the announcement
function float PlayAnnouncement(byte A, byte Team) {
    local PlayerPawn P;
    local AnnouncementContent AC;
    local AnnouncementSlot AS;
    local AnnouncementPlayer AP;
    local int slot;

    P = GetLocalPlayer();
    if (P == none) return 0;

    AC = GetAnnouncementContent(A, Team);
    for (slot = 0; slot < MaxSlots; slot++) {
        AS = AC.Slots[slot];
        if (AS.Snd == none || AS.VolAdj <= -1.0) continue;
        AP = GetAnnouncementPlayer(AS.Section, Team);
        if (AP == none) continue;
        if (CanPlayAnnouncement(P, Team, AS.Cond) == false) continue;
        PlayAnnouncementSound(AP, P, AS.Snd, AnnouncerVolume * (1.0 + AS.VolAdj), false, true);
    }

    return AC.Duration;
}

event Timer() {
    local int i;
    local float duration;
    if (AnnouncementQueue[0].AnnID == 0) {
        AnnouncementPlaying = false;
        return;
    }

    do {
        duration = PlayAnnouncement(AnnouncementQueue[0].AnnID, AnnouncementQueue[0].Team);

        for (i = 0; i < QueueSize - 1; i++) {
            AnnouncementQueue[i] = AnnouncementQueue[i + 1];
            if (AnnouncementQueue[i].AnnID == 0) break;
        }

        AnnouncementQueue[QueueSize - 1].AnnID = 0;
        AnnouncementQueue[QueueSize - 1].Team = 0;
    } until(duration > 0 || AnnouncementQueue[0].AnnID == 0);

    SetTimer(duration, false);
}

function Announce(byte A, optional byte Team) {
    local float Duration;
    local int i;

    if (AnnouncementPlaying == false) {
        Duration = PlayAnnouncement(A, Team);
        if (Duration > 0) {
            AnnouncementPlaying = true;
            SetTimer(Duration, false);
        }
        return;
    }

    for (i = 0; i < QueueSize; i++) {
        if (AnnouncementQueue[i].AnnID == 0) {
            AnnouncementQueue[i].AnnID = A;
            AnnouncementQueue[i].Team = Team;
            break;
        }
    }
}

function PlayerPawn GetLocalPlayer() {
    local Pawn P;

    if (LocalPlayer != none) return LocalPlayer;

    foreach AllActors(class'Pawn', P) {
        if ((PlayerPawn(P) != none) && Viewport(PlayerPawn(P).Player) != none) {
            LocalPlayer = PlayerPawn(P);
            break;
        }
    }
    return LocalPlayer;
}

event Tick(float DeltaTime) {
    local PlayerPawn P;
    local Actor ViewActor;
    local vector CameraLocation;
    local rotator CameraRotation;
    local int i;

    P = GetLocalPlayer();
    if (P == none) return;

    P.PlayerCalcView(ViewActor, CameraLocation, CameraRotation);
    General.SetLocation(CameraLocation);
    for (i = 0; i < MaxNumTeams; i++)
        Team[i].SetLocation(CameraLocation);
}


defaultproperties
{
    DrawType=DT_None
    RemoteRole=ROLE_None
    AnnouncementPlaying=false
}
