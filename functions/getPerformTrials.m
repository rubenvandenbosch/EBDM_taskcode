function trials = getPerformTrials(ex)
% 
% trials = getPerformTrials(ex)
% 
% DESCRIPTION
% Get trial information for the performance stage by selecting from
% previously made choices.
% Each combination of reward and effort level is sampled if possible, and,
% again if possible, at least one trial on which the offer was accepted is 
% selected per reward/effort combination.
% For the remaining trials, random samples are drawn from the other choices
% that were made.
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
    'There are more trials to perform effort for (%d) than the number of decisions made in the choice stage (%d)', ex.blocks * ex.blockLen, nChoices);

% Get reward/effort combo indices in choices
%   Also get vector of accepted offers yes/no per trial index
choicesREixs = [choices.result.data.rewardIx; choices.result.data.effortIx];
accepted = [choices.result.data.Yestrial];

% Get all unique reward/effort combinations
[nR, nE] = ndgrid(ex.trialVariables.rewardIx, ex.trialVariables.effortIx);
combs = cat(2,nR(:),nE(:));

% Find trial indices for each combination, and 
%   find trial indices with accepted offers for each combination, and
%   already randomly select one accepted offer per combination if possible
trIxs = {};
acceptIxs = {};
selected = [];
for icomb = 1:size(combs,1)
    trIxs{icomb} = find(choicesREixs(1,:) == combs(icomb,1) & choicesREixs(2,:) == combs(icomb,2));
    acceptIxs{icomb} = trIxs{icomb}(find(accepted(trIxs{icomb})));
    
    % For each combination, select one accepted offer if possible
    if ~isempty(acceptIxs{icomb})
        selected(end+1) = acceptIxs{icomb}(randsample(numel(acceptIxs{icomb}),1));
    end
    % Also randomly select one other choice for this combination if
    % possible
    if ~isempty(trIxs{icomb})
        tmp = trIxs{icomb};
        tmp(ismember(tmp,selected)) = [];
        if ~isempty(tmp)
            selected(end+1) = tmp(randsample(numel(tmp),1));
        end
    end
end

% Fill the rest of the required trial numbers with random draws from choice
% trials for random reward/effort combinations
nTrials = ex.blocks * ex.blockLen;
while numel(selected) < nTrials
    icomb = randsample(size(combs,1),1);
    if ~isempty(trIxs{icomb})
        selected(end+1) = trIxs{icomb}(randsample(numel(trIxs{icomb}),1));
    end
    % Discard duplicates in selection
    selected = unique(selected);
end

% Get trial info for the selected trial indices, and shuffle trial order
allTrials = choices.result.trials(selected);
allTrials = allTrials(randperm(numel(allTrials)));

% Collect trials in a block by trial struct array and return
for b = 1:ex.blocks
    trials(b,:) = allTrials((b-1)*ex.blockLen + 1:(b-1)*ex.blockLen + ex.blockLen);
end
end