-- ============================================================================
-- Blender-style Transformation Tools (Macros Only - CLEANED)
-- ============================================================================
-- Place this file in: usermacros

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
			local activeNodes = selection as array
			local movingVerts = ::BlenderGrab_GetMovingVertsV25 activeNodes
			
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
			::BlenderGrab_CustomBasePointV25 = closestVert
			::BlenderGrab_StartupActionV25 = #grab
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
	on isChecked return ::BlenderGrab_FullModeActive
	on execute do (
		::BlenderGrab_FullModeActive = not ::BlenderGrab_FullModeActive
		if ::BlenderGrab_FullModeActive then (
			if ::BlenderGrab_KeyReaderV25 != undefined do (
				::BlenderGrab_KeyReaderV25.InstallHook()
				::BlenderGrab_KeyReaderV25.isHookActive = true
			)
			pushPrompt "Full Blender Mode: ON (G, R, S are intelligently intercepted)"
		) else (
			if ::BlenderGrab_KeyReaderV25 != undefined do (
				::BlenderGrab_KeyReaderV25.isHookActive = false
				::BlenderGrab_KeyReaderV25.RemoveHook()
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
	rollout BlenderGrab_TutorialRollout "Blender Workflow - Quick Guide" width:390 height:445 (
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

	local iniPath = (GetDir #plugcfg) + "\\BlenderGrabTool.ini"
	local showTutorial = (getINISetting iniPath "Settings" "ShowTutorial")
	if showTutorial != "false" do (
		try(destroyDialog BlenderGrab_TutorialRollout)catch()
		createDialog BlenderGrab_TutorialRollout modal:true
	)

	tool BlenderGrab_MouseTool (
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
		local lastOrigTestPt = undefined
		local lastDeltaOffset = [0,0,0]
		
		local movingVertsOrig = #()
		local bboxMin = [0,0,0]
		local bboxMax = [0,0,0]
		
		fn updatePromptText = (
			local actionStr = case ::BlenderGrab_StateV25.mainAction of (
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
		
		fn executeTransform = (
			if not isMoving do return()
			enableAccelerators = false
			
			gw.setTransform (matrix3 1)
			local centerScreen2D = gw.transPoint selCenter
			local centerScreen = [centerScreen2D.x, centerScreen2D.y]
				
			local isPressedX = ::BlenderGrab_KeyReaderV25.IsPressed VK_X
			local isPressedY = ::BlenderGrab_KeyReaderV25.IsPressed VK_Y
			local isPressedZ = ::BlenderGrab_KeyReaderV25.IsPressed VK_Z
			local isPressedG = ::BlenderGrab_KeyReaderV25.IsPressed VK_G
			local isPressedR = ::BlenderGrab_KeyReaderV25.IsPressed VK_R
			local isPressedS = ::BlenderGrab_KeyReaderV25.IsPressed VK_S
			local isPressedCtrl = ::BlenderGrab_KeyReaderV25.IsPressed VK_CONTROL
			local isPressedEnter = ::BlenderGrab_KeyReaderV25.IsPressed VK_RETURN
			local shiftPressed = ::BlenderGrab_KeyReaderV25.IsPressed VK_SHIFT or keyboard.shiftPressed
			
			local justPressedX = isPressedX and not wasPressedX
			local justPressedY = isPressedY and not wasPressedY
			local justPressedZ = isPressedZ and not wasPressedZ
			local justPressedG = isPressedG and not wasPressedG
			local justPressedR = isPressedR and not wasPressedR
			local justPressedS = isPressedS and not wasPressedS
			local justPressedCtrl = isPressedCtrl and not wasPressedCtrl
			local justPressedEnter = isPressedEnter and not wasPressedEnter
			
			local justPressedNum = ""
			for k = 0x30 to 0x39 do (
				local isP = ::BlenderGrab_KeyReaderV25.IsPressed k
				if isP and not wasPressedKeys[k] do justPressedNum = (k - 0x30) as string
				wasPressedKeys[k] = isP
			)
			for k = 0x60 to 0x69 do (
				local isP = ::BlenderGrab_KeyReaderV25.IsPressed k
				if isP and not wasPressedKeys[k] do justPressedNum = (k - 0x60) as string
				wasPressedKeys[k] = isP
			)
			local isMinus1 = ::BlenderGrab_KeyReaderV25.IsPressed 0xBD; local isMinus2 = ::BlenderGrab_KeyReaderV25.IsPressed 0x6D
			if (isMinus1 and not wasPressedKeys[0xBD]) or (isMinus2 and not wasPressedKeys[0x6D]) do justPressedNum = "-"
			wasPressedKeys[0xBD] = isMinus1; wasPressedKeys[0x6D] = isMinus2
			
			local isDot1 = ::BlenderGrab_KeyReaderV25.IsPressed 0xBE; local isDot2 = ::BlenderGrab_KeyReaderV25.IsPressed 0x6E
			if (isDot1 and not wasPressedKeys[0xBE]) or (isDot2 and not wasPressedKeys[0x6E]) do justPressedNum = "."
			wasPressedKeys[0xBE] = isDot1; wasPressedKeys[0x6E] = isDot2
			
			local isBS = ::BlenderGrab_KeyReaderV25.IsPressed 0x08
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
			
			if justPressedEnter do ::BlenderGrab_KeyReaderV25.SimulateLeftClick()
			if justPressedCtrl do snapMode.active = not snapMode.active
			
			if justPressedG or justPressedR or justPressedS do (
				if theHold.Holding() do theHold.Cancel()
				if not theHold.Holding() do theHold.Begin()
				
				if justPressedG do ::BlenderGrab_StateV25.mainAction = #grab
				if justPressedR do ::BlenderGrab_StateV25.mainAction = #rotate
				if justPressedS do ::BlenderGrab_StateV25.mainAction = #scale
				
				currentMode = #free
				currentSpace = #global
				numericInputString = ""
				
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
			
			fn cycleMode targetMode = (
				if theHold.Holding() do theHold.Cancel()
				if not theHold.Holding() do theHold.Begin()
				
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
					::BlenderGrab_KeyReaderV25.SetPos (newScreenPos.x as integer) (newScreenPos.y as integer)
					virtualMouseOffset += [-wrapX, -wrapY]
					mPos = mPos + [wrapX, wrapY]
				)
			)

			local virtualMousePos = mPos + virtualMouseOffset
			local action = ::BlenderGrab_StateV25.mainAction
			local workTM = if currentSpace == #local then refRotTM else (matrix3 1)
			
			if action == #grab then (
				local finalOffset = [0,0,0]
				
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
						if snapMode.hit != undefined and snapMode.hit then (
							local rawHit = snapMode.worldHitpoint
							local origTestPt = rawHit - lastAppliedOffset
							local isSelfSnap = false
							
							if movingVertsOrig.count > 0 do (
								local threshold = 0.5 
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
							
							-- Edge/Face Feedback Loop Protection (швидкісний захист від само-прив'язки)
							if not isSelfSnap and lastOrigTestPt != undefined then (
								if distance origTestPt lastOrigTestPt < 0.1 and length lastDeltaOffset > 0.001 do (
									isSelfSnap = true
								)
							)
							
							if length lastDeltaOffset > 0.001 do (
								lastOrigTestPt = origTestPt
							)
							
							if not isSelfSnap then (
								snapPt = rawHit
								lastValidSnapPt = rawHit
							) else (
								if lastValidSnapPt != undefined and distance rawHit lastValidSnapPt < 0.1 then (
									snapPt = lastValidSnapPt
								) else (
									snapPt = undefined
								)
							)
						) else (
							lastValidSnapPt = undefined
							lastOrigTestPt = undefined
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
						local startH = ::BlenderGrab_IntersectRayV25 sRay workPlaneNorm selCenter
						local currentH = ::BlenderGrab_IntersectRayV25 mRay workPlaneNorm selCenter
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
				lastDeltaOffset = deltaOffset
				
				if length(deltaOffset) > 0.0001 or justPressedX or justPressedY or justPressedZ or justPressedCtrl or justPressedNum != "" do (
					::BlenderGrab_ApplyActionV25 #grab deltaOffset workTM selCenter currentSpace
					lastAppliedOffset = finalOffset
					::BlenderGrab_StateV25.mode = currentMode; ::BlenderGrab_StateV25.space = currentSpace
					::BlenderGrab_StateV25.rotTM = workTM; ::BlenderGrab_StateV25.pos = selCenter + finalOffset
					gw.updatescreen()
				)
			)
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
					::BlenderGrab_ApplyActionV25 #rotate qDelta workTM selCenter currentSpace
					lastAppliedAngle = rawAngle
					::BlenderGrab_StateV25.mode = currentMode; ::BlenderGrab_StateV25.space = currentSpace
					::BlenderGrab_StateV25.rotTM = workTM; ::BlenderGrab_StateV25.pos = selCenter
					gw.updatescreen()
				)
			)
			else if action == #scale then (
				local localScale = [1,1,1]
				
				if numericInputString != "" then (
					local numVal = numericInputString as float
					if numVal == undefined do numVal = 0.0
					local rawRatio = numVal / 100.0
					
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
				
				fn safeDiv a b = if abs b < 1e-5 then 1.0 else a / b
				local deltaScale = [safeDiv localScale.x lastAppliedScale.x, safeDiv localScale.y lastAppliedScale.y, safeDiv localScale.z lastAppliedScale.z]
				
				if abs(deltaScale.x - 1.0) > 0.0001 or abs(deltaScale.y - 1.0) > 0.0001 or abs(deltaScale.z - 1.0) > 0.0001 or justPressedX or justPressedY or justPressedZ or justPressedNum != "" do (
					::BlenderGrab_ApplyActionV25 #scale deltaScale workTM selCenter currentSpace
					lastAppliedScale = localScale
					::BlenderGrab_StateV25.mode = currentMode; ::BlenderGrab_StateV25.space = currentSpace
					::BlenderGrab_StateV25.rotTM = workTM; ::BlenderGrab_StateV25.pos = selCenter
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
			
			if ::BlenderGrab_KeyReaderV25 != undefined do ::BlenderGrab_KeyReaderV25.isToolActive = true
			
			::BlenderGrab_ActiveNodesV25 = selection as array
			
			-- Захист: Ініціалізуємо прапорець дублювання, якщо він порожній
			if ::BlenderGrab_WasDuplicatedV25 == undefined do ::BlenderGrab_WasDuplicatedV25 = false
			
			if ::BlenderGrab_CustomBasePointV25 != undefined then (
				selCenter = ::BlenderGrab_CustomBasePointV25
				
				local pt2D = gw.transPoint selCenter
				local viewOffset = mouse.screenpos - mouse.pos
				local absPos = viewOffset + [pt2D.x, pt2D.y]
				::BlenderGrab_KeyReaderV25.SetPos (absPos.x as integer) (absPos.y as integer)
				
				-- Фікс початкового мікро-стрибка: прив'язуємо startMousePos до того, чим зараз реально стане mouse.pos після варпу
				startMousePos = [(absPos.x as integer) - viewOffset.x, (absPos.y as integer) - viewOffset.y]
			) else (
				selCenter = ::BlenderGrab_GetCenterV25 ::BlenderGrab_ActiveNodesV25
				startMousePos = mouse.pos
			)
			
			if ::BlenderGrab_ActiveNodesV25.count > 0 do refRotTM = ::BlenderGrab_ActiveNodesV25[1].transform.rotation as matrix3
			
			for k = 1 to 256 do wasPressedKeys[k] = ::BlenderGrab_KeyReaderV25.IsPressed k
			wasPressedX = wasPressedKeys[VK_X]; wasPressedY = wasPressedKeys[VK_Y]; wasPressedZ = wasPressedKeys[VK_Z]
			wasPressedG = wasPressedKeys[VK_G]; wasPressedR = wasPressedKeys[VK_R]; wasPressedS = wasPressedKeys[VK_S]
			wasPressedCtrl = wasPressedKeys[VK_CONTROL]; wasPressedEnter = wasPressedKeys[VK_RETURN]
			
			viewNorm = -(Inverse(getViewTM())).row3
			
			movingVertsOrig = ::BlenderGrab_GetMovingVertsV25 ::BlenderGrab_ActiveNodesV25
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
			
			if not theHold.Holding() do theHold.Begin()
			
			::BlenderGrab_OriginalStatesV25 = #()
			if subObjectLevel == undefined or subObjectLevel == 0 do (
				for obj in ::BlenderGrab_ActiveNodesV25 do (
					append ::BlenderGrab_OriginalStatesV25 #(obj, obj.isFrozen, obj.showFrozenInGray)
					obj.showFrozenInGray = false
					obj.isFrozen = true
				)
			)
			
			::BlenderGrab_StateV25.isActive = true
			::BlenderGrab_StateV25.mainAction = ::BlenderGrab_StartupActionV25
			::BlenderGrab_StartupActionV25 = #grab
			::BlenderGrab_StateV25.mode = #free
			::BlenderGrab_StateV25.space = #global
			::BlenderGrab_StateV25.pos = selCenter
			::BlenderGrab_StateV25.rotTM = matrix3 1
			::BlenderGrab_StateV25.updateCb = executeTransform
			
			::BlenderGrab_CustomBasePointV25 = undefined
			
			if ::BlenderGrab_HiddenRollout != undefined do ::BlenderGrab_HiddenRollout.clock.active = true
			
			unregisterRedrawViewsCallback ::BlenderGrab_DrawAxes
			registerRedrawViewsCallback ::BlenderGrab_DrawAxes
			
			isMoving = true
			updatePromptText()
			
			local pX = 0, pY = 0
			if ::BlenderGrab_CustomBasePointV25 != undefined then (
				local pt2D = gw.transPoint selCenter
				local viewOffset = mouse.screenpos - mouse.pos
				pX = (viewOffset.x + pt2D.x) as integer
				pY = (viewOffset.y + pt2D.y) as integer
			) else (
				pX = mouse.screenpos.x as integer
				pY = mouse.screenpos.y as integer
			)
			::BlenderGrab_KeyReaderV25.SetPos pX (pY + 1)
			::BlenderGrab_KeyReaderV25.SetPos pX pY
		)

		on freeMove do ( executeTransform() )

		on mousePoint clickNum do (
			if clickNum == 1 then (
				::BlenderGrab_RepeatStateV25.isValid = true
				::BlenderGrab_RepeatStateV25.actionType = ::BlenderGrab_StateV25.mainAction
				::BlenderGrab_RepeatStateV25.spaceMode = ::BlenderGrab_StateV25.space
				::BlenderGrab_RepeatStateV25.rotTM = ::BlenderGrab_StateV25.rotTM
				
				if ::BlenderGrab_StateV25.mainAction == #grab then ::BlenderGrab_RepeatStateV25.val = lastAppliedOffset
				else if ::BlenderGrab_StateV25.mainAction == #rotate then ::BlenderGrab_RepeatStateV25.val = (angleaxis lastAppliedAngle lastRotAxis)
				else if ::BlenderGrab_StateV25.mainAction == #scale then ::BlenderGrab_RepeatStateV25.val = lastAppliedScale
				
				-- Запам'ятовуємо для Shift+R, чи ця дія включала дублювання перед цим
				::BlenderGrab_RepeatIsDuplicateV25 = (::BlenderGrab_WasDuplicatedV25 == true)
				::BlenderGrab_WasDuplicatedV25 = false
				
				if theHold.Holding() do theHold.Accept "Blender Transform"
				#stop
			)
		)

		on mouseAbort arg do (
			enableAccelerators = true
			isMoving = false
			
			::BlenderGrab_WasDuplicatedV25 = false -- Скидаємо прапорець при відміні
			
			if ::BlenderGrab_KeyReaderV25 != undefined do ::BlenderGrab_KeyReaderV25.isToolActive = false
			if ::BlenderGrab_HiddenRollout != undefined do ::BlenderGrab_HiddenRollout.clock.active = false
			unregisterRedrawViewsCallback ::BlenderGrab_DrawAxes
			popPrompt()
			gw.updatescreen()
			
			if theHold.Holding() do theHold.Cancel()
			#stop
		)
		
		on stop do (
			isMoving = false
			enableAccelerators = true
			::BlenderGrab_StateV25.isActive = false
			::BlenderGrab_StateV25.updateCb = undefined
			
			::BlenderGrab_WasDuplicatedV25 = false -- Скидаємо прапорець при зупинці
			
			if ::BlenderGrab_KeyReaderV25 != undefined do ::BlenderGrab_KeyReaderV25.isToolActive = false
			
			if ::BlenderGrab_HiddenRollout != undefined do ::BlenderGrab_HiddenRollout.clock.active = false
			
			unregisterRedrawViewsCallback ::BlenderGrab_DrawAxes
			popPrompt()
			gw.updatescreen()
			
			if ::BlenderGrab_OriginalStatesV25.count > 0 do (
				for item in ::BlenderGrab_OriginalStatesV25 do (
					if isValidNode item[1] do (
						item[1].isFrozen = item[2]
						item[1].showFrozenInGray = item[3]
					)
				)
				::BlenderGrab_OriginalStatesV25 = #()
				if ::BlenderGrab_ActiveNodesV25.count > 0 do select ::BlenderGrab_ActiveNodesV25
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
				local curMod = obj.baseObject
				
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
			::BlenderGrab_WasDuplicatedV25 = true -- Фіксуємо, що рух викликаний після дублювання
			
			global BlenderGrab_LaunchRollout
			try(destroyDialog BlenderGrab_LaunchRollout)catch()
			rollout BlenderGrab_LaunchRollout "Launch" (
				timer launchTimer "launchTimer" interval:10 active:true
				on launchTimer tick do (
					launchTimer.active = false
					try(destroyDialog BlenderGrab_LaunchRollout)catch()
					
					::BlenderGrab_StartupActionV25 = #grab
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
		if not ::BlenderGrab_RepeatStateV25.isValid do (
			messageBox "No valid transformation saved yet. Use Grab/Rotate/Scale first." title:"Blender Repeat"
			return()
		)
		
		if not theHold.Holding() do theHold.Begin()
		
		-- Якщо остання дія включала дублювання, спочатку дублюємо об'єкти
		if ::BlenderGrab_RepeatIsDuplicateV25 == true do (
			if subObjectLevel == undefined or subObjectLevel == 0 then (
				local clonedObjs = #()
				maxOps.cloneNodes selection cloneType:#instance newNodes:&clonedObjs
				
				if clonedObjs.count > 0 do (
					clearSelection()
					select clonedObjs
				)
			) else (
				local cancelAll = false
				
				for obj in selection do (
					if cancelAll do continue
					local curMod = obj.baseObject
					
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
							)
						) else cancelAll = true
					) else cancelAll = true
				)
			)
		)
		
		-- Після дублювання (або якщо його не було), застосовуємо саму трансформацію
		::BlenderGrab_ActiveNodesV25 = selection as array
		if ::BlenderGrab_ActiveNodesV25.count > 0 do (
			local center = ::BlenderGrab_GetCenterV25 ::BlenderGrab_ActiveNodesV25
			::BlenderGrab_ApplyActionV25 ::BlenderGrab_RepeatStateV25.actionType ::BlenderGrab_RepeatStateV25.val ::BlenderGrab_RepeatStateV25.rotTM center ::BlenderGrab_RepeatStateV25.spaceMode
		)
		
		if theHold.Holding() do theHold.Accept "Blender Repeat Action"
		gw.updatescreen()
	)
)