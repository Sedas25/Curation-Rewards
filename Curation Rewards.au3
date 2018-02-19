#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=test.ico
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include <GUIConstantsEx.au3>
#include <ListViewConstants.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include "JSON.au3"
#include <array.au3>
#include <Date.au3>
#include <Timers.au3>
#include <Math.au3>
#include <File.au3>
#include <GuiListView.au3>
#include <Debug.au3>

Global Const $HTTP_STATUS_OK = 200
Global $g_hTimer, $g_iSecs, $g_iMins, $g_iHour, $g_sTime
Global $votedate = "", $differenz = ""
Global $RPC = "https://api.steemit.com"

While 1
	Global $account = InputBox("Account Name", "Please insert your Accountname" & @CRLF & "without @", "")
	Select
		Case @error = 0
		Case @error = 1
			Exit
	EndSelect
	If $account > "" Then ExitLoop
WEnd

$Form1 = GUICreate("Curation Rewards", 880, 766, 192, 124)
$ListView1 = GUICtrlCreateListView("Voter|Author|Perma|Curation|Payout|Vote Time|Payout in", 0, 32, 880, 726)
GUICtrlSendMsg(-1, $LVM_SETCOLUMNWIDTH, 0, 100)
GUICtrlSendMsg(-1, $LVM_SETCOLUMNWIDTH, 1, 100)
GUICtrlSendMsg(-1, $LVM_SETCOLUMNWIDTH, 2, 200)
GUICtrlSendMsg(-1, $LVM_SETCOLUMNWIDTH, 3, 100)
GUICtrlSendMsg(-1, $LVM_SETCOLUMNWIDTH, 4, 100)
GUICtrlSendMsg(-1, $LVM_SETCOLUMNWIDTH, 5, 100)
GUICtrlSendMsg(-1, $LVM_SETCOLUMNWIDTH, 6, 100)
$Label1 = GUICtrlCreateLabel("Expected Curation Rewards:", 0, 0, 570, 28)
GUICtrlSetFont(-1, 14, 800, 0, "MS Sans Serif")
GUISetState(@SW_SHOW)
GUIRegisterMsg($WM_NOTIFY, "WM_NOTIFY")

$t3 = _JSONDecode(_Steem_Get_Reward_Fund_Global())
$global = $t3[3][1]
Global $rewardBalance = StringTrimRight($global[3][1], 6)
Global $recentClaims = $global[4][1]
Global $FULL_CURATION_TIME = 30 * 60
Global $start = 0
Global $pos = 1
_DebugSetup("Test", True)
_DebugOut("-------------------------------------------------------------------------------------------------------------------")
_DebugOut("Load All Votes")
_Loadall($account)
_DebugOut("-------------------------------------------------------------------------------------------------------------------")
_loadlist()
_DebugOut("Ende")
While 1
	$nMsg = GUIGetMsg()
	Switch $nMsg
		Case $GUI_EVENT_CLOSE
			Exit

	EndSwitch
WEnd

Func _CalcVote($account, $weight)
	$t2 = _JSONDecode(_Steem_Get_Account($account))
	$t2 = $t2[2][1]
	$t2 = $t2[0]
	$vest = StringReplace($t2[41][1], " VEST", "")
	$dele_vest = StringReplace($t2[42][1], " VEST", "")
	$rec_vest = StringReplace($t2[43][1], " VEST", "")
	$vest_share = $vest + $rec_vest - $dele_vest
	$effective_vesting_shares = $vest_share * 1000000
	$current_power = _Steem_Actually_Vote_Power($account)

EndFunc   ;==>_CalcVote


