class AnnouncementPlayer extends Actor;

event Spawned() {
    SetBase(Owner);
    SetCollision(false, false, false);
    SetCollisionSize(0, 0);
    SetPhysics(PHYS_None);
}

event Tick(float deltaSeconds) {
    local PlayerPawn P;
    local Actor CameraActor;
    local vector CameraLocation;
    local rotator CameraRotation;

    P = PlayerPawn(Owner);

    if (P != none)
        P.PlayerCalcView(CameraActor, CameraLocation, CameraRotation);
    else
        CameraLocation = Owner.Location;

    SetLocation(CameraLocation);


}

defaultproperties
{
    RemoteRole=ROLE_None
    DrawType=DT_None
}
