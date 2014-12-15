;****************************************************************
;                  === Celulární automat === 
;
;                      -- projekt IPA --
;
; - jednoduchá aplikace v assembleru
;
; - Drahoslav Bednář xbedna55
; - 2BIA zima 2014/15
;
; nasm -fobj ca.asm
; alink -oPE ca.obj
;
; ca.exe [-h] [-s] [-p] [-d WH]
;	-h show help
;	-s show stats
;	-p auto play
;	-d dimension (Height Width 0-9)
;		e.g.: -d 43 => (Width = 2^(2+4) ;Height = 2^(2+3)) => 64×32
;
;****************************************************************
bits 32
;****************************************************************
; Vložené soubory
%include 'win32.inc'
%include 'general.inc'
%include 'opengl.inc'
;****************************************************************
; Funkce z knihovny kernel32.dll
dllimport GetModuleHandle, kernel32.dll, GetModuleHandleW
dllimport GetCommandLine, kernel32.dll, GetCommandLineW
dllimport ExitProcess, kernel32.dll
dllimport GetProcessHeap, kernel32.dll;
dllimport HeapAlloc, kernel32.dll;
dllimport Sleep, kernel32.dll;
;dllimport SleepEx, kernel32.dll;
dllimport GetTickCount, kernel32.dll 
;****************************************************************
; Funkce z knihovny user32.dll 
dllimport ShowWindow, user32.dll
dllimport UpdateWindow, user32.dll
dllimport RedrawWindow, user32.dll
dllimport TranslateMessage, user32.dll
dllimport RegisterClassEx, user32.dll, RegisterClassExW
dllimport LoadIcon, user32.dll, LoadIconA
dllimport LoadCursor, user32.dll, LoadCursorW
dllimport SetCursor, user32.dll
dllimport CreateWindowEx, user32.dll, CreateWindowExW
dllimport GetMessage, user32.dll, GetMessageW
dllimport PeekMessage, user32.dll, PeekMessageW
dllimport DispatchMessage, user32.dll, DispatchMessageW
dllimport PostQuitMessage, user32.dll
dllimport MessageBox, user32.dll, MessageBoxA
dllimport DefWindowProc, user32.dll, DefWindowProcW
dllimport BringWindowToTop, user32.dll;
dllimport BeginPaint, user32.dll;
dllimport EndPaint, user32.dll;
dllimport DrawText, user32.dll, DrawTextW;
dllimport GetDC, user32.dll;;
dllimport ReleaseDC, user32.dll;;
dllimport SetWindowText, user32.dll, SetWindowTextW
;****************************************************************
; Funkce z knihovny Gdi32.dll
dllimport SetBkColor, gdi32.dll;
dllimport SwapBuffers, gdi32.dll;;
dllimport ChoosePixelFormat, gdi32.dll;;
dllimport SetPixelFormat, gdi32.dll;;
dllimport GetStockObject, gdi32.dll;;
;****************************************************************
; Funkce z knihovny Shell32.dll
dllimport CommandLineToArgv, Shell32.dll, CommandLineToArgvW;
; Funkce z knihovny Shlwapi.dll
dllimport StrCmp, Shlwapi.dll, StrCmpW;
dllimport StrCat, Shlwapi.dll, StrCatW;
; Funkce z knihovny glu32.dll 
; dllimport gluPerspective, glu32.dll
; dllimport gluOrtho2D, glu32.dll
;********************************************************-
; funkce z knihovny msvcrt.dll
dllimport swprintf, msvcrt.dll, swprintf_s

;*****************************************************
; makra

; uloží na zásobník 32b z st0 
%macro pushst0 0
	sub esp,4
	fst dword [esp];
%endmacro 

; uloží na zásobník 64b z paměti
%macro push64 1 
	sub esp,8                
	;movq xmm0,[%1]
	;movq [esp],xmm0

	;mov eax,[%1]					
	;mov [esp],eax
	;mov eax,[%1 + 4]
	;mov [esp + 4],eax

	fld qword [%1]
	fstp qword [esp]
%endmacro


%define f(x) __float32__(x)
%define d(x) __float64__(x)


;****************************************************************
; Datový segment
[section .data class=DATA use32]


;************
; KONSTANTY :

%define HEAP_ZERO_MEMORY 0x00000008


%define EOL `\r\n`
%define TAB `\t`

%assign Help_W 350 ; velikost help okna
%assign Help_H 300

%assign WIN_W 1024 ; velikost hlavního okna
%assign WIN_H 512

%assign MAP_W 128*2 ; výchozí šířka mapy (počet buňěk)
%assign MAP_H 64*2 ; výchozí výška mapy
%assign MAP_size MAP_W*MAP_H



;************
; konstanty :
f2_0: 		dd 2.0 ; dva = šířka a výška view portu
f_1_0:		dd -1.0 ; začátek view portu
_f64_1:		dq d(1.0) ; const 1.0
_f64__1:	dq d(-1.0) ; const -1.0


;***********
; proměnné :

argc			dd  0       ;
argv 			dd 	0       ;

hInstance		dd	0		; handle instance
hCursor			dd 	0 		; handle cursoru
hWnd			dd	0		; handle okna
hHelpWnd		dd 	0		; handle help okna
hStatWnd		dd	0		; handle okna statistik
hDC				dd	0		; handle kontextu zarizeni
hRC				dd	0		; handle kontextu zdroju
hStatDC 		dd  0 ; handle kontextu zarizeni Stat okna

dwWndWidth		dd	WIN_W	; sirka okna
dwWndHeight		dd	WIN_H	; vyska okna
dwHelpWndWidth	dd	Help_W	; sirka okna nápovědy
dwHelpWndHeight	dd	Help_H	; vyska okna nápovědy

map_w:		dd	MAP_W ; šířka mapy
map_h:		dd	MAP_H ; výška
map_size:	dd 	MAP_size ; velikost
map:		dd	NULL ; ukazatel na mapu buňěk
mapB:		dd 	NULL ; ukazatel na druhou mapu buňěk


cell_w: 	dd 0.0 ; výška bunky (0.0 - 2.0 fov)
cell_h: 	dd 0.0 ; šířka bunky


;gl view
w_left:		dq d(-1.0) 
w_right:	dq d(1.0)
w_top:		dq d(1.0)
w_bottom:	dq d(-1.0)


; aktuálně vybraná pravidla 
rule:
.S 	dw 	000000000_00001100b; to Survives => 3,2 
.B 	dw 	000000000_00001000b; to Birth => 3

dw 0


ruleList: ; konstantní seznam předdefinovaných  pravidel

