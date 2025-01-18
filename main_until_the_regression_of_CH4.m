%- find industries
%- find data
%- process data + form factors + portfolios
%- perform regression
%- summarise the results

%梁梓庭：ind data + perform regression + turnover factor
%张梓瑶：MKT + size effect factors  (undate: 张梓瑶 gathered stock price data from RiceQuant 
% website into stock_data_new.csv; she also downloaded SHIBOR weekly interest rate as sirk free rate to be used in the following work)
%maria: process data + value effect

%need to form return rate like retadj in crsp

dataset=readtable('stock_data_new.csv');
risk_free_rate=readtable('shibor_weekly.xlsx');

%%
dataset.date = datetime(dataset.date, 'InputFormat', 'yyyy-MM-dd');
dataset = sortrows(dataset, {'order_book_id', 'date'});  
dataset = dataset(:,(2:end));

% calculating continuously compounded returns and weight of each stock
[G, id] = findgroups(dataset.order_book_id);  
prevCloseCell = splitapply(@(x) { [NaN; x(1:end-1)] }, dataset.close, G);
prevClose = vertcat(prevCloseCell{:});
dataset.prev_close = prevClose;

dataset.returns = log(dataset.close./dataset.prev_close);

Lme = splitapply(@(x) { [NaN; x(1:end-1)] }, dataset.market_cap, G);%上个月的市值，用于计算wvg
Lme = vertcat(Lme{:});
dataset.lme = Lme; % use previous market capital as weight of each stock


%% Forming MKT factor:  MKT = return of value weighted portfolio (top 70%) of stocks – risk free rate

risk_free_rate= renamevars(risk_free_rate, 'x__', 'date');
merged_data = outerjoin(dataset, risk_free_rate, 'Keys','date', 'MergeKeys',true, 'Type','left');
merged_data.rf = 0.01*merged_data.rf;
merged_data = sortrows(merged_data, {'order_book_id', 'date'});
%dropping NaN
merged_data = merged_data(~ismissing(merged_data.lme), :);

%%
[G, date] = findgroups(merged_data.date);
R_mkt=splitapply(@wavg,merged_data (:,{'returns', 'lme'}),G);
Rmkt = table(date, R_mkt);
merged_data = outerjoin(merged_data, Rmkt, "Keys",'date','MergeKeys',true, 'Type','left');
merged_data.MKT = merged_data.R_mkt - merged_data.rf; % MKT is the market factor.

%% size effect factors SMB
% Specifically, each month we separate the remaining 70% of stocks into two size groups, 
% small (S) and big (B), split at the median market value of that universe. 
% We also break that universe into three EP groups: top 30% (value, V), middle 40% (middle,M), 
% and bottom 30% (growth, G). We then use the intersections of those groups to 
% form value-weighted portfolios for the six resulting size-EP combinations: 
% S/V, S/M, S/G,B/V, B/M, and B/G. When forming value-weighted portfolios, 
% here and throughout the study, we weight each stock by the market capitalization of all 
% its outstanding A shares, including nontradable shares. Our size and value factors,
% denoted as SMB (small-minus-big) and VMG (value-minusgrowth)

[G, date] = findgroups(merged_data.date);
% assigning mid point for each trading day's ME
sizemedn = splitapply(@median, merged_data.market_cap, G);

% Create a table that stores the breakpoint for breakpoints (hs is short
% for 沪深, which means Shanghai and Shenzhen)
hs_breaks=table(date,sizemedn);


prctile_30=@(input)prctile(input,30);% two function handles
prctile_70=@(input)prctile(input,70);


hs_breaks.ep30=splitapply(prctile_30, merged_data.ep_ratio_ttm, G);%splitapply(函数，要split的变量)
hs_breaks.ep70=splitapply(prctile_70, merged_data.ep_ratio_ttm, G);


merged_data1 = outerjoin(merged_data, hs_breaks, 'Keys',{'date'},'MergeKeys',true,'Type','left');

% Assign size portfolios，divide firms into different groups and buckets
szport=rowfun(@sz_bucket,merged_data1(:,{'market_cap','sizemedn'}),'OutputFormat','cell'); %doc rowfun: Apply function to table or timetable rows
merged_data1.szport=cell2mat(szport); 

