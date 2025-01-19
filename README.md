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

