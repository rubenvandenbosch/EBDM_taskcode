function a1 = combineStruct(a1, a2)
% a1 = combineStruct(a1, a2)
% Copy all fields of struct a2 into struct a1, overwriting any identically 
% named fields in a1.
%

assert(isstruct(a1) && isstruct(a2), 'Input arguments should be of class struct');

fields = fieldnames(a2);
for ix = 1:numel(fields)
    a1.(fields{ix}) = a2.(fields{ix});
end
