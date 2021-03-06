module type S0 = sig
  type elt
  type t

  val fold: init:'b -> t -> f:('b -> elt -> 'b) -> 'b
  val fold_i: init:'b -> t -> f:(i:int -> 'b -> elt -> 'b) -> 'b
  val fold_acc: acc:'acc -> init:'b -> t -> f:(acc:'acc -> 'b -> elt -> 'acc * 'b) -> 'b
end

module type S1 = sig
  type 'a t

  val fold: init:'b -> 'a t -> f:('b -> 'a -> 'b) -> 'b
  val fold_i: init:'b -> 'a t -> f:(i:int -> 'b -> 'a -> 'b) -> 'b
  val fold_acc: acc:'acc -> init:'b -> 'a t -> f:(acc:'acc -> 'b -> 'a -> 'acc * 'b) -> 'b
end
