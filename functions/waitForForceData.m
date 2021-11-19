function [squeezeData keys timeOfLastAcquisition] = waitForForceData(ex,...
    timeOfLastAcquisition, ...
    maxTimeToWait, stopRecordingAtThreshold , ISI, ...
    continuousFeedbackFunction )
% Function to stream data from squeezy device
% require MP Acquisition daemon to be running
% 'timeOfLastAcquisition':
%  Needs to know the time of the last acquisition in order to calculate 
%  how many samples to dequeue before starting this acquisition.
%  The first time you call this in a trial, you should send the time that
%  the acquisition started - i.e. tr.startSqueezyAcquisition.
%  Subsequent calls in the same trial must pass the value returned from
%  this function 'timeOfLastAcquisition'.
%
% The function blocks execution until either 
% 1) the force exceeds 'stopRecordingAtThreshold'
% 2) the time elapsed exceeds 'maxTimeToWait'.
%
% The function returns a matrix 'sqeezeData(TIME,CHANNEL)' 
% which is the force data for the left and right channels
% and also if any keys were pressed, they are in the vector 'keys',
% otherwise this vector is empty.
%
% Finally, we also return "timeOfLastAcquisition" which is the time that we
% last checked the MP150 stream. This is needed for further calls, to know
% how much data to de-queue
%
% continuousFeedbackFunction( currentForce )
%  should be a function that can be called repeatedly each time new samples
%  are acquired. You can do the drawing in here.

if isfield(ex,'useGripforce') && ex.useGripforce
    if isfield(ex,'simulateGripforce') && ex.simulateGripforce
       [squeezeData keys timeOfLastAcquisition] = waitForSimulatedGripForceData(ex,...
        timeOfLastAcquisition, ...
        maxTimeToWait, stopRecordingAtThreshold , ISI, ...
        continuousFeedbackFunction );
    else
       [squeezeData keys timeOfLastAcquisition] = waitForGripForceData(ex,...
        timeOfLastAcquisition, ...
        maxTimeToWait, stopRecordingAtThreshold , ISI, ...
        continuousFeedbackFunction );
    end
   return;
end

EXIT = 0;
startRecordingTime = GetSecs;
%%%% De-queue data from MP150
% first dequeing is for all samples since the start of the acquisition.

% Calculate how many samples need to be read from the MP150; sadly we
% have to use  (last read-time) * (sample-rate) due to awful programming
% on behalf of BioPAC.
queueLen = @(lastread)2*floor((GetSecs-lastread)*ex.MP_SAMPLE_RATE);
% set up recording buffer of 3 seconds, and buffer
record=nan*zeros(ex.MP_SAMPLE_RATE*ISI,2);
lq = queueLen(timeOfLastAcquisition);
buffer=nan*zeros(lq,1);
[z buffer nread] = calllib(ex.mplib, 'receiveMPData', buffer,lq,0);
lastread=GetSecs;
%lastread=timeOfLastAcquisition+nread/2/ex.MP_SAMPLE_RATE; % update last read time.
record(1:(nread/2),:)=[buffer(1:2:nread) buffer(2:2:nread)]; % store both channels
nTotalRead=nread/2; 
fprintf('err=%g',GetSecs-lastread);

% not sure how to code that, or should I use button press and if they responded 'yes' then 'get ready to squeeze the left grip with your left hand'
while(GetSecs < startRecordingTime + maxTimeToWait && ~EXIT)              % how do I do this for right and left hand
    %%%% CHECK KEYPRESSES
    [keyisdown,secs,keycode] = KbCheck; % check for real key
    keys=find(keycode);
    if(any(keys==27)) EXIT=1; end         % check for ESCAPE
    
    %%%% POLL squeezes from MP150
    lq = queueLen(lastread); % required length of queue

    if(lq>0)                 % any data in queue?
        if(lq>length(buffer)) buffer=nan*zeros(lq,1); end % extend buffer if needed
        [z buffer nread]=calllib(ex.mplib, 'receiveMPData', buffer,lq,0); % READ MP150
        %lastread=lastread+nread/2/ex.MP_SAMPLE_RATE; % keep log of elapsed reads, to allow calculation of queue length next time.
        
        lastread=GetSecs;
        %times(nTotalRead)=GetSecs; % keep track of time
        record((nTotalRead+1):(nTotalRead+nread/2),:)=[buffer(1:2:nread) buffer(2:2:nread)]; % store both channels
        nTotalRead=nTotalRead+nread/2; % keep track of how many bytes read
        if nTotalRead>20
            mu  = mean( record((nTotalRead-20):nTotalRead, :) );       % 20ms mean force
            mud = mean( diff(record((nTotalRead-20):nTotalRead, :)) ); % 20ms mean differential
            if any(mu > stopRecordingAtThreshold)
                EXIT=1;
            end
        end
    end
    if exist('continuousFeedbackFunction','var')&& exist('mu','var')
        continuousFeedbackFunction( mu ); % if the user supplied a feedback 
        % function, call it now with the mean force over last 20ms (this is
        % a vector with two elements, one for each channel)
    end
end
squeezeData = record; % send back the actual data recorded
timeOfLastAcquisition = lastread; % send back the time we last read the device