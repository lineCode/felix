(** Beta reduction *)

open Flx_util
open Flx_types
open Flx_btype
open Flx_mtypes2

open Flx_print
open Flx_typing
open Flx_unify
open Flx_maps

(* fixpoint reduction: reduce
   Fix f. Lam x. e ==> Lam x. Fix z. e [f x -> z]
   to replace a recursive function
   with a recursive data structure.

   Example: consider:

   list t = t * list t

   which is

   list = fix f. lam t. t * f t

   We can apply list to int:

   list int = (fix f. lam t. t * f t) int

   unfolding:

   list int = (lam t. t * (fix f. lam t. t * f t)) int
            = int * (fix f. lam t. t * f t) int
            = int * list int

   which is just

   list int = fix z. int * z

  The rule ONLY works when a recursive function f
  is applied in its own definition to its own parameter.

  The rule traps in infinite expansion of a data type,
  and creates instead an recursive data type, eliminating
  the function.

  The normal beta reduction rule is

  (lam t. b) a => b [t->a]

  For a recursive function:

  (fix f. lam t. b) a => b[f-> fix f. lam t. b; t-> a]

  and the result must be reduced again.

*)

let rec fixup syms ps body =
 let param = match ps with
   | [] -> assert false
   | [i,mt] -> btyp_type_var (i,mt)
   | x -> btyp_type_tuple (List.map (fun (i,mt) -> btyp_type_var (i,mt)) x)
 in
 (*
 print_endline ("Body  = " ^ sbt bsym_table body);
 print_endline ("Param = " ^ sbt bsym_table param);
 *)
 let rec aux term depth =
   let fx t = aux t (depth+1) in
   match Flx_btype.map ~ft:fx term with
   | BTYP_type_apply (BTYP_fix i, arg)
     when arg = param
     && i + depth +1  = 0 (* looking inside application, one more level *)
     -> print_endline "SPECIAL REDUCTION";
     btyp_fix (i+2) (* elide application AND skip under lambda abstraction *)

   | BTYP_type_function (a,b,c) ->
      (* NOTE we have to add 2 to depth here, an extra
      level for the lambda binder.
      NOTE also: this is NOT a recusive call to fixup!
      It doesn't fixup this function.
      *)

      (*
      print_endline "OOPS >> no alpha conversion?";
      *)

      btyp_type_function (a, fx b, aux c (depth + 2))
   | x -> x
 in
   (* note depth 1: we seek a fix to an abstraction
   of which we're given only the body, that's an
   extra level in the term structure
   *)
   aux body 1

(* generic fixpoint adjuster: add amt to the fixpoint
   to make it span less deep term, to compensate
   for removing the top combinator of the term as a result
   of a one level adjustment eg: reduce a type match
*)

and adjust t =
  let rec adj depth t =
    let fx t = adj (depth + 1) t in
    match Flx_btype.map ~ft:fx t with
    | BTYP_fix i when i + depth < 0 -> btyp_fix (i+1)
    | x -> x
  in adj 0 t

and mk_prim_type_inst i args =
  print_endline "MK_PRIM_TYPE";
  btyp_inst (i,args)

and beta_reduce syms bsym_table sr t1 =
  (*
  print_endline ("---------- Beta reduce " ^ sbt bsym_table t1);
  *)
  let t2 =
  try
  beta_reduce' syms bsym_table sr [] t1
  with
    | Not_found ->
        failwith ("Beta reduce failed with Not_found in " ^
          sbt bsym_table t1)
    | Failure s ->
        failwith ("beta-reduce failed in " ^ sbt bsym_table t1 ^
          "\nmsg: " ^ s)
  in
  (*
  print_endline ("============  reduced= " ^ sbt bsym_table t2);
  *)
  t2

and type_list_index syms bsym_table ls t =
  (*
  print_endline ("Comparing : " ^ sbt bsym_table t ^ " with ..");
  *)
  let rec aux ls n = match ls with
  | [] -> None
  | hd :: tl ->
    (*
    print_endline ("Candidate : " ^ sbt bsym_table hd);
    *)
    if
      begin try type_eq syms.counter hd t
      with x ->
        print_endline ("Exception: " ^ Printexc.to_string x);
        false
      end
    then Some n
    else aux tl (n+1)
  in aux ls 0

