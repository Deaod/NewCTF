class NewCTFFlag extends CTFFlag;

function SendHome() {
    local DeathMatchPlus G;
    local Pawn P;
    local vector D;

    G = DeathMatchPlus(Level.Game);

    if ((G != none) && G.bNetReady == false && (G.bRequireReady == false || (G.CountDown <= 0))) {
        if (Holder == none) {
            BroadcastLocalizedMessage(
                class'NewCTFMessages',
                2, // FlagReturned
                none,
                none,
                CTFGame(Level.Game).Teams[Team]
            );
        }
    }

    super.SendHome();

    if (HomeBase != none && Level.Game.GameReplicationInfo.GameEndedComments == "") {
        for (P = Level.PawnList; P != none; P = P.NextPawn) {
            D = P.Location - Location;
            if (P.IsA('Spectator') || P.bCollideActors == false)
                continue;
            if (VSize(D * vect(1,1,0)) <= P.CollisionRadius + CollisionRadius && Abs(D.Z) <= P.CollisionHeight + CollisionHeight) {
                Touch(P);
            }
        }
    }
}

function Drop(vector newVel) {
    local Pawn OldHolder;
    local vector X,Y,Z;
    local vector NewLoc;
    local bool bHolderPainZone;

    BroadcastLocalizedMessage(class'CTFMessage', 2, Holder.PlayerReplicationInfo, None, CTFGame(Level.Game).Teams[Team]);
    if (Level.Game.WorldLog != None)
        Level.Game.WorldLog.LogSpecialEvent("flag_dropped", Holder.PlayerReplicationInfo.PlayerID, CTFGame(Level.Game).Teams[Team].TeamIndex);
    if (Level.Game.LocalLog != None)
        Level.Game.LocalLog.LogSpecialEvent("flag_dropped", Holder.PlayerReplicationInfo.PlayerID, CTFGame(Level.Game).Teams[Team].TeamIndex);

    RotationRate.Yaw = int(FRand() - 0.5) * 200000;
    RotationRate.Pitch = int(FRand() - 0.5) * (200000 - Abs(RotationRate.Yaw));
    Velocity = (0.2 + FRand()) * (newVel + 400 * FRand() * VRand());
    If (Region.Zone.bWaterZone)
        Velocity *= 0.5;
    OldHolder = Holder;
    Holder.PlayerReplicationInfo.HasFlag = None;
    Holder.AmbientGlow = Holder.Default.AmbientGlow;
    LightType = LT_Steady;
    Holder.LightType = LT_None;
    bHolderPainZone =
        (Holder.Region.Zone.bPainZone && (Holder.Region.Zone.DamagePerSec > 0)) ||
        (Holder.FootRegion.Zone.bPainZone && (Holder.FootRegion.Zone.DamagePerSec > 0));
    if (Holder.Inventory != None)
        Holder.Inventory.SetOwnerDisplay();
    Holder = None;

    GetAxes(OldHolder.Rotation, X,Y,Z);
    SetRotation(rotator(-1 * X));
    bCollideWorld = true;
    SetCollisionSize(0.5 * Default.CollisionRadius, CollisionHeight);
    NewLoc = OldHolder.Location - 2 * OldHolder.CollisionRadius * X + OldHolder.CollisionHeight * vect(0,0,0.5);
    if ((SetLocation(NewLoc) == false || FastTrace(OldHolder.Location, Location) == false) && SetLocation(OldHolder.Location) == false) {
        SetCollisionSize(0.8 * OldHolder.CollisionRadius, FMin(CollisionHeight, 0.8 * OldHolder.CollisionHeight));
        if (SetLocation(OldHolder.Location) == false) {
            SendHome();
            return;
        }
    }

    SetPhysics(PHYS_Falling);
    SetBase(None);
    SetCollision(true, false, false);
    GotoState('Dropped');
    if (bHolderPainZone)
        Timer();
    else
        BroadcastLocalizedMessage(
            class'NewCTFMessages',
            1, // FlagDropped
            none,
            none,
            CTFGame(Level.Game).Teams[Team]
        );
}

state Held {
    function BeginState() {
        local Pawn P;
        local CTFFlag OwnFlag;
        local vector DeltaOwn;
        local vector DeltaEnemy;

        super.BeginState();

        BroadcastLocalizedMessage(
            class'NewCTFMessages',
            3, // FlagTaken
            Holder.PlayerReplicationInfo,
            none,
            CTFGame(Level.Game).Teams[Team]
        );

        for(P = Level.PawnList; P != none; P = P.NextPawn)
            if (P.PlayerReplicationInfo != none && P.PlayerReplicationInfo.Team == Team)
                P.ReceiveLocalizedMessage(class'CTFMessage2', 1);

        Holder.ReceiveLocalizedMessage(
            class'NewCTFMessages',
            8, // YouHaveTheFlag
        );
        Holder.ReceiveLocalizedMessage(
            class'CTFMessage2',
            0
        );

        if (Level.Game.IsA('CTFGame')) {
            OwnFlag = CTFReplicationInfo(Level.Game.GameReplicationInfo).FlagList[Holder.PlayerReplicationInfo.Team];
            if (OwnFlag != none && OwnFlag.bHome) {
                DeltaOwn = Holder.Location - OwnFlag.Location;
                DeltaEnemy = Holder.Location - Location;
                if (VSize(DeltaOwn * vect(1,1,0)) <= Holder.CollisionRadius + OwnFlag.CollisionRadius &&
                    Abs(DeltaOwn.Z) <= Holder.CollisionHeight + OwnFlag.CollisionHeight &&
                    VSize(DeltaEnemy * vect(1,1,0)) <= Holder.CollisionRadius + CollisionRadius &&
                    Abs(DeltaEnemy.Z) <= Holder.CollisionHeight + CollisionHeight
                ) {
                    OwnFlag.Touch(Holder);
                }
            }
        }
    }
}

auto state Home {
    function Touch(Actor A) {
        local Pawn P;

        P = Pawn(A);
        if (P == none || P.bIsPlayer == false || P.Health <= 0) {
            super.Touch(A);
            return;
        }

        if (P.PlayerReplicationInfo.Team == Team && P.PlayerReplicationInfo.HasFlag != none) {
            BroadcastLocalizedMessage(
                class'NewCTFMessages',
                4, // FlagCaptured
                none,
                none,
                CTFGame(Level.Game).Teams[Team]
            );
        }

        super.Touch(A);
    }
}

state Dropped {
    function BeginState() {
        LightEffect = LE_NonIncidence;
        SetTimer(NewCTF(Level.Game).GetFlagTimeout(), false);
        bCollideWorld = true;
        bKnownLocation = false;
        bHidden = false;
    }
}

function SetHolderLighting() {
    local NewCTF G;

    super.SetHolderLighting();

    G = NewCTF(Level.Game);
    if (G != none && G.bFlagGlow == false) {
        Holder.LightType = LT_None;
        Holder.AmbientGlow = Holder.default.AmbientGlow;
    }
}

DefaultProperties
{
    bAlwaysRelevant=True
    bSimFall=True
}
