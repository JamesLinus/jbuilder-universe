(*
 * Copyright (c) 2015 Unikernel Systems
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

let src =
   let src = Logs.Src.create "test" ~doc:"Test ASL using the logs library" in
   Logs.Src.set_level src (Some Logs.Debug);
   src

module Log = (val Logs.src_log src : Logs.LOG)

let _ =
  let client = Asl.Client.create ~ident:(Sys.executable_name) ~facility:"Daemon" () in
  Logs.set_reporter (Log_asl.reporter ~client ());
  Log.err (fun f -> f "This is an error");
  Log.info (fun f -> f "This is informational");
  Log.debug (fun f -> f "This is lowly debugging data");
  ()