Func _Steem_Actually_Vote_Power($name)
	$power_per_Hour = 83
	$new = 0
	While 1
		$au = _Steem_Get_Account($name)
		$t2 = _JSONDecode($au)
		If IsArray($t2) Then
			$t3 = $t2[2][1]
			If IsArray($t3) Then
				$account = $t3[0]
				If IsArray($account) Then
					$votepower = $account[24][1]
					$lastvote = $account[25][1]
					$aInfo = _Date_Time_GetTimeZoneInformation()
					$dif = (_DateDiff('s', StringReplace($lastvote, "T", " ", 1), _NowCalc()) + $aInfo[1] * 60) / 60
					$new = Round((($power_per_Hour / 60) * $dif) + $votepower, 0)
					ExitLoop
				EndIf
			EndIf
		EndIf
	WEnd
	Return $new
EndFunc   ;==>_Steem_Actually_Vote_Power

Func _Loadall($account)
	DirCreate("Curation")
	$t2 = _JSONDecode(_Steem_Get_Account_votes($account))
	$t2 = $t2[2][1]
	FileDelete("Curation\log.ini")
	For $x = 0 To UBound($t2) - 1
		_DebugOut($x&" / "&UBound($t2) - 1)
		$vo = $t2[$x]
		$create = StringReplace($vo[5][1], "T", " ")
		$aInfo = _Date_Time_GetTimeZoneInformation()
		$diffdate = _DateDiff("D", $create, _NowCalc())
		ConsoleWrite($diffdate & @CRLF)
		If $diffdate <= 7 Then
			If Not StringInStr($vo[1][1], $account) Then
				FileWrite("Curation\log.ini", $account & ";" & StringReplace($vo[1][1], "/", ";") & ";" & $create & @CRLF)
			EndIf
		EndIf
	Next
EndFunc   ;==>_Loadall

Func WM_NOTIFY($hWnd, $iMsg, $iwParam, $ilParam)
	Local $hWndFrom, $iIDFrom, $iCode, $tNMHDR, $hWndListView
	$hWndListView = $ListView1
	If Not IsHWnd($ListView1) Then $hWndListView = GUICtrlGetHandle($ListView1)
	$tNMHDR = DllStructCreate($tagNMHDR, $ilParam)
	$hWndFrom = HWnd(DllStructGetData($tNMHDR, "hWndFrom"))
	$iCode = DllStructGetData($tNMHDR, "Code")
	Switch $hWndFrom
		Case $hWndListView
			Switch $iCode
				Case $LVN_COLUMNCLICK
					Local $tInfo = DllStructCreate($tagNMLISTVIEW, $ilParam)
					Local $ColumnIndex = DllStructGetData($tInfo, "SubItem")
					_ListView_Sort($ColumnIndex)
				Case $NM_DBLCLK
					Local $tInfo = DllStructCreate($tagNMITEMACTIVATE, $ilParam)
					$Index = DllStructGetData($tInfo, "Index")
					$subitemNR = DllStructGetData($tInfo, "SubItem")
					If $Index <> -1 Then
						$item = StringSplit(_GUICtrlListView_GetItemTextString($ListView1, $Index), '|')
						ClipPut("https://steemit.com/@" & $item[2] & "/" & $item[3])
						ToolTip("The URL has been copied", Default, Default, "Bot Tracker", 1)
						AdlibRegister("undotip", 2000)
						ConsoleWrite($item & ' ' & @CRLF)
					EndIf
			EndSwitch
	EndSwitch
	Return $GUI_RUNDEFMSG
EndFunc   ;==>WM_NOTIFY

Func undotip()
	ToolTip("")
	AdlibUnRegister("undotip")
EndFunc   ;==>undotip

