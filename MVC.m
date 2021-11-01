function result = MVC(params)
% result = MVC(params)

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

% if you have already run the calibration in this session, set this to false.
% Allows for you to use pre-calculated MVCs if necessary (e.g. program crashed)
ex.calibNeeded          = true;
ex.calibOnly            = true; 

ex.blockLen             = 25;  % number of  trials within each block.
ex.blocks               = 1;   % How many blocks are there? Note that calibration and practice phases are not blocks.
ex.numCalibration       = 3;
ex.numFamiliarise       = 0;
ex.numPracticeChoices   = 0;
ex.practiceTrials       = ex.numCalibration + ex.numFamiliarise + ex.numPracticeChoices; 

ex = inputSubjectSession('MVC', ex);
ex = displayInstructions(ex, 1);
result = AGT_CoreProtocol_RU_BSI(params,ex);
