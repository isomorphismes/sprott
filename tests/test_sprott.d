module test_sprott;

import std.math : abs;
import std.stdio : writeln;

import sprott;

private void check(bool condition, string message)
{
    if (!condition)
        throw new Exception(message);
}

int main()
{
    check(polynomialCoefficientCount(1, 2) == 3, "1-D quadratic coefficient count");
    check(polynomialCoefficientCount(2, 2) == 12, "2-D quadratic coefficient count");
    check(polynomialCoefficientCount(4, 5) == 504, "4-D quintic coefficient count");

    auto map2 = decodeCodePrefix('E');
    check(map2.dimension == 2 && map2.order == 2 && map2.odeKind == 0, "E prefix");
    auto ode3 = decodeCodePrefix('Q');
    check(ode3.dimension == 3 && ode3.order == 2 && ode3.odeKind == 1, "Q prefix");
    auto special2 = decodeCodePrefix('Y');
    check(special2.dimension == 4 && special2.odeKind == 2 && special2.coefficientCount == 10, "Y prefix");
    auto special7 = decodeCodePrefix('^');
    check(special7.dimension == 4 && special7.odeKind == 7 && special7.coefficientCount == 9, "^ prefix");

    // PROG28 consumes cubic coefficients depth-first through I1/I2/I3.
    // For a 2-D cubic, coefficient 4 (zero-based 3) is x^3, not x^2.
    string cubic = "FMMMW";
    while (cubic.length < 21)
        cubic ~= 'M';
    auto orderEngine = new Engine(Config(), 1);
    auto orderResult = orderEngine.runCandidate(cubic, RunMode.code, 1, null);
    check(abs(orderResult.finalValue.x - 0.000125) < 1e-15,
          "PROG28 depth-first polynomial coefficient order");

    const string zero2 = normalizeCode("E", true);
    check(zero2.length == 13, "repair 2-D quadratic code length");
    auto zeroCoefficients = coefficientsFromCode(zero2);
    foreach (coefficient; zeroCoefficients)
        check(abs(coefficient) < 1e-15, "M must decode to zero");

    Config config;
    config.maxIterations = 1_001;
    auto engine = new Engine(config, 12345);
    auto result = engine.runCandidate(zero2, RunMode.code, 1_001, null);
    check(result.iterations == 1_001, "finite code run length");
    check(result.window.ready, "display window after transient");
    check(result.window.rasterYh > result.window.yh,
          "QuickBASIC graphics-window top margin is preserved separately");
    check(result.code == zero2, "code round-trip");

    const string specialZero = normalizeCode("Y", true);
    auto specialEngine = new Engine(config, 67890);
    auto specialResult = specialEngine.runCandidate(specialZero, RunMode.code, 1_001, null);
    check(specialResult.iterations == 1_001, "special map finite run");

    Config randomConfig;
    randomConfig.dimension = 4;
    randomConfig.odeKind = 0;
    auto randomEngine = new Engine(randomConfig, 42);
    foreach (_; 0 .. 64)
    {
        const string code = randomEngine.randomCode(4, 0);
        auto decoded = decodeCodePrefix(code[0]);
        check(code.length == decoded.coefficientCount + 1, "random polynomial code length");
    }

    Config specialConfig;
    specialConfig.odeKind = 5;
    specialConfig.dimension = 4;
    auto specialRandom = new Engine(specialConfig, 42);
    const string specialCode = specialRandom.randomCode(4, 5);
    check(specialCode[0] == '\\', "special function 5 prefix");
    check(specialCode.length == 19, "special function 5 coefficient count");

    writeln("sprott D tests: ok");
    return 0;
}
