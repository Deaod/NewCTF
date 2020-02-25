class NewCTFAnnouncer extends Actor;

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
const MaxSlots = 4;
const MaxNumTeams = 4;

enum AnnouncementCondition {
    // play for everyone
    ANNC_All,
    // only play for matching team
    ANNC_Team,
    // dont play for matching team
    ANNC_NotTeam
};

struct AnnouncementContent {
    // The sounds to play
    var() sound Snd[4];
    //
    var() AnnouncementCondition Cond[4];
    // The volume individual sounds play at is AnnouncerVolume * (1 + VolAdj) for each sound
    var() float VolAdj[4];
    // This is the length of time where this announcement plays without any other announcements
    var() float Duration;
};

// Sounds that should be replaced
var() AnnouncementContent FlagDropped[4];
var() AnnouncementContent FlagReturned[4];
var() AnnouncementContent FlagTaken[4];
var() AnnouncementContent FlagScored[4];
var() AnnouncementContent Overtime;
var() AnnouncementContent AdvantageGeneric;
var() AnnouncementContent Draw;
var() AnnouncementContent GotFlag;

// Internal variables to make announcements overlap less
struct Announcement {
    var byte AnnID;
    var byte Team;
};

var PlayerPawn LocalPlayer;
var Announcement AnnouncementQueue[16]; // QueueSize
var bool AnnouncementPlaying;
var float AnnouncerVolume;

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

event Spawned() {
    FlagDropped[0].Snd[0] = sound'NewCTF.RedFlagDropped';
    FlagDropped[0].Duration = GetSoundDuration(FlagDropped[0].Snd[0]);
    FlagDropped[1].Snd[0] = sound'NewCTF.BlueFlagDropped';
    FlagDropped[1].Duration = GetSoundDuration(FlagDropped[1].Snd[0]);
    FlagDropped[2].Snd[0] = none;
    FlagDropped[2].Duration = 0;
    FlagDropped[3].Snd[0] = none;
    FlagDropped[3].Duration = 0;

    FlagReturned[0].Snd[0] = sound'NewCTF.RedFlagReturned';
    FlagReturned[0].Snd[1] = sound'Botpack.CTF.ReturnSound';
    FlagReturned[0].Duration = GetSoundDuration(FlagReturned[0].Snd[0]);
    FlagReturned[1].Snd[0] = sound'NewCTF.BlueFlagReturned';
    FlagReturned[1].Snd[1] = sound'Botpack.CTF.ReturnSound';
    FlagReturned[1].Duration = GetSoundDuration(FlagReturned[1].Snd[0]);
    FlagReturned[2].Snd[0] = none;
    FlagReturned[2].Snd[1] = sound'Botpack.CTF.ReturnSound';
    FlagReturned[2].Duration = 0;
    FlagReturned[3].Snd[0] = none;
    FlagReturned[3].Snd[1] = sound'Botpack.CTF.ReturnSound';
    FlagReturned[3].Duration = 0;

    FlagTaken[0].Snd[0] = sound'NewCTF.RedFlagTaken';
    FlagTaken[0].Snd[1] = sound'NewCTF.FlagAlarm';
    FlagTaken[0].Cond[1] = ANNC_Team;
    FlagTaken[0].Duration = GetSoundDuration(FlagTaken[0].Snd[0]);
    FlagTaken[1].Snd[0] = sound'NewCTF.BlueFlagTaken';
    FlagTaken[1].Snd[1] = sound'NewCTF.FlagAlarm';
    FlagTaken[1].Cond[1] = ANNC_Team;
    FlagTaken[1].Duration = GetSoundDuration(FlagTaken[1].Snd[0]);
    FlagTaken[2].Snd[0] = none;
    FlagTaken[2].Snd[1] = sound'NewCTF.FlagAlarm';
    FlagTaken[2].Cond[1] = ANNC_Team;
    FlagTaken[2].Duration = 0;
    FlagTaken[3].Snd[0] = none;
    FlagTaken[3].Snd[1] = sound'NewCTF.FlagAlarm';
    FlagTaken[3].Cond[1] = ANNC_Team;
    FlagTaken[3].Duration = 0;

    FlagScored[0].Snd[0] = sound'NewCTF.RedTeamScores';
    FlagScored[0].Snd[1] = sound'Botpack.CTF.CaptureSound2';
    FlagScored[0].Duration = GetSoundDuration(FlagScored[0].Snd[0]);
    FlagScored[1].Snd[0] = sound'NewCTF.BlueTeamScores';
    FlagScored[1].Snd[1] = sound'Botpack.CTF.CaptureSound3';
    FlagScored[1].Duration = GetSoundDuration(FlagScored[1].Snd[0]);
    FlagScored[2].Snd[0] = none;
    FlagScored[2].Snd[1] = sound'Botpack.CTF.CaptureSound2';
    FlagScored[2].Duration = 0;
    FlagScored[3].Snd[0] = none;
    FlagScored[3].Snd[1] = sound'Botpack.CTF.CaptureSound3';
    FlagScored[3].Duration = 0;

    Overtime.Snd[0]           = sound'NewCTF.Overtime';
    Overtime.Duration         = GetSoundDuration(Overtime.Snd[0]);
    AdvantageGeneric.Snd[0]   = sound'NewCTF.AdvantageGeneric';
    AdvantageGeneric.Duration = GetSoundDuration(AdvantageGeneric.Snd[0]);
    Draw.Snd[0]               = sound'NewCTF.Draw';
    Draw.Duration             = GetSoundDuration(Draw.Snd[0]);
    GotFlag.Snd[0]            = sound'NewCTF.GotFlag';
    GotFlag.Duration          = GetSoundDuration(GotFlag.Snd[0]);
}

function bool CanPlayAnnouncement(PlayerPawn P, byte Team, AnnouncementCondition ACond) {
    switch (ACond) {
        case ANNC_All:
            break;

        case ANNC_Team:
            if (P.PlayerReplicationInfo.Team != Team) return false;
            break;

        case ANNC_NotTeam:
            if (P.PlayerReplicationInfo.Team == Team) return false;
            break;
    }
    return true;
}

// Returns the longest duration of all sounds associated with the announcement
function float PlayAnnouncement(byte A, byte Team) {
    local PlayerPawn P;
    local AnnouncementContent AC;
    local int slot;

    P = GetLocalPlayer();
    if (P == none) return 0;

    AC = GetAnnouncementContent(A, Team);
    for (slot = 0; slot < MaxSlots; slot++) {
        if (AC.Snd[slot] == none || AC.VolAdj[slot] <= -1.0) continue;
        if (CanPlayAnnouncement(P, Team, AC.Cond[slot]) == false) continue;
        P.PlayOwnedSound(AC.Snd[slot], SLOT_None, AnnouncerVolume * (1.0 + AC.VolAdj[slot]), false);
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
    local Sound S;
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

    for (P = Level.PawnList; P != none; P = P.NextPawn) {
        if ((PlayerPawn(P) != none) && Viewport(PlayerPawn(P).Player) != none) {
            LocalPlayer = PlayerPawn(P);
            break;
        }
    }
    return LocalPlayer;
}


defaultproperties
{
    DrawType=DT_None
    RemoteRole=ROLE_None
    AnnouncementPlaying=false
}
