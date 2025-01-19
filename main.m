%- find industries
%- find data
%- process data + form factors + portfolios
%- perform regression
%- summarise the results

%梁梓庭：ind data + perform regression( CH3 and CH4 ) + turnover factor + CH4 factors
%张梓瑶：MKT + size effect factors + PCA (undate: 张梓瑶 gathered stock price data from RiceQuant 
%Maria：data processing + value effect factors + CH3 factors
% website into stock_data_new.csv; she also downloaded SHIBOR weekly interest rate as sirk free rate to be used in the following work)
%maria: process data + value effect

%need to form return rate like retadj in crsp

dataset=readtable('stock_data_new.csv');
risk_free_rate=readtable('shibor_weekly.xlsx');

%% Data Processing
dataset.date = datetime(dataset.date, 'InputFormat', 'yyyy-MM-dd');
dataset = sortrows(dataset, {'order_book_id', 'date'});  
dataset = dataset(:,(2:end));

dataset.month = month(dataset.date);
dataset.year = year(dataset.date);

% eliminate stocks that have been listed for less than 6 months
[G, order_book_id] = findgroups(dataset.order_book_id);
min_trade_date=groupsummary(dataset,'order_book_id',{'min'},{'date'});
processed_dataset = outerjoin(dataset, min_trade_date(:, {'order_book_id', 'min_date'}), 'Keys', {'order_book_id'}, 'MergeKeys', true, 'Type', 'left');

six_months_ago = datetime(2024, 7, 1);
disp(size(processed_dataset));
% keep the entries which have min date before 6 months ago
processed_dataset = processed_dataset(((processed_dataset.min_date) < six_months_ago), :);
disp(size(processed_dataset));

% eliminate stocks that have less than 120/5 = 24 trading records in the past year
stock_data_by_year_by_stock=groupsummary(processed_dataset,{'order_book_id', 'year'});
processed_dataset = outerjoin(processed_dataset, stock_data_by_year_by_stock, 'Keys', {'order_book_id', 'year'}, 'MergeKeys', true, 'Type', 'left');
disp(size(processed_dataset));
processed_dataset = processed_dataset((processed_dataset.GroupCount) >= 24, :);
disp(size(processed_dataset));

%%
% calculating continuously compounded returns and weight of each stock
[G, id] = findgroups(processed_dataset.order_book_id);  
prevCloseCell = splitapply(@(x) { [NaN; x(1:end-1)] }, processed_dataset.close, G);
prevClose = vertcat(prevCloseCell{:});
processed_dataset.prev_close = prevClose;

processed_dataset.returns = log(processed_dataset.close./processed_dataset.prev_close);

Lme = splitapply(@(x) { [NaN; x(1:end-1)] }, processed_dataset.market_cap, G);%上个月的市值，用于计算wvg
Lme = vertcat(Lme{:});
processed_dataset.lme = Lme; % use previous market capital as weight of each stock


%% Forming MKT factor:  MKT = return of value weighted portfolio (top 70%) of stocks – risk free rate

risk_free_rate= renamevars(risk_free_rate, 'x__', 'date');
merged_data = outerjoin(processed_dataset, risk_free_rate, 'Keys','date', 'MergeKeys',true, 'Type','left');
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
%MKT: 0.9889 (p-value: 1.0007)
%WSMB: 0.5690 (p-value: 0.5914)
%WHML: -0.2608 (p-value: -0.2422)
%R-squared: 0.2795
%F-statistic: 16175.9667 (p-value: 0.0000)

%Mid-Pandemic Regression Results:
%---------------------------------
%Intercept: 0.0227 (p-value: 0.0000)
%MKT: 0.9867 (p-value: 0.9946)
%WSMB: 0.5527 (p-value: 0.5618)
%WHML: -0.1846 (p-value: -0.1761)
%R-squared: 0.1730
%F-statistic: 27454.2447 (p-value: 0.0000)

%Post-Pandemic Regression Results:
%---------------------------------
%Intercept: 0.0211 (p-value: 0.0000)
%MKT: 1.0566 (p-value: 1.0651)
%WSMB: 0.4893 (p-value: 0.4987)
%WHML: -0.1913 (p-value: -0.1811)
%R-squared: 0.2980
%F-statistic: 39236.9104 (p-value: 0.0000)

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
final_dataset.abnormal_turnover = final_dataset.num_trades ./ (final_dataset.turnover_12w_avg * 12);
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
%Intercept: 0.0271 (p-value: 0.0000)
%MKT: 0.9996 (p-value: 1.0143)
%WHML: -0.1851 (p-value: -0.1620)
%WSMB_new: 0.5650 (p-value: 0.5978)
%WPMO: -0.0105 (p-value: 0.0154)
%R-squared: 0.2773
%F-statistic: 9514.9747 (p-value: 0.0000)

