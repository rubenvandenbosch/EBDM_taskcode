% start apple task
function start_apple_task(PTBfolder)

if nargin > 0 && ~isempty(PTBfolder)
    % add Psychtoobox folders to Matlab path
    addpath(genpath(PTBfolder));
else
    % we assume Psychtoolbox is default added to Matlab path at startup
    try
        fprintf('Using Psychtoolbox version: %s\n',PsychtoolboxVersion);
    catch
        fprintf('Psychtoolbox is not added to your Matlab path. Please, specify path to Psychtoobox installation folder as input argument to ''start_apple_task()'' and execute it from the Matlab prompt.\n');
        return;
    end
end

% add all required folders for apple tree task to Matlab path
fld = fileparts(mfilename('fullpath'));
addpath(genpath(fld));

