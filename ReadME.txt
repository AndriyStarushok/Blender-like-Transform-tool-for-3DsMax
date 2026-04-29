Blender Transform Tool for 3ds Max
This script brings Blender’s modal transformation workflow (Grab, Rotate, Scale) into 3ds Max, completely bypassing the traditional Gizmo dragging. It allows you to transform objects and sub-objects instantly using keyboard shortcuts on the fly.

Note: This script was 100% generated and developed by Google's Gemini AI.

Core Features:
Modal Operations: Press G (Grab) to initiate movement. Press R (Rotate) or S (Scale) mid-operation to seamlessly switch transform modes.

Axis Constraints: Press X, Y, or Z while transforming to lock the action to a specific axis.

Plane Constraints: Press Shift + X/Y/Z to lock the transformation to a specific 2D plane (e.g., Shift+Z locks to the XY plane).

Space Cycling: Tap the axis keys repeatedly to cycle between Global, Local, and Free transform spaces.

Sub-object Support: Fully compatible with Vertices, Edges, Polygons, and Knots across Editable Poly, Editable Mesh, Edit Poly modifier, and Splines.

Screen Wrap: The mouse cursor automatically wraps around viewport edges, allowing for infinite dragging distances without interruption.

Instant Snapping: Tap Ctrl mid-transform to toggle 3D snapping on/off. Fully supports 2D, 2.5D, and 3D snap modes with proper depth projection.

Visual Guides: Dynamically draws infinite colored axis lines directly in the viewport to indicate the active constraint.

Non-blocking Input: Utilizes a background .NET timer and Windows API hooks to ensure instantaneous keyboard response, even if the mouse is completely still.