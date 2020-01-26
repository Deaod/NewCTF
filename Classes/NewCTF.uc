class NewCTF extends BotPack.CTFGame
    config;

const MaxNumSpawnPointsPerTeam = 16;
const MaxNumTeams = 4;

enum EAnnouncement {
    ANN_FlagDropped,
    ANN_FlagReturned,
    ANN_FlagTaken,
    ANN_FlagCaptured,
    ANN_Overtime,
    ANN_AdvantageGeneric,
    ANN_Advantage,
    ANN_Draw,
    ANN_Win,
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
var()            config bool bAllowOvertime;
// Extra time if a flag is in play when the game ends, 0 for no limit
var()            config int AdvantageExtraSeconds;

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

function InitSpawnSystem()
{
    local int i,j, swapTarget, offset;
    local NavigationPoint N;
    local int PSTeam;
    local PlayerStart PS;

    for (i = 0; i < MaxNumTeams; i++)
        TeamSpawnCount[i] = 0;

    // find the list of spawn points for each team up to a maximum
    for(N = Level.NavigationPointList; N != none; N = N.NextNavigationPoint)
    {
        PS = PlayerStart(N);
        if (PS != none)
        {
            PSTeam = PS.TeamNumber;
            if (TeamSpawnCount[PSTeam] < MaxNumSpawnPointsPerTeam) {
                PlayerStartList[PSTeam*MaxNumSpawnPointsPerTeam + TeamSpawnCount[PSTeam]] = PS;
                TeamSpawnCount[PSTeam] += 1;
            }
        }
    }

    // give each teams list of spawn points a little shake
    for (i = 0; i < MaxNumTeams; i++)
    {
        offset = i*MaxNumSpawnPointsPerTeam;
        for(j = 0; j < TeamSpawnCount[i]; j++)
        {
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

function bool SetEndCams(string Reason) {
    local TeamInfo Best;
    local FlagBase BestBase;
    local CTFFlag BestFlag;
    local Pawn P;
    local int i;
    local PlayerPawn Player;
    local CTFReplicationInfo ctfState;
    local int numFlagsHeld;
    local bool draw;
    local bool AllFlagsHome;

    ctfState = CTFReplicationInfo(GameReplicationInfo);
    draw = false;

    Best = Teams[0];
    for (i = 1; i < MaxTeams; i++)
        if (Best.Score < Teams[i].Score)
            Best = Teams[i];


    for (i = 0; i < MaxTeams; i++) {
        if ((Best.TeamIndex != i) && (Best.Score == Teams[i].Score)) {
            draw = true;
            if (bAllowOvertime) {
                BroadcastLocalizedMessage(DMMessageClass, 0);
                Announce(ANN_Overtime);
                return false;
            }
        }
    }

    for (i = 0; i < MaxTeams; i++)
        AllFlagsHome = AllFlagsHome && ctfState.FlagList[i].bHome;

    if (bAdvantageDone == false && bAdvantage == false && AllFlagsHome == false) {
        bAdvantage = true;
        AdvantageCountdown = AdvantageExtraSeconds;
        Announce(ANN_AdvantageGeneric);
        return false;
    }

    if (draw) {
        GameReplicationInfo.GameEndedComments = "Draw";

        EndTime = Level.TimeSeconds + 3.0;
        for (P = Level.PawnList; P != none; P = P.NextPawn) {
            P.GotoState('GameEnded');
            Player = PlayerPawn(P);
            if (Player != none) {
                Player.bBehindView = true;
                Player.ViewTarget = ctfState.FlagList[Player.PlayerReplicationInfo.Team].HomeBase;
                Player.ClientGameEnded();
            }
        }

        for (i = 0; i < MaxTeams; i++) {
            if (ctfState.FlagList[i] != none) {
                ctfState.FlagList[i].HomeBase.bHidden = false;
                ctfState.FlagList[i].bHidden = true;
            }
        }

        CalcEndStats();
        Announce(ANN_Draw);
    } else {
        // find winner
        ForEach AllActors(class'CTFFlag', BestFlag)
            if ( BestFlag.Team == Best.TeamIndex )
                break;

        BestBase = BestFlag.HomeBase;
        GameReplicationInfo.GameEndedComments = TeamPrefix@Best.TeamName@GameEndedMessage;

        EndTime = Level.TimeSeconds + 3.0;
        for (P = Level.PawnList; P != None; P = P.nextPawn) {
            P.GotoState('GameEnded');
            Player = PlayerPawn(P);
            if (Player != None)
            {
                Player.bBehindView = true;
                Player.ViewTarget = BestBase;
                if (!bTutorialGame)
                    PlayWinMessage(Player, (Player.PlayerReplicationInfo.Team == Best.TeamIndex));
                Player.ClientGameEnded();
            }
        }
        BestBase.bHidden = false;
        BestFlag.bHidden = true;
        CalcEndStats();
    }
    return true;
}

function Timer() {
    local CTFReplicationInfo ctfState;
    local bool AllFlagsHome;
    local int i;
    local Pawn P;

    Super.Timer();

    ctfState = CTFReplicationInfo(GameReplicationInfo);
    AllFlagsHome = true;
    for (i = 0; i < MaxTeams; i++) {
        AllFlagsHome = AllFlagsHome && ctfState.FlagList[i].bHome;
    }
    if (bAdvantage) {
        AdvantageCountdown--;

        if (AdvantageCountdown <= 10) {
            for (P = Level.PawnList; P != none; P = P.NextPawn)
                if (P.IsA('TournamentPlayer'))
                    TournamentPlayer(P).TimeMessage(AdvantageCountdown);
        }

        if (AdvantageCountdown == 0 || AllFlagsHome) {
            bAdvantageDone = true;
            bAdvantage = false;
            EndGame("timelimit");
        }
    }
}

function bool IsEnemyOfTeam(Pawn P, byte team)
{
    return P.PlayerReplicationInfo != none
        && P.PlayerReplicationInfo.Team != team
        && P.Health > 0
        && P.IsA('Spectator') == false;
}

function bool IsFriendOfTeam(Pawn P, byte team)
{
    return P.PlayerReplicationInfo != none
        && P.PlayerReplicationInfo.Team == team
        && P.Health > 0
        && P.IsA('Spectator') == false;
}

function bool IsPlayerStartViable(PlayerStart PS)
{
    local Pawn P;
    local CTFFlag F;

    if (PS.bEnabled == false) return false;

    foreach PS.RadiusActors(class'Pawn', P, SpawnEnemyBlockRange)
        if (IsEnemyOfTeam(P, PS.TeamNumber))
            return false;

    foreach PS.VisibleActors(class'Pawn', P, SpawnEnemyVisionBlockRange)
        if (IsEnemyOfTeam(P, PS.TeamNumber))
            return false;

    foreach PS.RadiusActors(class'Pawn', P, SpawnFriendlyBlockRange)
        if (IsFriendOfTeam(P, PS.TeamNumber))
            return false;

    foreach PS.VisibleActors(class'Pawn', P, SpawnFriendlyVisionBlockRange)
        if (IsFriendOfTeam(P, PS.TeamNumber))
            return false;

    foreach PS.RadiusActors(class'CTFFlag', F, SpawnFlagBlockRange)
        return false;

    return true;
}

function NavigationPoint FindPlayerStart(Pawn Player, optional byte InTeam, optional string incomingName)
{
    local int i;
    local int j;
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
    for (i = 0; i < TeamSpawnCount[team]; i++)
    {
        PS = PlayerStartList[psOffset + i];

        if (IsPlayerStartViable(PS))
        {
            for (i = i; i < TeamSpawnCount[team] - 1; i++)
                PlayerStartList[psOffset + i] = PlayerStartList[psOffset + i + 1];

            PlayerStartList[psOffset + i + 1] = PS;

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
    case ANN_Advantage:
        return CTFAnnouncerClass.Default.Advantage[Team];
    case ANN_Draw:
        return CTFAnnouncerClass.Default.Draw;
    case ANN_Win:
        return CTFAnnouncerClass.Default.Win[Team];
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
     SpawnEnemyBlockRange=400.0
     SpawnEnemyVisionBlockRange=800.0
     SpawnFriendlyBlockRange=120.0
     SpawnFriendlyVisionBlockRange=120.0
     SpawnFlagBlockRange=400.0
     bAllowOvertime=False
     AdvantageExtraSeconds=60;

     CaptureSound(0)=none
     CaptureSound(1)=none
     CaptureSound(2)=none
     CaptureSound(3)=none
     ReturnSound=none
     BeaconName="NCTF"
     GameName="New Capture the Flag"
}