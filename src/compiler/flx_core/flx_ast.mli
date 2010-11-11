(** {6 Source Reference}
 *
 * Provides a reference to the original source.  *)

(** {6 Abstract Syntax Tree}
 *
 * AST types are nodes of the Abstract Syntax Tree generated by the parser. *)

(** {7 Names}
 *
 * A simple name is an identifier, a qualified name is a dot (.) separated list
 * of instantiated names, and a instantiated name is a simple name optionally
 * followed by a square bracket enclosed list of type expressions. *)
type id_t = string

type index_t = int
type index_map_t = (int,int) Hashtbl.t

type code_spec_t =
  | CS_str_template of string
  | CS_str of string
  | CS_virtual
  | CS_identity

type base_type_qual_t = [
  | `Incomplete
  | `Pod
  | `GC_pointer (* this means the type is a pointer the GC must follow *)
]

(** type of a qualified name *)
type qualified_name_t =
  [
  | `AST_void of Flx_srcref.t
  | `AST_name of Flx_srcref.t * string * typecode_t list
  | `AST_case_tag of Flx_srcref.t * int
  | `AST_typed_case of Flx_srcref.t * int * typecode_t
  | `AST_lookup of Flx_srcref.t * (expr_t * string * typecode_t list)
  | `AST_the of Flx_srcref.t * qualified_name_t
  | `AST_index of Flx_srcref.t * string * index_t
  | `AST_callback of Flx_srcref.t * qualified_name_t
  ]

(** type of a suffixed name *)
and suffixed_name_t =
  [
  | `AST_void of Flx_srcref.t
  | `AST_name of Flx_srcref.t * string * typecode_t list
  | `AST_case_tag of Flx_srcref.t * int
  | `AST_typed_case of Flx_srcref.t * int * typecode_t
  | `AST_lookup of Flx_srcref.t * (expr_t * string * typecode_t list)
  | `AST_the of Flx_srcref.t * qualified_name_t
  | `AST_index of Flx_srcref.t * string * index_t
  | `AST_callback of Flx_srcref.t * qualified_name_t
  | `AST_suffix of Flx_srcref.t * (qualified_name_t * typecode_t)
  ]

(** {7 Type sublanguage}
 *
 * The encoding '`TYP_void' is the categorical initial: the type of an empty
 * union, and the type ordinary procedure types return.  There are no values
 * of this type. *)

(** type of a type *)
and typecode_t =
  | TYP_void of Flx_srcref.t                   (** void type *)
  | TYP_name of Flx_srcref.t * string * typecode_t list
  | TYP_case_tag of Flx_srcref.t * int
  | TYP_typed_case of Flx_srcref.t * int * typecode_t
  | TYP_lookup of Flx_srcref.t * (expr_t * string * typecode_t list)
  | TYP_the of Flx_srcref.t * qualified_name_t
  | TYP_index of Flx_srcref.t * string * index_t
  | TYP_callback of Flx_srcref.t * qualified_name_t
  | TYP_suffix of Flx_srcref.t * (qualified_name_t * typecode_t)
  | TYP_patvar of Flx_srcref.t * string
  | TYP_patany of Flx_srcref.t
  | TYP_tuple of typecode_t list               (** product type *)
  | TYP_unitsum of int                         (** sum of units  *)
  | TYP_sum of typecode_t list                 (** numbered sum type *)
  | TYP_intersect of typecode_t list           (** intersection type *)
  | TYP_record of (string * typecode_t) list   (** anon product *)
  | TYP_variant of (string * typecode_t) list  (** anon sum *)
  | TYP_function of typecode_t * typecode_t    (** function type *)
  | TYP_cfunction of typecode_t * typecode_t   (** C function type *)
  | TYP_pointer of typecode_t                  (** pointer type *)
  | TYP_array of typecode_t * typecode_t       (** array type base ^ index *)
  | TYP_as of typecode_t * string              (** fixpoint *)
  | TYP_typeof of expr_t                       (** typeof *)
  | TYP_var of index_t                         (** unknown type *)
  | TYP_none                                   (** unspecified *)
  | TYP_ellipsis                               (** ... for varargs *)
