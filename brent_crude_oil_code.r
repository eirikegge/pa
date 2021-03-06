---
title: "Forecasting Brent Crude Oil Appendix"
subtitle: "Forecasting DC Oil Brent EU"
author: "Eirik Egge"
date: "30/08/2021"
output:
  pdf_document:
    toc: no
    number_sections: yes
  html_document:
    toc: yes
    toc_depth: 2
    number_sections: yes
  word_document:
    toc: yes
    toc_depth: '2'
header-includes:
- \usepackage{graphicx}
- \usepackage{float}
- \usepackage{comment}
- \floatplacement{figure}{H}
urlcolor: blue
---

```{r setup, include=FALSE, cache = FALSE}

knitr::opts_chunk$set(echo = TRUE)
options(repos="https://cran.rstudio.com" )

list.of.packages <- c("tseries", "readr", "tidyverse", "forecast", "urca", "ggplot2", "xts", "quantmod", "pracma", "fpp2", "simpleboot","AER", "gridExtra")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
library(tseries)
library(readr)
library(tidyverse)
library(forecast)
library(urca)
library(ggplot2)
library(xts)
library(quantmod)
library(pracma)
library(fpp2)
library(AER)
library(gridExtra)
library(vars)
library(sandwich)
library(strucchange)
library(seastests)

```

# Section 1.1
```{r 1.1.1, echo= T}
# LOAD DATA, INSPECT ACF & DECOMP. PLOT

#read data
df_oil <- read.csv("DCOILBRENTEU.csv", sep = ",")

#create xts and ts time series
oil$DATE <- as.Date(df_oil$DATE, "%Y-%m-%d")
oil.xts <- xts(df_oil[,2], order.by = oil$DATE)
oil.ts <- ts(df_oil[,2], start = c(1987,6), end = c(2021,5), frequency = 12)

#view data
autoplot(oil.ts) + ylab("Closing Price") + xlab("Time") + 
  ggtitle("Crude Oil Prices: Brent - Europe, US Dollars per Barrel, Monthly")

#check NAs
which(is.na(oil.ts)) #null na values

#check col names
names(df_oil)

#check class
class(df_oil)

# summary stats
summary(df_oil)

#### TIME SERIES PATTERNS ####

grid.arrange((autoplot(oil.ts) 
              + ylab("") 
              + ggtitle("Original Data")),
             (ggAcf(oil.ts) 
              + ylab("") 
              + ggtitle("ACF")),
             nrow = 1)

# decomposition plot (multiplicative) 
(autoplot(decompose(oil.ts, type="multiplicative")) 
+ xlab("Year") 
+ ggtitle("Multiplicative Decomposition"))


#check variance for deciding upon transformation (unequal variance indicates that a transformation might be good)
autoplot(oil.ts) + geom_point()


# check for seasonality (test) # to be dealt with in stationarity section 
summary(wo(oil.ts)) #p-valoue = 0.4955 (H0: Non-seasonal time series, HA: Seasonal time series) (https://cran.r-project.org/web/packages/seastests/vignettes/seastests-vignette.html)
#conclusion: no seasonality

```
*Comment Original Data:*
+ Appears to be non stationary
+ Exponential increase from '02 until '08, followed by high fluctuation
+ Increasing variance

*Comment ACF plot:*
+ increasing trend until 2000, might be exponential
+ lot of fluctuations
+ several upswings and slumps, which might indicate a cyclic behavior

*Comment Multiplicative Decomposition Plot:*
+ trend is exponential
+ seasonality suggested, but cannot be confirmed as this plot assumes seasonal behavior that is the same each year
+ remainder/noise significant in '90, '07 and '20, otherwise stable (does not increase or decrease)