%% 
% Assign value portfolios using ep ratio
ep_port = rowfun(@ep_bucket, merged_data1(:, {'ep_ratio_ttm', 'ep30', 'ep70'}), 'OutputFormat', 'cell');
merged_data1.ep_port = cell2mat(ep_port);

%%
% skipped merging back with monthly records?

% Keep only records that meet the criteria, drop missing observations
% delete records with market_cap <= 0?
x=char(0); 
disp(size(merged_data1));
merged_data2= merged_data1((merged_data1.lme>0)& (merged_data1.market_cap>0) & (merged_data1.ep_ratio_ttm>0) & ~(merged_data1.szport==x)& ~(merged_data1.ep_port==x)...
  &~ismissing(merged_data1.szport)&~ismissing(merged_data1.ep_port)...
  & ~(merged_data1.ep_port==blanks(1))& ~(merged_data1.szport == blanks(1)),:);
disp(size(merged_data2));

%% Form CH3 Factors

% Create group of portfolios
[G,date,szport, ep_port]=findgroups(merged_data2.date,merged_data2.szport,merged_data2.ep_port);

% weighting by lme?
vwret=splitapply(@wavg,merged_data2(:,{'returns','lme'}),G);

% Create labels for the portfolios
seport=strcat(szport,ep_port);
seport=cellstr(seport);
vwret_table=table(vwret,date,szport,ep_port,seport);

% Reshape the dataset into a a table for portfolio return organized with
% date in ascending order. This faciliates the creation of factors

ch3_factors=unstack(vwret_table(:,{'vwret','date','seport'}),'vwret','seport');

%create SMB and HML factors
ch3_factors.WH=(ch3_factors.BH+ch3_factors.SH)/2;
ch3_factors.WL=(ch3_factors.BL+ch3_factors.SL)/2;
ch3_factors.WHML=ch3_factors.WH-ch3_factors.WL;

ch3_factors.WB=(ch3_factors.BL+ch3_factors.BM+ch3_factors.BH)/3;
ch3_factors.WS=(ch3_factors.SL+ch3_factors.SM+ch3_factors.SH)/3;
ch3_factors.WSMB=ch3_factors.WS-ch3_factors.WB;

%% Regression of CH-3

% merge WHML and WSMB into merged_data2 
ch3_factors.date = datetime(ch3_factors.date); 
merged_data2.date = datetime(merged_data2.date);
final_dataset = outerjoin(merged_data2, ch3_factors(:, {'date', 'WHML', 'WSMB'}), 'Keys', 'date', 'MergeKeys', true, 'Type', 'left');

%% 
% Define time periods for pre-pandemic, mid-pandemic and post-pandemic
pre_pandemic = final_dataset(final_dataset.date <= datetime(2020, 1, 23), :); 
mid_pandemic = final_dataset(final_dataset.date >= datetime(2020, 1, 24) & final_dataset.date <= datetime(2023, 1, 8), :);
post_pandemic = final_dataset(final_dataset.date >= datetime(2023, 1, 9), :);

% Define the variables for the regression model
y_pre = pre_pandemic.returns;
X_pre = [pre_pandemic.MKT, pre_pandemic.WSMB, pre_pandemic.WHML];

y_mid = mid_pandemic.returns;
X_mid = [mid_pandemic.MKT,mid_pandemic.WSMB, mid_pandemic.WHML];

y_post = post_pandemic.returns;
X_post = [post_pandemic.MKT,post_pandemic.WSMB, post_pandemic.WHML];

% intercept term
X_pre = [ones(size(X_pre, 1), 1), X_pre];
X_mid = [ones(size(X_mid, 1), 1), X_mid];
X_post = [ones(size(X_post, 1), 1), X_post];

% Perform regression of pre-pandemic, mid-pandemic and post-pandemic
[b_pre, bint_pre, r_pre, rint_pre, stats_pre] = regress(y_pre, X_pre);
[b_mid, bint_mid, r_mid, rint_mid, stats_mid] = regress(y_mid, X_mid);
[b_post, bint_post, r_post, rint_post, stats_post] = regress(y_post, X_post);

