class NewCTFClientSettings extends Object
    config perobjectconfig;

var(Announcer) config float  AnnouncerVolume;
var(Announcer) config string CTFAnnouncerClass;
var(Debug)     config bool   Debug;
var()          config int    _Version;

defaultproperties
{
    AnnouncerVolume=1.5
    CTFAnnouncerClass="NewCTFv13.DefaultAnnouncer"
    Debug=False
    _Version=0
}