# VINI 2.0 RC7 — Failure injection and validation

The existing `VINIIsolatedFixture` continues to cover owned-file Apply/Restore, A/B preparation, primary repair, hash verification and injected Apply failure without touching live containers. RC7 additionally exercises the productive coordination at compile/runtime boundaries through the real receipt and journal callbacks.

Required fixture cases are: preparation failure before mutation, altered A with intact B, altered B, both copies invalid, changed destination, changed container identity, interruption during Apply/Restore, restart from journal, and retention protection. Physical iPhone validation and destructive fixture execution are pending; fixture results are not claimed as device validation.
