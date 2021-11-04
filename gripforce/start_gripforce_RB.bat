
call activate C:\Users\rubvdbos\AppData\Local\Continuum\anaconda3\envs\flair

cd C:\Users\rubvdbos\surfdrive\Shared\FLAIR\Methods\fMRI task\ebdm_fmri\gripforce

start start_recording_buffer.bat
python gripforce2ft.py buffer://localhost:1972 COM5 50 False

