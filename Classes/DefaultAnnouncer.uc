class DefaultAnnouncer extends NewCTFAnnouncer;

#exec AUDIO IMPORT FILE="Sounds/flagtaken.wav" name="FlagTaken"

event Spawned() {
    FlagReturned[0].Snd[0] = sound'Botpack.CTF.ReturnSound';
    FlagReturned[0].Duration = 0;
    FlagReturned[1].Snd[0] = sound'Botpack.CTF.ReturnSound';
    FlagReturned[1].Duration = 0;
    FlagReturned[2].Snd[0] = sound'Botpack.CTF.ReturnSound';
    FlagReturned[2].Duration = 0;
    FlagReturned[3].Snd[0] = sound'Botpack.CTF.ReturnSound';
    FlagReturned[3].Duration = 0;

    FlagTaken[0].Snd[1] = sound'NewCTF.FlagTaken';
    FlagTaken[0].Cond[1] = ANNC_Team;
    FlagTaken[0].Duration = 0;
    FlagTaken[1].Snd[1] = sound'NewCTF.FlagTaken';
    FlagTaken[1].Cond[1] = ANNC_Team;
    FlagTaken[1].Duration = 0;
    FlagTaken[2].Snd[1] = sound'NewCTF.FlagTaken';
    FlagTaken[2].Cond[1] = ANNC_Team;
    FlagTaken[2].Duration = 0;
    FlagTaken[3].Snd[1] = sound'NewCTF.FlagTaken';
    FlagTaken[3].Cond[1] = ANNC_Team;
    FlagTaken[3].Duration = 0;

    FlagScored[0].Snd[0] = sound'Botpack.CTF.CaptureSound2';
    FlagScored[0].Duration = 0;
    FlagScored[1].Snd[0] = sound'Botpack.CTF.CaptureSound3';
    FlagScored[1].Duration = 0;
    FlagScored[2].Snd[0] = sound'Botpack.CTF.CaptureSound2';
    FlagScored[2].Duration = 0;
    FlagScored[3].Snd[0] = sound'Botpack.CTF.CaptureSound3';
    FlagScored[3].Duration = 0;

    Overtime.Snd[0]           = sound'NewCTF.Overtime';
    Overtime.Duration         = 0;
    AdvantageGeneric.Snd[0]   = sound'NewCTF.AdvantageGeneric';
    AdvantageGeneric.Duration = 0;
    Draw.Snd[0]               = sound'NewCTF.Draw';
    Draw.Duration             = 0;
    GotFlag.Snd[0]            = sound'NewCTF.GotFlag';
    GotFlag.Duration          = 0;
}
