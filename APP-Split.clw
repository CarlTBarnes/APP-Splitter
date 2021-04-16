! APP Splitter by Carl Barnes - (c) 2018-2021 released under the MIT License
!---------------------------------------------------------------------------------------------
! 04/16/2021 First release on Github


!TODO Source subfolder or folder for those that choose to generate that way.
!TODO my Locator Class

  PROGRAM
  INCLUDE('KeyCodes.CLW')

!  INCLUDE('CBWndPreview.INC'),ONCE    !Download https://github.com/CarlTBarnes/WindowPreview
    COMPILE('!**WndPrv END**', _IFDef_CBWndPreview_)
WndPrvCls   CBWndPreviewClass
    !**WndPrv END**
  
CBSortClass1 CLASS,TYPE
QRef        &QUEUE
FEQ         LONG
ColumnNow   SHORT            
ColumnLast  SHORT            
QFieldNow   SHORT
QFieldLast  SHORT
Who1st      STRING(128)
Who2nd      STRING(129)
Init        PROCEDURE(QUEUE ListQueue, LONG ListFEQ, SHORT SortColumnNow=0)
SetSortCol  PROCEDURE(SHORT SortColNow)
HeaderPressed PROCEDURE(SHORT ForceSortByColumn=0) !Call in OF EVENT:HeaderPressed for LIST
    END
  
  MAP
ProcessAppClwFile  PROCEDURE() 
LoadLinkMapFile    PROCEDURE()
LittleTextWindow   PROCEDURE(STRING Txt,<STRING InCaption>) 
LoadTricksText     PROCEDURE()               
TextLoadFromFile   PROCEDURE(STRING FileName, *STRING OutText) 
PathBS             PROCEDURE(STRING PathRaw),STRING
DB                 PROCEDURE(STRING xMessage)
    MODULE('Win32')
OutputDebugString   PROCEDURE(*cstring Msg),PASCAL,RAW,NAME('OutputDebugStringA'),DLL(1)
LenFastClip         PROCEDURE(CONST *STRING Text2Measure),LONG,NAME('Cla$FASTCLIP')
    END
  END


AppPathBS           PSTRING(256)  
AppNameOnly         STRING(32)
TargetName          STRING(32)      !W/o Ext 
AppClwNameOfFile    STRING(260)
AppExpNameOfFile    STRING(260)
DebugRelease        STRING('Debug  ')   !Or Release

AppClwFile   FILE,DRIVER('ASCII'),PRE(AppClw),NAME(AppClwNameOfFile) 
    RECORD
Line       STRING(512)     !AppClw:Line
    END 
  END 

BigDosFile   FILE,DRIVER('DOS'),PRE(Big)
    RECORD
Block          STRING(8000)     !AppClw:Block
    END 
  END 
  
OmitImportedData    BYTE(1)     
MapLnkNameOfFile    STRING(260)
MapLnkFile   FILE,DRIVER('ASCII'),PRE(MapLnk),NAME(MapLnkNameOfFile) 
    RECORD
Line       STRING(512)     !MapLnk:Line
    END 
  END

!Region Queues == Queues == Queues == Queues == Queues == Queues ==
ImportQ QUEUE,PRE(ImpQ)
DllName     STRING(32)  !ImpQ:DllName
Level       LONG        !ImpQ:Level
ProcName    STRING(64)  !ImpQ:ProcName
DllUpr      STRING(32)  !ImpQ:DllUpr
ProcUpr     STRING(64)  !ImpQ:ProcUpr
        END 
Import2Q QUEUE(ImportQ),PRE(Imp2Q)
    END

MapSizeQ QUEUE,PRE(MapzQ)  !Store the MAP lines use to calc Procedure Size
LineNo      USHORT      !MapzQ:LineNo
ProcName    STRING(256) !MapzQ:ProcName
Addr1       STRING(8)   !MapzQ:Addr1
Addr2       STRING(8)   !MapzQ:Addr2
Size        LONG        !MapzQ:Size 
ProcNoAtF   STRING(256) !MapzQ:ProcNoAtF  !No @F might be Upper
ProcUPR     STRING(256) !MapzQ:ProcUPR    !No @F and Upper
LineText    STRING(256) !MapzQ:LineText
        END 
        
ModViewFileName  STRING(260) 
ModViewFile   FILE,DRIVER('DOS'),PRE(ModVw),NAME(ModViewFileName) 
    RECORD
Block       STRING(32000)     !ModVw:Block
    END 
  END 

ModuleQ    QUEUE,PRE(ModQ)
LineNo          LONG                    !ModQ:LineNo
FileName        STRING(40)              !ModQ:FileName
FileSize        LONG                    !ModQ:FileSize
FileDate        LONG                    !ModQ:FileDate
FileTime        LONG                    !ModQ:FileTime
ProcCnt         SHORT                   !ModQ:ProcCnt
Procs           STRING(1024)            !ModQ:Procs
ProcsTip        STRING(1024)            !ModQ:ProcsTip
            END

ProcedureQ    QUEUE,PRE(ProcQ)
LineNo          LONG                    !ProcQ:LineNo
ModName         STRING(40)              !ProcQ:ModName
MapSize         LONG                    !ProcQ:MapSize  !Size from Map
ProcName        STRING(64)              !ProcQ:ProcName
ProcTip         STRING(256)             !ProcQ:ProcsTip
ProcUPR         STRING(64)              !ProcQ:ProcUPR
            END

CodeQ    QUEUE,PRE(CodeQ)
LineNo          LONG                    !CodeQ:LineNo
ModuleName      STRING(32)              !CodeQ:ModuleName
Source          STRING(256)             !CodeQ:Source
            END
!EndRegion Queues

ProcDelimTabs    BYTE 
ViewModOnMouse2  BYTE(1) 
ProcNames4File        STRING(256) 
ProcNamesInModule     STRING(2000) 
WorkNotes             STRING(8000)  
TricksText            STRING(8000)  
ExpFileName           STRING(260)  
ExpFileText           STRING(8000)  