# Section 1.2
```{r 1.1.2, echo=T}

# TRANSFORM

#Logarithmic transformation and decomposition plot
log_oil.ts <- log(oil.ts)

autoplot(log_oil.ts) + ylab("Log Closing Price") + xlab("Year") + 
  ggtitle("Log transformed Crude Oil Price")

dec_log <- decompose(log_oil.ts, type = c('multiplicative'),filter = NULL)
autoplot(dec_log) + ylab("") + xlab("") + ggtitle('Decomposition Multiplicative Log Transformed')

# Box & Cox transformation (power, lambda = -0.414) and decomposition plot
lambda_oil <- BoxCox.lambda(oil.ts)

bc_oil.ts <- BoxCox(oil.ts,lambda_oil)

autoplot(bc_oil.ts) + ylab("Powered Closing Price") + xlab("Year") + 
  ggtitle("Box & Cox Crude Oil Price, lambda = -0.414")

dec_bc <- decompose(bc_oil.ts, type = c('multiplicative'),filter = NULL)
autoplot(dec_bc) + ylab("") + xlab("") + ggtitle('Decomposition Multiplicative B.& C. Transformed')

```

*Comments regarding transformation (Box & Cox):*
 + Time series now displays a more linear trend  
 + Therefore, bc_oil.ts will be used for further analysis
 + The patterns in the historical data is now simplified
 + These factors can lead to a simpler forecasting task, and hereby more accurate forecasts

# Section 2.1
```{r 2.1.1, echo=T}
# REMOVING NON STATIONARITY

# KPSS- H0: Data is stationary, HA: Data is not stationary

# ADF - H0: Data has unit root, HA: Stationary* (*different hypothesis)

summary(ur.kpss(bc_oil.ts, type = "tau"))
summary(ur.df(bc_oil.ts, type= "trend", selectlags = "AIC"))
```

Comment KPSS w/ tau: 
+ The value of the test-statistic is greater than the critical value
    on 1% level. Therefore, we **reject** the null hypothesis that our data is
    stationary. (0.6583 > 0.216) 1pct
+ Conclusion: NOT STATIONARY 
    
Comment ADF w/ trend: 
+ GAMMA/TAU3 (gamma = 0 --> unit root):
  + 1pct: |T-stat| **accept** lower than critical value (unit root)
  
+ PHI2 (alpha0 = alpha2 = gamma = 0, drift/alpha0)
  + 5pct & 1pct: |T-stat| **accept** lower than critical value (drift, trend, unit root)
  
+ PHI3 (alpha2 = gamma = 0, trend/alpha2)
  + 5pct & 1pct: |T-stat| **accept** lower than critical value (trend)

+ Conclusion 1pct: unit root, drift, trend

# Section 2.2
```{r 2.1.2, echo=T}
# take the difference
d.bc.oil.ts <- diff(bc_oil.ts)

# inspect data 
autoplot(d.bc.oil.ts)

summary(ur.kpss(d.bc.oil.ts, type = "tau"))
summary(ur.df(d.bc.oil.ts, type="trend", selectlags = "AIC"))
## no trend (0.0354 < 0.216)

# new test, type = "mu" and "drift"
summary(ur.kpss(d.bc.oil.ts, type = "mu"))
summary(ur.df(d.bc.oil.ts, type="drift", selectlags = "AIC"))
```
*Comment KPSS:*
 + all pct: t-stat lower than critical values (0.0354 < 0.347 10pct) **accept** H0: data ia stationary

*Comment ADF:*
 + TAU2: 
    + t-stat > critical value **reject** H0: hence, no drift.
 + PHI1: 
    + t-stat > critical value **reject** H0: no unit root. 
   
# Section 2.3
```{r 2.1.3}
summary(ur.df(d.bc.oil.ts, type="none", selectlags = "AIC")) 
```


Comment ADF:
  + T-stat > critical value at 1pct (-15.8657 > -2.58) 
  + **Reject** H0: Data are stationary