(*  | TYP_lvalue of typecode_t *)                  (** ... lvalue annotation *)
  | TYP_isin of typecode_t * typecode_t        (** typeset membership *)

  (* sets of types *)
  | TYP_typeset of typecode_t list             (** discrete set of types *)
  | TYP_setunion of typecode_t list            (** union of typesets *)
  | TYP_setintersection of typecode_t list     (** intersection of typesets *)

  (* dualizer *)
  | TYP_dual of typecode_t                     (** dual *)

  (* destructors *)
  | TYP_dom of typecode_t                      (** function domain extractor *)
  | TYP_cod of typecode_t                      (** function codomain extractor *)
  | TYP_proj of int * typecode_t               (** tuple projection *)
  | TYP_case_arg of int * typecode_t           (** argument of n'th variant *)

  | TYP_apply of typecode_t * typecode_t       (** type function application *)
  | TYP_typefun of simple_parameter_t list * typecode_t * typecode_t
                                                (** type lambda *)
  | TYP_type                                   (** meta type of a type *)
  | TYP_type_tuple of typecode_t list          (** meta type product *)

  | TYP_type_match of typecode_t * (typecode_t * typecode_t) list

and tpattern_t =
  | TPAT_function of tpattern_t * tpattern_t
  | TPAT_sum of tpattern_t list
  | TPAT_tuple of tpattern_t list
  | TPAT_pointer of tpattern_t
  | TPAT_void
  | TPAT_var of string
  | TPAT_name of string * tpattern_t list
  | TPAT_as of tpattern_t * string
  | TPAT_any
  | TPAT_unitsum of int
  | TPAT_type_tuple of tpattern_t list

and raw_typeclass_insts_t = qualified_name_t list
and vs_aux_t = {
  raw_type_constraint:typecode_t;
  raw_typeclass_reqs: raw_typeclass_insts_t
}

and plain_vs_list_t = (id_t * typecode_t) list
and vs_list_t = plain_vs_list_t * vs_aux_t

(** Literals recognized by the lexer. *)
and literal_t =
  | AST_int of string * string (* first string is kind, second is value *) 
  | AST_string of string
  | AST_cstring of string
  | AST_wstring of string
  | AST_ustring of string
  | AST_float of string * string

and axiom_kind_t = Axiom | Lemma
and axiom_method_t = Predicate of expr_t | Equation of expr_t * expr_t

(** {7 Expressions}
 *
 * Raw expression terms. *)
and expr_t =
  | EXPR_vsprintf of Flx_srcref.t * string
  | EXPR_map of Flx_srcref.t * expr_t * expr_t
  | EXPR_noexpand of Flx_srcref.t * expr_t
  | EXPR_name of Flx_srcref.t * string * typecode_t list
  | EXPR_the of Flx_srcref.t * qualified_name_t
  | EXPR_index of Flx_srcref.t * string * index_t
  | EXPR_case_tag of Flx_srcref.t * int
  | EXPR_typed_case of Flx_srcref.t * int * typecode_t
  | EXPR_lookup of Flx_srcref.t * (expr_t * string * typecode_t list)
  | EXPR_apply of Flx_srcref.t * (expr_t * expr_t)
  | EXPR_tuple of Flx_srcref.t * expr_t list
  | EXPR_record of Flx_srcref.t * (string * expr_t) list
  | EXPR_record_type of Flx_srcref.t * (string * typecode_t) list
  | EXPR_variant of Flx_srcref.t * (string * expr_t)
  | EXPR_variant_type of Flx_srcref.t * (string * typecode_t) list
  | EXPR_arrayof of Flx_srcref.t * expr_t list
  | EXPR_coercion of Flx_srcref.t * (expr_t * typecode_t)
  | EXPR_suffix of Flx_srcref.t * (qualified_name_t * typecode_t)

  | EXPR_patvar of Flx_srcref.t * string
  | EXPR_patany of Flx_srcref.t

  | EXPR_void of Flx_srcref.t
  | EXPR_ellipsis of Flx_srcref.t
  | EXPR_product of Flx_srcref.t * expr_t list
  | EXPR_sum of Flx_srcref.t * expr_t list
  | EXPR_intersect of Flx_srcref.t * expr_t list
  | EXPR_isin of Flx_srcref.t * (expr_t * expr_t)
  | EXPR_setintersection of Flx_srcref.t * expr_t list
  | EXPR_setunion of Flx_srcref.t * expr_t list
  | EXPR_orlist of Flx_srcref.t * expr_t list
  | EXPR_andlist of Flx_srcref.t * expr_t list
  | EXPR_arrow of Flx_srcref.t * (expr_t * expr_t)
  | EXPR_longarrow of Flx_srcref.t * (expr_t * expr_t)
  | EXPR_superscript of Flx_srcref.t * (expr_t * expr_t)

  | EXPR_literal of Flx_srcref.t * literal_t
  | EXPR_deref of Flx_srcref.t * expr_t
  | EXPR_ref of Flx_srcref.t * expr_t
  | EXPR_likely of Flx_srcref.t * expr_t
  | EXPR_unlikely of Flx_srcref.t * expr_t
  | EXPR_new of Flx_srcref.t * expr_t
  | EXPR_callback of Flx_srcref.t * qualified_name_t
  | EXPR_dot of Flx_srcref.t * (expr_t * expr_t)
  | EXPR_lambda of Flx_srcref.t * (vs_list_t * params_t list * typecode_t * statement_t list)

  (* this boolean expression checks its argument is
     the nominated union variant .. not a very good name for it
  *)
  | EXPR_match_ctor of Flx_srcref.t * (qualified_name_t * expr_t)

  (* this boolean expression checks its argument is the nominate
     sum variant
  *)
  | EXPR_match_case of Flx_srcref.t * (int * expr_t)

  (* this extracts the argument of a named union variant -- unsafe *)
  | EXPR_ctor_arg of Flx_srcref.t * (qualified_name_t * expr_t)

  (* this extracts the argument of a number sum variant -- unsafe *)
  | EXPR_case_arg of Flx_srcref.t * (int * expr_t)

  (* this just returns an integer equal to union or sum index *)
  | EXPR_case_index of Flx_srcref.t * expr_t (* the zero origin variant index *)

  | EXPR_letin of Flx_srcref.t * (pattern_t * expr_t * expr_t)

  | EXPR_get_n of Flx_srcref.t * (int * expr_t) (* get n'th component of a tuple *)
  | EXPR_get_named_variable of Flx_srcref.t * (string * expr_t) (* get named component of a class or record *)
  | EXPR_as of Flx_srcref.t * (expr_t * string)
  | EXPR_match of Flx_srcref.t * (expr_t * (pattern_t * expr_t) list)

  | EXPR_typeof of Flx_srcref.t * expr_t
  | EXPR_cond of Flx_srcref.t * (expr_t * expr_t * expr_t)

  | EXPR_expr of Flx_srcref.t * string * typecode_t

  | EXPR_type_match of Flx_srcref.t * (typecode_t * (typecode_t * typecode_t) list)

  | EXPR_macro_ctor of Flx_srcref.t * (string * expr_t)
  | EXPR_macro_statements of Flx_srcref.t * statement_t list

  | EXPR_user_expr of Flx_srcref.t * string * ast_term_t

(** {7 Patterns}
 *
 * Patterns; used for matching variants in match statements. *)
and float_pat =
  | Float_plus of string * string (** type, value *)
  | Float_minus of string * string
  | Float_inf  (** infinity *)
  | Float_minus_inf (** negative infinity *)

and pattern_t =
  | PAT_nan of Flx_srcref.t
  | PAT_none of Flx_srcref.t

  (* constants *)
  | PAT_int of Flx_srcref.t * string * string
  | PAT_string of Flx_srcref.t * string

  (* ranges *)
  | PAT_int_range of Flx_srcref.t * string * string * string * string
  | PAT_string_range of Flx_srcref.t * string * string
  | PAT_float_range of Flx_srcref.t * float_pat * float_pat

  (* other *)
  | PAT_coercion of Flx_srcref.t * pattern_t * typecode_t

  | PAT_name of Flx_srcref.t * id_t
  | PAT_tuple of Flx_srcref.t * pattern_t list
  | PAT_any of Flx_srcref.t
    (* second list is group bindings 1 .. n-1: EXCLUDES 0 cause we can use 'as' for that ?? *)
  | PAT_const_ctor of Flx_srcref.t * qualified_name_t
  | PAT_nonconst_ctor of Flx_srcref.t * qualified_name_t * pattern_t
  | PAT_as of Flx_srcref.t * pattern_t * id_t
  | PAT_when of Flx_srcref.t * pattern_t * expr_t
  | PAT_record of Flx_srcref.t * (id_t * pattern_t) list

(** {7 Statements}
 *
 * Statements; that is, the procedural sequence control system. *)
and param_kind_t = [`PVal | `PVar | `PFun | `PRef ]
and simple_parameter_t = id_t * typecode_t
and parameter_t = param_kind_t * id_t * typecode_t * expr_t option
and macro_parameter_type_t =
  | Ident
  | Expr
  | Stmt
and macro_parameter_t = id_t * macro_parameter_type_t
and lvalue_t = [
  | `Val of Flx_srcref.t * string
  | `Var of Flx_srcref.t * string
  | `Name of Flx_srcref.t * string
  | `Skip of Flx_srcref.t
  | `List of tlvalue_t list
  | `Expr of Flx_srcref.t * expr_t
]
and tlvalue_t = lvalue_t * typecode_t option

and funkind_t = [
  | `Function
  | `CFunction
  | `InlineFunction
  | `NoInlineFunction
  | `Virtual
  | `Ctor
  | `Generator
]

and property_t = [
  | `Recursive
  | `Inline
  | `NoInline
  | `Inlining_started
  | `Inlining_complete
  | `Generated of string
  | `Heap_closure        (* a heaped closure is formed *)
  | `Explicit_closure    (* explicit closure expression *)
  | `Stackable           (* closure can be created on stack *)
  | `Stack_closure       (* a stacked closure is formed *)
  | `Unstackable         (* closure cannot be created on stack *)
  | `Pure                (* closure not required by self *)
  | `Uses_global_var     (* a global variable is explicitly used *)
  | `Ctor                (* Class constructor procedure *)
  | `Generator           (* Generator: fun with internal state *)
  | `Yields              (* Yielding generator *)
  | `Cfun                (* C function *)
  | `Lvalue              (* primitive returns lvalue *)

  (* one of the below must be set before code generation *)
  | `Requires_ptf        (* a pointer to thread frame is needed *)
  | `Not_requires_ptf    (* no pointer to thread frame is needed *)

  | `Uses_gc             (* requires gc locally *)
  | `Virtual             (* interface in a typeclass *)
]

and type_qual_t = [
  | base_type_qual_t
  | `Raw_needs_shape of typecode_t
]

and requirement_t =
  | Body_req of code_spec_t
  | Header_req of code_spec_t
  | Named_req of qualified_name_t
  | Property_req of string
  | Package_req of code_spec_t

and ikind_t = [
  | `Header
  | `Body
  | `Package
]

and raw_req_expr_t =
  | RREQ_atom of requirement_t
  | RREQ_or of raw_req_expr_t * raw_req_expr_t
  | RREQ_and of raw_req_expr_t * raw_req_expr_t
  | RREQ_true
  | RREQ_false

and named_req_expr_t =
  | NREQ_atom of qualified_name_t
  | NREQ_or of named_req_expr_t * named_req_expr_t
  | NREQ_and of named_req_expr_t * named_req_expr_t
  | NREQ_true
  | NREQ_false

and prec_t = string
and params_t = parameter_t list * expr_t option (* second arg is a constraint *)

and ast_term_t =
  | Expression_term of expr_t
  | Statement_term of statement_t
  | Statements_term of statement_t list
  | Identifier_term of string
  | Keyword_term of string
  | Apply_term of ast_term_t * ast_term_t list

and statement_t =
  | STMT_include of Flx_srcref.t * string
  | STMT_open of Flx_srcref.t * vs_list_t * qualified_name_t

  (* the keyword for this one is 'inherit' *)
  | STMT_inject_module of Flx_srcref.t * qualified_name_t
  | STMT_use of Flx_srcref.t * id_t * qualified_name_t
  | STMT_comment of Flx_srcref.t * string (* for documenting generated code *)
  (*
  | STMT_public of Flx_srcref.t * string * statement_t
  *)
  | STMT_private of Flx_srcref.t * statement_t

  (* definitions *)
  | STMT_reduce of Flx_srcref.t * id_t * vs_list_t * simple_parameter_t list * expr_t * expr_t
  | STMT_axiom of Flx_srcref.t * id_t * vs_list_t * params_t * axiom_method_t
  | STMT_lemma of Flx_srcref.t * id_t * vs_list_t * params_t * axiom_method_t
  | STMT_function of Flx_srcref.t * id_t * vs_list_t * params_t * (typecode_t * expr_t option) * property_t list * statement_t list
  | STMT_curry of Flx_srcref.t * id_t * vs_list_t * params_t list * (typecode_t * expr_t option) * funkind_t * statement_t list

  (* macros *)
  | STMT_macro_name of Flx_srcref.t * id_t * id_t
  | STMT_macro_names of Flx_srcref.t * id_t * id_t list
  | STMT_expr_macro of Flx_srcref.t * id_t * macro_parameter_t list * expr_t
  | STMT_stmt_macro of Flx_srcref.t * id_t * macro_parameter_t list * statement_t list
  | STMT_macro_block of Flx_srcref.t * statement_t list
  | STMT_macro_val  of Flx_srcref.t * id_t list * expr_t
  | STMT_macro_vals  of Flx_srcref.t * id_t * expr_t list
  | STMT_macro_var  of Flx_srcref.t * id_t list * expr_t
  | STMT_macro_assign of Flx_srcref.t * id_t list * expr_t
  | STMT_macro_forget of Flx_srcref.t * id_t list
  | STMT_macro_label of Flx_srcref.t * id_t
  | STMT_macro_goto of Flx_srcref.t * id_t
  | STMT_macro_ifgoto of Flx_srcref.t * expr_t * id_t
  | STMT_macro_proc_return of Flx_srcref.t

  (* type macros *)
  | STMT_macro_ifor of Flx_srcref.t * id_t * id_t list * statement_t list
  | STMT_macro_vfor of Flx_srcref.t * id_t list * expr_t * statement_t list

  (* composition of statements: note NOT A BLOCK *)
  | STMT_seq of Flx_srcref.t * statement_t list

  (* types *)
  | STMT_union of Flx_srcref.t * id_t * vs_list_t * (id_t * int option * vs_list_t * typecode_t) list
  | STMT_struct of Flx_srcref.t * id_t * vs_list_t * (id_t * typecode_t) list
  | STMT_cstruct of Flx_srcref.t * id_t * vs_list_t * (id_t * typecode_t) list
  | STMT_type_alias of Flx_srcref.t * id_t * vs_list_t * typecode_t
  | STMT_inherit of Flx_srcref.t * id_t * vs_list_t * qualified_name_t
  | STMT_inherit_fun of Flx_srcref.t * id_t * vs_list_t * qualified_name_t

  (* variables *)
  | STMT_val_decl of Flx_srcref.t * id_t * vs_list_t * typecode_t option * expr_t option
  | STMT_lazy_decl of Flx_srcref.t * id_t * vs_list_t * typecode_t option * expr_t option
  | STMT_var_decl of Flx_srcref.t * id_t * vs_list_t * typecode_t option * expr_t option
  | STMT_ref_decl of Flx_srcref.t * id_t * vs_list_t * typecode_t option * expr_t option

  (* module system *)
  | STMT_untyped_module of Flx_srcref.t * id_t * vs_list_t * statement_t list
  | STMT_typeclass of Flx_srcref.t * id_t * vs_list_t * statement_t list
  | STMT_instance of Flx_srcref.t * vs_list_t * qualified_name_t * statement_t list

  (* control structures: primitives *)
  | STMT_label of Flx_srcref.t * id_t
  (*
  | STMT_whilst of Flx_srcref.t * expr_t * statement_t list
  | STMT_until of Flx_srcref.t * expr_t * statement_t list
  *)
  | STMT_goto of Flx_srcref.t * id_t
  | STMT_ifgoto of Flx_srcref.t * expr_t *id_t
  | STMT_ifreturn of Flx_srcref.t * expr_t
  | STMT_ifdo of Flx_srcref.t * expr_t * statement_t list * statement_t list
  | STMT_call of Flx_srcref.t * expr_t * expr_t
  | STMT_assign of Flx_srcref.t * string * tlvalue_t * expr_t
  | STMT_cassign of Flx_srcref.t * expr_t * expr_t
  | STMT_jump of Flx_srcref.t * expr_t * expr_t
  | STMT_loop of Flx_srcref.t * id_t * expr_t
  | STMT_svc of Flx_srcref.t * id_t
  | STMT_fun_return of Flx_srcref.t * expr_t
  | STMT_yield of Flx_srcref.t * expr_t
  | STMT_proc_return of Flx_srcref.t
  | STMT_halt of Flx_srcref.t  * string
  | STMT_trace of Flx_srcref.t  * id_t * string
  | STMT_nop of Flx_srcref.t * string
  | STMT_assert of Flx_srcref.t * expr_t
  | STMT_init of Flx_srcref.t * id_t * expr_t
  | STMT_stmt_match of Flx_srcref.t * (expr_t * (pattern_t * statement_t list) list)

  | STMT_newtype of Flx_srcref.t * id_t * vs_list_t * typecode_t

  (* binding structures [prolog] *)
  | STMT_abs_decl of Flx_srcref.t * id_t * vs_list_t * type_qual_t list * code_spec_t * raw_req_expr_t
  | STMT_ctypes of Flx_srcref.t * (Flx_srcref.t * id_t) list * type_qual_t list  * raw_req_expr_t
  | STMT_const_decl of Flx_srcref.t * id_t * vs_list_t * typecode_t * code_spec_t * raw_req_expr_t
  | STMT_fun_decl of Flx_srcref.t * id_t * vs_list_t * typecode_t list * typecode_t * code_spec_t * raw_req_expr_t * prec_t
  | STMT_callback_decl of Flx_srcref.t * id_t * typecode_t list * typecode_t * raw_req_expr_t
  (* embedding *)
  | STMT_insert of Flx_srcref.t * id_t * vs_list_t * code_spec_t * ikind_t  * raw_req_expr_t
  | STMT_code of Flx_srcref.t * code_spec_t
  | STMT_noreturn_code of Flx_srcref.t * code_spec_t

  | STMT_export_fun of Flx_srcref.t * suffixed_name_t * string
  | STMT_export_python_fun of Flx_srcref.t * suffixed_name_t * string
  | STMT_export_type of Flx_srcref.t * typecode_t * string

  | STMT_user_statement of Flx_srcref.t * string * ast_term_t
  | STMT_scheme_string of Flx_srcref.t * string

type exe_t =
  | EXE_code of code_spec_t (* for inline C++ code *)
  | EXE_noreturn_code of code_spec_t (* for inline C++ code *)
  | EXE_comment of string (* for documenting generated code *)
  | EXE_label of string (* for internal use only *)
  | EXE_goto of string  (* for internal use only *)
  | EXE_ifgoto of expr_t * string  (* for internal use only *)
  | EXE_call of expr_t * expr_t
  | EXE_jump of expr_t * expr_t
  | EXE_loop of id_t * expr_t
  | EXE_svc of id_t
  | EXE_fun_return of expr_t
  | EXE_yield of expr_t
  | EXE_proc_return
  | EXE_halt of string
  | EXE_trace of id_t * string
  | EXE_nop of string
  | EXE_init of id_t * expr_t
  | EXE_iinit of (id_t * index_t) * expr_t
  | EXE_assign of expr_t * expr_t
  | EXE_assert of expr_t

type sexe_t = Flx_srcref.t * exe_t

(** The whole of a compilation unit, this is the data structure returned by
 * parsing a whole file. *)
type compilation_unit_t = statement_t list

(* Convert types into source references *)
val src_of_qualified_name : qualified_name_t -> Flx_srcref.t
val src_of_suffixed_name : suffixed_name_t -> Flx_srcref.t
val src_of_typecode : typecode_t -> Flx_srcref.t
val src_of_expr : expr_t -> Flx_srcref.t
val src_of_stmt : statement_t -> Flx_srcref.t
val src_of_pat : pattern_t -> Flx_srcref.t

(* Convert typecode to a qualified name *)
val typecode_of_qualified_name : qualified_name_t -> typecode_t
val qualified_name_of_typecode : typecode_t -> qualified_name_t option

val rsexpr : expr_t -> expr_t -> Flx_srcref.t
val rslist : expr_t list -> Flx_srcref.t

(** Define a default vs_aux_t. *)
val dfltvs_aux : vs_aux_t

(** Define a default vs_list_t. *)
val dfltvs : 'a list * vs_aux_t

(** Prints out a code_spec_t to a formatter. *)
val print_code_spec : Format.formatter -> code_spec_t -> unit

(** Prints out a base_type_qual_t to a formatter. *)
val print_base_type_qual : Format.formatter -> base_type_qual_t -> unit

(** Prints out a literal_t to a formatter. *)
val print_literal : Format.formatter -> literal_t -> unit

(** Prints out a property_t to a formatter. *)
val print_property : Format.formatter -> property_t -> unit

(** Prints out a property list to a formatter. *)
val print_properties : Format.formatter -> property_t list -> unit

(** Prints out a param_kind_t to a formatter. *)
val print_param_kind : Format.formatter -> param_kind_t -> unit