%Mid-Pandemic Four-Factor Regression Results (4):
%-----------------------------------------------
%Intercept: 0.0215 (p-value: 0.0000)
%MKT: 0.9859 (p-value: 0.9938)
%WHML: -0.1202 (p-value: -0.1119)
%WSMB_new: 0.5991 (p-value: 0.6089)
%WPMO: -0.0518 (p-value: -0.0401)
%R-squared: 0.1735
%F-statistic: 20653.4048 (p-value: 0.0000)

%Post-Pandemic Four-Factor Regression Results (4):
%------------------------------------------------
%Intercept: 0.0210 (p-value: 0.0000)
%MKT: 1.0515 (p-value: 1.0602)
%WHML: -0.1029 (p-value: -0.0920)
%WSMB_new: 0.5391 (p-value: 0.5494)
%WPMO: -0.0114 (p-value: 0.0012)
%R-squared: 0.2996
%F-statistic: 29641.8156 (p-value: 0.0000)

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
% The turnover factor (WPMO) performed well and remained significant before, during, 
% and after the pandemic. This suggests that in the A-share market, where retail investors dominate, 
% stock prices are significantly influenced by investor sentiment. Particularly during periods of 
% higher market uncertainty, the relationship between investor sentiment and stock price volatility 
% becomes even more pronounced.

%% PCA
%To conduct PCA analysis for different periods across pandemic,
% and to discuss the significance of Turnover factor(PMO), 
% weighted average return rate of each group is calculated 
% according to the classification of turnover_port.

%dropping NaN
final_dataset_4 = final_dataset_4(~ismissing(final_dataset_4.turnover_port),:);
[G, date, turnover_port] = findgroups(final_dataset_4.date, final_dataset_4.turnover_port);
vwet_pca = splitapply(@wavg, final_dataset_4(:,{'returns', 'lme'}), G);
vwet_pca_table = table(vwet_pca, date, turnover_port);
turnover_port_table = unstack(vwet_pca_table, 'vwet_pca', 'turnover_port');

newOrder = {'P', 'M', 'O'};
turnover_port_table = turnover_port_table(:, ['date', newOrder]);

%%
[G, date] = findgroups(final_dataset_4.date);

WSMB_new = splitapply(@mean, final_dataset_4.WSMB_new, G);
WSMB_new = table(date, WSMB_new);

WHML = splitapply(@mean, final_dataset_4.WHML, G);
WHML = table(date, WHML);


% deviding datasets
pre_pandemic_pca = turnover_port_table (turnover_port_table .date <= datetime(2020, 1, 23), :); 
mid_pandemic_pca = turnover_port_table (turnover_port_table .date >= datetime(2020, 1, 24) & turnover_port_table .date <= datetime(2023, 1, 8), :);
post_pandemic_pca = turnover_port_table (turnover_port_table .date >= datetime(2023, 1, 9), :);

pre_MKT = Rmkt(Rmkt.date <= datetime(2020, 1, 23), :);
mid_MKT = Rmkt(Rmkt.date >= datetime(2020, 1, 24) & Rmkt.date <= datetime(2023, 1, 8), :);
post_MKT = Rmkt(Rmkt.date >= datetime(2023, 1, 9), :);

pre_WSMB_new  = WSMB_new (WSMB_new .date <= datetime(2020, 1, 23), :); 
mid_WSMB_new  = WSMB_new (WSMB_new .date >= datetime(2020, 1, 24) & WSMB_new  .date <= datetime(2023, 1, 8), :);
post_WSMB_new  = WSMB_new (WSMB_new .date >= datetime(2023, 1, 9), :);

pre_WHML = WHML(WHML.date<= datetime(2020, 1, 23), :); 
mid_WHML = WHML(WHML.date >= datetime(2020, 1, 24) & WHML .date <= datetime(2023, 1, 8), :);
post_WHML = WHML(WHML.date >= datetime(2023, 1, 9), :);


%% 1. pca analysis: Pre Pandemic
pre_pca_returns = table2array(pre_pandemic_pca(:,2:end));
[pre_coefMatrix,~,~,~,pre_explainedVar] = pca(pre_pca_returns);
pre_PCAfactors = pre_pca_returns*pre_coefMatrix;
pre_pca1=pre_PCAfactors(:,1);
pre_pca2=pre_PCAfactors(:,2);
pre_pca3=pre_PCAfactors(:,3);

% test the relationship between these 3 pca and CH3factor
pre_PCA_Table = table();
pre_PCA_Table.date= pre_pandemic_pca.date;
pre_PCA_Table.PCA1 = pre_pca1;
pre_PCA_Table.PCA2 = pre_pca2;
pre_PCA_Table.PCA3 = pre_pca3;