# Section 2.4
```{r 2.1.4, echo=T}

###### DATA are now STATIONARY ######

# Box Pierce test for autocorrelation

Box.test(d.bc.oil.ts, lag = 10, fitdf = 0) #(check what fitdf is)

# H0: Not random walk (double check)
# HA: Random walk
# P-value = 0.0449, therefore not random walk 


# ACF & PACF PLOTS

# O.G. Data
grid.arrange((ggAcf(oil.ts) 
              + ylab("") 
              + ggtitle("ACF")),
             (ggPacf(oil.ts)
              + ylab("") 
              + ggtitle("PACF")),
             nrow = 1)

# B&C Transformed Oil 
grid.arrange((ggAcf(bc_oil.ts) 
              + ylab("") 
              + ggtitle("ACF")),
             (ggPacf(bc_oil.ts)
              + ylab("") 
              + ggtitle("PACF")),
             nrow = 1)

# B&C Transformed Oil DIFFERENTIATED
grid.arrange((ggAcf(d.bc.oil.ts, lag.max = 36) 
              + ylab("") 
              + ggtitle("ACF")),
             (ggPacf(d.bc.oil.ts, lag.max = 36)
              + ylab("") 
              + ggtitle("PACF")),
             nrow = 1)

#inspection of diff vs. original (stationarity)
autoplot(acf(diff(oil.ts)))
autoplot(acf(oil.ts))
```

*Comment ACF & PACF B&C TRANSFORMED ts:*
 + ACF
   + Since the ACF spikes are all significant, the series is not stationary, therefore it should be differentiated. 


*Comment ACF & PACF 1 diff B&C ts:* 
 + ACF: 
  + No clear pattern.
  + Significant spikes for lag = 2, 4, 13, 24
  + No sharp drop after after q number of lags
  
+ PACF: 
  + No clear pattern.
  + Significant spikes for lag = 2, 4
  + no geometrical pattern, but it might be slightly decreasing
  
  
+ Summary:
  + Many significant lags
  + 1st and 2nd lag changes sign
  + regular plots: 
    + 1 lag is highly significant
    

