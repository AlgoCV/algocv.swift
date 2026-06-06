# ImagePro Agent Guide

## Project Structure

The repository is organized around a SwiftUI document app and two local Swift packages:

- `ImagePro/`: Xcode app project and application source.
- `ImagePro/ImagePro/`: main SwiftUI app target.
- `ImagePro/ImagePro/ImageProApp.swift`: app entry point. Creates a `DocumentGroup` backed by `CircuitModel`, installs document environment values, and wires app commands.
- `ImagePro/ImagePro/AppActions.swift`: small action wrappers used by menus and command-style UI.
- `ImagePro/ImagePro/Controls/`: shared SwiftUI controls and view extensions.
- `ImagePro/ImagePro/ScriptDesigner/`: main document editing experience.
- `ImagePro/ImagePro/ScriptDesigner/Document/`: top-level designer view, document focus keys, toolbar, and command definitions.
- `ImagePro/ImagePro/ScriptDesigner/View/Canvas/`: graph canvas, node/segue rendering, zooming, panning, selection rectangle, grid overlay, and add controls.
- `ImagePro/ImagePro/ScriptDesigner/View/Chrome/`: sidebar and surrounding document chrome.
- `ImagePro/ImagePro/ScriptDesigner/View/Node/`: node-specific views and image display surfaces.
- `ImagePro/ImagePro/ScriptDesigner/View/Segue/`: segue-specific views and connection display.
- `ImagePro/ImagePro/ScriptDesigner/Inspector/`: inspector shell, pages, reusable inspector sections, and operation parameter editors.
- `ImagePro/ImagePro/ScriptDesigner/Commands/`: toolbar/menu/context-menu actions for graph, node, segue, selection, operation, and image-import workflows.
- `ImagePro/ImagePro/ScriptDesigner/State/`: ephemeral UI state, selection state, status messages, and settings storage/defaults.
- `ImagePro/ImagePro/ScriptDesigner/Shared/`: designer-specific geometry, model extensions, notes, and operation UI helpers.
- `ImagePro/Docs/`: design and architecture notes. `Operations.md` documents the operation type/preset/operator model.
- `ImagePro/TODO.md`: current backlog and known product work.
- `ImagePro/ImageProTests/`: app unit tests.
- `ImagePro/ImageProUITests/`: UI automation tests.
- `ImageProModel/`: Swift package containing the document model, graph entities, processing pipeline, serialization, image import, layout, history, and operation catalog.
- `ImageProModel/Sources/CircuitModel/`: `CircuitModel` and mutations for creation, deletion, duplication, graph updates, undo/redo, and related model behavior.
- `ImageProModel/Sources/GraphEntities/`: core graph objects such as `Graph`, `Source`, `Segue`, `Sink`, and graph state.
- `ImageProModel/Sources/GraphLayout/`: automatic graph arrangement and layout planning.
- `ImageProModel/Sources/History/`: history message types and recording helpers.
- `ImageProModel/Sources/ImageImport/`: source-image import model logic and error reporting.
- `ImageProModel/Sources/Images/`: platform image abstractions, image display data, lookup tables, and image sizing helpers.
- `ImageProModel/Sources/Operations/`: operation types, presets, ImPro operator metadata, conversion helpers, execution, and operation preset library storage.
- `ImageProModel/Sources/Processing/`: graph processing job construction, progress tracking, execution scheduling, and output application.
- `ImageProModel/Sources/Serialization/`: DTOs used for document persistence.
- `ImageProModel/Tests/`: model-level script and graph operation tests.
- `ImPro/`: Swift package wrapping the lower-level ImPro C/Zig libraries.
- `ImPro/Sources/CImPro/`: system library target exposing the native ImPro headers.
- `ImPro/Sources/ImPro/`: Swift API over the native image-processing library.
- `ImPro/Tests/`: package tests, smoke tests, and shared check support.

## Architecture

ImagePro is a SwiftUI document-based image-processing graph editor. Each open document is a `CircuitModel`, which conforms to `ReferenceFileDocument` and persists through JSON DTO snapshots. The app entry point creates new documents with default view and model settings, injects the model into the SwiftUI environment, and exposes it through focused scene values so commands, toolbars, context menus, the canvas, sidebar, and inspector can act on the active document.

The editor UI is centered on `ScriptDesigner`. It uses a `NavigationSplitView` with `SidebarView` on the leading side, `DesignerView` as the canvas, and `InspectorView` in a trailing inspector column. `EphemeralState` carries transient UI state such as current selection, subtree selection, and status messages; persistent document data stays in `CircuitModel`.

The graph model lives in `ImageProModel`. A document contains one or more `Graph` instances plus orphaned sources and segues. `Source` and `Sink` inherit from `Node`; sources hold imported source images, segues define operations and input bindings, and sinks hold processed output images. `Segue.definedInputs` connects operation input slots either to a source or to a previous segue output, while each segue owns its output `Sink` nodes.

Model mutation is implemented through `CircuitModel` extensions grouped by concern. Creation, deletion, duplication, graph mutation, graph layout, image import, operation updates, and history handling live in separate source folders. UI code should generally call these model APIs rather than editing graph internals directly, because the model also maintains relationships such as `usedBy`, orphan handling, history messages, undo/redo snapshots, and automatic graph arrangement.

Processing is performed by converting each graph into a `ProcessingGraphJob`. The model clears stale sink images, estimates work, publishes `ImageProcessingProgress`, and schedules execution on a shared serial queue because ImPro is single-threaded. Processing walks ready segues in dependency order, applies `ImProOperationExecutor` to available grid cells, and posts resulting sink images back to the main thread for the active processing session.

Operations are layered to separate UI concepts from executable native calls. `OperationType` is the user-facing family shown in menus. `OperationPreset` is a named configuration for one operation type and one concrete operator. `ImProOperator` describes the executable operation backed by the ImPro package and native library. A segue stores an `Operation` payload with the selected type, operator id, parameters, and optional source preset id. Built-in operation metadata lives under `ImageProModel/Sources/Operations`, while custom operation preset libraries can come from app-level storage or be embedded in documents.

The inspector is tab-based and context-aware. Document and view pages are always available; node and segue pages appear only for compatible single selections; history is always available. Operation parameters are edited through specialized SwiftUI controls under `Inspector/OperationParameters`, including matrix, kernel, binary shape, gray value, and variant editors.

The canvas is responsible for spatial editing and preview interactions. `DesignerView` renders the scrollable and zoomable document surface, grid overlay, selection surface, segues, nodes, new-input affordances, arrangement controls, and zoom controls. Sidebar rows expose the same graph hierarchy in a list-oriented form and share selection and deletion behavior through `EphemeralState`.

Menus and commands are intentionally thin UI layers over model operations. Context menu files under `ScriptDesigner/Commands/ContextMenus` compose actions for the current target, while `OperationMenu` builds operation choices from `OperationType` metadata. Global undo/redo, duplicate, delete, and settings commands are installed from the app and designer command definitions.

The dependency direction is app UI -> `ImageProModel` -> `ImPro`. The app target owns SwiftUI presentation and transient interaction state. `ImageProModel` owns document state, graph invariants, persistence, layout, image import, processing orchestration, and operation metadata. `ImPro` owns the native processing bridge and links against the underlying `impro` and `improconv` libraries.
