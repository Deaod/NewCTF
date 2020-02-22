class NewCTFAnnouncer extends Actor;

#exec AUDIO IMPORT FILE="Sounds\Red_Flag_Dropped.wav" NAME="RedFlagDropped"
#exec AUDIO IMPORT FILE="Sounds\Red_Flag_Returned.wav" NAME="RedFlagReturned"
#exec AUDIO IMPORT FILE="Sounds\Red_Flag_Taken.wav" NAME="RedFlagTaken"
#exec AUDIO IMPORT FILE="Sounds\Red_Team_Scores.wav" NAME="RedTeamScores"

#exec AUDIO IMPORT FILE="Sounds\Blue_Flag_Dropped.wav" NAME="BlueFlagDropped"
#exec AUDIO IMPORT FILE="Sounds\Blue_Flag_Returned.wav" NAME="BlueFlagReturned"
#exec AUDIO IMPORT FILE="Sounds\Blue_Flag_Taken.wav" NAME="BlueFlagTaken"
#exec AUDIO IMPORT FILE="Sounds\Blue_Team_Scores.wav" NAME="BlueTeamScores"

#exec AUDIO IMPORT FILE="Sounds\flagalarm.wav" name="FlagAlarm"
#exec AUDIO IMPORT FILE="Sounds\overtime.wav" NAME="Overtime"
#exec AUDIO IMPORT FILE="Sounds\Draw_Game.wav" NAME="Draw"
#exec AUDIO IMPORT FILE="Sounds\gotflag.wav" NAME="GotFlag"
#exec AUDIO IMPORT FILE="Sounds\advantage.wav" name="AdvantageGeneric"

const QueueSize = 16;
const MaxSlots = 4;
const MaxNumTeams = 4;

// Sounds that should be replaced
var() sound FlagDropped[16];
var() sound FlagReturned[16];
var() sound FlagTaken[16];
var() sound FlagScored[16];
var() sound Overtime[4];
var() sound AdvantageGeneric[4];
var() sound Draw[4];
var() sound GotFlag[4];

// Internal variables to make announcements overlap less
struct Announcement {
    byte AnnID;
    byte Team;
};

var PlayerPawn LocalPlayer;
var Announcement AnnouncementQueue[16]; // QueueSize
var bool AnnouncementPlaying;
var float AnnouncerVolume;

function sound GetAnnouncementSound(byte Ann, optional byte Team, optional int Slot) {
    switch (Ann) {
    case 0: // dont ever use 0 for anything, it is reserved to mean "No Announcement"
        return none;
    case 1:
        return FlagDropped[Slot*MaxNumTeams + Team];
    case 2:
        return FlagReturned[Slot*MaxNumTeams + Team];
    case 3:
        return FlagTaken[Slot*MaxNumTeams + Team];
    case 4:
        return FlagScored[Slot*MaxNumTeams + Team];
    case 5:
        return Overtime[Slot];
    case 6:
        return AdvantageGeneric[Slot];
    case 7:
        return Draw[Slot];
    case 8:
        return GotFlag[Slot];
    }
    return none;
}

// Returns the longest duration of all sounds associated with the announcement
function float PlayAnnouncement(byte A, byte Team) {
    local PlayerPawn P;
    local Sound S;
    local int slot;
    local float duration;

    P = GetLocalPlayer();
    if (P == none) return 0;

    duration = 0;
    for (slot = 0; slot < MaxSlots; slot++) {
        S = GetAnnouncementSound(A, Team, slot);
        if (S == none) continue;
        if (duration < GetSoundDuration(S))
            duration = GetSoundDuration(S);
        P.PlayOwnedSound(S, SLOT_None, AnnouncerVolume, false);
    }

    return duration;
}

event Timer() {
    local int i;
    local float duration;
    if (AnnouncementQueue[0].AnnID == 0) {
        AnnouncementPlaying = false;
        return;
    }

    duration = 0;
    while(duration == 0) {
        duration = PlayAnnouncement(AnnouncementQueue[0].AnnID, AnnouncementQueue[0].Team);

        for (i = 0; i < QueueSize - 1; i++) {
            AnnouncementQueue[i] = AnnouncementQueue[i + 1];
            if (AnnouncementQueue[i].S == none) return;
        }

        AnnouncementQueue[QueueSize - 1].AnnID = 0;
        AnnouncementQueue[QueueSize - 1].Team = 0;
    }

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


defaultproperties {
    RemoteRole=ROLE_None
    AnnouncementPlaying=false

    FlagDropped(0)=sound'NewCTF.RedFlagDropped'
    FlagDropped(1)=sound'NewCTF.BlueFlagDropped'
    FlagDropped(2)=none
    FlagDropped(3)=none

    FlagReturned(0)=sound'NewCTF.RedFlagReturned'
    FlagReturned(1)=sound'NewCTF.BlueFlagReturned'
    FlagReturned(2)=none
    FlagReturned(3)=none
    FlagReturned(4)=Sound'Botpack.CTF.ReturnSound'
    FlagReturned(5)=Sound'Botpack.CTF.ReturnSound'
    FlagReturned(6)=sound'Botpack.CTF.ReturnSound'
    FlagReturned(7)=sound'Botpack.CTF.ReturnSound'

    FlagTaken(0)=sound'NewCTF.RedFlagTaken'
    FlagTaken(1)=sound'NewCTF.BlueFlagTaken'
    FlagTaken(2)=none
    FlagTaken(3)=none
    FlagTaken(4)=sound'NewCTF.FlagAlarm'
    FlagTaken(5)=sound'NewCTF.FlagAlarm'
    FlagTaken(6)=sound'NewCTF.FlagAlarm'
    FlagTaken(7)=sound'NewCTF.FlagAlarm'

    FlagScored(0)=sound'NewCTF.RedTeamScores'
    FlagScored(1)=sound'NewCTF.BlueTeamScores'
    FlagScored(2)=none
    FlagScored(3)=none
    FlagScored(4)=sound'Botpack.CTF.CaptureSound2'
    FlagScored(5)=sound'Botpack.CTF.CaptureSound3'
    FlagScored(6)=Sound'Botpack.CTF.CaptureSound2'
    FlagScored(7)=sound'Botpack.CTF.CaptureSound3'

    Overtime=sound'NewCTF.Overtime'
    AdvantageGeneric=sound'NewCTF.AdvantageGeneric'
    Draw=sound'NewCTF.Draw'
    GotFlag=sound'NewCTF.GotFlag'
}