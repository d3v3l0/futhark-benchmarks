-- Generic pricing
-- ==
-- compiled input @ OptionPricing-data/small.in
-- output @ OptionPricing-data/small.out
--
-- notravis input @ OptionPricing-data/medium.in
-- output @ OptionPricing-data/medium.out
--
-- notravis input @ OptionPricing-data/large.in
-- output @ OptionPricing-data/large.out

default(f32)

fun grayCode(x: int): int = (x >> 1) ^ x

----------------------------------------
--- Sobol Generator
----------------------------------------
fun testBit(n: int, ind: int): bool =
    let t = (1 << ind) in (n & t) == t

-----------------------------------------------------------------
---- INDEPENDENT FORMULA: 
----    filter is redundantly computed inside map.
----    Currently Futhark hoists it outside, but this will
----    not allow fusing the filter with reduce => redomap,
-----------------------------------------------------------------
fun xorInds(n: int) (dir_vs: [num_bits]int): int =
    let reldv_vals = map (fn (dv: int, i: int): int  => 
                            if testBit(grayCode(n),i) 
                            then dv else 0
                        ) (zip (dir_vs) (iota(num_bits)) )
    in reduce (^) 0 (reldv_vals )

fun sobolIndI (dir_vs:  [m][num_bits]int, n: int ): [m]int =
    map (xorInds(n)) (dir_vs )

fun sobolIndR(dir_vs: [m][num_bits]int) (n: int): [m]f32 =
    let divisor = 2.0 ** f32(num_bits)
    let arri    = sobolIndI( dir_vs, n )
    in map (fn (x: int): f32  => f32(x) / divisor) arri

--------------------------------
---- STRENGTH-REDUCED FORMULA
--------------------------------
fun index_of_least_significant_0(num_bits: int, n: int): int = 
  let (goon,k) = (True,0)
  loop ((goon,k,n)) =
        for i < num_bits do
          if(goon) 
          then if (n & 1) == 1
               then (True, k+1, n>>1)
               else (False,k,   n   )
          else      (False,k,   n   )
  in k

fun sobolRecI(sob_dir_vs: [][num_bits]int, prev: []int, n: int): []int = 
  let bit = index_of_least_significant_0(num_bits,n)
  in map  (fn (vct_prev: ([]int,int)): int  => 
             let (vct_row, prev) = vct_prev
             in vct_row[bit] ^ prev
          ) (zip (sob_dir_vs) prev)

fun sobolRecMap(sob_fact:  f32, dir_vs: [n][]int, lu_bds: (int,int) ): [][]f32 =
  let (lb_inc, ub_exc) = lu_bds
  -- the if inside may be particularly ugly for
  -- flattening since it introduces control flow!
  let contribs = map (fn (k: int): []int  => 
                        if (k==0) 
            then sobolIndI(dir_vs,lb_inc+1)
                        else recM(dir_vs,k+lb_inc)
                    ) (iota(ub_exc-lb_inc) 
                    )
  let vct_ints = scan (fn x y: []int  => zipWith (^) x y
                     ) (replicate n 0
                     ) contribs
  in  map (fn (xs: []int): []f32  => 
             map  (fn (x: int): f32  => 
                     f32(x) * sob_fact 
                 ) xs
         ) (vct_ints)

fun sobolRecI2(sob_dirs: [][]int, prev: []int, i: int): []int=
  let col = recM(sob_dirs, i) in zipWith (^) prev col

fun recM(sob_dirs:  [][num_bits]int, i: int ): []int =
  let bit= index_of_least_significant_0(num_bits,i)
  in map (fn (row: []int): int => row[bit]) (sob_dirs )

-- computes sobol numbers: n,..,n+chunk-1
fun sobolChunk(dir_vs: [len][num_bits]int, n: int, chunk: int): [chunk][]f32 =
  let sob_fact= 1.0 / f32(1 << num_bits)
  let sob_beg = sobolIndI(dir_vs, n+1)
  let contrbs = map (fn (k: int): []int  =>
                        let sob = k + n
                        in if k==0 then sob_beg
                           else recM(dir_vs, k+n)
                   ) (iota(chunk) )
  let vct_ints= scan (fn x y: []int  => zipWith (^) x y
                    ) (replicate len 0) contrbs
  in map (fn (xs: []int): []f32  =>
            map  (fn (x: int): f32  =>
                    f32(x) * sob_fact
                  ) xs
          ) (vct_ints)
  
