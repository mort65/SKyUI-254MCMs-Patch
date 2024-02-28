scriptname SKI_ConfigManager extends SKI_QuestBase hidden 

; SCRIPT VERSION ----------------------------------------------------------------------------------
;
; History
;
; 1:	- Initial version
;
; 2:	- Added lock for API functions
;
; 3:	- Removed lock again until I have time to test it properly
;
; 4:	- Added redundancy for registration process
; 
; 4.Barzing:  - Barzing version w/ 128 mods limit override and pagination

int function GetVersion()
	return 4
endFunction


; CONSTANTS ---------------------------------------------------------------------------------------

string property		JOURNAL_MENU	= "Journal Menu" autoReadonly
string property		MENU_ROOT		= "_root.ConfigPanelFader.configPanel" autoReadonly


; PRIVATE VARIABLES -------------------------------------------------------------------------------

; -- Version 1 --

SKI_ConfigBase[]	_modConfigs ; deprecated with Barzing version 
string[]			_modNames ; deprecated with Barzing version 
int					_curConfigID	= 0
int					_configCount	= 0

SKI_ConfigBase		_activeConfig

; -- Version 2 --

; keep those for now
bool				_lockInit		= false
bool				_locked			= false

; -- Version 4 --

bool				_cleanupFlag	= false
int					_addCounter		= 0
int					_updateCounter	= 0

; -- Barzing version --

SKI_ConfigBase[]	_modConfigsP1
string[]			_modNamesP1
SKI_ConfigBase[]	_modConfigsP2
string[]			_modNamesP2
int 				_page = 1


; INITIALIZATION ----------------------------------------------------------------------------------

event OnInit()


	; Barzing 2 pages = 254 possible mods
	_modConfigsP1	= new SKI_ConfigBase[128]
	_modNamesP1	= new string[128]
	_modConfigsP2	= new SKI_ConfigBase[128]
	_modNamesP2	= new string[128]
	
	; Barzing Pagination init
	_page = 1
	
	OnGameReload()
endEvent

; @implements SKI_QuestBase
event OnGameReload()
	RegisterForModEvent("SKICP_modSelected", "OnModSelect")
	RegisterForModEvent("SKICP_pageSelected", "OnPageSelect")
	RegisterForModEvent("SKICP_optionHighlighted", "OnOptionHighlight")
	RegisterForModEvent("SKICP_optionSelected", "OnOptionSelect")
	RegisterForModEvent("SKICP_optionDefaulted", "OnOptionDefault")
	RegisterForModEvent("SKICP_keymapChanged", "OnKeymapChange")
	RegisterForModEvent("SKICP_sliderSelected", "OnSliderSelect")
	RegisterForModEvent("SKICP_sliderAccepted", "OnSliderAccept")
	RegisterForModEvent("SKICP_menuSelected", "OnMenuSelect")
	RegisterForModEvent("SKICP_menuAccepted", "OnMenuAccept")
	RegisterForModEvent("SKICP_colorSelected", "OnColorSelect")
	RegisterForModEvent("SKICP_colorAccepted", "OnColorAccept")
	RegisterForModEvent("SKICP_inputSelected", "OnInputSelect")
	RegisterForModEvent("SKICP_inputAccepted", "OnInputAccept")
	RegisterForModEvent("SKICP_dialogCanceled", "OnDialogCancel")

	RegisterForMenu(JOURNAL_MENU)

	; no longer used but better safe than sorry
	_lockInit = true

	_cleanupFlag = true

	CleanUp()
	SendModEvent("SKICP_configManagerReady")

	_updateCounter = 0
	RegisterForSingleUpdate(5)
endEvent


; EVENTS ------------------------------------------------------------------------------------------

event OnUpdate()

	if (_cleanupFlag)
		CleanUp()
	endIf

	if (_addCounter > 0)
		Debug.Notification("MCM: Registered " + _addCounter + " new menu(s).")
		_addCounter = 0
	endIf

	SendModEvent("SKICP_configManagerReady")

	if (_updateCounter < 6)
		_updateCounter += 1
		RegisterForSingleUpdate(5)
	else
		RegisterForSingleUpdate(30)
	endIf
endEvent

