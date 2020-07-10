class NewCTFClientSettings extends Object
    config perobjectconfig;

var(Announcer) config bool   bEnabled;
var(Announcer) config float  AnnouncerVolume;
var(Announcer) config string CTFAnnouncerClass;
var(Debug)     config bool   Debug;
var()          config int    _Version;

defaultproperties
{
    bEnabled=True
    AnnouncerVolume=1.5
    CTFAnnouncerClass="NewCTF.DefaultAnnouncer"
    Debug=False
    _Version=0
}