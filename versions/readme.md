## versions/README.md (Separate Codebase)

The `versions/` directory is treated as a **separate codebase** from the main CmdMind release.

Nothing inside `versions/` is:

* Loaded by default
* Installed by `setup_cmdmind.sh`
* Considered stable or production-ready

### Purpose

This codebase exists to:

* Explore breaking changes safely
* Prototype new UX or execution models
* Test alternative safety flows or prompts

### Rules (Strict)

* No imports, symlinks, or sourcing from root files
* Each version is self-contained
* Each version must include its own README explaining:

  * What changed
  * Why it exists
  * Known risks

Example:

```text
versions/
├── v2/
│   ├── cmdmind.sh
│   └── README.md
├── experimental/
└── prototypes/
```

If something breaks here, **that is expected**.

---
