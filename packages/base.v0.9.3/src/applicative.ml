open! Import

include Applicative_intf

module Make2 (X : Basic2) : S2 with type ('a, 'e) t := ('a, 'e) X.t = struct

  include X

  let (<*>) = apply

  let derived_map t ~f = return f <*> t

  let map =
    match X.map with
    | `Define_using_apply -> derived_map
    | `Custom x -> x

  let map2 ta tb ~f = map ~f ta <*> tb

  let map3 ta tb tc ~f = map ~f ta <*> tb <*> tc

  let all ts = List.fold_right ts ~init:(return []) ~f:(map2 ~f:(fun x xs -> x :: xs))

  let both ta tb = map2 ta tb ~f:(fun a b -> (a, b))

  let ( *> ) u v = return (fun () y -> y) <*> u <*> v
  let ( <* ) u v = return (fun x () -> x) <*> u <*> v

  let all_ignore ts = List.fold ts ~init:(return ()) ~f:( *> )

  module Applicative_infix = struct
    let ( <*> ) = ( <*> )
    let (  *> ) = (  *> )
    let ( <*  ) = ( <*  )
  end
end

module Make (X : Basic) : S with type 'a t := 'a X.t = Make2 (struct
    type ('a, 'e) t = 'a X.t
    include (X : Basic with type 'a t := 'a X.t)
  end)

module Make_args' (X : S2) = struct
  open X

  type ('f, 'r, 'e) t_ = { applyN : ('f, 'e) X.t -> ('r, 'e) X.t }

  let nil = { applyN = fun x -> x }

  let cons arg t = { applyN = fun d -> t.applyN (apply d arg) }

  let step t ~f = { applyN = fun d -> t.applyN (map ~f d) }

  let (@>) = cons

  let applyN arg t = t.applyN arg

  let mapN ~f t = applyN (return f) t
end

module Make_args (X : S) : Args with type 'a arg := 'a X.t = struct
  include Make_args' (struct
      type ('a, 'e) t = 'a X.t
      include (X : S with type 'a t := 'a X.t)
    end)

  type ('f, 'r) t = ('f, 'r, unit) t_
end

module Make_args2 (X : S2) : Args2 with type ('a, 'e) arg := ('a, 'e) X.t = struct
  include Make_args' (X)

  type ('f, 'r, 'e) t = ('f, 'r, 'e) t_
end

module Of_monad (M : Monad.S) : S with type 'a t := 'a M.t =
  Make (struct
    type 'a t = 'a M.t
    let return = M.return
    let apply mf mx = M.bind mf ~f:(fun f -> M.map mx ~f)
    let map = `Custom M.map
  end)

module Compose (F : S) (G : S) : S with type 'a t = 'a F.t G.t = struct
  type 'a t = 'a F.t G.t
  include Make (struct
      type nonrec 'a t = 'a t
      let return a = G.return (F.return a)
      let apply tf tx = G.apply (G.map ~f:F.apply tf) tx
      let custom_map t ~f = G.map ~f:(F.map ~f) t
      let map = `Custom custom_map
    end)
end

module Pair (F : S) (G : S) : S with type 'a t = 'a F.t * 'a G.t = struct
  type 'a t = 'a F.t * 'a G.t
  include Make (struct
      type nonrec 'a t = 'a t
      let return a = (F.return a, G.return a)
      let apply tf tx = (F.apply (fst tf) (fst tx), G.apply (snd tf) (snd tx))
      let custom_map t ~f = (F.map ~f (fst t), G.map ~f (snd t))
      let map = `Custom custom_map
    end)
end

module Const (Monoid : sig
    type t
    val zero : t
    val plus : t -> t -> t
  end) : S with type 'a t = Monoid.t = struct
  type _ t = Monoid.t
  include Make (struct
      type nonrec 'a t = 'a t
      let return _a = Monoid.zero
      let apply tf tx = Monoid.plus tf tx
      let custom_map t ~f:_ = t
      let map = `Custom custom_map
    end)
end
