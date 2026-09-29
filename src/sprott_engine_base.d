module sprott_engine_base;

import std.algorithm : min, max;
import std.exception : enforce;
import std.math : abs, cos, pow, sin;
import std.stdio : File;

import sprott_core;
import sprott_raster;

struct CandidateState
{
    Vec4 value;
    Vec4 next;
    Vec4 perturbed;
    double[] coefficients;
    string code;
    int dimension;
    int order;
    int odeKind;
    ulong n;
    ulong lyapunovSamples;
    double lyapunovSum;
    double lyapunov;
    ulong nearCount;
    ulong veryNearCount;
    double fractalDimension;
    double maxSquaredDiameter;
    Bounds bounds;
    double[][] history;
    size_t historyPosition;
    Window window;
    double specialSin;
    double specialCos;
    ToneEvent[] tones;
}

class EngineBase
{
    Config config;
    Prng rng;
    Raster raster;
    bool soundEnabled;
    protected double[100] shuffle;
    protected bool shuffleReady;
    protected double shuffledValue;
    protected ubyte[16] colors;
    protected ubyte white;
    protected ubyte black;
    protected ubyte red;
    protected ubyte cyan;

    this(Config config, ulong seed)
    {
        config.validate();
        this.config = config;
        rng = Prng(seed);
        raster = new Raster(config.width, config.height);
        soundEnabled = config.sound;
        setColors();
    }

    void setColors()
    {
        foreach (i; 0 .. 16)
            colors[i] = cast(ubyte)i;
        colors[0] = 0;
        colors[1] = 8;
        colors[2] = 7;
        colors[3] = 15;
        white = 15;
        black = 8;
        red = 12;
        cyan = 11;

        if (config.thirdMode == ThirdDimensionMode.colors ||
            (config.dimension > 3 && config.fourthMode == FourthDimensionMode.colors &&
             config.thirdMode != ThirdDimensionMode.shadow))
        {
            foreach (i; 0 .. 16)
                colors[i] = cast(ubyte)((i + 1) & 15);
        }
    }

    protected double shuffledRandom()
    {
        if (!shuffleReady)
        {
            foreach (ref value; shuffle)
                value = rng.unit();
            shuffleReady = true;
        }
        size_t j = cast(size_t)(100.0 * shuffledValue);
        if (j > 99)
            j = 99;
        shuffledValue = shuffle[j];
        shuffle[j] = rng.unit();
        return shuffledValue;
    }

    string randomCode(int dimension, int odeKind)
    {
        int order = 2;
        char prefix;
        size_t count;

        if (odeKind > 1)
        {
            prefix = cast(char)(87 + odeKind);
            count = specialCoefficientCount(odeKind);
        }
        else
        {
            order = 2 + cast(int)((config.maxOrder - 1) * rng.unit());
            prefix = cast(char)(59 + 4 * dimension + order + 8 * odeKind);
            count = polynomialCoefficientCount(dimension, order);
        }

        string code;
        code ~= prefix;
        foreach (_; 0 .. count)
            code ~= cast(char)(65 + cast(int)(25.0 * shuffledRandom()));
        return code;
    }

    protected CandidateState initializeCandidate(string requestedCode, bool randomize)
    {
        CandidateState s;
        s.value = Vec4(0.05, 0.05, 0.05, 0.05);
        s.perturbed = Vec4(0.050001, 0.05, 0.05, 0.05);

        if (randomize)
            s.code = randomCode(config.dimension, config.odeKind);
        else
            s.code = normalizeCode(requestedCode, true);

        auto decoded = decodeCodePrefix(s.code[0]);
        s.dimension = decoded.dimension;
        s.order = decoded.order;
        s.odeKind = decoded.odeKind;
        s.coefficients = coefficientsFromCode(s.code);

        s.bounds.low = Vec4(1_000_000.0, 1_000_000.0, 1_000_000.0, 1_000_000.0);
        s.bounds.high = Vec4(-1_000_000.0, -1_000_000.0, -1_000_000.0, -1_000_000.0);
        s.history = new double[][](4, config.historyLength);
        return s;
    }

    // PROG28 consumes coefficients depth-first through its nested I1..I5
    // loops.  That order differs from grouping every monomial by degree.
    protected double consumePolynomialBranch(ref size_t coefficientIndex,
                                           const double[] coefficients,
                                           const double[] variables,
                                           int depth, int start, int order,
                                           double product)
    {
        double sum = 0.0;
        foreach (j; start .. variables.length)
        {
            enforce(coefficientIndex < coefficients.length,
                    "coefficient code ended inside polynomial");
            const double nextProduct = product * variables[j];
            sum += coefficients[coefficientIndex++] * nextProduct;
            if (depth < order)
                sum += consumePolynomialBranch(coefficientIndex, coefficients, variables,
                                               depth + 1, cast(int)j, order, nextProduct);
        }
        return sum;
    }

