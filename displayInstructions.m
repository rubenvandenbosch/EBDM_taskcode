function ex = displayInstructions(ex, instructionsDir, slides, varargin)
% ex = displayInstructions(ex, instructionsDir, slides, stage)
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
%                       'restore' (show restored session slide)
%                   If not specified, it is based on the value of ex.stage
% -------------------------------------------------------------------------

% Process input arguments
assert(nargin < 5, 'Too many input arguments')
if nargin == 4; stage = varargin{1}; end
assert(isstruct(ex), 'Input ex should be type struct')
assert(ischar(instructionsDir), 'Input instructionsDir should be type char')
assert(isnumeric(slides), 'Input slides should be a numeric')
assert(ischar(stage), 'Input stage should be type char')
assert(ismember(stage,{'practice', 'choice', 'perform','restore'}), 'Input stage should be one of: practice, choice, perform, restore')

% Prepare screen if necessary
if ~isfield(ex, 'scr')
    ex.scr=prepareScreen(ex);
end

% Get experiment stage
if ~exist(stage,'var')
    stage = ex.stage;
end

% Display selected instruction slides
for n = 1:numel(slides)
    % Get file name
    filename = fullfile(instructionsDir,sprintf('instructions_%s_%s_%d.jpg',ex.language,stage,slides(n)));
    
    % If requested file does not exist, warn and continue
    if ~(exist(filename,'file') == 2)
        warning('Instructions file does not exist: %s', filename)
        continue
    end
    
    % Read and display image
    image = imread(filename);
    Screen('PutImage', ex.scr.w, image);
    Screen('Flip', ex.scr.w);
    
    % Wait and wait for key press
    WaitSecs(2);
    myKbWait(ex);
    WaitSecs(0.5);
end