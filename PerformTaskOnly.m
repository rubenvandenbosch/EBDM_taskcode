function result = PerformTaskOnly(OutputFilenameChoiceTaskOnly,params)
% result = PerformTaskOnly(OutputFilenameChoiceTaskOnly,params)

%%% Notes
% 2018-06-29 : Adapted script from AGT_Simplified.
% Squeezy implementation: interfaces with MP150 and transducers, records  from channels 1.
% Authors: Sanjay Manohar, Annika Kienast, Matthew Apps, Valerie Bonnelle,
%          Michele Veldsman, Campbell Le Heron, Trevor Chong 2012-2018
% 2020-June: adapted to meet the requirements for conducting the apple tree experiment
% in the Donders fmri lab (RU/FSW/TSG, P.L.C. van den Broek).

global totalReward YesResp
totalReward = 0;

if nargin < 1
    error('Please, specify as input the matlab output file from ChoiceTaskOnly'); 
end
if nargin < 2
   params = [];
end
if ~exist(OutputFilenameChoiceTaskOnly, 'file')
    error('Output matlab file from ChoiceTaskOnly could not be found: %s',OutputFilenameChoiceTaskOnly); 
end

% load common settings
ex = commonSettings();

ex.resultsChoiceTaskOnly = load(OutputFilenameChoiceTaskOnly);
YesResp = [ex.resultsChoiceTaskOnly.result.data.Yestrial];

%% Things to adjust

% NB: must be < ex.blockLen * ex.blocks from ChoiceTaskOnly !!
ex.blockLen             = 25;  % number of  trials within each block.
if ex.resultsChoiceTaskOnly.result.params.blockLen * ex.resultsChoiceTaskOnly.result.params.blocks < ex.blockLen
    error('Too many trials to be performed compared to number of choices %d made in Choice task',ex.resultsChoiceTaskOnly.result.params.blockLen * ex.resultsChoiceTaskOnly.result.params.blocks);
end
ex.blocks               = 1;   % How many blocks are there? Note that calibration and practice phases are not blocks.
ex.numCalibration       = 0;   % 0 calibration trials, then
ex.numFamiliarise       = 0;   
ex.numPracticeChoices   = 0;   % 0 practice trials: 2 trials at each effort level. (no reward)
% total number trials before first main block = 'practice block' : block 0.
ex.practiceTrials       = ex.numCalibration + ex.numFamiliarise + ex.numPracticeChoices; 
if ex.practiceTrials > ex.blockLen
    error('Set parameter "blockLen >= "practiceTrials"');
end

% Pseudorandomly selected trials where force to be performed after all choices
allCombinationsOnce = combinationsEffortReward(ex.order_effort,ex.order_reward,1);
ex.last_trial = allCombinationsOnce;

% the block number on which people are asked to actually perform selected
% squeezes (at the end of the experiment).
ex.choiceBlockNumber    = 1; 


ex = inputSubjectSession('ChoiceTask', ex);
%ex = displayInstructions(ex, [9]);
ex = displayInstructions(ex, [16]); %BL feb2021: split fmri version
result = AGT_CoreProtocol_RU_BSI(params,ex);
