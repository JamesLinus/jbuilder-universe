open Base
open Stdio
open Expect_test_common.Std

let fprintf = Out_channel.fprintf

module Test_outcome = struct
  type t =
    { expectations    : Fmt.t Cst.t Expectation.t Map.M(File.Location).t
    ; saved_output    : string Map.M(File.Location).t
    ; trailing_output : string
    }
end

module Test_correction = struct
  type node_correction =
    | Collector_never_triggered
    | Correction of Fmt.t Cst.t Expectation.Body.t

  type t =
    { location        : File.Location.t
    ; (* In the order of the file *)
      corrections     : (Fmt.t Cst.t Expectation.t * node_correction) list
    ; trailing_output : Fmt.t Cst.t Expectation.Body.t Reconcile.Result.t
    }

  let map_corrections t ~f =
    { location = t.location
    ; corrections = List.map t.corrections ~f:(fun (e, c) ->
        (e, match c with
         | Collector_never_triggered -> c
         | Correction body -> Correction (Expectation.Body.map_pretty body ~f)))
    ; trailing_output =
        Reconcile.Result.map t.trailing_output ~f:(Expectation.Body.map_pretty ~f)
    }
  ;;

  let compare_locations a b = compare a.location.line_number b.location.line_number

  let make ~location ~corrections ~trailing_output : t Reconcile.Result.t =
    if List.is_empty corrections &&
       match trailing_output with
       | Reconcile.Result.Match -> true
       | _ -> false then
      Match
    else
      Correction { location; corrections; trailing_output }
  ;;
end

let indentation_at file_contents (loc : File.Location.t) =
  let n = ref loc.line_start in
  while Char.equal file_contents.[!n] ' ' do Int.incr n done;
  !n - loc.line_start
;;

let evaluate_test ~file_contents ~(location : File.Location.t) (test : Test_outcome.t) =
  let corrections =
    Map.fold test.expectations ~init:[]
      ~f:(fun ~key:location ~data:(expect:Fmt.t Cst.t Expectation.t) corrections ->
        match Map.find test.saved_output location with
        | None -> (expect, Test_correction.Collector_never_triggered) :: corrections
        | Some actual ->
          let default_indent = indentation_at file_contents expect.body_location in
          match
            Reconcile.expectation_body
              ~expect:expect.body
              ~actual
              ~default_indent
              ~pad_single_line:(Option.is_some expect.tag)
          with
          | Match -> corrections
          | Correction c -> (expect, Test_correction.Correction c) :: corrections)
    |> List.rev
  in

  let trailing_output =
    let indent = location.start_pos - location.line_start + 2 in
    Reconcile.expectation_body
      ~expect:(Pretty Cst.empty)
      ~actual:test.trailing_output
      ~default_indent:indent
      ~pad_single_line:true
  in

  Test_correction.make ~location ~corrections ~trailing_output
;;

type mode = Inline_expect_test | Toplevel_expect_test

let output_slice out s a b =
  Out_channel.output_string out (String.sub s ~pos:a ~len:(b - a))
;;

let rec output_semi_colon_if_needed oc file_contents pos =
  if pos >= 0 then
    match file_contents.[pos] with
    | '\t' | '\n' | '\011' | '\012' | '\r' | ' ' ->
      output_semi_colon_if_needed oc file_contents (pos - 1)
    | ';' -> ()
    | _ -> Out_channel.output_char oc ';'
;;

let split_lines s = String.split s ~on:'\n'

let output_corrected oc ~file_contents ~mode test_corrections =
  let id_and_string_of_body : _ Expectation.Body.t -> string * string = function
    | Exact  x -> ("expect_exact", x)
    | Pretty x -> ("expect", Cst.to_string x)
  in
  let output_body oc tag body =
    match tag with
    | None ->
      fprintf oc "\"%s\""
        (String.concat ~sep:"\n" (split_lines body |> List.map ~f:String.escaped))
    | Some tag ->
      let tag = Choose_tag.choose ~default:tag body in
      fprintf oc "{%s|%s|%s}" tag body tag
  in
  let ofs =
    List.fold_left test_corrections ~init:0
      ~f:(fun ofs (test_correction : Test_correction.t) ->
        let ofs =
          List.fold_left test_correction.corrections ~init:ofs
            ~f:(fun ofs (e, correction) ->
              match (correction : Test_correction.node_correction) with
              | Collector_never_triggered ->
                output_slice oc file_contents ofs e.Expectation.body_location.start_pos;
                output_body oc e.tag " DID NOT REACH THIS PROGRAM POINT ";
                e.body_location.end_pos
              | Correction c ->
                let id, body = id_and_string_of_body c in
                output_slice oc file_contents ofs e.extid_location.start_pos;
                Out_channel.output_string oc id;
                output_slice oc file_contents e.extid_location.end_pos
                  e.body_location.start_pos;
                output_body oc e.tag body;
                e.body_location.end_pos)
        in
        match test_correction.trailing_output with
        | Match -> ofs
        | Correction c ->
          let loc = test_correction.location in
          output_slice oc file_contents ofs loc.end_pos;
          if match mode with Inline_expect_test -> true | _ -> false then
            output_semi_colon_if_needed oc file_contents loc.end_pos;
          let id, body = id_and_string_of_body c in
          (match mode with
           | Inline_expect_test ->
             let indent = loc.start_pos - loc.line_start + 2 in
             fprintf oc "\n%*s[%%%s " indent "" id
           | Toplevel_expect_test ->
             if loc.end_pos = 0 || Char.(<>) file_contents.[loc.end_pos - 1] '\n' then
               Out_channel.output_char oc '\n';
             fprintf oc "[%%%%%s" id);
          output_body oc (Some "") body;
          fprintf oc "]";
          loc.end_pos)
  in
  output_slice oc file_contents ofs (String.length file_contents)
;;

let write_corrected ~file ~file_contents ~mode test_corrections =
  Out_channel.with_file file ~f:(fun oc ->
    output_corrected oc ~file_contents ~mode
      (List.sort test_corrections ~cmp:Test_correction.compare_locations))
;;
