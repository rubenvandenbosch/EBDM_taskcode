function result = FamiliariseTaskOnly(params)
% result = FamiliariseTaskOnly(params)

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

%% Things to adjust

ex.blocks               = 0;   % How many blocks are there? Note that calibration and practice phases are not blocks.
ex.numCalibration       = 0;
ex.numFamiliarise       = 5; %15;
ex.numPracticeChoices   = 5;
ex.blockLen             = ex.numFamiliarise + ex.numPracticeChoices;
ex.practiceTrials       = ex.numCalibration + ex.numFamiliarise + ex.numPracticeChoices; 
if ex.practiceTrials > ex.blockLen
    error('Set parameter "blockLen >= "practiceTrials"');
end
ex.last_trial           = [];

ex = inputSubjectSession('ChoiceTask', ex);
ex = displayInstructions(ex, [1:5]); %BL feb2021: split fmri version (but is same here)
result = AGT_CoreProtocol_RU_BSI(params,ex);