% Display the regression results for pre-pandemic, mid-pandemic, and post-pandemic
fprintf('Pre-Pandemic Regression Results:\n');
fprintf('---------------------------------\n');
fprintf('Intercept: %.4f (p-value: %.4f)\n', b_pre(1), stats_pre(3));
fprintf('MKT: %.4f (p-value: %.4f)\n', b_pre(2), bint_pre(2,2)); % p-value from confidence interval
fprintf('WSMB: %.4f (p-value: %.4f)\n', b_pre(3), bint_pre(3,2)); % p-value from confidence interval
fprintf('WHML: %.4f (p-value: %.4f)\n', b_pre(4), bint_pre(4,2)); % p-value from confidence interval
fprintf('R-squared: %.4f\n', stats_pre(1));
fprintf('F-statistic: %.4f (p-value: %.4f)\n\n', stats_pre(2), stats_pre(3));

fprintf('Mid-Pandemic Regression Results:\n');
fprintf('---------------------------------\n');
fprintf('Intercept: %.4f (p-value: %.4f)\n', b_mid(1), stats_mid(3));
fprintf('MKT: %.4f (p-value: %.4f)\n', b_mid(2), bint_mid(2,2));
fprintf('WSMB: %.4f (p-value: %.4f)\n', b_mid(3), bint_mid(3,2));
fprintf('WHML: %.4f (p-value: %.4f)\n', b_mid(4), bint_mid(4,2));
fprintf('R-squared: %.4f\n', stats_mid(1));
fprintf('F-statistic: %.4f (p-value: %.4f)\n\n', stats_mid(2), stats_mid(3));

fprintf('Post-Pandemic Regression Results:\n');
fprintf('---------------------------------\n');
fprintf('Intercept: %.4f (p-value: %.4f)\n', b_post(1), stats_post(3));
fprintf('MKT: %.4f (p-value: %.4f)\n', b_post(2), bint_post(2,2));
fprintf('WSMB: %.4f (p-value: %.4f)\n', b_post(3), bint_post(3,2));
fprintf('WHML: %.4f (p-value: %.4f)\n', b_post(4), bint_post(4,2));
fprintf('R-squared: %.4f\n', stats_post(1));
fprintf('F-statistic: %.4f (p-value: %.4f)\n', stats_post(2), stats_post(3));

%Pre-Pandemic Regression Results:
%---------------------------------
%Intercept: 0.0276 (p-value: 0.0000)
%MKT: 0.9890 (p-value: 1.0008)
%WSMB: 0.5696 (p-value: 0.5920)
%WHML: -0.2608 (p-value: -0.2422)
%R-squared: 0.2769
%F-statistic: 16098.9814 (p-value: 0.0000)

%Mid-Pandemic Regression Results:
%---------------------------------
%Intercept: 0.0228 (p-value: 0.0000)
%MKT: 0.9863 (p-value: 0.9942)
%WSMB: 0.5541 (p-value: 0.5631)
%WHML: -0.1836 (p-value: -0.1752)
%R-squared: 0.1714
%F-statistic: 27419.3489 (p-value: 0.0000)

%Post-Pandemic Regression Results:
%---------------------------------
%Intercept: 0.0212 (p-value: 0.0000)
%MKT: 1.0582 (p-value: 1.0668)
%WSMB: 0.4887 (p-value: 0.4981)
%WHML: -0.1917 (p-value: -0.1815)
%R-squared: 0.2967
%F-statistic: 39141.8123 (p-value: 0.0000)

%1、In the three-factor model, for all three periods (pre-pandemic, mid-pandemic, and post-pandemic), 
% the three factors do not appear to have a statistically significant impact on stock market returns.
%2、The decline in the R-squared value during the pandemic suggests that the model's explanatory power 
% was noticeably weaker during the pandemic compared to the pre- and post-pandemic periods. This may 
% indicate that the stock market exhibited increased volatility during the pandemic, related to 
% macroeconomic uncertainty and industry changes.
%3、Prior to the pandemic, the market was in a relatively stable state. After the pandemic, 
% the stock market showed signs of recovery.

% The MKT factor is close to 1 before, during, and after the pandemic, while the WSMB factor 
% is positive in all three periods. In contrast, the WHML factor is negative in all three stages. 
% This suggests that in the Chinese market, small-cap stocks outperform large-cap stocks, while the 
%value premium is not significant.

