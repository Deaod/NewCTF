class DefaultAnnouncer extends INewCTFAnnouncer;

static function InitAnnouncements(INewCTFAnnouncer Announcer) {
    Announcer.Overtime.Slots[0].Snd = sound'Overtime';
    Announcer.Overtime.Duration = 0;
    Announcer.AdvantageGeneric.Slots[0].Snd = sound'AdvantageGeneric';
    Announcer.AdvantageGeneric.Duration = 0;
    Announcer.Draw.Slots[0].Snd = sound'Draw';
    Announcer.Draw.Duration = 0;
}
