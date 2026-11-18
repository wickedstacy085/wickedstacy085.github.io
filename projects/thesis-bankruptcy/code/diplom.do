clear all
set more off
capture log close

log using "results.log", replace text
**************************************************************
* DATA PREPARATION
**************************************************************
import excel "Panel_data.xlsx", sheet("Sheet1") firstrow
save Panel_data.dta, replace
use Panel_data.dta, clear

capture rename A Region
capture rename B year
egen region_id = group(Region)
duplicates report region_id year

collapse (mean) Y1 Y2 unemployment log_debt_people log_median_income divorce_rate CPI housing_prices ///
interest_rate wages_to_social property_income_to_wages gambling log_hospital_beds log_graduates ///
industrial_SEZ innovative_SEZ tourist_SEZ log_VRP_dobycha log_VRP_obrabatyvayuschie log_VRP_energy ///
log_VRP_agriculture log_VRP_finance log_VRP_trade log_investment log_debt_firm log_housing_stock log_R_and_D ///
log_skilled_graduates business_income_to_wages, by(region_id year Region)

xtset region_id year

gen unemployment_sq = unemployment^2
gen CPI_sq = CPI^2
gen interest_rate_sq = interest_rate^2

**************************************************************
* MODEL SPECIFICATIONS
**************************************************************
global modelY1 unemployment unemployment_sq log_debt_people log_median_income divorce_rate ///
CPI CPI_sq housing_prices interest_rate interest_rate_sq wages_to_social ///
property_income_to_wages gambling log_hospital_beds log_graduates industrial_SEZ innovative_SEZ ///
tourist_SEZ log_VRP_dobycha log_VRP_obrabatyvayuschie log_VRP_energy log_VRP_agriculture ///
log_VRP_finance log_VRP_trade

global modelY2 unemployment unemployment_sq log_investment log_debt_firm CPI CPI_sq ///
housing_prices log_housing_stock interest_rate interest_rate_sq log_R_and_D ///
log_median_income wages_to_social business_income_to_wages property_income_to_wages ///
log_skilled_graduates gambling industrial_SEZ innovative_SEZ tourist_SEZ log_VRP_dobycha ///
log_VRP_obrabatyvayuschie log_VRP_energy log_VRP_agriculture log_VRP_finance log_VRP_trade

**************************************************************
* BASE MODELS + Hausman + Comparative Table Y1
**************************************************************
reg Y1 $modelY1
estimates store pool_y1

xtreg Y1 $modelY1, fe
estimates store fe_y1

xtreg Y1 $modelY1, re
estimates store re_y1

hausman fe_y1 re_y1
xttest0

esttab pool_y1 fe_y1 re_y1 , b(%7.4f) stats(N r2) star replace

**************************************************************
* BASE MODELS + Hausman + Comparative Table Y2
**************************************************************
reg Y2 $modelY2
estimates store pool_y2

xtreg Y2 $modelY2, fe
estimates store fe_y2

xtreg Y2 $modelY2, re
estimates store re_y2

hausman fe_y2 re_y2
xttest0

esttab pool_y2 fe_y2 re_y2 , b(%7.4f) stats(N r2) star replace

**************************************************************
* TIME MODELS + Hausman + Comparative Table Y1
**************************************************************
reg Y1 $modelY1 i.year
estimates store pool_time_y1

xtreg Y1 $modelY1 i.year, fe
estimates store fe_time_y1

xtreg Y1 $modelY1 i.year, re
estimates store re_time_y1

hausman fe_time_y1 re_time_y1
xttest0

esttab pool_time_y1 fe_time_y1 re_time_y1 , b(%7.4f) stats(N r2) star replace

**************************************************************
* TIME MODELS + Hausman + Comparative Table Y2
**************************************************************
reg Y2 $modelY2 i.year
estimates store pool_time_y2

xtreg Y2 $modelY2 i.year, fe
estimates store fe_time_y2

xtreg Y2 $modelY2 i.year, re
estimates store re_time_y2

hausman fe_time_y2 re_time_y2
xttest0

esttab pool_time_y2 fe_time_y2 re_time_y2 , b(%7.4f) stats(N r2) star replace

**************************************************************
* 7. SERIAL AUTOCORRELATION (Wooldridge test)
**************************************************************
xtserial Y1 $modelY1
xtserial Y2 $modelY2

**************************************************************
* 8. PESARAN CD TEST — CORRECTED!!!
**************************************************************
xtreg Y1 $modelY1 i.year, fe
xtcsd, pesaran abs

xtreg Y2 $modelY2 i.year, fe
xtcsd, pesaran abs

**************************************************************
* 9. HETEROSKEDASTICITY TEST (Modified Wald test)
**************************************************************
xtreg Y1 $modelY1 i.year, fe
xttest3

xtreg Y2 $modelY2 i.year, fe
xttest3

**************************************************************
* 10. REPLACE xtregar WITH xtgls (Y1 and Y2)
**************************************************************
xtgls Y1 $modelY1 i.year , corr(ar1) panels(heteroskedastic)
estimates store gls_y1

xtgls Y2 $modelY2 i.year, corr(ar1) panels(heteroskedastic)
estimates store gls_y2

**************************************************************
* 11. ROBUST / CLUSTER FINAL CORRECTIONS (Y1 and Y2)
**************************************************************
xtreg Y1 $modelY1 i.year, fe vce(robust)
estimates store fe_rob_y1

xtreg Y1 $modelY1 i.year, fe vce(cluster region_id)
estimates store fe_cl_y1

xtreg Y2 $modelY2 i.year, fe vce(robust)
estimates store fe_rob_y2

xtreg Y2 $modelY2 i.year, fe vce(cluster region_id)
estimates store fe_cl_y2

**************************************************************
* 12. FINAL EXPORT (GLS + Robust + Cluster)
**************************************************************
esttab fe_rob_y1 fe_cl_y1 gls_y1 , b(%7.4f) stats(N r2) star replace
esttab fe_rob_y2 fe_cl_y2 gls_y2 , b(%7.4f) stats(N r2) star replace

**************************************************************
* 13. СОЗДАЁМ ВРЕМЕННЫЕ ДАММИ
**************************************************************
tabulate year, generate(year_)

**************************************************************
* 14. XTSSC: FE модель с Driscoll-Kraay стандартными ошибками (с дамми)
**************************************************************
xtscc Y1 $modelY1 year_2 year_3 year_4 year_5 year_6, fe
estimates store fe_scc_y1

xtscc Y2 $modelY2 year_2 year_3 year_4 year_5 year_6, fe
estimates store fe_scc_y2

**************************************************************
* 15. Y2 Pool Mode4 Robust errors
**************************************************************
xtreg Y2 $modelY2 ,  vce(cluster region_id)
estimates store pool_cl_y2

xtscc Y2 $modelY2
estimates store pool_scc_y2


**************************************************************
* 15. Итоговые таблицы с xtscc и всеми моделями
**************************************************************
esttab fe_rob_y1 fe_cl_y1 gls_y1 fe_scc_y1 , b(%7.4f) stats(N r2) star replace
esttab fe_rob_y2 fe_cl_y2 gls_y2 fe_scc_y2 pool_cl_y2 pool_scc_y2 , b(%7.4f) stats(N r2) star replace

