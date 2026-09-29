module sprott_engine;

import std.math : abs, cos, floor, log, pow, sin, sqrt;
import std.stdio : File;

import sprott_core;
import sprott_raster;
import sprott_engine_base;

final class Engine : EngineBase
{
    this(Config config, ulong seed)
    {
        super(config, seed);
    }

    private void plotBackgroundGrid(ref CandidateState s)
    {
        foreach (i; 0 .. 16)
        {
            const double x = s.bounds.low.x + i * (s.bounds.high.x - s.bounds.low.x) / 15.0;
            raster.line(x, s.bounds.low.y, x, s.bounds.high.y, 0);
        }
        foreach (i; 0 .. 11)
        {
            const double y = s.bounds.low.y + i * (s.bounds.high.y - s.bounds.low.y) / 10.0;
            raster.line(s.bounds.low.x, y, s.bounds.high.x, y, 0);
        }
    }

    private void resize(ref CandidateState s)
    {
        if (s.dimension == 1)
        {
            s.bounds.low.y = s.bounds.low.x;
            s.bounds.high.y = s.bounds.high.x;
        }
        foreach (i; 0 .. 4)
            expandDegenerate(s.bounds.low[i], s.bounds.high[i]);

        const double mx = 0.1 * (s.bounds.high.x - s.bounds.low.x);
        const double my = 0.1 * (s.bounds.high.y - s.bounds.low.y);
        s.window.xl = s.bounds.low.x - mx;
        s.window.xh = s.bounds.high.x + mx;
        s.window.yl = s.bounds.low.y - my;
        s.window.rasterYh = s.bounds.high.y + 1.5 * my;
        s.window.yh = s.window.rasterYh - 0.5 * my;
        s.window.xa = (s.window.xl + s.window.xh) / 2.0;
        s.window.ya = (s.window.yl + s.window.yh) / 2.0;
        s.window.za = (s.bounds.high.z + s.bounds.low.z) / 2.0;
        s.window.tt = BASIC_PROJECTION_PI / safeRange(s.bounds.low.x, s.bounds.high.x);
        s.window.pt = BASIC_PROJECTION_PI / safeRange(s.bounds.low.y, s.bounds.high.y);
        const double illumination = 0.05;
        s.window.xz = -illumination * safeRange(s.bounds.low.x, s.bounds.high.x)
            / safeRange(s.bounds.low.z, s.bounds.high.z);
        s.window.yz = illumination * safeRange(s.bounds.low.y, s.bounds.high.y)
            / safeRange(s.bounds.low.z, s.bounds.high.z);
        s.window.ready = true;

        raster.setWindow(s.window);
        raster.clear(0);
        if (s.dimension >= 3 && config.thirdMode == ThirdDimensionMode.shadow)
        {
            raster.fillWindow(colors[1]);
            plotBackgroundGrid(s);
        }
        if (s.dimension >= 3 && config.thirdMode == ThirdDimensionMode.anaglyph)
            raster.fillWindow(white);
        if (s.dimension >= 3 && config.thirdMode == ThirdDimensionMode.stereogram)
            raster.line(s.window.xa, s.window.yl, s.window.xa, s.window.yh, 15);
        if (s.dimension >= 3 && config.thirdMode == ThirdDimensionMode.slices)
        {
            foreach (i; 1 .. 4)
            {
                const double x = s.window.xl + i * (s.window.xh - s.window.xl) / 4.0;
                const double y = s.window.yl + i * (s.window.yh - s.window.yl) / 4.0;
                raster.line(x, s.window.yl, x, s.window.yh, 15);
                raster.line(s.window.xl, y, s.window.xh, y, 15);
            }
        }

        if (config.projection != Projection.sphere)
            raster.rectangle(s.window.xl, s.window.yl, s.window.xh, s.window.yh, 15);
        else if (config.thirdMode < ThirdDimensionMode.stereogram)
            raster.circle(s.window.xa, s.window.ya, 0.36 * (s.window.xh - s.window.xl), 15);
    }