%%  Liu 2019 CH4 model
%%  Turnover factor
% Liu believes that excessive stock turnover is a sign of irrational behavior by retail 
% and individual investors in the stock market, who chase rising prices. However, stock 
% prices will eventually revert to rational levels, so investors should buy currently 
% pessimistic (low-turnover) stocks and sell currently optimistic (high-turnover) stocks. 
% To account for the impact of investor sentiment, Liu constructed a turnover factor called 
% PMO (Pessimistic Minus Optimistic).

% Since we are using weekly data, and based on the construction method from Liu (2019), 
% we select a 12-week rolling window to calculate the moving average. We then further 
% divide the turnover quantity of the current week by the moving average turnover quantity 
% to obtain the abnormal turnover.

new_table = final_dataset(:, {'date', 'order_book_id', 'num_trades'});
unstacked_data = unstack(new_table, 'num_trades', 'order_book_id');

moving_avg_data = movmean(unstacked_data{:, 2:end}, 12, 'Endpoints', 'discard');
moving_avg_table = array2table(moving_avg_data, 'VariableNames', unstacked_data.Properties.VariableNames(2:end));
%% 
date_without_11 = unstacked_data.date(12:end);
moving_avg_table = [table(date_without_11, 'VariableNames', {'date'}), moving_avg_table];
%% 
% stack back
moving_avg_table.date = datetime(moving_avg_table.date);
stacked_table = stack(moving_avg_table, 2:width(moving_avg_table), 'NewDataVariableName', 'turnover_12w_avg', 'IndexVariableName', 'order_book_id');

%% innerjoin turnover average（12 weeks）
%stacked_table.order_book_id = string(stacked_table.order_book_id);
%stacked_table.order_book_id = string(cellfun(@(x) x(2:end), cellstr(stacked_table.order_book_id), 'UniformOutput', false));
final_dataset.order_book_id = string(final_dataset.order_book_id);
stacked_table.order_book_id = string(stacked_table.order_book_id);
%% 
final_dataset.order_book_id = extractBefore(final_dataset.order_book_id, 7);
%% 
% This line could cause an error if run repeatedly.
%
%
%
stacked_table.order_book_id = extractBetween(stacked_table.order_book_id, 2, 7);
%%
final_dataset = innerjoin(final_dataset, stacked_table, ...
    'Keys', {'date', 'order_book_id'}, 'RightVariables', {'turnover_12w_avg'});
% abnormal_turnover
final_dataset.abnormal_turnover = final_dataset.num_trades ./ final_dataset.turnover_12w_avg;
%% turnover factor
[G, date] = findgroups(final_dataset.date);
sizemedn_to = splitapply(@median, final_dataset.abnormal_turnover, G);

prctile_30 = @(input) prctile(input, 30); 
prctile_70 = @(input) prctile(input, 70); 

to_breaks = table(date, sizemedn_to);
to_breaks.abnormal_30 = splitapply(prctile_30, final_dataset.abnormal_turnover, G);
to_breaks.abnormal_70 = splitapply(prctile_70, final_dataset.abnormal_turnover, G);

final_dataset_4 = outerjoin(final_dataset, to_breaks, 'Keys', {'date'}, 'MergeKeys', true, 'Type', 'left');

% Creating abnormal_turnover Categories (O, P, M) using rowfun
turnover_port = rowfun(@turnover_bucket, final_dataset_4(:, {'abnormal_turnover', 'abnormal_30', 'abnormal_70'}), 'OutputFormat', 'cell');
final_dataset_4.turnover_port = cell2mat(turnover_port);

%% Form CH4 Factors

% Create group of portfolios
[G,date,szport,turnover_port]=findgroups(final_dataset_4.date,final_dataset_4.szport,final_dataset_4.turnover_port);

% weighting by lme
vwret_4=splitapply(@wavg,final_dataset_4(:,{'returns','lme'}),G);

% Create labels for the portfolios
stport_4=strcat(szport,turnover_port);
stport_4=cellstr(stport_4);
vwret_table_4=table(vwret_4,date,szport,turnover_port,stport_4);

% Reshape the dataset
ch4_factors=unstack(vwret_table_4(:,{'vwret_4','date','stport_4'}),'vwret_4','stport_4');

