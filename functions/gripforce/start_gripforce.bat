:: INPUTS
:: input 1 = full path to conda environment to activate
:: input 2 = full path to directory containing this and other gripforce code files
:: input 3 = which COM port to use. Character string, e.g. 'COM5'

:: Collect input arguments
set env_path=%1
set grip_dir=%2
set comport=%3

:: Activate conda environment
call activate %env_path%

:: Change directory to the folder containing the gripforce files
pushd %grip_dir%

:: Start gripforce recording
start start_recording_buffer.bat
python gripforce2ft.py buffer://localhost:1972 %comport% 50 False