R_life: ; 23/3 Clasický Conway's Game of Life
.S 	dw 000000000_00001100b ; 23
.B 	dw 000000000_00001000b ; 3
R_life34: ; 34/34
.S 	dw 000000000_00011000b ; 34
.B 	dw 000000000_00011000b ; 34
R_seeds: ; /2
.S 	dw 000000000_00000000b ; nic
.B 	dw 000000000_00000100b ; 2
R_amoeba: ; 1358/357
.S 	dw 000000001_00101010b ; 1358
.B 	dw 000000000_10101000b ; 357
R_coagulation: ; 235678/378
.S 	dw 000000001_11101100b ; 235678
.B 	dw 000000001_10001000b ; 378
R_maze: ; 12345/3
.S 	dw 000000000_00111110b ; 12345
.B 	dw 000000000_00001000b ; 3
R_flakes: ; 012345678/3
.S 	dw 000000001_11111111b ; 012345678
.B 	dw 000000000_00001000b ; 3
R_coral: ; 45678/3
.S 	dw 000000001_11110000b ; 45678
.B 	dw 000000000_00001000b ; 3
R_walledCities: ; 2345/45678
.S 	dw 000000001_00111100b ; 2345
.B 	dw 000000001_11110000b ; 45678
R_replicator: ; 1357/1357
.S 	dw 000000000_10101010b ; 1357
.B 	dw 000000000_10101010b ; 1357
R_longLIfe: ; 5/345
.S 	dw 000000000_00100000b ; 5
.B 	dw 000000000_00111000b ; 345

ruleList_end:
%define RULE_LIST_SIZE ((ruleList_end-ruleList)>>2)

ruleIndex: 		dd 0 ; index aktuálního pravidla
shapeIndex:		dd 0 ; index na aktuální tvar

statShowed	dd 0; 
play: 		dd 0; stav play/pause ~0/0
speed:		dd 1; rychlost vývoje

time: 		dd 0 ; pro měření času mezi redrawStat

debug:		dd 0 ; todo delete
mouse_x:	dd 0
mouse_y:	dd 0


generation: dd 0; počítadlo generací
population: dd 0; počítadlo popoulace

; stringy
stringw swzWndClassName, "Main Window";
stringw swzSideWndClassName, "Side Window ";
stringw swzWndCaption, "CA "; titulek hlavního okna
stringw swzHelpWndCaption, "Help" ; titulek okna nápovědy
stringw swzStatWndCaption, "Stats" ; titulek okna statistik
stringw swzHelpText,\
	"[F1]",TAB,"- show help",EOL,\
	"[F2]",TAB,"- show stats",EOL,\
	"[esc]",TAB,"- close help / stats",EOL,\
	"[space]",TAB,"- play / pause",EOL,\
 	"[O]",TAB,"- speed up",EOL,\
 	"[L]",TAB,"- slow down",EOL,\
 	"[J]",TAB,"- Jump to next gen",EOL,\
 	"[K]",TAB,"- back",EOL,\
 	"[U] / [I]",TAB,"- change rules",EOL,\
 	"[C]",TAB,"- Clear",EOL,\
 	"[R]",TAB,"- Restart",EOL,\
 	"[Q]",TAB,"- Quit program",EOL,\
 	""
; přepínače příkazové řádky
stringw swzArgHelp, '-h' ; zobrazit okneo nápovědy
stringw swzArgStat, '-s' ; zobrazit okno statistik
stringw swzArgPlay, '-p' ; rovnou do stavu play
stringw swzArgDims, '-d' ; nastavení rozměru -d 32


winTitle:
times 40 dw 0 ; místo pro popisek hlavního okna

; komponenty popisku okna
stringw swzPlayChar, '► '
stringw swzStopChar, '￭ '
stringw swzSpeedChar, '▹'
stringw swzSpace, '  '


statsText:
times 400 dw '!' ; místo pro text okna statistik 
SIZEOF_statsText EQU ($ - statsText)

; sprintf format textu okna statistik
stringw swzStatForm,\
	"rule",TAB,"%02u",EOL,\
	"generation:",TAB,"%06u",EOL,\
	"population:",TAB,"%06u",EOL,\
	"win width:",TAB,"%u",EOL,\
	"win height:",TAB,"%u",EOL,\
	"map width:",TAB,"%u",EOL,\
	"map height:",TAB,"%u",EOL,\
	"x:",TAB,"%04u",EOL,\
	"y:",TAB,"%04u",EOL,\
	"test:",TAB,"%08X",EOL,\
	""



;numero:
;times 11 dw 0 ; místo pro převádění 32b čísla na string

; struktury

Message:	resb MSG_size

HelpPS:		resb PAINTSTRUCT_size	; pro vykreslení textu nápovědy
StatPS:		resb PAINTSTRUCT_size	; pro vykreslení textu nápovědy

HelpRect:	; definice velikosti rámce pro text nápovědy
	istruc RECT
		at RECT.left,	dd 6
		at RECT.top,	dd 5
		at RECT.right,	dd Help_W-5
		at RECT.bottom,	dd Help_H-5
	iend

StatRect:	; definice velikosti rámce pro text nápovědy
	istruc RECT
		at RECT.left,	dd 6
		at RECT.top,	dd 5
		at RECT.right,	dd Help_W-5
		at RECT.bottom,	dd Help_H-5
	iend

WndClass:
	istruc WNDCLASSEX
	    at WNDCLASSEX.cbSize,          dd  WNDCLASSEX_size
	    at WNDCLASSEX.style,           dd  CS_VREDRAW + CS_HREDRAW + CS_OWNDC
	    at WNDCLASSEX.lpfnWndProc,     dd  WndProc
	    at WNDCLASSEX.cbClsExtra,      dd  0
	    at WNDCLASSEX.cbWndExtra,      dd  0
	    at WNDCLASSEX.hInstance,       dd  NULL
	    at WNDCLASSEX.hIcon,           dd  NULL
	    at WNDCLASSEX.hCursor,         dd  NULL
	    at WNDCLASSEX.hbrBackground,   dd  NULL
	    at WNDCLASSEX.lpszMenuName,    dd  NULL
	    at WNDCLASSEX.lpszClassName,   dd  swzWndClassName
	    at WNDCLASSEX.hIconSm,         dd  NULL
	iend

SideWndClass:
	istruc WNDCLASSEX
	    at WNDCLASSEX.cbSize,          dd  WNDCLASSEX_size
	    at WNDCLASSEX.style,           dd  CS_VREDRAW + CS_HREDRAW; + CS_OWNDC
	    at WNDCLASSEX.lpfnWndProc,     dd  SideWndProc
	    at WNDCLASSEX.cbClsExtra,      dd  0
	    at WNDCLASSEX.cbWndExtra,      dd  0
	    at WNDCLASSEX.hInstance,       dd  NULL
	    at WNDCLASSEX.hIcon,           dd  NULL
	    at WNDCLASSEX.hCursor,         dd  NULL
	    at WNDCLASSEX.hbrBackground,   dd  NULL
	    at WNDCLASSEX.lpszMenuName,    dd  NULL
	    at WNDCLASSEX.lpszClassName,   dd  swzSideWndClassName
	    at WNDCLASSEX.hIconSm,         dd  NULL
	iend


