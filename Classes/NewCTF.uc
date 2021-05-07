class NewCTF extends BotPack.CTFGame;

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
// Minimum number of spawn points to cycle through before reusing one
var(SpawnSystem) config int SpawnMinCycleDistance;

// True results in default behavior, False activates an advantage system.
var(Game) config bool  bAllowOvertime;
// This is the RespawnDelay after OvertimeRespawnDelayStartTime seconds of
// overtime.
var(Game) config float OvertimeRespawnDelay;
// Every this many seconds of overtime past OvertimeRespawnDelayStartTime
// spawns are delayed by one second.
// Set to zero or less to not increase RespawnDelay past OvertimeRespawnDelay.
var(Game) config float OvertimeRespawnDelayCoefficient;
// Only start delaying respawns after this many seconds of overtime.
var(Game) config int   OvertimeRespawnDelayStartTime;
// Extra time if a flag is in play when the game ends, 0 for no limit
// Never use the value 60, if you like the end-of-match countdown.
var(Game) config int   AdvantageDuration;
// Maximum score difference between best team and second-best team.
// If exceeded, game ends immediately.
var(Game) config int   MercyScore;
// Whether flags glow when held by players.
var(Game) config bool  bFlagGlow;
// How long the flag will remain on the ground during the match
var(Game) config float FlagTimeout;
// How long the flag will remain on the ground during advantage
var(Game) config float FlagTimeoutAdvantage;
// How long the flag will remain on the ground during overtime
var(Game) config float FlagTimeoutOvertime;

const MaxNumSpawnPointsPerTeam = 16;
const MaxNumTeams = 4;

var bool bAdvantage;
var bool bAdvantageDone;

var int OvertimeOffset;

// size of array should be the result of MaxNumTeams*MaxNumSpawnPointsPerTeam
var PlayerStart PlayerStartList[64];
var int         TeamSpawnCount[4];

var int HandledSpawns;
var int OldSystemSpawns;

event InitGame(string Options, out string Error) {
    local string opt;

    super.InitGame(Options, Error);

    SaveConfig();

    opt = ParseOption(Options, "bAllowOvertime");
    if (opt != "" && !(opt ~= "false"))
        bAllowOvertime = true;

    opt = ParseOption(Options, "AdvantageDuration");
    if (opt != "")
        AdvantageDuration = float(opt);

    opt = ParseOption(Options, "MercyScore");
    if (opt != "")
        MercyScore = int(opt);

    opt = ParseOption(Options, "bFlagGlow");
    if (opt != "" && !(opt ~= "false"))
        bFlagGlow = true;
}

function InitSpawnSystem()
{
    local int i,j, swapTarget, offset;
    local NavigationPoint N;
    local int PSTeam;
    local PlayerStart PS;
    local SpawnControlInfo SCI;

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

    foreach AllActors(class'SpawnControlInfo', SCI) {
        SpawnSystemThreshold = SCI.SpawnSystemThreshold;
        SpawnEnemyBlockRange = SCI.SpawnEnemyBlockRange;
        SpawnEnemyVisionBlockRange = SCI.SpawnEnemyVisionBlockRange;
        SpawnFriendlyBlockRange = SCI.SpawnFriendlyBlockRange;
        SpawnFriendlyVisionBlockRange = SCI.SpawnFriendlyVisionBlockRange;
        SpawnFlagBlockRange = SCI.SpawnFlagBlockRange;
    }
}

function InitFlags() {
    local FlagBase FB;
    local NewCTFFlag F;
    local CTFFlag oldF;
    local CTFReplicationInfo ctfState;
    local sound FBAlarm;

    ctfState = CTFReplicationInfo(GameReplicationInfo);
    foreach AllActors(class'FlagBase', FB)
    {
        // CTFFlag hides the flag of its FlagBase when it leaves state Home.
        // Destroying the flag makes it leave its current state, which by
        // default is Home.
        // Since actors are destroyed at the end of a frame, we have to get
        // tricky to work around this.

        FBAlarm = FB.TakenSound;
        FB.TakenSound = none; // first, make sure we dont get annoying sounds

        switch(FB.Team) {
        case TEAM_Red:
            F = FB.Spawn(class'NewCTFFlagRed');
            break;
        case TEAM_Blue:
            F = FB.Spawn(class'NewCTFFlagBlue');
            break;
        case TEAM_Green:
            F = FB.Spawn(class'NewCTFFlagGreen');
            break;
        case TEAM_Gold:
            F = FB.Spawn(class'NewCTFFlagGold');
            break;
        }

        if (F != none) {
            F.HomeBase = FB;
            F.Team = FB.Team;

            oldF = ctfState.FlagList[FB.Team];
            oldF.GoToState('Held'); // next, transition flag out of state Home right now
            oldF.SetTimer(0.0, false); // disable the timer of state Held
            oldF.Destroy(); // now we can safetly destroy the old flag

            ctfState.FlagList[FB.Team] = F;
        }

        FB.bHidden = false; // fix the FlagBase
        FB.TakenSound = FBAlarm;
        FB.NetUpdateFrequency = 20.0;
    }
}

