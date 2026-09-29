module app;

import core.stdc.time : time;
import std.conv : to;
import std.exception : enforce;
import std.file : exists, mkdirRecurse, remove, rename;
import std.path : buildPath;
import std.stdio : File, stdin, stdout, stderr, writeln, write, readln;
import std.string : chomp, strip, toLower;

import sprott;

struct Options
{
    string command = "search";
    string code;
    string output = "out";
    string dictionary = "SA.DIC";
    string favorites = "FAVORITE.DIC";
    ulong seed;
    ulong count = 0;
    ulong candidateLimit = 0;
    ulong iterations = 0;
    Config config;
}

private void usage()
{
    writeln("sprott-d search [options]");
    writeln("sprott-d code CODE [options]");
    writeln("sprott-d evaluate [options]");
    writeln("");
    writeln("Options:");
    writeln("  --output DIR");
    writeln("  --seed N");
    writeln("  --count N                 found attractors to save; 0 means unbounded");
    writeln("  --candidate-limit N       stop search after N candidates; 0 means unbounded");
    writeln("  --iterations N            finite code/evaluate run length");
    writeln("  --dimension 1..4");
    writeln("  --ode 0..7");
    writeln("  --max-order 2..5");
    writeln("  --max-iterations N");
    writeln("  --projection planar|sphere|hcyl|vcyl|torus");
    writeln("  --third projection|shadow|bands|colors|anaglyph|stereogram|slices");
    writeln("  --fourth projection|bands|colors");
    writeln("  --sound");
    writeln("  --save none|x|y|z|w");
    writeln("  --dictionary FILE");
    writeln("  --favorites FILE");
}

private string nextArg(string[] args, ref size_t i, string option)
{
    enforce(i + 1 < args.length, option ~ " needs a value");
    i++;
    return args[i];
}

private Projection parseProjection(string value)
{
    switch (value.toLower)
    {
        case "planar": return Projection.planar;
        case "sphere": return Projection.sphere;
        case "hcyl": return Projection.horizontalCylinder;
        case "vcyl": return Projection.verticalCylinder;
        case "torus": return Projection.torus;
        default: throw new Exception("bad projection: " ~ value);
    }
}

private ThirdDimensionMode parseThird(string value)
{
    switch (value.toLower)
    {
        case "projection": return ThirdDimensionMode.projection;
        case "shadow": return ThirdDimensionMode.shadow;
        case "bands": return ThirdDimensionMode.bands;
        case "colors": return ThirdDimensionMode.colors;
        case "anaglyph": return ThirdDimensionMode.anaglyph;
        case "stereogram": return ThirdDimensionMode.stereogram;
        case "slices": return ThirdDimensionMode.slices;
        default: throw new Exception("bad third-dimension mode: " ~ value);
    }
}

private FourthDimensionMode parseFourth(string value)
{
    switch (value.toLower)
    {
        case "projection": return FourthDimensionMode.projection;
        case "bands": return FourthDimensionMode.bands;
        case "colors": return FourthDimensionMode.colors;
        default: throw new Exception("bad fourth-dimension mode: " ~ value);
    }
}

private int parseSave(string value)
{
    switch (value.toLower)
    {
        case "none": return 0;
        case "x": return 1;
        case "y": return 2;
        case "z": return 3;
        case "w": return 4;
        default: throw new Exception("bad save coordinate: " ~ value);
    }
}

