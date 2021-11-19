function results=WaitForSaccade(el, maxtime, minsize)



s=eyelink('newestsample');
p0=[s.time s.gx(el.eye) s.gy(el.eye)];
p = repmat(p0,5,1);
cont=1;
count=0;
time=0;
debugFixation = 0;
while cont
    if(eyelink('newsampleavailable'))
        s=eyelink('newestsample');
        dt=s.time-p(end,1);
        if(dt>0) % if it's a later timepoint,
            p = [p(2:end,:); s.time s.gx(el.eye)/10 s.gy(el.eye)/10];
            time=time+dt;
            count=count+1;
            if(count<=5) continue; end;
            if(isSaccade(p,10) & norm(p(end,2:3)-p0(2:3))>minsize)
                cont=0;
                result=1;
            end;
    
            if(time>maxtime) cont=0; result=0; end;
            if(debugFixation)
                screen('fillrect', el.window, [255 255 255],[p(end,2) p(end,3) p(end,2)+10 p(end,3)+10]);
                screen('flip', el.window);
            end;
        end;
    end;
    [z z keys]=KbCheck;
    if(any(keys)) cont=0; result=0; end;
end;
if(result==0) 
    results=0; %timeout or escape pressed
else
    results = p(end,:)-[p0(1) 0 0]; %return latency and final location
end;