----------------------------------------
--- Inverse Gaussian
----------------------------------------
fun polyAppr(x:       f32,
                        a0: f32, a1: f32, a2: f32, a3: f32,
                        a4: f32, a5: f32, a6: f32, a7: f32,
                        b0: f32, b1: f32, b2: f32, b3: f32,
                        b4: f32, b5: f32, b6: f32, b7: f32
                    ): f32 =
        (x*(x*(x*(x*(x*(x*(x*a7+a6)+a5)+a4)+a3)+a2)+a1)+a0) /
        (x*(x*(x*(x*(x*(x*(x*b7+b6)+b5)+b4)+b3)+b2)+b1)+b0)

fun smallcase(q: f32): f32 =
        q * polyAppr( 0.180625 - q * q,

                      3.387132872796366608,
                      133.14166789178437745,
                      1971.5909503065514427,
                      13731.693765509461125,
                      45921.953931549871457,
                      67265.770927008700853,
                      33430.575583588128105,
                      2509.0809287301226727,

                      1.0,
                      42.313330701600911252,
                      687.1870074920579083,
                      5394.1960214247511077,
                      21213.794301586595867,
                      39307.89580009271061,
                      28729.085735721942674,
                      5226.495278852854561
                    )

fun intermediate(r: f32): f32 =
        polyAppr( r - 1.6,

                  1.42343711074968357734,
                  4.6303378461565452959,
                  5.7694972214606914055,
                  3.64784832476320460504,
                  1.27045825245236838258,
                  0.24178072517745061177,
                  0.0227238449892691845833,
                  7.7454501427834140764e-4,

                  1.0,
                  2.05319162663775882187,
                  1.6763848301838038494,
                  0.68976733498510000455,
                  0.14810397642748007459,
                  0.0151986665636164571966,
                  5.475938084995344946e-4,
                  1.05075007164441684324e-9
                )

fun tail(r: f32): f32 =
        polyAppr( r - 5.0,

                  6.6579046435011037772,
                  5.4637849111641143699,
                  1.7848265399172913358,
                  0.29656057182850489123,
                  0.026532189526576123093,
                  0.0012426609473880784386,
                  2.71155556874348757815e-5,
                  2.01033439929228813265e-7,

                  1.0,
                  0.59983220655588793769,
                  0.13692988092273580531,
                  0.0148753612908506148525,
                  7.868691311456132591e-4,
                  1.8463183175100546818e-5,
                  1.4215117583164458887e-7,
                  2.04426310338993978564e-5
                )

fun ugaussianEl(p:  f32 ): f32 =
    let dp = p - 0.5
    in  --if  ( fabs(dp) <= 0.425 )
        if ( ( (dp < 0.0 ) && (0.0 - dp <= 0.425) ) || 
             ( (0.0 <= dp) && (dp <= 0.425)       )  )
        then smallcase(dp)
        else let pp = if(dp < 0.0) then dp + 0.5 
                                   else 0.5 - dp
             let r  = sqrt32( - log32(pp) )
             let x = if(r <= 5.0) then intermediate(r) 
                                  else tail(r)
             in if(dp < 0.0) then 0.0 - x else x

-- Transforms a uniform distribution [0,1) 
-- into a gaussian distribution (-inf, +inf)
fun ugaussian(ps: [n]f32): [n]f32 = map ugaussianEl ps


---------------------------------
--- Brownian Bridge
---------------------------------
fun brownianBridgeDates (bb_inds: [3][num_dates]int,
                         bb_data: [3][num_dates]f32)
                         (gauss: [num_dates]f32): [num_dates]f32 =
    let bi = bb_inds[0]
    let li = bb_inds[1]
    let ri = bb_inds[2]
    let sd = bb_data[0]
    let lw = bb_data[1]
    let rw = bb_data[2]

    let bbrow = replicate num_dates 0.0
    let bbrow[ bi[0]-1 ] = sd[0] * gauss[0]

    loop (bbrow) =
        for i < num_dates-1 do  -- use i+1 since i in 1 .. num_dates-1
            unsafe
            let j  = li[i+1] - 1
            let k  = ri[i+1] - 1
            let l  = bi[i+1] - 1

            let wk = bbrow [k  ]
            let zi = gauss [i+1]
            let tmp= rw[i+1] * wk + sd[i+1] * zi

            let bbrow[ l ] = if( j == -1)
                             then tmp
                             else tmp + lw[i+1] * bbrow[j]
            in  bbrow

        -- This can be written as map-reduce, but it
        --   needs delayed arrays to be mapped nicely!
    in loop (bbrow) =
        for ii < num_dates-1 do
            let i = num_dates - (ii+1)
            let bbrow[i] = bbrow[i] - bbrow[i-1]
            in  bbrow
       in bbrow