PixelFormatDescriptor:
	istruc PIXELFORMATDESCRIPTOR
		at PIXELFORMATDESCRIPTOR.nSize,				dw	PIXELFORMATDESCRIPTOR_size
		at PIXELFORMATDESCRIPTOR.nVersion,			dw	1
		at PIXELFORMATDESCRIPTOR.dwFlags,			dd	PFD_DOUBLEBUFFER + PFD_DRAW_TO_WINDOW + PFD_SUPPORT_OPENGL
		at PIXELFORMATDESCRIPTOR.iPixelType,		db	PFD_TYPE_RGBA
		at PIXELFORMATDESCRIPTOR.cColorBits,		db	24 
  		at PIXELFORMATDESCRIPTOR.cRedBits,			db	0 
  		at PIXELFORMATDESCRIPTOR.cRedShift,			db	0 
  		at PIXELFORMATDESCRIPTOR.cGreenBits,		db	0 
  		at PIXELFORMATDESCRIPTOR.cGreenShift,		db	0 
  		at PIXELFORMATDESCRIPTOR.cBlueBits,			db	0 
  		at PIXELFORMATDESCRIPTOR.cBlueShift,		db	0 
  		at PIXELFORMATDESCRIPTOR.cAlphaBits,		db	0 
  		at PIXELFORMATDESCRIPTOR.cAlphaShift,		db	0 
  		at PIXELFORMATDESCRIPTOR.cAccumBits,		db	0 
  		at PIXELFORMATDESCRIPTOR.cAccumRedBits,		db	0 
  		at PIXELFORMATDESCRIPTOR.cAccumGreenBits,	db	0 
  		at PIXELFORMATDESCRIPTOR.cAccumBlueBits,	db	0 
  		at PIXELFORMATDESCRIPTOR.cAccumAlphaBits,	db	0 
  		at PIXELFORMATDESCRIPTOR.cDepthBits,		db	32 
  		at PIXELFORMATDESCRIPTOR.cStencilBits,		db	0 
  		at PIXELFORMATDESCRIPTOR.cAuxBuffers,		db	0 
  		at PIXELFORMATDESCRIPTOR.iLayerType,		db	PFD_MAIN_PLANE 
  		at PIXELFORMATDESCRIPTOR.bReserved,			db	0 
  		at PIXELFORMATDESCRIPTOR.dwLayerMask,		dd	0 
  		at PIXELFORMATDESCRIPTOR.dwVisibleMask,		dd	0
  		at PIXELFORMATDESCRIPTOR.dwDamageMask,		dd	0
	iend



;****************************************************************
; Kódový segment
[section .code class=CODE use32]



;*************************;
;  ===  ENTER POINT  ===  ;
..start:
;*******************
; příprava oken atd.


	invoke GetModuleHandle,NULL ; získání hInstance
	mov [hInstance],eax
	mov [WndClass + WNDCLASSEX.hInstance],eax
	mov [SideWndClass + WNDCLASSEX.hInstance],eax

	invoke LoadCursor,NULL,IDC_ARROW ; získání hCursoru
	mov [hCursor],eax
	mov [WndClass + WNDCLASSEX.hCursor],eax
	mov [SideWndClass + WNDCLASSEX.hCursor],eax

	invoke LoadIcon,NULL,IDI_APPLICATION ; získání hIkonky hlavního okna
	mov [WndClass + WNDCLASSEX.hIcon],eax

	invoke LoadIcon,NULL,IDI_QUESTION ; získání hIkonky pro vedlejší okno
	mov [SideWndClass + WNDCLASSEX.hIcon],eax



	;**************
	; side okna
	invoke RegisterClassEx,SideWndClass ; registrace třídy okna
	;***********
	; Help okno
	test eax,eax
	jz near .Finish
	; vytvoření okna nápovědy
	invoke CreateWindowEx, \
		0, \
		swzSideWndClassName, \
		swzHelpWndCaption, \
		WS_CAPTION + WS_SYSMENU,\
		CW_USEDEFAULT, CW_USEDEFAULT, \
		Help_W, Help_H, \
		NULL, NULL, \
		[hInstance], NULL
	test eax,eax 
	jz near .Finish
	mov [hHelpWnd],eax
	; (zatím se nezobrazuje)

	;***********
	; Stats okno
	test eax,eax
	jz near .Finish
	; vytvoření okna statistik
	invoke CreateWindowEx, \
		0, \
		swzSideWndClassName, \
		swzStatWndCaption, \
		WS_CAPTION + WS_SYSMENU,\
		CW_USEDEFAULT, CW_USEDEFAULT, \
		Help_W, Help_H, \
		NULL, NULL, \
		[hInstance], NULL
	test eax,eax 
	jz near .Finish
	mov [hStatWnd],eax
	; (zatím se nezobrazuje)


	call HandleArgs ; zpracování argumentů - zobrazuje side okna, ale je potřeba pro rozměry pro main okno => nutno volat tady

	; výpočet velikosti okna podle poměru stran mapy
	;if(map_w > map_h){
	; wndW = wndWdef;	
	; wndH = wndW*map_h/map_w		
	;} else {
	; wndH = wndHdef;	
	; wndW = wndH*map_w/map_h
	;}
	mov ebx, [map_w]
	mov ecx, [map_h]
	cmp ebx, ecx
	jng .else
		mov eax, [dwWndWidth]
		mul ecx
		div ebx
		mov [dwWndHeight], eax
		jmp .fi
	.else:
		mov eax, [dwWndHeight]
		mul ebx
		div ecx
		mov [dwWndWidth], eax
		jmp .fi
	.fi:
	; pořešit orámování
	add [dwWndWidth], dword 8
	add [dwWndHeight], dword 31




	;***********
	; main okno
	invoke RegisterClassEx,WndClass ; registrace třídy okna
	test eax,eax
	jz near .Finish
	; vytvoření okna
	invoke CreateWindowEx, \
		0, \
		swzWndClassName, \
		swzWndCaption, \
		WS_TILEDWINDOW,\
		CW_USEDEFAULT, CW_USEDEFAULT, \
		[dwWndWidth], [dwWndHeight], \
		NULL, NULL, \
		[hInstance], NULL
	test eax,eax 
	jz near .Finish

	mov [hWnd],eax
	invoke ShowWindow,eax,SW_SHOWDEFAULT ; zobrazit
	invoke UpdateWindow,[hWnd] ; překleslit

;****************


	; spepočítáme velikost bunky, na základě velikosti mapy
	;cell_w = 2.0/map_w
	fld dword [f2_0];
	fidiv dword [map_w];
	fstp dword [cell_w];
	;cell_h = 2.0/map_h
	fld dword [f2_0];
	fidiv dword [map_h];
	fstp dword [cell_h];

;***************************
; alokace paměti pro bitmapy

	;spočítat velikost mapy
	mov eax,[map_w]
	mul dword [map_h]
	mov [map_size], eax;

	; alokace hlavní mapy:
	invoke GetProcessHeap
	test eax,eax
	jz near .Finish
	invoke HeapAlloc,eax, HEAP_ZERO_MEMORY, [map_size]
	cmp eax,NULL
	je near .Finish
	mov [map],eax

	; alokace druhé  mapy
	invoke GetProcessHeap
	test eax,eax
	jz near .Finish
	invoke HeapAlloc,eax, HEAP_ZERO_MEMORY, [map_size]
	cmp eax,NULL
	je near .Finish
	mov [mapB],eax



	call InitMap ;

	call InitGL ;


