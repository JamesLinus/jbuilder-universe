**Malfunction** is a high-performance, low-level untyped program
representation, designed as a target for compilers of functional
programming languages.

**Malfunction** is a revolting hack, exposing bits of the OCaml
compiler's guts that were never meant to see the light of day.

"Hello, World" looks like this:

    (module
      (_ (apply (global $Pervasives $print_string) "Hello, world!\n"))
      (export))

Malfunction requires a recent version of OCaml with flambda enabled,
which you can get by doing:

    opam switch 4.05.0+flambda

Then, install malfunction using:

    opam pin add malfunction git://github.com/stedolan/malfunction.git

You can then compile and run the above example with:

    malfunction compile docs/helloworld.mlf -o hello
    ./hello

The syntax is based on s-expressions, and is designed to be easy to
correctly generate, rather than to be particularly beautiful. For
instance, there are no reserved words: all user-defined identifiers
must be prefixed with `$`.

Files are compiled as OCaml modules, and may import values from OCaml
(e.g. `Pervasives.print_string` in the example above) and export
values to OCaml (using the `export` form). Modules written in
malfunction may be combined with an `mli` file written in OCaml.

Malfunction makes no effort to check types. Typical programs do go
wrong. Compilers targeting Malfunction need to convince themselves
that their output won't go wrong, but don't need to explain
their reasoning.

For more, read the [spec](./docs/spec.md), or the
[abstract submitted to the ML Workshop](http://www.cl.cam.ac.uk/~sd601/papers/malfunction.pdf),
or [some examples](./docs)

There's also an
[experimental backend](https://github.com/stedolan/idris-malfunction)
for the dependently typed language [Idris](http://idris-lang.org).
