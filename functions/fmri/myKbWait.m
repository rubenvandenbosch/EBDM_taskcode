function myKbWait(ex)
if ex.useBitsiBB
    ex.BitsiBB.clearResponses(); % empty input buffer
    [resp, time_resp] = ex.BitsiBB.getResponse(Inf, true); % wait for any button press
else
    KbWait();
end