;***********************
; klasická smyčka zpráv
.MessageLoop:

	invoke GetMessage,Message,NULL,0,0 ; načtení zprávy
	test eax,eax ; 0 => Message je WM_QUIT
	jz near .Finish
	cmp eax,-1 ; chyba
	je near .Finish

	invoke TranslateMessage,Message ; překlad virtuálních kláves
	invoke DispatchMessage,Message ; poslání zprávy obslužné fci
	
	call Tik

	jmp .MessageLoop


;************************;
;  ===  EXIT POINT  ===  ;
.Finish:
	invoke ExitProcess,[Message + MSG.wParam] ; ukonceni procesu
	ret


;*******************************************************************************;
;                   			===  FUNKCE  ===								;
;																				;
;*******************************************************************************;

;************************
; Hlavní logika aplikace
function Tik
begin

	cmp [play], dword 0 ; je ve stavu play?
	je near .noop ; pokud ne nic nedělat

	cmp [speed], dword 0 ; velmi pomalá rychlost?
	jne near .notveryslow
		invoke Sleep, dword 300 ; velmi pomalé => ~3fps
		jmp near .notfast
	.notveryslow:

	cmp [speed], dword 1 ; pomalá rychlost?
	jne near .notslow
		invoke Sleep, dword 100 ; pomalé => ~10fps
		jmp near .notfast
	.notslow:

	cmp [speed], dword 2 ; větší rychlost?
	jne near .notfast
		invoke Sleep, dword 15 ; rychlejší => ~60fps

	.notfast:
	; => superfast, bez čekání

	call near Evolve ; nová generace

	; překreslit jen pokud uběhlo víc jak ?? ms od posledního překereslení
	invoke GetTickCount
	mov ebx, [time]
	add ebx, 50
	cmp eax, ebx
	jng .Finish

	mov [time], eax 

	call near DrawMap ; vykreslit

	cmp [statShowed], dword 1
	jne .Finish

	call near RedrawStatWin

	jmp .Finish

.noop:

	invoke Sleep, dword 10 ; předat cpu systému

	;jmp .Finish

.Finish:

	return

end


;***********************************;
; -- obsluha zpráv hlavního okna -- ;
function WndProc, hWnd,wMsg,wParam,lParam
begin
	mov eax,dword [wMsg] ; zpráva //  http://msdn.microsoft.com/en-us/library/windows/desktop/ms644927(v=vs.85).aspx#system_defined
	cmp eax,WM_DESTROY
	je near .Destroy
	cmp eax,WM_CLOSE
	je near .Destroy
	cmp eax,WM_PAINT 		; PAINT = okno potřebuje překreslit
	je near .Redraw
	cmp eax,WM_KEYDOWN
	je near .Keydown
	cmp eax,WM_MOUSEMOVE 
	je near .Redraw
	cmp eax,WM_CREATE		; CREATE = bylo vytvoreno naše okno
	je near .Create
	cmp eax,WM_SIZE			; SIZE = velikost okna byla zmenena
	je near .Resize
	cmp eax,WM_LBUTTONDOWN 
	je near .LClick

	invoke DefWindowProc,[hWnd],[wMsg],[wParam],[lParam] ; default - všechny ostatní spadnou sem
	return eax

.Create:
	call reTitle
	invoke GetDC,[hWnd]				; zjistíme kontext zarízení našeho okna
	mov [hDC],eax					; a uložíme ho do promìnné hDC
	invoke ChoosePixelFormat,eax,PixelFormatDescriptor		; nastavíme formát
	invoke SetPixelFormat,[hDC],eax,PixelFormatDescriptor	; pixelu
	invoke wglCreateContext,[hDC]	; vytvoríme kontext OpenGL a uložíme ho
	mov [hRC],eax					; do promìnné hRC
	invoke wglMakeCurrent,[hDC],eax	; vytvorený kontext aktivujeme
	call InitGL						; zavoláme naši funkci pro inicializaci OpenGL
	jmp near .Redraw						; konec obsluhy zprávy


.Resize:
	mov eax,[lParam]				; lParam obsahuje novou výšku a šírku, uložíme
	shr eax,16						; hodnotu do EAX, posuneme o 16 bitu do prava
	mov [dwWndHeight],eax			; a vysledek (nova vyska okna) uložíme do
	push eax						; promenne dwWndHeight a na zasobnik (budeme
	mov eax,[lParam]				; ji predávat funkci glViewport), opet ulozime 	
	and eax,0x0000FFFF				; hodnotu do EAX a vymaskujeme dolní cást hodnoty,	
	mov [dwWndWidth],eax			; získáme tak sirku okna, a uložíme ji do promenné	
	push eax						; dwWndWidth a na zasobnik 
	call near InitGL						; nyní znovu inicializujeme OpenGL (kvuli zmene
	invoke glViewport, 0, 0			; pomeru stran) a zavolame glViewport jen se dvema


	;mov eax, [generation]
	;cmp eax, 100
	;jng near .Finish
	;invoke PostQuitMessage,0		; pošleme príkaz k ukoncení aplikace

	jmp near .Finish						; parametry, poslední dva uz jsou na zasobniku

.Redraw:
	call DrawMap
	jmp near .Finish


.Destroy:
	invoke wglMakeCurrent,NULL,NULL	; nejdríve se zbavíme všeho, co se
	invoke wglDeleteContext,[hRC]	; týká OpenGL (grafického kontextu)
	invoke ReleaseDC,[hWnd],[hDC]	; uvolníme grafické prostredky
	invoke PostQuitMessage,0		; pošleme príkaz k ukoncení aplikace
	return 0

.LClick:

	; y
	mov eax, dword [lParam]
	shr eax, 16
	push eax
	; x
	mov eax, dword [lParam] 
	and eax, 0x0000FFFF;
	push eax

	call near Click
	jmp near .Finish

.Keydown:
	mov eax, dword [wParam]; virtual key code // http://msdn.microsoft.com/en-us/library/windows/desktop/dd375731(v=vs.85).aspx
	
	cmp eax,0x51 ; Q key - vypnout
	je near .Destroy ; 
	cmp eax,VK_F1	
	je near .ShowHelp ; F1 - zobrazit nápovědu
	cmp eax,VK_F2
	je near .ShowStat ; F2 - zobrazit statistiky
	cmp eax,VK_SPACE
	je near .Play
	cmp eax,0x4A ; J key
	je near .Evolve
	cmp eax,0x4B ; K key
	je near .Undo
	cmp eax,0x52 ; R key
	je near .Reset
	cmp eax,0x43 ; C key
	je near .Clear
	cmp eax,VK_UP ; up 
	je near .SpeedUp
	cmp eax,VK_DOWN ; down 
	je near .SlowDown
	cmp eax, 0x4F ; O key
	je near .SpeedUp
	cmp eax, 0x4C ; L key
	je near .SlowDown
	cmp eax,0x55 ; U key
	je near .NextRule
	cmp eax,0x49 ; I key
	je near .PrevRule

	cmp eax,VK_NUMPAD0 
	je near .Shape0
	cmp eax,VK_NUMPAD1
	je near .Shape1
	cmp eax,VK_NUMPAD2
	je near .Shape2
	cmp eax,VK_NUMPAD3
	je near .Shape3

	jmp near .Finish

