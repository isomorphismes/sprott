module sprott_io;

import std.file : mkdirRecurse;
import std.path : buildPath;
import std.stdio : File;

import sprott_core;

void writeToneEvents(string path, const ToneEvent[] tones)
{
    auto file = File(path, "w");
    file.write("index\tfrequency_hz\tduration_basic_ticks\n");
    foreach (i, tone; tones)
        file.writef("%s\t%s\t%.17g\n", i, tone.frequency, tone.durationTicks);
}

void writeMetadata(string path, const CandidateResult result, const Config config)
{
    auto file = File(path, "w");
    file.writef("code=%s\n", result.code);
    file.writef("iterations=%s\n", result.iterations);
    file.writef("status=%s\n", cast(int)result.status);
    file.writef("lyapunov=%.17g\n", result.lyapunov);
    file.writef("fractal_dimension=%.17g\n", result.fractalDimension);
    file.writef("dimension=%s\n", decodeCodePrefix(result.code[0]).dimension);
    file.writef("ode_kind=%s\n", decodeCodePrefix(result.code[0]).odeKind);
    file.writef("projection=%s\n", cast(int)config.projection);
    file.writef("third_mode=%s\n", cast(int)config.thirdMode);
    file.writef("fourth_mode=%s\n", cast(int)config.fourthMode);
    foreach (i, coefficient; result.coefficients)
        file.writef("a[%s]=%.17g\n", i + 1, coefficient);
}

string outputStem(string directory, size_t index, string code)
{
    mkdirRecurse(directory);
    char[] safe = code.dup;
    foreach (ref c; safe)
        if (c < '!' || c > '~' || c == '/' || c == '\\')
            c = '_';
    if (safe.length > 48)
        safe.length = 48;
    import std.format : format;
    return buildPath(directory, format("sprott-%04d-%s", index, safe));
}
