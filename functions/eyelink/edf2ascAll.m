function edf2ascAll
d=dir;
for(i=1:length(d))
  if all(d(i).name(end-3:end)=='.edf')
    do=1;
    for(j=1:length(d)) % does the asc file exist?
      if([d(j).name(1:end-4) '.asc']==d(i).name)
        do=0;
      end
    end 
    if(do) % if not, neeeds to be done.
      [err tmp]=dos('edf2asc ' d(i).name], '-echo');
      rehash path
      if ~exist([d(i).name(1:end-4) '.asc'],'file')
        error(tmp);
      end 
    end % if do
  end % if edf
end  % for
