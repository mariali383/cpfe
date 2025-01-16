function value = turnover_bucket(abnormal_turnover, abnormal_30, abnormal_70)
    % Classification based on the value of abnormal turnover
    if isnan(abnormal_turnover)
        value = blanks(1);
    elseif abnormal_turnover <= abnormal_30
        value = 'P'; 
    elseif abnormal_turnover > abnormal_30 && abnormal_turnover <= abnormal_70
        value = 'M';
    elseif abnormal_turnover > abnormal_70
        value = 'O'; 
    else
        value = blanks(1);
    end
end