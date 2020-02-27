class DefaultAnnouncer extends NewCTFAnnouncer;

event Spawned() {
    Overtime.Slots[0].Snd = sound'NewCTF.Overtime';
    Overtime.Duration = 0;
    AdvantageGeneric.Slots[0].Snd = sound'NewCTF.AdvantageGeneric';
    AdvantageGeneric.Duration = 0;
    Draw.Slots[0].Snd = sound'NewCTF.Draw';
    Draw.Duration = 0;
}
