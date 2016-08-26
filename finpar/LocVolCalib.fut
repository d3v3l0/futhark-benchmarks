-- LocVolCalib
-- ==
-- compiled input @ LocVolCalib-data/small.in
-- output @ LocVolCalib-data/small.out
--
-- notravis input @ LocVolCalib-data/medium.in
-- output @ LocVolCalib-data/medium.out
--
-- notravis input @ LocVolCalib-data/large.in
-- output @ LocVolCalib-data/large.out

default(f32)

fun initGrid(s0: f32, alpha: f32, nu: f32, t: f32, numX: int, numY: int, numT: int): (int,int,[numX]f32,[numY]f32,[numT]f32) =
    let logAlpha = log32(alpha) in
    let myTimeline = map(fn (i: int): f32  => t * f32(i) / (f32(numT) - 1.0), iota(numT)) in
    let (stdX, stdY) = (20.0 * alpha * s0 * sqrt32(t),
                        10.0 * nu         * sqrt32(t)) in
    let (dx, dy) = (stdX / f32(numX), stdY / f32(numY)) in
    let (myXindex, myYindex) = (int(s0 / dx), numY / 2) in
    let myX = map(fn (i: int): f32  => f32(i) * dx - f32(myXindex) * dx + s0,       iota(numX)) in
    let myY = map(fn (i: int): f32  => f32(i) * dy - f32(myYindex) * dy + logAlpha, iota(numY)) in
    (myXindex, myYindex, myX, myY, myTimeline)

-- make the innermost dimension of the result of size 4 instead of 3?
fun initOperator(x: [n]f32): ([n][]f32,[n][]f32) =
    let dxu    = x[1] - x[0] in
    let dxl    = 0.0         in
    let dx_low  = [[0.0, -1.0 / dxu, 1.0 / dxu]] in
    let dxx_low = [[0.0, 0.0, 0.0]]              in
    let dx_mids = map(fn (i: int): ([]f32,[]f32)  =>
                       let dxl = x[i] - x[i-1]  in
                       let dxu = x[i+1] - x[i]  in
                       ( [ -dxu/dxl/(dxl+dxu), (dxu/dxl - dxl/dxu)/(dxl+dxu),      dxl/dxu/(dxl+dxu) ],
                         [  2.0/dxl/(dxl+dxu), -2.0*(1.0/dxl + 1.0/dxu)/(dxl+dxu), 2.0/dxu/(dxl+dxu) ] )
                   , map (+ (1), iota(n-2))) in
    let (dx_mid, dxx_mid) = unzip(dx_mids)         in
    let dxl    = x[n-1] - x[n-2] in
    let dxu    = 0.0 in
    let dx_high = [[-1.0 / dxl, 1.0 / dxl, 0.0 ]] in
    let dxx_high= [[0.0, 0.0, 0.0 ]] in
    let dx     = concat(concat(dx_low, dx_mid), dx_high) in
    let dxx    = concat(concat(dxx_low, dxx_mid), dxx_high)
    in  (dx, dxx)

fun max(x: f32, y: f32): f32 = if y < x then x else y
fun maxInt(x: int, y: int): int = if y < x then x else y

fun setPayoff(strike: f32, myX: [numX]f32, myY: [numY]f32): *[numY][numX]f32 =
  replicate(numY, map(fn (xi: f32): f32  => max(xi-strike,0.0), myX) )
--  let myres = map(fn []f32 (f32 xi) => replicate(numY, max(xi-strike,0.0)), myX) in
--  transpose(myres)

-- Returns new myMuX, myVarX, myMuY, myVarY.
fun updateParams(myX:  [numX]f32, myY: [numY]f32, myTimeline: []f32,
              g: int, alpha: f32, beta: f32, nu: f32    ): ([][]f32 , [][]f32 , [][]f32 , [][]f32) =
  let myMuY  = replicate(numX, replicate(numY, 0.0  )) in
  let myVarY = replicate(numX, replicate(numY, nu*nu)) in
  let myMuX  = replicate(numY, replicate(numX, 0.0  )) in
  let myVarX = map( fn (yj: f32): []f32  =>
                      map ( fn (xi: f32): f32  =>
                              exp32(2.0*(beta*log32(xi) + yj - 0.5*nu*nu*myTimeline[g]))
                          , myX )
                  , myY )
  in  ( myMuX, myVarX, myMuY, myVarY )

fun tridagSeq(a:  [n]f32, b: *[n]f32, c: [n]f32, y: *[n]f32 ): *[]f32 =
    loop ((y, b)) =
      for 1 <= i < n do
        let beta = a[i] / b[i-1]      in
        let b[i] = b[i] - beta*c[i-1] in
        let y[i] = y[i] - beta*y[i-1]
        in  (y, b)
    in
    let y[n-1] = y[n-1]/b[n-1] in
    loop (y) = for n-1 > i >= 0 do
                 let y[i] = (y[i] - c[i]*y[i+1]) / b[i]
                 in  y
    in  y