fun brownianBridge (num_und: int,
                    bb_inds: [3][num_dates]int,
                    bb_data: [3][num_dates]f32)
                   (gaussian_arr: []f32): [num_dates][num_und]f32 =
    let gauss2d  = reshape (num_dates,num_und) gaussian_arr
    let gauss2dT = transpose gauss2d
    in transpose (map (brownianBridgeDates(bb_inds, bb_data)) gauss2dT)


---------------------------------
--- Black-Scholes
---------------------------------
fun take(n: int, a: []f32): [n]f32 = let (first, rest) = split (n) a in first

fun correlateDeltas(md_c:  [num_und][num_und]f32, 
                 zds: [num_dates][num_und]f32  
): [num_dates][num_und]f32 =
    map (fn (zi: [num_und]f32): [num_und]f32  =>
            map (fn (j: int): f32  =>
                    let x = zipWith (*) (take(j+1,zi)) (take(j+1,md_c[j]) )
                    in  reduce (+) (0.0) x
               ) (iota(num_und) )
       ) zds

fun combineVs(n_row:   [num_und]f32, 
                               vol_row: [num_und]f32, 
                               dr_row: [num_und]f32 ): [num_und]f32 =
    zipWith (+) dr_row (zipWith (*) n_row vol_row)

fun mkPrices(md_starts:    [num_und]f32,
           md_vols: [num_dates][num_und]f32,
                   md_drifts: [num_dates][num_und]f32,
           noises: [num_dates][num_und]f32
): [num_dates][num_und]f32 =
    let c_rows = map combineVs (zip noises (md_vols) (md_drifts) )
    let e_rows = map (fn (x: []f32): [num_und]f32  =>
                        map exp32 x
                    ) (c_rows --map( combineVs, zip(noises, md_vols, md_drifts) )
                    )
    in  map (fn (x: []f32): [num_und]f32  =>
              zipWith (*) (md_starts) x
           ) (scan (fn x y: []f32  => zipWith (*) x y
                 ) (replicate num_und 1.0
                 ) (e_rows))

fun blackScholes(md_c: 
                [num_und][num_und]f32,
                md_vols: [num_dates][num_und]f32,
                md_drifts: [num_dates][num_und]f32,
                 md_starts: [num_und]f32,
                bb_arr: [num_dates][num_und]f32
           ): [num_dates][num_und]f32 =
    let noises = correlateDeltas(md_c, bb_arr)
    in  mkPrices(md_starts, md_vols, md_drifts, noises)

----------------------------------------
-- MAIN
----------------------------------------
fun main(contract_number: 
               int,
               num_mc_it: int,
             dir_vs_nosz: [][num_bits]int,
             md_cs: [num_models][num_und][num_und]f32,
             md_vols: [num_models][num_dates][num_und]f32,
             md_drifts: [num_models][num_dates][num_und]f32,
             md_sts: [num_models][num_und]f32,
             md_detvals: [num_models][]f32,
             md_discts: [num_models][]f32,
             bb_inds: [3][num_dates]int,
             bb_data: [3][num_dates]f32
): []f32 =
  let dir_vs    = reshape (num_dates*num_und, num_bits) dir_vs_nosz
 
  let sobol_mat = map  (sobolIndR(dir_vs) 
                              ) (map (fn (x: int): int  => x + 1) (iota(num_mc_it) ) 
                              )

  let gauss_mat = map  ugaussian (sobol_mat )

  let bb_mat    = map  (brownianBridge( num_und, bb_inds, bb_data )) (gauss_mat )

  let payoffs   = map  (fn (bb_row: [][]f32): [num_models]f32  =>
                          let market_params = zip (md_cs) (md_vols) (md_drifts) (md_sts)
                          let bd_row =
                            map  (fn (m: ([][]f32,[][]f32,[][]f32,[]f32)): [num_dates][num_und]f32  =>
                                   let (c,vol,drift,st) = m
                                   in blackScholes(c, vol, drift, st, bb_row)
                                ) (market_params)
                          let payoff_params = zip (md_discts) (md_detvals) (bd_row)
                          in map  (fn (p: ([]f32,[]f32,[][]f32)): f32  =>
                                     let (disct, detval, bd) = p
                                     in genericPayoff(contract_number, disct, detval, bd)
                                  ) (payoff_params)
                      ) (bb_mat)

  let payoff    = reduce  (fn x y: []f32  => zipWith (+) x y
                         ) (replicate num_models 0.0
                         ) payoffs
  in  map  (fn (price: f32): f32  => price / f32(num_mc_it)) payoff



