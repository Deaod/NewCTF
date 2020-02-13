class NewCTF extends BotPack.CTFGame
    config;

#exec AUDIO IMPORT FILE="Sounds\flagalarm.wav" NAME="FlagAlarm"

const MaxNumSpawnPointsPerTeam = 16;
const MaxNumTeams = 4;

enum EAnnouncement {
    ANN_FlagDropped,
    ANN_FlagReturned,
    ANN_FlagTaken,
    ANN_FlagCaptured,
    ANN_Overtime,
    ANN_AdvantageGeneric,
    ANN_Draw,
    ANN_GotFlag
};
var(Announcer)   config class<NewCTFAnnouncer> CTFAnnouncerClass;

// Number of player up until which the old spawn system is used
var(SpawnSystem) config int   SpawnSystemThreshold;
// Range within which any enemy, visible or not will block a spawn
var(SpawnSystem) config float SpawnEnemyBlockRange;
// Range within which any enemy with vision on the spawn will block it
var(SpawnSystem) config float SpawnEnemyVisionBlockRange;
// Range within which any friend, visible or not will block a spawn
var(SpawnSystem) config float SpawnFriendlyBlockRange;
// Range within which any friend with vision will block a spawn
var(SpawnSystem) config float SpawnFriendlyVisionBlockRange;
// Range within which any flag will block a spawn
var(SpawnSystem) config float SpawnFlagBlockRange;

// True results in default behavior, False activates an advantage system
var(Overtime)    config bool bAllowOvertime;
// Extra time if a flag is in play when the game ends, 0 for no limit
var(Advantage)   config int  AdvantageDuration;

var bool bAdvantage;
var bool bAdvantageDone;
var int AdvantageCountdown;

// size of array should be the result of MaxNumTeams*MaxNumSpawnPointsPerTeam
var PlayerStart PlayerStartList[64];
var int         TeamSpawnCount[4];

replication {
    reliable if (Role == ROLE_Authority)
        Announce, AnnounceForPlayer;
}

event InitGame(string Options, out string Error) {
    local string opt;

    super.InitGame(Options, Error);

    opt = ParseOption(Options, "AllowOvertime");
    if (opt != "" && !(opt ~= "false"))
        bAllowOvertime = true;

    opt = ParseOption(Options, "AdvantageDuration");
    if (opt != "")
        AdvantageDuration = float(opt);
}

function InitSpawnSystem()
{
    local int i,j, swapTarget, offset;
    local NavigationPoint N;
    local int PSTeam;
    local PlayerStart PS;

    for (i = 0; i < MaxNumTeams; i++)
        TeamSpawnCount[i] = 0;

    // find the list of spawn points for each team up to a maximum
    for(N = Level.NavigationPointList; N != none; N = N.NextNavigationPoint) {
        PS = PlayerStart(N);
        if (PS != none) {
            PSTeam = PS.TeamNumber;
            if (PSTeam < MaxNumTeams && TeamSpawnCount[PSTeam] < MaxNumSpawnPointsPerTeam) {
                PlayerStartList[PSTeam*MaxNumSpawnPointsPerTeam + TeamSpawnCount[PSTeam]] = PS;
                TeamSpawnCount[PSTeam] += 1;
            }
        }
    }

    // give each teams list of spawn points a little shake
    for (i = 0; i < MaxNumTeams; i++) {
        offset = i * MaxNumSpawnPointsPerTeam;
        for(j = 0; j < TeamSpawnCount[i]; j++) {
            swapTarget = Rand(TeamSpawnCount[i]);
            PS = PlayerStartList[offset + swapTarget];
            PlayerStartList[offset + swapTarget] = PlayerStartList[offset + j];
            PlayerStartList[offset + j] = PS;
        }
    }
}

function InitFlags() {
    local FlagBase FB;
    local int i;
    local NewCTFFlag F;
    local CTFFlag oldF;
    local CTFReplicationInfo ctfState;

    ctfState = CTFReplicationInfo(GameReplicationInfo);
    foreach AllActors(class'FlagBase', FB)
    {
        // CTFFlag hides the flag of its FlagBase when it leaves state Home.
        // Destroying the flag makes it leave its current state, which by
        // default is Home.
        // Since actors are destroyed at the end of a frame, we have to get
        // tricky to work around this.

        FB.TakenSound = none; // first, make sure we dont get annoying sounds

        oldF = ctfState.FlagList[FB.Team];
        oldF.GoToState('Held'); // next, transition flag out of state Home right now
        oldF.SetTimer(0.0, false); // disable the timer of state Held
        oldF.Destroy(); // now we can safetly destroy the old flag

        FB.bHidden = false; // fix the FlagBase
        FB.TakenSound = sound'NewCTF.FlagAlarm';

        F = FB.Spawn(class'NewCTFFlag');
        F.HomeBase = FB;
        F.Team = FB.Team;
        ctfState.FlagList[FB.Team] = F;

        switch(F.Team) {
        case TEAM_Red:
            F.LightHue = 0;
            F.Skin = texture'Botpack.Skins.JpflagR';
            break;
        case TEAM_Blue:
            F.LightHue = 170;
            F.Skin = texture'Botpack.Skins.JpflagB';
            break;
        case TEAM_Green:
            F.LightHue = 80;
            F.Skin = none;//texture'Botpack.Skins.JFlag13'; // doesnt exist
            break;
        case TEAM_Gold:
            F.LightHue = 32;
            F.Skin = none;//texture'Botpack.Skins.JFlag14'; // doesnt exist
            break;
        }
    }
}

