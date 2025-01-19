CPFE Project
The Shock of the Pandemic on the Explanatory Power of China's Asset Pricing Models: A China-Adapted Factor Model Based on Liu (2019)

In class, we learned how to construct the Fama-French three-factor model and how to analyze the effects of the factors. Based on our ability to process and analyze data using MATLAB, we aim to conduct a trial using Chinese financial data.

The COVID-19 pandemic has had a tremendous impact on China's production and consumption sectors. In this unique context, is the factor model pricing still effective? Is the China-adapted four-factor pricing model based on Liu (2019) effective? Are there differences in factor characteristics before, during, and after the pandemic? These are the questions we aim to explore.

We collected the necessary data before, during and after the pandemic, defining January 23, 2020, and earlier as the pre-pandemic period, and after January 9, 2023, as the post-pandemic period. We selected weekly data for analysis. 

Based on Liu (2019)'s practice of removing shell value from the Chinese market, we excluded the smallest 30% of stocks by market capitalization, as well as those with fewer than 6 months listed or fewer than 120 trading records in the past year/less than 15 trading records in the past month.

Additionally, based on the characteristics of the Chinese market, we used the reciprocal of the Price-to-Earnings (PE) ratio, known as the Earnings-to-Price (EP) ratio, to replace the Book-to-Market (BM) ratio, thus replicating the China-specific treatment.

We first conducted a regression using the three factors and found that the model's explanatory power was different before and after the pandemic, with a noticeable decrease during the pandemic. However, the effectiveness remains limited.

We referred to Liu (2019) to construct a turnover factor to capture investor sentiment. This is particularly relevant in China's A-share market, where retail investors are numerous, and investor sentiment significantly influences stock price movements. We used a 12-week moving average to calculate turnover volume. The turnover rate indicator was constructed by dividing the current week's turnover volume by the moving average. Using this turnover rate, we created the PMO (Turnover Factor). It is worth noting that after constructing the turnover factor, the original paper rebuilt the SMB factor, and we also replicated this detail.

After regression, we found that, in addition to the reduced explanatory power during the pandemic, the turnover rate factor was effective.

Finally, based on the assets classified by the turnover factor, we performed principal component analysis and observed the correlation between the first three principal components and the three-factor model.

This is the logic of our research.

To be more specific：

The explanation of the main data used in our stock_data_new is as follows:
order_book_id: the column storing stock index numbers
volume: the amount for which each a specific stock has been traded on that trading day
close: the close price of a specific stock on that trading day; this column is the stock price I will use for cunducting stock returns
high / low: the highest / lowest price a specific stock achieved on that trading day;
total_turnover: the sum of money a specific stock has been traded for on that trading day;
num_trades: the number of trades achieved for a specific stock n that trading day;
prev_close: close price of a stock on the last trading day; I will use it to compute stock returns;
market_cap: market capitalization of the company. This is the parameter to be used to conduct our SMB factor;
ep_ratio_ttm: 盈市率 ttm, 连续四季度报表披露归属母公司净利润之和 / 当前股票总市值: net_profit_parent_company_ttm_0 / market_cap_3, this is the EP parameter the paper suggested for constructing HML factor.

Regression Results of the China-Adapted Three-Factor Model:
Pre-Pandemic Regression Results:
---------------------------------
Intercept: 0.0276 (p-value: 0.0000)
MKT: 0.9889 (p-value: 1.0007)
WSMB: 0.5690 (p-value: 0.5914)
WHML: -0.2608 (p-value: -0.2422)
R-squared: 0.2795
F-statistic: 16175.9667 (p-value: 0.0000)

Mid-Pandemic Regression Results:
---------------------------------
Intercept: 0.0227 (p-value: 0.0000)
MKT: 0.9867 (p-value: 0.9946)
WSMB: 0.5527 (p-value: 0.5618)
WHML: -0.1846 (p-value: -0.1761)
R-squared: 0.1730
F-statistic: 27454.2447 (p-value: 0.0000)

Post-Pandemic Regression Results:
---------------------------------
Intercept: 0.0211 (p-value: 0.0000)
MKT: 1.0566 (p-value: 1.0651)
WSMB: 0.4893 (p-value: 0.4987)
WHML: -0.1913 (p-value: -0.1811)
R-squared: 0.2980
F-statistic: 39236.9104 (p-value: 0.0000)

1、In the three-factor model, for all three periods (pre-pandemic, mid-pandemic, and post-pandemic), 
 the three factors do not appear to have a statistically significant impact on stock market returns.
2、The decline in the R-squared value during the pandemic suggests that the model's explanatory power 
 was noticeably weaker during the pandemic compared to the pre- and post-pandemic periods. This may 
 indicate that the stock market exhibited increased volatility during the pandemic, related to 
 macroeconomic uncertainty and industry changes.
3、Prior to the pandemic, the market was in a relatively stable state. After the pandemic, 
 the stock market showed signs of recovery.

The MKT factor is close to 1 before, during, and after the pandemic, while the WSMB factor 
is positive in all three periods. In contrast, the WHML factor is negative in all three stages. 
This suggests that in the Chinese market, small-cap stocks outperform large-cap stocks, while the 
value premium is not significant.