private Options parseOptions(string[] args)
{
    Options options;
    options.seed = cast(ulong)time(null);
    if (args.length > 1 && args[1][0] != '-')
        options.command = args[1].toLower;

    size_t i = options.command == "search" && (args.length <= 1 || args[1][0] == '-') ? 1 : 2;
    if (options.command == "code")
    {
        enforce(i < args.length, "code mode needs an attractor code");
        options.code = args[i++];
    }

    while (i < args.length)
    {
        const string arg = args[i];
        switch (arg)
        {
            case "--output": options.output = nextArg(args, i, arg); break;
            case "--seed": options.seed = to!ulong(nextArg(args, i, arg)); break;
            case "--count": options.count = to!ulong(nextArg(args, i, arg)); break;
            case "--candidate-limit": options.candidateLimit = to!ulong(nextArg(args, i, arg)); break;
            case "--iterations": options.iterations = to!ulong(nextArg(args, i, arg)); break;
            case "--dimension": options.config.dimension = to!int(nextArg(args, i, arg)); break;
            case "--ode": options.config.odeKind = to!int(nextArg(args, i, arg)); break;
            case "--max-order": options.config.maxOrder = to!int(nextArg(args, i, arg)); break;
            case "--max-iterations": options.config.maxIterations = to!ulong(nextArg(args, i, arg)); break;
            case "--projection": options.config.projection = parseProjection(nextArg(args, i, arg)); break;
            case "--third": options.config.thirdMode = parseThird(nextArg(args, i, arg)); break;
            case "--fourth": options.config.fourthMode = parseFourth(nextArg(args, i, arg)); break;
            case "--sound": options.config.sound = true; break;
            case "--save": options.config.saveCoordinate = parseSave(nextArg(args, i, arg)); break;
            case "--dictionary": options.dictionary = nextArg(args, i, arg); break;
            case "--favorites": options.favorites = nextArg(args, i, arg); break;
            case "--help": usage(); throw new Exception("");
            default: throw new Exception("unknown option: " ~ arg);
        }
        i++;
    }

    if (options.config.odeKind == 1)
        enforce(options.config.dimension >= 3, "the original polynomial ODE modes are 3-D and 4-D");
    if (options.config.odeKind > 1)
        options.config.dimension = 4;
    options.config.validate();
    return options;
}

private File openDataFile(ref Options options)
{
    if (options.config.saveCoordinate == 0)
        return File.init;
    static immutable string[5] names = ["", "XDATA.DAT", "YDATA.DAT", "ZDATA.DAT", "WDATA.DAT"];
    const string path = buildPath(options.output, names[options.config.saveCoordinate]);
    return File(path, "w");
}

private void saveResult(ref Engine engine, ref Options options, const CandidateResult result, size_t index)
{
    const string stem = outputStem(options.output, index, result.code);
    engine.raster.writePpm(stem ~ ".ppm");
    writeMetadata(stem ~ ".txt", result, options.config);
    if (result.tones.length)
        writeToneEvents(stem ~ ".tones.tsv", result.tones);
    writeln(stem ~ ".ppm");
}

private void appendDictionary(string path, const CandidateResult result)
{
    auto file = File(path, "a");
    file.writef("%s%5.2f%5.2f\n", result.code, result.fractalDimension, result.lyapunov);
}

private int runSearch(ref Options options)
{
    auto engine = new Engine(options.config, options.seed);
    mkdirRecurse(options.output);
    ulong attempts = 0;
    size_t found = 0;

    while (options.count == 0 || found < options.count)
    {
        attempts++;
        auto data = openDataFile(options);
        File* dataPtr = data.isOpen ? &data : null;
        auto result = engine.runCandidate("", RunMode.search, 0, dataPtr);
        if (data.isOpen)
            data.close();

        if (result.found)
        {
            found++;
            saveResult(engine, options, result, found);
            appendDictionary(options.dictionary, result);
        }
        if (options.candidateLimit && attempts >= options.candidateLimit)
            break;
    }

    if (options.count != 0 && found < options.count)
    {
        stderr.writefln("search stopped after %s candidates with %s attractors", attempts, found);
        return 2;
    }
    return 0;
}

private int runCode(ref Options options)
{
    enforce(options.code.length > 0, "code mode needs a nonempty attractor code");
    auto decoded = decodeCodePrefix(options.code[0]);
    options.config.dimension = decoded.dimension;
    options.config.odeKind = decoded.odeKind;
    options.config.validate();
    auto engine = new Engine(options.config, options.seed);
    mkdirRecurse(options.output);
    auto data = openDataFile(options);
    File* dataPtr = data.isOpen ? &data : null;
    const ulong iterations = options.iterations == 0 ? options.config.maxIterations : options.iterations;
    auto result = engine.runCandidate(options.code, RunMode.code, iterations, dataPtr);
    if (data.isOpen)
        data.close();
    saveResult(engine, options, result, 1);
    return 0;
}

private string[] readDictionary(string path)
{
    if (!exists(path))
    {
        auto created = File(path, "a");
        created.close();
    }
    string[] lines;
    foreach (line; File(path, "r").byLineCopy())
    {
        auto value = line.chomp.strip;
        if (value.length)
            lines ~= value;
    }
    return lines;
}