Func _loadlist()
	$spglobal = 0
	$del = ""
	Local $aArray = 0
	If Not _FileReadToArray("Curation\log.ini", $aArray, 1) Then
		MsgBox($MB_SYSTEMMODAL, "", "There was an error reading the file. @error: " & @error) ; An error occurred reading the current script file.
	EndIf
	For $x = 1 To $aArray[0]
		_DebugOut($x & " / " & $aArray[0])
		$split = StringSplit($aArray[$x], ";")
		$createdat = _Checkcreatedate($split[2], $split[3])
		ConsoleWrite($createdat & @CRLF)
		_TicksToTime(Int(_Diff(_NowCalc(), $createdat)), $g_iHour, $g_iMins, $g_iSecs)
		If Not $createdat = 0 Then
			If Int($g_iSecs) > 0 Then
				$sp = Round(_Steem_Get_Curation_rewards($split[1], $split[2], $split[3]), 8)
				$spglobal = $sp + $spglobal
				_TicksToTime(Int(_Diff(_NowCalc(), $createdat)), $g_iHour, $g_iMins, $g_iSecs)
				$g_sTime = StringFormat("%02i:%02i:%02i", $g_iHour, $g_iMins, $g_iSecs)
				GUICtrlCreateListViewItem($split[1] & "|" & $split[2] & "|" & $split[3] & "|" & $sp & " SP|" & $createdat & "|" & $split[4] & "|" & $g_sTime, $ListView1)
				GUICtrlSetData($Label1, "Expected Curation Rewards: " & $spglobal & " SP")
			EndIf
		EndIf
	Next
EndFunc   ;==>_loadlist

Func _Diff($date1, $date2)
	$diff = _DateDiff('s', $date1, $date2)
	Return $diff * 1000
EndFunc   ;==>_Diff

Func _Checkcreatedate($author, $perma)
	$created = 999999
	$loop = 0
	While 1
		If $loop <= 1 Then
			$loop = $loop + 1
			$result = _Steem_Get_Content($author, $perma)
			$t2 = _JSONDecode($result)
			If UBound($t2) = 4 Then
				$cont = $t2[3][1]
				$pre_30_min_pct = 0
				$beneficiary_pct = 0
				If UBound($cont[34][1]) > 0 Then
					$acon = $cont[34][1]
					For $x = 0 To UBound($cont[34][1]) - 1
						$acon2 = $acon[$x]
					Next

				EndIf
				$aInfo = _Date_Time_GetTimeZoneInformation()
				ConsoleWrite(StringReplace($cont[11][1], "T", " ") & @CRLF)
				$createdat = _DateAdd('D', 7, StringReplace($cont[11][1], "T", " "))
				$created = _DateDiff('D', StringReplace($cont[11][1], "T", " "), _DateAdd('n', $aInfo[1], _NowCalc()))
				ExitLoop
			EndIf
		Else
			ExitLoop
		EndIf
	WEnd
	If $created > 7 Then
		Return 0
	Else
		Return $createdat
	EndIf
EndFunc   ;==>_Checkcreatedate

Func _check_Conntent($author, $link)
	$content = _Steem_Get_Content($author, $link)
	$t2 = _JSONDecode($content)
	If IsArray($t2) Then
		$cont = $t2[2][1]
		If IsArray($cont) Then
			$create = StringReplace($cont[20][1], "T", " ")
			$aInfo = _Date_Time_GetTimeZoneInformation()
			$diffdate = _DateDiff("n", $create, _NowCalc()) + $aInfo[1]
			If $diffdate < 0 Then
				Return True
			EndIf
		EndIf
	EndIf
EndFunc   ;==>_check_Conntent

