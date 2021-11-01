dirname = '/Volumes/U129109/data/SvenVanAs/Cubicle20/';
folders = dir(dirname);
for f=1:numel(folders)
   try
      if folders(f).name(1)~='.' && isdir(fullfile(dirname,folders(f).name))
         dat=ft_read_data([dirname folders(f).name '/0001']); 
         fprintf('maxval=%f\tindex=%d\n',max(dat(1,:)),f);
         if max(dat(1,:)) > 100
            % something weird in the data, show surrounding values
            idx = find(dat(1,:)==max(dat(1,:)),1);
            start = max(idx-3,1);
            einde = min(idx+2,size(dat,2));
            dat(1,start:einde)
            fprintf('index=%d\ttijd=%f\n',idx,idx/50);
         end
      end
   catch 
      disp(f); 
   end
end