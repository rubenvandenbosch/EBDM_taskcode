function drawTextCentred(scr, txt, fgColour, pos)
% drawTextCentred( scr, text, fgColour, pos)
%
% draw text centred on given point (pos)
% if pos is absent, draw text at centre of screen
% scr = screen structure from prepareScreen.


if(exist('pos')~=1)
    pos=scr.centre;
end;

if(~exist('fgColour'))
    fgColour=[255 255 255];
end;

if PsychtoolboxVersion<=2.54
    trs=[length(txt)*32, 40];
else
    [tr]=Screen( scr.w,'TextBounds', txt); trs=[tr(3)-tr(1), tr(4)-tr(2)];
end;
ctrs=pos-trs/2;
Screen( scr.w,'DrawText', txt , ctrs(1),ctrs(2), fgColour);