Window WINDOW('APP Splitter - Find the Biggest Modules and Procedures to move to another APP'), |
            AT(,,500,300),GRAY,SYSTEM,MAX,ICON('AppSplit.ico'),FONT('Seogo UI',9),RESIZE
        SHEET,AT(2,2),FULL,USE(?Sheet1),SCROLL,JOIN
            TAB(' APP to Process '),USE(?TabAPP)
                PROMPT('Project Folder:'),AT(7,20),USE(?AppPathBS:Pmt)
                ENTRY(@s255),AT(58,20,423),USE(AppPathBS),FONT('Consolas',9),TIP('xxxxx')
                PROMPT('APP Name:'),AT(7,36),USE(?AppNameOnly:Pmt)
                ENTRY(@s32),AT(58,36,141),USE(AppNameOnly),FONT('Consolas',9),TIP('APP Name without ' & |
                        '.APP Extension')
                STRING('If generated Source CLWs are in another folder that is not supported'),AT(210,37), |
                        USE(?SourceFYI)
                PROMPT('Target Name:'),AT(7,52),USE(?TargetName:Pmt)
                STRING('   (w/o .EXT)'),AT(7,64),USE(?TargetName:Pmt:fyi),FONT(,8)
                ENTRY(@s32),AT(58,52,141),USE(TargetName),FONT('Consolas',9),TIP('Target Name withou' & |
                        't .DLL .EXE .LIB Extension')
                CHECK('Debug Build (Uncheck for Release) - Used to file .MAP file'),AT(58,68), |
                        USE(DebugRelease),VALUE('Debug','Release')
                BUTTON('&Load All Files CLW, EXP, MAP'),AT(58,88,142,24),USE(?LoadFilesBtn), |
                        FONT('Microsoft Sans Serif',10,,FONT:regular),ICON(ICON:VCRplay),LEFT
                PROMPT('App CLW File with MAP:'),AT(7,150,49,18),USE(?AppClwNameOfFile:Pmt)
                ENTRY(@s255),AT(58,153,423),USE(AppClwNameOfFile),FONT('Consolas',9),TIP('Usually Ap' & |
                        'pName.CLW has MAP')
                BUTTON('&Process File'),AT(59,169,49,14),USE(?ProcessBtn)
                CHECK('Tab between procs'),AT(122,169),USE(ProcDelimTabs),TIP('Tab puts them in colu' & |
                        'mns in Excel<13,10> Norm is spaces between procs. ')
                BUTTON('Paste'),AT(214,169,,14),USE(?PasteBtn),SKIP,TIP('Paste Clipboard into Window' & |
                        ' and Process')
                BUTTON('&Close'),AT(324,169,42,14),USE(?CloseBtn),SKIP,STD(STD:Close)
                PROMPT('Scan the Map to find MODULES and the Procedures. Also get the CLW file size.' & |
                        ' To split an APP it can be easiest to start with the biggest modules.'), |
                        AT(7,193,276,37),USE(?About)
                PROMPT('Linker MAP:'),AT(7,225,49,18),USE(?AppClwNameOfFile:Pmt:2)
                ENTRY(@s255),AT(58,226,423),USE(MapLnkNameOfFile),FONT('Consolas',9),TIP('In MAP fol' & |
                        'der under Release or Debug')
                CHECK('Omit DATA Imports'),AT(137,249),USE(OmitImportedData),TIP('Data has $ in symbol')
                BUTTON('&Load Link MAP'),AT(59,242,64,14),USE(?LoadLinkBtn)
                BUTTON('Run<13,10>Again'),AT(449,36,33,26),USE(?RunAgainBtn),SKIP,TIP('Run another instance of App Splitter')
            END
            TAB(' &Modules '),USE(?TabModules)
                BUTTON('Copy Modules for Excel Paste'),AT(7,18,106,12),USE(?CopyModsBtn),SKIP
                BUTTON('View Module File'),AT(127,18,,12),USE(?ViewModuleBtn),SKIP,TIP('View the mod' & |
                        'ule source. Useful to see if there is module data')
                CHECK('Double Click Views'),AT(201,19),USE(ViewModOnMouse2),TIP('Double click on mod' & |
                        'ule line to view.<13,10>Uncheck shows line in Map Clw. ')
                STRING('Click to Sort - Typically by File Size and work on the Largest First'),AT(283,19), |
                        USE(?ClikSort:Pmt)
                LIST,AT(7,33),FULL,USE(?LIST:ModuleQ),VSCROLL,FONT('Consolas',10),FROM(ModuleQ), |
                        FORMAT('23R(2)|FM~Line~@n5@60L(2)|FM~Module Name~@s64@40R(2)|FM~Size~C(0)@n9' & |
                        '@36R(2)|FM~Date~C(0)@d1-@28R(2)|FM~Time~C(0)@t1@24R(2)|FM~Count~C(0)@n4@20L' & |
                        '(2)|FMP~Procedures~@s255@')
            END
            TAB(' &Procedures '),USE(?TabProcedures)
                STRING('MAP Size is calculated from the MAP Addresses. Zero would indicate the Smart' & |
                        ' Linker did not include a procedure that was not callered nor exported'),AT(7,19), |
                        USE(?ProcMapSizeFYI)
                LIST,AT(7,33),FULL,USE(?LIST:ProcedureQ),VSCROLL,FONT('Consolas',10),FROM(ProcedureQ), |
                        FORMAT('27R(2)|FM~Line~@n6@70L(2)|FM~Module Name~@s64@44R(2)|FM~MAP Size~C(0' & |
                        ')@n9b@20L(2)|FMP~Procedure~@s255@')
            END
            TAB(' Map CL&W File Code '),USE(?TabClw)
                LIST,AT(5,19),FULL,USE(?LIST:CodeQ),VSCROLL,FONT('Consolas',10),FROM(CodeQ), |
                        FORMAT('29R(2)|FM~Line~@n7@61L(2)|FM~Module Name~@s32@20L(2)|FMP~CODE - Doub' & |
                        'le click on line to open code line for copy~@s255@')
            END
            TAB(' File View '),USE(?TabViewModule)
                ENTRY(@s255),AT(7,20,491),USE(ModViewFileName),SKIP,TRN,FONT('Consolas'),READONLY
                TEXT,AT(7,36),FULL,USE(ModVw:Block),HVSCROLL,FONT('Consolas',10),READONLY
            END
            TAB(' Proc Names '),USE(?TabProcNames)
                ENTRY(@s255),AT(7,20,491),USE(ProcNames4File),SKIP,TRN,FONT('Consolas'),READONLY
                TEXT,AT(7,36),FULL,USE(ProcNamesInModule),HVSCROLL,FONT('Consolas',11),READONLY
            END
            TAB('.MAP Size '),USE(?TabMapSize)
                BUTTON('Proc Only'),AT(5,19,44,12),USE(?MapProcOnlyBtn),SKIP,TIP('Keep only PROCEDUR' & |
                        'E lines')
                BUTTON('Notepad'),AT(53,19,42,12),USE(?MapOpenNotepadBtn),SKIP,TIP('Open MAP file in' & |
                        ' Notepad')
                ENTRY(@s255),AT(106,19,,11),FULL,USE(MapLnkNameOfFile,, ?MapLnkNameOfFile:2),SKIP,TRN, |
                        FONT('Consolas'),TIP('Linker Map file'),READONLY
                LIST,AT(5,34),FULL,USE(?LIST:MapSizeQ),VSCROLL,FONT('Consolas',10),VCR,FROM(MapSizeQ), |
                        FORMAT('27R(2)|M~Line~C(0)@N_5@142L(2)|FM~Procedure Mangeled & Symbols ~@s64' & |
                        '@?40R(2)|M~Start~C(0)@s8@40R(2)|M~End Addr~C(0)@s8@44R(2)|M~Code Size~L(2)@' & |
                        'n9b@20L(2)F~Procedure Name~@s64@')
            END
            TAB('.MAP Imports '),USE(?TabLnkMap)
                BUTTON('Reload MAP'),AT(5,19,46,12),USE(?LoadLinkReloadBtn),SKIP
                ENTRY(@s255),AT(67,19,,11),FULL,USE(MapLnkNameOfFile,, ?MapLnkNameOfFile:3),SKIP,TRN, |
                        FONT('Consolas'),READONLY
                LIST,AT(5,34,250),FULL,USE(?LIST:ImportQ),VSCROLL,FONT('Consolas',10),FROM(ImportQ), |
                        FORMAT('60L(2)|FMT~DLL Name~@s32@?20L(2)|FM~Procedure~@s64@')
                LIST,AT(260,34),FULL,USE(?LIST:Import2Q),VSCROLL,FONT('Consolas',10),FROM(Import2Q), |
                        FORMAT('49L(2)|FM~DLL Name~@s32@20L(2)|FM~By Procedure~@s64@?#3#')
            END
            TAB(' Exports '),USE(?TabExports)
                BUTTON('Notepad'),AT(7,19,42,12),USE(?ExpOpenNotepadBtn),SKIP,TIP('Open EXP file in ' & |
                        'Notepad')
                ENTRY(@s255),AT(57,20,,11),FULL,USE(ExpFileName),SKIP,TRN,FONT('Consolas'),READONLY
                TEXT,AT(7,36),FULL,USE(ExpFileText),HVSCROLL,FONT('Consolas',10),READONLY
            END
            TAB(' Notes '),USE(?TabWorkNotes)
                TEXT,AT(7,20),FULL,USE(WorkNotes),HVSCROLL,COLOR(0E1FFFFH)
            END
            TAB(' Tricks '),USE(?TabTrricks)
                TEXT,AT(7,20),FULL,USE(TricksText),HVSCROLL,FONT('Consolas',10),COLOR(0E1FFFFH),READONLY
            END
        END
    END
