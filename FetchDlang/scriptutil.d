module scriptutil;
static import std.ascii;
import std.typecons : Tuple, tuple;
import std.conv : to;
import std.stdio : writefln, stdout;

/**
    Script utilities written 2015 by Laeeth Isharc to accompany fetchdlang script
    Boost license - do as you wish with this, but at your own risk
*/

enum maxTries = 100_000;


private string makeHash(string path)
{
    import std.digest.digest : digest;
    import std.digest.crc : crcHexString,CRC32;
    import std.datetime : Clock,SysTime;
    return digest!CRC32(path).crcHexString ~ digest!CRC32((Clock.currTime.toISOExtString)).crcHexString;
}

private enum permittedCharacters = std.ascii.letters ~ std.ascii.digits;

private string makeRandomAlphaNumeric(size_t numChars)
{
    import std.random : uniform;
    string ret = "";
    foreach(i; 0 .. numChars)
    {
        auto r = uniform(0,permittedCharacters.length);
        ret ~= to!char(r);
    }
    return ret;
}

// shamelessly nicked from http://www.mktemp.org/repos/mktemp/file/e4089ef40fd0/mkdtemp.c

string makeTempDir(string path)
{
    import std.algorithm : max;
    import std.math : pow;
    import std.file : exists, isDir, File;
    import std.string : strip, indexOf;

    if (path.length == 0)
        throw new Exception("makeTempDir: trying to create directory in empty path");

    auto firstindex = path.indexOf("X"); // just add the temp junk to the end if no X specified
    size_t lastindex = -1;
    string frontStub,backStub;
    auto numVarChars = ((lastindex - firstindex) > 2) ? (lastindex-firstindex) : 2;

    if (firstindex != -1)
        lastindex = path[firstindex .. $].indexOf("X")+firstindex;
    frontStub = (firstindex != -1)?path[0 .. firstindex] : "";
    backStub = (lastindex != -1)?path[lastindex .. $] : "";
    File f;

    foreach(trycount; 0 .. max(maxTries,pow(permittedCharacters.length,numVarChars)/5))
    {
        auto tempPath = frontStub ~ ((numVarChars>8) ? makeHash(path) : "") ~ makeRandomAlphaNumeric(lastindex-firstindex);
        debug
        {
            writefln("%s trying to make temp entry in %s",tempPath);
            stdout.flush();
        }
        if (exists(tempPath))
            continue;

        if (safeCreateDir(tempPath))
            return tempPath;
    }
    
    throw new Exception ("makeTempDir unable to make temporary directory in generic path " ~ path );
    assert(0);
}

bool safeCreateDir(string path)
{
    import std.file : mkdir;
    try
    {
        debug
        {
            writefln("safeCreateDir testing %s",path);
            stdout.flush();
        }
        mkdir(path);
    }
    catch(Exception e)
    {
        return false;
    }
    return true;
}

alias universalWhichReturn = Tuple!(bool,"success",string,"result");

universalWhichReturn universalWhich(string arg)
{
    import std.process : executeShell;
    import std.string : strip;

    version(Posix)
    {
        auto which = executeShell("which " ~ arg);
        return universalWhichReturn((which.status == 0),strip(which.output));
    }

    else version(Windows)
    {
        auto which = executeShell("where " ~ arg ~ ".exe");
        return universalWhichReturn((which.status == 0),strip(which.output));
    }
}


bool fileExists(string path)
{
    import std.file : exists, isDir;

    return (exists(path) && (!isDir(path)));
}
string joinPath(string[] args)
{
    import std.file : dirSeparator;
    import std.array : join;
    return join(args,dirSeparator);
}

// I don't know how to get the file permissions bit to see if our process
// can write,. so let's just try and see what happens
// possibly dangerous to try to appenmd to a file we care about if
// something goes wrong and this function does not do what it says on the
// tin

bool fileIsWritable(string path)
{
    import std.file : File;
    try
    {
        auto f = File(path,"w+");
    }
    catch(Exception e) // not checking properly for other exceptions eg memory
    {
        return false;
    }
    return true;
}

bool amIRoot()
{
    import core.sys.posix.unistd : geteuid;
    return (geteuid() == 0);
}