function PostBeginPlay() {
    super.PostBeginPlay();
    InitSpawnSystem();
    InitFlags();

    if (AdvantageDuration == 60) {
        Warn("AdvantageDuration of 60 does not trigger a countdown before advantage end.");
        Warn("Changed AdvantageDuration to 59 as a workaround");
        AdvantageDuration = 59;
    }
}

simulated event PostNetBeginPlay() {
    class'NewCTFMessages'.static.InitAnnouncements(self);
}

function ScoreFlag(Pawn Scorer, CTFFlag F) {
    local CTFReplicationInfo ctfState;
    local int i;
    local bool AllHome;

    super.ScoreFlag(Scorer, F);

    CheckMercy();

    if (bGameEnded || bAdvantage == false) return;

    ctfState = CTFReplicationInfo(GameReplicationInfo);
    AllHome = true;

    for (i = 0; i < MaxTeams; i++) {
        if (   (ctfState.FlagList[i] != none)
            && (ctfState.FlagList[i] != F)
            && (ctfState.FlagList[i].bHome == false))
        {
            AllHome = false;
            break;
        }
    }

    if (AllHome) {
        bAdvantageDone = true;
        bAdvantage = false;
        EndGame("timelimit");
    }
}

function CheckMercy() {
    local int i;
    local TeamInfo T[4];
    local TeamInfo Temp;
    local int Best;

    if (MercyScore <= 0) return;

    for (i = 0; i < MaxTeams; ++i)
        T[i] = Teams[i];

    Best = 0;
    for (i = 1; i < MaxTeams; ++i)
        if (T[i].Score > T[Best].Score)
            Best = i;

    if (Best != 0) {
        Temp = T[0];
        T[0] = T[Best];
        T[Best] = Temp;
    }

    Best = 1;
    for (i = 2; i < MaxTeams; ++i)
        if (T[i].Score > T[Best].Score)
            Best = i;

    if (Best != 1) {
        Temp = T[1];
        T[1] = T[Best];
        T[Best] = Temp;
    }

    if (T[0].Score - T[1].Score > MercyScore) {
        EndGame("mercy");
    }
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
        BroadcastLocalizedMessage(
            class'NewCTFMessages',
            7, // Draw
        );
    }
    CalcEndStats();

    Log(HandledSpawns@"respawns handled of which"@OldSystemSpawns@"("$int(100.0 * float(OldSystemSpawns) / float(HandledSpawns) + 0.5)$"%) fell back to default algorithm.", 'NewCTF');

    return true;
}

function EndGame(string reason) {
    if (reason ~= "timelimit") {
        if (bAllowOvertime && GetBestTeam() == none) {
            bOverTime = true;
            BroadcastLocalizedMessage(DMMessageClass, 0);
            BroadcastLocalizedMessage(
                class'NewCTFMessages',
                5, // Overtime
            );
            OvertimeOffset = GameReplicationInfo.ElapsedTime;
            return;
        }

        if (bAdvantageDone == false && bAdvantage == false && IsEveryFlagHome() == false && AdvantageDuration > 0) {
            bAdvantage = true;
            RemainingTime = AdvantageDuration;
            // Youre probably wondering why the value 60 cant be used. Well, its
            // because of the interaction between variable replication, and how
            // the remaining time is synchronized between server and client.
            //
            // See, variables are only replicated at the end of a tick, so if
            // you change the value twice within a single tick, only the last
            // value will be replicated. This also means that if you change the
            // value of variable A from 'a' to 'b', then back to 'a', nothing
            // will be replicated.
            //
            // Now, when EndGame is called with reason "timelimit",
            // GRI.RemainingMinute was always 60 before entering Timer(), and
            // is changed to 0 during Timer(), after which EndGame is called.
            // AdvantageDuration of 60 would effectively mark
            // GRI.RemainingMinute as unchanged, and thus unreplicated.
            //
            // This is why AdvantageDuration can have any value other than 60.
            GameReplicationInfo.RemainingMinute = AdvantageDuration;
            BroadcastLocalizedMessage(
                class'NewCTFMessages',
                6, // Advantage
            );
            return;
        }
    }

    super.EndGame(reason); // Super is GameInfo
}

