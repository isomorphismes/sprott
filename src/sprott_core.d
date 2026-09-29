module sprott_core;

import std.algorithm : min, max;
import std.exception : enforce;
import std.math : abs, cos, floor, log, pow, sin, sqrt;

enum double TWO_PI = 6.28318530717959;
enum double BASIC_PROJECTION_PI = 3.1416;

struct Prng
{
    private ulong state;

    this(ulong seed)
    {
        state = seed == 0 ? 0x9e3779b97f4a7c15UL : seed;
    }

    ulong nextU64()
    {
        state += 0x9e3779b97f4a7c15UL;
        ulong z = state;
        z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9UL;
        z = (z ^ (z >> 27)) * 0x94d049bb133111ebUL;
        return z ^ (z >> 31);
    }

    double unit()
    {
        return cast(double)(nextU64() >> 11) / 9007199254740992.0;
    }
}

enum Projection
{
    planar,
    sphere,
    horizontalCylinder,
    verticalCylinder,
    torus,
}

enum ThirdDimensionMode
{
    projection,
    shadow,
    bands,
    colors,
    anaglyph,
    stereogram,
    slices,
}

enum FourthDimensionMode
{
    projection,
    bands,
    colors,
}

enum RunMode
{
    search,
    code,
    evaluate,
}

enum CandidateStatus
{
    running,
    rejected,
    found,
}

struct Config
{
    size_t historyLength = 500;
    size_t previous = 5;
    ulong maxIterations = 11_000;
    int maxOrder = 5;
    int dimension = 2;
    double odeStep = 0.1;
    int odeKind = 0;
    Projection projection = Projection.planar;
    ThirdDimensionMode thirdMode = ThirdDimensionMode.shadow;
    FourthDimensionMode fourthMode = FourthDimensionMode.colors;
    bool sound = false;
    int saveCoordinate = 0;
    int width = 640;
    int height = 480;

    void validate() const
    {
        enforce(historyLength >= 20, "history length must be at least 20");
        enforce(previous < historyLength, "previous iterate must fit history");
        enforce(maxIterations >= 1_001, "max iterations must be at least 1001");
        enforce(maxOrder >= 2 && maxOrder <= 5, "polynomial order range is 2..5");
        enforce(dimension >= 1 && dimension <= 4, "dimension range is 1..4");
        enforce(odeKind >= 0 && odeKind <= 7, "ODE/special kind range is 0..7");
        enforce(saveCoordinate >= 0 && saveCoordinate <= 4, "saved coordinate range is 0..4");
        enforce(width >= 64 && height >= 64, "raster must be at least 64x64");
    }
}

struct Vec4
{
    double x;
    double y;
    double z;
    double w;

    double opIndex(size_t i) const
    {
        switch (i)
        {
            case 0: return x;
            case 1: return y;
            case 2: return z;
            case 3: return w;
            default: assert(false, "Vec4 index out of range");
        }
    }

    ref double opIndex(size_t i)
    {
        switch (i)
        {
            case 0: return x;
            case 1: return y;
            case 2: return z;
            case 3: return w;
            default: assert(false, "Vec4 index out of range");
        }
    }
}

struct Bounds
{
    Vec4 low;
    Vec4 high;
}

struct Window
{
    double xl;
    double xh;
    double yl;
    double yh;
    // QuickBASIC keeps the graphics WINDOW top at ymax + 1.5*margin,
    // then lowers the YH variable by 0.5*margin for clipping/annotation.
    double rasterYh;
    double xa;
    double ya;
    double za;
    double tt;
    double pt;
    double xz;
    double yz;
    bool ready;
}

struct ToneEvent
{
    long frequency;
    double durationTicks;
}

struct CandidateResult
{
    bool found;
    CandidateStatus status;
    string code;
    double[] coefficients;
    ulong iterations;
    double lyapunov;
    double fractalDimension;
    Window window;
    Vec4 finalValue;
    ToneEvent[] tones;
}

struct DecodedCode
{
    int dimension;
    int order;
    int odeKind;
    size_t coefficientCount;
}

