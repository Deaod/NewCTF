class NewCTFFlag extends CTFFlag;

state Held {
    function BeginState() {
        super.BeginState();

        NewCTF(Level.Game).Announce(3, Team, Holder);
        if (PlayerPawn(Holder) != none)
            NewCTF(Level.Game).AnnounceForPlayer(8, PlayerPawn(Holder));
    }
}

state Dropped {
    function BeginState() {
        super.BeginState();

        NewCTF(Level.Game).Announce(1, Team);
    }

    function Touch(Actor Other)
    {
        local Pawn aPawn;

        super.Touch(Other);

        aPawn = Pawn(Other);
        if (   aPawn != None
            && aPawn.bIsPlayer
            && aPawn.Health > 0
            && aPawn.IsInState('FeigningDeath') == false
            && aPawn.PlayerReplicationInfo.Team == Team
        ) {
            // returned flag
            NewCTF(Level.Game).Announce(2, Team);
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
            NewCTF(Level.Game).Announce(4, Team);
        }

        super.Touch(A);
    }
}
