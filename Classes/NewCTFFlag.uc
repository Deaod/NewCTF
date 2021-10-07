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
    if (   (Holder.Region.Zone.bPainZone && (Holder.Region.Zone.DamagePerSec > 0)) == false
        && (Holder.FootRegion.Zone.bPainZone && (Holder.FootRegion.Zone.DamagePerSec > 0)) == false
    ) {
        BroadcastLocalizedMessage(
            class'NewCTFMessages',
            1, // FlagDropped
            none,
            none,
            CTFGame(Level.Game).Teams[Team]
        );
    }

    super.Drop(newVel);
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
