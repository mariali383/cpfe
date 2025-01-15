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
risk_free_rate=readtable('shibor_weekly.xlsx');
%risk_free_rate=readtable('shibor_weekly.csv');

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

% can modify this date...
six_months_ago = datetime(2024, 7, 1);
disp(size(processed_dataset));
% keep the entries which have min date before 6 months ago...
processed_dataset = processed_dataset(((processed_dataset.min_date) < six_months_ago), :);
disp(size(processed_dataset));

% eliminate stocks that have less than 120/7 = 20 trading records in the past year
% can change this number... need to explain this?
stock_data_by_year_by_stock=groupsummary(processed_dataset,{'order_book_id', 'year'});
processed_dataset = outerjoin(processed_dataset, stock_data_by_year_by_stock, 'Keys', {'order_book_id', 'year'}, 'MergeKeys', true, 'Type', 'left');
disp(size(processed_dataset));
processed_dataset = processed_dataset((processed_dataset.GroupCount) >= 20, :);
disp(size(processed_dataset));

% eliminate stocks that have num_trades = 0 ? - should we???
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


%% perhaps need to add ch4 factor?

%% regression...


