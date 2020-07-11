class DefaultAnnouncer extends NewCTFAnnouncer;

event Spawned() {
    Overtime.Slots[0].Snd = sound'Overtime';
    Overtime.Duration = 0;
    AdvantageGeneric.Slots[0].Snd = sound'AdvantageGeneric';
    AdvantageGeneric.Duration = 0;
    Draw.Slots[0].Snd = sound'Draw';
    Draw.Duration = 0;
}