private void rewriteDictionary(string path, const string[] remaining)
{
    const string temporary = path ~ ".tmp";
    auto file = File(temporary, "w");
    foreach (line; remaining)
        file.write(line, "\n");
    file.close();
    if (exists(path))
        remove(path);
    rename(temporary, path);
}

private ulong cycleIterations(ulong current)
{
    ulong next = 10 * (current - 1_000) + 1_000;
    if (next > 10_000_000_000UL)
        next = 2_000;
    return next;
}

private bool applyEvaluationViewCommand(ref Options options, char choice)
{
    switch (choice)
    {
        case 'c':
        case 'C':
            return true; // clear/re-render the current attractor
        case 'h':
        case 'H':
            options.config.fourthMode = cast(FourthDimensionMode)((cast(int)options.config.fourthMode + 1) % 3);
            return true;
        case 'n':
        case 'N':
            options.config.maxIterations = cycleIterations(options.config.maxIterations);
            return true;
        case 'p':
        case 'P':
            options.config.projection = cast(Projection)((cast(int)options.config.projection + 1) % 5);
            return true;
        case 'r':
        case 'R':
            options.config.thirdMode = cast(ThirdDimensionMode)((cast(int)options.config.thirdMode + 1) % 7);
            return true;
        case 's':
        case 'S':
            options.config.sound = !options.config.sound;
            return true;
        case 'v':
        case 'V':
            options.config.saveCoordinate = (options.config.saveCoordinate + 1) % 5;
            return true;
        default:
            return false;
    }
}

private int runEvaluate(ref Options options)
{
    auto entries = readDictionary(options.dictionary);
    mkdirRecurse(options.output);
    size_t processed = 0;
    size_t i = 0;

    while (i < entries.length)
    {
        const string fullLine = entries[i];
        enforce(fullLine.length > 0, "empty dictionary entry");
        auto decoded = decodeCodePrefix(fullLine[0]);
        const string code = normalizeCode(fullLine, true);

        bool advance = false;
        while (!advance)
        {
            auto local = options;
            local.config.dimension = decoded.dimension;
            local.config.odeKind = decoded.odeKind;
            local.config.validate();
            auto engine = new Engine(local.config, options.seed + i);
            const ulong iterations = options.iterations == 0 ? local.config.maxIterations : options.iterations;
            auto data = openDataFile(local);
            File* dataPtr = data.isOpen ? &data : null;
            auto result = engine.runCandidate(code, RunMode.evaluate, iterations, dataPtr);
            if (data.isOpen)
                data.close();
            saveResult(engine, local, result, i + 1);
            if (result.status == CandidateStatus.rejected)
            {
                // In PROG28 evaluation mode a divergent entry advances without
                // waiting for a favorite/discard command.
                advance = true;
                continue;
            }

            write("[Enter] favorite, [space] discard, [x] exit; c/h/n/p/r/s/v changes view: ");
            stdout.flush();
            string answer = readln();
            if (answer is null)
                answer = "x";
            const char choice = answer.length ? answer[0] : '\n';

            if (choice == '\n' || choice == '\r')
            {
                auto favorites = File(options.favorites, "a");
                // PROG28 saves the entire SA.DIC line, including F and L fields.
                favorites.write(fullLine, "\n");
                processed++;
                advance = true;
            }
            else if (choice == ' ')
            {
                processed++;
                advance = true;
            }
            else if (choice == 'x' || choice == 'X' || choice == 27)
            {
                rewriteDictionary(options.dictionary, entries[i .. $]);
                writeln(processed, " cases evaluated");
                return 0;
            }
            else if (applyEvaluationViewCommand(options, choice))
            {
                // PROG28 changes display state on the live trajectory.  The host
                // adapter deterministically re-renders the same code from its
                // initial condition with the new display setting.
            }
        }
        i++;
    }

    string[] empty;
    rewriteDictionary(options.dictionary, empty);
    writeln(processed, " cases evaluated");
    return 0;
}

int main(string[] args)
{
    try
    {
        auto options = parseOptions(args);
        switch (options.command)
        {
            case "search": return runSearch(options);
            case "code": return runCode(options);
            case "evaluate": return runEvaluate(options);
            default:
                usage();
                stderr.writeln("unknown command: ", options.command);
                return 2;
        }
    }
    catch (Exception error)
    {
        if (error.msg.length)
            stderr.writeln(error.msg);
        return error.msg.length ? 2 : 0;
    }
}