!X       LONG
SortClsMods CBSortClass1
SortClsProc CBSortClass1
SortClsMapZ CBSortClass1
ConfigINI  STRING('.\Config.INI') 
DOO CLASS
ProcessCLW          PROCEDURE(BOOL CheckExists=0),BOOL
ProcessMAP          PROCEDURE(BOOL CheckExists=0),BOOL
ExtRemove           PROCEDURE(*STRING FN, STRING ExtList)  !Remove .APP 
Set_TabProcNames    PROCEDURE()
CopyModsButton      PROCEDURE()
MapProcedureOnly    PROCEDURE()  !Only keep PROCEDURE's in MapSizeQ no Data or markers
    END
  CODE
  LoadTricksText()
    AppNameOnly='Pr04'
    TargetName ='QPr04'

  AppPathBS   = GETINI('Cfg','Path','D:\DecSys_Zips_Clarion11\C11Apps\EisTrsTier2\',ConfigINI)
  AppNameOnly = GETINI('Cfg','APP',AppNameOnly,ConfigINI)
  TargetName  = GETINI('Cfg','Target',TargetName,ConfigINI)
  DebugRelease  = GETINI('Cfg','Build',DebugRelease,ConfigINI)
  
  ModViewFilename = 'Select File on the Modules tab to view source here' 
  ProcNames4File  = 'Select File on the Modules tab to view procedure names here' 
  SYSTEM{PROP:PropVScroll}=1 ; SYSTEM{PROP:MsgModeDefault}=MSGMODE:CANCOPY
  OPEN(Window) 
  0{PROP:MinWidth} = 0{PROP:Width} * .50
  0{PROP:MinHeight} = 0{PROP:Height} * .60
  ?Sheet1{PROP:TabSheetStyle}=1   
  ?LIST:ModuleQ{PROP:LineHeight} = 1 + ?LIST:ModuleQ{PROP:LineHeight} 
  ?LIST:ProcedureQ{PROP:LineHeight} = 1 + ?LIST:ProcedureQ{PROP:LineHeight} 
  ?LIST:CodeQ{PROP:LineHeight} = 1 + ?LIST:CodeQ{PROP:LineHeight} 
  ?LIST:ImportQ{PROP:LineHeight} = 1 + ?LIST:ImportQ{PROP:LineHeight} 
  SortClsMods.Init(ModuleQ, ?LIST:ModuleQ,1) 
  SortClsProc.Init(ProcedureQ, ?LIST:ProcedureQ,1)                         
  SortClsMapZ.Init(MapSizeQ, ?LIST:MapSizeQ,3)                         
  COMPILE('!**WndPrv END**', _IFDef_CBWndPreview_)
    WndPrvCls.Init()
  !**WndPrv END**

  ACCEPT
    CASE EVENT() 
    OF EVENT:OpenWindow 
    END
    CASE ACCEPTED()
    OF ?AppPathBS  ; AppPathBS=PathBS(AppPathBS)
                     IF ~EXISTS(AppPathBS) THEN BEEP ; SELECT(?AppPathBS) ; CYCLE.
                     PUTINI('Cfg','Path',AppPathBS,ConfigINI)

    OF ?AppNameOnly  
                     DOO.ExtRemove(AppNameOnly,'.APP')
                     IF AppNameOnly THEN PUTINI('Cfg','APP',AppNameOnly,ConfigINI).
                     IF ~TargetName THEN 
                         TargetName=AppNameOnly ; DISPLAY  !ToDo get from CwProj
                     END 
    OF ?TargetName   
                     IF ~TargetName THEN TargetName=AppNameOnly ; DISPLAY .
                     DOO.ExtRemove(TargetName,'.EXE.DLL.LIB')
                     IF TargetName THEN PUTINI('Cfg','Target',TargetName,ConfigINI).
                     
    OF ?DebugRelease  
                     PUTINI('Cfg','Build',DebugRelease,ConfigINI)
    OF ?LoadFilesBtn 
                     IF ~EXISTS(AppPathBS) THEN SELECT(?AppPathBS) ; CYCLE.
                     IF ~DOO.ProcessCLW(1) OR ~DOO.ProcessMAP(1) THEN CYCLE.
                     IF ~DOO.ProcessCLW()  OR ~DOO.ProcessMAP() THEN 
                         SELECT(?TabAPP)
                         CYCLE
                     END
                     SELECT(?TabModules) 

    OF ?ProcessBtn   
                     IF ~DOO.ProcessCLW() THEN CYCLE.
                     
    OF ?PasteBtn ;  AppClwNameOfFile=CLIPBOARD() ; DISPLAY
                    IF Exists(AppClwNameOfFile) THEN POST(EVENT:Accepted, ?ProcessBtn). 

    OF ?CopyModsBtn ; DOO.CopyModsButton()
    OF ?RunAgainBtn ; RUN(COMMAND('0'))  
    OF ?ViewModuleBtn
       GET(ModuleQ,CHOICE(?LIST:ModuleQ)) 
       ModViewFileName=AppPathBS & ModQ:FileName  
       DOO.Set_TabProcNames() 
       CLOSE(ModViewFile) 
       OPEN(ModViewFile,40h) 
       IF ERRORCODE() THEN 
          Message('Open file error ' & Error() &'||'& ErrorFile()) ; CYCLE 
       END 
       SET(ModViewFile) 
       NEXT(ModViewFile) 
       CLOSE(ModViewFile) 
       DISPLAY ; SELECT(?TabViewModule) ; DISPLAY        
    
    OF ?MapProcOnlyBtn      ; DOO.MapProcedureOnly()   
    OF ?MapOpenNotepadBtn   ; IF EXISTS(MapLnkNameOfFile) THEN RUN('Notepad "' & CLIP(MapLnkNameOfFile) &'"').
    OF ?ExpOpenNotepadBtn   ; IF EXISTS(ExpFileName) THEN RUN('Notepad "' & CLIP(ExpFileName) &'"').
    
    OF   ?LoadLinkBtn 
    OROF ?LoadLinkReloadBtn 
         IF ~DOO.ProcessMAP() THEN CYCLE.
    END  

    CASE FIELD()
    OF ?Sheet1      ; IF EVENT()=EVENT:NewSelection THEN DISPLAY. 
    OF ?LIST:ModuleQ 
        CASE EVENT()
        OF EVENT:NewSelection  
            GET(ModuleQ,CHOICE(?LIST:ModuleQ))
            IF KEYCODE()=MouseLeft2 THEN
               DOO.Set_TabProcNames()
               !ProcNames4File = AppPathBS & ModQ:FileName 
               !ProcNamesInModule=ModQ:ProcsTip 
               IF ViewModOnMouse2 THEN 
                  POST(EVENT:Accepted,?ViewModuleBtn) ; CYCLE 
                  CYCLE 
               ENd 
               CodeQ:LineNo = ModQ:LineNo
               GET(CodeQ,CodeQ:LineNo) 
               SELECT(?LIST:CodeQ,POINTER(CodeQ))
            END 
        OF EVENT:HeaderPressed ; SortClsMods.HeaderPressed()   
        END 

    OF ?LIST:ProcedureQ 
        CASE EVENT()
        OF EVENT:NewSelection  
            GET(ProcedureQ,CHOICE(?LIST:ProcedureQ))
            IF KEYCODE()=MouseLeft2 THEN
!               DOO.Set_TabProcNames()
               CodeQ:LineNo = ProcQ:LineNo
               GET(CodeQ,CodeQ:LineNo) 
               SELECT(?LIST:CodeQ,POINTER(CodeQ))
            END 
        OF EVENT:HeaderPressed ; SortClsProc.HeaderPressed()   
        END

    OF ?LIST:CodeQ 
        CASE EVENT()
        OF EVENT:NewSelection  
            GET(CodeQ ,CHOICE(?LIST:CodeQ ))
            IF KEYCODE()=MouseLeft2 THEN
               LittleTextWindow(CLIP(CodeQ:ModuleName) &'<13,10,13,10>'&LEFT(CodeQ:Source),'Code line ' & CodeQ:LineNo )
            END 
        END
 
    OF ?LIST:MapSizeQ 
        CASE EVENT()
        OF EVENT:NewSelection  
            GET(MapSizeQ,CHOICE(?LIST:MapSizeQ)) 
            IF KEYCODE()=MouseLeft2 THEN
               LittleTextWindow(MapzQ:LineText,'MAP Line ' & MapzQ:LineNo)
            END 
        OF EVENT:HeaderPressed ; SortClsMapZ.HeaderPressed()   
        END      
    END 
           
  END
  RETURN   
!-------------------------------------------------
DOO.ProcessClw PROCEDURE(BOOL CheckExists=0)!,BOOL
    CODE  
    AppClwNameOfFile=AppPathBS & CLIP(AppNameOnly) &'.CLW' ; DISPLAY
    IF ~EXISTS(AppClwNameOfFile) THEN 
        Message('APP CLW file not found|  ' & AppClwNameOfFile) 
        RETURN False
    ELSIF CheckExists
        RETURN TRUE
    END 
    ProcessAppClwFile() 
    SELECT(?TabModules) 
    PUTINI('Cfg','File',AppClwNameOfFile,ConfigINI) 
    ExpFileName=AppPathBS & CLIP(TargetName) &'.EXP'
    TextLoadFromFile(ExpFileName,ExpFileText)
    RETURN TRUE

DOO.ProcessMAP PROCEDURE(BOOL CheckExists=0)!,BOOL
    CODE
    MapLnkNameOfFile=AppPathBS &'Map\' & CLIP(DebugRelease) &'\'& CLIP(TargetName) &'.MAP' ; DISPLAY 
    IF ~EXISTS(MapLnkNameOfFile) THEN 
        Message('Link MAP file not found |   ' & MapLnkNameOfFile) 
        SELECT(?MapLnkNameOfFile)
        RETURN False
    ELSIF CheckExists
        RETURN TRUE        
    END
    LoadLinkMapFile() 
    SELECT(?TabLnkMap) 
    PUTINI('Cfg','LnkMap',MapLnkNameOfFile,ConfigINI)
    RETURN True   

DOO.ExtRemove PROCEDURE(*STRING FN, STRING ExtList)  !Remove .APP
P SHORT,AUTO
    CODE
    P=LEN(CLIP(FN))-3
    IF P>1 AND FN[P]='.' THEN
       IF INSTRING(UPPER(SUB(FN,P,4)),ExtList) THEN
          FN=SUB(FN,1,P-1)
          DISPLAY
       END 
    END
    RETURN
    

DOO.Set_TabProcNames    PROCEDURE()
    CODE
    ProcNames4File = AppPathBS & ModQ:FileName 
    ProcNamesInModule= CLIP(ModQ:ProcsTip) & |
            '<13,10,13,10>Proc Count: ' & ModQ:ProcCnt & |
            '<13,10>File Size: ' & ModQ:FileSize & |
            '<13,10>File Name: ' & CLIP(ProcNames4File) & | 
            '<13,10>' 
    RETURN

DOO.CopyModsButton    PROCEDURE()
CB   ANY
MX   LONG  
    CODE
    EXECUTE POPUP('As Sorted Now|-|Sort by Size|Sort by Name|Sort by Count|Sort by Line No')
        BEGIN ; END
        SORT(ModuleQ, ModQ:FileSize, -ModQ:ProcCnt, ModQ:FileName)
        SORT(ModuleQ, ModQ:FileName)
        SORT(ModuleQ, ModQ:ProcCnt, ModQ:FileSize, ModQ:FileName)
        SORT(ModuleQ, ModQ:LineNo, ModQ:FileName)
    END 
    CB='FileName<9>FileSize<9>Count<9>Procedures<13,10>'
    LOOP MX=1 TO Records(ModuleQ)
        GET(ModuleQ,MX)
        CB=CB& CLIP(ModQ:FileName) &'<9>'&  ModQ:FileSize &'<9>'&  ModQ:ProcCnt &'<9>'& CLIP(ModQ:Procs) &'<13,10>'
    END         
    SETCLIPBOARD(CB)
    RETURN 

DOO.MapProcedureOnly PROCEDURE()  !Only keep PROCEDURE's in MapSizeQ no Data or markers
MX LONG,AUTO 
    CODE
    LOOP MX=RECORDS(MapSizeQ) TO 1 BY -1
        GET(MapSizeQ,MX)
        IF ~MapzQ:ProcNoAtF THEN 
            DELETE(MapSizeQ) 
        END 
    END
    DISPLAY
    RETURN 
!=====================
DB   PROCEDURE(STRING xMessage)
Prfx EQUATE('ModSplit: ')   !All output gets this
sz   CSTRING(SIZE(Prfx)+SIZE(xMessage)+1),AUTO
  CODE 
  sz  = Prfx & CLIP(xMessage)
  OutputDebugString( sz )
!==============================================================  
LittleTextWindow   PROCEDURE(STRING InTxt,<STRING InCaption>) 
Txt STRING(4000)
WindowLT WINDOW('Text'),AT(,,395,100),GRAY,SYSTEM,FONT('Segoe UI',10),RESIZE 
        TEXT,AT(1,1),FULL,USE(Txt),HVSCROLL,FONT('Consolas',10)
    END
    CODE
    Txt = InTxt
    OPEN(WindowLT) 
    IF ~OMITTED(InCaption) AND InCaption THEN 0{PROP:Text}=InCaption .
    ACCEPT ; END
    RETURN
!==============================================================  
ProcessAppClwFile  PROCEDURE()
PathBS SHORT    
!AppPathBS   PSTRING(256) 
LastModule  STRING(32)
InModule    SHORT
IsCLW       SHORT     
IsRDRUSF    SHORT           !Standard functions that I want to ignore
ALine       STRING(512)
ULine       STRING(512)
!LineX       LONG
Qt1         SHORT     
Qt2         SHORT     
Par1        SHORT 
QNdx    LONG,AUTO
DirQ    QUEUE(FILE:Queue),PRE(DirQ)
        END ! DirQ:Name  DirQ:ShortName(8.3?)  DirQ:Date  DirQ:Time  DirQ:Size  DirQ:Attrib    
LineNo  LONG    
ModProcQ QUEUE,PRE(MPrcQ)
Name       PSTRING(80)
LwrName    PSTRING(80)
       END
Px     LONG 
DelimProcs    PSTRING(6)       
    CODE
    DelimProcs=CHOOSE(~ProcDelimTabs,'  ',' <9>')  
    FREE(ModuleQ) ; FREE(CodeQ) 
    AppClwNameOfFile=LONGPATH(AppClwNameOfFile) 
    PathBS=INSTRING('\',AppClwNameOfFile,-1,SIZE(AppClwNameOfFile)) ;   
        IF ~PathBS THEN Message('PathBS=' & PathBS ) ; RETURN .
    DB('AppClwNameOfFile=' & AppClwNameOfFile)  
    DB('Path=' & SUB(AppClwNameOfFile,1,PathBS))  
    AppPathBS = SUB(AppClwNameOfFile,1,PathBS) 
    
    DIRECTORY(DirQ,AppPathBS & '*.CLW',ff_:NORMAL)
    DB('Dir *.CLW found ' & RECORDS(DirQ) & ' in ' & AppPathBS )
    IF ~RECORDS(DirQ) THEN Message('No CLWs found in Folder ' & AppPathBS ). 
    LOOP QNdx = 1 TO RECORDS(DirQ)                    !Case Name
         GET(DirQ,QNdx)
         DirQ:Name=UPPER(DirQ:Name)
         PUT(DirQ)
    END !LOOP

    !--- Now Process 
    OPEN(AppClwFile,40h)
    IF ERRORCODE() THEN 
       Message('Error Open File Error ' & Error() &'||' & Name(AppClwFile) ) 
       RETURN
    END 
    SET(AppClwFile)
    LOOP
        NEXT(AppClwFile) ; IF ERRORCODE() THEN BREAK.
        LineNo+=1 
        CodeQ:LineNo=LineNo
        CodeQ:ModuleName=''
        CodeQ:Source=AppClw:Line
        ADD(CodeQ) 
        IF AppClw:Line THEN DO Take1LineRtn .
    END
    CLOSE(AppClwFile)    
    RETURN

Take1LineRtn ROUTINE
    
    ALine = LEFT(AppClw:Line)
    IF ALine[1]='!' THEN EXIT.
    ULine = UPPER(ALine)
    IF ~AppClw:Line[1] AND SUB(ULine,1,7) =  'MODULE(' THEN    !Must have a space in col 1 
        
       IF RECORDS(ModProcQ) THEN DO FinishModuleRtn.
       FREE(ModProcQ)  
       InModule=1 ; IsCLW=0 ; IsRDRUSF=0
       Qt1=INSTRING(CHR(39),ALine,1)
       Qt2=INSTRING(CHR(39),ALine,1,Qt1+1)
       IF ~Qt1 OR ~Qt2 THEN EXIT.  !so IsCLW=0.        
       LastModule=SUB(ALine,Qt1+1,Qt2-Qt1-1) ; LastModule[1]=UPPER(LastModule[1])
       CodeQ:ModuleName=LastModule
       PUT(CodeQ) 
       
       IF INSTRING('_SF.CLW',ULine,1) OR INSTRING('_RU.CLW',ULine,1) OR INSTRING('_RD.CLW',ULine,1) THEN 
          IsRDRUSF=1
          EXIT
       END
       !must be numeric ? 
       IsCLW=INSTRING('.CLW',ULine,1) 
       IF ~Qt1 THEN IsCLW=0. 
       IF ~IsCLW THEN EXIT. 
       
       CLEAR(ModuleQ) 
       ModQ:LineNo=LineNo 
       ModQ:FileName=SUB(ALine,Qt1+1,99) 
       Qt1=INSTRING(CHR(39),ModQ:FileName,1)  
       IF Qt1 THEN ModQ:FileName=SUB(ModQ:FileName,1,Qt1-1). 

       DirQ:Name=UPPER(ModQ:FileName)
       GET(DirQ,DirQ:Name)
       IF ERRORCODE() THEN CLEAR(DirQ).
       ModQ:FileSize = DirQ:Size
       ModQ:FileDate = DirQ:Date
       ModQ:FileTime = DirQ:Time  
       ADD(ModuleQ)

       EXIT

    ELSIF SUB(ULine,1,4) = 'END ' THEN 
       IF InModule=1 AND IsCLW THEN 
          !Finish the Line 
          IF RECORDS(ModProcQ) THEN DO FinishModuleRtn.
       END 
       InModule=0
       IsCLW=0 
       EXIT 
    ELSIF ~ALine THEN 
       EXIT 
    END    
    IF InModule<>1 THEN EXIT. 

!TODO Multi Line Protypes 
    IF ~IsCLW THEN 
       CASE ALine[1]
       OF ')' OROF '<<' ; EXIT  !multi-line PROTOTYPE
       END
    END 


    Par1=INSTRING('(',ALine,1) ; IF Par1 THEN ALine=SUB(ALine,1,Par1-1).
    Par1=INSTRING(',',ALine,1) ; IF Par1 THEN ALine=SUB(ALine,1,Par1-1).    !Could be ProceName,DLL()
    Par1=INSTRING(' ',ALine,1) ; IF Par1 THEN ALine=SUB(ALine,1,Par1-1).    !Could be  Name  Procedure('
    
    IF ~IsRDRUSF THEN  
       CLEAR(ProcedureQ)
       ProcQ:LineNo   = LineNo
       ProcQ:ModName  = LastModule
       ProcQ:ProcName = ALine            
       ProcQ:ProcName[1]=UPPER(ProcQ:ProcName[1])
       ProcQ:ProcTip  = LEFT(AppClw:Line)
       ProcQ:ProcUPR  = UPPER(ProcQ:ProcName)
       ADD(ProcedureQ,ProcQ:LineNo)
       !ADD(ProcedureQ,ProcQ:ProcName,ProcQ:ModName)
    END

    IF ~IsCLW THEN EXIT. 
    ModQ:ProcCnt += 1    
    ModQ:Procs=CHOOSE(~ModQ:ProcCnt,'',CLIP(ModQ:Procs)& DelimProcs ) & ALine      
    MPrcQ:Name=CLIP(ALine)
    MPrcQ:LwrName=CLIP(LOWER(MPrcQ:Name))
    ADD(ModProcQ,MPrcQ:LwrName) 

    PUT(ModuleQ)

FinishModuleRtn ROUTINE     !Rewrite Procs in Alpha order . could be optional 

    LOOP PX=1 TO RECORDS(ModProcQ)
        GET(ModProcQ,PX)
        ModQ:Procs=CHOOSE(PX=1,'',CLIP(ModQ:Procs)& DelimProcs ) & MPrcQ:Name      
        ModQ:ProcsTip=CHOOSE(PX=1,'',CLIP(ModQ:ProcsTip)&'<13,10>') &' '& MPrcQ:Name      
    END
    PUT(ModuleQ)
    FREE(ModProcQ)    
    
!==========================================================
LoadLinkMapFile  PROCEDURE()
InImports   SHORT
OutImports  SHORT
BlankCount  SHORT        !After first Blank are Procedures
ALine       STRING(512)
ULine       STRING(512)
Cln1         SHORT     
Spc1         SHORT     
LineNo  LONG    
LastDLLUpr  STRING(32)
EndF        LONG            !Imports ewnd with @F 

SizeCount LONG
Addr1   LONG
Addr2   LONG
MX      LONG
      
    CODE
    FREE(ImportQ)
    FREE(Import2Q)
    MapLnkNameOfFile=LONGPATH(MapLnkNameOfFile) 
    DB('MapLnkNameOfFile=' & MapLnkNameOfFile)  
    
    !--- Now Process 
    OPEN(MapLnkFile,40h)
    IF ERRORCODE() THEN 
       Message('Error Open File Error ' & Error() &'||' & Name(MapLnkFile) ) 
       RETURN
    END 
    SET(MapLnkFile)
    LOOP
        NEXT(MapLnkFile) ; IF ERRORCODE() THEN BREAK.
        LineNo+=1 
        DO Take1LineRtn
    END
    CLOSE(MapLnkFile)
    DO MapSizeQ_Sort_Rtn
    RETURN

!Imports
!ClaDOS.dll:DOS 6A9198
!ClaRUN.dll:Cla$ACCEPTED 6A9670,401000
!ClaRUN.dll:Cla$ADDqueue 6A9674
!ClaRUN.dll:Cla$ADDqueuekey 6A9678,401008
!ClaRUN.dll:__sysinit 6A9B34,401580
!ClaRUN.dll:__sysstart 6A9B38,401588
!CPC110P32:ASSGNPGOFPG 6A9B54
!CPC110P32:HANDLECOPIES 6A9B58
!CPC110P32:PRINTPREVIEW 6A9B5C
!CPC110P32:SUPPORTED 6A9B60
!KERNEL32.dll:CloseHandle 6A9BB8,401590
!KERNEL32.dll:CreateFileA 6A9BBC,401598
!KERNEL32.dll:CreateMutexA 6A9BC0,4015A0
!KERNEL32.dll:DeleteFileA 6A9BC4

Take1LineRtn ROUTINE
    
    IF ~MapLnk:Line THEN BlankCount += 1.
    ALine = LEFT(MapLnk:Line)
    ULine = UPPER(ALine)
    IF ~InImports THEN 
        IF ULine='IMPORTS' THEN InImports=1. 
        IF ~InImports AND ~OutImports THEN    !BlankCount=1 AND 
           DO MapSizeQ_Add_Rtn
        END
        EXIT
    END 
    IF ~ALine THEN          !First blank line ends
        OutImports=1
        InImports=0 
        EXIT 
    END 
    Cln1=INSTRING(':',ALine,1) ; IF ~Cln1 THEN EXIT.                !Look for 
    Spc1=INSTRING(' ',ALine,1) ; IF ~Spc1 THEN Spc1=SIZE(ALine).    !Look for 
 
    ImpQ:DllName=SUB(ALine,1,Cln1-1)        ;  ImpQ:DllName[1]=UPPER(ImpQ:DllName[1])
    ImpQ:DllUpr =UPPER(ImpQ:DllName)
    ImpQ:ProcName=ALine[Cln1+1 : Spc1]      ;  ImpQ:ProcName[1]=UPPER(ImpQ:ProcName[1])
    ImpQ:ProcUpr=UPPER(ImpQ:ProcName)
    
    IF OmitImportedData AND INSTRING('$',ImpQ:ProcName) THEN EXIT.
    
    CASE UPPER(ImpQ:DllName)
    OF   'CLARUN.DLL'
    OROF 'KERNEL32.DLL'
    OROF 'SHELL32.DLL'
    OROF 'USER32.DLL'
    
    OROF 'CPC110P32'
    OROF 'PXCLIB40.DLL'
    OROF 'XCPRO40.DLL'
    OROF 'PXCLIB40.DLL'
         EXIT
    ELSE
         IF ImpQ:DllUpr[1:3]='CLA' AND ImpQ:DllUpr[7:10]='.DLL' THEN EXIT.  !e.g. ClaDOS.DLL
    END
    IF LastDLLUpr<>ImpQ:DllUpr THEN     !Add a Heading
       LastDLLUpr=ImpQ:DllUpr
       Import2Q = ImportQ
       ImpQ:ProcName='' 
       ImpQ:ProcUpr=''
       ImpQ:Level=-1
       ADD(ImportQ,ImpQ:DllUpr,ImpQ:ProcUpr) 
       ImportQ = Import2Q
    END
    ImpQ:Level=2 

    !Imports are UPPER so look up and try to make eaiser to read    
    EndF=INSTRING('@F',ImpQ:ProcName,1)     !Imports ewnd with @F
 !DB('EndF=' & EnDF &'  '& 
    IF EndF>1 THEN      !Imports ewnd with @F 
       ImpQ:ProcName[EndF : SIZE(ImpQ:ProcName)]=' '& ImpQ:ProcName[EndF : SIZE(ImpQ:ProcName)] !Insert space so easier to read
       ProcQ:ProcUPR  = UPPER(ImpQ:ProcName[1 : EndF-1]) 
       GET(ProcedureQ,ProcQ:ProcUPR)
!FYI if there is a INC file for the Externals then will NOT see this have an Effect       
       IF ~ERRORCODE() THEN
           ImpQ:ProcName[1 : EndF-1]=ProcQ:ProcName       !This is Upload Pretty
       END 
    END    
    
    ADD(ImportQ,ImpQ:DllUpr,ImpQ:ProcUpr)
    Import2Q = ImportQ
    ADD(Import2Q,Imp2Q:ProcUpr,Imp2Q:DllUpr)
    EXIT
    !-------------------------------------------------------------
MapSizeQ_Add_Rtn ROUTINE 

    IF ~ALine THEN EXIT.  !0123                  
    ALine = MapLnk:Line     !No LEFT()           19                  39
    IF SUB(ALine,19,19) = 'Code' THEN !Line with: Code                CSIDLFOLDER_TEXT
       ALine=SUB(ALine,1,19+3) & SUB(ALine,19+17,999)
    END
    ULine = ALine  
    CLEAR(MapSizeQ)
    MapzQ:LineText = MapLnk:Line
    MapzQ:LineNo = LineNo
    MapzQ:Addr1  = ULine[1:8] 
    ALine = ALine[10 : SIZE(ALine)] 
    MapzQ:ProcName = ALine

    EndF=INSTRING('@F',ALine,1)     !Imports ewnd with @F
    IF EndF>1 THEN      !Imports ewnd with @F 
       IF ~NUMERIC(ALine[EndF+2])  !A Class  @F##xxxx
          MapzQ:ProcNoAtF = SUB(ALine,1,EndF-1)
          MapzQ:ProcUPR   = SUB(ALine,1,EndF-1)
       END 
    END 
    MapzQ:Size    = LineNo  
    ADD(MapSizeQ)
    SizeCount += 1
!12345678 0    
! 610F440 INIT@F20PDFXTOOLSREPORTCLASSsbOsb
! 610F4B0 INIT@F20PDFXTOOLSREPORTCLASSBrsbOsb
! 610F570 COMPILESIZE_PR21@FRsbsb
! 616A108 PRINTCONTRACTSBYTRSCALENDAR@F
! 616C2A0 PRINTCONTRACTSBYTRSREASON@F
! 616E3B4 PRINTCONTRACTSDAYSPAID@F
!
! 627C234 CALLUPDATEJOB@F15SIE::JOBMANAGEROl
! 627C25C CONSTRUCT@F15SIE::JOBMANAGER
! 627D860 TYPE$CSIDLFOLDER
! 627D88C VMT$CSIDLFOLDER
MapSizeQ_Sort_Rtn ROUTINE
    SORT(MapSizeQ,MapzQ:Addr1) 
    SortClsMapZ.SetSortCol(3)
    ALine=''
    LOOP MX=RECORDS(MapSizeQ)  TO 1 BY -1
        GET(MapSizeQ,MX)
        IF ~ALine THEN     !TODO need to get Last Size High Address?
            ALine=MapzQ:Addr1
            CYCLE
        END 
       MapzQ:Addr2 = ALine
       Addr1=EVALUATE(MapzQ:Addr1 &'h')
       Addr2=EVALUATE(MapzQ:Addr2 &'h') 
       MapzQ:Size=Addr2-Addr1 
       IF MapzQ:ProcUPR THEN 
          ProcQ:ProcUPR = MapzQ:ProcUPR
          GET(ProcedureQ,ProcQ:ProcUPR)
          IF ERRORCODE() THEN CYCLE.
          ProcQ:MapSize = MapzQ:Size 
          PUT(ProcedureQ)
          MapzQ:ProcNoAtF = ProcQ:ProcName  !Up Low Name
       END
       PUT(MapSizeQ) 
       ALine=MapzQ:Addr1 
    END

!============================================================
PathBS   PROCEDURE(STRING P)!,STRING
L   LONG 
    CODE
    P=LEFT(P)
    L=Len(Clip(P))
    IF L AND P[L]<>'\' THEN RETURN P[1 : L] & '\'.
    RETURN CLIP(P) 
!============================================================
TextLoadFromFile   PROCEDURE(STRING FileName, *STRING OutText)
    CODE 
    BigDosFile{PROP:Name}=FileName
    OPEN(BigDosFile,40h) 
    IF ERRORCODE() THEN 
       OutText='Open File "' & CLIP(FileName) &'"<13,10>Error: ' & ErrorCode() &' '& ERROR()
       RETURN 
    END 
    SET(BigDosFile) 
    NEXT(BigDosFile) 
    IF ~ERRORCODE() AND Big:Block THEN 
        OutText=Big:Block
    ELSE
        OutText='No Text in "' & CLIP(FileName) &'"<13,10>Error: ' & ErrorCode() &' '& ERROR()
    END 
    CLOSE(BigDosFile) 
    RETURN 

!============================================================
LoadTricksText     PROCEDURE()
    CODE
    BigDosFile{PROP:Name}='TricksText.TXT'
    TricksText='Load from file: ' & BigDosFile{PROP:Name} 
    OPEN(BigDosFile,40h) 
    IF ERRORCODE() THEN 
        TricksText=CLIP(TricksText) &'<13,10,13,10>Open File Error ' & ErrorCode() &' '& ERROR()
       RETURN 
    END 
    SET(BigDosFile) 
    NEXT(BigDosFile) 
    IF ~ERRORCODE() AND Big:Block THEN TricksText=Big:Block .
    CLOSE(BigDosFile) 
    RETURN 
    
!Region CBSortClass
!==========================================================
CBSortClass1.Init PROCEDURE(QUEUE ListQueue, LONG ListFEQ, SHORT SortColNow=0)
    CODE
    SELF.QRef &= ListQueue
    SELF.FEQ=ListFEQ
    ListFEQ{PROPLIST:HasSortColumn}=1
    SELF.FEQ{PROPLIST:HdrSortBackColor}=COLOR:HIGHLIGHT     !8000001Bh  !GradientActiveCaption
    SELF.FEQ{PROPLIST:HdrSortTextColor}=COLOR:HIGHLIGHTtext !Color:CaptionText
    !Brighter {PROPLIST:HdrSortBackColor}=COLOR:Highlight / {PROPLIST:HdrSortTextColor}=COLOR:HighlightText    
    IF SortColNow THEN SELF.SetSortCol(SortColNow).
    RETURN
CBSortClass1.SetSortCol PROCEDURE(SHORT SortColNow)
    CODE
    SELF.ColumnNow=SortColNow
    SELF.FEQ{PROPLIST:Locator,ABS(SortColNow)}=1
    SELF.QFieldLast=SELF.FEQ{PROPLIST:FieldNo,ABS(SortColNow)}
    SELF.Who1st=CHOOSE(SortColNow<0,'-','+') & WHO(SELF.QRef,SELF.QFieldLast) ; SELF.Who2nd=''
    SELF.FEQ{PROPLIST:SortColumn}=ABS(SortColNow)
    RETURN    
CBSortClass1.HeaderPressed PROCEDURE(SHORT ForceSortByColumn=0)
QRecord    STRING(SIZE(SELF.QRef)),AUTO
LChoice    LONG,AUTO
X          LONG,AUTO
ColumnNow  &SHORT
ColumnLast &SHORT
QFieldNow  &SHORT
QFieldLast &SHORT
Who1st     &STRING
Who2nd     &STRING
    CODE
    ColumnNow&=SELF.ColumnNow;ColumnLast&=SELF.ColumnLast;QFieldNow&=SELF.QFieldNow;QFieldLast&=SELF.QFieldLast;Who1st&=SELF.Who1st;Who2nd&=SELF.Who2nd
    LChoice = CHOICE(SELF.FEQ)
    IF LChoice THEN GET(SELF.QRef, LChoice) ; QRecord=SELF.QRef.
    ColumnNow=CHOOSE(~ForceSortByColumn, SELF.FEQ{PROPList:MouseDownField}, ForceSortByColumn)
    QFieldNow=SELF.FEQ{PROPLIST:FieldNo,ColumnNow} 
    IF QFieldNow<>ABS(QFieldLast) AND Who1st THEN Who2nd=',' & Who1st.
    Who1st=CHOOSE(QFieldNow=QFieldLast,'-','+') & WHO(SELF.QRef,QFieldNow)
 SELF.FEQ{PROP:Tip}='Sort ColumnNow:'& ColumnNow  &' QNow=' & QFieldNow &' QLast='& QFieldLast &' Who=' & CLIP(Who1st) & Who2nd
    SORT(SELF.QRef,CLIP(Who1st) & Who2nd)
    SELF.FEQ{PROPLIST:Locator,ColumnNow}=1
    ColumnLast=CHOOSE(QFieldNow=ABS(QFieldLast),-1*ColumnLast,ColumnNow) 
    QFieldLast=CHOOSE(QFieldNow=ABS(QFieldLast),-1*QFieldLast,QFieldNow) 
    IF LChoice THEN !Reselect the LChoice that was selected 
       LOOP X=1 TO RECORDS(SELF.QRef) ; GET(SELF.QRef,X)
          IF SELF.QRef=QRecord THEN SELF.FEQ{PROP:Selected}=X ; BREAK.
       END
    END
    DISPLAY
    RETURN
!EndRegion    
    