.ShowHelp:
	call ShowWin, [hHelpWnd]
	jmp near .Finish
.ShowStat:
	call ShowWin, [hStatWnd]
	jmp near .Finish


.Clear: ; zabije všechny živé buňky
	mov [population], dword 0 
	call WipeMap
	call DrawMap
	jmp near .Finish

.Reset: ; vrátí do stavu po startu programu
	mov [generation], dword 0
	mov [population], dword 0 
	call WipeMap
	call InitMap
	call near RedrawStatWin
	call DrawMap
	jmp near .Finish

.Play: ; přepíná stav play/pause
	not dword [play];
	call reTitle
	jmp near .Finish

.SpeedUp: ; nastaví vyšší ryychlost, pokud není nejvyšší
	cmp [speed], dword 3 ; 3 = nejvyšší rychlost (0-3)
	je near .Finish
	inc dword [speed]
	call reTitle
	jmp near .Finish

.SlowDown: ; nastaví nižší rychlost, pokud není nejnižší
	cmp [speed], dword 0
	je near .Finish
	dec dword [speed]
	call reTitle
	jmp near .Finish

.Evolve: ; další generace (jen pokud není ve stavu play)
	cmp [play], dword 0 
	jne .Finish
	call Evolve 
	call near RedrawStatWin
	call DrawMap
	jmp near .Finish

.Undo: ; vrátí 1 krok zpět (jen pokud není ve stavu play)
	cmp [play], dword 0
	jne .Finish
	call SwapMap
	call DrawMap
	;dec dword [generation] ; blbost
	call near countPopulation
	call near RedrawStatWin
	jmp near .Finish

.NextRule:
	cmp dword [ruleIndex], RULE_LIST_SIZE-1
	jne .notLastR
	sub dword [ruleIndex], RULE_LIST_SIZE
	.notLastR:
	inc dword [ruleIndex]
	jmp .SelectRule

.PrevRule:
	cmp dword [ruleIndex],0
	jne .notFirstR
	add dword [ruleIndex], RULE_LIST_SIZE
	.notFirstR:
	dec dword [ruleIndex]
	jmp .SelectRule
	
.Shape0:
	mov [shapeIndex], dword 0;
	jmp near .SelectShape
.Shape1:
	mov [shapeIndex], dword 1;
	jmp near .SelectShape
.Shape2:
	mov [shapeIndex], dword 2;
	jmp near .SelectShape
.Shape3:
	mov [shapeIndex], dword 3
	jmp near .SelectShape
.Shape4:
	mov [shapeIndex], dword 4
	jmp near .SelectShape
.Shape5:
	mov [shapeIndex], dword 5
	jmp near .SelectShape
.Shape6:
	mov [shapeIndex], dword 6;
	jmp near .SelectShape
.Shape7:
	mov [shapeIndex], dword 7;
	jmp near .SelectShape
.Shape8:
	mov [shapeIndex], dword 8;
	jmp near .SelectShape
.Shape9:
	mov [shapeIndex], dword 9
	jmp near .SelectShape
.Shape10:
	mov [shapeIndex], dword 10
	jmp near .SelectShape
.Shape11:
	mov [shapeIndex], dword 11
	jmp near .SelectShape

.SelectShape:
	; TODO
	jmp near .Finish

.SelectRule:
	mov eax, [ruleIndex]
	shl eax, 2; ×4 ..  eax je ukazatel na dword
	add eax, dword ruleList
	mov eax, [eax] ; v eax jsou obě pravidla
	mov  [rule], eax;
	call near reTitle
	call near RedrawStatWin
	jmp  near .Finish

.Finish:
	return 0

end ; WndProc


;**************************************************************;
; -- obsluha zpráv pro vedlejší okna (nápověda, statistiky) -- ;
function SideWndProc, hWnd_s, wMsg_s, wParam_s, lParam_s
begin
	mov eax,dword [wMsg_s] ; zpráva //  http://msdn.microsoft.com/en-us/library/windows/desktop/ms644927(v=vs.85).aspx#system_defined
	cmp eax,WM_DESTROY
	je near .Hide
	cmp eax,WM_CLOSE
	je near .Hide
	cmp eax,WM_KEYDOWN
	je near .Keydown
	cmp eax,WM_PAINT 
	je near .Redraw
	cmp eax,WM_CREATE
	je near .Create
	
	invoke DefWindowProc, [hWnd_s],[wMsg_s],[wParam_s],[lParam_s] ; default - všechny ostatní spadnou sem
	return eax

.Create:
	mov eax, [hWnd_s]
	cmp eax, [hStatWnd]
	je .Finish
	invoke GetDC,[hStatWnd]				; zjistíme kontext zarízení našeho okna
	mov [hStatDC],eax

.Redraw:
	mov eax, [hStatWnd]
	cmp eax, [hWnd]
	je .redrawStat
.redrawHelp:
	invoke BeginPaint, [hWnd_s],HelpPS ; returning HDC
	cmp eax,NULL ; chyba
	je near .Finish
	invoke DrawText, eax,swzHelpText,-1,HelpRect,\
		DT_LEFT | DT_EXTERNALLEADING | DT_WORDBREAK | DT_EXPANDTABS; vypsat text nápovědy
	invoke EndPaint, [hWnd_s],HelpPS
	jmp near .Finish
.redrawStat:
	call RedrawStatWin
	jmp near .Finish



.Keydown:
	mov eax, dword [wParam_s]; virtual key code // http://msdn.microsoft.com/en-us/library/windows/desktop/dd375731(v=vs.85).aspx
	
	cmp eax, dword VK_ESCAPE 
	je near .Hide ; escapem skrýt okno
	cmp eax, dword VK_F1
	je near WndProc.ShowHelp
	cmp eax, dword VK_F2
	je near WndProc.ShowStat

	jmp near .Finish

.Hide:
	call near HideWin, [hWnd_s] ; skrýt okno
	jmp near .Finish

.Finish:

	return 0

end ; SideWndProc




;*********************************************************
; Zobrazí okno  a přenese ho do popředí
function ShowWin, WndHandler_s
begin

	invoke ShowWindow, [WndHandler_s],SW_SHOW ; zobrazit
	invoke UpdateWindow, [WndHandler_s] ; překleslit
	invoke BringWindowToTop, [WndHandler_s] ; přenést do popředí

	mov eax, [WndHandler_s]
	cmp eax, [hStatWnd]
	jne .Finish
	mov [statShowed], dword 1

	.Finish:
	return
end


;*********************************************************
; Skryje okno
function HideWin, WndHandler_h
begin

	invoke ShowWindow, [WndHandler_h],SW_HIDE ; zobrazit
	
	mov eax, [WndHandler_h]
	cmp eax, [hStatWnd]
	jne .Finish
	mov [statShowed], dword 0

	.Finish:
	return
end

