class NewCTFSpawnDummy extends Actor;

#exec TEXTURE IMPORT FILE="Textures/GreySkin.bmp" MIPS=OFF

var NewCTF CTFGame;
var PlayerStart RelatedPlayerStart;

event PostBeginPlay() {
    LoopAnim('Breath1');

    if (CTFGame.MaxPlayers > CTFGame.SpawnSystemThreshold)
        SetTimer(0.2, true);
}

event Timer() {
    SetLocation(RelatedPlayerStart.Location);
    Skin = GetDummyTexture();
    bUnlit = (Skin != Texture'GreySkin');
}

function Texture GetDummyTexture() {
    local byte Reason;
    local bool Viable;
    local int T;
    local int i;
    local int end;

    T = RelatedPlayerStart.TeamNumber;
    end = T*CTFGame.MaxNumSpawnPointsPerTeam + CTFGame.TeamSpawnCount[T];
    for (i = end - CTFGame.SpawnMinCycleDistance; i < end; ++i)
        if (CTFGame.GetPlayerStartByIndex(i) == RelatedPlayerStart)
            return Texture'GreySkin';

    Viable = CTFGame.IsPlayerStartViable(RelatedPlayerStart, Reason);

    if (Viable)
        return Texture'UnrealShare.ShieldBelt.newgreen';

    switch(Reason) {
        case 1:
        case 2:
            return Texture'UnrealShare.ShieldBelt.newred';

        case 3:
        case 4:
            return Texture'UnrealShare.ShieldBelt.newblue';

        case 5:
        case 6:
            return Texture'UnrealShare.ShieldBelt.newgold';
    }

    return Texture'UnrealShare.ShieldBelt.newgreen';
}

defaultproperties
{

    CollisionHeight=0
    CollisionRadius=0

    bCollideWorld=False
    bCollideActors=False
    bBlockActors=False
    bBlockPlayers=False
    bProjTarget=False

    DrawType=DT_Mesh
    Mesh=LodMesh'Botpack.Commando'
    Skin=Texture'GreySkin'
    bAlwaysRelevant=True
    bUnlit=True
}
