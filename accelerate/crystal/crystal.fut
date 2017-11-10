-- The first data set is equal to the Accelerate default.
--
-- ==
-- tags { futhark-c futhark-opencl }
-- input {
--   200
--   30.0f32
--   5
--   1
--   1.0f32
-- }
--
-- compiled input {
--   20
--   30.0f32
--   5
--   50
--   0.5f32
-- }
--
-- compiled input {
--   40
--   30.0f32
--   5
--   50
--   0.5f32
-- }
--
-- compiled input {
--   40
--   30.0f32
--   50
--   50
--   0.5f32
-- }
--
-- input {
--   2000
--   30.0f32
--   50
--   1
--   1.0f32
-- }
--
-- input {
--   4000
--   30.0f32
--   50
--   1
--   1.0f32
-- }

import "/futlib/math"

default (f32)

let pi(): f32 = 3.14159265358979323846264338327950288419716939937510

let odd(n: i32): bool = (n & 1) == 1

let point(scale: f32, x: f32, y: f32): (f32, f32) =
  (x * scale, y * scale)

let rampColour(v: f32): (f32, f32, f32) =
  (1.0, 0.4 + (v * 0.6), v) -- rgb

let intPixel(t: f32): u32 =
  u32.f32(255.0 * t)

let intColour((r,g,b): (f32, f32, f32)): u32 =
  intPixel(r) << 16u32 | intPixel(g) << 8u32 | intPixel(b)

let wrap(n: f32): f32 =
  let n' = n - f32(i32(n))
  let odd_in_int = i32(n) & 1
  let even_in_int = 1 - odd_in_int
  in f32(odd_in_int) * (1.0 - n') + f32(even_in_int) * n'

let wave(th: f32, x: f32, y: f32): f32 =
  let cth = f32.cos(th)
  let sth = f32.sin(th)
  in (f32.cos(cth * x + sth * y) + 1.0) / 2.0

let waver(th: f32, x: f32, y: f32, n: i32): f32 =
  reduce (+) (0.0) (map (\i  -> wave(f32(i) * th, x, y)) (iota n))

let waves(degree: i32, phi: f32, x: f32, y: f32): f32 =
  let th = pi() / phi
  in wrap(waver(th, x, y, degree))

let quasicrystal(scale: f32, degree: i32, time: f32, x: f32, y: f32): u32 =
  let phi = 1.0 + (time ** 1.5) * 0.005
  let (x', y') = point(scale, x, y)
  in intColour(rampColour(waves(degree, phi, x', y')))

let normalize_index(i: i32, field_size: i32): f32 =
  f32(i) / f32(field_size)

entry render_frame(field_size: i32, scale: f32, degree: i32, time: f32)
                  : [field_size][field_size]u32 =
  let ks = iota(field_size)
  in map (\(y: i32): [field_size]u32  ->
            map (\(x: i32): u32  ->
                   quasicrystal(scale, degree, time,
                                normalize_index(x, field_size),
                                normalize_index(y, field_size)))
                ks)
         ks

let main(field_size: i32, scale: f32, degree: i32,
         n_steps: i32, time_delta: f32): [n_steps][field_size][field_size]u32 =
  map (\step_i: [field_size][field_size]u32  ->
         let time = f32(step_i) * time_delta
         in render_frame(field_size, scale, degree, time))
  (iota(n_steps))