%% 
% According to Fama and French (2015), after adding the turnover factor, 
% the size factor will undergo some changes, so it is necessary to reconstruct the SMB factor.
% create new SMB factors and PMO factors
ch4_factors.WB=(ch4_factors.BO+ch4_factors.BM+ch4_factors.BP)/3;
ch4_factors.WS=(ch4_factors.SO+ch4_factors.SM+ch4_factors.SP)/3;
ch4_factors.WSMB_turnover=ch4_factors.WS-ch4_factors.WB;
ch3_factors = ch3_factors(12:end, :);
ch4_factors.WSMB_new = (ch3_factors.WSMB + ch4_factors.WSMB_turnover)/2;

ch4_factors.WP=(ch4_factors.SP+ch4_factors.BP)/2;
ch4_factors.WO=(ch4_factors.SO+ch4_factors.BO)/2;
ch4_factors.WPMO=ch4_factors.WP-ch4_factors.WO;

%% Regression of CH-4
final_dataset_4 = outerjoin(final_dataset_4, ch4_factors(:, {'date', 'WPMO', 'WSMB_new'}), 'Keys', 'date', 'MergeKeys', true, 'Type', 'left');

pre_pandemic4 = final_dataset_4(final_dataset_4.date <= datetime(2020, 1, 23), :); 
mid_pandemic4 = final_dataset_4(final_dataset_4.date >= datetime(2020, 1, 24) & final_dataset_4.date <= datetime(2023, 1, 8), :);
post_pandemic4 = final_dataset_4(final_dataset_4.date >= datetime(2023, 1, 9), :);

% Define the variables for the regression model （CH-4）
y_pre_4 = pre_pandemic4.returns;
X_pre_4 = [pre_pandemic4.MKT, pre_pandemic4.WHML, pre_pandemic4.WSMB_new, pre_pandemic4.WPMO];

y_mid_4 = mid_pandemic4.returns;
X_mid_4 = [mid_pandemic4.MKT, mid_pandemic4.WHML, mid_pandemic4.WSMB_new, mid_pandemic4.WPMO];

y_post_4 = post_pandemic4.returns;
X_post_4 = [post_pandemic4.MKT, post_pandemic4.WHML, post_pandemic4.WSMB_new, post_pandemic4.WPMO];

% intercept term(CH-4)
X_pre_4 = [ones(size(X_pre_4, 1), 1), X_pre_4]; 
X_mid_4 = [ones(size(X_mid_4, 1), 1), X_mid_4];
X_post_4 = [ones(size(X_post_4, 1), 1), X_post_4];

% Perform regression of pre-pandemic, mid-pandemic and post-pandemic under CH-4
[b_pre_4, bint_pre_4, r_pre_4, rint_pre_4, stats_pre_4] = regress(y_pre_4, X_pre_4);
[b_mid_4, bint_mid_4, r_mid_4, rint_mid_4, stats_mid_4] = regress(y_mid_4, X_mid_4);
[b_post_4, bint_post_4, r_post_4, rint_post_4, stats_post_4] = regress(y_post_4, X_post_4);

% Display the regression results for pre-pandemic, mid-pandemic, and post-pandemic
fprintf('Pre-Pandemic Four-Factor Regression Results (4):\n');
fprintf('-----------------------------------------------\n');
fprintf('Intercept: %.4f (p-value: %.4f)\n', b_pre_4(1), stats_pre_4(3));
fprintf('MKT: %.4f (p-value: %.4f)\n', b_pre_4(2), bint_pre_4(2,2));
fprintf('WHML: %.4f (p-value: %.4f)\n', b_pre_4(3), bint_pre_4(3,2));
fprintf('WSMB_new: %.4f (p-value: %.4f)\n', b_pre_4(4), bint_pre_4(4,2));
fprintf('WPMO: %.4f (p-value: %.4f)\n', b_pre_4(5), bint_pre_4(5,2));
fprintf('R-squared: %.4f\n', stats_pre_4(1));
fprintf('F-statistic: %.4f (p-value: %.4f)\n\n', stats_pre_4(2), stats_pre_4(3));