event OnMenuOpen(string a_menuName)
	GotoState("BUSY")
	_activeConfig = none
	if (_page == 1)
		Log("Menu Open on Page 1")
		UI.InvokeStringA(JOURNAL_MENU, MENU_ROOT + ".setModNames", _modNamesP1);
	endIf
	if (_page == 2)
		Log("Menu Open on Page 2")
		UI.InvokeStringA(JOURNAL_MENU, MENU_ROOT + ".setModNames", _modNamesP2);
	endIf
endEvent


event OnMenuClose(string a_menuName)
	GotoState("")
	if (_activeConfig)
		_activeConfig.CloseConfig()
	endIf

	_activeConfig = none
endEvent

event OnModSelect(string a_eventName, string a_strArg, float a_numArg, Form a_sender)
	int configIndex = a_numArg as int
	GotoState("BUSY")
	if (configIndex > -1)

		; We can clean the buffers of the previous menu now
		if (_activeConfig)
			_activeConfig.CloseConfig()
		endIf
		
		if (_page == 1 && _modNamesP1[configIndex] == "-- Next Page")
			_page = 2
			Log("Go to Page 2")
			UI.InvokeStringA(JOURNAL_MENU, MENU_ROOT + ".setModNames", _modNamesP2);
			UI.Invoke("Journal Menu", MENU_ROOT + ".contentHolder.modListPanel.showList")
			_activeConfig = none
		elseif (_page == 2 && _modNamesP2[configIndex] == "-- Back Page")
			_page = 1
			Log("Go to Page 1")
			UI.InvokeStringA(JOURNAL_MENU, MENU_ROOT + ".setModNames", _modNamesP1);
			UI.Invoke("Journal Menu", MENU_ROOT + ".contentHolder.modListPanel.showList")
			_activeConfig = none
		else
			if (_page == 1)
				Log("Selected Mod is :" + _modNamesP1[configIndex] + " index " + configIndex)
				_activeConfig = _modConfigsP1[configIndex]
				_activeConfig.OpenConfig()
			elseif (_page == 2)
				Log("Selected Mod is :" + _modNamesP2[configIndex] + " index " + configIndex)
				_activeConfig = _modConfigsP2[configIndex]
				_activeConfig.OpenConfig()
			else
			endif
		endif
	endIf
	GotoState("")
	UI.InvokeBool(JOURNAL_MENU, MENU_ROOT + ".unlock", true)
endEvent

event OnPageSelect(string a_eventName, string a_strArg, float a_numArg, Form a_sender)
	string page = a_strArg
	int index = a_numArg as int
	_activeConfig.SetPage(page, index)
	UI.InvokeBool(JOURNAL_MENU, MENU_ROOT + ".unlock", true)
endEvent

event OnOptionHighlight(string a_eventName, string a_strArg, float a_numArg, Form a_sender)
	int optionIndex = a_numArg as int
	_activeConfig.HighlightOption(optionIndex)
endEvent

event OnOptionSelect(string a_eventName, string a_strArg, float a_numArg, Form a_sender)
	int optionIndex = a_numArg as int
	_activeConfig.SelectOption(optionIndex)
	UI.InvokeBool(JOURNAL_MENU, MENU_ROOT + ".unlock", true)
endEvent

event OnOptionDefault(string a_eventName, string a_strArg, float a_numArg, Form a_sender)
	int optionIndex = a_numArg as int
	_activeConfig.ResetOption(optionIndex)
	UI.InvokeBool(JOURNAL_MENU, MENU_ROOT + ".unlock", true)
endEvent

event OnKeymapChange(string a_eventName, string a_strArg, float a_numArg, Form a_sender)
	int optionIndex = a_numArg as int
	int keyCode = UI.GetInt(JOURNAL_MENU, MENU_ROOT + ".selectedKeyCode")

	; First test vanilla controls
	string conflictControl = Input.GetMappedControl(keyCode)
	string conflictName = ""

	; Then test mod controls
	int i = 0
	while (conflictControl == "" && i < _modConfigsP1.length)
		if (_modConfigsP1[i] != none)
			conflictControl = _modConfigsP1[i].GetCustomControl(keyCode)
			if (conflictControl != "")
				conflictName = _modNamesP1[i]
			endIf
		endIf
			
		i += 1
	endWhile
	
	if ( conflictControl != "" )
	i=0
	while (conflictControl == "" && i < _modConfigsP2.length)
		if (_modConfigsP2[i] != none)
			conflictControl = _modConfigsP2[i].GetCustomControl(keyCode)
			if (conflictControl != "")
				conflictName = _modNamesP2[i]
			endIf
		endIf
		i += 1
	endWhile
	endIf
	
	_activeConfig.RemapKey(optionIndex, keyCode, conflictControl, conflictName)
	UI.InvokeBool(JOURNAL_MENU, MENU_ROOT + ".unlock", true)
