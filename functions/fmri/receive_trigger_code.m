% File Name:  receive_trigger_code
%
% Description: 
% The code sets the bitsi to it's initial trigger mode and receives a 
% trigger on one of its 8 inputs from the button boxes. We assume that the 
% button boxes are connected through the bitsi. 
% 
% when you press one of the buttons, the corresponding character is
% displayed together with it's decimal ascii value. When you press'a' 
% (right index), the program stops.
%
% The Character - Bit Number reference is:
% (Up meaning rising edge, down meaning falling edge)
% Bit 1 up: 'a', Bit 1 down: 'A' (RI, Right Index)
% Bit 2 up: 'b'. Bit 2 down: 'B' (RM, Right Middle)
% Bit 3 up: 'c', Bit 3 down: 'C' (RR, Right Ring)
% Bit 4 up: 'd', Bit 4 down: 'D' (RP, Right Pink)
% Bit 5 up: 'e', Bit 5 down: 'E' (LI, Left Index)
% Bit 6 up: 'f', Bit 6 down: 'F' (LM, Left Middle)
% Bit 7 up: 'g', Bit 7 down: 'G' (LR, Left Ring)
% Bit 8 up: 'h', Bit 8 down: 'H' (LP, Left Pink)
%
% The program uses the Bitsi.m file to communicate with the bitsi.
%
% Programmer: Uriel Plones
% 
% Date: 2-3-2016
% 
% Version: 0.0: Initial version

delete(instrfindall);

% create a serial object
b1 = Bitsi_2016('com2');
b1.setTriggerMode();

b1.clearResponses();                  % empty input buffer
buttonpress = 0;
quit = false;

fprintf('Press a button on the buttonbox.\n');
fprintf('Pressing "a" will quit the program.\n');
while quit == false 
  [resp, time_resp] = b1.getResponse(0.001, true);
  if resp > 0
    buttonpress = buttonpress + 1;
    time = time_resp;
    fprintf('Button %d pressed is: %s, %d\n', buttonpress, char(resp), resp);
  end;
  if resp == 'a'
     quit = true;
  end;
end;

b1.close;
clear b1;
