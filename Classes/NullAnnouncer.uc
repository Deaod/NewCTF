class NullAnnouncer extends NewCTFAnnouncer;

event Spawned() {
    AdvantageGeneric.Snd[0]   = sound'NewCTF.AdvantageGeneric';
    AdvantageGeneric.Duration = GetSoundDuration(AdvantageGeneric.Snd[0]);
    Draw.Snd[0]               = sound'NewCTF.Draw';
    Draw.Duration             = GetSoundDuration(Draw.Snd[0]);
}