endEvent

event OnSliderSelect(string a_eventName, string a_strArg, float a_numArg, Form a_sender)
	int optionIndex = a_numArg as int
	_activeConfig.RequestSliderDialogData(optionIndex)
endEvent

event OnSliderAccept(string a_eventName, string a_strArg, float a_numArg, Form a_sender)
	float value = a_numArg
	_activeConfig.SetSliderValue(value)
	UI.InvokeBool(JOURNAL_MENU, MENU_ROOT + ".unlock", true)
endEvent

event OnMenuSelect(string a_eventName, string a_strArg, float a_numArg, Form a_sender)
	int optionIndex = a_numArg as int
	_activeConfig.RequestMenuDialogData(optionIndex)
endEvent

event OnMenuAccept(string a_eventName, string a_strArg, float a_numArg, Form a_sender)
	int value = a_numArg as int
	_activeConfig.SetMenuIndex(value)
	UI.InvokeBool(JOURNAL_MENU, MENU_ROOT + ".unlock", true)
endEvent

event OnInputSelect(String a_eventName, String a_strArg, Float a_numArg, Form a_sender)
	Int optionIndex = a_numArg as Int
	_activeConfig.RequestInputDialogData(optionIndex)
endEvent

event OnColorSelect(string a_eventName, string a_strArg, float a_numArg, Form a_sender)
	int optionIndex = a_numArg as int
	_activeConfig.RequestColorDialogData(optionIndex)
endEvent

event OnColorAccept(string a_eventName, string a_strArg, float a_numArg, Form a_sender)
	int color = a_numArg as int
	_activeConfig.SetColorValue(color)
	UI.InvokeBool(JOURNAL_MENU, MENU_ROOT + ".unlock", true)
endEvent

event OnInputAccept(String a_eventName, String a_strArg, Float a_numArg, Form a_sender)
	_activeConfig.SetInputText(a_strArg)
	ui.InvokeBool(JOURNAL_MENU, MENU_ROOT + ".unlock", true)
endEvent

event OnDialogCancel(string a_eventName, string a_strArg, float a_numArg, Form a_sender)
	UI.InvokeBool(JOURNAL_MENU, MENU_ROOT + ".unlock", true)
endEvent


; FUNCTIONS ---------------------------------------------------------------------------------------

; @interface
int function RegisterMod(SKI_ConfigBase a_menu, string a_modName)
	int P2curindex = 0
	GotoState("BUSY")
	Log("Registering config menu : " + a_menu + "(" + a_modName + ")")
	
	if (_configCount > 256)
		GotoState("")
		return -1
	endIf

	; Already registered?
	int i = 0
	while (i < _modConfigsP1.length)
		if (_modConfigsP1[i] == a_menu)
			GotoState("")
			return i
		endIf
		i += 1
	endWhile
	
	i = 0
	while (i < _modConfigsP2.length)
		if (_modConfigsP2[i] == a_menu)
			GotoState("")
			return i + 128
		endIf
		i += 1
	endWhile
	
	; New registration
	int configID = NextID(a_modName)

	if (configID == -1)
		GotoState("")
		return -1
	endIf
	
	if (configID > 254)
		GotoState("")
		return -1
	endIf
	
	if (configID > 127)
		P2curindex = configID - 128
		_modConfigsP2[P2curindex] = a_menu
		_modNamesP2[P2curindex] = a_modName
		Log("Registered config menu P2,line " + P2curindex + " : " + _modConfigsP2[P2curindex] + "(" + _modNamesP2[P2curindex]+ ")")
	elseif (configID <= 127)
		_modConfigsP1[configID] = a_menu
		_modNamesP1[configID] = a_modName
		Log("Registered config menu P1,line " + ConfigID + " : " + _modConfigsP1[configID] + "(" + _modNamesP1[configID] + ")")
	else
		GotoState("")
		return -1
	endIf
	
		_configCount += 1
	Log("Registered on Position " + ConfigID)

	; Track mods added in the current cycle so we don't have to display one message per mod
	_addCounter += 1

	GotoState("")
	
	return configID