;*****************************************************
; aktualizuje a překreslí okno statistik
function RedrawStatWin
begin
	call near composeStatsText
	invoke GetDC, [hStatWnd]
	push eax
	invoke DrawText, eax,statsText,-1,StatRect,\
		DT_LEFT | DT_EXTERNALLEADING | DT_WORDBREAK | DT_EXPANDTABS; vypsat text nápovědy
	pop eax
	invoke ReleaseDC, [hStatWnd], eax
	.Finish:
	return
end


;*********************************************************
; zpracuje argumenty příkazové řádky
; pokud najde přepínač '-h' zobrazí nápovědu
;
; TODO custom map_w map_h
function HandleArgs
var ch01
begin
	push edx ; zaloha

	invoke GetCommandLine
	invoke CommandLineToArgv,eax,argc
	cmp eax,NULL ; chyba
	je .Finish
	cmp [argc], dword 0 ; chyba
	je .Finish

	mov [argv],eax ; uložení získaného argv
	mov edx,eax ; pomocí edx se bude cyklit

	times 4 add edx,[argc]	; posun za poslední ukazatel

.while: ; projít všechny args zprava
	sub edx,4 ; o jedno doleva
	cmp edx,[argv] ; pokud jsme moc vlevo (na argv[0]) ukončit 
	je .Finish

	mov eax, dword [edx] ; ukazatel na wide string
	mov eax, dword [eax] ; přesun dvou znaků do eax

	cmp eax, dword [swzArgHelp] ; hledat shodnost s "-h"
	jne .notShowHelp
		push edx
		call near ShowWin, [hHelpWnd];
		pop edx
	.notShowHelp:

	cmp eax, dword [swzArgStat] ; hledat shodnost s "-s"
	jne .notShowStat
		push edx
		call near ShowWin, [hStatWnd]
		pop edx
	.notShowStat:

	cmp eax, dword [swzArgPlay] ; hledat shodnost s "-p"
	jne .notPlay
		push edx
		not dword [play]
		pop edx
	.notPlay:

	push edx
	cmp eax, dword [swzArgDims] ; hledat shodnost s "-d"
	jne .notDims

	mov eax, [ch01]

		cmp [ch01], word 0x0030
		jnge .notDims
		cmp [ch01], word 0x0039
		jnle .notDims
		cmp [ch01+2], word 0x0030
		jnge .notDims
		cmp [ch01+2], word 0x0039
		jnle .notDims

		xor ecx, ecx
		mov cx, word [ch01]
		sub cx, word 0x0030
		add cx, word 2 ;
		mov ebx, 1
		.loop1:
			shl ebx, 1
			loop .loop1
		mov [map_w], ebx

		xor ecx, ecx
		mov cx, word [ch01+2]
		sub cx, word 0x0030
		add cx, word 2 ; 
		mov ebx, 1
		.loop2:
			shl ebx, 1
			loop .loop2
		mov [map_h], ebx
	.notDims:
	pop edx

	;načíst první dva znaky do pomocné proměnné 
	mov eax, [edx]
	mov bx, word [eax] ; první wchar
	cmp bx, 0
	je .while
	mov [ch01], bx
	add eax, 2 
	mov bx, word [eax] ; druhý wchar
	cmp bx, 0
	je .while
	mov [ch01+2], bx


	jmp .while


.Finish:
	pop edx ; obnova
	return 0

end ; HandleArgs



;******************
; naství buňku v mapě na daných souřadnicích na 1
function SetCell,sx,sy
begin
	
	;eax = map + y*map_w + x
	mov eax, [map_w]
	mul dword [sy]
	add eax, [sx]
	add eax, [map]

	mov [eax], byte 1;
	add [population], dword 1 

	return
end


;*************************************************************
; nastaví bity (vytvoří prvotní buňky) v mapě
function InitMap
begin 
	push ecx
	push edx

%if 1
	; spinner
	call SetCell, 12,2
	call SetCell, 12,3
	call SetCell, 12,4

	; glider ->
	call SetCell, 1,2
	call SetCell, 2,2
	call SetCell, 3,2
	call SetCell, 3,3
	call SetCell, 2,4

	; glider <-
	call SetCell, 21,2
	call SetCell, 22,2
	call SetCell, 23,2
	call SetCell, 21,1
	call SetCell, 22,0

	; rabbits
	call SetCell, 201, 100
	call SetCell, 200, 101
	call SetCell, 201, 101
	call SetCell, 202, 101
	call SetCell, 205, 101
	call SetCell, 200, 102
	call SetCell, 204, 102
	call SetCell, 205, 102
	call SetCell, 206, 102

%endif

%if 0

	mov eax, [map] ; ukazatel na konkretni buňku
; řádky
	mov edx,0 ; y
.fory:
	cmp edx,[map_h]
	je .breaky

	;sloupce
		mov ecx,0  ; x
	.forx:
		cmp ecx,[map_w]
		je .breakx
			; eax tec ukazuje na konkretni bunku

			; if(x>10 && x<15 && y>12 && y<30)
			cmp ecx, 10
			jnge .continuex
			cmp ecx, 20
			jnl .continuex
			cmp edx, 10
			jnge .continuex
			cmp edx, 20
			jnl .continuex

			mov [eax], byte 1 ; zrození buňky
			add [population], dword 1;
			;; 
	.continuex:
		inc eax
		inc ecx
		jmp .forx
	.breakx:

.continuey:
	inc edx
	jmp .fory
.breaky:

%endif
	
	pop edx
	pop ecx

	return
end ; InitMap



;********************************************************************
;
function InitGL
begin

  
	invoke glMatrixMode,GL_PROJECTION	; nastavíme matici projekce
	invoke glLoadIdentity				; nahrajeme identitu

; // celá fce dělá následující:
;
;aspect =  (dwWndWidth * map_h) / (dwWndHeight * map_w);
;
;if (aspect > 1) {
;	glOrtho(-1.0 * aspect, 1.0 * aspect, -1.0, 1.0, 1.0, -1.0);
;
;} else {
;	glOrtho(-1.0, 1.0, -1.0 / aspect, 1.0 / aspect, 1.0, -1.0);
;} 

	finit

	fild dword [dwWndHeight] ; st0 = dwWndHeight
	fimul dword [map_w] ; st0 = dwWndHeight * map_w
	;
	fild dword [dwWndWidth] ; st0 = dwWndWidth
	fimul dword [map_h] ; st0 = dwWndWidth * map_h


	fdivp st1, st0 ; st0 = aspect = st0/st1 = (dwWndWidth*map_h)/(dwWndHeight*map_w)
	;fld1 ;
	; if(aspect > 1):
	fld qword [_f64_1] 
	fxch ; st0 = aspect ; st1 = 1.0
	fcom ; aspect > 1.0
	fstsw ax          ;copy the Status Word containing the result to AX
	fwait             ;insure the previous instruction is completed
	sahf              ;transfer the condition codes to the CPU's flag register
	;jpe .Finish ;the comparison was indeterminate

ja .else

	;fld1
	;fchs
	fld qword [_f64__1] 
	fst qword [w_bottom]
	fdiv st0,st1 ; st0 = -1.0 / aspect
	fstp qword [w_left]

	;fld1
	fld qword [_f64_1] 
	fst qword [w_top]
	fdiv st0,st1 ; st0 = 1.0 / aspect
	fstp qword [w_right]

