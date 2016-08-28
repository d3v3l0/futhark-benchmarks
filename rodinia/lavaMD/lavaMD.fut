-- Code and comments based on
-- https://github.com/kkushagra/rodinia/blob/master/openmp/lavaMD/main.c
--
-- ==
-- nobench input @ data/3_boxes.in
-- output @ data/3_boxes.out
-- notravis input @ data/10_boxes.in
-- output @ data/10_boxes.out

default(f32)

fun num_neighbors(): int      = 27
fun number_par_per_box(): int = 100 

fun dot(a: (f32,f32,f32), b: (f32,f32,f32)): f32 =
    let (ax,ay,az) = a in
    let (bx,by,bz) = b in
    ax*bx + ay*by + az*bz

-----------------------------------------
-- Main Computational Kernel of lavaMD --
-----------------------------------------
fun main(alpha:  f32
            , box_coefs_0: [number_boxes]int
            , box_coefs_1: [number_boxes]int
            , box_coefs_2: [number_boxes]int
            , box_coefs_3: [number_boxes]int
            , box_nnghs_0 : [][number_boxes]int  -- outer dim should be num_neighbors
            , box_nnghs_1 : [][number_boxes]int  -- outer dim should be num_neighbors
            , box_nnghs_2 : [][number_boxes]int  -- outer dim should be num_neighbors
            , box_nnghs_3 : [][number_boxes]int  -- outer dim should be num_neighbors
            , box_num_nghbs: [number_boxes]int
            , rv_0: [number_boxes][par_per_box]f32
            , rv_1: [number_boxes][par_per_box]f32
            , rv_2: [number_boxes][par_per_box]f32
            , rv_3: [number_boxes][par_per_box]f32
            , qv: [number_boxes][par_per_box]f32
      ): ([number_boxes][par_per_box]f32,
      [number_boxes][par_per_box]f32,
      [number_boxes][par_per_box]f32,
      [number_boxes][par_per_box]f32) =
  let box_coefs = zip(box_coefs_0, box_coefs_1, box_coefs_2, box_coefs_3)
  let box_nnghs = zip@1(box_nnghs_0, box_nnghs_1, box_nnghs_2, box_nnghs_3)
  let rv = zip@1(rv_0, rv_1, rv_2, rv_3)
  let a2 = 2.0*alpha*alpha in
  unzip(map (fn (l: int): [par_per_box](f32,f32,f32,f32)  =>
        let ( bl_x, bl_y, bl_bz, bl_number ) = box_coefs[l] in
        let rA = rv[l] in
        map  (fn (rA_el:  (f32,f32,f32,f32) ): (f32,f32,f32,f32)  => --(int i) =>
                let (rai_v, rai_x, rai_y, rai_z) = rA_el in -- rA[i] in
                let acc = (0.0,0.0,0.0,0.0) in
                loop(acc) = 
                  for k < box_num_nghbs[l]+1 do
                          let pointer = if (k > 0)
                                        then let (_,_,_,num) = unsafe box_nnghs[k-1, l] in num
                                        else l
                          in
                          let (_,_,_,first_j) = unsafe box_coefs[pointer] in
                          let rB = unsafe rv[first_j] in
                          let qB = unsafe qv[first_j] in
                          ---------------------------------------------------------
                          -- Important note: rB and qB are invariant to the      --
                          -- second map on rA => can be blocked in shared memory --
                          ---------------------------------------------------------
                          let pres = 
                            map (fn (tup:  ( (f32,f32,f32,f32), f32 )): (f32,f32,f32,f32)  =>
                                      let ( (rbj_v,rbj_x,rbj_y,rbj_z), qbj ) = tup in
                                      let r2   = rai_v + rbj_v - dot((rai_x,rai_y,rai_z), (rbj_x,rbj_y,rbj_z)) in
                                      let u2   = a2*r2          in
                                      let vij  = exp32(-u2)       in
                                      let fs   = 2.0 * vij      in
                                      let d_x  = rai_x  - rbj_x in 
                                      let d_y  = rai_y  - rbj_y in 
                                      let d_z  = rai_z  - rbj_z in 
                                      let fxij = fs * d_x       in
                                      let fyij = fs * d_y       in
                                      let fzij = fs * d_z       in
                                      (qbj*vij, qbj*fxij, qbj*fyij, qbj*fzij)
                               ) (zip(rB,qB) )

                          let (r1, r2, r3, r4) = 
                            reduce (fn (a: (f32,f32,f32,f32)) (b: (f32,f32,f32,f32)): (f32,f32,f32,f32)  =>
                                        let (a1,a2,a3,a4) = a in let (b1,b2,b3,b4) = b in (a1+b1, a2+b2, a3+b3, a4+b4)
                                  ) (0.0,0.0,0.0,0.0) pres
                          let (a1, a2, a3, a4) = acc
                          in  (a1+r1, a2+r2, a3+r3, a4+r4)
                in acc                         
            ) rA
     ) (iota(number_boxes) ))