Func _Steem_Get_Curation_rewards($ownAccount, $author, $perma)
	_DebugOut("")
	_DebugOut("-------------------------------------------------------------------------------------------------------------------")
	_DebugOut("https://steemit.com/@" & $author & "/" & $perma)
	While 1
		$result = _Steem_Get_Content($author, $perma)
		$t2 = _JSONDecode($result)
		If UBound($t2) = 4 Then
			$cont = $t2[3][1]
			$pre_30_min_pct = 0
			$beneficiary_pct = 0
			If UBound($cont[34][1]) > 0 Then
				$acon = $cont[34][1]
				For $x = 0 To UBound($cont[34][1]) - 1
					$acon2 = $acon[$x]
				Next
			EndIf
			$created = _DateDiff('s', "1970/01/01 00:00:00", StringReplace($cont[11][1], "T", " "))
			$beneficiary_pct = (1 - $beneficiary_pct / 1000)
			ExitLoop
		EndIf
	WEnd
	$t2 = _JSONDecode(_Steem_Get_Active_Votes($author, $perma))
	$resvote = $t2[2][1]
	$votetime = ""
	Dim $yourAr
	For $x = 0 To UBound($resvote) - 1
		$sel = $resvote[$x]
		If $sel[1][1] = $ownAccount Then $votetime = _DateDiff('s', "1970/01/01 00:00:00", StringReplace($sel[6][1], "T", " "))
		If IsArray($yourAr) = 1 Then
			$Bound = UBound($yourAr)
			ReDim $yourAr[$Bound + 1][3]
			$yourAr[$Bound][0] = _DateDiff('s', "1970/01/01 00:00:00", StringReplace($sel[6][1], "T", " "))
			$yourAr[$Bound][1] = $sel[1][1]
			$yourAr[$Bound][2] = $sel[3][1]
		Else
			Dim $yourAr[1][3]
			$yourAr[0][0] = _DateDiff('s', "1970/01/01 00:00:00", StringReplace($sel[6][1], "T", " "))
			$yourAr[0][1] = $sel[1][1]
			$yourAr[0][2] = $sel[3][1]
		EndIf
	Next
	$befor = 0
	$self = 0
	$total = 0
	$befor2 = 0
	_ArraySort($yourAr, 0, 0, 0, 0)
	$pre_30_min_pct = ((100 / 30) * (($votetime - $created) / 60)) / 100
	If $pre_30_min_pct > 1 Then $pre_30_min_pct = 1
	For $y = 0 To UBound($yourAr) - 1
		If $yourAr[$y][1] = $ownAccount Then
			$self = $yourAr[$y][2]
			$total = $total + $yourAr[$y][2]
			$befor2 = 1
		Else
			If $befor2 = 0 Then
				$befor = $befor + $yourAr[$y][2]
				$total = $total + $yourAr[$y][2]
			Else
				$total = $total + $yourAr[$y][2]
			EndIf
		EndIf
	Next
	$beneficiary_pct = 1
	$curation_rshares = (Sqrt($befor * 0.25 + $self * 0.25) - Sqrt($befor * 0.25)) * Sqrt($total * 0.25) * $pre_30_min_pct * $beneficiary_pct
	_DebugOut($befor & " @ " & 0.25 & " @ " & $self & " @ " & $total & " @ " & $pre_30_min_pct & " @ " & $beneficiary_pct & " @ " & $curation_rshares)
	_DebugOut(Round($curation_rshares * $rewardBalance / $recentClaims, 9))
	_DebugOut("-------------------------------------------------------------------------------------------------------------------")
	If StringInStr($curation_rshares * $rewardBalance / $recentClaims, "-") Then
		Return 0
	Else
		Return $curation_rshares * $rewardBalance / $recentClaims
	EndIf
EndFunc   ;==>_Steem_Get_Curation_rewards