jmp .fi
.else:

	;fld1
	;fchs
	fld qword [_f64__1] 
	fst qword [w_left]
	fmul st0,st1 ; -1.0 * aspect 
	fstp qword [w_bottom]

	;fld1
	fld qword [_f64_1] 
	fst qword [w_right]
	fmul st0,st1 ; 1.0 * aspect
	fstp qword [w_top]


.fi:

	fstp st0
	fstp st0


	.notfail:

	%if 1 ; zachovat poměr stran

	push64 _f64__1 ;pro 2D vždy -1
	push64 _f64_1  ;pro 2D vždy 1
	push64 w_top  ; ^ +1.0
	push64 w_bottom ; ˘ -1.0
	push64 w_right  ;    |-->  +1.0
	push64 w_left ; <--|     -1.0

	%else ; deformovat

	push64 _f64__1 ;pro 2D vždy -1
	push64 _f64_1  ;pro 2D vždy 1
	push64 _f64__1 ; ˘ -1.0
	push64 _f64_1  ; ^ +1.0
	push64 _f64_1  ;    |-->  +1.0
	push64 _f64__1 ; <--|     -1.0

	%endif

	invoke glOrtho; 


	return
end ; InitGL



;******************************-
; Vykreslí mapu podle bajtů v mapě na adrese [map]
function DrawMap
begin 
	
	cmp dword [map],NULL
	je near .Finish

	push ebx ; zaloha
	push ecx

	invoke glMatrixMode,GL_MODELVIEW
    invoke glLoadIdentity

	invoke glClearColor,f(0.5),f(0.6),f(0.7),f(1.0) ; divně modrá na pozadí
	invoke glClear, GL_COLOR_BUFFER_BIT ;| GL_DEPTH_BUFFER_BIT; | GL_ACCUM_BUFFER_BIT

	invoke glBegin,GL_QUADS ; budou se vykreslovat čtverečky
	invoke glColor3b,10,10,10	; tmavě šedé čtverečky


	mov edx, [map_w]
	mov eax, [map]; ukazatel na buňku
; řádky
	mov ebx,0 ; y souřadnice buňky
.fory:
	cmp ebx, dword [map_h]
	je .breaky

	;sloupce
		mov ecx,0  ; x souřadnice buňky
	.forx:
		cmp ecx, [map_w]
		je .breakx
			; eax ted ukazuje na bunku

			cmp byte [eax], 0 ; cell is dead?
			je .continuex
			call DrawCell, ecx, ebx
		
			;; 
	.continuex:
		inc eax
		inc ecx
		jmp .forx
	.breakx:

.continuey:
	inc ebx
	jmp .fory
.breaky:
	

	invoke glEnd

	invoke SwapBuffers, [hDC]

	pop ecx
	pop ebx ; obnova

	.Finish:

	return
end ; DrawMap


;*******************************************************-
; Vykreslí jeden čtvereček na souřadnicích x,y
; param x: int32 0 <= x < map_w
; param y: int32 0 <= y < map_h
function DrawCell,x,y ; 
begin

	push eax
	;push ebx
	push ecx

; TODO uložit  cell_w a cell_h do st registrů (před prvním voláním fce?)
	;finit 
	; roh buňky / čtverčíku:
	; pos x = -1.0 + x * cell_w
	; pos y = -1.0 + y * cell_h
	fld dword [cell_h];
	fimul dword [y];
	fadd dword [f_1_0];
	; st0 = pos y
	pushst0 ; push pos y
	fld dword [cell_w];
	fimul dword [x];
	fadd dword [f_1_0];
	; st0 =  pos x
	pushst0 ; push pos x
	invoke glVertex2f ; (levý dolní roh)

	fxch ; st0 = pos y
	pushst0 ; push pos y
	fxch ; st0 = pos x 
	fadd dword [cell_w] ; posx += cell_w  
	pushst0 ; pus pos x
	invoke glVertex2f ; (pravý dolní roh)

	fxch ; st0 = pos y
	fadd dword [cell_h] ; pos y += cell_h
	pushst0 ; todo uložit na zasobník y
	fxch ; st0 = pos x
	pushst0 ; todo uložit na zásobník y 
	invoke glVertex2f ; (pravý horní roh)

	fxch ; st0 = pos y
	pushst0 ; push pos y
	fxch ; st0 = pos x
	fsub dword [cell_w] ; ; pos y -= cell_w 
	pushst0 ; push pos x 
	invoke glVertex2f ; (levý horní roh)

	fstp
	fstp

	pop ecx
	;pop ebx
	pop eax

	return
end


;*************************************************
; vytovoří novou generaci buňěk podle pravidel [rule.S] a [rule.B]
;
function Evolve
var neigh, map_w_1, map_h_1
begin

	mov [population], dword 0 ; vynulování čítače live buňěk

	; uložení proměnné map_w - 1
	mov eax, [map_w]
	dec eax
	mov [map_w_1],eax

	; uložení proměnné map_h - 1
	mov eax, [map_h]
	dec eax
	mov [map_h_1],eax

	mov eax, [map]; eax = ukazatel na konkretni bunku

	mov ebx,0 ; y
