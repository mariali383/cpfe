function value = sz_bucket(me,sizemedn)
%SZ_BUCKET Summary of this function goes here，根据公司规模分为大公司B和小公司S
%   row is a table class

if isnan(me)
    value=blanks(1);
elseif me<=sizemedn
    value='S';
elseif me>sizemedn 
    value='B';
else
    value=blanks(1);
end