*Model Assumptions:*
 + ARIMA(0,1,0)
  + Non Seasonal Part: 
    + 0 AR - no geometric trend in ACF followed by q significant lags
    + 1 I due to non stationary process, 1 diff for Y variables to be mean variance stationary
    + 0 MA - no geometric trend in PACF followed by p significant lags
  + Seasonal Part: 
    + 2 - Significant spikes for lag 24 and 36, therefore add seasonal order of 2 (check up what it's called)


+ ETS (Error, Trend, Seasonal) (A = Additive, M = Multiplicative, Z = Automatic, Ad = Additive damped)
 + ETS(A,N,N)
  + Error: A - The series has been B&C transformed, therefore the error component is additive
  + Trend: N - After Unit root handling there is no trend present (also what decomposition plot indicates)
  + Seasonal: N - ref. WO test, no seasonality present
  

# Section 3.1
```{r 3.1.1, echo=T}

# split train test (~ 80/20 split)

train <- window(bc_oil.ts, end = c(2014, 12))
test <- window(bc_oil.ts, start = c(2015, 1))
h <- length(test)

train_og <- window(oil.ts, end = c(2014, 12))
train_log <- window(log_oil.ts, end = c(2014, 12))

coronaperiod <- window(bc_oil.ts, start = c(2019, 11))


#check autocorrelation for train necessary? 
```


# Section 3.2
```{r 3.1.2, echo = T}
#MODELS

#modelling procedure (https://otexts.com/fpp2/arima-r.html)

#hand model ARIMA 
fit1.1 <- Arima(train, order = c(0, 1, 0))
summary(fit1.1)
checkresiduals((fit1.1)) #Ljung Box Test - H0: Residuals are independent (Rejected 1%, they are correlated)
shapiro.test(residuals(fit1.1)) # H0: Normally Distributed (Rejected, not normally distributed)

# significant lags ACF: 24 & 36 (+)
# Ljung-Box test (H0: Model is fine) rejects null hypothesis that the time series isn't auto correlated.
  # Conclusion: Residuals are auto correlated
# Variance appears to reduce over time, which might indicate the presence of heteroskedacity

fit1.2 <- Arima(train, order = c(0,1,0), seasonal = c(2, 0, 1))
summary(fit1.2)
checkresiduals((fit1.2))
shapiro.test(residuals(fit1.2))

fit1.3 <- Arima(train, order = c(7,1,4), seasonal = c(2, 0, 1))
summary(fit1.3)
checkresiduals(fit1.3)
shapiro.test(residuals(fit1.3))


#auto ARIMA (what fit1.3 yielded)
#fit1.4 <- auto.arima(train, stepwise = F, approximation = F, max.p = 7,
#                   max.q = 7,
#                   max.P = 7,
#                   max.Q = 7,
#                   max.order = 7,
#                   max.d = 7,
#                   max.D = 7, ic = 'aic')


#summary(fit1.4)
#checkresiduals((fit1.4))
#shapiro.test(residuals(fit1.4)) # H0: Normally Distributed (Rejected, not normally distributed)



# Selected: fit1.2 / ARIMA(0,1,0)(2,0,1)[12] (principle of parsimony)

#hand model ETS
fit2.1 <- ets(train, model = ("ANN"))
summary(fit2.1)
checkresiduals((fit2.1))
shapiro.test(residuals(fit2.1))

fit2.2 <- ets(train_og, model = ('MNN'))
summary(fit2.1)
checkresiduals((fit2.2))

fit2.3 <- ets(train_log, model = 'MAA', damped = T)
summary(fit2.3)
checkresiduals(fit2.3)

#auto model ETS
fit2.4 <- ets(train, model = ("ZZZ"), ic = 'aic')
summary(fit2.4)
checkresiduals((fit2.4))
shapiro.test(residuals(fit2.4))


# Selected: fit3.1 = fit3.4 / ETS(ANN) (lowest on all IC)

#auto model ANN
fit3.1 <- nnetar(train)
summary(fit3.1)
checkresiduals((fit3.1))
Box.test(residuals(fit3.1), lag = 25)
shapiro.test(residuals(fit3.1))
```


*Desired Properties of Residuals:*
1. Uncorrelated (if sufficient model)
2. Zero Mean (if sufficient model)
3. Constant Variance (beneficial)
4. Normal Distribution (beneficial)


# Section 4.1 
```{r 4.1.1, echo=T}
#FORECASTS

#benchmark forecasts
for.b1  <- meanf(train, h = h, level = c(80, 95))
for.b2  <- naive(train, PI = T, h = h)
for.b3  <- rwf(train, PI = T, h = h, drift = T)


#ARIMA, ETS, NNAR
for.autoar <- forecast(fit1.2, h = h)
for.autoets <- forecast(fit2.4, h = h)
for.nnetar <- forecast(fit3.1, h = h, PI = T)


#combined plot
grid.arrange((autoplot(bc_oil.ts)
              + ylab("")
              + autolayer(meanf(train, h = h), series = 'Mean', PI = F)
              + autolayer(naive(train, h = h), series = 'Naive', PI = F)
              + autolayer(rwf(train, h = h, drift = T), series = 'Drift', PI = F)
              + ggtitle("Benchmark Forecasts")),
             (autoplot(for.autoar)
              + ylab("") 
              + autolayer(test)
              + ggtitle("ARIMA(0,1,0)(2,0,1)[12]")),
             (autoplot(for.autoets) 
              + autolayer(test)
              + ylab("") 
              + ggtitle("ETS(A,N,N)")),
             (autoplot(for.nnetar)
              + autolayer(test)
              + ylab("")

              + ggtitle("NNAR(25,1,3)[12]")),
             nrow = 2)
```


# Section 4.2
```{r 4.1.2, echo = T}
#Accuracy measures [RMSE, MAE, MAPE, MASE] (https://otexts.com/fpp2/arima-ets.html)
accuracy(for.b1, test) #MEAN
accuracy(for.b2, test) #NAIVE
accuracy(for.b3, test) #DRIFT
accuracy(for.autoar,test) #ARIMA
accuracy(for.autoets,test) #ETS
accuracy(for.nnetar, test) #NNETAR



#Accuracy measures corona period [2019(11) - CTD]
accuracy(for.b1, coronaperiod) #MEAN
accuracy(for.b2, coronaperiod) #NAIVE
accuracy(for.b3, coronaperiod) #DRIFT
accuracy(for.autoar,coronaperiod) #ARIMA
accuracy(for.autoets,coronaperiod) #ETS
accuracy(for.nnetar, coronaperiod) #NNETAR

```







