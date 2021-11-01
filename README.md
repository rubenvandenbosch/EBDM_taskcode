Matlab experiment modified to allow TSG manufactured gripforce device to be used with further extended options. This script is adapted from Squeezy script written by Sanjay Manohar (https://github.com/sgmanohar/matlib), using his Matlib toolbox (https://osf.io/vmabg/).
It is seperated into different stages, each individually startable. The decision
phase is modified to run in an fmri lab setting without using the handgrip.
Changes made:
- Integration of TSG gripforce device
- Streaming gripforce channels to fieldtrip buffer (gripforce2ft)
- Fix some minor bugs
- Option to execute a calibration only
- Remove handgrip use in decision stage for fmri lab
- Add fixation cross before decision tree becomes visible (with random ISI)
- Add waiting for fmri scanner pulses before starting decision stage