fun tridagPar(a:  [n]f32, b: *[]f32, c: []f32, y: *[]f32 ): *[]f32 =
    unsafe
    ----------------------------------------------------
    -- Recurrence 1: b[i] = b[i] - a[i]*c[i-1]/b[i-1] --
    --   solved by scan with 2x2 matrix mult operator --
    ----------------------------------------------------
    let b0   = b[0] in
    let mats = map ( fn (i: int): (f32,f32,f32,f32)  =>
                         if 0 < i
                         then (b[i], 0.0-a[i]*c[i-1], 1.0, 0.0)
                         else (1.0,  0.0,             0.0, 1.0)
                   , iota(n) ) in
    let scmt = scan( fn (a:  (f32,f32,f32,f32),
                                                b: (f32,f32,f32,f32) ): (f32,f32,f32,f32)  =>
                         let (a0,a1,a2,a3) = a   in
                         let (b0,b1,b2,b3) = b   in
                         let value = 1.0/(a0*b0)   in
                         ( (b0*a0 + b1*a2)*value,
                           (b0*a1 + b1*a3)*value,
                           (b2*a0 + b3*a2)*value,
                           (b2*a1 + b3*a3)*value
                         )
                   , (1.0,  0.0, 0.0, 1.0), mats ) in
    let b    = map ( fn (tup: (f32,f32,f32,f32)): f32  =>
                         let (t0,t1,t2,t3) = tup in
                         (t0*b0 + t1) / (t2*b0 + t3)
                   , scmt ) in
    ------------------------------------------------------
    -- Recurrence 2: y[i] = y[i] - (a[i]/b[i-1])*y[i-1] --
    --   solved by scan with linear func comp operator  --
    ------------------------------------------------------
    let y0   = y[0] in
    let lfuns= map ( fn (i: int): (f32,f32)  =>
                         if 0 < i
                         then (y[i], 0.0-a[i]/b[i-1])
                         else (0.0,  1.0            )
                   , iota(n) ) in
    let cfuns= scan( fn (a: (f32,f32), b: (f32,f32)): (f32,f32)  =>
                         let (a0,a1) = a in
                         let (b0,b1) = b in
                         ( b0 + b1*a0, a1*b1 )
                   , (0.0, 1.0), lfuns ) in
    let y    = map ( fn (tup: (f32,f32)): f32  =>
                         let (a,b) = tup in
                         a + b*y0
                   , cfuns ) in
    ------------------------------------------------------
    -- Recurrence 3: backward recurrence solved via     --
    --             scan with linear func comp operator  --
    ------------------------------------------------------
    let yn   = y[n-1]/b[n-1] in
    let lfuns= map ( fn (k: int): (f32,f32)  =>
                         let i = n-k-1
                         in  if   0 < k
                             then (y[i]/b[i], 0.0-c[i]/b[i])
                             else (0.0,       1.0          )
                   , iota(n) ) in
    let cfuns= scan( fn (a: (f32,f32), b: (f32,f32)): (f32,f32)  =>
                         let (a0,a1) = a in
                         let (b0,b1) = b in
                         (b0 + b1*a0, a1*b1)
                   , (0.0, 1.0), lfuns ) in
    let y    = map ( fn (tup: (f32,f32)): f32  =>
                         let (a,b) = tup in
                         a + b*yn
                   , cfuns ) in
    let y    = map (fn (i: int): f32  => y[n-i-1], iota(n)) in
    y

------------------------------------------/
-- myD,myDD          : [m][3]f32
-- myMu,myVar,result : [n][m]f32
-- RETURN            : [n][m]f32
------------------------------------------/
fun explicitMethod(myD:  [m][3]f32,  myDD: [m][3]f32,
                                  myMu: [n][m]f32, myVar: [n][m]f32,
                                  result: [n][m]f32 ): *[n][m]f32 =
  -- 0 <= i < m AND 0 <= j < n
  map( fn (tup:  ([]f32,[]f32,[]f32) ): []f32  =>
         let (mu_row, var_row, result_row) = tup in
         map( fn (tup: ([]f32, []f32, f32, f32, int)): f32  =>
                let ( dx, dxx, mu, var, j ) = tup in
                let c1 = if 0 < j
                         then ( mu*dx[0] + 0.5*var*dxx[0] ) * unsafe result_row[j-1]
                         else 0.0 in
                let c3 = if j < (m-1)
                         then ( mu*dx[2] + 0.5*var*dxx[2] ) * unsafe result_row[j+1]
                         else 0.0 in
                let c2 =      ( mu*dx[1] + 0.5*var*dxx[1] ) * unsafe result_row[j  ]
                in  c1 + c2 + c3
            , zip( myD, myDD, mu_row, var_row, iota(m) )
            )
     , zip( myMu, myVar, result ))