fun mainRec(contract_number: 
               int,
               num_mc_it: int,
             dir_vs_nosz: [][num_bits]int,
             md_cs: [num_models][num_und][num_und]f32,
             md_vols: [num_models][num_dates][num_und]f32,
             md_drifts: [num_models][num_dates][num_und]f32,
             md_sts: [num_models][num_und]f32,
             md_detvals: [num_models][]f32,
             md_discts: [num_models][]f32,
             bb_inds: [3][num_dates]int,
             bb_data: [3][num_dates]f32
): []f32 =
  let sobvctsz  = num_dates*num_und
  let dir_vs    = reshape (sobvctsz,num_bits) dir_vs_nosz
  let sobol_mat = streamMap (fn (chunk: int) (ns: []int): [][sobvctsz]f32  =>
                                sobolChunk(dir_vs, ns[0], chunk)
                           ) (iota(num_mc_it) )

  let gauss_mat = map  ugaussian (sobol_mat )

  let bb_mat    = map  (brownianBridge( num_und, bb_inds, bb_data )) (gauss_mat )

  let payoffs   = map  (fn (bb_row: [][]f32): []f32  =>
                          let market_params = zip (md_cs) (md_vols) (md_drifts) (md_sts)
                          let bd_row = map  (fn (m: ([][]f32,[][]f32,[][]f32,[]f32)): [][]f32  =>
                                               let (c,vol,drift,st) = m
                                               in blackScholes(c, vol, drift, st, bb_row)
                                            ) (market_params)

                          let payoff_params = zip (md_discts) (md_detvals) (bd_row)
                          in map  (fn (p: ([]f32,[]f32,[][]f32)): f32  =>
                                     let (disct, detval, bd) = p
                                     in genericPayoff(contract_number, disct, detval, bd)
                                  ) (payoff_params)
                       ) bb_mat

  let payoff    = reduce (fn x y: []f32 => zipWith (+) x y
                         ) (replicate num_models 0.0
                         ) payoffs
  in  map  (fn (price: f32): f32  => price / f32(num_mc_it)) payoff


----------------------------------------
-- PAYOFF FUNCTIONS
----------------------------------------
fun genericPayoff(contract: int, md_disct: []f32, md_detval: []f32, xss: [][]f32): f32 = 
    if      (contract == 1) then payoff1(md_disct, md_detval, xss)
    else if (contract == 2) then payoff2(md_disct, xss)
    else if (contract == 3) then payoff3(md_disct, xss)
    else 0.0                

fun payoff1(md_disct: []f32, md_detval: []f32, xss: [1][1]f32): f32 = 
    let detval = unsafe md_detval[0]
    let amount = ( xss[0,0] - 4000.0 ) * detval
    let amount0= if (0.0 < amount) then amount else 0.0
    in  trajInner(amount0, 0, md_disct)

fun payoff2 (md_disc: []f32, xss: [5][3]f32): f32 =
  let (date, amount) = 
    if      (1.0 <= fminPayoff(xss[0])) then (0, 1150.0)
    else if (1.0 <= fminPayoff(xss[1])) then (1, 1300.0)
    else if (1.0 <= fminPayoff(xss[2])) then (2, 1450.0)
    else if (1.0 <= fminPayoff(xss[3])) then (3, 1600.0)
    else let x50  = fminPayoff(xss[4])
         let value  = if      ( 1.0 <= x50 ) then 1750.0
                      else if ( 0.75 < x50 ) then 1000.0
                      else                        x50*1000.0
         in (4, value)
  in  trajInner(amount, date, md_disc) 

fun payoff3(md_disct: []f32, xss: [367][3]f32): f32 =
    let conds  = map  (fn (x: []f32): bool  => (x[0] <= 2630.6349999999998) || 
                                            (x[1] <= 8288.0)             || 
                                            (x[2] <=  840.0)
                     ) xss
    let cond  = reduce  (||) False conds
    let price1= trajInner(100.0,  0, md_disct)
    let goto40= cond && 
                  ( (xss[366,0] < 3758.05) || 
                    (xss[366,1] < 11840.0) ||
                    (xss[366,2] < 1200.0 )  )
    let amount= if goto40
                  then 1000.0 * fminPayoff(xss[366]) 
                  else 1000.0
    let price2 = trajInner(amount, 1, md_disct)
    in price1 + price2

fun fminPayoff(xs: []f32): f32 = 
--    MIN( zipWith(/, xss, {3758.05, 11840.0, 1200.0}) )
    let (a,b,c) = ( xs[0]/3758.05, xs[1]/11840.0, xs[2]/1200.0)
    in if a < b
       then if a < c then a else c
       else if b < c then b else c

fun min(arr: []f32): f32 =
  reduce (fn x y: f32  => if x<y then x else y) (arr[0]) arr

fun minint(x: int, y: int): int = if x < y then x else y

fun trajInner(amount: f32, ind: int, disc: []f32): f32 = amount * unsafe disc[ind]