fprintf('Mid-Pandemic Four-Factor Regression Results (4):\n');
fprintf('-----------------------------------------------\n');
fprintf('Intercept: %.4f (p-value: %.4f)\n', b_mid_4(1), stats_mid_4(3));
fprintf('MKT: %.4f (p-value: %.4f)\n', b_mid_4(2), bint_mid_4(2,2));
fprintf('WHML: %.4f (p-value: %.4f)\n', b_mid_4(3), bint_mid_4(3,2));
fprintf('WSMB_new: %.4f (p-value: %.4f)\n', b_mid_4(4), bint_mid_4(4,2));
fprintf('WPMO: %.4f (p-value: %.4f)\n', b_mid_4(5), bint_mid_4(5,2));
fprintf('R-squared: %.4f\n', stats_mid_4(1));
fprintf('F-statistic: %.4f (p-value: %.4f)\n\n', stats_mid_4(2), stats_mid_4(3));

fprintf('Post-Pandemic Four-Factor Regression Results (4):\n');
fprintf('------------------------------------------------\n');
fprintf('Intercept: %.4f (p-value: %.4f)\n', b_post_4(1), stats_post_4(3));
fprintf('MKT: %.4f (p-value: %.4f)\n', b_post_4(2), bint_post_4(2,2));
fprintf('WHML: %.4f (p-value: %.4f)\n', b_post_4(3), bint_post_4(3,2));
fprintf('WSMB_new: %.4f (p-value: %.4f)\n', b_post_4(4), bint_post_4(4,2));
fprintf('WPMO: %.4f (p-value: %.4f)\n', b_post_4(5), bint_post_4(5,2));
fprintf('R-squared: %.4f\n', stats_post_4(1));
fprintf('F-statistic: %.4f (p-value: %.4f)\n', stats_post_4(2), stats_post_4(3));

%Pre-Pandemic Four-Factor Regression Results (4):
%-----------------------------------------------
%Intercept: 0.0270 (p-value: 0.0000)
%MKT: 0.9989 (p-value: 1.0136)
%WHML: -0.1829 (p-value: -0.1597)
%WSMB_new: 0.5667 (p-value: 0.5996)
%WPMO: -0.0156 (p-value: 0.0103)
%R-squared: 0.2740
%F-statistic: 9451.4790 (p-value: 0.0000)

%Mid-Pandemic Four-Factor Regression Results (4):
%-----------------------------------------------
%Intercept: 0.0213 (p-value: 0.0000)
%MKT: 0.9862 (p-value: 0.9941)
%WHML: -0.1208 (p-value: -0.1124)
%WSMB_new: 0.5993 (p-value: 0.6090)
%WPMO: -0.0559 (p-value: -0.0440)
%R-squared: 0.1719
%F-statistic: 20635.0242 (p-value: 0.0000)

%Post-Pandemic Four-Factor Regression Results (4):
%------------------------------------------------
%Intercept: 0.0210 (p-value: 0.0000)
%MKT: 1.0526 (p-value: 1.0613)
%WHML: -0.1033 (p-value: -0.0924)
%WSMB_new: 0.5392 (p-value: 0.5495)
%WPMO: -0.0082 (p-value: 0.0043)
%R-squared: 0.2982
%F-statistic: 29570.5880 (p-value: 0.0000)

% The explanatory power of the four-factor model is similar to that of the three-factor model.
% Prior to the pandemic, the stock market was relatively stable, allowing the factor model 
% to price stocks to some extent. During the pandemic, the decline in the R-squared value 
% indicates that the model's explanatory power was noticeably weaker during the pandemic 
% compared to the pre- and post-pandemic periods. This may suggest that the stock market 
% exhibited increased volatility during the pandemic, influenced by macroeconomic uncertainty 
% and industry changes. After the pandemic, the stock market's stability was relatively restored, 
% leading to an improvement in the model's explanatory power.

% The coefficient of the market factor changed relatively little, remaining close to 1 
% in all three periods. 
% The coefficient of the value factor (WHML) was consistently negative across all periods, 
% indicating that value stocks underperformed during the pre-pandemic, mid-pandemic, 
% and post-pandemic periods. The size factor (WSMB_new) was positive in all three periods, 
% suggesting that small-cap stocks outperformed large-cap stocks throughout. 
% The effect of the turnover factor (WPMO) increased during the pandemic and approached significance, 
% indicating that during periods of higher market uncertainty, investor sentiment became more closely 
% linked to stock price volatility.