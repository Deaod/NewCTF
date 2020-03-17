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

    super.SendHome();
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
        super.BeginState();

        BroadcastLocalizedMessage(
            class'NewCTFMessages',
            3, // FlagTaken
            Holder.PlayerReplicationInfo,
            none,
            CTFGame(Level.Game).Teams[Team]
        );

        Holder.ReceiveLocalizedMessage(
            class'NewCTFMessages',
            8, // YouHaveTheFlag
        );
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

DefaultProperties
{
    bAlwaysRelevant=True
}
