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
MKT: 0.9890 (p-value: 1.0008)
WSMB: 0.5696 (p-value: 0.5920)
WHML: -0.2608 (p-value: -0.2422)
R-squared: 0.2769
F-statistic: 16098.9814 (p-value: 0.0000)

Mid-Pandemic Regression Results:
---------------------------------
Intercept: 0.0228 (p-value: 0.0000)
MKT: 0.9863 (p-value: 0.9942)
WSMB: 0.5541 (p-value: 0.5631)
WHML: -0.1836 (p-value: -0.1752)
R-squared: 0.1714
F-statistic: 27419.3489 (p-value: 0.0000)

Post-Pandemic Regression Results:
---------------------------------
Intercept: 0.0212 (p-value: 0.0000)
MKT: 1.0582 (p-value: 1.0668)
WSMB: 0.4887 (p-value: 0.4981)
WHML: -0.1917 (p-value: -0.1815)
R-squared: 0.2967
F-statistic: 39141.8123 (p-value: 0.0000)

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
Intercept: 0.0270 (p-value: 0.0000)
MKT: 0.9989 (p-value: 1.0136)
WHML: -0.1829 (p-value: -0.1597)
WSMB_new: 0.5667 (p-value: 0.5996)
WPMO: -0.0156 (p-value: 0.0103)
R-squared: 0.2740
F-statistic: 9451.4790 (p-value: 0.0000)

Mid-Pandemic Four-Factor Regression Results (4):
-----------------------------------------------
Intercept: 0.0213 (p-value: 0.0000)
MKT: 0.9862 (p-value: 0.9941)
WHML: -0.1208 (p-value: -0.1124)
WSMB_new: 0.5993 (p-value: 0.6090)
WPMO: -0.0559 (p-value: -0.0440)
R-squared: 0.1719
F-statistic: 20635.0242 (p-value: 0.0000)

Post-Pandemic Four-Factor Regression Results (4):
------------------------------------------------
Intercept: 0.0210 (p-value: 0.0000)
MKT: 1.0526 (p-value: 1.0613)
WHML: -0.1033 (p-value: -0.0924)
WSMB_new: 0.5392 (p-value: 0.5495)
WPMO: -0.0082 (p-value: 0.0043)
R-squared: 0.2982
F-statistic: 29570.5880 (p-value: 0.0000)

The explanatory power of the four-factor model is similar to that of the three-factor model.
Prior to the pandemic, the stock market was relatively stable, allowing the factor model 
to price stocks to some extent. During the pandemic, the decline in the R-squared value 
indicates that the model's explanatory power was noticeably weaker during the pandemic 
compared to the pre- and post-pandemic periods. This may suggest that the stock market 
exhibited increased volatility during the pandemic, influenced by macroeconomic uncertainty 
and industry changes. After the pandemic, the stock market's stability was relatively restored, 
leading to an improvement in the model's explanatory power.

The coefficient of the market factor changed relatively little, remaining close to 1 in all three periods. 
The coefficient of the value factor (WHML) was consistently negative across all periods, 
indicating that value stocks underperformed during the pre-pandemic, mid-pandemic, 
and post-pandemic periods. The size factor (WSMB_new) was positive in all three periods, 
suggesting that small-cap stocks outperformed large-cap stocks throughout. 
The effect of the turnover factor (WPMO) increased during the pandemic and approached significance, 
indicating that during periods of higher market uncertainty, investor sentiment became more closely 
linked to stock price volatility.