pre_PCA_Table = outerjoin(pre_PCA_Table, Rmkt,"Keys",'date','MergeKeys', true, 'Type', 'left');
pre_PCA_Table.SMB = table2array(pre_WSMB_new(:,2));
pre_PCA_Table.HML = table2array(pre_WHML(:,2)); 


%
for n_p=2:4
    for n_f=5:7
        cm = corrcoef(table2array(pre_PCA_Table (:,[n_p,n_f])),'row','complete');
        fprintf("%4.4f ", cm(1,2));
    end
    fprintf("\n");
end
fprintf('\n');

%% 2. pca analysis: Mid Pandemic
mid_pca_returns = table2array(mid_pandemic_pca(:,2:end));
[mid_coefMatrix,~,~,~,mid_explainedVar] = pca(mid_pca_returns);
mid_PCAfactors = mid_pca_returns*mid_coefMatrix;
mid_pca1=mid_PCAfactors(:,1);
mid_pca2=mid_PCAfactors(:,2);
mid_pca3=mid_PCAfactors(:,3);

% test the relationship between these 3 pca and CH3factor
mid_PCA_Table = table();
mid_PCA_Table.date= mid_pandemic_pca.date;
mid_PCA_Table.PCA1 = mid_pca1;
mid_PCA_Table.PCA2 = mid_pca2;
mid_PCA_Table.PCA3 = mid_pca3;

mid_PCA_Table = outerjoin(mid_PCA_Table, Rmkt,"Keys",'date','MergeKeys', true, 'Type', 'left');
mid_PCA_Table.SMB = table2array(mid_WSMB_new(:,2));
mid_PCA_Table.HML = table2array(mid_WHML(:,2)); 


%
for n_p=2:4
    for n_f=5:7
        cm = corrcoef(table2array(mid_PCA_Table (:,[n_p,n_f])),'row','complete');
        fprintf("%4.4f ", cm(1,2));
    end
    fprintf("\n");
end
fprintf('\n');

%% 3. pca analysis: Post Pandemic
post_pca_returns = table2array(post_pandemic_pca(:,2:end));
[post_coefMatrix,~,~,~,post_explainedVar] = pca(post_pca_returns);
post_PCAfactors = post_pca_returns*post_coefMatrix;
post_pca1=post_PCAfactors(:,1);
post_pca2=post_PCAfactors(:,2);
post_pca3=post_PCAfactors(:,3);

% test the relationship between these 3 pca and CH3factor
post_PCA_Table = table();
post_PCA_Table.date= post_pandemic_pca.date;
post_PCA_Table.PCA1 = post_pca1;
post_PCA_Table.PCA2 = post_pca2;
post_PCA_Table.PCA3 = post_pca3;

post_PCA_Table = outerjoin(post_PCA_Table, Rmkt,"Keys",'date','MergeKeys', true, 'Type', 'left');
post_PCA_Table.SMB = table2array(post_WSMB_new(:,2));
post_PCA_Table.HML = table2array(post_WHML(:,2)); 

for n_p=2:4
    for n_f=5:7
        cm = corrcoef(table2array(post_PCA_Table (:,[n_p,n_f])),'row','complete');
        fprintf("%4.4f ", cm(1,2));
    end
    fprintf("\n");
end

%% correlation between PCA factors and CH3 factors indicates that:
% pca1 always represents market risk, with a correlation coefficient over 99% for each subsets. 
% pca2's negative correlation with SMB factor magnified during and after pandemic.
% pc3 has a negative correlation with SMB factor for all periods, and 
% has a positive correlation with HML before and after pandemic with a coefficient 
% over 0.22. However, during pandemic, pca3's correlation with HML is poor,
% showing the market's abnormality during pandemic.

% before pandamic:
%            Mkt            SMB           HML
% pca1     0.9961         0.5555       -0.2040  
% pca2    -0.0401        -0.0121       -0.1136 
% pca3     0.0406        -0.5473        0.4558 

% during pandemic:
%            Mkt            SMB           HML
% pca1     0.9904         0.0009       -0.2720 
% pca2    -0.0452        -0.2600        0.0097 
% pca3     0.0648        -0.6219       -0.0999 

% after pandemic:
%            Mkt            SMB           HML
% pca1     0.9938         0.2419       -0.4588 
% pca2    -0.0473        -0.4155        0.1712
% pca3     0.0422        -0.3404        0.2227


%% regression: Pre Pandemic
X_pre_pca = [pre_pca1, pre_pca2, pre_pca3];
y_pre_pca = pre_pandemic_pca(:,2:4);
constant_pre_pca = ones(length(X_pre_pca), 1);
turnover_port_name = ['P', 'M', 'O'];

