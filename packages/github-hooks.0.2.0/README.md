## github-hooks -- GitHub API web hook listener library

Library to create GitHub webhook server.

### Web hook tests

This repository contains a GitHub web hook test harness that confirms
that ocaml-github can parse both polled and web-hook-received events and
that the expected events are delivered in the correct order. To run the
`test_hook_server` program, you must have a publicly accessible IP
address with a DNS `A` record and a TLS certificate. You can use [Let's
Encrypt](https://letsencrypt.org/) to get a TLS certificate for your
domain for free. `test_hook_server` should be run from an account on the
public-facing machine which also has agent access to an SSH key which is
registered with GitHub. I recommend using a remote VM for the domain and
forwarding a local ssh agent with something like `ssh -A example.net`.

Once this is configured, place your TLS certificate in the file
`webhook.crt` and the key for that certificate in
`webhook.key`. Generate a personal GitHub token named `test` with `git
jar make --scopes=admin:repo_hook,delete_repo,repo [GitHub token
username] test` (with the `git-jar` subcommand from
[mirage/ocaml-github](https://github.com/mirage/ocaml-github)) which has
`admin:repo_hook`, `delete_repo`, and `repo` authority scopes. This
token has quite a lot of authority so it is important to keep safe or
use a test account rather than your primary GitHub account.

Finally, run `make test` and then `_build/test/test_hook_server.native
https://example.net:4433 [GitHub token username] test-github-hooks
[GitHub SSH username]` to run the tests on your server at `example.net`
on port `4433` as the user `[GitHub token username]` but git-pushing as the
user `[GitHub SSH username]`. The test program will create and delete the
repository `test-github-hooks` in the process of running. If the tests
fail, you may have to remove the cloned repository called
`test-github-hooks` and the GitHub repository `[GitHub token
username]/test-github-hooks`.
