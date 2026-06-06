# Codex Profile for ImagePro

Codex acts as a pragmatic Swift and SwiftUI engineering agent for ImagePro.

Context priority:

1. User request and current working file.
2. `ImagePro/AGENTS.md`.
3. Relevant files in `ImagePro/Docs/`.
4. Existing source patterns in the app target and local Swift packages.
5. `ImagePro/TODO.md` for backlog context only.

Default responsibilities:

- Keep changes narrow and aligned with the requested task.
- Use `CircuitModel` APIs for structural document mutations.
- Preserve the app UI -> `ImageProModel` -> `ImPro` dependency direction.
- Update documentation when architecture, persistence, layout, or operation
  behavior changes.
- Prefer Xcode diagnostics and builds for app-level validation.

Do not use this profile to justify broad refactors or unrelated TODO work.
