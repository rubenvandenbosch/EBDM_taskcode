function displayInstructions(ex, instructionsDir, slides, varargin)
% displayInstructions(ex, instructionsDir, slides, stage)
% 
% INPUTS
% ex              : struct; experiment parameters
% instructionsDir : char; directory containing image files of instruction
%                   slides
% slides          : num array; which slide(s) to display
% stage           : char; which experiment stage to display experiment
%                   slides from. 
%                   Possible values: 
%                       'practice', 'choice', 'perform', 
%                       'welcome' (show welcome slide),
%                       'restore' (show restored session slide),
%                       'end' (show end of experiment slide)
%                   If not specified, it is based on the value of ex.stage
% -------------------------------------------------------------------------

% Process input arguments
assert(nargin <= 4, 'Too many input arguments')
if nargin == 4; stage = varargin{1}; assert(ischar(stage), 'Input stage should be class char'); end
assert(isstruct(ex), 'Input ex should be class struct')
assert(ischar(instructionsDir), 'Input instructionsDir should be class char')
assert(isnumeric(slides), 'Input slides should be numeric')

if ~exist('stage','var'), stage = ex.stage; end
assert(ismember(stage,{'practice', 'choice', 'perform','welcome','restore','end'}), 'Input stage should be one of: practice, choice, perform, welcome, restore, end')

% Prepare screen if necessary
if ~isfield(ex, 'scr')
    ex.scr = prepareScreen(ex);
end

% Display selected instruction slides
slideNr = 1;
while slideNr <= numel(slides)
    % Get file name
    filename = fullfile(instructionsDir,sprintf('instructions_%s_%s_%d.jpg',ex.language,stage,slides(slideNr)));
    
    % If requested file does not exist, warn and continue
    if ~(exist(filename,'file') == 2)
        warning('Instructions file does not exist: %s', filename)
        slideNr = slideNr + 1;
        continue
    end
    
    % Read and display image
    image = imread(filename);
    Screen('PutImage', ex.scr.w, image);
    Screen('Flip', ex.scr.w);
    
    % Wait before allowing key press
    WaitSecs(1);
    
    % Wait for a button press
    if ex.useBitsiBB
        ex.BitsiBB.clearResponses(); % empty input buffer
        [resp, ~] = ex.BitsiBB.getResponse(Inf, true); % wait for any button press
    else
        [~,resp,~] = KbWait();
    end
    
    % If left key was pressed, go back one slide (if possible). Otherwise
    % continue to next slide or with experiment
    if slideNr > 1 && resp(ex.leftKey)
        slideNr = slideNr - 1;
        WaitSecs(0.1);
    else
        slideNr = slideNr + 1;
        WaitSecs(0.5);
    end
end
end