    private void project(ref CandidateState s, ref double xp, ref double yp)
    {
        final switch (config.projection)
        {
            case Projection.planar:
                break;
            case Projection.sphere:
            {
                const double th = s.window.tt * (s.bounds.high.x - xp);
                const double ph = s.window.pt * (s.bounds.high.y - yp);
                xp = s.window.xa + 0.36 * (s.window.xh - s.window.xl) * cos(th) * sin(ph);
                yp = s.window.ya + 0.5 * (s.window.yh - s.window.yl) * cos(ph);
                break;
            }
            case Projection.horizontalCylinder:
            {
                const double ph = s.window.pt * (s.bounds.high.y - yp);
                yp = s.window.ya + 0.5 * (s.window.yh - s.window.yl) * cos(ph);
                break;
            }
            case Projection.verticalCylinder:
            {
                const double th = s.window.tt * (s.bounds.high.x - xp);
                xp = s.window.xa + 0.5 * (s.window.xh - s.window.xl) * cos(th);
                break;
            }
            case Projection.torus:
            {
                const double th = s.window.tt * (s.bounds.high.x - xp);
                const double ph = 2.0 * s.window.pt * (s.bounds.high.y - yp);
                xp = s.window.xa + 0.18 * (s.window.xh - s.window.xl) * (1.0 + cos(th)) * sin(ph);
                yp = s.window.ya + 0.25 * (s.window.yh - s.window.yl) * (1.0 + cos(th)) * cos(ph);
                break;
            }
        }
    }

    private int colorBucket(double value, double low, double high, int scale, int offset, int modulo)
    {
        return (cast(int)(scale * (value - low) / safeRange(low, high) + offset) % modulo + modulo) % modulo;
    }

    private void plotPoint(ref CandidateState s, double xp, double yp)
    {
        ubyte c4 = white;
        if (s.dimension >= 4)
        {
            if (config.fourthMode == FourthDimensionMode.bands)
            {
                if ((cast(int)(30.0 * (s.value.w - s.bounds.low.w)
                    / safeRange(s.bounds.low.w, s.bounds.high.w)) & 1) != 0)
                    return;
            }
            else if (config.fourthMode == FourthDimensionMode.colors)
            {
                const int bucket = colorBucket(s.value.w, s.bounds.low.w, s.bounds.high.w, 15, 15, 15);
                c4 = cast(ubyte)(1 + bucket);
            }
        }

        if (s.dimension < 3)
        {
            raster.pset(xp, yp, 15);
            return;
        }

        final switch (config.thirdMode)
        {
            case ThirdDimensionMode.projection:
                raster.pset(xp, yp, c4);
                break;
            case ThirdDimensionMode.shadow:
            {
                if (s.dimension > 3 && config.fourthMode == FourthDimensionMode.colors)
                    raster.pset(xp, yp, c4);
                else
                {
                    const int current = raster.point(xp, yp);
                    if (current == colors[2])
                        raster.pset(xp, yp, colors[3]);
                    else if (current != colors[3])
                        raster.pset(xp, yp, colors[2]);
                }
                xp -= s.window.xz * (s.value.z - s.bounds.low.z);
                yp -= s.window.yz * (s.value.z - s.bounds.low.z);
                if (raster.point(xp, yp) == colors[1])
                    raster.pset(xp, yp, 0);
                break;
            }
            case ThirdDimensionMode.bands:
            {
                if (s.dimension > 3 && config.fourthMode == FourthDimensionMode.colors)
                {
                    const int band = cast(int)(15.0 * (s.value.z - s.bounds.low.z)
                        / safeRange(s.bounds.low.z, s.bounds.high.z) + 2.0) % 2;
                    if (band == 1)
                        raster.pset(xp, yp, c4);
                }
                else
                {
                    const int bucket = colorBucket(s.value.z, s.bounds.low.z, s.bounds.high.z, 60, 4, 4);
                    raster.pset(xp, yp, colors[bucket]);
                }
                break;
            }
            case ThirdDimensionMode.colors:
            {
                const int bucket = colorBucket(s.value.z, s.bounds.low.z, s.bounds.high.z, 15, 15, 15);
                raster.pset(xp, yp, colors[bucket]);
                break;
            }
            case ThirdDimensionMode.anaglyph:
            {
                const double xrt = xp + s.window.xz * (s.value.z - s.window.za);
                const int cr = raster.point(xrt, yp);
                if (cr == white)
                    raster.pset(xrt, yp, red);
                if (cr == cyan)
                    raster.pset(xrt, yp, black);
                const double xlt = xp - s.window.xz * (s.value.z - s.window.za);
                const int cl = raster.point(xlt, yp);
                if (cl == white)
                    raster.pset(xlt, yp, cyan);
                if (cl == red)
                    raster.pset(xlt, yp, black);
                break;
            }
            case ThirdDimensionMode.stereogram:
            {
                const double hsf = 2.0;
                const double right = s.window.xa + (xp + s.window.xz * (s.value.z - s.window.za) - s.window.xl) / hsf;
                const double left = s.window.xa + (xp - s.window.xz * (s.value.z - s.window.za) - s.window.xh) / hsf;
                raster.pset(right, yp, c4);
                raster.pset(left, yp, c4);
                break;
            }
            case ThirdDimensionMode.slices:
            {
                const double dz = (15.0 * (s.value.z - s.bounds.low.z)
                    / safeRange(s.bounds.low.z, s.bounds.high.z) + 0.5) / 16.0;
                xp = (xp - s.window.xl + (cast(int)(16 * dz) % 4) * (s.window.xh - s.window.xl)) / 4.0 + s.window.xl;
                yp = (yp - s.window.yl + (3 - cast(int)(4 * dz) % 4) * (s.window.yh - s.window.yl)) / 4.0 + s.window.yl;
                raster.pset(xp, yp, c4);
                break;
            }
        }
    }

