class AnnouncementPlayer extends Actor;

event Spawned() {
    SetBase(Owner);
    SetCollision(false, false, false);
    SetCollisionSize(0, 0);
    SetPhysics(PHYS_None);
}

event Tick(float deltaSeconds) {
    SetLocation(Owner.Location);
}

defaultproperties
{
    RemoteRole=ROLE_None
    DrawType=DT_None
}
