function ex = inputSubjectSession(stage, ex)

   fld = fileparts(mfilename('fullpath'));
   addpath(genpath(fld));
   %ex.outputFolder = fullfile(fld,'..','output');
   
   % switch to output folder
   ex.stage = stage; % i.e., 'MVC', 'Hexercise' or 'ChoiceTask'
   cd(ex.outputFolder);
   
   clc;
   fprintf('Experiment stage: %s\n',stage);
   fprintf('Please provide input for subject identifier\n');
   result = input('Subject identifier: ', 's');
   ex.subjectId = strtrim(result);
   
   % find out if output for an earlier session can be found
   nr = 1;
   while 1
      fn = sprintf('%s_%d_%s.txt',ex.subjectId,nr,stage);
      if ~exist(fn,'file')
         break;
      end
      nr = nr + 1;
   end
   ex.session = nr;
   ex.outputFilenameSession = fn;
   ex.outputFilenameSessions = sprintf('%s_%s.txt',ex.subjectId,stage); 
   ex.payoutFilenameSessions = sprintf('%s_%s.txt',ex.subjectId,'payout'); 
   
   fprintf('\nSubject id: %s\nExperiment stage: %s\nSession: %d\n',ex.subjectId,ex.stage,ex.session);
   result = input('Is this correct (yes/no)? ', 's');
   result = strtrim(result);
   if ~any(strcmpi(result,{'y', 'yes', 'ja', 'j'}))
      error('Wrong experiment stage or session follow up number ...?');
   end
end