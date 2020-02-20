class NewCTFFlag extends CTFFlag;

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

state Dropped {
    function BeginState() {
        super.BeginState();

        BroadcastLocalizedMessage(
            class'NewCTFMessages',
            1, // FlagDropped
            none,
            none,
            CTFGame(Level.Game).Teams[Team]
        );
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
            BroadcastLocalizedMessage(
                class'NewCTFMessages',
                2, // FlagReturned
                none,
                none,
                CTFGame(Level.Game).Teams[Team]
            );
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