and beta_reduce' syms bsym_table sr termlist t =
  (*
  print_endline ("BETA REDUCE " ^ sbt bsym_table t ^ "\ntrail length = " ^
    si (length termlist));
  *)
  if List.length termlist > 20
  then begin
    print_endline ("Trail=" ^ catmap "\n" (sbt bsym_table) termlist);
    failwith  ("Trail overflow, infinite expansion: BETA REDUCE " ^
    sbt bsym_table t ^ "\ntrail length = " ^ si (List.length termlist))
  end;

  match type_list_index syms bsym_table termlist t with
  | Some j ->
        (*
        print_endline "+++Trail:";
        let i = ref 0 in
        iter (fun t -> print_endline (
          "    " ^ si (!i) ^ " ---> " ^sbt bsym_table t)
          ; decr i
        )
        (t::termlist)
        ;
        print_endline "++++End";
    print_endline ("Beta find fixpoint " ^ si (-j-1));
    print_endline ("Repeated term " ^ sbt bsym_table t);
    *)
    btyp_fix (-j - 1)

  | None ->

  let br t' = beta_reduce' syms bsym_table sr (t::termlist) t' in
  let st t = string_of_btypecode bsym_table t in
  match t with
  | BTYP_fix _ -> t
  | BTYP_type_var (i,_) -> t

  | BTYP_type_function (p,r,b) -> t
  (*
    let b = fixup syms p b in
    let b' = beta_reduce' syms bsym_table sr (t::termlist) b in
    let t = BTYP_type_function (p, br r, b') in
    t
  *)

  | BTYP_inst (i,ts) -> btyp_inst (i, List.map br ts)
  | BTYP_tuple ls -> btyp_tuple (List.map br ls)
  | BTYP_array (i,t) -> btyp_array (i, br t)
  | BTYP_sum ls -> btyp_sum (List.map br ls)
  | BTYP_record ts ->
     let ss,ls = List.split ts in
     btyp_record (List.combine ss (List.map br ls))

  | BTYP_variant ts ->
     let ss,ls = List.split ts in
     btyp_variant (List.combine ss (List.map br ls))

  (* Intersection type reduction rule: if any term is 0,
     the result is 0, otherwise the result is the intersection
     of the reduced terms with 1 terms removed: if there
     are no terms return 1, if a single term return it,
     otherwise return the intersection of non units
     (at least two)
  *)
  | BTYP_intersect ls ->
    let ls = List.map br ls in
    if List.mem btyp_void ls then btyp_void
    else let ls = List.filter (fun i -> i <> btyp_tuple []) ls in
    begin match ls with
    | [] -> btyp_tuple []
    | [t] -> t
    | ls -> btyp_intersect ls
    end

  | BTYP_type_set ls -> btyp_type_set (List.map br ls)

  | BTYP_type_set_union ls ->
    let ls = List.rev_map br ls in
    (* split into explicit typesets and other terms
      at the moment, there shouldn't be any 'other'
      terms (since there are no typeset variables ..
    *)
    let rec aux ts ot ls  = match ls with
    | [] ->
      begin match ot with
      | [] -> btyp_type_set ts
      | _ ->
        (*
        print_endline "WARNING UNREDUCED TYPESET UNION";
        *)
        btyp_type_set_union (btyp_type_set ts :: ot)
      end

    | BTYP_type_set xs :: t -> aux (xs @ ts) ot t
    | h :: t -> aux ts (h :: ot) t
    in aux [] [] ls

  (* NOTE: sets have no unique unit *)
  (* WARNING: this representation is dangerous:
     we can only calculate the real intersection
     of discrete types *without type variables*

     If there are pattern variables, we may be able
     to apply unification as a reduction. However
     we have to be very careful doing that: we can't
     unify variables bound by universal or lambda quantifiers
     or the environment: technically I think we can only
     unify existentials. For example the intersection

     'a * int & long & 'b

     may seem to be long * int, but only if 'a and 'b are
     pattern variables, i.e. dependent variables we're allowed
     to assign. If they're actually function parameters, or
     just names for types in the environment, we have to stop
     the unification algorithm from assigning them (since they're
     actually particular constants at that point).

     but the beta-reduction can be applied anywhere .. so I'm
     not at all confident of the right reduction rule yet.

     Bottom line: the rule below is a hack.
  *)
  | BTYP_type_set_intersection ls ->
    let ls = List.map br ls in
    if List.mem (btyp_type_set []) ls then btyp_type_set []
    else begin match ls with
    | [t] -> t
    | ls -> btyp_type_set_intersection ls
    end


  | BTYP_type_tuple ls -> btyp_type_tuple (List.map br ls)
  | BTYP_function (a,b) -> btyp_function (br a, br b)
  | BTYP_cfunction (a,b) -> btyp_cfunction (br a, br b)
  | BTYP_pointer a -> btyp_pointer (br a)
(*  | BTYP_lvalue a -> btyp_lvalue (br a) *)

  | BTYP_void -> t
  | BTYP_type _ -> t
  | BTYP_unitsum _ -> t

  | BTYP_type_apply (t1,t2) ->
    let t1 = br t1 in (* eager evaluation *)
    let t2 = br t2 in (* eager evaluation *)
    let t1 =
      match t1 with
      | BTYP_fix j ->
        (*
        print_endline ("++++Fixpoint application " ^ si j);
        print_endline "+++Trail:";
        let i = ref 0 in
        iter (fun t -> print_endline (
          "    " ^ si (!i) ^ " ---> " ^sbt bsym_table t)
          ; decr i
        )
        (t1::t::termlist)
        ;
        print_endline "++++End";
        *)
        let whole = List.nth termlist (-2-j) in
        (*
        print_endline ("Recfun = " ^ sbt bsym_table whole);
        *)
        begin match whole with
        | BTYP_type_function _ -> ()
        | _ -> assert false
        end;
        whole

      | _ -> t1
    in
    (*
    print_endline ("Function = " ^ sbt bsym_table t1);
    print_endline ("Argument = " ^ sbt bsym_table t2);
    print_endline ("Unfolded = " ^
      sbt bsym_table (unfold sym_table t1));
    *)
    begin match unfold t1 with
    | BTYP_type_function (ps,r,body) ->
      let params' =
        match ps with
        | [] -> []
        | [i,_] -> [i,t2]
        | _ ->
          let ts = match t2 with
          | BTYP_type_tuple ts -> ts
          | _ -> assert false
          in
            if List.length ps <> List.length ts
            then failwith "Wrong number of arguments to typefun"
            else List.map2 (fun (i,_) t -> i, t) ps ts
      in
      (*
      print_endline ("Body before subs    = " ^ sbt bsym_table body);
      print_endline ("Parameters= " ^ catmap ","
        (fun (i,t) -> "T"^si i ^ "=>" ^ sbt bsym_table t) params');
      *)
      let t' = list_subst syms.counter params' body in
      (*
      print_endline ("Body after subs     = " ^ sbt bsym_table t');
      *)
      let t' = beta_reduce' syms bsym_table sr (t::termlist) t' in
      (*
      print_endline ("Body after reduction = " ^ sbt bsym_table t');
      *)
      let t' = adjust t' in
      t'

    | _ ->
      (*
      print_endline "Apply nonfunction .. can't reduce";
      *)
      btyp_type_apply (t1,t2)
    end

  | BTYP_type_match (tt,pts) ->
    (*
    print_endline ("Typematch [before reduction] " ^ sbt bsym_table t);
    *)
    let tt = br tt in
    let new_matches = ref [] in
    List.iter (fun ({pattern=p; pattern_vars=dvars; assignments=eqns}, t') ->
      (*
      print_endline (spc ^"Tring to unify argument with " ^
        sbt bsym_table p');
      *)
      let p =  br p in
      let x =
        {
          pattern=p;
          assignments=List.map (fun (j,t) -> j, br t) eqns;
          pattern_vars=dvars;
        }, t'
      in
      match maybe_unification syms.counter [p,tt] with
      | Some _ -> new_matches := x :: !new_matches
      | None ->
        (*
        print_endline (spc ^"Discarding pattern " ^ sbt bsym_table p');
        *)
        ()
    )
    pts
    ;
    let pts = List.rev !new_matches in
    match pts with
    | [] ->
      failwith "[beta-reduce] typematch failure"
    | ({pattern=p';pattern_vars=dvars;assignments=eqns},t') :: _ ->
      try
        let mgu = unification syms.counter [p', tt] dvars in
        (*
        print_endline "Typematch success";
        *)
        let t' = list_subst syms.counter (mgu @ eqns) t' in
        let t' = br t' in
        (*
        print_endline ("type match reduction result=" ^ sbt bsym_table t');
        *)
        adjust t'
      with Not_found -> btyp_type_match (tt,pts)
