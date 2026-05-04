-- ============================================================================
-- Blender Transform Engine (Logic & Functions)
-- ============================================================================
-- Place this file in: scripts/startup

-- Глобальне оголошення станів
global BlenderGrab_StateV25
struct BGrabStateStructV25 ( isActive = false, mainAction = #grab, mode = #free, space = #global, pos = [0,0,0], rotTM = matrix3 1, updateCb = undefined )
::BlenderGrab_StateV25 = BGrabStateStructV25()

global BlenderGrab_RepeatStateV25
struct BRepeatStateStructV25 ( isValid = false, actionType = #grab, val = undefined, spaceMode = #global, rotTM = matrix3 1 )
::BlenderGrab_RepeatStateV25 = BRepeatStateStructV25()

global BlenderGrab_StartupActionV25
::BlenderGrab_StartupActionV25 = #grab

-- Point Snapping Globals
global BlenderGrab_CustomBasePointV25
::BlenderGrab_CustomBasePointV25 = undefined

global BlenderGrab_ActiveNodesV25
::BlenderGrab_ActiveNodesV25 = #()

global BlenderGrab_OriginalStatesV25
::BlenderGrab_OriginalStatesV25 = #()

global BlenderGrab_FullModeActive
::BlenderGrab_FullModeActive = false

-- ============================================================================
-- C# WRAPPER (Mouse Simulation & Keyboard & Hook)
-- ============================================================================
global BlenderGrab_KeyReaderV25
try(if ::BlenderGrab_KeyReaderV25 != undefined do ::BlenderGrab_KeyReaderV25.RemoveHook())catch()

(
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
	::BlenderGrab_KeyReaderV25 = results.CompiledAssembly.CreateInstance "KeyReaderV25"
)

callbacks.removeScripts id:#BlenderGrabCleanup
callbacks.addScript #preSystemShutdown "try(::BlenderGrab_KeyReaderV25.RemoveHook())catch()" id:#BlenderGrabCleanup

-- ============================================================================
-- GLOBAL BACKGROUND TIMERS
-- ============================================================================
global BlenderGrab_GlobalHookTimer
try(destroyDialog ::BlenderGrab_GlobalHookTimer)catch()
rollout BlenderGrab_GlobalHookTimer "BGHookTimer" (
	timer clock "clock" interval:15 active:true
	on clock tick do (
		if ::BlenderGrab_KeyReaderV25 != undefined and ::BlenderGrab_KeyReaderV25.isHookActive then (
			local doG = ::BlenderGrab_KeyReaderV25.consumeG
			local doR = ::BlenderGrab_KeyReaderV25.consumeR
			local doS = ::BlenderGrab_KeyReaderV25.consumeS
			
			::BlenderGrab_KeyReaderV25.consumeG = false
			::BlenderGrab_KeyReaderV25.consumeR = false
			::BlenderGrab_KeyReaderV25.consumeS = false
			
			if ::BlenderGrab_StateV25 != undefined and not ::BlenderGrab_StateV25.isActive then (
				if doG then ( ::BlenderGrab_StartupActionV25 = #grab; macros.run "Custom Tools" "BlenderGrabTool" )
				else if doR then ( ::BlenderGrab_StartupActionV25 = #rotate; macros.run "Custom Tools" "BlenderGrabTool" )
				else if doS then ( ::BlenderGrab_StartupActionV25 = #scale; macros.run "Custom Tools" "BlenderGrabTool" )
			)
		)
	)
)
createDialog ::BlenderGrab_GlobalHookTimer pos:[-1000,-1000] width:10 height:10 style:#()

global BlenderGrab_HiddenRollout
try(destroyDialog ::BlenderGrab_HiddenRollout)catch()
rollout BlenderGrab_HiddenRollout "BGTimer" (
	timer clock "clock" interval:15 active:false
	on clock tick do (
		if ::BlenderGrab_StateV25 != undefined and ::BlenderGrab_StateV25.isActive and ::BlenderGrab_StateV25.updateCb != undefined do (
			::BlenderGrab_StateV25.updateCb()
		)
	)
)
createDialog ::BlenderGrab_HiddenRollout pos:[-1000,-1000] width:10 height:10 style:#()

-- ============================================================================
-- GLOBAL MATHEMATICS FUNCTIONS
-- ============================================================================

global BlenderGrab_GetSubObjMatrixV25
::BlenderGrab_GetSubObjMatrixV25 = fn BlenderGrab_GetSubObjMatrixV25_Func activeNodes = (
	if activeNodes.count == 0 do return matrix3 1
	local baseTM = activeNodes[1].transform.rotation as matrix3
	local avgNormal = [0,0,0]
	local normCount = 0
	
	for obj in activeNodes do (
		local curMod = modPanel.getCurrentObject()
		if curMod == undefined do curMod = obj.baseObject
		local cClassStr = classOf curMod as string
		
		if cClassStr == "Editable_Poly" then (
			local faces = #{}
			case subObjectLevel of (
				1: faces = polyop.getFacesUsingVert obj (polyop.getVertSelection obj)
				2: faces = polyop.getFacesUsingEdge obj (polyop.getEdgeSelection obj)
				3: faces = polyop.getFacesUsingEdge obj (polyop.getEdgeSelection obj)
				4: faces = polyop.getFaceSelection obj
				5: faces = polyop.getFaceSelection obj
			)
			-- Беремо чисту нормаль у світовому просторі без подвійного множення
			in coordsys world (
				for f in faces do (
					avgNormal += normalize (polyop.getFaceNormal obj f)
					normCount += 1
				)
			)
		)
		else if cClassStr == "Edit_Poly" or cClassStr == "Editable_Mesh" then (
			local tempMesh = undefined
			try(tempMesh = snapshotAsMesh obj)catch()
			if tempMesh != undefined do (
				local faces = #{}
				if cClassStr == "Edit_Poly" then (
					case subObjectLevel of (
						1: faces = meshop.getFacesUsingVert tempMesh (curMod.GetSelection #Vertex)
						2: faces = meshop.getFacesUsingEdge tempMesh (curMod.GetSelection #Edge)
						3: faces = meshop.getFacesUsingEdge tempMesh (curMod.GetSelection #Edge)
						4: faces = curMod.GetSelection #Face
						5: faces = curMod.GetSelection #Face
					)
				) else (
					case subObjectLevel of (
						1: faces = meshop.getFacesUsingVert tempMesh (getVertSelection obj)
						2: faces = meshop.getFacesUsingEdge tempMesh (getEdgeSelection obj)
						3: faces = meshop.getFacesUsingEdge tempMesh (getEdgeSelection obj)
						4: faces = getFaceSelection obj
						5: faces = getFaceSelection obj
					)
				)
				for f in faces do (
					avgNormal += normalize (getFaceNormal tempMesh f)
					normCount += 1
				)
				free tempMesh
			)
		)
	)
	
	if normCount > 0 then (
		local zAxis = normalize (avgNormal / normCount)
		if length zAxis > 0.001 then (
			-- Використовуємо локальний Z об'єкта як напрямок 'вгору' для стабільної орієнтації X/Y
			local upAxis = normalize baseTM.row3
			if abs(dot zAxis upAxis) > 0.99 do upAxis = normalize baseTM.row2
			if abs(dot zAxis upAxis) > 0.99 do upAxis = normalize baseTM.row1

			local xAxis = normalize (cross upAxis zAxis)
			local yAxis = normalize (cross zAxis xAxis)
			return matrix3 xAxis yAxis zAxis [0,0,0]
		) else return baseTM
	) else return baseTM
)

global BlenderGrab_DrawAxes
::BlenderGrab_DrawAxes = fn BlenderGrab_DrawAxes_Func = (
	if not ::BlenderGrab_StateV25.isActive do return()
	local drawTM = copy ::BlenderGrab_StateV25.rotTM
	drawTM.translation = ::BlenderGrab_StateV25.pos
	gw.setTransform drawTM 
	local p = [0,0,0], s = 100000.0 
	case ::BlenderGrab_StateV25.mode of (
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

global BlenderGrab_IntersectRayV25
::BlenderGrab_IntersectRayV25 = fn BlenderGrab_IntersectRayV25_Func rayObj planeNormal planePoint = (
	local d = dot planeNormal rayObj.dir
	if abs d < 0.0001 then return undefined
	local t = (dot planeNormal (planePoint - rayObj.pos)) / d
	return (rayObj.pos + rayObj.dir * t)
)

global BlenderGrab_GetCenterV25
::BlenderGrab_GetCenterV25 = fn BlenderGrab_GetCenterV25_Func activeNodes = (
	if activeNodes.count == 0 do return [0,0,0]
	if subObjectLevel == undefined or subObjectLevel == 0 then (
		local centerPos = [0,0,0]
		for obj in activeNodes do centerPos += obj.pivot
		return (centerPos / activeNodes.count)
	)
	local centerPos = [0,0,0], vertCount = 0
	local processedMods = #()
	
	for obj in activeNodes do (
		local curMod = modPanel.getCurrentObject()
		if curMod == undefined do curMod = obj.baseObject
		
		local cClassStr = classOf curMod as string
		local trackItem = curMod
		
		if cClassStr == "Editable_Poly" or cClassStr == "Editable_Mesh" or cClassStr == "line" or cClassStr == "Editable_Spline" or cClassStr == "SplineShape" then (
			trackItem = obj.baseObject
		)
		
		if findItem processedMods trackItem > 0 do continue
		append processedMods trackItem
		
		if cClassStr == "Editable_Poly" then (
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
		else if cClassStr == "Edit_Poly" then (
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
		else if cClassStr == "Editable_Mesh" then (
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
		else if cClassStr == "line" or cClassStr == "Editable_Spline" or cClassStr == "SplineShape" then (
			for s = 1 to (numSplines obj) do (
				local knots = getKnotSelection obj s
				for k in knots do ( centerPos += getKnotPoint obj s k; vertCount += 1 )
			)
		)
		else if hasProperty curMod #gizmo then (
			if subObjectLevel == 1 then (
				local gTM = curMod.gizmo.transform * obj.objectTransform
				centerPos += gTM.translation
				vertCount += 1
			) else if subObjectLevel == 2 and hasProperty curMod #center then (
				local cPos = curMod.center * obj.objectTransform
				centerPos += cPos
				vertCount += 1
			)
		)
		else if matchPattern cClassStr pattern:"FFD*" then (
			centerPos += selection.center
			vertCount += 1
		)
	)
	if vertCount > 0 then return (centerPos / vertCount) else return selection.center
)

global BlenderGrab_GetMovingVertsV25
::BlenderGrab_GetMovingVertsV25 = fn BlenderGrab_GetMovingVertsV25_Func activeNodes = (
	local vertsArr = #()
	if subObjectLevel == undefined or subObjectLevel == 0 do return vertsArr
	
	local processedMods = #()
	
	for obj in activeNodes do (
		local curMod = modPanel.getCurrentObject()
		if curMod == undefined do curMod = obj.baseObject
		
		local cClassStr = classOf curMod as string
		local trackItem = curMod
		
		if cClassStr == "Editable_Poly" or cClassStr == "Editable_Mesh" or cClassStr == "line" or cClassStr == "Editable_Spline" or cClassStr == "SplineShape" then (
			trackItem = obj.baseObject
		)
		
		if findItem processedMods trackItem > 0 do continue
		append processedMods trackItem
		
		if cClassStr == "Editable_Poly" then (
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
		else if cClassStr == "Edit_Poly" then (
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
		else if cClassStr == "Editable_Mesh" then (
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
		else if cClassStr == "line" or cClassStr == "Editable_Spline" or cClassStr == "SplineShape" then (
			for s = 1 to (numSplines obj) do (
				local knots = getKnotSelection obj s
				for k in knots do append vertsArr (getKnotPoint obj s k)
			)
		)
	)
	return vertsArr
)

global BlenderGrab_ApplyActionV25
::BlenderGrab_ApplyActionV25 = fn BlenderGrab_ApplyActionV25_Func actionType val workTM center spaceMode = (
	local activeNodes = ::BlenderGrab_ActiveNodesV25
	if activeNodes.count == 0 do return()
	
	if subObjectLevel == undefined or subObjectLevel == 0 then (
		if spaceMode == #local then (
			local invWorkTM = inverse workTM
			for obj in activeNodes do (
				local oldPos = obj.pos
				local objTM = obj.transform.rotation as matrix3
				
				if actionType == #grab do (
					local localDelta = val * invWorkTM
					local perObjWorldDelta = localDelta * objTM
					obj.pos += perObjWorldDelta
				)
				if actionType == #rotate do (
					local localAxis = val.axis * invWorkTM
					local perObjWorldAxis = localAxis * objTM
					about oldPos in coordsys world rotate obj (angleaxis val.angle perObjWorldAxis)
				)
				if actionType == #scale do (
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
	
	local processedMods = #()
	
	for obj in activeNodes do (
		local curMod = modPanel.getCurrentObject()
		if curMod == undefined do curMod = obj.baseObject
		
		local cClassStr = classOf curMod as string
		local trackItem = curMod
		
		if cClassStr == "Editable_Poly" or cClassStr == "Editable_Mesh" or cClassStr == "line" or cClassStr == "Editable_Spline" or cClassStr == "SplineShape" then (
			trackItem = obj.baseObject
		)
		
		if findItem processedMods trackItem > 0 do continue
		append processedMods trackItem
		
		if cClassStr == "Editable_Poly" then (
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
		else if cClassStr == "Edit_Poly" then (
			if actionType == #grab do curMod.MoveSelection val
			if actionType == #rotate do curMod.RotateSelection val
			if actionType == #scale do curMod.ScaleSelection val
			curMod.Commit()
		)
		else if cClassStr == "Editable_Mesh" then (
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
		else if cClassStr == "line" or cClassStr == "Editable_Spline" or cClassStr == "SplineShape" then (
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
		else if hasProperty curMod #gizmo then (
			if subObjectLevel == 1 then (
				local gTM = curMod.gizmo.transform * obj.objectTransform
				local preTrans = transMatrix (-center)
				local postTrans = transMatrix center
				local finalTM = preTrans * deltaTM * postTrans
				curMod.gizmo.transform = gTM * finalTM * (inverse obj.objectTransform)
			) else if subObjectLevel == 2 and hasProperty curMod #center then (
				local cPos = curMod.center * obj.objectTransform
				cPos = (cPos - center) * deltaTM + center
				curMod.center = cPos * (inverse obj.objectTransform)
			)
		)
	)
)

print "Blender Transform Engine V25 (Sub-Object Local Orientation Ready) Loaded."