    protected Vec4 polynomialStep(ref CandidateState s, Vec4 value)
    {
        double[4] varsStorage = [value.x, value.y, value.z, value.w];
        auto variables = varsStorage[0 .. cast(size_t)s.dimension];
        Vec4 result;
        size_t coefficientIndex = 0;

        foreach (output; 0 .. cast(size_t)s.dimension)
        {
            enforce(coefficientIndex < s.coefficients.length);
            double v = s.coefficients[coefficientIndex++];
            v += consumePolynomialBranch(coefficientIndex, s.coefficients, variables,
                                         1, 0, s.order, 1.0);
            result[output] = s.odeKind == 1
                ? value[output] + config.odeStep * v
                : v;
        }
        enforce(coefficientIndex == s.coefficients.length,
                "polynomial coefficient traversal did not consume the code exactly");
        return result;
    }

    protected Vec4 specialStep(ref CandidateState s, Vec4 value)
    {
        const auto a = s.coefficients;
        Vec4 r;
        r.z = value.x * value.x + value.y * value.y;
        r.w = s.n <= 1000
            ? (cast(double)s.n - 100.0) / 900.0
            : (cast(double)s.n - 1000.0) / (cast(double)config.maxIterations - 1000.0);

        switch (s.odeKind)
        {
            case 2:
                r.x = a[0] + a[1] * value.x + a[2] * value.y + a[3] * abs(value.x) + a[4] * abs(value.y);
                r.y = a[5] + a[6] * value.x + a[7] * value.y + a[8] * abs(value.x) + a[9] * abs(value.y);
                break;
            case 3:
            {
                const int x1 = cint16Basic(a[3] * value.x);
                const int y1 = cint16Basic(a[4] * value.y);
                const int x2 = cint16Basic(a[5] * value.x);
                const int y2 = cint16Basic(a[6] * value.y);
                const int x3 = cint16Basic(a[10] * value.x);
                const int y3 = cint16Basic(a[11] * value.y);
                const int x4 = cint16Basic(a[12] * value.x);
                const int y4 = cint16Basic(a[13] * value.y);
                r.x = a[0] + a[1] * value.x + a[2] * value.y + (x1 & y1) + (x2 | y2);
                r.y = a[7] + a[8] * value.x + a[9] * value.y + (x3 & y3) + (x4 | y4);
                break;
            }
            case 4:
                r.x = a[0] + a[1] * value.x + a[2] * value.y
                    + a[3] * pow(abs(value.x), a[4]) + a[5] * pow(abs(value.y), a[6]);
                r.y = a[7] + a[8] * value.x + a[9] * value.y
                    + a[10] * pow(abs(value.x), a[11]) + a[12] * pow(abs(value.y), a[13]);
                break;
            case 5:
                r.x = a[0] + a[1] * value.x + a[2] * value.y
                    + a[3] * sin(a[4] * value.x + a[5])
                    + a[6] * sin(a[7] * value.y + a[8]);
                r.y = a[9] + a[10] * value.x + a[11] * value.y
                    + a[12] * sin(a[13] * value.x + a[14])
                    + a[15] * sin(a[16] * value.y + a[17]);
                break;
            case 6:
            {
                if (s.n < 2)
                {
                    const double angle = TWO_PI / (13.0 + 10.0 * a[5]);
                    s.specialSin = sin(angle);
                    s.specialCos = cos(angle);
                }
                const double dum = value.x + a[1] * sin(a[2] * value.y + a[3]);
                r.x = 10.0 * a[0] + dum * s.specialCos + value.y * s.specialSin;
                r.y = 10.0 * a[4] - dum * s.specialSin + value.y * s.specialCos;
                break;
            }
            case 7:
                r.x = value.x + config.odeStep * a[0] * value.y;
                r.y = value.y + config.odeStep * (a[1] * value.x + a[2] * value.x * value.x * value.x
                    + a[3] * value.x * value.x * value.y + a[4] * value.x * value.y * value.y
                    + a[5] * value.y + a[6] * value.y * value.y * value.y + a[7] * sin(value.z));
                r.z = value.z + config.odeStep * (a[8] + 1.3);
                if (r.z > TWO_PI)
                    r.z -= TWO_PI;
                break;
            case 0:
            case 1:
                assert(false, "specialStep called for polynomial mode");
            default:
                assert(false, "special-system kind out of range");
        }
        return r;
    }

    Vec4 step(ref CandidateState s, Vec4 value)
    {
        return s.odeKind > 1 ? specialStep(s, value) : polynomialStep(s, value);
    }

    protected void updateBounds(ref CandidateState s)
    {
        foreach (i; 0 .. 4)
        {
            s.bounds.low[i] = min(s.bounds.low[i], s.value[i]);
            s.bounds.high[i] = max(s.bounds.high[i], s.value[i]);
        }
    }

    protected void expandDegenerate(ref double low, ref double high)
    {
        if (high - low < 0.000001)
        {
            low -= 0.0000005;
            high += 0.0000005;
        }
    }

}
