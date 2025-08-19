## Attempts to apply multiple macro operations against defined files in Neovim.

Put all your files in the argument list:

 `:args *.sql`

See :help :args.

Run your macro on every file in the argument list:

 `:argdo :normal @q`

See :help :argdo, :help :normal.

Write them to disc:

 `:argdo :write`


