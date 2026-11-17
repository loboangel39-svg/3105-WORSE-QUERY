# RC12 Final Fix — Apply

Apply remains the original `PatchTransaction` flow. Existing target bytes are
copied before writes into that transaction's `.original` backup and verified.
Different previous content is not an Apply rejection. An active prepared or
applied receipt remains exclusive; when no active receipt exists, a new Apply
creates a new transaction reference from the current bytes.