    private ToneEvent makeTone(ref CandidateState s)
    {
        ToneEvent tone;
        const double ratio = 36.0 * (s.next.x - s.window.xl) / safeRange(s.window.xl, s.window.xh);
        tone.frequency = cintBasic(220.0 * pow(2.0, cintBasic(ratio) / 12.0));
        tone.durationTicks = 1.0;
        if (s.dimension > 1)
        {
            const double denominator = s.next.y - 9.0 * s.window.yl / 8.0 + s.window.yh / 8.0;
            if (abs(denominator) > 1e-12)
                tone.durationTicks = pow(2.0, floor(0.5 * (s.window.yh - s.window.yl) / denominator));
        }
        return tone;
    }

    private void display(ref CandidateState s)
    {
        if (s.n >= 100 && s.n <= 1000)
            updateBounds(s);
        if (s.n == 1000)
            resize(s);

        foreach (i; 0 .. 4)
            s.history[i][s.historyPosition] = s.value[i];
        s.historyPosition = (s.historyPosition + 1) % config.historyLength;
        const size_t previousIndex = (s.historyPosition + config.historyLength - config.previous) % config.historyLength;

        double xp = s.dimension == 1 ? s.history[0][previousIndex] : s.value.x;
        double yp = s.dimension == 1 ? s.next.x : s.value.y;
        if (s.n < 1000 || !s.window.ready || xp <= s.window.xl || xp >= s.window.xh || yp <= s.window.yl || yp >= s.window.yh)
            return;

        project(s, xp, yp);
        plotPoint(s, xp, yp);
        if (soundEnabled)
            s.tones ~= makeTone(s);
    }

    private void updateLyapunov(ref CandidateState s)
    {
        // The BASIC routine decrements N before reiterating the perturbed
        // trajectory, then its iteration routine increments N back.  Preserve
        // that detail because the special systems use N in their W coordinate.
        assert(s.n > 0);
        s.n--;
        Vec4 perturbedNext = step(s, s.perturbed);
        s.n++;
        Vec4 delta;
        double squared = 0.0;
        foreach (i; 0 .. 4)
        {
            delta[i] = perturbedNext[i] - s.next[i];
            squared += delta[i] * delta[i];
        }
        if (!(squared > 0.0))
            return;

        const double df = 1_000_000_000_000.0 * squared;
        const double rescale = 1.0 / sqrt(df);
        foreach (i; 0 .. 4)
            s.perturbed[i] = s.next[i] + rescale * delta[i];
        s.lyapunovSum += log(df);
        s.lyapunovSamples++;
        s.lyapunov = 0.721347 * s.lyapunovSum / s.lyapunovSamples;
        if (s.odeKind == 1 || s.odeKind == 7)
            s.lyapunov /= config.odeStep;
    }

