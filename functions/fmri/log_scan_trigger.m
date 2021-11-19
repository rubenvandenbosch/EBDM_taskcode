function log_scan_trigger(identifier, outfolder)
% File Name:  log_scan_trigger (adapted from receive_trigger_code, Uriel Plones)
%
% identifier: identifies subject
% outfolder: folder to store output results
%
% Description:
% The code sets the bitsi to it's initial trigger mode and receives a
% trigger on one of its 8 inputs from the button boxes. Input one receives
% a trigger when a new scan starts.
% Incoming scanner pulses will be logged to a file, which name is
% determined by the specified identifier and outfolder.
%
% The Character - Bit Number reference is:
% (Up meaning rising edge, down meaning falling edge)
% Bit 1 up: 'a', Bit 1 down: 'A' (RI, Right Index)
%
% The program uses the Bitsi.m file to communicate with the bitsi.

if nargin < 2
    error('Please specify subject identifer and output folder');
end

name = sprintf('%s_scannerpuls.log',identifier);
filename = fullfile(outfolder,name);
fp = fopen(filename, 'a');  
if fp < 0
    error('Can not open output log file: %s',filename);
end

comport = 'COM3'; % set to empty '' for simulating bitsi
trigger_keycode = 97; % 97 = key 'a' ( set to 4 if simulated bitsi, i.e., when comport='')

delete(instrfindall);
clean = onCleanup(@()cleanup()); % executes at cleanup of local variable clean

% create a serial object
b1 = Bitsi_2016(comport);
b1.setTriggerMode();

b1.clearResponses();                  % empty input buffer
pulse = 0;

fprintf('Start scanning for incoming scanner pulses.\n');
fprintf(fp,'Start\t%s\n',strrep(datestr(now),' ','_'));
while 1
    % time  from PTB GetSecs() % time since system startup
    [resp, time_resp] = b1.getResponse(0.001, true);
    if resp == trigger_keycode
        pulse = pulse + 1;
        fprintf('Scanner pulse %d at %f\n', pulse, time_resp);
        fprintf(fp,'%f\t%d\n',time_resp,pulse);
    end
end


    function cleanup()
        try fclose(fp); catch, end
        fprintf('Close bitsi object\n');
        b1.close;
        clear b1;
    end

end