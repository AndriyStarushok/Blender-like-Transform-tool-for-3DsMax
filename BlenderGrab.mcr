-- ============================================================================
-- Інструменти трансформації у стилі Blender (Grab, Rotate, Scale) для 3ds Max
-- ============================================================================

-- Глобальний стан (Оновлено до V15 для очищення пам'яті)
global BlenderGrab_StateV15
struct BGrabStateStructV15 ( isActive = false, mainAction = #grab, mode = #free, space = #global, pos = [0,0,0], rotTM = matrix3 1, updateCb = undefined )
if BlenderGrab_StateV15 == undefined do BlenderGrab_StateV15 = BGrabStateStructV15()

-- Глобальний фоновий таймер для відв'язки розрахунків від руху миші
global BlenderGrab_HiddenRollout
try(destroyDialog BlenderGrab_HiddenRollout)catch()
rollout BlenderGrab_HiddenRollout "BGTimer" (
	timer clock "clock" interval:15 active:false -- ~60 FPS
	on clock tick do (
		if BlenderGrab_StateV15 != undefined and BlenderGrab_StateV15.isActive and BlenderGrab_StateV15.updateCb != undefined do (
			BlenderGrab_StateV15.updateCb()
		)
	)
)

-- Функція для візуального малювання нескінченних вісей у в'юпорті
global BlenderGrab_DrawAxes
fn BlenderGrab_DrawAxes = (
	if not BlenderGrab_StateV15.isActive do return()
	
	local drawTM = copy BlenderGrab_StateV15.rotTM
	drawTM.translation = BlenderGrab_StateV15.pos
	gw.setTransform drawTM 
	
	local p = [0,0,0]
	local s = 100000.0 
	
	case BlenderGrab_StateV15.mode of (
		#x: ( gw.setColor #line red; gw.polyline #(p - [s,0,0], p + [s,0,0]) false )
		#y: ( gw.setColor #line green; gw.polyline #(p - [0,s,0], p + [0,s,0]) false )
		#z: ( gw.setColor #line blue; gw.polyline #(p - [0,0,s], p + [0,0,s]) false )
		#shiftX: ( 
			gw.setColor #line green; gw.polyline #(p - [0,s,0], p + [0,s,0]) false
			gw.setColor #line blue; gw.polyline #(p - [0,0,s], p + [0,0,s]) false
		)
		#shiftY: ( 
			gw.setColor #line red; gw.polyline #(p - [s,0,0], p + [s,0,0]) false
			gw.setColor #line blue; gw.polyline #(p - [0,0,s], p + [0,0,s]) false
		)
		#shiftZ: ( 
			gw.setColor #line red; gw.polyline #(p - [s,0,0], p + [s,0,0]) false
			gw.setColor #line green; gw.polyline #(p - [0,s,0], p + [0,s,0]) false
		)
	)
	gw.enlargeUpdateRect #whole
	gw.setTransform (matrix3 1)
)

