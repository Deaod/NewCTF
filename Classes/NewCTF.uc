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
var(SpawnSystem) config int   SpawnMinCycleDistance;
// If enabled, use extrapolated position of remote players
var(SpawnSystem) config bool  bSpawnExtrapolateMovement;
// If enabled, use secondary algorithm, else fall back to default
var(SpawnSystem) config bool  bSpawnSecondaryEnabled;
// Maximum distance that can influence the secondary spawn system
var(SpawnSystem) config float SpawnSecondaryMaxDistance;
// Weight of own teams distance to spawn points for secondary system
var(SpawnSystem) config float SpawnSecondaryOwnTeamWeight;
// Weight of flag carrier distance to spawn points for secondary system
var(SpawnSystem) config float SpawnSecondaryCarrierWeight;

// True results in default behavior, False activates an advantage system.
var(Game) config bool  bAllowOvertime;
// How long players have to wait in seconds before being able to respawn.
var(Game) config float RespawnDelay;
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
// Maximum score difference that allows advantage to kick in at the end of the
// match. Negative values mean no limit.
var(Game) config int   AdvantageMaxScoreDiff;
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
// False results in default behaviour. True replaces flag drop behaviour where a dropped flag takes the player velocity up to a maximum speed of FlagDropMaximumSpeed.
var(Game) config bool  bEnableModifiedFlagDrop;
// Limits the velocity of a flag to this value when it is dropped. Only applies if bEnableModifiedFlagDrop is true.
var(Game) config float FlagDropMaximumSpeed;
// Using this password will automatically assign you as spectator
var(Game) config string SpectatorPassword;
// Whether players can change teams after joining
var(Game) config bool   bAllowChangingTeams;
// Whether players can change their names after joining
var(Game) config bool   bAllowChangingNames;
// Whether teams and names should be assigned based on the password provided by players
var(Game) config bool   bEnableAssignedTeams;
// Configures which teams are assigned to which passwords contained in GamePassword
var(Game) config string AssignedTeamStrategy;

const MaxNumSpawnPointsPerTeam = 16;
const MaxNumTeams = 4;

var bool bAdvantage;
var bool bAdvantageDone;

var int OvertimeOffset;

struct SpawnPoint {
    var PlayerStart Spawn;
    var int PrimaryUsage;
    var int SecondaryUsage;
};

// size of array should be the result of MaxNumTeams*MaxNumSpawnPointsPerTeam
var NewCTF.SpawnPoint PlayerStartList[64];
var int               TeamSpawnCount[MaxNumTeams];
var Texture           TeamSkinMap[MaxNumTeams];
var NewCTFSpawnDummy  DummyList[64];


var int HandledSpawns;
var int PrimarySpawns;
var int SecondarySpawns;
var int DefaultSpawns;

var string LogIndentation;

var Mutator WarmupMutator;
var bool bWarmupMutatorSearchDone;
var bool bWarmupDone;

struct PlayerAssignedTeam {
    var string Pass;
    var string PlayerName;
    var byte Team;
};

var PlayerAssignedTeam AssignedPlayer[32];
var int NumAssignedPlayers;
var bool bPlayerInit;

event InitGame(string Options, out string Error) {
    local string opt;
    local string GamePW;

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

    GamePW = ConsoleCommand("get Engine.GameInfo GamePassword");
    opt = ParseOption(Options, "SpectatorPassword");
    if (opt != "" && opt != GamePW)
        SpectatorPassword = opt;

    LogLine("GamePassword: "$GamePW);
    if (bEnableAssignedTeams && InStr(GamePW, ";") >= 0) {
        ParseAssignedTeamConfig(GamePW);
    }
}

function ParseAssignedTeamConfig(string Cfg) {
    local string Part;
    local string Strat;
    local int Pos;
    local int Index;

    Index = 0;
    while(Index < Len(AssignedTeamStrategy) && Cfg != "") {
        Pos = InStr(Cfg, ";");
        Part = Left(Cfg, Pos);
        if (Part != "") {
            Strat = Mid(AssignedTeamStrategy, Index, 1);
            Index += 1;

            if (Strat ~= "s") {
                SpectatorPassword = Part;
            } else {
                ParseAssignment(Part, int(Strat));
            }
        }

        Cfg = Mid(Cfg, Pos + 1);
    }

    LogLine("Assigned Team Config:");
    LogIndent();
    for (Index = 0; Index < NumAssignedPlayers; Index += 1) {
        LogLine("Player:"@AssignedPlayer[Index].PlayerName$", Pass:"@AssignedPlayer[Index].Pass$", Team:"@AssignedPlayer[Index].Team);
    }
    LogUnindent();
}

