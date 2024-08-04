class NewCTFFlag extends CTFFlag;

function SendHome() {
    local DeathMatchPlus G;

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

    if (Level.Game.bGameEnded == false)
        SetCollision(false, false, false);

    super.SendHome();

    // CTFFlag.SendHome calls SetLocation before SetCollision.
    // SetCollision seems to not re-evaluate which Actors are now being touched.
    // Fix this by calling SetLocation again after SetCollision.
    if (Level.Game.bGameEnded == false)
        SetLocation(Location);
}

function Drop(vector newVel) {
    local Pawn OldHolder;
    local vector X,Y,Z;
    local vector NewLoc;
    local bool bHolderPainZone;

    local NewCTF G;
    local bool bEnableModifiedFlagDrop;
    local float FlagDropMaximumSpeed;

    G = NewCTF(Level.Game);
    if (G != none) {
        bEnableModifiedFlagDrop = G.bEnableModifiedFlagDrop;
        FlagDropMaximumSpeed = G.FlagDropMaximumSpeed;
    } else {
        bEnableModifiedFlagDrop = False;
        FlagDropMaximumSpeed = 0;
    }

    BroadcastLocalizedMessage(class'CTFMessage', 2, Holder.PlayerReplicationInfo, None, CTFGame(Level.Game).Teams[Team]);
    if (Level.Game.WorldLog != None)
        Level.Game.WorldLog.LogSpecialEvent("flag_dropped", Holder.PlayerReplicationInfo.PlayerID, CTFGame(Level.Game).Teams[Team].TeamIndex);
    if (Level.Game.LocalLog != None)
        Level.Game.LocalLog.LogSpecialEvent("flag_dropped", Holder.PlayerReplicationInfo.PlayerID, CTFGame(Level.Game).Teams[Team].TeamIndex);

    RotationRate.Yaw = int(FRand() - 0.5) * 200000;
    RotationRate.Pitch = int(FRand() - 0.5) * (200000 - Abs(RotationRate.Yaw));
    if (bEnableModifiedFlagDrop)
        // Modified drop, following player velocity direction and capping maximum speed.
        Velocity = FMin(VSize(newVel),  FlagDropMaximumSpeed)*Normal(newVel);
    else
        // Base game behaviour
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
    SetLocation(Location); // see equivalent line in function SendHome() for why
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
            if (OwnFlag != none && OwnFlag.bHome)
                foreach OwnFlag.TouchingActors(class'Pawn', P)
                    if (P == Holder)
                        OwnFlag.Touch(Holder);
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