.fory:
	cmp ebx, dword [map_h]
	je .breaky

		mov ecx,0  ; x
	.forx:
		cmp ecx, dword [map_w]
		je .breakx
			;;
			%if 1

			push eax;
			xor dl, dl; počítadlo sousedů dané buňky
				
			; eax ukazuje na konkretni bunku pro níž se počítají sousedi

			; kontorlují se v pořadí:
			; 678
			; 501
			; 432

			inc eax ; ->; buňka napravo			
			cmp ecx, dword [map_w_1]; za hranicí
			jne near .skip1
			sub eax, [map_w]
			.skip1: 
			add dl, byte [eax] ; připočítat souseda

			add eax, [map_w] ; dolů; buňka v pravo dole
			cmp ebx, dword [map_h_1] ; za dolní hranicí 
			jne near .skip2
			sub eax, [map_size]
			.skip2:
			add dl, byte [eax] ; připočítat souseda
			
			dec eax ; <- ; buňka dole 
			cmp ecx, [map_w_1] ; za hranicí
			jne near .skip3
			add eax, [map_w]
			.skip3:
			add dl, byte [eax] ; připočítat souseda

			dec eax; <- ; buňka vlevo dole
			cmp ecx, dword 0 ; za hranicí
			jne near .skip4
			add eax, [map_w]
			.skip4:
			add dl, byte [eax] ; připočítat souseda

			sub eax, [map_w]; ^ nahoru; buňka vlevo
			cmp ebx, dword [map_h_1] ; za hranicí
			jne near .skip5
			add eax, [map_size]
			.skip5:
			add dl, byte [eax] ; připočítat souseda

			sub eax, [map_w] ; ^ nahoru; buňka vlevo nahoře
			cmp ebx, dword 0 ; 
			jne near .skip6
			add eax, [map_size]
			.skip6:
			add dl, byte [eax] ; připočítat souseda

			inc eax; -> doprava ; buňka nahoře
			cmp ecx, dword 0; ; za hranicí
			jne .skip7
			sub eax, [map_w]
			.skip7:
			add dl, byte [eax] ; připočítat souseda

			inc eax; -> doprava; buňka vpravo nahoře
			cmp ecx, [map_w_1] ; za hranicí
			jne .skip8
			sub eax, [map_w]
			.skip8:
			add dl, byte [eax] ; připočítat souseda

			pop eax;

			;v dl je ted počet sousedů buňky na adrese eax

			cmp [eax], byte 0; dead or alive?
			je .dead
			; if is alive:

				; kontrola pravidel
				; vždy se napřed testuje zda se má testovat dané pravidlo...

				.testS0:
				cmp dl, byte 0
				jne near .testS1
				test word [rule.S], 0000_0000_0000_0001b ; 0?
				jnz near .live

				.testS1:
				cmp dl, byte 1
				jne near .testS2
				test word [rule.S], 0000_0000_0000_0010b ; 1?
				jnz near .live

				.testS2:
				cmp dl, byte 2
				jne near .testS3
				test word [rule.S], 0000_0000_0000_0100b ; 2?
				jnz near .live

				.testS3:
				cmp dl, byte 3
				jne near .testS4
				test word [rule.S], 0000_0000_0000_1000b ; 3?
				jnz near .live

				.testS4:
				cmp dl, byte 4
				jne near .testS5
				test word [rule.S], 0000_0000_0001_0000b ; 4?
				jnz near .live

				.testS5:
				cmp dl, byte 5
				jne near .testS6
				test word [rule.S], 0000_0000_0010_0000b ; 5?
				jnz near .live

				.testS6:
				cmp dl, byte 6
				jne near .testS7
				test word [rule.S], 0000_0000_0100_0000b ; 6?
				jnz near .live

				.testS7:
				cmp dl, byte 7
				jne near .testS8
				test word [rule.S], 0000_0000_1000_0000b ; 7?
				jnz near .live

				.testS8:
				cmp dl, byte 8
				jne near .die
				test word [rule.S], 0000_0001_0000_0000b ; 8?
				jnz near .live


				jmp .die

			.dead:
			; if is dead:

				.testB0:
				cmp dl, byte 0
				jne near .testB1
				test word [rule.B], 0000_0000_0000_0001b ; 0?
				jnz near .live

				.testB1:
				cmp dl, byte 1
				jne near .testB2
				test word [rule.B], 0000_0000_0000_0010b ; 1?
				jnz near .live

				.testB2:
				cmp dl, byte 2
				jne near .testB3
				test word [rule.B], 0000_0000_0000_0100b ; 2?
				jnz near .live

				.testB3:
				cmp dl, byte 3
				jne near .testB4
				test word [rule.B], 0000_0000_0000_1000b ; 3?
				jnz near .live

				.testB4:
				cmp dl, byte 4
				jne near .testB5
				test word [rule.B], 0000_0000_0001_0000b ; 4?
				jnz near .live

				.testB5:
				cmp dl, byte 5
				jne near .testB6
				test word [rule.B], 0000_0000_0010_0000b ; 5?
				jnz near .live

				.testB6:
				cmp dl, byte 6
				jne near .testB7
				test word [rule.B], 0000_0000_0100_0000b ; 6?
				jnz near .live

				.testB7:
				cmp dl, byte 7
				jne near .testB8
				test word [rule.B], 0000_0000_1000_0000b ; 7?
				jnz near .live

				.testB8:
				cmp dl, byte 8
				jne near .die
				test word [rule.B], 0000_0001_0000_0000b ; 8?
				jnz near .live

				jmp .die


			.live:
				mov edx, eax
				sub edx, [map]
				add [population], dword 1 ; započítat živou buňku
				add edx, [mapB]
				mov [edx], byte 1 ; live!

			jmp .continuex

			.die:
				mov edx, eax
				sub edx, [map]
				add edx, [mapB]
				mov [edx], byte 0 ; die!

			%endif

		
			;; 
	.continuex:
	inc eax
		inc ecx
		jmp .forx
	.breakx:

.continuey:
	inc ebx
	jmp .fory
.breaky:


	call SwapMap 
	inc dword [generation]

	return
end ; Evolve


;******************************
; prohodí map a mapB
;
function SwapMap
begin
	push ebx;
	mov eax, dword [map]
	mov ebx, dword [mapB]
	mov dword [map], ebx
	mov dword [mapB], eax
	pop ebx;
	return
end

;****************************************
; vymaže mapu (nastaví všechny byty na 0)
function WipeMap
begin 
	mov eax, [map]
	add eax, [map_size];

	.dowhile:
	sub eax, 4;
	mov [eax], dword 0;
	cmp eax, [map]
	je .Finish 

	jmp .dowhile


	.Finish:

	return
end


;*********************************-
; Spočítá populaci, uloží do [population]
function countPopulation
begin
	; todo - zrychlit .. sse?
	push ebx
	mov ebx, dword 0 ; čítač populace

	mov eax, [map]
	add eax, [map_size];

	.dowhile:
	sub eax, 1;
	xor ecx, ecx
	mov cl, byte [eax]
	add ebx, ecx
	cmp eax, [map]
	je .Finish 

	jmp .dowhile


	.Finish:
	mov [population], ebx
	pop ebx

return
end

;******************
; nastaví titulek hlavního okna v závislosti na stavu aplikace
; rozhodující hodnoty: [play], [speed]
function reTitle
begin
	push ecx
		mov [winTitle], word 0 ;  smazání starého stringu
		invoke StrCat,winTitle,swzWndCaption ; nazev aplikace
		
		cmp [play], dword 0 ; štvereček nebo trojuhelnik 
		je .stop
		invoke StrCat,winTitle,swzPlayChar
		jmp .fi
		.stop:
		invoke StrCat,winTitle,swzStopChar
		.fi:
 		
 		; čim větší rychlost tim víc trojuhelníčků
		mov ecx, dword [speed]
		inc ecx
		.while:
		push ecx
		invoke StrCat,winTitle,swzSpeedChar
		pop ecx
		loop .while


		invoke StrCat,winTitle,swzSpace
		;invoke StrCat,winTitle,rule

		invoke SetWindowText,[hWnd],winTitle ; nastavit titulek oknu
	
	pop ecx
	return
end

;**************************
; Sestaví string statsText
; rozhodující hodnoty: [generation]
function composeStatsText
begin
	push ecx
	push edx

	invoke swprintf, statsText, SIZEOF_statsText, swzStatForm,\
		[ruleIndex], [generation], [population], [dwWndWidth], [dwWndHeight], [map_w], [map_h], [mouse_x], [mouse_y], [debug]
	add esp, 4*(3+10) ; návrat z cdecl fce

	pop edx
	pop ecx
return
end


;***********
; zpracuje kliknutí na souřadnicích x_c y_c
function Click, x_c, y_c
begin
	mov eax, [x_c]
	mov [mouse_x], eax
	mov eax, [y_c]
	mov [mouse_y], eax
return
end