function PostBeginPlay() {
    super.PostBeginPlay();
    InitSpawnSystem();
    InitFlags();
}

// Returns the best team by score, or None if at least two teams are tied for first
function TeamInfo GetBestTeam() {
    local int i;
    local TeamInfo Best;
    Best = Teams[0];
    for (i = 1; i < MaxTeams; i++)
        if (Best.Score < Teams[i].Score)
            Best = Teams[i];

    for (i = 0; i < MaxTeams; i++)
        if (Teams[i] != Best && Best.Score == Teams[i].Score)
            return none;

    return Best;
}

function bool IsEveryFlagHome() {
    local int i;
    local bool AllFlagsHome;
    local CTFReplicationInfo ctfState;

    ctfState = CTFReplicationInfo(GameReplicationInfo);
    AllFlagsHome = true;
    for (i = 0; i < MaxTeams; i++)
        AllFlagsHome = AllFlagsHome && ctfState.FlagList[i].bHome;

    return AllFlagsHome;
}

function bool SetEndCams(string Reason) {
    local TeamInfo Best;
    local FlagBase BestBase;
    local Pawn P;
    local int i;
    local PlayerPawn Player;
    local CTFReplicationInfo ctfState;

    ctfState = CTFReplicationInfo(GameReplicationInfo);
    Best = GetBestTeam();

    EndTime = Level.TimeSeconds + 3.0;

    if (Best == none) {
        GameReplicationInfo.GameEndedComments = "Draw";
    } else {
        GameReplicationInfo.GameEndedComments = TeamPrefix@Best.TeamName@GameEndedMessage;
        BestBase = ctfState.FlagList[Best.TeamIndex].HomeBase;
    }

    for (P = Level.PawnList; P != none; P = P.NextPawn) {
        P.GotoState('GameEnded');
        Player = PlayerPawn(P);
        if (Player != none) {
            Player.bBehindView = true;
            if (Best == none) {
                if (Player.PlayerReplicationInfo.Team < MaxTeams)
                    Player.ViewTarget = ctfState.FlagList[Player.PlayerReplicationInfo.Team].HomeBase;
            } else {
                Player.ViewTarget = BestBase;
                PlayWinMessage(Player, (Player.PlayerReplicationInfo.Team == Best.TeamIndex));
            }
            Player.ClientGameEnded();
        }
    }

    // show all flags on their respective FlagBases
    for (i = 0; i < MaxTeams; i++) {
        ctfState.FlagList[i].HomeBase.bHidden = false;
        ctfState.FlagList[i].bHidden = true;
    }

    if (Best == none) {
        Announce(ANN_Draw);
    }
    CalcEndStats();

    return true;
}

function DistributeTrigger(name event, optional Actor other, optional Pawn instigator) {
    local actor A;
    foreach AllActors(class'Actor', A, event)
        A.trigger(other, instigator);
}

function EndGame(string reason) {
    if (reason ~= "timelimit") {
        if (bAllowOvertime && GetBestTeam() == none) {
            bOverTime = true;
            BroadcastLocalizedMessage(DMMessageClass, 0);
            Announce(ANN_Overtime);
            return;
        }

        if (bAdvantageDone == false && bAdvantage == false && IsEveryFlagHome() == false) {
            bAdvantage = true;
            AdvantageCountdown = AdvantageDuration;
            RemainingTime = AdvantageDuration;
            GameReplicationInfo.RemainingMinute = AdvantageDuration;
            Announce(ANN_AdvantageGeneric);
            return;
        }
    }

    super.EndGame(reason);
}

function Timer() {
    if (bAdvantage) {
        AdvantageCountdown--;

        if (AdvantageCountdown == 0 || IsEveryFlagHome()) {
            bAdvantageDone = true;
            RemainingTime = 1;
        }
    }

    Super.Timer();

    if (bAdvantage && bAdvantageDone) {
        bAdvantage = false;
    }
}

function bool IsEnemyOfTeam(Pawn P, byte team)
{
    return (P.PlayerReplicationInfo != none)
        && (P.PlayerReplicationInfo.Team != team)
        && (P.Health > 0)
        && (P.IsA('Spectator') == false);
}

function bool IsFriendOfTeam(Pawn P, byte team)
{
    return (P.PlayerReplicationInfo != none)
        && (P.PlayerReplicationInfo.Team == team)
        && (P.Health > 0)
        && (P.IsA('Spectator') == false);
}

