class NewCTFFlag extends CTFFlag;

// facilitates edge triggering
var name OldState;

state Held {
    function BeginState() {
        super.BeginState();

        NewCTF(Level.Game).Announce(ANN_FlagTaken, Team);
    }

    function EndState() {
        OldState = 'Held';
        super.EndState();
    }
}

state Dropped {
    function BeginState() {
        super.BeginState();

        NewCTF(Level.Game).Announce(ANN_FlagDropped, Team);
    }

    function EndState() {
        OldState = 'Dropped';
        super.EndState();
    }
}

auto state Home {
    function BeginState() {
        super.BeginState();
        if (OldState == 'Dropped')
            NewCTF(Level.Game).Announce(ANN_FlagReturned, Team);
    }

    function Touch(Actor A) {
        local Pawn P;

        P = Pawn(A);
        if (P == none || P.bIsPlayer == false || P.Health <= 0) {
            super.Touch(A);
            return;
        }

        if (P.PlayerReplicationInfo.Team == Team && P.PlayerReplicationInfo.HasFlag != none) {
            NewCTF(Level.Game).Announce(ANN_FlagCaptured, Team);
        }

        super.Touch(A);
    }

    function EndState() {
        OldState = 'Home';
        super.EndState();
    }
}

defaultproperties
{
    OldState='None'
}