------------------------------------------/
-- myD,myDD     : [m][3]f32
-- myMu,myVar,u : [n][m]f32
-- RETURN       : [n][m]f32
------------------------------------------/
-- for implicitY: should be called with transpose(u) instead of u
fun implicitMethod(myD:  [][]f32,  myDD: [][]f32,
                              myMu: [][]f32, myVar: [][]f32,
                             u: *[][]f32,    dtInv: f32  ): *[][]f32 =
  map( fn (tup:  ([]f32,[]f32,*[]f32) ): *[]f32   =>
         let (mu_row,var_row,u_row) = tup in
         let abc = map( fn (tup: (f32,f32,[]f32,[]f32)): (f32,f32,f32)  =>
                          let (mu, var, d, dd) = tup in
                          ( 0.0   - 0.5*(mu*d[0] + 0.5*var*dd[0])
                          , dtInv - 0.5*(mu*d[1] + 0.5*var*dd[1])
                          , 0.0   - 0.5*(mu*d[2] + 0.5*var*dd[2])
                          )
                      , zip(mu_row, var_row, myD, myDD)
                      ) in
         let (a,b,c) = unzip(abc) in
         if 1==1 then tridagSeq( a, b, c, u_row )
                 else tridagPar( a, b, c, u_row )
     , zip(myMu,myVar,u)
     )

fun rollback
    (myX: [numX]f32, myY: [numY]f32, myTimeline: []f32, myResult: *[][]f32,
     myMuX: [][]f32, myDx: [][]f32, myDxx: [][]f32, myVarX: [][]f32,
     myMuY: [][]f32, myDy: [][]f32, myDyy: [][]f32, myVarY: [][]f32, g: int): *[numY][numX]f32 =

    let dtInv = 1.0/(myTimeline[g+1]-myTimeline[g]) in

    -- explicitX
    let u = explicitMethod( myDx, myDxx, myMuX, myVarX, myResult ) in
    let u = map( fn (tup: ([]f32,[]f32)): []f32  =>
                    let (u_row, res_row) = tup in
                    map (fn (tup: (f32,f32)): f32  =>
                           let (u_el,res_el) = tup
                           in  dtInv*res_el + 0.5*u_el
                        , zip(u_row,res_row) )
                , zip(u,myResult) )
    in
    -- explicitY
    let myResultTR = transpose(myResult) in
    let v = explicitMethod( myDy, myDyy, myMuY, myVarY, myResultTR ) in
    let u = map( fn (us: []f32, vs: []f32): *[]f32  =>
                   copy(map(+, zip(us, vs)))
               , zip(u, transpose(v))
               ) in
    -- implicitX
    let u = implicitMethod( myDx, myDxx, myMuX, myVarX, u, dtInv ) in
    -- implicitY
    let y = map( fn (uv_row: ([]f32,[]f32)): []f32  =>
                   let (u_row, v_row) = uv_row in
                   map( fn (uv: (f32,f32)): f32  =>
                          let (u_el,v_el) = uv
                          in  dtInv*u_el - 0.5*v_el
                      , zip(u_row,v_row)
                      )
               , zip(transpose(u),v))
    in
    let myResultTR = implicitMethod( myDy, myDyy, myMuY, myVarY, y, dtInv )
    in  transpose(myResultTR)

fun value(numX: int, numY: int, numT: int, s0: f32, strike: f32, t: f32, alpha: f32, nu: f32, beta: f32): f32 =
    let (myXindex, myYindex, myX, myY, myTimeline) =
        initGrid(s0, alpha, nu, t, numX, numY, numT) in
    let (myDx, myDxx) = initOperator(myX) in
    let (myDy, myDyy) = initOperator(myY) in
    let myResult = setPayoff(strike, myX, myY) in

    loop (myResult) =
        for numT-1 > i do
            let (myMuX, myVarX, myMuY, myVarY) =
                updateParams(myX, myY, myTimeline, i, alpha, beta, nu) in
            let myResult = rollback(myX, myY, myTimeline, myResult,
                                    myMuX, myDx, myDxx, myVarX,
                                    myMuY, myDy, myDyy, myVarY, i) in

            myResult in
    myResult[myYindex,myXindex]

fun main (outer_loop_count: int, numX: int, numY: int, numT: int,
                 s0: f32, strike: f32, t: f32, alpha: f32, nu: f32, beta: f32): []f32 =
    let strikes = map(fn (i: int): f32  => 0.001*f32(i), iota(outer_loop_count)) in
    let res = map(fn (x: f32): f32  => value(numX, numY, numT, s0, x, t, alpha, nu, beta), strikes) in
    res