endFunction

; @interface
int function UnregisterMod(SKI_ConfigBase a_menu)
	GotoState("BUSY")
	;Log("Unregistering config menu: " + a_menu)

	int i = 0
	while (i < _modConfigsP1.length)
		if (_modConfigsP1[i] == a_menu)
			_modConfigsP1[i] = none
			_modNamesP1[i] = ""
			_configCount -= 1

			GotoState("")
			return i
		endIf
			
		i += 1
	endWhile
	
	i = 0
	while (i < _modConfigsP2.length)
		if (_modConfigsP2[i] == a_menu)
			_modConfigsP2[i] = none
			_modNamesP2[i] = ""
			_configCount -= 1

			GotoState("")
			return i + 128
		endIf
			
		i += 1
	endWhile

	GotoState("")
	return -1
endFunction

; @interface
function ForceReset()
	Log("Forcing config manager reset...")
	SendModEvent("SKICP_configManagerReset")

	GotoState("BUSY")

	int i = 0
	while (i < _modConfigsP1.length)
		_modConfigsP1[i] = none
		_modNamesP1[i] = ""
		i += 1
	endWhile
	
	i = 0
	while (i < _modConfigsP2.length)
		_modConfigsP2[i] = none
		_modNamesP2[i] = ""
		i += 1
	endWhile

	_curConfigID = 0
	_configCount = 0
	
	; Barzing Pagination init
	_page = 1
	
	GotoState("")

	SendModEvent("SKICP_configManagerReady")
endFunction

function CleanUp()
	GotoState("BUSY")

	_cleanupFlag = false

	_configCount = 0
	int i = 0
	while (i < _modConfigsP1.length)
		if (_modConfigsP1[i] == none || _modConfigsP1[i].GetFormID() == 0)
			if (i < 127)
			_modConfigsP1[i] = none
			_modNamesP1[i] = ""
			endIf
		else
			_configCount += 1
		endIf

		i += 1
	endWhile
	
	i = 0
	while (i < _modConfigsP2.length)
		if (_modConfigsP2[i] == none || _modConfigsP2[i].GetFormID() == 0)
			if (i > 0)
			_modConfigsP2[i] = none
			_modNamesP2[i] = ""
			endIf
		else
			_configCount += 1
		endIf

		i += 1
	endWhile
	
	; Barzing Pagination init
	_page = 1
	
	GotoState("")
endFunction

int function NextID(String nModname)
	int startIdx = _curConfigID
	int P2curindex = 0
	
	Log("Passed NextID Modname : " + nModname)
	
	if (nModname == "-- Back Page")
		return 128
	Endif
	
	if (_curConfigID > 127)
		while (_curConfigID <= 254)
			P2curindex = _curConfigID - 128
			if (_modConfigsP2[P2curindex] == none)
				return _curConfigID
			else
				_curConfigID += 1
			endif
		endWhile
	endif
	
	if (_curConfigID <= 127)
		if (_modConfigsP1[_curConfigID] != none)
			while (_curConfigID <= 127)
				if (_modConfigsP1[_curConfigID] == none)
					return _curConfigID
				else
					_curConfigID += 1
				endIf
			endWhile
		else
			return _curConfigID
		endif
	endif
	
	if (_curConfigID == startIdx)
		return -1 ; Just to be sure. 
	endIf
	
	if (_curConfigID == 254)
		return -1
	endIf
	
endFunction

function Log(string a_msg)
	Debug.Trace(self + ": " + a_msg)
endFunction


; STATES ---------------------------------------------------------------------------------------

state BUSY
	int function RegisterMod(SKI_ConfigBase a_menu, string a_modName)
		return -2
	endFunction

	int function UnregisterMod(SKI_ConfigBase a_menu)
		return -2
	endFunction

	function ForceReset()
	endFunction

	function CleanUp()
	endFunction
endState
