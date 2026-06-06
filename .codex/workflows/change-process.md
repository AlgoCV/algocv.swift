# Change Process

Use this workflow for Codex changes in ImagePro.

1. Identify the touched layer: SwiftUI app, `ImageProModel`, `ImPro`, docs, or a
   narrow combination of those layers.
2. Read `ImagePro/AGENTS.md` and the relevant documentation in `ImagePro/Docs/`
   before editing architecture-sensitive code.
3. Prefer existing model APIs for graph mutations. UI code should not bypass
   `CircuitModel` helpers for structural changes.
4. Keep edits scoped to the requested behavior. Avoid unrelated cleanups,
   formatting churn, and project-file changes unless they are required.
5. Update `ImagePro/Docs/` when the change alters document state, layout
   behavior, operation semantics, processing flow, persistence, or user-visible
   workflows.
6. Run the smallest validation that covers the change, then broaden validation
   when shared model behavior or persistence is affected.

For SwiftUI work, preserve the existing document-app interaction model:
`ScriptDesigner` owns editor composition, `EphemeralState` owns transient
selection/status, and `CircuitModel` owns persistent document state.
