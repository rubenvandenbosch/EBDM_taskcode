function result = ChoiceTaskOnly(params)
% result = ChoiceTaskOnly(params)

%%% Notes
% 2018-06-29 : Adapted script from AGT_Simplified.
% Squeezy implementation: interfaces with MP150 and transducers, records  from channels 1.
% Authors: Sanjay Manohar, Annika Kienast, Matthew Apps, Valerie Bonnelle,
%          Michele Veldsman, Campbell Le Heron, Trevor Chong 2012-2018
% 2020-June: adapted to meet the requirements for conducting the apple tree experiment
% in the Donders fmri lab (RU/FSW/TSG, P.L.C. van den Broek).

global totalReward
totalReward = 0;

if nargin < 1
   params = [];
end

% load common settings
ex = commonSettings();

ex.useBitsiBB = 1; % overrule common setting for fmri decision phase
if ex.useBitsiBB
    delete(instrfindall);
    ex.BitsiBB = Bitsi_2016(ex.fmriComport); % create a serial object
    ex.BitsiBB.setTriggerMode();
    ex.leftKey   = ex.leftButton;
    ex.rightKey  = ex.rightButton;
end

ex.useGripforce         = false;          % Change to 1 to use GripForce device (manufactured by TSG department, Radboud University)

% NOTE blockLen must be defined 5, 10, 15, 20, or 25 !!!!
ex.blockLen             = 25;  % number of  trials within each block.
ex.blocks               = 4;   % How many blocks are there? Note that calibration and practice phases are not blocks.
ex.numCalibration       = 0;   
ex.numFamiliarise       = 0;   
ex.numPracticeChoices   = 5;   % start with 5 practice trials
ex.practiceTrials       = ex.numCalibration + ex.numFamiliarise + ex.numPracticeChoices; 
if ex.practiceTrials > ex.blockLen
    error('Set parameter "blockLen >= "practiceTrials"');
end

ex = inputSubjectSession('ChoiceTask', ex);

% open scanner pulse log file
name = sprintf('%s_scannerpuls.log',ex.subjectId);
filename = fullfile(ex.outputFolder,name);
fp = fopen(filename, 'r');  
if fp < 0
    error('Can not find/open output log file: %s, is ''log_scan_trigger'' running?',filename);
end
%  wait for ex.waitNumScans (5) fmri scanner pulses
tline = {[]}; % init
num = 0;
while 1
    while isempty([tline{:}])
        tline = textscan(fp,'%s\t%s',1);
        WaitSecs(0.1);
    end
    t = tline{1}{1}; % time or 'Start'
    p = tline{2}{1}; % scanner pulse number
    if ~strcmp(t,'Start')
        num = num + 1;
        fprintf('Incoming scan: %s\t%s\n',t,p);
    end   
    if num >= ex.waitNumScans, break, end
    tline = {[]}; % init
end

%ex = displayInstructions(ex, [1:5]);
ex = displayInstructions(ex, [8:13]); %BL feb2021: split fmri version
result = AGT_CoreProtocol_RU_BSI(params,ex);
