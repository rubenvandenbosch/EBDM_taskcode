function ret = buttonbox(cmd,varargin)
% to initialize connection: (omit 2nd argument if defaults apply)
%    define settings as structure with fields:
%       bb.Device    = 'COM2';
%       bb.BaudRate  = 115200;
%       bb.DataBits  = 8;
%       bb.StopBits  = 1;
%       bb.Parity    = 'none';
% handle = buttonbox('open',bb)
%
% to run: (receiving incoming data, check code for own purposes)
% buttonbox('run');
%
% or
%
% to send a marker: (marker: a numeric value; Fs: sampling frequency device)
% buttonbox(marker,Fs)
%
% or
%
% to wait for a buttonpress:
% buttonbox('clear'); (make sure buttonbox buffer is emptied)
% key = buttonbox('wait_keypress')
%
% to close the connection:
% buttonbox('close'); 

mlock
persistent old_hdl  % keep handle to COM object persistent 
% set defaults
bb.Device    = 'COM2';
bb.BaudRate  = 115200;
bb.DataBits  = 8;
bb.StopBits  = 1;
bb.Parity    = 'none'; 

if nargin < 1
   cmd = 'open';
end
if nargin > 1 && isstruct(varargin{1})
   % user overwrites default settings
   flds = fields(varargin{1});
   for n = 1 : numel(flds)
      bb.(flds{n}) = varargin{1}.(flds{n});
   end
end
if nargin==1 && isnumeric(cmd)
   error('Please also specify acquisition sampling frequency of device that receives the marker');
end
if nargin > 1 && isnumeric(cmd)
   marker = cmd;
   cmd = 'marker';
   Fs = varargin{1};
end

if ~any(strcmp(cmd,{'open','close'}))
   if isempty(old_hdl)
      help buttonbox
      error('Buttonbox not yet initialized');
   end
   handle = old_hdl;
end

switch cmd
   case 'marker'
      fwrite(handle, uint8(marker));%IOPort('Write', handle, uint8(marker), 1); % last argument: blocking
      %WaitSecs(2/Fs);
      java.lang.Thread.sleep(1000*(2/Fs));
      fwrite(handle, uint8(0));%IOPort('Write', handle, uint8(0), 0); % last argument: blocking
      return
   case 'clear'
      while(handle.BytesAvailable)
         fread(handle, handle.BytesAvailable);
      end      
      ret = []; % meaningless
      return
   case 'open'
      % get handle to serial device
      handle = open_buttonbox(bb);
      ret = handle;
      return
   case 'close'
      if nargin > 1
         handle = varargin{1};
      else
         handle = old_hdl;
      end
      fclose(handle);
      delete(handle);
      ret = [];
      return
   case 'run'
      % read incoming data
      % code proceeds below ....
   case 'wait_keypress'
      % start polling for characters (indicating start of scan)
      while(1)
         data = [];
         while handle.BytesAvailable
            % read incoming data
            [newdata, cnt] = fread(handle, handle.BytesAvailable);
            % concatenate possible new data
            if cnt
               data = [data newdata(:)];
            end
         end
         if ~isempty(data)
            ret = data;
            return
         end
      end
   otherwise
      fprintf('Unknown option %s\n',cmd);
      ret = [];
      return            
end 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% only gets here when cmd = 'run' %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% Initialize output figure
win = list_output(' ',[]);
while 1
   % Exit if user closed output figure
   if ~ishandle(win)
      return
   end
   % start polling for characters (indicating start of scan)
  data = [];
  while handle.BytesAvailable
     % read incoming data
     [newdata, cnt] = fread(handle, handle.BytesAvailable);
     % concatenate possible new data
     if cnt
        data = [data newdata(:)];
     end
  end
  % output info about which button was pressed
  for n = 1 : numel(data)
     line = sprintf('incoming: %03d   %s',data(n),char(data(n)));
     list_output(line,win);
  end
   pause(0.01);
end %while 1 



   function hdl = open_buttonbox(device)
      % open handle to serial device (mini buttonbox)      WaitSecs(0.002); % just to load mex-file into memory
     if ~isempty(old_hdl)
        try, fclose(old_hdl); delete(old_hdl); catch, end
     end
     hdl = serial(device.Device, 'Baudrate', device.BaudRate, 'DataBits', device.DataBits, 'StopBits', device.StopBits, 'Parity', device.Parity);
     fopen(hdl);
      old_hdl = hdl;      
      fprintf('Wait for device buttonbox....\n');
      pause(0.5);      
      tic
      while hdl.BytesAvailable && toc<10
         % wait for welcome message device
         [ret] = fread(hdl, hdl.BytesAvailable, 'uint8');
         fprintf('%s',uint8(ret));
      end
      fprintf('\n');
   end 

   function win = list_output(line,win)
      persistent ptr
      persistent lines
      persistent edt
      Maxlines = 40;      
      if isempty(win)
         % initialize listbox output figure
         lines = cell(1,Maxlines);
         [lines(1:end)]=deal({''});
         ptr=Maxlines;
         lines(ptr) = {'Buttonbox output:'};
         idxs = mod(ptr:ptr+Maxlines-1,Maxlines)+1;         
         win = figure();
         % initialize figure to hold output text
         edt = uicontrol('Parent',win,'Style','ListBox','HorizontalAlignment','left', ...
            'Max',Maxlines,'BackgroundColor',[1 1 1],'Visible','on','String',lines(idxs), ...
            'FontSize',12,'Value',Maxlines);
         pos = get(win,'Position');
         set(edt,'Position',[1 1 pos(3) pos(4)]);
      end
      ptr = mod(ptr,Maxlines)+1; % start
      lines{ptr} = line;
      idxs = mod(ptr:ptr+Maxlines-1,Maxlines)+1;
      set(edt,'String',lines(idxs),'Value',Maxlines);
      drawnow;
   end 
end
 