function ParseAssignment(string Part, int Team) {
    local string Pass, PlayerName;
    local int Pos;

    Pos = InStr(Part, "%");
    if (Pos >= 0) {
        Pass = Left(Part, Pos);
        PlayerName = Mid(Part, Pos + 1);
    } else {
        Pass = Part;
    }

    AssignedPlayer[NumAssignedPlayers].Pass = Pass;
    AssignedPlayer[NumAssignedPlayers].PlayerName = PlayerName;
    AssignedPlayer[NumAssignedPlayers].Team = byte(Team);

    NumAssignedPlayers += 1;
}

function InitSpawnSystem()
{
    local int i,j, swapTarget, offset;
    local NavigationPoint N;
    local int PSTeam;
    local PlayerStart PS;
    local NewCTF.SpawnPoint SP;
    local SpawnControlInfo SCI;

    for (i = 0; i < MaxNumTeams; i++)
        TeamSpawnCount[i] = 0;

    // find the list of spawn points for each team up to a maximum
    for(N = Level.NavigationPointList; N != none; N = N.NextNavigationPoint) {
        PS = PlayerStart(N);
        if (PS != none) {
            PSTeam = PS.TeamNumber;
            if (PSTeam < MaxNumTeams && TeamSpawnCount[PSTeam] < MaxNumSpawnPointsPerTeam) {
                i = PSTeam*MaxNumSpawnPointsPerTeam + TeamSpawnCount[PSTeam];
                PlayerStartList[i].Spawn = PS;
                TeamSpawnCount[PSTeam] += 1;
                DummyList[i] = CreateSpawnDummy(PS);
            }
        }
    }

    // give each teams list of spawn points a little shake
    for (i = 0; i < MaxNumTeams; i++) {
        offset = i * MaxNumSpawnPointsPerTeam;
        for(j = 0; j < TeamSpawnCount[i]; j++) {
            swapTarget = Rand(TeamSpawnCount[i]);
            SP = PlayerStartList[offset + swapTarget];
            PlayerStartList[offset + swapTarget] = PlayerStartList[offset + j];
            PlayerStartList[offset + j] = SP;
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

    Spawn(class'NewCTFFlagFix', self);
}

function NewCTFSpawnDummy CreateSpawnDummy(PlayerStart PS) {
    local NewCTFSpawnDummy D;

    D = Spawn(class'NewCTFSpawnDummy', none, '', PS.Location, PS.Rotation);
    if (D == none)
        return none;

    D.CTFGame = self;
    D.RelatedPlayerStart = PS;

    return D;
}

function PlayerStart GetPlayerStartByIndex(int i) {
    return PlayerStartList[i].Spawn;
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

event PreLogin(
    string Options,
    string Address,
    out string Error,
    out string FailCode
) {
    local string InPassword;
    local string GamePW, AdminPW;

    GamePW = ConsoleCommand("get Engine.GameInfo GamePassword");
    AdminPW = ConsoleCommand("get Engine.GameInfo AdminPassword");

    InPassword = ParseOption(Options, "Password");
    Error="";

    if (!CheckIPPolicy(Address)) {
        Error = IPBanned;
        return;
    }

    if (AdminPW != "" && InPassword ~= AdminPW) {
        return;
    }

    if ((Level.NetMode != NM_Standalone) && AtCapacity(Options)) {
        Error = MaxedOutMessage;
        return;
    }

    if (GamePW == "") {
        return;
    }

    if (InPassword == "") {
        Error = NeedPassword;
        FailCode = "NEEDPW";
        return;
    }

    if (bEnableAssignedTeams && IsAssignedPassword(InPassword)) {
        return;
    }

    if (InPassword ~= GamePW) {
        return;
    }

    if (InPassword ~= SpectatorPassword) {
        return;
    }

    Error = WrongPassword;
    FailCode = "WRONGPW";
    return;
}

function bool IsAssignedPassword(string Password) {
    local int i;

    for (i = 0; i < NumAssignedPlayers; i += 1)
        if (Password ~= AssignedPlayer[i].Pass)
            return true;

    return false;
}

event PlayerPawn Login(
    string Portal,
    string Options,
    out string Error,
    class<PlayerPawn> SpawnClass
) {
    local string Password;
    local int i;
    local PlayerPawn Result;

    Password = ParseOption(Options, "Password");
    if (bEnableAssignedTeams) {
        for (i = 0; i < NumAssignedPlayers; i += 1) {
            if (Password ~= AssignedPlayer[i].Pass) {
                Options = RemoveOption(Options, "Team");
                Options = Options$"?Team="$AssignedPlayer[i].Team;
                if (AssignedPlayer[i].PlayerName != "") {
                    Options = RemoveOption(Options, "Name");
                    Options = Options$"?Name="$AssignedPlayer[i].PlayerName;
                }
                break;
            }
        }
    }

    if (SpectatorPassword != "" && Password ~= SpectatorPassword) {
        Options = RemoveOption(Options, "OverrideClass");
        Options = Options$"?OverrideClass=Botpack.CHSpectator";
    }

    LogLine("Login Options:"@Options);

    bPlayerInit = true;
    Result = super.Login(Portal, Options, Error, SpawnClass);
    bPlayerInit = false;

    return Result;
}

function string RemoveOptionSingle(string Option, string ToRemove) {
    local int Pos;

    Pos = InStr(Option, "=");
    if ((Pos >= 0 && Left(Option, Pos) ~= ToRemove) || (Pos < 0 && Option ~= ToRemove)) {
        return "";
    } else {
        return "?" $ Option;
    }
}

function string RemoveOption(string Options, string ToRemove) {
    local int Pos;
    local string Result, Option;

    if (Left(Options, 1) == "?")
        Options = Mid(Options, 1);

    Pos = InStr(Options, "?");

    while(Pos >= 0) {
        Result = Result $ RemoveOptionSingle(Left(Options, Pos), ToRemove);

        Options = Mid(Options, Pos + 1);
        Pos = InStr(Options, "?");
    }

    return Result $ RemoveOptionSingle(Options, ToRemove);
}

function Mutator FindWarmupMutator() {
    if (bWarmupMutatorSearchDone)
        return WarmupMutator;

    if (WarmupMutator == none)
        foreach AllActors(class'Mutator', WarmupMutator)
            if (WarmupMutator.IsA('MutWarmup'))
                break;

    if (WarmupMutator != none && WarmupMutator.IsA('MutWarmup') == false)
        WarmupMutator = none;

    bWarmupMutatorSearchDone = true;
    return WarmupMutator;
}

function bool IsInWarmup() {
    local Mutator M;
    local bool bInWarmup;

    M = FindWarmupMutator();
    if (M != none)
        bInWarmup = (M.GetPropertyText("bInWarmup") ~= "true");

    // I do not understand what bNetReady is supposed to tell me.
    //   My understanding of bNetReady is that its true when the game is waiting
    // for NetWait seconds to pass. A better name would have been
    // bWaitForNetReady.
    //   Anyway, the result is that the logic is reversed from what youd assume
    // based on the name.
    return bNetReady || bInWarmup || (bRequireReady && CountDown > 0);
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

function int GetMinScoreDiff() {
    local int i;
    local TeamInfo T[4];
    local TeamInfo Temp;
    local int Best;

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

    return T[0].Score - T[1].Score;
}

function CheckMercy() {
    if (MercyScore <= 0) return;

    if (GetMinScoreDiff() > MercyScore) {
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

    LogStats();
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

        if (AdvantageDuration > 0 &&
            bAdvantage == false &&
            bAdvantageDone == false &&
            IsEveryFlagHome() == false &&
            (AdvantageMaxScoreDiff < 0 || GetMinScoreDiff() <= AdvantageMaxScoreDiff)
        ) {
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

function float CalculateRespawnDelay() {
    local int Overtime;
    local float Delay;

    if (bOverTime) {
        Overtime = GameReplicationInfo.ElapsedTime - OvertimeOffset;
        if (Overtime < OvertimeRespawnDelayStartTime)
            return RespawnDelay;

        Delay = OvertimeRespawnDelay;
        if (OvertimeRespawnDelayCoefficient > 0.0)
            Delay += (Overtime - OvertimeRespawnDelayStartTime) / OvertimeRespawnDelayCoefficient;
        return Delay;
    }

    return RespawnDelay;
}

function ScoreKill(Pawn Killer, Pawn Other) {
    super.ScoreKill(Killer, Other);

    Other.SetPropertyText("RespawnDelay", string(FMax(1.0, CalculateRespawnDelay()))); // dont go below default RespawnDelay
}

function RemoveSpawnDummies() {
    local int i;

    for (i = 0; i < arraycount(DummyList); ++i) {
        if (DummyList[i] != none) {
            DummyList[i].Destroy();
            DummyList[i] = none;
        }
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

    if (bWarmupDone == false) {
        bWarmupDone = (IsInWarmup() == false);
        if (bWarmupDone) {
            RemoveSpawnDummies();
        }
    }
}

function bool IsParticipant(Pawn P) {
    return (P.PlayerReplicationInfo != none)
        && (P.Health > 0)
        && (P.IsA('Spectator') == false)
        && (   P.bCollideActors
            || P.IsInState('PlayerWalking')
            || P.IsInState('PlayerSwimming')
            || P.IsInState('PlayerFlying'));
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
    local NewCTFFlag F;
    local bool visible;
    local bool enemy, friend, carrier;
    local vector playerLoc, spawnEyeLoc;
    local float distance;
    local vector eyeHeight;
    local float EBR, EVBR, FBR, FVBR, FlagBR;
    local SpawnControlPlayerStart SCPS;
    local float VisionRange;

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

    VisionRange = FMax(EVBR, FVBR);

    for (P = Level.PawnList; P != none; P = P.NextPawn) {
        if (IsParticipant(P) == false) continue;
        enemy = IsEnemyOfTeam(P, PS.TeamNumber);
        friend = IsFriendOfTeam(P, PS.TeamNumber);
        carrier = IsCarryingFlag(P);
        visible = false;

        eyeHeight.Z = P.BaseEyeHeight;
        spawnEyeLoc = PS.Location;
        spawnEyeLoc.Z += P.default.BaseEyeHeight;

        playerLoc = P.Location + eyeHeight;
        if (bSpawnExtrapolateMovement && P.RemoteRole == ROLE_AutonomousProxy)
            playerLoc += P.Velocity * 0.0005 * Min(P.PlayerReplicationInfo.Ping, 250);

        distance = FMin(VSize(PS.Location - P.Location), VSize(spawnEyeLoc - playerLoc));
        if (distance <= VisionRange) {
            visible = PS.FastTrace(playerLoc) || PS.FastTrace(playerLoc, spawnEyeLoc);
            if (bSpawnExtrapolateMovement && P.RemoteRole == ROLE_AutonomousProxy)
                visible = visible
                    || PS.FastTrace(P.Location + eyeHeight)
                    || PS.FastTrace(P.Location + eyeHeight, spawnEyeLoc);
        }

        if ( enemy && visible && distance <= EVBR)   { ExclusionReason = 1; return false; }
        if ( enemy &&            distance <= EBR)    { ExclusionReason = 2; return false; }
        if (friend && visible && distance <= FVBR)   { ExclusionReason = 3; return false; }
        if (friend &&            distance <= FBR)    { ExclusionReason = 4; return false; }
        if ( enemy && carrier && distance <= FlagBR) { ExclusionReason = 5; return false; }
    }

    foreach PS.RadiusActors(class'NewCTFFlag', F, FlagBR) {
        if (F.bHeld) continue;
        ExclusionReason = 6;
        return false;
    }

    return true;
}

function NavigationPoint PrimarySpawnSystem(Pawn Player, int Team) {
    local int i;
    local int end;
    local int psOffset;
    local NewCTF.SpawnPoint SP;
    local byte ExclusionReason[MaxNumSpawnPointsPerTeam];

    psOffset = Team * MaxNumSpawnPointsPerTeam;
    for (i = 0; i < TeamSpawnCount[Team] - SpawnMinCycleDistance; i++) {
        SP = PlayerStartList[psOffset + i];

        if (IsPlayerStartViable(SP.Spawn, ExclusionReason[i])) {
            end = TeamSpawnCount[Team] - 1;
            while (i < end) {
                PlayerStartList[psOffset + i] = PlayerStartList[psOffset + i + 1];
                i++;
            }

            PrimarySpawns++;
            SP.PrimaryUsage++;
            PlayerStartList[psOffset + i] = SP;

            LastStartSpot = SP.Spawn;
            return SP.Spawn;
        }
    }

    while (i < TeamSpawnCount[Team]) {
        ExclusionReason[i] = 7;
        i++;
    }

    if (Player != none && Player.PlayerReplicationInfo != none) {
        LogLine("["$Level.TimeSeconds$"]"@Player.PlayerReplicationInfo.PlayerName@"cannot spawn using primary algorithm");
        for (i = 0; i < TeamSpawnCount[Team]; ++i)
            LogLine(PlayerStartList[psOffset + i].Spawn$":"@ExclusionReasonToString(ExclusionReason[i]));
    }

    return none;
}

function NavigationPoint SecondarySpawnSystem(Pawn Player, int Team) {
    local Pawn P;
    local int Offset;
    local int Index;
    local int End;
    local NewCTF.SpawnPoint SP;
    local bool Friend;
    local bool Carrier;
    local vector PlayerLoc;
    local vector EyeHeight;
    local float Distance;
    local float DistanceSum[MaxNumSpawnPointsPerTeam];
    local int BestIndex;
    local float BestSum;
    local NavigationPoint Spawn;

    if (bSpawnSecondaryEnabled == false)
        return none;

    SecondarySpawns++;

    Offset = Team * MaxNumSpawnPointsPerTeam;
    End = TeamSpawnCount[Team] - SpawnMinCycleDistance;
    for (P = Level.PawnList; P != none; P = P.NextPawn) {
        if (IsParticipant(P) == false) continue;
        Friend = IsFriendOfTeam(P, Team);
        Carrier = IsCarryingFlag(P);
        EyeHeight.Z = P.BaseEyeHeight;

        PlayerLoc = P.Location + EyeHeight;
        if (bSpawnExtrapolateMovement && P.RemoteRole == ROLE_AutonomousProxy)
            PlayerLoc += P.Velocity * 0.0005 * Min(P.PlayerReplicationInfo.Ping, 250);

        for (Index = 0; Index < End; Index++) {
            SP = PlayerStartList[Offset + Index];

            Distance = FMin(VSize(SP.Spawn.Location - PlayerLoc), SpawnSecondaryMaxDistance);
            if (Friend)
                Distance *= SpawnSecondaryOwnTeamWeight;
            else if (Carrier)
                Distance *= SpawnSecondaryCarrierWeight;

            DistanceSum[Index] += Distance;
        }
    }

    for (Index = 0; Index < End; Index++) {
        if (DistanceSum[Index] > BestSum) {
            BestSum = DistanceSum[Index];
            BestIndex = Index;
        }
    }

    SP = PlayerStartList[Offset + BestIndex];
    SP.SecondaryUsage++;
    Spawn = SP.Spawn;

    for(Index = BestIndex; Index < TeamSpawnCount[Team]-1; Index++) {
        PlayerStartList[Offset + Index] = PlayerStartList[Offset + Index + 1];
    }
    PlayerStartList[Offset + Index] = SP;

    if (Player != none && Player.PlayerReplicationInfo != none)
        BroadcastMessage(Player.PlayerReplicationInfo.PlayerName@"used secondary algorithm to spawn");

    return Spawn;
}

function NavigationPoint FindPlayerStart(Pawn Player, optional byte InTeam, optional string IncomingName) {
    local int team;
    local Teleporter Tel;
    local NavigationPoint Spawn;

    // The following is copied from TeamGamePlus
    if ( bStartMatch && (Player != None) && Player.IsA('TournamentPlayer')
        && (Level.NetMode == NM_Standalone)
        && (TournamentPlayer(Player).StartSpot != None) )
        return TournamentPlayer(Player).StartSpot;

    if ((Player != None) && (Player.PlayerReplicationInfo != None))
        team = Player.PlayerReplicationInfo.Team;
    else
        team = InTeam;

    if( IncomingName != "" )
        foreach AllActors( class 'Teleporter', Tel )
            if( string(Tel.Tag) ~= IncomingName )
                return Tel;
    // end of copy

    if (team >= MaxNumTeams || NumPlayers <= SpawnSystemThreshold || Player == none)
       return super.FindPlayerStart(Player, InTeam, IncomingName);

    ++HandledSpawns;

    Spawn = PrimarySpawnSystem(Player, team);
    if (Spawn != none)
        return Spawn;

    Spawn = SecondarySpawnSystem(Player, team);
    if (Spawn != none)
        return Spawn;

    ++DefaultSpawns;

    if (Player != none && Player.PlayerReplicationInfo != none)
        BroadcastMessage(Player.PlayerReplicationInfo.PlayerName@"used default algorithm to spawn");

    return super.FindPlayerStart(Player, InTeam, IncomingName);
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

function bool ChangeTeam(Pawn Other, int NewTeam) {
    local bool Result;
    if (bAllowChangingTeams || bPlayerInit) {
        Result = super.ChangeTeam(Other, NewTeam);
        LogLine("ChangeTeam - Allowed -"@Result);
        return Result;
    }
    LogLine("ChangeTeam - Forbidden");
    return false;
}

function ChangeName(Pawn Other, string S, bool bNameChange) {
    if (bAllowChangingNames || bPlayerInit) {
        super.ChangeName(Other, S, bNameChange);
        LogLine("ChangeName - Allowed -"@S);
        return;
    }
    LogLine("ChangeName - Forbidden");
}

function LogLine(coerce string S) {
    Log(LogIndentation$S, 'NewCTF');
}

function LogStats() {
    local int Team;
    LogLine("Total respawns:"@HandledSpawns);
    LogIndent();
    LogLine("Primary:"@PrimarySpawns);
    LogLine("Seconary:"@SecondarySpawns);
    LogLine("Default:"@DefaultSpawns);
    LogUnindent();

    for(Team = 0; Team < MaxTeams; Team++)
        LogTeamStats(Team);
}

function LogTeamStats(int Team) {
    local int Index;
    local int Offset;
    LogLine("Spawns for team"@"'"$GetTeam(Team).TeamName$"'");
    Offset = Team * MaxNumSpawnPointsPerTeam;
    for (Index = 0; Index < TeamSpawnCount[Team]; Index++) {
        LogIndent();
        LogSpawnPointStats(PlayerStartList[Offset + Index]);
        LogUnindent();
    }
}

function LogSpawnPointStats(NewCTF.SpawnPoint SP) {
    LogLine(SP.Spawn);
    LogIndent();
    LogLine("Primary:"@SP.PrimaryUsage);
    LogLine("Secondary:"@SP.SecondaryUsage);
    LogUnindent();
}

function LogIndent() {
    LogIndentation = LogIndentation $ "    ";
}

function LogUnindent() {
    LogIndentation = Left(LogIndentation, Len(LogIndentation) - 4);
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
    bSpawnExtrapolateMovement=True
    bSpawnSecondaryEnabled=True
    SpawnSecondaryMaxDistance=2000.0
    SpawnSecondaryOwnTeamWeight=0.2
    SpawnSecondaryCarrierWeight=2.0

    bAllowOvertime=False
    RespawnDelay=1.0
    OvertimeRespawnDelay=1.0
    OvertimeRespawnDelayCoefficient=120.0
    OvertimeRespawnDelayStartTime=300
    AdvantageDuration=120
    AdvantageMaxScoreDiff=-1
    MercyScore=0
    bFlagGlow=True
    FlagTimeout=25.0
    FlagTimeoutAdvantage=25.0
    FlagTimeoutOvertime=25.0

    bEnableModifiedFlagDrop=False
    FlagDropMaximumSpeed=200.0

    SpectatorPassword=""
    bAllowChangingTeams=True
    bAllowChangingNames=True

    bEnableAssignedTeams=False
    AssignedTeamStrategy="0000011111"

    GameName="New Capture the Flag"
}