macroScript BlenderGrabTool
category:"Custom Tools"
tooltip:"Blender Transform (G, R, S)"
buttonText:"B-Transform"
(
	-- Туторіал Rollout
	rollout BlenderGrab_TutorialRollout "Blender Transform Tool - Quick Guide" width:370 height:360
	(
		label lbl_title "--- BLENDER WORKFLOW IN 3DS MAX ---" style_sunkenedge:false width:350 height:18 align:#center
		
		label lbl_h1 "HOTKEYS:" pos:[15, 30] style_sunkenedge:true width:340 height:18
		
		label lbl_k1 "G" pos:[20, 55] bold:true
		label lbl_k1d "- Enter tool mode (starts with Grab)" pos:[100, 55]
		
		label lbl_k1a "R, S" pos:[20, 75] bold:true
		label lbl_k1ad "- Rotate / Scale (only AFTER pressing G)" pos:[100, 75]
		
		label lbl_k2 "X, Y, Z" pos:[20, 95] bold:true
		label lbl_k2d "- Constrain Axis (Global -> Local -> Free)" pos:[100, 95]
		
		label lbl_k3 "Shift+XYZ" pos:[20, 115] bold:true
		label lbl_k3d "- Constrain Plane (e.g. Shift+Z locks XY)" pos:[100, 115]
		
		label lbl_k4 "Ctrl" pos:[20, 135] bold:true
		label lbl_k4d "- Toggle Snapping on/off" pos:[100, 135]
		
		label lbl_k5 "LMB" pos:[20, 155] bold:true
		label lbl_k5d "- Apply Transform" pos:[100, 155]
		
		label lbl_k6 "RMB / Esc" pos:[20, 175] bold:true
		label lbl_k6d "- Cancel Transform" pos:[100, 175]
		
		label lbl_tip "Tip: Mouse wraps around screen edges automatically!" pos:[15, 205] 
		
		label lbl_setup "HOW TO ASSIGN A HOTKEY:" pos:[15, 235] style_sunkenedge:true width:340 height:18
		label lbl_set1 "1. Go to: Customize -> Hotkey Editor" pos:[20, 260]
		label lbl_set2 "2. Search for: 'Blender Transform'" pos:[20, 275]
		label lbl_set3 "3. Assign the 'G' key and click Assign/Save." pos:[20, 290]
		
		checkbox chk_dontShow "Don't show this anymore" pos:[15, 325]
		button btn_ok "Got it!" width:100 height:30 pos:[255, 320]
		
		on btn_ok pressed do (
			if chk_dontShow.checked do (
				local iniPath = (GetDir #plugcfg) + "\\BlenderGrabTool.ini"
				setINISetting iniPath "Settings" "ShowTutorial" "false"
			)
			destroyDialog BlenderGrab_TutorialRollout
		)
	)

	-- Перевірка чи потрібно показувати туторіал
	local iniPath = (GetDir #plugcfg) + "\\BlenderGrabTool.ini"
	local showTutorial = (getINISetting iniPath "Settings" "ShowTutorial")
	if showTutorial != "false" do (
		try(destroyDialog BlenderGrab_TutorialRollout)catch()
		createDialog BlenderGrab_TutorialRollout modal:true
	)

	-- 1. Створюємо C#-обгортку (Оновлено до V15)
	global BlenderGrab_KeyReaderV15
	if BlenderGrab_KeyReaderV15 == undefined do (
		local csharpSource = "
		using System;
		using System.Runtime.InteropServices;
		public class KeyReaderV15 {
			[DllImport(\"user32.dll\")]
			public static extern short GetAsyncKeyState(int vKey);
			
			[DllImport(\"user32.dll\")]
			public static extern bool SetCursorPos(int X, int Y);
			
			public bool IsPressed(int keyCode) {
				return (GetAsyncKeyState(keyCode) & 0x8000) != 0;
			}
			
			public void SetPos(int X, int Y) {
				SetCursorPos(X, Y);
			}
		}"
		local compilerParams = dotnetobject "System.CodeDom.Compiler.CompilerParameters"
		compilerParams.GenerateInMemory = true
		local compiler = dotnetobject "Microsoft.CSharp.CSharpCodeProvider"
		local results = compiler.CompileAssemblyFromSource compilerParams #(csharpSource)
		BlenderGrab_KeyReaderV15 = results.CompiledAssembly.CreateInstance "KeyReaderV15"
	)

	-- 2. Перетин променя екрану та площини
	fn intersectRayPlane rayObj planeNormal planePoint = (
		local d = dot planeNormal rayObj.dir
		if abs d < 0.0001 then return undefined
		local t = (dot planeNormal (planePoint - rayObj.pos)) / d
		return (rayObj.pos + rayObj.dir * t)
	)

	-- 3. Функція для отримання правильного центру виділення
	fn getSelectionCenter = (
		if selection.count == 0 do return [0,0,0]
		
		if subObjectLevel == undefined or subObjectLevel == 0 then (
			local centerPos = [0,0,0]
			for obj in selection do centerPos += obj.pivot
			return (centerPos / selection.count)
		)
		
		local centerPos = [0,0,0], vertCount = 0
		
		for obj in selection do (
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

	-- 4. Універсальна функція застосування трансформацій
	fn applyActionDeltaToSelection actionType val workTM center spaceMode = (
		if subObjectLevel == undefined or subObjectLevel == 0 then (
			if actionType == #grab then (
				in coordsys world move selection val
			) else (
				if spaceMode == #local then (
					for obj in selection do (
						local oldPos = obj.pos
						local objTM = obj.transform.rotation as matrix3
						
						if actionType == #rotate do about oldPos in coordsys world rotate obj val
						if actionType == #scale do in coordsys objTM about oldPos scale obj val
						
						obj.pos = oldPos 
					)
				) else (
					local oldPos = if selection.count == 1 then selection[1].pos else undefined
					
					if actionType == #rotate do about center in coordsys world rotate selection val
					if actionType == #scale do in coordsys workTM about center scale selection val
					
					if oldPos != undefined do selection[1].pos = oldPos
				)
			)
			return()
		)
		
		local deltaTM = matrix3 1
		if actionType == #grab do deltaTM.translation = val
		if actionType == #rotate do deltaTM = val as matrix3
		if actionType == #scale do deltaTM = (inverse workTM) * scaleMatrix val * workTM
		
		local objs = selection as array
		for obj in objs do (
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

	-- 5. Головний інструмент миші
	tool BlenderGrab_MouseTool
	(
		local startMousePos
		local selCenter
		local viewNorm
		local currentMode = #free
		local currentSpace = #global
		local refRotTM = matrix3 1
		local isMoving = false
		local startHitPos
		
		local lastAppliedOffset = [0,0,0]
		local lastAppliedAngle = 0.0
		local lastAppliedScale = [1,1,1]
		
		local lastMouseAng = 0.0
		local accumulatedAngle = 0.0
		
		local wasPressedX = false, wasPressedY = false, wasPressedZ = false
		local wasPressedG = false, wasPressedR = false, wasPressedS = false
		local wasPressedCtrl = false
		
		local VK_X = 0x58, VK_Y = 0x59, VK_Z = 0x5A
		local VK_G = 0x47, VK_R = 0x52, VK_S = 0x53, VK_SHIFT = 0x10, VK_CONTROL = 0x11
		
		local virtualMouseOffset = [0,0]
		
		fn updatePromptText = (
			local actionStr = case BlenderGrab_StateV15.mainAction of (
				#grab: "Переміщення"
				#rotate: "Обертання"
				#scale: "Масштаб"
			)
			local modeStr = case currentMode of (
				#free: "Вільний рух"
				#x: "Вісь X"
				#y: "Вісь Y"
				#z: "Вісь Z"
				#shiftX: "Площина YZ"
				#shiftY: "Площина XZ"
				#shiftZ: "Площина XY"
			)
			local spaceStr = if currentMode != #free then (if currentSpace == #global then " (Глобально)" else " (Локально)") else ""
			pushPrompt (actionStr + " | " + modeStr + spaceStr + " | X,Y,Z - вісі | G,R,S - режим | Ctrl - Snap")
		)
		
		-- Уся логіка винесена в єдину функцію, яку викликає і миша, і таймер
		fn executeTransform = (
			if not isMoving do return()
			enableAccelerators = false
			
			gw.setTransform (matrix3 1)
			local centerScreen2D = gw.transPoint selCenter
			local centerScreen = [centerScreen2D.x, centerScreen2D.y]
				
			local isPressedX = BlenderGrab_KeyReaderV15.IsPressed VK_X
			local isPressedY = BlenderGrab_KeyReaderV15.IsPressed VK_Y
			local isPressedZ = BlenderGrab_KeyReaderV15.IsPressed VK_Z
			local isPressedG = BlenderGrab_KeyReaderV15.IsPressed VK_G
			local isPressedR = BlenderGrab_KeyReaderV15.IsPressed VK_R
			local isPressedS = BlenderGrab_KeyReaderV15.IsPressed VK_S
			local isPressedCtrl = BlenderGrab_KeyReaderV15.IsPressed VK_CONTROL
			local shiftPressed = BlenderGrab_KeyReaderV15.IsPressed VK_SHIFT or keyboard.shiftPressed
			
			local justPressedX = isPressedX and not wasPressedX
			local justPressedY = isPressedY and not wasPressedY
			local justPressedZ = isPressedZ and not wasPressedZ
			local justPressedG = isPressedG and not wasPressedG
			local justPressedR = isPressedR and not wasPressedR
			local justPressedS = isPressedS and not wasPressedS
			local justPressedCtrl = isPressedCtrl and not wasPressedCtrl
			
			-- Перемикання прив'язки кліком на Ctrl
			if justPressedCtrl do snapMode.active = not snapMode.active
			
			-- Зміна РЕЖИМУ (G, R, S)
			if justPressedG or justPressedR or justPressedS do (
				theHold.Cancel()
				theHold.Begin()
				
				if justPressedG do BlenderGrab_StateV15.mainAction = #grab
				if justPressedR do BlenderGrab_StateV15.mainAction = #rotate
				if justPressedS do BlenderGrab_StateV15.mainAction = #scale
				
				currentMode = #free
				currentSpace = #global
				
				startMousePos = mouse.pos
				local sRay = mapScreenToWorldRay startMousePos
				startHitPos = intersectRayPlane sRay viewNorm selCenter
				
				local vStart = startMousePos - centerScreen
				lastMouseAng = atan2 vStart.y vStart.x
				accumulatedAngle = 0.0
				
				lastAppliedOffset = [0,0,0]
				lastAppliedAngle = 0.0
				lastAppliedScale = [1,1,1]
				virtualMouseOffset = [0,0]
			)
			
			-- Зміна ВІСЕЙ (X, Y, Z) 
			fn cycleMode targetMode = (
				theHold.Cancel()
				theHold.Begin()
				
				lastAppliedOffset = [0,0,0]
				lastAppliedAngle = 0.0
				lastAppliedScale = [1,1,1]
				
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
			wasPressedCtrl = isPressedCtrl

			-- Screen Wrap
			local mPos = mouse.pos
			local viewX = gw.getWinSizeX(), viewY = gw.getWinSizeY()
			local isWrapped = false, wrapX = 0, wrapY = 0
			
			if mPos.x <= 2 then ( wrapX = viewX - 6; isWrapped = true )
			if mPos.x >= viewX - 2 then ( wrapX = -(viewX - 6); isWrapped = true )
			if mPos.y <= 2 then ( wrapY = viewY - 6; isWrapped = true )
			if mPos.y >= viewY - 2 then ( wrapY = -(viewY - 6); isWrapped = true )
			
			if isWrapped do (
				local newScreenPos = mouse.screenpos + [wrapX, wrapY]
				BlenderGrab_KeyReaderV15.SetPos (newScreenPos.x as integer) (newScreenPos.y as integer)
				virtualMouseOffset += [-wrapX, -wrapY]
				mPos = mPos + [wrapX, wrapY]
			)

			local virtualMousePos = mPos + virtualMouseOffset
			local action = BlenderGrab_StateV15.mainAction
			local workTM = if currentSpace == #local then refRotTM else (matrix3 1)
			
			-- ==========================================
			-- ЛОГІКА: ПЕРЕМІЩЕННЯ (GRAB)
			-- ==========================================
			if action == #grab then (
				local rawOffset = undefined
				local snapPt = undefined
				if snapMode.active do try ( if snapMode.hit == true do snapPt = snapMode.worldHitpoint ) catch ()
				
				if snapPt != undefined then (
					if snapMode.type == #2_5D or snapMode.type == #2D do (
						local vToSnap = snapPt - selCenter
						snapPt = snapPt - (viewNorm * (dot vToSnap viewNorm))
					)
					rawOffset = snapPt - selCenter 
				) else (
					local mRay = mapScreenToWorldRay virtualMousePos
					local hitCurrent = intersectRayPlane mRay viewNorm selCenter
					if hitCurrent != undefined and startHitPos != undefined do rawOffset = hitCurrent - startHitPos
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
					
					local finalOffset = localFinalOffset * workTM
					local deltaOffset = finalOffset - lastAppliedOffset
					
					if length(deltaOffset) > 0.0001 or justPressedX or justPressedY or justPressedZ or justPressedCtrl do (
						applyActionDeltaToSelection #grab deltaOffset workTM selCenter currentSpace
						lastAppliedOffset = finalOffset
						BlenderGrab_StateV15.mode = currentMode; BlenderGrab_StateV15.space = currentSpace
						BlenderGrab_StateV15.rotTM = workTM; BlenderGrab_StateV15.pos = selCenter + finalOffset
						gw.updatescreen()
					)
				)
			)
			-- ==========================================
			-- ЛОГІКА: ОБЕРТАННЯ (ROTATE)
			-- ==========================================
			else if action == #rotate then (
				local vCur = virtualMousePos - centerScreen
				local curAng = atan2 vCur.y vCur.x
				
				local frameDelta = curAng - lastMouseAng
				if frameDelta > 180.0 do frameDelta -= 360.0
				if frameDelta < -180.0 do frameDelta += 360.0
				
				accumulatedAngle += frameDelta
				lastMouseAng = curAng
				
				local rotAxis = viewNorm
				case currentMode of (
					#x: rotAxis = workTM.row1
					#y: rotAxis = workTM.row2
					#z: rotAxis = workTM.row3
					#shiftX: rotAxis = workTM.row1
					#shiftY: rotAxis = workTM.row2
					#shiftZ: rotAxis = workTM.row3
					#free: rotAxis = viewNorm
				)
				
				local rawAngle = accumulatedAngle
				local deltaAngle = rawAngle - lastAppliedAngle
				
				if abs(deltaAngle) > 0.001 or justPressedX or justPressedY or justPressedZ do (
					local qDelta = angleaxis deltaAngle rotAxis
					applyActionDeltaToSelection #rotate qDelta workTM selCenter currentSpace
					lastAppliedAngle = rawAngle
					BlenderGrab_StateV15.mode = currentMode; BlenderGrab_StateV15.space = currentSpace
					BlenderGrab_StateV15.rotTM = workTM; BlenderGrab_StateV15.pos = selCenter
					gw.updatescreen()
				)
			)
			-- ==========================================
			-- ЛОГІКА: МАСШТАБУВАННЯ (SCALE)
			-- ==========================================
			else if action == #scale then (
				local distStart = length (startMousePos - centerScreen)
				local distCur = length (virtualMousePos - centerScreen)
				if distStart < 1.0 do distStart = 1.0
				local rawRatio = distCur / distStart
				
				local localScale = [rawRatio, rawRatio, rawRatio]
				case currentMode of (
					#x: localScale = [rawRatio, 1, 1]
					#y: localScale = [1, rawRatio, 1]
					#z: localScale = [1, 1, rawRatio]
					#shiftX: localScale = [1, rawRatio, rawRatio]
					#shiftY: localScale = [rawRatio, 1, rawRatio]
					#shiftZ: localScale = [rawRatio, rawRatio, 1]
					#free: localScale = [rawRatio, rawRatio, rawRatio]
				)
				
				local deltaScale = [localScale.x / lastAppliedScale.x, localScale.y / lastAppliedScale.y, localScale.z / lastAppliedScale.z]
				
				if abs(deltaScale.x - 1.0) > 0.0001 or abs(deltaScale.y - 1.0) > 0.0001 or abs(deltaScale.z - 1.0) > 0.0001 or justPressedX or justPressedY or justPressedZ do (
					applyActionDeltaToSelection #scale deltaScale workTM selCenter currentSpace
					lastAppliedScale = localScale
					BlenderGrab_StateV15.mode = currentMode; BlenderGrab_StateV15.space = currentSpace
					BlenderGrab_StateV15.rotTM = workTM; BlenderGrab_StateV15.pos = selCenter
					gw.updatescreen()
				)
			)
		)
		
		on start do (
			if selection.count == 0 do (
				messageBox "Виберіть хоча б один об'єкт або під-об'єкт." title:"Blender Transform"
				return #stop
			)
			
			enableAccelerators = false 
			selCenter = getSelectionCenter()
			if selection.count > 0 do refRotTM = selection[1].transform.rotation as matrix3
			
			startMousePos = mouse.pos
			viewNorm = -(Inverse(getViewTM())).row3
			
			gw.setTransform (matrix3 1)
			local centerScreen2D = gw.transPoint selCenter
			local centerScreen = [centerScreen2D.x, centerScreen2D.y]
			local vStart = startMousePos - centerScreen
			lastMouseAng = atan2 vStart.y vStart.x
			accumulatedAngle = 0.0
			
			theHold.Begin()
			
			local sRay = mapScreenToWorldRay startMousePos
			startHitPos = intersectRayPlane sRay viewNorm selCenter
			
			BlenderGrab_StateV15.isActive = true
			BlenderGrab_StateV15.mainAction = #grab
			BlenderGrab_StateV15.mode = #free
			BlenderGrab_StateV15.space = #global
			BlenderGrab_StateV15.pos = selCenter
			BlenderGrab_StateV15.rotTM = matrix3 1
			BlenderGrab_StateV15.updateCb = executeTransform
			
			-- Запускаємо прихований таймер (без вікна) для фонових розрахунків
			createDialog BlenderGrab_HiddenRollout pos:[-1000,-1000] width:10 height:10 style:#()
			BlenderGrab_HiddenRollout.clock.active = true
			
			unregisterRedrawViewsCallback BlenderGrab_DrawAxes
			registerRedrawViewsCallback BlenderGrab_DrawAxes
			
			isMoving = true
			updatePromptText()
		)

		on freeMove do ( executeTransform() )

		on mousePoint clickNum do (
			if clickNum == 1 then (
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
			BlenderGrab_StateV15.isActive = false
			BlenderGrab_StateV15.updateCb = undefined
			
			-- Зупиняємо та видаляємо фоновий таймер
			BlenderGrab_HiddenRollout.clock.active = false
			try(destroyDialog BlenderGrab_HiddenRollout)catch()
			
			unregisterRedrawViewsCallback BlenderGrab_DrawAxes
			popPrompt()
			gw.updatescreen()
		)
	)

	startTool BlenderGrab_MouseTool
)