for i = 1:3
  [pre_b_pca, pre_bint_pca, pre_r_pca ,pre_rint_pca, pre_stats_pca] = regress(table2array(y_pre_pca(:,i)), [constant_pre_pca, pre_PCAfactors(:,1:3)]); 
  residSD_PCA(i) = sqrt(pre_stats_pca(4)); 
  gamma1(i)=pre_b_pca(2);
  gamma2(i)=pre_b_pca(3);
  gamma3(i)=pre_b_pca(4);
end

% display factors
fprintf(1, '\n\n'); 
fprintf(1, 'top three PCA factors loadings(before pandemic)\n'); 
fprintf(1, ...
        '  Portfolio    Factor1    Factor2    Factor3\n');
fprintf(1, ...
        '----------------------------------------\n'); 
for i = 1:3
    fprintf(1, '   %s     %11.2f    %11.2f     %11.2f \n', turnover_port_name(i), gamma1(i), gamma2(i), gamma3(i)); 
end


%% regression: Mid Pandemic
X_mid_pca = [mid_pca1, mid_pca2, mid_pca3];
y_mid_pca = mid_pandemic_pca(:,2:4);
constant_mid_pca = ones(length(X_mid_pca), 1);


for i = 1:3
  [mid_b_pca, mid_bint_pca, mid_r_pca ,mid_rint_pca, mid_stats_pca] = regress(table2array(y_mid_pca(:,i)), [constant_mid_pca, mid_PCAfactors(:,1:3)]); 
  residSD_PCA(i) = sqrt(mid_stats_pca(4)); 
  gamma1(i)=mid_b_pca(2);
  gamma2(i)=mid_b_pca(3);
  gamma3(i)=mid_b_pca(4);
end

% display factors
fprintf(1, '\n\n'); 
fprintf(1, 'top three PCA factors loadings(during pandemic)\n'); 
fprintf(1, ...
        '  Portfolio    Factor1    Factor2    Factor3\n');
fprintf(1, ...
        '----------------------------------------\n'); 
for i = 1:3
    fprintf(1, '   %s     %11.2f    %11.2f     %11.2f \n', turnover_port_name(i), gamma1(i), gamma2(i), gamma3(i)); 
end

%% regression: Post Pandemic
X_post_pca = [post_pca1, post_pca2, post_pca3];
y_post_pca = post_pandemic_pca(:,2:4);
constant_post_pca = ones(length(X_post_pca), 1);


for i = 1:3
  [post_b_pca, post_bint_pca, post_r_pca ,post_rint_pca, post_stats_pca] = regress(table2array(y_post_pca(:,i)), [constant_post_pca, post_PCAfactors(:,1:3)]); 
  residSD_PCA(i) = sqrt(post_stats_pca(4)); 
  gamma1(i)=post_b_pca(2);
  gamma2(i)=post_b_pca(3);
  gamma3(i)=post_b_pca(4);
end

% display factors
fprintf(1, '\n\n'); 
fprintf(1, 'top three PCA factors loadings(after pandemic)\n'); 
fprintf(1, ...
        '  Portfolio    Factor1    Factor2    Factor3\n');
fprintf(1, ...
        '----------------------------------------\n'); 
for i = 1:3
    fprintf(1, '   %s     %11.2f    %11.2f     %11.2f \n', turnover_port_name(i), gamma1(i), gamma2(i), gamma3(i)); 
end


%% Regression Outcome: 
%Portfolios with different turnover sign are exposed to different amount of certain
%risks, which cannot be explained by SMB and HML factors. Expecially for
%Factor2, which has negative coefficients on stocks with low and middle
%abmormal turnover rate, but positice coefficients on stocks with high
%abnormal turnover rate.
%In addition, Factor 3 has positive coeffients on stocks with middle
%abonormal turnover rate, but not on their low and high abnormao
%turnover rate counterparts.
%Therefore, turnover rate effect is considered sort of systematic risk, such that CH4 model 
% explains more information of Chinese stock market than CH3 model.

%top three PCA factors loadings(before pandemic)
%  Portfolio    Factor1    Factor2    Factor3
%----------------------------------------
%   P            0.53          -0.64           -0.56 
%   M            0.50          -0.29            0.81 
%   O            0.68           0.71           -0.16 


%top three PCA factors loadings(during pandemic)
%  Portfolio    Factor1    Factor2    Factor3
%----------------------------------------
%   P            0.53          -0.62           -0.59 
%   M            0.56          -0.27            0.79 
%   O            0.64           0.74           -0.20 


%top three PCA factors loadings(after pandemic)
%  Portfolio    Factor1    Factor2    Factor3
%----------------------------------------
%   P            0.55          -0.67           -0.49 
%   M            0.50          -0.21            0.84 
%   O            0.67           0.71           -0.22 