function bool IsPlayerStartViable(PlayerStart PS)
{
    local Pawn P;
    local CTFFlag F;
    local bool visible;
    local bool enemy, friend;
    local float distance;
    local vector eyeHeight;

    for (P = Level.PawnList; P != none; P = P.NextPawn) {
        enemy = IsEnemyOfTeam(P, PS.TeamNumber);
        friend = IsFriendOfTeam(P, PS.TeamNumber);

        eyeHeight.Z = P.BaseEyeHeight;
        visible = PS.FastTrace(P.Location + eyeHeight);
        distance = VSize(PS.Location - P.Location + eyeHeight);

        if ( enemy &&  visible && distance <= SpawnEnemyVisionBlockRange)    return false;
        if ( enemy && !visible && distance <= SpawnEnemyBlockRange)          return false;
        if (friend &&  visible && distance <= SpawnFriendlyVisionBlockRange) return false;
        if (friend && !visible && distance <= SpawnFriendlyBlockRange)       return false;
    }

    foreach PS.RadiusActors(class'CTFFlag', F, SpawnFlagBlockRange)
        return false;

    return true;
}

function NavigationPoint FindPlayerStart(Pawn Player, optional byte InTeam, optional string incomingName)
{
    local int i;
    local int end;
    local int team;
    local int psOffset;
    local PlayerStart PS;
    local Teleporter Tel;

    // The following is copied from TeamGamePlus
    if ((Player != None) && (Player.PlayerReplicationInfo != None))
        team = Player.PlayerReplicationInfo.Team;
    else
        team = InTeam;

    if( incomingName!="" )
        foreach AllActors( class 'Teleporter', Tel )
            if( string(Tel.Tag)~=incomingName )
                return Tel;
    // end of copy

    if (team > MaxNumTeams || NumPlayers <= SpawnSystemThreshold)
       return super.FindPlayerStart(Player, InTeam, incomingName);

    psOffset = team * MaxNumSpawnPointsPerTeam;
    for (i = 0; i < TeamSpawnCount[team]; i++) {
        PS = PlayerStartList[psOffset + i];

        if (IsPlayerStartViable(PS)) {
            end = TeamSpawnCount[team] - 1;
            while (i < end) {
                PlayerStartList[psOffset + i] = PlayerStartList[psOffset + i + 1];
                i++;
            }

            PlayerStartList[psOffset + i] = PS;

            return PS;
        }
    }

    return super.FindPlayerStart(Player, InTeam, incomingName);
}

function PlayForAll(sound S, optional bool interruptible, optional Pawn exclude)
{
    local Pawn P;
    local PlayerPawn PP;
    for (P = Level.PawnList; P != none; P = P.NextPawn)
    {
        if (P == exclude) continue;
        PP = PlayerPawn(P);
        if (PP != none)
            PP.ClientReliablePlaySound(S, false, true);
    }
}

function sound GetAnnouncementSound(EAnnouncement A, optional byte Team) {
    switch (A) {
    case ANN_FlagDropped:
        return CTFAnnouncerClass.Default.FlagDropped[Team];
    case ANN_FlagReturned:
        return CTFAnnouncerClass.Default.FlagReturned[Team];
    case ANN_FlagTaken:
        return CTFAnnouncerClass.Default.FlagTaken[Team];
    case ANN_FlagCaptured:
        return CTFAnnouncerClass.Default.FlagScored[Team];
    case ANN_Overtime:
        return CTFAnnouncerClass.Default.Overtime;
    case ANN_AdvantageGeneric:
        return CTFAnnouncerClass.Default.AdvantageGeneric;
    case ANN_Draw:
        return CTFAnnouncerClass.Default.Draw;
    case ANN_GotFlag:
        return CTFAnnouncerClass.Default.GotFlag;
    }
}

simulated function Announce(EAnnouncement AnnouncementID, optional byte Team, optional Pawn exclude) {
    PlayForAll(GetAnnouncementSound(AnnouncementID, Team),, exclude);
}

simulated function AnnounceForPlayer(EAnnouncement AnnouncementID, PlayerPawn P, optional byte Team) {
    P.ClientReliablePlaySound(GetAnnouncementSound(AnnouncementID, Team), false, true);
}

defaultproperties
{
     CTFAnnouncerClass=class'NewCTFAnnouncer'
     SpawnSystemThreshold=4
     SpawnEnemyBlockRange=500.0
     SpawnEnemyVisionBlockRange=1000.0
     SpawnFriendlyBlockRange=150.0
     SpawnFriendlyVisionBlockRange=150.0
     SpawnFlagBlockRange=500.0
     bAllowOvertime=False
     AdvantageDuration=60
     HUDType=class'newCTF.newChallengeCTFHUD'

     CaptureSound(0)=none
     CaptureSound(1)=none
     CaptureSound(2)=none
     CaptureSound(3)=none
     ReturnSound=none
     BeaconName="NCTF"
     GameName="New Capture the Flag"
}
