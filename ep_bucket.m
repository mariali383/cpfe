function value = ep_bucket(ep_ratio_ttm, ep30, ep70)
%EP_BUCKET Summary of this function goes here
%   row is a table class 
if isnan(ep_ratio_ttm)
    value=blanks(1); 
elseif ep_ratio_ttm<=ep30 && ep_ratio_ttm>=0
    value='L';
elseif ep_ratio_ttm <=ep70 && ep_ratio_ttm>ep30
    value='M';
elseif ep_ratio_ttm>ep70
    value='H';
else
    value=blanks(1);
    
end

