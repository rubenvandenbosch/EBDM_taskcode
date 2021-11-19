function [tr] = createTrials(ex)
% Create a structure of trials from experiment parameters.
%
% ex.blocks         : number of blocks in the experiment
% ex.blockLen       : number of trials in each block
%
% ex.blockVariables 
% ex.trialVariables
%     structures whose fields are the variables to vary in each trial or
%     block respectively. The value of each field should be a list or
%     vector of the possible values for that variable, e.g.
%       ex.trialVariables.contrast = [0.1, 0.4, 0.6, 0.9]
% ex.unequalTrials
%     unless this is set, do not allow unequal numbers of each trial type.
%
%
% returns:  
%   a structure array whosee elements
%   tr(block, trial).variablename = value
%
%   with each block and trial variable set to one of the specified values
%   in each trial, and
%   with trials and blocks in randomised counterbalanced order (if possible)
%
% Sanjay Manohar 2008


% if the trials are already there, just use the existing trial order
% (e.g. when continuing from an interrupted experiment)
if isfield(ex, 'trials'), tr=ex.trials; return; end 
if ~isfield(ex,'blockVariables')    % any variables that vary block-wise?
  ex.blockVariables.blockType=1;    % if not, create a dummy variable
end
if ~isfield(ex,'trialVariables')    % any variables that vary trial-wise?
  ex.blockVariables.trialType=1;    
  warning('No trial variables specified - trials will be identical');
end

tr=struct;                                  % create blank trial
bvarnames = fieldnames(ex.blockVariables);  % names of variables that vary by block
tvarnames = fieldnames(ex.trialVariables);  % and by trial

for i=1:length(bvarnames)  % possible values of each block variable
    bvvlist{i} = ex.blockVariables.(bvarnames{i});
    bvnum(i)   = length(bvvlist{i});            % number of levels of each factor
end
            
for i=1:length(tvarnames) % possible values of each trial variable
    tvvlist{i} = ex.trialVariables.(tvarnames{i});
    tvnum(i)   = length(tvvlist{i});            % number of levels
end
if isfield(ex,'repetitionsPerBlock') && ~isfield(ex,'blockLen')
    ex.blockLen = prod(tvnum) * ex.repetitionsPerBlock;
elseif isfield(ex,'blockLen') && ~isfield(ex,'repetitionsPerBlock')
    % Work out how many of each trial type we can fit in a block.
    ex.repetitionsPerBlock = ex.blockLen/prod(tvnum);
else
    error('you must specify either "repetitionsPerBlock" or "blockLen" in ex')
end
% If we aren't allowing unequal trials per block, then test the number of
% trials is OK
if ~isfield(ex,'allowUnequalTrials') || ~ex.allowUnequalTrials
  % Require more trials in a block than conditions:
  % if the numer of repetitions per block is not a whole number,
  % exit with error
  if floor(ex.repetitionsPerBlock) < ex.repetitionsPerBlock
    error('There not enough trials in each block (%d repetitions)', ex.repetitionsPerBlock) ;
  end
end
bvvi=ones(1,length(bvarnames)); % index of current block variables, in range 0-bvnum(i)
for b = 1:ex.blocks                  % construct the blocks
    tvvi=ones(1, length(tvarnames)); % index of current trial variables
    for t = 1:ex.blockLen            % for each trial:
        %tr{b,t} = ex; % copy all params? -- optional!
        for i = 1:length(bvarnames)  % set block type
            if iscell(bvvlist{i})
                tr=setfield(tr,{b,t}, bvarnames{i}, bvvlist{i}{bvvi(i)});
            else
                tr=setfield(tr,{b,t}, bvarnames{i}, bvvlist{i}(bvvi(i)));
            end
        end
        for i = 1:length(tvarnames)  % set trial type
            if iscell(tvvlist{i})
                tr=setfield(tr,{b,t}, tvarnames{i}, tvvlist{i}{tvvi(i)});
            else
                tr=setfield(tr,{b,t}, tvarnames{i}, tvvlist{i}(tvvi(i)));
            end
        end
        done=false;
        ti=1;
        while ~done                % serially increment trial type
            tvvi(ti)=tvvi(ti)+1;   
            if tvvi(ti)>tvnum(ti)  % if the trial type has wrapped around,
                tvvi(ti)=1;        % reset to 1, and 
                ti=ti+1;           % increment the next trial variable
                if(ti>length(tvvi)), done=true; end % back to ones
            else, done=true; 
            end
        end
    end
    done=false;                    % now do the same thing with block types:
    while ~done                    % serially increment block type
        bi=1;
        bvvi(bi)=bvvi(bi)+1;
        if bvvi(bi) > bvnum(bi)    % increment next block variable
            bvvi(bi)=1;
            bi=bi+1;
            if(bi>length(bvvi)), done=true; end % back to ones
        else, done=true;   
        end
    end
end

% trial order - shuffle for each block, but counterbalance trial order
% across blocks
nbt=prod(bvnum);    % number of block types
nebt=ex.blocks/nbt; % number of each block type
for b=1:ex.blocks   % counterbalance order across blocks
    if b<=ex.blocks/2+1                       % first half of experiment:    
        if ~isfield(ex,'shuffleTrials') || ex.shuffleTrials % default: shuffle trials
            order(b,:) = Shuffle(1:ex.blockLen);  % shuffle each block
        else % If 'shuffleTrials' is false:
            order(b,:) = 1:ex.blockLen;       % fixed order of trials.
        end
    else                                      % second half:
        order(b,:) = order(ex.blocks-b+1,:);  % use order from first half in reverse
    end
    tr(b,:)=tr(b,order(b,:));         
end


% block order
counterbalance=1;
if( (nebt/2) == floor(nebt/2) )  % if even, counterbalance blocks
    if(isfield(ex, 'blockorder'))
        if(length(ex.blockorder)==ex.blocks/2)
            blockorder=ex.blockorder;
        else
            blockorder=repmat(ex.blockorder,1,1+floor(ex.blocks/length(ex.blockorder)));
            blockorder=blockorder(1:ex.blocks);
            warning('createTrials:blockorder',['Block order is ' num2str(length(ex.blockorder))...
                ' blocks long, but experiment is ' num2str(ex.blocks) ' long. '...
                'Blocks not counterbalanced.']);
            counterbalance=0;
        end
    else
        blockorder=Shuffle(1:ex.blocks/2);
    end

else                       % otherwise randomise blocks
    if(isfield(ex, 'blockorder'))
        blockorder=ex.blockorder;
        if(length(blockorder)<ex.blocks) % blockorder too small? repeat it
            blockorder=repmat(blockorder,1,1+floor(ex.blocks/length(blockorder)));
            warning('createTrials:blockorder', ['blockorder is only ' ...
                num2str(length(ex.blockorder)) 'items. Repeating to fill '...
                num2str(ex.blocks) ' blocks.']);
        end
    else
        blockorder=Shuffle(1:ex.blocks);
        warning('createTrials:blocknumber',...
            ['There are ' num2str(nbt) ' types of block, but ' num2str(ex.blocks)...
            ' blocks. Shuffling them, but some will be more frequent.']);
    end
    counterbalance=0;
end
if ex.blocks > 0
    if(counterbalance)
        tr(1:ex.blocks/2,:) = tr(blockorder,:);
        tr(ex.blocks/2+1:end,:) = tr(ex.blocks/2:-1:1,:);
    else
        tr(:,:)=tr(blockorder,:);
    end
    % display the block order in the console 
%     disp(blockorder);
end

function x=Shuffle(x)
x=x(randperm(length(x)));
return