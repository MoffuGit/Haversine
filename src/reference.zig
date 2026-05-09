const std = @import("std");
const math = std.math;
const debug = std.debug;
const assert = debug.assert;

fn square(x: f64) f64 {
    return x * x;
}

pub fn referenceHaversine(
    x0: f64,
    y0: f64,
    x1: f64,
    y1: f64,
    earth: f64,
) f64 {
    assert(y0 <= 90.0);
    assert(y0 >= -90.0);

    assert(y1 <= 90.0);
    assert(y1 >= -90.0);

    assert(x0 <= 180.0);
    assert(x0 >= -180.0);

    assert(x1 <= 180.0);
    assert(x1 >= -180.0);

    const dY = math.degreesToRadians(y1 - y0);
    const dX = math.degreesToRadians(x1 - x0);
    const _y0 = math.degreesToRadians(y0);
    const _y1 = math.degreesToRadians(y1);

    const a = square(math.sin(dY / 2.0)) + math.cos(_y0) * math.cos(_y1) * square(math.sin(dX / 2.0));
    const c = 2.0 * math.asin(math.sqrt(a));

    return c * earth;
}

test "referenceHaversine test" {
    const testing = std.testing;

    const expected: f64 = 4449.0537028438;
    const result = referenceHaversine(70, 50, 180, 90, 6372.8);

    try testing.expectApproxEqAbs(expected, result, 0.0000000001);
}

// # ========================================================================
// # LISTING 21
// # ========================================================================
//
// from math import radians, sin, cos, sqrt, asin
// import time
// import json
//
// JSONFile = open('data_10000000_flex.json')
//
// #
// # Read the input
// #
//
// StartTime = time.time()
// JSONInput = json.load(JSONFile)
// MidTime = time.time()
//
// #
// # Average the haversines
// #
//
// def HaversineOfDegrees(X0, Y0, X1, Y1, R):
//
//   dY = radians(Y1 - Y0)
//   dX = radians(X1 - X0)
//   Y0 = radians(Y0)
//   Y1 = radians(Y1)
//
//   RootTerm = (sin(dY/2)**2) + cos(Y0)*cos(Y1)*(sin(dX/2)**2)
//   Result = 2*R*asin(sqrt(RootTerm))
//
//   return Result
//
// EarthRadiuskm = 6371
// Sum = 0
// Count = 0
// for Pair in JSONInput['pairs']:
//     Sum += HaversineOfDegrees(Pair['x0'], Pair['y0'], Pair['x1'], Pair['y1'], EarthRadiuskm)
//     Count += 1
// Average = Sum / Count
// EndTime = time.time()
//
// #
// # Display the result
// #
//
// print("Result: " + str(Average))
// print("Input = " + str(MidTime - StartTime) + " seconds")
// print("Math = " + str(EndTime - MidTime) + " seconds")
// print("Total = " + str(EndTime - StartTime) + " seconds")
// print("Throughput = " + str(Count/(EndTime - StartTime)) + " haversines/second")