function ScoreKill(Pawn Killer, Pawn Other) {
    local int Overtime;
    local float RespawnDelay;

    super.ScoreKill(Killer, Other);

    if (bOverTime) {
        Overtime = GameReplicationInfo.ElapsedTime - OvertimeOffset;
        if (Overtime < OvertimeRespawnDelayStartTime)
            return;

        RespawnDelay = OvertimeRespawnDelay;
        if (OvertimeRespawnDelayCoefficient > 0.0)
            RespawnDelay += (Overtime - OvertimeRespawnDelayStartTime) / OvertimeRespawnDelayCoefficient;

        Other.SetPropertyText("RespawnDelay", string(FMax(1.0, RespawnDelay))); // dont go below default RespawnDelay
    }
}

function Timer() {
    if (bAdvantage && IsEveryFlagHome()) {
        bAdvantageDone = true;
        RemainingTime = 1;
    }

    super.Timer(); // Super is DeathMatchPlus

    if (bAdvantage && bAdvantageDone) {
        bAdvantage = false;
    }
}

function bool IsParticipant(Pawn P) {
    return (P.PlayerReplicationInfo != none)
        && (P.Health > 0)
        && (P.IsA('Spectator') == false)
        && (P.bCollideActors);
}

function bool IsEnemyOfTeam(Pawn P, byte team)
{
    return (P.PlayerReplicationInfo.Team != team);
}

function bool IsFriendOfTeam(Pawn P, byte team)
{
    return (P.PlayerReplicationInfo.Team == team);
}

function bool IsCarryingFlag(Pawn P)
{
    return (P.PlayerReplicationInfo.HasFlag != none)
        && (P.PlayerReplicationInfo.HasFlag.IsA('NewCTFFlag'));
}

