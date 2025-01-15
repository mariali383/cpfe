%- find industries
%- find data
%- process data + form factors + portfolios
%- perform regression
%- summarise the results

%梁梓庭：ind data + perform regression
%张梓瑶：MKT + size effect factors  (undate: 张梓瑶 gathered stock price data from RiceQuant 
% website into stock_data_new.csv; she also downloaded SHIBOR weekly interest rate as sirk free rate to be used in the following work)
%maria: process data + value effect

%need to form return rate like retadj in crsp

dataset=readtable('stock_data_new.csv');
risk_free_rate=readtable('shibor_weekly.csv');

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


hs_breaks.bm30=splitapply(prctile_30, merged_data.ep_ratio_ttm, G);%splitapply(函数，要split的变量)
hs_breaks.bm70=splitapply(prctile_70, merged_data.ep_ratio_ttm, G);


merged_data1 = outerjoin(merged_data, hs_breaks, 'Keys',{'date'},'MergeKeys',true,'Type','left');

% Assign size portfolios，divide firms into different groups and buckets
szport=rowfun(@sz_bucket,merged_data1(:,{'market_cap','sizemedn'}),'OutputFormat','cell'); %doc rowfun: Apply function to table or timetable rows
merged_data1.szport=cell2mat(szport); 



