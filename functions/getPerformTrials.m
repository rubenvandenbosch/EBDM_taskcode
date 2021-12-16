function trials = getPerformTrials(ex)
% 
% trials = getPerformTrials(ex)
% 
% DESCRIPTION
% Get trial information for the performance stage by selecting from
% previously made choices.
% Each combination of reward and effort level is sampled, if possible.
% An equal number of choices per reward/effort combination is selected, as
% much as possible.
% If more perform trials are requested than some precise multiple of the
% number of combinations, the rest of the required trials are randomly
% drawn from the remaining choice trials.
% 
% INPUT
% ex : struct with experiment settings. Must contain fields:
%   ex.choices_file : char; full path to .mat output file containing the
%                     data of the choice stage.
%   ex.blocks       : double; number of blocks
%   ex.blockLen     : double; number of trials per block
%   ex.trialVariables.rewardIx : vector with available reward indices
%   ex.trialVariables.effortIx : vector with available effort indices
% 
% OUTPUT
% trials    : struct array of size ex.blocks x ex.blockLen containing the
%             trial info of the selected trials to perform.
% -------------------------------------------------------------------------
% 

% Load previous choices
assert(exist(ex.choices_file,'file') == 2, 'The choices output file does not exist: %s', ex.choices_file);
choices = load(ex.choices_file,'result');
assert(ex.blocks * ex.blockLen <= numel(choices.result.data) || ex.DEBUG, ...
    'There are more trials to perform effort for (%d) than the number of decisions made in the choice stage (%d)', ex.blocks * ex.blockLen, numel(choices.result.data));

% Get reward/effort combo indices in choices
%   Also get vector of accepted offers yes/no per trial index
choicesREixs = [choices.result.data.rewardIx; choices.result.data.effortIx];
accepted = [choices.result.data.Yestrial];

% Get all unique reward/effort combinations
[nR, nE] = ndgrid(ex.trialVariables.rewardIx, ex.trialVariables.effortIx);
combs = cat(2,nR(:),nE(:));

% Find trial indices for each combination
for icomb = 1:size(combs,1)
    trIxs{icomb} = find(choicesREixs(1,:) == combs(icomb,1) & choicesREixs(2,:) == combs(icomb,2));
end

% Get the number of possible repetitions per reward/effort combination for
% the perform trials, given the requested number of trials and number of
% combinations
nTrials = ex.blocks * ex.blockLen;
nRepsAll = floor(nTrials/size(combs,1));
if nRepsAll == 0, nRepsAll = 1; end

% Select equal number of random choices for each combination.
%   Missing combinations in choices are skipped
%   Only unique choices are selected, i.e. if a combination only appears
%   once in choices, it's only selected once.
selected = [];
for rep = 1:nRepsAll
    for icomb = 1:size(combs,1)
        if ~isempty(trIxs{icomb})
            tmp = trIxs{icomb};
            tmp(ismember(tmp,selected)) = [];
            if ~isempty(tmp)
                selected(end+1) = tmp(randsample(numel(tmp),1));
            end
        end
    end
end

% If more perform trials are requested than some precise multiple of the
% number of combinations, get the rest of the required trials with random 
% draws from the remaining choice trials
if numel(selected) < nTrials
    nToSelect = nTrials-numel(selected);
    
    remainingTrials = cell2mat(trIxs);
    remainingTrials(remainingTrials == selected) = [];
    assert(numel(remainingTrials) >= nToSelect, 'Too many perform trials requested. No more choices to select from');
    
    selected = [selected, remainingTrials(randsample(numel(remainingTrials),nToSelect,false))];
end

% Get trial info for the selected trial indices
%   Reshape choice trial info to get all in one row (same as selected var)
%   Add field that indicates whether the trial's offer was accepted
choices.result.trials = reshape(choices.result.trials',[1,numel(choices.result.trials)]);
allTrials = choices.result.trials(selected);
for ix = 1:numel(selected)
    allTrials(ix).Yestrial = choices.result.data(selected(ix)).Yestrial;
end

% Shuffle trial order and collect trials in a block by trial struct array
allTrials = allTrials(randperm(numel(allTrials)));
for b = 1:ex.blocks
    trials(b,:) = allTrials((b-1)*ex.blockLen + 1:(b-1)*ex.blockLen + ex.blockLen);
end
end