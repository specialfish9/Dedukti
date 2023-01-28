(** A process module processes entries. It is parameterized by an environment. *)

(** {1 How to use processors} *)

(** As a user of the API of Dedukti, processors are the main entry point.
    The point of processors is to handle automatically inputs and files for you.
    The API of Dedukti has already defined 5 processors for you, but you are free
    to define more. This 5 processors are:
    - TypeChecker : to type check the input
    - SignatureBuilder : to construct a signature without type checking it
    - Printer : to pretty print the input
    - Dependencies : Compute dependencies of the input
    - TopLevel : TypeCheck and prints and standard output

    Processors should be used through the methods:
    - handle_input : to process one input
    - handle_files : to process a set of files
    - fold_files : to process a set of files and fold the results

    Mose of the time, we want to apply some operations before processing one
    file and some operations after. To do so, the API declares a type [hook]
    that can be given optionaly to the functions mentioned above.
    In particular, a hook allows to handle errors that may have been raised
    by the processor. By default, any error raised by the processor stops
    the execution of the processor and are pretty printed via the module [Errors].
    This applies also for errors generated at parsing/scoping time for the functions
    which handle files.

    We also recall that for [handle_input], a processor consumes an [input]. As such,
    the [input] will not be reusable once it has been processed. This is because a
    Dedukti [input] is an abstraction for a stream of [Entry.entry].

    If you want to create your own processor, we invite you to go to Section {2} of
    this documentation.
*)

(** This is the type of errors returned by a processor *)
type processor_error = Env.t * Kernel.Basic.loc * exn

(** To hook an input before and after it is being processed *)
type hook = {
  before : Parsers.Parser.input -> Env.t -> unit;
      (** hook_before is executed by the processor before processing the input *)
  after : Parsers.Parser.input -> Env.t -> processor_error option -> unit;
      (** hook_after is executed by the processor after processing the output *)
}

module type S = sig
  (** result type of the processor *)
  type t = Env.t

  type output

  (** [handle_entry env entry] processed the entry [entry] in the environment [env] *)
  val handle_entry : t -> Parsers.Entry.entry -> t

  (** [get_data ()] returns the data computed by the current processor *)
  val output : t -> output
end

(** {2 Implement its own processor} *)

(** The type [t] given above hides the complexity of a processor. Under the hood,
    a processor is actually a module of type [S] (see below). This module declares
    one type and two function. The type [S.t] is the type of the result computed by
    the processor. It is the same as ['a] in ['a t], the type declared above.
    For example, the processor [Dependencies] as type [Deps.t t]. It is implemented
    by a module of type [S] where [S.t = Deps.t].

    A processor acts on top-level commands of Dedukti which are represented by the
    type [Parsers.Entry.entry] and are paremeterized by an environement [Env.t].
    The module [Env] is the view of the API of the kernel of Dedukti. The type [Env.t]
    are paremeters for the kernel. In particular, it knows where to look for the next
    [entry], how to reduce a term, how to type check a term etc...

    Hence, a processor implements a function [handle_entry env entry] which is
    called successively on each entry (if no exception are triggered).

    Finally, to get the result of a processor, we use the function [get_data env].

    These are the three things you need to define to declare a new processor.
    Once your processor has been defined, to be able to use the API above, you need
    to register you processor. The registration step is actually really easy.
    To register a processor, you need to do three things.
    1. First, you need to extend the type [t] with a new constructor for your processor
    2. Declare a trivial equality function for your new constructor (see below)
    3. Call the Register function with your new constructor, your processor (as a module) and
    your equality function.

    If you look at the type of the equality function and the register function it seems ugly.
    To understand how it works, we will give you an example. Assume your new processor is
    a module [Foo] such that [Foo.t = foo]. Then for the first step you do :

    type _ t += Foo : foo t

    For the second step you declare the following function

    let equal_foo (type a b) : (a t * b t) -> (a t,b t) Registration.equal option =
    function
    | Foo, Foo -> Some (Registration.Refl (Foo))
    | _ -> None

    For the third step you call the registration function this way :

    let () = Registration.register_processor Foo {equal = equal_foo} (module Foo);

    And then you are ready to go!

    The current version allows you to shadow a previously known [Processor], be careful with that.

    Finally, in this section we declare an [of pure] function which allows you to define a processor
    by calling a function and without using the syntax of modules.
*)

type 'a t = (module S with type output = 'a)

(** [handle_input ?hook ~load_path ~input processor] applies the
     processor [processor] on the [input] using [load_path] (see
     {!module:Files}). [hook.hook_before] is executed once before the
     processor and [hook.hook_after] is executed once after the
     processor.  By default (without hooks), if an exception [exn] has
     been raised while processing the data it is raised at
     top-level. *)
val handle_input :
  ?hook:hook -> Files.load_path -> input:Parsers.Parser.input -> 'a t -> 'a

(** [handle_files ?hook files processor] apply a processor on each file of
     [files].  [hook] is used once by file. The result is the one
     given once each file has been processed. *)
val handle_files :
  ?hook:hook -> Files.load_path -> files:string list -> 'a t -> 'a

(** [fold_files ?hook ~load_path ~files ~f ~default processor] is the
   [fold] variant of [handle_files]. *)
val fold_files :
  ?hook:hook ->
  Files.load_path ->
  files:string list ->
  f:('a -> 'b -> 'b) ->
  default:'b ->
  'a t ->
  'b

val typecheck : unit t

val get_signature : Kernel.Signature.t t

val top_level : unit t

val get_deps : Dep_legacy.t t

val print : unit t
