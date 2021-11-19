function [d,s]=ensureStructsAssignable(d,s)
% [dest, source] = ensureStructsAssignable(dest, src)
% pad and reorder the fields of the structs so that it is possible to
% assign one to another in the form dest(x)=src
sf=fieldnames(s);                 % field names from source
DEBUG=true;                       % set this to false to prevent messages
for i=1:length(sf)                % for each source field
  if ~isfield(d,sf{i})            % is it missing in the destination?
    if DEBUG, fprintf('dest does not contain %s\n',sf{i}); end
    if isnumeric(s(1).(sf{i}))    % for numerical fields, fill with 'nan'
      [d.(sf{i})]=deal(nan(size(s(1).(sf{i}))));
    else                          % otherwise fill with the value from source (element 1)
      [d.(sf{i})]=deal(s(1).(sf{i}));
    end;
  end;
end
df=fieldnames(d);                 % repeat the whole process with the destination
for i=1:length(df)
  if ~isfield(s,df{i})
    if DEBUG, fprintf('src does not contain %s\n',df{i}); end
    if isnumeric(d(1).(df{i}))
      [s.(df{i})]=deal(nan(size(d(1).(df{i}))));
    else
      [s.(df{i})]=deal(d(1).(df{i}));
    end;
  end;
end;
d=orderfields(d,s);               % now make sure the fields are in the same order