Regression Results of the China-Adapted Four-Factor Model (CH-4 of Liu 2019):
Pre-Pandemic Four-Factor Regression Results (4):
-----------------------------------------------
Intercept: 0.0271 (p-value: 0.0000)
MKT: 0.9996 (p-value: 1.0143)
WHML: -0.1851 (p-value: -0.1620)
WSMB_new: 0.5650 (p-value: 0.5978)
WPMO: -0.0105 (p-value: 0.0154)
R-squared: 0.2773
F-statistic: 9514.9747 (p-value: 0.0000)

Mid-Pandemic Four-Factor Regression Results (4):
-----------------------------------------------
Intercept: 0.0215 (p-value: 0.0000)
MKT: 0.9859 (p-value: 0.9938)
WHML: -0.1202 (p-value: -0.1119)
WSMB_new: 0.5991 (p-value: 0.6089)
WPMO: -0.0518 (p-value: -0.0401)
R-squared: 0.1735
F-statistic: 20653.4048 (p-value: 0.0000)

Post-Pandemic Four-Factor Regression Results (4):
------------------------------------------------
Intercept: 0.0210 (p-value: 0.0000)
MKT: 1.0515 (p-value: 1.0602)
WHML: -0.1029 (p-value: -0.0920)
WSMB_new: 0.5391 (p-value: 0.5494)
WPMO: -0.0114 (p-value: 0.0012)
R-squared: 0.2996
F-statistic: 29641.8156 (p-value: 0.0000)

The explanatory power of the four-factor model is similar to that of the three-factor model.
Prior to the pandemic, the stock market was relatively stable, allowing the factor model 
to price stocks to some extent. During the pandemic, the decline in the R-squared value 
indicates that the model's explanatory power was noticeably weaker during the pandemic 
compared to the pre- and post-pandemic periods. This may suggest that the stock market 
exhibited increased volatility during the pandemic, influenced by macroeconomic uncertainty 
and industry changes. After the pandemic, the stock market's stability was relatively restored, 
leading to an improvement in the model's explanatory power.

The coefficient of the market factor changed relatively little, remaining close to 1 
in all three periods. 
The coefficient of the value factor (WHML) was consistently negative across all periods, 
indicating that value stocks underperformed during the pre-pandemic, mid-pandemic, 
and post-pandemic periods. The size factor (WSMB_new) was positive in all three periods, 
suggesting that small-cap stocks outperformed large-cap stocks throughout. 
The turnover factor (WPMO) performed well and remained significant before, during, 
and after the pandemic. This suggests that in the A-share market, where retail investors dominate, 
stock prices are significantly influenced by investor sentiment. Particularly during periods of 
higher market uncertainty, the relationship between investor sentiment and stock price volatility 
becomes even more pronounced.

PCA result：
------------------------------------------------
pca1 always represents market risk, with a correlation coefficient over 99% for each subsets. 
pca2's negative correlation with SMB factor magnified during and after pandemic.
pc3 has a negative correlation with SMB factor for all periods, and 
has a positive correlation with HML before and after pandemic with a coefficient 
over 0.22. However, during pandemic, pca3's correlation with HML is poor,
showing the market's abnormality during pandemic.

before pandamic: 
          Mkt            SMB           HML
pca1     0.9961         0.5555       -0.2040  
pca2    -0.0401        -0.0121       -0.1136 
pca3     0.0406        -0.5473        0.4558 

during pandemic:
          Mkt            SMB           HML
pca1     0.9904         0.0009       -0.2720 
pca2    -0.0452        -0.2600        0.0097 
pca3     0.0648        -0.6219       -0.0999 

after pandemic:
           Mkt            SMB           HML
pca1     0.9938         0.2419       -0.4588 
pca2    -0.0473        -0.4155        0.1712
pca3     0.0422        -0.3404        0.2227

Regression Outcome: 
Portfolios with different turnover sign are exposed to different amount of certain
risks, which cannot be explained by SMB and HML factors. Expecially for
Factor2, which has negative coefficients on stocks with low and middle
abmormal turnover rate, but positice coefficients on stocks with high abnormal turnover rate.
In addition, Factor 3 has positive coeffients on stocks with middle
abonormal turnover rate, but not on their low and high abnormao turnover rate counterparts.
Therefore, turnover rate effect is considered sort of systematic risk, such that CH4 model 
explains more information of Chinese stock market than CH3 model.

top three PCA factors loadings(before pandemic)
  Portfolio    Factor1    Factor2    Factor3
----------------------------------------
   P            0.53          -0.64           -0.56 
   M            0.50          -0.29            0.81 
   O            0.68           0.71           -0.16 

top three PCA factors loadings(during pandemic)
  Portfolio    Factor1    Factor2    Factor3
----------------------------------------
   P            0.53          -0.62           -0.59 
   M            0.56          -0.27            0.79 
   O            0.64           0.74           -0.20 

top three PCA factors loadings(after pandemic)
  Portfolio    Factor1    Factor2    Factor3
----------------------------------------
   P            0.55          -0.67           -0.49 
   M            0.50          -0.21            0.84 
   O            0.67           0.71           -0.22 





