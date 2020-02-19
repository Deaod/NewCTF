class NewCTFAnnouncer extends Actor;

#exec AUDIO IMPORT FILE="Sounds\Red_Flag_Dropped.wav" NAME="RedFlagDropped"
#exec AUDIO IMPORT FILE="Sounds\Red_Flag_Returned.wav" NAME="RedFlagReturned"
#exec AUDIO IMPORT FILE="Sounds\Red_Flag_Taken.wav" NAME="RedFlagTaken"
#exec AUDIO IMPORT FILE="Sounds\Red_Team_Scores.wav" NAME="RedTeamScores"

#exec AUDIO IMPORT FILE="Sounds\Blue_Flag_Dropped.wav" NAME="BlueFlagDropped"
#exec AUDIO IMPORT FILE="Sounds\Blue_Flag_Returned.wav" NAME="BlueFlagReturned"
#exec AUDIO IMPORT FILE="Sounds\Blue_Flag_Taken.wav" NAME="BlueFlagTaken"
#exec AUDIO IMPORT FILE="Sounds\Blue_Team_Scores.wav" NAME="BlueTeamScores"

#exec AUDIO IMPORT FILE="Sounds\overtime.wav" NAME="Overtime"
#exec AUDIO IMPORT FILE="Sounds\Draw_Game.wav" NAME="Draw"
#exec AUDIO IMPORT FILE="Sounds\gotflag.wav" NAME="GotFlag"
#exec AUDIO IMPORT FILE="Sounds\advantage.wav" name="AdvantageGeneric"

const QueueSize = 16;

// Sounds that should be replaced
var() sound FlagDropped[4];
var() sound FlagReturned[4];
var() sound FlagTaken[4];
var() sound FlagScored[4];
var() sound Overtime;
var() sound AdvantageGeneric;
var() sound Draw;
var() sound GotFlag;

// Internal variables to make announcements overlap less
struct Announcement {
    var sound S;
    var float Duration;
};

var PlayerPawn LocalPlayer;
var Announcement AnnouncementQueue[16]; // QueueSize
var bool AnnouncementPlaying;
var float AnnouncerVolume;

event Timer() {
    local int i;
    if (AnnouncementQueue[0].S == none) {
        AnnouncementPlaying = false;
        return;
    }

    GetLocalPlayer().PlayOwnedSound(AnnouncementQueue[0].S, SLOT_Interface, AnnouncerVolume, false);
    SetTimer(AnnouncementQueue[0].Duration, false);

    for (i = 0; i < QueueSize - 1; i++) {
        AnnouncementQueue[i] = AnnouncementQueue[i + 1];
        if (AnnouncementQueue[i].S == none) return;
    }

    AnnouncementQueue[QueueSize - 1].S = none;
    AnnouncementQueue[QueueSize - 1].Duration = 0;
}

function sound GetAnnouncementSound(byte Ann, optional byte Team) {
    switch (Ann) {
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
    return none;
}

function Announce(byte A, optional byte Team) {
    local Sound S;
    local float Duration;
    local int i;

    S = GetAnnouncementSound(A, Team);
    if (S == none) return;
    Duration = GetSoundDuration(S);

    if (AnnouncementPlaying == false) {
        AnnouncementPlaying = true;
        GetLocalPlayer().PlayOwnedSound(S, SLOT_Interface, AnnouncerVolume, false);
        SetTimer(Duration, false);
        return;
    }

    for (i = 0; i < QueueSize; i++) {
        if (AnnouncementQueue[i].S == none) {
            AnnouncementQueue[i].S = S;
            AnnouncementQueue[i].Duration = Duration;
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

    FlagTaken(0)=sound'NewCTF.RedFlagTaken'
    FlagTaken(1)=sound'NewCTF.BlueFlagTaken'
    FlagTaken(2)=none
    FlagTaken(3)=none

    FlagScored(0)=sound'NewCTF.RedTeamScores'
    FlagScored(1)=sound'NewCTF.BlueTeamScores'
    FlagScored(2)=none
    FlagScored(3)=none

    Overtime=sound'NewCTF.Overtime'
    AdvantageGeneric=sound'NewCTF.AdvantageGeneric'
    Draw=sound'NewCTF.Draw'
    GotFlag=sound'NewCTF.GotFlag'
}