private size_t choose(size_t n, size_t k)
{
    if (k > n)
        return 0;
    if (k > n - k)
        k = n - k;
    size_t result = 1;
    foreach (i; 1 .. k + 1)
        result = result * (n - k + i) / i;
    return result;
}

size_t polynomialCoefficientCount(int dimension, int order)
{
    enforce(dimension >= 1 && dimension <= 4);
    enforce(order >= 2 && order <= 5);
    return cast(size_t)dimension * choose(cast(size_t)(dimension + order), cast(size_t)order);
}

size_t specialCoefficientCount(int odeKind)
{
    switch (odeKind)
    {
        case 2: return 10;
        case 3: return 14;
        case 4: return 14;
        case 5: return 18;
        case 6: return 6;
        case 7: return 9;
        case 0: return 0;
        case 1: return 0;
        default: assert(false, "special-system kind out of range");
    }
}

DecodedCode decodeCodePrefix(char prefix)
{
    const int ascii = cast(ubyte)prefix;
    int encodedDimension = 1 + (ascii - 65) / 4;
    DecodedCode decoded;

    if (encodedDimension > 6)
    {
        decoded.odeKind = ascii - 87;
        decoded.dimension = 4;
        decoded.order = 2;
        enforce(decoded.odeKind >= 2 && decoded.odeKind <= 7, "invalid special-system code");
        decoded.coefficientCount = specialCoefficientCount(decoded.odeKind);
        return decoded;
    }

    if (encodedDimension > 4)
    {
        decoded.dimension = encodedDimension - 2;
        decoded.odeKind = 1;
    }
    else
    {
        decoded.dimension = encodedDimension;
        decoded.odeKind = 0;
    }

    decoded.order = 2 + ((ascii - 65) % 4);
    enforce(decoded.dimension >= 1 && decoded.dimension <= 4, "invalid dimension in code");
    enforce(decoded.order >= 2 && decoded.order <= 5, "invalid polynomial order in code");
    decoded.coefficientCount = polynomialCoefficientCount(decoded.dimension, decoded.order);
    return decoded;
}

string normalizeCode(string code, bool repairLength)
{
    enforce(code.length >= 1, "empty attractor code");
    auto decoded = decodeCodePrefix(code[0]);
    const size_t needed = decoded.coefficientCount + 1;
    if (!repairLength)
    {
        enforce(code.length >= needed, "attractor code is shorter than its coefficient count");
        return code[0 .. needed].dup;
    }

    auto result = code.dup;
    while (result.length < needed)
        result ~= 'M';
    if (result.length > needed)
        result.length = needed;
    return result.idup;
}

double[] coefficientsFromCode(string code)
{
    auto normalized = normalizeCode(code, true);
    auto decoded = decodeCodePrefix(normalized[0]);
    auto coefficients = new double[decoded.coefficientCount];
    foreach (i; 0 .. coefficients.length)
        coefficients[i] = (cast(int)cast(ubyte)normalized[i + 1] - 77) / 10.0;
    return coefficients;
}

int roundPixel(double x)
{
    if (x >= 0)
        return cast(int)floor(x + 0.5);
    return -cast(int)floor(-x + 0.5);
}

// QuickBASIC CINT rounds halves to the nearest even integer.
int cintBasic(double x)
{
    const double lower = floor(x);
    const double fraction = x - lower;
    long rounded;
    if (fraction < 0.5)
        rounded = cast(long)lower;
    else if (fraction > 0.5)
        rounded = cast(long)lower + 1;
    else
    {
        const long low = cast(long)lower;
        rounded = (low & 1L) == 0 ? low : low + 1;
    }
    enforce(rounded >= int.min && rounded <= int.max, "CINT overflow");
    return cast(int)rounded;
}

short cint16Basic(double x)
{
    const int rounded = cintBasic(x);
    enforce(rounded >= short.min && rounded <= short.max, "QuickBASIC INTEGER overflow");
    return cast(short)rounded;
}

double safeRange(double low, double high)
{
    const double r = high - low;
    return abs(r) < 1e-12 ? 1e-12 : r;
}
