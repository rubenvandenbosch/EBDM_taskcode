@echo off
set thisdir=%~dp0

rem get current date and time
FOR /F "TOKENS=1* DELIMS= " %%A IN ('DATE/T') DO SET CDATE=%%B 
For /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set date=%%c%%a%%b) 
FOR /F "TOKENS=1* DELIMS= " %%A IN ('TIME/T') DO SET CTIME=%%B 
For /f "tokens=1-4 delims=: " %%a in ('time /t') do (set time=%%a%%b%%c) 
set timestamp=%date%_%time%

set hostport=1972
set odmport=8000
set BUFFER_BCI=fieldtrip\realtime\bin\win32
set savfld=%USERPROFILE%\saving_buffer\raw
mkdir %savfld%
set savfld=%savfld%\buffer_%timestamp%

set OS=win32
set ft_rec_exe=%BUFFER_BCI%\recording.exe

echo fieldtrip saving buffer on port %hostport% started in new command window...
echo saving data to: %savfld%
start "FieldTrip buffer saving gripforce data" call %ft_rec_exe% %savfld% %hostport%