;===============================================================================
;
; Function Name:    _ListView_Sort()
; Description:      Sorting ListView items when column click
; Parameter(s):     $cIndex - Column index
; Return Value(s):  None
; Requirement(s):   AutoIt 3.2.12.0 and above
; Author(s):        R.Gilman (a.k.a rasim)
;
;================================================================================
Func _ListView_Sort($cIndex = 0)
	Local $iColumnsCount, $iDimension, $iItemsCount, $aItemsTemp, $aItemsText, $iCurPos, $iImgSummand, $i, $j

	$iColumnsCount = _GUICtrlListView_GetColumnCount($ListView1)

	$iDimension = $iColumnsCount * 2

	$iItemsCount = _GUICtrlListView_GetItemCount($ListView1)

	Local $aItemsTemp[1][$iDimension]

	For $i = 0 To $iItemsCount - 1
		$aItemsTemp[0][0] += 1
		ReDim $aItemsTemp[$aItemsTemp[0][0] + 1][$iDimension]

		$aItemsText = _GUICtrlListView_GetItemTextArray($ListView1, $i)
		$iImgSummand = $aItemsText[0] - 1

		For $j = 1 To $aItemsText[0]
			$aItemsTemp[$aItemsTemp[0][0]][$j - 1] = $aItemsText[$j]
			$aItemsTemp[$aItemsTemp[0][0]][$j + $iImgSummand] = _GUICtrlListView_GetItemImage($ListView1, $i, $j - 1)
		Next
	Next

	$iCurPos = $aItemsTemp[1][$cIndex]
	_ArraySort($aItemsTemp, 0, 1, 0, $cIndex)
	If StringInStr($iCurPos, $aItemsTemp[1][$cIndex]) Then _ArraySort($aItemsTemp, 1, 1, 0, $cIndex)

	For $i = 1 To $aItemsTemp[0][0]
		For $j = 1 To $iColumnsCount
			_GUICtrlListView_SetItemText($ListView1, $i - 1, $aItemsTemp[$i][$j - 1], $j - 1)
			_GUICtrlListView_SetItemImage($ListView1, $i - 1, $aItemsTemp[$i][$j + $iImgSummand], $j - 1)
		Next
	Next
EndFunc   ;==>_ListView_Sort

Func _Steem_Get_Reward_Fund_Global()
	Local $Data1 = '{"jsonrpc": "2.0","id":7,"method":"get_reward_fund","params":["post"]}'
	Return HttpPost($Data1)
EndFunc   ;==>_Steem_Get_Reward_Fund_Global

Func _Steem_Get_Config()
	Local $Data1 = '{"jsonrpc": "2.0","id":7,"method":"get_config","params":[]}'
	Return HttpPost($Data1)
EndFunc   ;==>_Steem_Get_Config

Func _Steem_Get_State($path)
	Local $Data1 = '{"jsonrpc": "2.0","id":7,"method":"get_state","params":["' & $path & '"]}'
	Return HttpPost($Data1)
EndFunc   ;==>_Steem_Get_State

Func _Steem_Get_Dynamic_Global_Properties()
	Local $Data1 = '{"jsonrpc": "2.0", "method": "get_dynamic_global_properties", "params":[]}'
	Return HttpPost($Data1)
EndFunc   ;==>_Steem_Get_Dynamic_Global_Properties

Func _Steem_Get_Chain_Properties()
	Local $Data1 = '{"jsonrpc": "2.0", "method": "get_chain_properties","params":[]}'
	Return HttpPost($Data1)
EndFunc   ;==>_Steem_Get_Chain_Properties

Func _Steem_Get_Current_Median_History_Price()
	Local $Data1 = '{"jsonrpc": "2.0","id":7,"method":"get_current_median_history_price","params":[]}'
	Return HttpPost($Data1)
EndFunc   ;==>_Steem_Get_Current_Median_History_Price

Func _Steem_Get_Feed_History()
	Local $Data1 = '{"jsonrpc": "2.0","id":7,"method":"get_feed_history","params":[]}'
	Return HttpPost($Data1)
EndFunc   ;==>_Steem_Get_Feed_History

Func _Steem_Get_Witness_Schedule()
	Local $Data1 = '{"jsonrpc": "2.0","id":7,"method":"get_witness_schedule","params":[]}'
	Return HttpPost($Data1)
EndFunc   ;==>_Steem_Get_Witness_Schedule

Func _Steem_Get_Hardfork_Version()
	Local $Data1 = '{"jsonrpc": "2.0","id":7,"method":"get_hardfork_version","params":[]}'
	Return HttpPost($Data1)
EndFunc   ;==>_Steem_Get_Hardfork_Version

Func _Steem_Get_Next_Scheduled_Hardfork()
	Local $Data1 = '{"jsonrpc": "2.0","id":7,"method":"get_next_scheduled_hardfork","params":[]}'
	Return HttpPost($Data1)
EndFunc   ;==>_Steem_Get_Next_Scheduled_Hardfork