    private void updateFractalDimension(ref CandidateState s)
    {
        if (s.n < 1000)
            return;
        if (s.n == 1000)
        {
            s.maxSquaredDiameter = 0.0;
            foreach (i; 0 .. 4)
            {
                const double span = s.bounds.high[i] - s.bounds.low[i];
                s.maxSquaredDiameter += span * span;
            }
        }

        const size_t j = (s.historyPosition + 1 + cast(size_t)(480.0 * rng.unit())) % config.historyLength;
        double d2 = 0.0;
        foreach (i; 0 .. 4)
        {
            const double d = s.next[i] - s.history[i][j];
            d2 += d * d;
        }
        const double scale = cast(double)(1UL << s.dimension) * s.maxSquaredDiameter;
        if (d2 < 0.001 * scale)
            s.nearCount++;
        if (d2 > 0.00001 * scale)
            return;
        s.veryNearCount++;
        const double ratio = s.nearCount / (cast(double)s.veryNearCount - 0.5);
        if (ratio > 0.0)
            s.fractalDimension = 0.434294 * log(ratio);
    }

    private CandidateStatus test(ref CandidateState s, RunMode mode)
    {
        const double magnitude = abs(s.next.x) + abs(s.next.y) + abs(s.next.z) + abs(s.next.w);
        const bool divergent = !(magnitude <= 1_000_000.0);

        // Evaluation mode jumps around the expensive L/F calculations in
        // PROG28, but a divergence flag still ends the current entry.
        if (mode == RunMode.evaluate)
            return divergent ? CandidateStatus.rejected : CandidateStatus.running;

        // In search/input modes PROG28 performs these calculations even after
        // setting its divergence flag.  Fractal estimation consumes RND, so
        // preserving the order also preserves the random-stream structure.
        updateLyapunov(s);
        updateFractalDimension(s);

        if (mode == RunMode.search)
        {
            // PROG28 saves when N reaches NMAX before applying its fixed-point
            // and Lyapunov rejections on that same iteration.
            if (s.n >= config.maxIterations)
                return CandidateStatus.found;
            if (divergent)
                return CandidateStatus.rejected;
            const double change = abs(s.next.x - s.value.x) + abs(s.next.y - s.value.y)
                + abs(s.next.z - s.value.z) + abs(s.next.w - s.value.w);
            if (change < 0.000001)
                return CandidateStatus.rejected;
            if (s.n > 100 && s.lyapunov < 0.005)
                return CandidateStatus.rejected;
        }
        else if (divergent)
            return CandidateStatus.rejected;

        return CandidateStatus.running;
    }

    CandidateResult runCandidate(string code, RunMode mode, ulong finiteIterations = 0,
                                 File* dataFile = null)
    {
        const bool randomize = mode == RunMode.search;
        auto s = initializeCandidate(code, randomize);
        const ulong stopAt = finiteIterations == 0 ? config.maxIterations : finiteIterations;
        CandidateStatus status = CandidateStatus.running;

        while (status == CandidateStatus.running)
        {
            s.next = step(s, s.value);
            s.n++;
            display(s);
            status = test(s, mode);

            if (dataFile !is null && config.saveCoordinate > 0 && s.n > 1000 && s.n < 17_001)
            {
                const double value = s.next[cast(size_t)(config.saveCoordinate - 1)];
                (*dataFile).writef("%.9g\n", cast(float)value);
            }

            s.value = s.next;
            if (mode != RunMode.search && s.n >= stopAt)
                break;
        }

        CandidateResult result;
        result.found = status == CandidateStatus.found ||
            (mode != RunMode.search && status != CandidateStatus.rejected);
        result.status = status;
        result.code = s.code;
        result.coefficients = s.coefficients.dup;
        result.iterations = s.n;
        result.lyapunov = s.lyapunov;
        result.fractalDimension = s.fractalDimension;
        result.window = s.window;
        result.finalValue = s.value;
        result.tones = s.tones.dup;
        return result;
    }
}
