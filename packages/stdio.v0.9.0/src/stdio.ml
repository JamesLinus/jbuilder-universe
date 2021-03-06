open! Import

module In_channel  = In_channel
module Out_channel = Out_channel

let stdin  = In_channel.stdin
let stdout = Out_channel.stdout
let stderr = Out_channel.stderr

let eprintf       = Out_channel.eprintf
let printf        = Out_channel.printf
let print_endline = Out_channel.print_endline
let prerr_endline = Out_channel.prerr_endline