Func _Steem_Get_Account($name)
	Local $Data1 = '{ "jsonrpc": "2.0", "method": "get_accounts", "params": [["' & $name & '"]], "id": 99}'
	Return HttpPost($Data1)
EndFunc   ;==>_Steem_Get_Account

Func _Steem_Get_Account_votes($name)
	Local $Data1 = '{"jsonrpc": "2.0","id":7,"method":"get_account_votes","params":["' & $name & '"]}'
	Return HttpPost($Data1)
EndFunc   ;==>_Steem_Get_Account_votes

Func _Steem_Get_Account_Count()
	Local $Data1 = '{"jsonrpc": "2.0","id":7,"method":"get_account_count","params":[]}'
	Return HttpPost($Data1)
EndFunc   ;==>_Steem_Get_Account_Count

Func _Steem_Get_Owner_History($name)
	Local $Data1 = '{"jsonrpc": "2.0","id":23,"method":"get_owner_history","params":["' & $name & '"]}'
	Return HttpPost($Data1)
EndFunc   ;==>_Steem_Get_Owner_History

Func _Steem_Get_Block_Header($blockNum)
	Local $Data1 = '{"jsonrpc": "2.0","id":7,"method":"get_block_header","params":["' & $blockNum & '"]}'
	Return HttpPost($Data1)
EndFunc   ;==>_Steem_Get_Block_Header

Func _Steem_Get_Block($blocknumber)
	Local $Data1 = '{"jsonrpc": "2.0","id":23,"method":"get_block","params":["' & $blocknumber & '"]}'
	Return HttpPost($Data1)
EndFunc   ;==>_Steem_Get_Block

Func _Steem_Get_Vesting_Delegations($account, $from, $limit)
	Local $Data1 = '{"jsonrpc": "2.0","id":7,"method":"get_vesting_delegations","params":["' & $account & '","' & $from & '","' & $limit & '"]}'
	Return HttpPost($Data1)
EndFunc   ;==>_Steem_Get_Vesting_Delegations

Func _Steem_Get_Ops_In_Block($blockNum, $onlyVirtual)
	Local $Data1 = '{"jsonrpc": "2.0","id":7,"method":"get_ops_in_block","params":["' & $blockNum & '","' & $onlyVirtual & '"]}'
	Return HttpPost($Data1)
EndFunc   ;==>_Steem_Get_Ops_In_Block

Func _Steem_Get_Content_Replies($name, $permalink)
	Local $Data1 = '{"jsonrpc": "2.0","id":20,"method":"get_content_replies","params":["' & $name & '", "' & $permalink & '"]}'
	Return HttpPost($Data1)
EndFunc   ;==>_Steem_Get_Content_Replies

Func _Steem_Get_Active_Votes($name, $permalink)
	Local $Data1 = '{"jsonrpc": "2.0","id":12,"method":"get_active_votes","params":[ "' & $name & '", "' & $permalink & '"]}'
	Return HttpPost($Data1)
EndFunc   ;==>_Steem_Get_Active_Votes

Func _Steem_Get_Content($name, $permalink)
	Local $Data1 = '{"jsonrpc": "2.0","id":12,"method":"get_content","params":[ "' & $name & '", "' & $permalink & '"]}'
	Return HttpPost($Data1)
EndFunc   ;==>_Steem_Get_Content

Func HttpPost($sData = "")
	Local $oHTTP = ObjCreate("WinHttp.WinHttpRequest.5.1")
	$oHTTP.Open("POST", $RPC, False)
	If (@error) Then Return SetError(1, 0, 0)
	$oHTTP.SetRequestHeader("Content-Type", "application/json-rpc")
	$oHTTP.Send($sData)
	If (@error) Then Return SetError(2, 0, 0)
	If ($oHTTP.Status <> $HTTP_STATUS_OK) Then Return SetError(3, 0, 0)
	Return SetError(0, 0, $oHTTP.ResponseText)
EndFunc   ;==>HttpPost
