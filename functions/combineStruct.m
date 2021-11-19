function a1=combineStruct(a1, a2)
%copy all fields in a2 into a1, overwriting any identically named fields in a1
f=fieldnames(a2);
for i=1:length(f)
    a1=setfield(a1, f{i}, getfield(a2, f{i}));
end;
