# RC12 Final Fix — Files/Patches alignment

Both surfaces resolve by Bundle ID through `ContainerStore`. Files refreshes
that resolution when loading, while Apply/Restore resolve immediately before
their operation. Sessions remain owned for the operation lifetime. Read access
does not imply write access; each path retains its explicit access mode.
