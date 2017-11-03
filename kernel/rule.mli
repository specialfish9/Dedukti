open Basic
open Term


(** Rewrite rules *)

(** {2 Patterns} *)

type pattern =
  | Var         of loc * string * int * pattern list
      (** l x i [x1 ; x2 ; ... ; xn ] where [i] is the position of x inside the context
          of the rule *)
  | Pattern     of loc * Name.ident * pattern list
      (** l n [p1 ; p2 ; ... ; pn ] where [md.id] is a constant *)
  | Lambda      of loc * string * pattern
      (** lambda abstraction *)
  | Brackets    of term
      (** te where [te] is convertible to the pattern matched *)

val get_loc_pat : pattern -> loc

val pattern_to_term : pattern -> term

(** a wf_pattern is a Miller pattern without brackets constraints and each free variable appear exactly once. *)
type wf_pattern =
  | LJoker
  | LVar         of string * int * int list
  | LLambda      of string * wf_pattern
  | LPattern     of Name.ident * wf_pattern array
  | LBoundVar    of string * int * wf_pattern array

(** {2 Linarization} *)

val allow_non_linear : bool ref

(** constr is the type of constraints. They are generated by the function check_patterns *)
type constr =
  | Linearity of int * int (** DB indices [i] and [j] of the pattern should be convertible *)
  | Bracket of int * term (** DB indicies [i] should be convertible to the term [te] *)

(** Check_patterns [i] [ps] checks that if the list of patterns [ps] with a context of size [i] are Miller's pattern. Moreover, if these patterns are non-linear
    or contains brackets, then constraints are generated *)
val check_patterns : int -> pattern list -> (int * wf_pattern list * constr list)

(** {2 Contexts} *)

(** context of rules after they have been parsed *)
type untyped_context = (loc * string) list

(** type checking rules implies to give a type to the variables of the context *)
type typed_context = ( loc * string * term ) list

(** {2 Rewrite Rules} *)

(** Delta rules are the rules associated to the definition of a constant while Gamma rules are the rules of lambda pi modulo. The first paraneter of Gamma indicates if the name of the rule has been given by the user. *)
type rule_name = Delta of Name.ident | Gamma of bool * Name.ident

val pp_rule_name : Format.formatter -> rule_name -> unit

type 'a rule =
  {
    name: rule_name;
    ctx: 'a;
    pat: pattern;
    rhs:term
  }

type untyped_rule = untyped_context rule

val pp_untyped_rule : Format.formatter -> untyped_rule -> unit

type typed_rule = typed_context rule

val pp_typed_rule : Format.formatter -> typed_rule -> unit

(** {2 Errors} *)

type rule_error =
  | BoundVariableExpected of pattern
  | DistinctBoundVariablesExpected of loc * string
  | VariableBoundOutsideTheGuard of term
  | UnboundVariable of loc * string * pattern
  | AVariableIsNotAPattern of loc * string
  | NonLinearRule of typed_rule
  | NotEnoughArguments of loc * string * int * int * int

(** {2 Rule infos} *)

type rule_infos = {
  l : loc; (** location of the rule *)
  name : rule_name; (** name of the rule *)
  ctx : typed_context; (** typed context of the rule *)
  cst : Name.ident; (** name of the pattern constant *)
  args : pattern list; (** arguments list of the pattern constant *)
  rhs : term; (** right hand side of the rule *)
  esize : int; (** size of the context *)
  l_args : wf_pattern array; (** free pattern without constraint *)
  constraints : constr list; (** constraints generated from the pattern to the free pattern *)
}

val pattern_of_rule_infos : rule_infos -> pattern

val to_rule_infos : typed_rule -> (rule_infos, rule_error) error

(** {2 Printing} *)

val pp_pattern : Format.formatter -> pattern -> unit

val pp_wf_pattern : Format.formatter -> wf_pattern -> unit

val pp_untyped_context : Format.formatter -> untyped_context -> unit

val pp_typed_context : Format.formatter -> typed_context -> unit

val pp_rule_infos : Format.formatter -> rule_infos -> unit
