-- ============================================================================
-- Blender-style Transformation Tools (Grab, Rotate, Scale, Duplicate, Repeat, Grab From Point)
-- ============================================================================

-- Global state (Updated to V25 for Point Snapping & Freeze Trick)
global BlenderGrab_StateV25
struct BGrabStateStructV25 ( isActive = false, mainAction = #grab, mode = #free, space = #global, pos = [0,0,0], rotTM = matrix3 1, updateCb = undefined )
if BlenderGrab_StateV25 == undefined do BlenderGrab_StateV25 = BGrabStateStructV25()

global BlenderGrab_RepeatStateV25
struct BRepeatStateStructV25 ( isValid = false, actionType = #grab, val = undefined, spaceMode = #global, rotTM = matrix3 1 )
if BlenderGrab_RepeatStateV25 == undefined do BlenderGrab_RepeatStateV25 = BRepeatStateStructV25()

global BlenderGrab_StartupActionV25
if BlenderGrab_StartupActionV25 == undefined do BlenderGrab_StartupActionV25 = #grab

-- Point Snapping Globals
global BlenderGrab_CustomBasePointV25 = undefined
global BlenderGrab_ActiveNodesV25 = #()
global BlenderGrab_OriginalStatesV25 = #()

global BlenderGrab_FullModeActive
if BlenderGrab_FullModeActive == undefined do BlenderGrab_FullModeActive = false

-- ============================================================================
-- C# WRAPPER (Mouse Simulation & Keyboard & Hook)
-- ============================================================================
try(if BlenderGrab_KeyReaderV25 != undefined do BlenderGrab_KeyReaderV25.RemoveHook())catch()
BlenderGrab_KeyReaderV25 = undefined

global BlenderGrab_KeyReaderV25
if BlenderGrab_KeyReaderV25 == undefined do (
	local csharpSource = "
	using System;
	using System.Runtime.InteropServices;
	using System.Text;
	public class KeyReaderV25 {
		[DllImport(\"user32.dll\")] public static extern short GetAsyncKeyState(int vKey);
		[DllImport(\"user32.dll\")] public static extern bool SetCursorPos(int X, int Y);
		[DllImport(\"user32.dll\", CharSet = CharSet.Auto, CallingConvention = CallingConvention.StdCall)] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint cButtons, uint dwExtraInfo);
		
		[DllImport(\"user32.dll\", SetLastError = true)] private static extern IntPtr SetWindowsHookEx(int idHook, HookProc lpfn, IntPtr hMod, uint dwThreadId);
		[DllImport(\"user32.dll\", SetLastError = true)] private static extern bool UnhookWindowsHookEx(IntPtr hhk);
		[DllImport(\"user32.dll\", SetLastError = true)] private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
		[DllImport(\"kernel32.dll\")] private static extern uint GetCurrentThreadId();
		[DllImport(\"user32.dll\")] private static extern IntPtr GetFocus();
		[DllImport(\"user32.dll\", CharSet = CharSet.Auto)] private static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

		public delegate IntPtr HookProc(int nCode, IntPtr wParam, IntPtr lParam);

		private const int WH_KEYBOARD = 2;
		private const int HC_ACTION = 0;

		private HookProc _proc;
		private IntPtr _hookID = IntPtr.Zero;

		public bool isHookActive = false;
		public bool isToolActive = false;
		public bool consumeG = false;
		public bool consumeR = false;
		public bool consumeS = false;

		public bool IsPressed(int keyCode) { return (GetAsyncKeyState(keyCode) & 0x8000) != 0; }
		public void SetPos(int X, int Y) { SetCursorPos(X, Y); }
		public void SimulateLeftClick() { mouse_event(0x02 | 0x04, 0, 0, 0, 0); }

		public void InstallHook() {
			if (_hookID == IntPtr.Zero) {
				_proc = HookCallback;
				_hookID = SetWindowsHookEx(WH_KEYBOARD, _proc, IntPtr.Zero, GetCurrentThreadId());
			}
		}

		public void RemoveHook() {
			if (_hookID != IntPtr.Zero) {
				UnhookWindowsHookEx(_hookID);
				_hookID = IntPtr.Zero;
			}
		}

		private bool CanBlock() {
			IntPtr hWnd = GetFocus();
			if (hWnd == IntPtr.Zero) return true;
			StringBuilder sb = new StringBuilder(256);
			GetClassName(hWnd, sb, 256);
			string cls = sb.ToString().ToLower();
			if (cls.Contains(\"edit\") || cls.Contains(\"combo\") || cls.Contains(\"list\") || cls.Contains(\"tree\") || cls.Contains(\"spinner\")) return false;
			return true;
		}

		private bool HasModifiers() {
			return (GetAsyncKeyState(0x10) & 0x8000) != 0 || // Shift
				   (GetAsyncKeyState(0x11) & 0x8000) != 0 || // Ctrl
				   (GetAsyncKeyState(0x12) & 0x8000) != 0;   // Alt
		}

		private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
			if (nCode == HC_ACTION && isHookActive) {
				int vkCode = wParam.ToInt32();
				bool isKeyDown = ((lParam.ToInt64() >> 31) & 1) == 0;
				bool wasKeyDown = ((lParam.ToInt64() >> 30) & 1) == 1;

				if (isKeyDown && !wasKeyDown && !isToolActive && CanBlock() && !HasModifiers()) {
					if (vkCode == 0x47) { consumeG = true; return (IntPtr)1; } // G
					if (vkCode == 0x52) { consumeR = true; return (IntPtr)1; } // R
					if (vkCode == 0x53) { consumeS = true; return (IntPtr)1; } // S
				}
			}
			return CallNextHookEx(_hookID, nCode, wParam, lParam);
		}
	}"
	local compilerParams = dotnetobject "System.CodeDom.Compiler.CompilerParameters"
	compilerParams.GenerateInMemory = true
	local compiler = dotnetobject "Microsoft.CSharp.CSharpCodeProvider"
	local results = compiler.CompileAssemblyFromSource compilerParams #(csharpSource)
	BlenderGrab_KeyReaderV25 = results.CompiledAssembly.CreateInstance "KeyReaderV25"
	
	callbacks.addScript #preSystemShutdown "try(BlenderGrab_KeyReaderV25.RemoveHook())catch()" id:#BlenderGrabCleanup
)

-- ============================================================================
-- GLOBAL BACKGROUND TIMERS
-- ============================================================================
global BlenderGrab_GlobalHookTimer
try(destroyDialog BlenderGrab_GlobalHookTimer)catch()
rollout BlenderGrab_GlobalHookTimer "BGHookTimer" (
	timer clock "clock" interval:15 active:true
	on clock tick do (
		if BlenderGrab_KeyReaderV25 != undefined and BlenderGrab_KeyReaderV25.isHookActive then (
			local doG = BlenderGrab_KeyReaderV25.consumeG
			local doR = BlenderGrab_KeyReaderV25.consumeR
			local doS = BlenderGrab_KeyReaderV25.consumeS
			
			BlenderGrab_KeyReaderV25.consumeG = false
			BlenderGrab_KeyReaderV25.consumeR = false
			BlenderGrab_KeyReaderV25.consumeS = false
			
			if BlenderGrab_StateV25 != undefined and not BlenderGrab_StateV25.isActive then (
				if doG then ( BlenderGrab_StartupActionV25 = #grab; macros.run "Custom Tools" "BlenderGrabTool" )
				else if doR then ( BlenderGrab_StartupActionV25 = #rotate; macros.run "Custom Tools" "BlenderGrabTool" )
				else if doS then ( BlenderGrab_StartupActionV25 = #scale; macros.run "Custom Tools" "BlenderGrabTool" )
			)
		)
	)
)
createDialog BlenderGrab_GlobalHookTimer pos:[-1000,-1000] width:10 height:10 style:#()

global BlenderGrab_HiddenRollout
try(destroyDialog BlenderGrab_HiddenRollout)catch()
rollout BlenderGrab_HiddenRollout "BGTimer" (
	timer clock "clock" interval:15 active:false -- ~60 FPS
	on clock tick do (
		if BlenderGrab_StateV25 != undefined and BlenderGrab_StateV25.isActive and BlenderGrab_StateV25.updateCb != undefined do (
			BlenderGrab_StateV25.updateCb()
		)
	)
)

-- Function for visual drawing of infinite axes in the viewport
global BlenderGrab_DrawAxes
fn BlenderGrab_DrawAxes = (
	if not BlenderGrab_StateV25.isActive do return()
	local drawTM = copy BlenderGrab_StateV25.rotTM
	drawTM.translation = BlenderGrab_StateV25.pos
	gw.setTransform drawTM 
	local p = [0,0,0], s = 100000.0 
	case BlenderGrab_StateV25.mode of (
		#x: ( gw.setColor #line red; gw.polyline #(p - [s,0,0], p + [s,0,0]) false )
		#y: ( gw.setColor #line green; gw.polyline #(p - [0,s,0], p + [0,s,0]) false )
		#z: ( gw.setColor #line blue; gw.polyline #(p - [0,0,s], p + [0,0,s]) false )
		#shiftX: ( gw.setColor #line green; gw.polyline #(p - [0,s,0], p + [0,s,0]) false; gw.setColor #line blue; gw.polyline #(p - [0,0,s], p + [0,0,s]) false )
		#shiftY: ( gw.setColor #line red; gw.polyline #(p - [s,0,0], p + [s,0,0]) false; gw.setColor #line blue; gw.polyline #(p - [0,0,s], p + [0,0,s]) false )
		#shiftZ: ( gw.setColor #line red; gw.polyline #(p - [s,0,0], p + [s,0,0]) false; gw.setColor #line green; gw.polyline #(p - [0,s,0], p + [0,s,0]) false )
	)
	gw.enlargeUpdateRect #whole
	gw.setTransform (matrix3 1)
)

-- ============================================================================
-- GLOBAL MATHEMATICS FUNCTIONS
-- ============================================================================
global BlenderGrab_IntersectRayV25
fn BlenderGrab_IntersectRayV25 rayObj planeNormal planePoint = (
	local d = dot planeNormal rayObj.dir
	if abs d < 0.0001 then return undefined
	local t = (dot planeNormal (planePoint - rayObj.pos)) / d
	return (rayObj.pos + rayObj.dir * t)
)

global BlenderGrab_GetCenterV25
fn BlenderGrab_GetCenterV25 activeNodes = (
	if activeNodes.count == 0 do return [0,0,0]
	if subObjectLevel == undefined or subObjectLevel == 0 then (
		local centerPos = [0,0,0]
		for obj in activeNodes do centerPos += obj.pivot
		return (centerPos / activeNodes.count)
	)
	local centerPos = [0,0,0], vertCount = 0
	for obj in activeNodes do (
		local curMod = modPanel.getCurrentObject()
		if curMod == undefined do continue
		local cClass = classOf curMod
		if cClass == Editable_Poly then (
			local verts = #{}
			case subObjectLevel of (
				1: verts = polyop.getVertSelection obj
				2: verts = polyop.getVertsUsingEdge obj (polyop.getEdgeSelection obj)
				3: verts = polyop.getVertsUsingEdge obj (polyop.getEdgeSelection obj)
				4: verts = polyop.getVertsUsingFace obj (polyop.getFaceSelection obj)
				5: verts = polyop.getVertsUsingFace obj (polyop.getFaceSelection obj)
			)
			for v in verts do ( centerPos += polyop.getVert obj v; vertCount += 1 )
		)
		else if cClass == Edit_Poly then (
			local tempMesh = undefined
			try(tempMesh = snapshotAsMesh obj)catch()
			if tempMesh != undefined do (
				local verts = #{}
				case subObjectLevel of (
					1: verts = curMod.GetSelection #Vertex
					2: verts = meshop.getVertsUsingEdge tempMesh (curMod.GetSelection #Edge)
					3: verts = meshop.getVertsUsingEdge tempMesh (curMod.GetSelection #Edge)
					4: verts = meshop.getVertsUsingFace tempMesh (curMod.GetSelection #Face)
					5: verts = meshop.getVertsUsingFace tempMesh (curMod.GetSelection #Face)
				)
				if verts != undefined do (
					for v in verts do ( centerPos += meshop.getVert tempMesh v; vertCount += 1 )
				)
				free tempMesh
			)
		)
		else if cClass == Editable_Mesh then (
			local verts = #{}
			case subObjectLevel of (
				1: verts = getVertSelection obj
				2: verts = meshop.getVertsUsingEdge obj (getEdgeSelection obj)
				3: verts = meshop.getVertsUsingFace obj (getFaceSelection obj)
				4: verts = meshop.getVertsUsingFace obj (getFaceSelection obj)
				5: verts = meshop.getVertsUsingFace obj (getFaceSelection obj)
			)
			for v in verts do ( centerPos += meshop.getVert obj v; vertCount += 1 )
		)
		else if cClass == line or cClass == Editable_Spline or cClass == SplineShape then (
			for s = 1 to (numSplines obj) do (
				local knots = getKnotSelection obj s
				for k in knots do ( centerPos += getKnotPoint obj s k; vertCount += 1 )
			)
		)
	)
	if vertCount > 0 then return (centerPos / vertCount) else return selection.center
)

global BlenderGrab_GetMovingVertsV25
fn BlenderGrab_GetMovingVertsV25 activeNodes = (
	local vertsArr = #()
	if subObjectLevel == undefined or subObjectLevel == 0 do return vertsArr
	
	for obj in activeNodes do (
		local curMod = modPanel.getCurrentObject()
		if curMod == undefined do continue
		local cClass = classOf curMod
		if cClass == Editable_Poly then (
			local verts = #{}
			case subObjectLevel of (
				1: verts = polyop.getVertSelection obj
				2: verts = polyop.getVertsUsingEdge obj (polyop.getEdgeSelection obj)
				3: verts = polyop.getVertsUsingEdge obj (polyop.getEdgeSelection obj)
				4: verts = polyop.getVertsUsingFace obj (polyop.getFaceSelection obj)
				5: verts = polyop.getVertsUsingFace obj (polyop.getFaceSelection obj)
			)
			for v in verts do append vertsArr (polyop.getVert obj v)
		)
		else if cClass == Edit_Poly then (
			local tempMesh = undefined
			try(tempMesh = snapshotAsMesh obj)catch()
			if tempMesh != undefined do (
				local verts = #{}
				case subObjectLevel of (
					1: verts = curMod.GetSelection #Vertex
					2: verts = meshop.getVertsUsingEdge tempMesh (curMod.GetSelection #Edge)
					3: verts = meshop.getVertsUsingEdge tempMesh (curMod.GetSelection #Edge)
					4: verts = meshop.getVertsUsingFace tempMesh (curMod.GetSelection #Face)
					5: verts = meshop.getVertsUsingFace tempMesh (curMod.GetSelection #Face)
				)
				if verts != undefined do (
					for v in verts do append vertsArr (meshop.getVert tempMesh v)
				)
				free tempMesh
			)
		)
		else if cClass == Editable_Mesh then (
			local verts = #{}
			case subObjectLevel of (
				1: verts = getVertSelection obj
				2: verts = meshop.getVertsUsingEdge obj (getEdgeSelection obj)
				3: verts = meshop.getVertsUsingFace obj (getFaceSelection obj)
				4: verts = meshop.getVertsUsingFace obj (getFaceSelection obj)
				5: verts = meshop.getVertsUsingFace obj (getFaceSelection obj)
			)
			for v in verts do append vertsArr (meshop.getVert obj v)
		)
		else if cClass == line or cClass == Editable_Spline or cClass == SplineShape then (
			for s = 1 to (numSplines obj) do (
				local knots = getKnotSelection obj s
				for k in knots do append vertsArr (getKnotPoint obj s k)
			)
		)
	)
	return vertsArr
)

global BlenderGrab_ApplyActionV25
fn BlenderGrab_ApplyActionV25 actionType val workTM center spaceMode = (
	local activeNodes = BlenderGrab_ActiveNodesV25
	if activeNodes.count == 0 do return()
	
	if subObjectLevel == undefined or subObjectLevel == 0 then (
		if spaceMode == #local then (
			local invWorkTM = inverse workTM
			for obj in activeNodes do (
				local oldPos = obj.pos
				local objTM = obj.transform.rotation as matrix3
				
				if actionType == #grab do (
					-- Convert world delta to local delta, then map it to the object's specific orientation
					local localDelta = val * invWorkTM
					local perObjWorldDelta = localDelta * objTM
					obj.pos += perObjWorldDelta
				)
				if actionType == #rotate do (
					-- Extract the relative local axis and apply it locally for each object
					local localAxis = val.axis * invWorkTM
					local perObjWorldAxis = localAxis * objTM
					about oldPos in coordsys world rotate obj (angleaxis val.angle perObjWorldAxis)
				)
				if actionType == #scale do (
					-- Scale inherently works locally if applied in coordsys objTM
					in coordsys objTM about oldPos scale obj val
					obj.pos = oldPos 
				)
			)
		) else (
			if actionType == #grab do (
				in coordsys world move activeNodes val
			)
			if actionType == #rotate or actionType == #scale do (
				local oldPos = if activeNodes.count == 1 then activeNodes[1].pos else undefined
				if actionType == #rotate do about center in coordsys world rotate activeNodes val
				if actionType == #scale do in coordsys workTM about center scale activeNodes val
				if oldPos != undefined do activeNodes[1].pos = oldPos
			)
		)
		return()
	)
	
	local deltaTM = matrix3 1
	if actionType == #grab do deltaTM.translation = val
	if actionType == #rotate do deltaTM = val as matrix3
	if actionType == #scale do deltaTM = (inverse workTM) * scaleMatrix val * workTM
	
	for obj in activeNodes do (
		local curMod = modPanel.getCurrentObject()
		if curMod == undefined do continue
		local cClass = classOf curMod
		if cClass == Editable_Poly then (
			local verts = #{}
			case subObjectLevel of (
				1: verts = polyop.getVertSelection obj
				2: verts = polyop.getVertsUsingEdge obj (polyop.getEdgeSelection obj)
				3: verts = polyop.getVertsUsingEdge obj (polyop.getEdgeSelection obj)
				4: verts = polyop.getVertsUsingFace obj (polyop.getFaceSelection obj)
				5: verts = polyop.getVertsUsingFace obj (polyop.getFaceSelection obj)
			)
			if not verts.isEmpty do (
				local vArr = verts as array
				local pArr = for v in vArr collect (((polyop.getVert obj v) - center) * deltaTM + center)
				polyop.setVert obj vArr pArr
			)
		)
		else if cClass == Edit_Poly then (
			if actionType == #grab do curMod.MoveSelection val
			if actionType == #rotate do curMod.RotateSelection val
			if actionType == #scale do curMod.ScaleSelection val
			curMod.Commit()
		)
		else if cClass == Editable_Mesh then (
			local verts = #{}
			case subObjectLevel of (
				1: verts = getVertSelection obj
				2: verts = meshop.getVertsUsingEdge obj (getEdgeSelection obj)
				3: verts = meshop.getVertsUsingFace obj (getFaceSelection obj)
				4: verts = meshop.getVertsUsingFace obj (getFaceSelection obj)
				5: verts = meshop.getVertsUsingFace obj (getFaceSelection obj)
			)
			if not verts.isEmpty do (
				local vArr = verts as array
				local pArr = for v in vArr collect (((meshop.getVert obj v) - center) * deltaTM + center)
				meshop.setVert obj vArr pArr
			)
		)
		else if cClass == line or cClass == Editable_Spline or cClass == SplineShape then (
			for s = 1 to (numSplines obj) do (
				local knots = getKnotSelection obj s
				for k in knots do (
					local p = getKnotPoint obj s k
					setKnotPoint obj s k (((p - center) * deltaTM) + center)
					local inV = getInVec obj s k
					setInVec obj s k (((inV - center) * deltaTM) + center)
					local outV = getOutVec obj s k
					setOutVec obj s k (((outV - center) * deltaTM) + center)
				)
			)
			updateShape obj
		)
	)
)

-- ============================================================================
-- GRAB FROM POINT MACRO (Quick Snapping)
-- ============================================================================
macroScript BlenderGrabFromPointTool
category:"Custom Tools"
tooltip:"Blender Grab From Point"
buttonText:"B-Grab Point"
(
	on execute do (
		if selection.count == 0 do (
			messageBox "Select at least one object to grab from a point." title:"Blender Grab From Point"
			return()
		)
		
		local mPos = mouse.pos
		local closestDist = 9999999.0
		local closestVert = undefined
		
		gw.setTransform (matrix3 1)
		local viewTM = Inverse(getViewTM())
		local viewPos = viewTM.row4
		local viewDir = -viewTM.row3
		local isPersp = viewport.IsPerspView()
		
		if subObjectLevel == undefined or subObjectLevel == 0 then (
			-- Окремі об'єкти: шукаємо по всьому мешу
			for obj in selection do (
				local tMesh = undefined
				try (tMesh = snapshotAsMesh obj) catch()
				
				if tMesh != undefined do (
					for i = 1 to tMesh.numverts do (
						local vPos = meshop.getVert tMesh i
						local isValid = true
						
						if isPersp do (
							local ptDir = normalize (vPos - viewPos)
							if (dot viewDir ptDir) <= 0.1 do isValid = false
						)
						
						if isValid do (
							local sPos = gw.transPoint vPos
							local d = distance [sPos.x, sPos.y] [mPos.x, mPos.y]
							if d < closestDist do (
								closestDist = d
								closestVert = vPos
							)
						)
					)
					free tMesh
				)
				
				if isKindOf obj SplineShape or isKindOf obj line do (
					for s = 1 to (numSplines obj) do (
						for k = 1 to (numKnots obj s) do (
							local vPos = getKnotPoint obj s k
							local isValid = true
							
							if isPersp do (
								local ptDir = normalize (vPos - viewPos)
								if (dot viewDir ptDir) <= 0.1 do isValid = false
							)
							
							if isValid do (
								local sPos = gw.transPoint vPos
								local d = distance [sPos.x, sPos.y] [mPos.x, mPos.y]
								if d < closestDist do (
									closestDist = d
									closestVert = vPos
								)
							)
						)
					)
				)
			)
		) else (
			-- Під-об'єкти: шукаємо ВИКЛЮЧНО серед виділених точок/полігонів
			local activeNodes = selection as array
			local movingVerts = BlenderGrab_GetMovingVertsV25 activeNodes
			
			for vPos in movingVerts do (
				local isValid = true
				
				if isPersp do (
					local ptDir = normalize (vPos - viewPos)
					if (dot viewDir ptDir) <= 0.1 do isValid = false
				)
				
				if isValid do (
					local sPos = gw.transPoint vPos
					local d = distance [sPos.x, sPos.y] [mPos.x, mPos.y]
					if d < closestDist do (
						closestDist = d
						closestVert = vPos
					)
				)
			)
		)
		
		if closestVert != undefined then (
			global BlenderGrab_CustomBasePointV25 = closestVert
			
			BlenderGrab_StartupActionV25 = #grab
			macros.run "Custom Tools" "BlenderGrabTool"
		) else (
			pushPrompt "No visible points found to snap from!"
		)
	)
)

-- ============================================================================
-- FULL BLENDER MODE TOGGLE (Toolbar Button)
-- ============================================================================
macroScript BlenderFullModeToggle
category:"Custom Tools"
tooltip:"Full Blender Mode Toggle"
buttonText:"Full B-Mode"
(
	on isChecked return BlenderGrab_FullModeActive
	on execute do (
		BlenderGrab_FullModeActive = not BlenderGrab_FullModeActive
		if BlenderGrab_FullModeActive then (
			if BlenderGrab_KeyReaderV25 != undefined do (
				BlenderGrab_KeyReaderV25.InstallHook()
				BlenderGrab_KeyReaderV25.isHookActive = true
			)
			pushPrompt "Full Blender Mode: ON (G, R, S are intelligently intercepted)"
		) else (
			if BlenderGrab_KeyReaderV25 != undefined do (
				BlenderGrab_KeyReaderV25.isHookActive = false
				BlenderGrab_KeyReaderV25.RemoveHook()
			)
			pushPrompt "Full Blender Mode: OFF (Standard 3ds Max keys restored)"
		)
	)
)

-- ============================================================================
-- MAIN TRANSFORM MACRO (The Engine)
-- ============================================================================
macroScript BlenderGrabTool
category:"Custom Tools"
tooltip:"Blender Transform Engine"
buttonText:"B-Engine"
(
	-- Tutorial Rollout
	rollout BlenderGrab_TutorialRollout "Blender Workflow - Quick Guide" width:390 height:445
	(
		label lbl_title "--- BLENDER WORKFLOW IN 3DS MAX ---" style_sunkenedge:false width:370 height:18 align:#center
		
		label lbl_h1 "HOTKEYS:" pos:[15, 30] style_sunkenedge:true width:360 height:18
		
		label lbl_k1 "G" pos:[20, 55] bold:true
		label lbl_k1d "- Enter tool mode (starts with Grab)" pos:[100, 55]
		
		label lbl_k1a "R, S" pos:[20, 75] bold:true
		label lbl_k1ad "- Rotate / Scale (only AFTER pressing G)" pos:[100, 75]
		
		label lbl_k2 "X, Y, Z" pos:[20, 95] bold:true
		label lbl_k2d "- Constrain Axis (Global -> Local -> Free)" pos:[100, 95]
		
		label lbl_k3 "Shift+XYZ" pos:[20, 115] bold:true
		label lbl_k3d "- Constrain Plane (e.g. Shift+Z locks XY)" pos:[100, 115]
		
		label lbl_k7 "0-9, -, ." pos:[20, 135] bold:true
		label lbl_k7d "- Numeric Input (Type directly!)" pos:[100, 135]
		
		label lbl_k4 "Ctrl" pos:[20, 155] bold:true
		label lbl_k4d "- Toggle Snapping on/off" pos:[100, 155]
		
		label lbl_k5 "LMB / Enter" pos:[20, 175] bold:true
		label lbl_k5d "- Apply Transform" pos:[100, 175]
		
		label lbl_k6 "RMB / Esc" pos:[20, 195] bold:true
		label lbl_k6d "- Cancel Transform" pos:[100, 195]
		
		label lbl_setup "HOW TO ASSIGN HOTKEYS:" pos:[15, 235] style_sunkenedge:true width:360 height:18
		label lbl_set1 "1. Go to: Customize -> Hotkey Editor" pos:[20, 260]
		label lbl_set2 "2. Search: 'Blender Transform Engine' -> Assign 'G'" pos:[20, 275]
		label lbl_set3 "3. Search: 'Blender Duplicate' -> Assign 'Shift+D'" pos:[20, 290]
		label lbl_set4 "4. Search: 'Blender Repeat' -> Assign 'Shift+R'" pos:[20, 305]
		label lbl_set5 "5. Search: 'Blender Grab From Point' -> Assign 'Shift+G'" pos:[20, 320]
		label lbl_set6 "6. Click Assign and Save." pos:[20, 335]
		
		checkbox chk_dontShow "Don't show this anymore" pos:[15, 410]
		button btn_ok "Got it!" width:100 height:30 pos:[275, 405]
		
		on btn_ok pressed do (
			if chk_dontShow.checked do (
				local iniPath = (GetDir #plugcfg) + "\\BlenderGrabTool.ini"
				setINISetting iniPath "Settings" "ShowTutorial" "false"
			)
			destroyDialog BlenderGrab_TutorialRollout
		)
	)

	-- Check if tutorial needs to be shown
	local iniPath = (GetDir #plugcfg) + "\\BlenderGrabTool.ini"
	local showTutorial = (getINISetting iniPath "Settings" "ShowTutorial")
	if showTutorial != "false" do (
		try(destroyDialog BlenderGrab_TutorialRollout)catch()
		createDialog BlenderGrab_TutorialRollout modal:true
	)

	-- 5. Main mouse tool
	tool BlenderGrab_MouseTool
	(
		local startMousePos
		local selCenter
		local viewNorm
		local currentMode = #free
		local currentSpace = #global
		local refRotTM = matrix3 1
		local isMoving = false
		
		local lastAppliedOffset = [0,0,0]
		local lastAppliedAngle = 0.0
		local lastAppliedScale = [1,1,1]
		local lastRotAxis = [0,0,1]
		
		local lastMouseAng = 0.0
		local accumulatedAngle = 0.0
		
		local wasPressedX = false, wasPressedY = false, wasPressedZ = false
		local wasPressedG = false, wasPressedR = false, wasPressedS = false
		local wasPressedCtrl = false, wasPressedEnter = false
		
		local wasPressedKeys = for i=1 to 256 collect false
		local numericInputString = ""
		
		local VK_X = 0x58, VK_Y = 0x59, VK_Z = 0x5A
		local VK_G = 0x47, VK_R = 0x52, VK_S = 0x53, VK_SHIFT = 0x10, VK_CONTROL = 0x11, VK_RETURN = 0x0D
		
		local virtualMouseOffset = [0,0]
		local lastValidSnapPt = undefined
		
		local movingVertsOrig = #()
		local bboxMin = [0,0,0]
		local bboxMax = [0,0,0]
		
		fn updatePromptText = (
			local actionStr = case BlenderGrab_StateV25.mainAction of (
				#grab: "Grab"
				#rotate: "Rotate"
				#scale: "Scale"
			)
			local modeStr = case currentMode of (
				#free: "Free Move"
				#x: "X Axis"
				#y: "Y Axis"
				#z: "Z Axis"
				#shiftX: "YZ Plane"
				#shiftY: "XZ Plane"
				#shiftZ: "XY Plane"
			)
			local spaceStr = if currentMode != #free then (if currentSpace == #global then " (Global)" else " (Local)") else ""
			local inputStr = if numericInputString != "" then (" | Input: " + numericInputString) else ""
			
			pushPrompt (actionStr + " | " + modeStr + spaceStr + " | X,Y,Z - Axis | Ctrl - Snap" + inputStr)
		)
		
		-- Logic centralized in function for timer to poll
		fn executeTransform = (
			if not isMoving do return()
			enableAccelerators = false
			
			gw.setTransform (matrix3 1)
			local centerScreen2D = gw.transPoint selCenter
			local centerScreen = [centerScreen2D.x, centerScreen2D.y]
				
			local isPressedX = BlenderGrab_KeyReaderV25.IsPressed VK_X
			local isPressedY = BlenderGrab_KeyReaderV25.IsPressed VK_Y
			local isPressedZ = BlenderGrab_KeyReaderV25.IsPressed VK_Z
			local isPressedG = BlenderGrab_KeyReaderV25.IsPressed VK_G
			local isPressedR = BlenderGrab_KeyReaderV25.IsPressed VK_R
			local isPressedS = BlenderGrab_KeyReaderV25.IsPressed VK_S
			local isPressedCtrl = BlenderGrab_KeyReaderV25.IsPressed VK_CONTROL
			local isPressedEnter = BlenderGrab_KeyReaderV25.IsPressed VK_RETURN
			local shiftPressed = BlenderGrab_KeyReaderV25.IsPressed VK_SHIFT or keyboard.shiftPressed
			
			local justPressedX = isPressedX and not wasPressedX
			local justPressedY = isPressedY and not wasPressedY
			local justPressedZ = isPressedZ and not wasPressedZ
			local justPressedG = isPressedG and not wasPressedG
			local justPressedR = isPressedR and not wasPressedR
			local justPressedS = isPressedS and not wasPressedS
			local justPressedCtrl = isPressedCtrl and not wasPressedCtrl
			local justPressedEnter = isPressedEnter and not wasPressedEnter
			
			-- Numeric Input Polling
			local justPressedNum = ""
			for k = 0x30 to 0x39 do ( -- Top row 0-9
				local isP = BlenderGrab_KeyReaderV25.IsPressed k
				if isP and not wasPressedKeys[k] do justPressedNum = (k - 0x30) as string
				wasPressedKeys[k] = isP
			)
			for k = 0x60 to 0x69 do ( -- Numpad 0-9
				local isP = BlenderGrab_KeyReaderV25.IsPressed k
				if isP and not wasPressedKeys[k] do justPressedNum = (k - 0x60) as string
				wasPressedKeys[k] = isP
			)
			-- Minus and Dot
			local isMinus1 = BlenderGrab_KeyReaderV25.IsPressed 0xBD; local isMinus2 = BlenderGrab_KeyReaderV25.IsPressed 0x6D
			if (isMinus1 and not wasPressedKeys[0xBD]) or (isMinus2 and not wasPressedKeys[0x6D]) do justPressedNum = "-"
			wasPressedKeys[0xBD] = isMinus1; wasPressedKeys[0x6D] = isMinus2
			
			local isDot1 = BlenderGrab_KeyReaderV25.IsPressed 0xBE; local isDot2 = BlenderGrab_KeyReaderV25.IsPressed 0x6E
			if (isDot1 and not wasPressedKeys[0xBE]) or (isDot2 and not wasPressedKeys[0x6E]) do justPressedNum = "."
			wasPressedKeys[0xBE] = isDot1; wasPressedKeys[0x6E] = isDot2
			
			-- Backspace
			local isBS = BlenderGrab_KeyReaderV25.IsPressed 0x08
			if isBS and not wasPressedKeys[0x08] do justPressedNum = "BS"
			wasPressedKeys[0x08] = isBS
			
			if justPressedNum != "" do (
				if justPressedNum == "BS" then (
					if numericInputString.count > 0 do numericInputString = substring numericInputString 1 (numericInputString.count - 1)
				) else (
					numericInputString += justPressedNum
				)
				popPrompt(); updatePromptText()
			)
			
			-- Simulate LMB click when Enter is pressed
			if justPressedEnter do BlenderGrab_KeyReaderV25.SimulateLeftClick()
			
			-- Toggle snapping with Ctrl
			if justPressedCtrl do snapMode.active = not snapMode.active
			
			-- Switch mode (G, R, S)
			if justPressedG or justPressedR or justPressedS do (
				theHold.Cancel()
				theHold.Begin()
				
				if justPressedG do BlenderGrab_StateV25.mainAction = #grab
				if justPressedR do BlenderGrab_StateV25.mainAction = #rotate
				if justPressedS do BlenderGrab_StateV25.mainAction = #scale
				
				currentMode = #free
				currentSpace = #global
				numericInputString = "" -- Reset numeric input on mode switch
				
				startMousePos = mouse.pos
				
				local vStart = startMousePos - centerScreen
				lastMouseAng = atan2 vStart.y vStart.x
				accumulatedAngle = 0.0
				
				lastAppliedOffset = [0,0,0]
				lastAppliedAngle = 0.0
				lastAppliedScale = [1,1,1]
				virtualMouseOffset = [0,0]
				lastValidSnapPt = undefined
			)
			
			-- Cycle Axis (X, Y, Z) 
			fn cycleMode targetMode = (
				theHold.Cancel()
				theHold.Begin()
				
				lastAppliedOffset = [0,0,0]
				lastAppliedAngle = 0.0
				lastAppliedScale = [1,1,1]
				lastValidSnapPt = undefined
				
				if currentMode != targetMode then (
					currentMode = targetMode; currentSpace = #global
				) else if currentSpace == #global then (
					currentSpace = #local
				) else (
					currentMode = #free; currentSpace = #global
				)
			)
			
			if justPressedX do cycleMode (if shiftPressed then #shiftX else #x)
			if justPressedY do cycleMode (if shiftPressed then #shiftY else #y)
			if justPressedZ do cycleMode (if shiftPressed then #shiftZ else #z)
			
			if justPressedG or justPressedR or justPressedS or justPressedX or justPressedY or justPressedZ or justPressedCtrl do (
				popPrompt(); updatePromptText()
			)
			
			wasPressedX = isPressedX; wasPressedY = isPressedY; wasPressedZ = isPressedZ
			wasPressedG = isPressedG; wasPressedR = isPressedR; wasPressedS = isPressedS
			wasPressedCtrl = isPressedCtrl; wasPressedEnter = isPressedEnter

			-- Screen Wrap (only if no numeric input)
			local mPos = mouse.pos
			local viewX = gw.getWinSizeX(), viewY = gw.getWinSizeY()
			local isWrapped = false, wrapX = 0, wrapY = 0
			
			if numericInputString == "" do (
				if mPos.x <= 2 then ( wrapX = viewX - 6; isWrapped = true )
				if mPos.x >= viewX - 2 then ( wrapX = -(viewX - 6); isWrapped = true )
				if mPos.y <= 2 then ( wrapY = viewY - 6; isWrapped = true )
				if mPos.y >= viewY - 2 then ( wrapY = -(viewY - 6); isWrapped = true )
				
				if isWrapped do (
					local newScreenPos = mouse.screenpos + [wrapX, wrapY]
					BlenderGrab_KeyReaderV25.SetPos (newScreenPos.x as integer) (newScreenPos.y as integer)
					virtualMouseOffset += [-wrapX, -wrapY]
					mPos = mPos + [wrapX, wrapY]
				)
			)

			local virtualMousePos = mPos + virtualMouseOffset
			local action = BlenderGrab_StateV25.mainAction
			local workTM = if currentSpace == #local then refRotTM else (matrix3 1)
			
			-- ==========================================
			-- LOGIC: GRAB
			-- ==========================================
			if action == #grab then (
				local finalOffset = [0,0,0]
				
				-- Numeric Input Override for GRAB (Only on locked axes)
				if numericInputString != "" and (currentMode == #x or currentMode == #y or currentMode == #z) then (
					local numVal = numericInputString as float
					if numVal == undefined do numVal = 0.0
					
					local localFinalOffset = [0,0,0]
					case currentMode of (
						#x: localFinalOffset = [numVal, 0, 0]
						#y: localFinalOffset = [0, numVal, 0]
						#z: localFinalOffset = [0, 0, numVal]
					)
					finalOffset = localFinalOffset * workTM
				) else (
					-- Normal Mouse Grab Logic
					local workPlaneNorm = viewNorm
					local axisX = workTM.row1
					local axisY = workTM.row2
					local axisZ = workTM.row3
					
					case currentMode of (
						#shiftX: workPlaneNorm = axisX
						#shiftY: workPlaneNorm = axisY
						#shiftZ: workPlaneNorm = axisZ
						#x: ( local c = cross axisX viewNorm; if length c > 0.001 then workPlaneNorm = normalize (cross c axisX) )
						#y: ( local c = cross axisY viewNorm; if length c > 0.001 then workPlaneNorm = normalize (cross c axisY) )
						#z: ( local c = cross axisZ viewNorm; if length c > 0.001 then workPlaneNorm = normalize (cross c axisZ) )
					)
					if length workPlaneNorm < 0.001 do workPlaneNorm = viewNorm
					
					local rawOffset = undefined
					local snapPt = undefined
					
					if snapMode.active do try ( 
						if snapMode.hit == true then (
							local rawHit = snapMode.worldHitpoint
							local isSelfSnap = false
							if movingVertsOrig.count > 0 do (
								local origTestPt = rawHit - lastAppliedOffset
								
								local threshold = 0.5 -- Збільшений поріг для відловлювання мікро-зміщень
								if origTestPt.x >= bboxMin.x - threshold and origTestPt.x <= bboxMax.x + threshold and \
								   origTestPt.y >= bboxMin.y - threshold and origTestPt.y <= bboxMax.y + threshold and \
								   origTestPt.z >= bboxMin.z - threshold and origTestPt.z <= bboxMax.z + threshold do (
									for v in movingVertsOrig do (
										if distance origTestPt v < threshold do (
											isSelfSnap = true
											exit
										)
									)
								)
							)
							
							if not isSelfSnap then (
								snapPt = rawHit
								lastValidSnapPt = rawHit
							) else (
								-- ЗАМОК ПАМ'ЯТІ: Розриває нескінченну петлю тіліпання (Jitter Loop)
								-- Якщо об'єкт примагнітився до себе ж, але ця координата знаходиться
								-- прямо на останній правильній цілі - ми ігноруємо само-прив'язку!
								if lastValidSnapPt != undefined and distance rawHit lastValidSnapPt < 0.1 then (
									snapPt = lastValidSnapPt
								) else (
									snapPt = undefined
								)
							)
						) else (
							lastValidSnapPt = undefined
						)
					) catch ()
					
					if snapPt != undefined then (
						if snapMode.type == #2_5D or snapMode.type == #2D do (
							local vToSnap = snapPt - selCenter
							snapPt = snapPt - (viewNorm * (dot vToSnap viewNorm))
						)
						rawOffset = snapPt - selCenter 
					) else (
						local sRay = mapScreenToWorldRay startMousePos
						local mRay = mapScreenToWorldRay virtualMousePos
						local startH = BlenderGrab_IntersectRayV25 sRay workPlaneNorm selCenter
						local currentH = BlenderGrab_IntersectRayV25 mRay workPlaneNorm selCenter
						if startH != undefined and currentH != undefined do rawOffset = currentH - startH
					)
					
					if rawOffset != undefined do (
						local invWorkTM = inverse workTM
						local localRawOffset = rawOffset * invWorkTM
						local localFinalOffset = localRawOffset
						
						case currentMode of (
							#x: localFinalOffset = [localRawOffset.x, 0, 0]
							#y: localFinalOffset = [0, localRawOffset.y, 0]
							#z: localFinalOffset = [0, 0, localRawOffset.z]
							#shiftX: localFinalOffset = [0, localRawOffset.y, localRawOffset.z]
							#shiftY: localFinalOffset = [localRawOffset.x, 0, localRawOffset.z]
							#shiftZ: localFinalOffset = [localRawOffset.x, localRawOffset.y, 0]
							#free: localFinalOffset = localRawOffset
						)
						finalOffset = localFinalOffset * workTM
					)
				)
				
				local deltaOffset = finalOffset - lastAppliedOffset
				
				if length(deltaOffset) > 0.0001 or justPressedX or justPressedY or justPressedZ or justPressedCtrl or justPressedNum != "" do (
					BlenderGrab_ApplyActionV25 #grab deltaOffset workTM selCenter currentSpace
					lastAppliedOffset = finalOffset
					BlenderGrab_StateV25.mode = currentMode; BlenderGrab_StateV25.space = currentSpace
					BlenderGrab_StateV25.rotTM = workTM; BlenderGrab_StateV25.pos = selCenter + finalOffset
					gw.updatescreen()
				)
			)
			-- ==========================================
			-- LOGIC: ROTATE
			-- ==========================================
			else if action == #rotate then (
				local rotAxis = viewNorm
				case currentMode of (
					#x: rotAxis = workTM.row1
					#y: rotAxis = workTM.row2
					#z: rotAxis = -workTM.row3 
					#shiftX: rotAxis = workTM.row1
					#shiftY: rotAxis = workTM.row2
					#shiftZ: rotAxis = -workTM.row3 
					#free: rotAxis = viewNorm
				)
				lastRotAxis = rotAxis
				
				local rawAngle = accumulatedAngle
				
				-- Numeric Input Override for ROTATE
				if numericInputString != "" then (
					local numVal = numericInputString as float
					if numVal == undefined do numVal = 0.0
					rawAngle = numVal
				) else (
					local vCur = virtualMousePos - centerScreen
					local curAng = atan2 vCur.y vCur.x
					
					local frameDelta = curAng - lastMouseAng
					if frameDelta > 180.0 do frameDelta -= 360.0
					if frameDelta < -180.0 do frameDelta += 360.0
					
					accumulatedAngle += frameDelta
					lastMouseAng = curAng
					rawAngle = accumulatedAngle
				)
				
				local deltaAngle = rawAngle - lastAppliedAngle
				
				if abs(deltaAngle) > 0.001 or justPressedX or justPressedY or justPressedZ or justPressedNum != "" do (
					local qDelta = angleaxis deltaAngle rotAxis
					BlenderGrab_ApplyActionV25 #rotate qDelta workTM selCenter currentSpace
					lastAppliedAngle = rawAngle
					BlenderGrab_StateV25.mode = currentMode; BlenderGrab_StateV25.space = currentSpace
					BlenderGrab_StateV25.rotTM = workTM; BlenderGrab_StateV25.pos = selCenter
					gw.updatescreen()
				)
			)
			-- ==========================================
			-- LOGIC: SCALE
			-- ==========================================
			else if action == #scale then (
				local localScale = [1,1,1]
				
				-- Numeric Input Override for SCALE (Percentages)
				if numericInputString != "" then (
					local numVal = numericInputString as float
					if numVal == undefined do numVal = 0.0
					local rawRatio = numVal / 100.0 -- 50 becomes 0.5 (50%)
					
					case currentMode of (
						#x: localScale = [rawRatio, 1, 1]
						#y: localScale = [1, rawRatio, 1]
						#z: localScale = [1, 1, rawRatio]
						#shiftX: localScale = [1, rawRatio, rawRatio]
						#shiftY: localScale = [rawRatio, 1, rawRatio]
						#shiftZ: localScale = [rawRatio, rawRatio, 1]
						#free: localScale = [rawRatio, rawRatio, rawRatio]
					)
				) else (
					local distStart = length (startMousePos - centerScreen)
					local distCur = length (virtualMousePos - centerScreen)
					if distStart < 1.0 do distStart = 1.0
					local rawRatio = distCur / distStart
					
					case currentMode of (
						#x: localScale = [rawRatio, 1, 1]
						#y: localScale = [1, rawRatio, 1]
						#z: localScale = [1, 1, rawRatio]
						#shiftX: localScale = [1, rawRatio, rawRatio]
						#shiftY: localScale = [rawRatio, 1, rawRatio]
						#shiftZ: localScale = [rawRatio, rawRatio, 1]
						#free: localScale = [rawRatio, rawRatio, rawRatio]
					)
				)
				
				local deltaScale = [localScale.x / lastAppliedScale.x, localScale.y / lastAppliedScale.y, localScale.z / lastAppliedScale.z]
				
				if abs(deltaScale.x - 1.0) > 0.0001 or abs(deltaScale.y - 1.0) > 0.0001 or abs(deltaScale.z - 1.0) > 0.0001 or justPressedX or justPressedY or justPressedZ or justPressedNum != "" do (
					BlenderGrab_ApplyActionV25 #scale deltaScale workTM selCenter currentSpace
					lastAppliedScale = localScale
					BlenderGrab_StateV25.mode = currentMode; BlenderGrab_StateV25.space = currentSpace
					BlenderGrab_StateV25.rotTM = workTM; BlenderGrab_StateV25.pos = selCenter
					gw.updatescreen()
				)
			)
		)
		
		on start do (
			if selection.count == 0 do (
				messageBox "Select at least one object or sub-object." title:"Blender Transform"
				return #stop
			)
			
			enableAccelerators = false 
			
			-- Pause hook interference while tool is active
			if BlenderGrab_KeyReaderV25 != undefined do BlenderGrab_KeyReaderV25.isToolActive = true
			
			-- Cache selection to protect against freeze deselection
			BlenderGrab_ActiveNodesV25 = selection as array
			
			if BlenderGrab_CustomBasePointV25 != undefined then (
				selCenter = BlenderGrab_CustomBasePointV25
				
				-- Snap the physical mouse cursor perfectly to the vertex
				local pt2D = gw.transPoint selCenter
				local viewOffset = mouse.screenpos - mouse.pos
				local absPos = viewOffset + [pt2D.x, pt2D.y]
				BlenderGrab_KeyReaderV25.SetPos (absPos.x as integer) (absPos.y as integer)
				startMousePos = [pt2D.x, pt2D.y]
			) else (
				selCenter = BlenderGrab_GetCenterV25 BlenderGrab_ActiveNodesV25
				startMousePos = mouse.pos
			)
			
			if BlenderGrab_ActiveNodesV25.count > 0 do refRotTM = BlenderGrab_ActiveNodesV25[1].transform.rotation as matrix3
			
			-- Зчитуємо точний стан клавіш на момент запуску
			for k = 1 to 256 do wasPressedKeys[k] = BlenderGrab_KeyReaderV25.IsPressed k
			wasPressedX = wasPressedKeys[VK_X]; wasPressedY = wasPressedKeys[VK_Y]; wasPressedZ = wasPressedKeys[VK_Z]
			wasPressedG = wasPressedKeys[VK_G]; wasPressedR = wasPressedKeys[VK_R]; wasPressedS = wasPressedKeys[VK_S]
			wasPressedCtrl = wasPressedKeys[VK_CONTROL]; wasPressedEnter = wasPressedKeys[VK_RETURN]
			
			viewNorm = -(Inverse(getViewTM())).row3
			
			movingVertsOrig = BlenderGrab_GetMovingVertsV25 BlenderGrab_ActiveNodesV25
			if movingVertsOrig.count > 0 do (
				bboxMin = copy movingVertsOrig[1]
				bboxMax = copy movingVertsOrig[1]
				for v in movingVertsOrig do (
					if v.x < bboxMin.x do bboxMin.x = v.x
					if v.y < bboxMin.y do bboxMin.y = v.y
					if v.z < bboxMin.z do bboxMin.z = v.z
					if v.x > bboxMax.x do bboxMax.x = v.x
					if v.y > bboxMax.y do bboxMax.y = v.y
					if v.z > bboxMax.z do bboxMax.z = v.z
				)
			)
			
			gw.setTransform (matrix3 1)
			local centerScreen2D = gw.transPoint selCenter
			local centerScreen = [centerScreen2D.x, centerScreen2D.y]
			local vStart = startMousePos - centerScreen
			lastMouseAng = atan2 vStart.y vStart.x
			accumulatedAngle = 0.0
			
			theHold.Begin()
			
			-- SMART FREEZE TRICK: Завжди вмикається в режимі Object Mode
			BlenderGrab_OriginalStatesV25 = #()
			if subObjectLevel == undefined or subObjectLevel == 0 do (
				for obj in BlenderGrab_ActiveNodesV25 do (
					append BlenderGrab_OriginalStatesV25 #(obj, obj.isFrozen, obj.showFrozenInGray)
					obj.showFrozenInGray = false
					obj.isFrozen = true -- Захист від магніту до самого себе
				)
			)
			
			BlenderGrab_StateV25.isActive = true
			BlenderGrab_StateV25.mainAction = BlenderGrab_StartupActionV25
			BlenderGrab_StartupActionV25 = #grab -- Reset default
			BlenderGrab_StateV25.mode = #free
			BlenderGrab_StateV25.space = #global
			BlenderGrab_StateV25.pos = selCenter
			BlenderGrab_StateV25.rotTM = matrix3 1
			BlenderGrab_StateV25.updateCb = executeTransform
			
			-- Reset states for next normal run
			BlenderGrab_CustomBasePointV25 = undefined
			
			createDialog BlenderGrab_HiddenRollout pos:[-1000,-1000] width:10 height:10 style:#()
			BlenderGrab_HiddenRollout.clock.active = true
			
			unregisterRedrawViewsCallback BlenderGrab_DrawAxes
			registerRedrawViewsCallback BlenderGrab_DrawAxes
			
			isMoving = true
			updatePromptText()
			
			-- Wiggle mouse to trigger 3ds Max refresh
			local pX = 0, pY = 0
			if BlenderGrab_CustomBasePointV25 != undefined then (
				local pt2D = gw.transPoint selCenter
				local viewOffset = mouse.screenpos - mouse.pos
				pX = (viewOffset.x + pt2D.x) as integer
				pY = (viewOffset.y + pt2D.y) as integer
			) else (
				pX = mouse.screenpos.x as integer
				pY = mouse.screenpos.y as integer
			)
			BlenderGrab_KeyReaderV25.SetPos pX (pY + 1)
			BlenderGrab_KeyReaderV25.SetPos pX pY
		)

		on freeMove do ( executeTransform() )

		on mousePoint clickNum do (
			if clickNum == 1 then (
				BlenderGrab_RepeatStateV25.isValid = true
				BlenderGrab_RepeatStateV25.actionType = BlenderGrab_StateV25.mainAction
				BlenderGrab_RepeatStateV25.spaceMode = BlenderGrab_StateV25.space
				BlenderGrab_RepeatStateV25.rotTM = BlenderGrab_StateV25.rotTM
				
				if BlenderGrab_StateV25.mainAction == #grab then BlenderGrab_RepeatStateV25.val = lastAppliedOffset
				else if BlenderGrab_StateV25.mainAction == #rotate then BlenderGrab_RepeatStateV25.val = (angleaxis lastAppliedAngle lastRotAxis)
				else if BlenderGrab_StateV25.mainAction == #scale then BlenderGrab_RepeatStateV25.val = lastAppliedScale
				
				theHold.Accept "Blender Transform"
				#stop
			)
		)

		on mouseAbort arg do (
			theHold.Cancel()
			#stop
		)
		
		on stop do (
			isMoving = false
			enableAccelerators = true
			BlenderGrab_StateV25.isActive = false
			BlenderGrab_StateV25.updateCb = undefined
			
			-- Resume hook if Full Mode is ON
			if BlenderGrab_KeyReaderV25 != undefined do BlenderGrab_KeyReaderV25.isToolActive = false
			
			BlenderGrab_HiddenRollout.clock.active = false
			try(destroyDialog BlenderGrab_HiddenRollout)catch()
			
			unregisterRedrawViewsCallback BlenderGrab_DrawAxes
			popPrompt()
			gw.updatescreen()
			
			-- UNFREEZE AND RESTORE SELECTION
			if BlenderGrab_OriginalStatesV25.count > 0 do (
				for item in BlenderGrab_OriginalStatesV25 do (
					if isValidNode item[1] do (
						item[1].isFrozen = item[2]
						item[1].showFrozenInGray = item[3]
					)
				)
				BlenderGrab_OriginalStatesV25 = #()
				if BlenderGrab_ActiveNodesV25.count > 0 do select BlenderGrab_ActiveNodesV25
			)
		)
	)

	startTool BlenderGrab_MouseTool
)

-- ============================================================================
-- DUPLICATE MACRO (Shift+D)
-- ============================================================================
macroScript BlenderDuplicateTool
category:"Custom Tools"
tooltip:"Blender Duplicate (Shift+D)"
buttonText:"B-Duplicate"
(
	on execute do (
		if selection.count == 0 do (
			messageBox "Select an object to duplicate." title:"Blender Duplicate"
			return()
		)
		
		local shouldLaunchGrab = false
		
		if subObjectLevel == undefined or subObjectLevel == 0 then (
			local clonedObjs = #()
			maxOps.cloneNodes selection cloneType:#instance newNodes:&clonedObjs
			
			if clonedObjs.count > 0 do (
				clearSelection()
				select clonedObjs
				shouldLaunchGrab = true
			)
		) else (
			local processedAny = false
			local cancelAll = false
			
			for obj in selection do (
				if cancelAll do continue
				local curMod = modPanel.getCurrentObject()
				
				if classOf curMod == Editable_Poly then (
					if subObjectLevel == 4 or subObjectLevel == 5 then (
						local selFaces = polyop.getFaceSelection obj
						if selFaces.isEmpty do continue
						
						local oldNumFaces = polyop.getNumFaces obj
						with quiet true (
							polyop.detachFaces obj selFaces delete:false asNode:false
						)
						local newNumFaces = polyop.getNumFaces obj
						
						if newNumFaces > oldNumFaces do (
							local clonedSel = #{oldNumFaces+1..newNumFaces}
							polyop.setFaceSelection obj clonedSel
							processedAny = true
						)
					) else (
						messageBox "Sub-object duplication is restricted to Polygons and Elements only." title:"Blender Duplicate"
						cancelAll = true
					)
				) else (
					messageBox "Sub-object duplication is restricted to Editable Poly base object." title:"Blender Duplicate"
					cancelAll = true
				)
			)
			
			if processedAny and not cancelAll do shouldLaunchGrab = true
		)
		
		if shouldLaunchGrab do (
			global BlenderGrab_LaunchRollout
			try(destroyDialog BlenderGrab_LaunchRollout)catch()
			rollout BlenderGrab_LaunchRollout "Launch" (
				timer launchTimer "launchTimer" interval:10 active:true
				on launchTimer tick do (
					launchTimer.active = false
					try(destroyDialog BlenderGrab_LaunchRollout)catch()
					
					BlenderGrab_StartupActionV25 = #grab
					macros.run "Custom Tools" "BlenderGrabTool"
				)
			)
			createDialog BlenderGrab_LaunchRollout pos:[-1000,-1000] width:10 height:10 style:#()
		)
	)
)

-- ============================================================================
-- REPEAT LAST ACTION MACRO (Shift+R)
-- ============================================================================
macroScript BlenderRepeatTool
category:"Custom Tools"
tooltip:"Blender Repeat (Shift+R)"
buttonText:"B-Repeat"
(
	on execute do (
		if selection.count == 0 do return()
		if not BlenderGrab_RepeatStateV25.isValid do (
			messageBox "No valid transformation saved yet. Use Grab/Rotate/Scale first." title:"Blender Repeat"
			return()
		)
		
		local shouldApply = false
		
		if subObjectLevel == undefined or subObjectLevel == 0 then (
			local clonedObjs = #()
			maxOps.cloneNodes selection cloneType:#instance newNodes:&clonedObjs
			
			if clonedObjs.count > 0 do (
				clearSelection()
				select clonedObjs
				shouldApply = true
			)
		) else (
			local processedAny = false
			local cancelAll = false
			
			for obj in selection do (
				if cancelAll do continue
				local curMod = modPanel.getCurrentObject()
				
				if classOf curMod == Editable_Poly then (
					if subObjectLevel == 4 or subObjectLevel == 5 then (
						local selFaces = polyop.getFaceSelection obj
						if selFaces.isEmpty do continue
						
						local oldNumFaces = polyop.getNumFaces obj
						with quiet true (
							polyop.detachFaces obj selFaces delete:false asNode:false
						)
						local newNumFaces = polyop.getNumFaces obj
						
						if newNumFaces > oldNumFaces do (
							local clonedSel = #{oldNumFaces+1..newNumFaces}
							polyop.setFaceSelection obj clonedSel
							processedAny = true
						)
					) else (
						messageBox "Sub-object duplication is restricted to Polygons and Elements only." title:"Blender Repeat"
						cancelAll = true
					)
				) else (
					messageBox "Sub-object duplication is restricted to Editable Poly base object." title:"Blender Repeat"
					cancelAll = true
				)
			)
			if processedAny and not cancelAll do shouldApply = true
		)
		
		if shouldApply do (
			theHold.Begin()
			BlenderGrab_ActiveNodesV25 = selection as array
			local center = BlenderGrab_GetCenterV25 BlenderGrab_ActiveNodesV25
			
			BlenderGrab_ApplyActionV25 BlenderGrab_RepeatStateV25.actionType BlenderGrab_RepeatStateV25.val BlenderGrab_RepeatStateV25.rotTM center BlenderGrab_RepeatStateV25.spaceMode
			
			theHold.Accept "Blender Repeat Action"
			gw.updatescreen()
		)
	)
)