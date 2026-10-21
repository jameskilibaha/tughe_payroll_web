@echo off
rem ============================================================================
rem  Inaweka faili za ADMIN PANEL (tughe_payroll_web)
rem  1) Toa (Extract) zip nzima  2) Bonyeza mara mbili faili hii  3) Anzisha upya server / app
rem  Kama folda yako ni nyingine, badilisha mstari wa DEST hapa chini (kwa Notepad).
rem ============================================================================
set DEST=X:\Projects\AARON\Payroll\tughe_payroll_web

if not exist "%DEST%\pubspec.yaml" (
  echo KOSA: sioni pubspec.yaml ndani ya %DEST%
  echo Fungua faili hii kwa Notepad na ubadilishe mstari wa DEST uwe folda sahihi.
  pause
  exit /b 1
)
xcopy "%~dp0frontend" "%DEST%" /E /I /Y
echo.
echo IMEKAMILIKA - nakala zimewekwa kwenye %DEST%
pause