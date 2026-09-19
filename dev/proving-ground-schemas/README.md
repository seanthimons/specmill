# Base proving-ground schemas

`specmill-testing-base-schemas.zip` transfers the base schema inputs from the
local `specmill-testing` proving ground to another device without copying its
generated R package or depending on access to the original API servers.
Keeping this snapshot lets development on another device use the same inputs.

Captured on 2026-09-19. The archive contains this README and 58 unchanged JSON
files, preserving their paths beneath `specmill-testing/`:

- 31 root-level source files, including existing alternate filenames.
- 27 files in `schema/`, used by the current proving-ground API configurations.

The archive deliberately excludes `additional-schemas/` (the separate stress-test
collection), generated R files, caches, credentials, and project configuration.
It provides schema inputs, not a complete runnable copy of the proving ground;
generation policies and API configuration must be recreated separately.

## Transfer

Download the ZIP from the development branch and extract it into a new directory
on the other device. In PowerShell, for example:

```powershell
Expand-Archive -LiteralPath ./specmill-testing-base-schemas.zip -DestinationPath ./schema-transfer
```

The inputs will be under `schema-transfer/specmill-testing/`. Use a new
destination to avoid overwriting a pre-existing proving ground. Preserve the
directory layout for relative schema references.

These files are snapshots of the original API descriptions, not refreshed
downloads or normalized replacements. The collection is intended for schema
parsing and generation work; transferring it does not grant live API access.
