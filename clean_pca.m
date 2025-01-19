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
% over 0.24. However, during pandemic, pca3's correlation with HML is poor,
% showing the market's abnormality during pandemic.

% before pandamic:
%            Mkt             SMB           HML
% pca1    0.9960     0.5540    -0.2044 
% pca2   -0.0394   -0.0145    -0.1279 
% pca3    0.0410     -0.5461     0.4547 

% during pandemic:
%            Mkt             SMB           HML
% pca1    0.9905    -0.0023     -0.2791 
% pca2   -0.0458   -0.2510      0.0158 
% pca3    0.0654   -0.5869     -0.0977 

% after pandemic:
%            Mkt             SMB           HML
% pca1    0.9937     0.2487     -0.4659 
% pca2   -0.0447   -0.4147      0.1737 
% pca3    0.0453   -0.3787      0.2417 



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
%   P            0.53          -0.61           -0.59 
%   M            0.56          -0.28            0.78 
%   O            0.64           0.74           -0.19 


%top three PCA factors loadings(after pandemic)
%  Portfolio    Factor1    Factor2    Factor3
%----------------------------------------
%   P            0.55          -0.67           -0.50 
%   M            0.50          -0.21            0.84 
%   O            0.67           0.71           -0.22 