function bool IsPlayerStartViable(PlayerStart PS, out byte ExclusionReason)
{
    local Pawn P;
    local CTFFlag F;
    local bool visible;
    local bool enemy, friend, carrier;
    local float distance;
    local vector eyeHeight;
    local float EBR, EVBR, FBR, FVBR, FlagBR;
    local SpawnControlPlayerStart SCPS;

    EBR = SpawnEnemyBlockRange;
    EVBR = SpawnEnemyVisionBlockRange;
    FBR = SpawnFriendlyBlockRange;
    FVBR = SpawnFriendlyVisionBlockRange;
    FlagBR = SpawnFlagBlockRange;

    SCPS = SpawnControlPlayerStart(PS);
    if (SCPS != none) {
        if (SCPS.SpawnEnemyBlockRange >= 0)          EBR = SCPS.SpawnEnemyBlockRange;
        if (SCPS.SpawnEnemyVisionBlockRange >= 0)    EVBR = SCPS.SpawnEnemyVisionBlockRange;
        if (SCPS.SpawnFriendlyBlockRange >= 0)       FBR = SCPS.SpawnFriendlyBlockRange;
        if (SCPS.SpawnFriendlyVisionBlockRange >= 0) FVBR = SCPS.SpawnFriendlyVisionBlockRange;
        if (SCPS.SpawnFlagBlockRange >= 0)           FlagBR = SCPS.SpawnFlagBlockRange;
    }

    for (P = Level.PawnList; P != none; P = P.NextPawn) {
        if (IsParticipant(P) == false) continue;
        enemy = IsEnemyOfTeam(P, PS.TeamNumber);
        friend = IsFriendOfTeam(P, PS.TeamNumber);
        carrier = IsCarryingFlag(P);

        eyeHeight.Z = P.BaseEyeHeight;
        visible = PS.FastTrace(P.Location + eyeHeight);
        distance = VSize(PS.Location - P.Location + eyeHeight);

        if ( enemy &&  visible && distance <= EVBR)   { ExclusionReason = 1; return false; }
        if ( enemy && !visible && distance <= EBR)    { ExclusionReason = 2; return false; }
        if (friend &&  visible && distance <= FVBR)   { ExclusionReason = 3; return false; }
        if (friend && !visible && distance <= FBR)    { ExclusionReason = 4; return false; }
        if ( enemy &&  carrier && distance <= FlagBR) { ExclusionReason = 5; return false; }
    }

    foreach PS.RadiusActors(class'CTFFlag', F, FlagBR) {
        ExclusionReason = 6;
        return false;
    }

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
    local byte ExclusionReason[16];

    // The following is copied from TeamGamePlus
    if ( bStartMatch && (Player != None) && Player.IsA('TournamentPlayer')
        && (Level.NetMode == NM_Standalone)
        && (TournamentPlayer(Player).StartSpot != None) )
        return TournamentPlayer(Player).StartSpot;

    if ((Player != None) && (Player.PlayerReplicationInfo != None))
        team = Player.PlayerReplicationInfo.Team;
    else
        team = InTeam;

    if( incomingName != "" )
        foreach AllActors( class 'Teleporter', Tel )
            if( string(Tel.Tag) ~= incomingName )
                return Tel;
    // end of copy

    if (team >= MaxNumTeams || NumPlayers <= SpawnSystemThreshold)
       return super.FindPlayerStart(Player, InTeam, incomingName);

    ++HandledSpawns;
    psOffset = team * MaxNumSpawnPointsPerTeam;
    for (i = 0; i < TeamSpawnCount[team] - SpawnMinCycleDistance; i++) {
        PS = PlayerStartList[psOffset + i];

        if (IsPlayerStartViable(PS, ExclusionReason[i])) {
            end = TeamSpawnCount[team] - 1;
            while (i < end) {
                PlayerStartList[psOffset + i] = PlayerStartList[psOffset + i + 1];
                i++;
            }

            PlayerStartList[psOffset + i] = PS;

            LastStartSpot = PS;
            return PS;
        }
    }

    while (i < TeamSpawnCount[team]) {
        ExclusionReason[i] = 7;
        i++;
    }

    ++OldSystemSpawns;
    if (Player.PlayerReplicationInfo != none) {
        Log("["$Level.TimeSeconds$"]"@Player.PlayerReplicationInfo.PlayerName@"spawned using default algorithm");
        for (i = 0; i < TeamSpawnCount[team]; ++i) {
            Log(PlayerStartList[psOffset + i]$":"@ExclusionReasonToString(ExclusionReason[i]));
        }
        if (Player.IsA('PlayerPawn')) {
            PlayerPawn(Player).ClientMessage("Used default algorithm to spawn");
        }
    }
    return super.FindPlayerStart(Player, InTeam, incomingName);
}

function string ExclusionReasonToString(byte Reason) {
    switch(Reason) {
        case 1: return "EnemyVisionBlockRange";
        case 2: return "EnemyBlockRange";
        case 3: return "FriendlyVisionBlockRange";
        case 4: return "FriendlyBlockRange";
        case 5: return "CarrierInRange";
        case 6: return "FlagBlockRange";
        case 7: return "RecentlyUsed";
    }
    return "Unknown";
}

function float GetFlagTimeout() {
    if (bOverTime)
        return FlagTimeoutOvertime;
    else if (bAdvantage)
        return FlagTimeoutAdvantage;

    return FlagTimeout;
}

defaultproperties
{
    SpawnSystemThreshold=4
    SpawnEnemyBlockRange=650.0
    SpawnEnemyVisionBlockRange=2000.0
    SpawnFriendlyBlockRange=150.0
    SpawnFriendlyVisionBlockRange=150.0
    SpawnFlagBlockRange=750.0
    SpawnMinCycleDistance=1

    bAllowOvertime=False
    OvertimeRespawnDelay=1.0
    OvertimeRespawnDelayCoefficient=120.0
    OvertimeRespawnDelayStartTime=300
    AdvantageDuration=120
    MercyScore=0
    bFlagGlow=True
    FlagTimeout=25.0
    FlagTimeoutAdvantage=25.0
    FlagTimeoutOvertime=25.0

    GameName="New Capture the Flag"
}
