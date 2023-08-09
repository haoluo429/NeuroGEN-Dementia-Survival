
/* Read first: If your dataset include both dementia and non-dementia patients, please refer to "STEP 0 Data preparation.sas" first to prepare your dataset */
/* Last updated 09/06/2020 */

/********************************************************************************/
/********************************************************************************/
/* 																				*/
/*	Global trends of survival of people with clinical diagnosis of dementia     */
/*																				*/
/*           STEP 1:	 DATA SETUP											    */
/*		     STEP 2:	 ESIMATE SURVIVAL            							*/
/*		     STEP 3:  CALCULATE STANDARD MORTATLITY RATIO (SMR)                 */
/* 																				*/
/********************************************************************************/
/********************************************************************************/

********************************************************************************************************************************************************************************************************

/****************************************************************/
/*																*/
/* 				STEP 1:	DATA SETUP			                	*/
/*																*/
/****************************************************************/;

libname ha 'D:\NeuroGEN';   * Attention: input your own path;
%LET study_end = '31DEC2010'd; * Attention: enter the last day of study here;

******************************************************************* *;
**             ICD9 IDENTIFY DEMENTIA CASES                         **
**               290 Dementias                                     **
**             (290.4 Vascular dementia)                           **
**             294.1 Dementia in conditions classified elsewhere   **
**             294.2 Dementia, unspecified                         **
**             331.0 Alzheimer's disease                           **
**             331.1 Frontotemporal dementia                       **
**             331.82 Dementia with lewy bodies                    **
*********************************************************************;

******************************************************************* *;
**             ICD10 IDENTIFY DEMENTIA CASES                       **
**             Alzheimer's disease        G30, F00                 **
**             Vascular dementia          F01                      **
**             Dementia with lewy bodies  G31.83                   **
**             Dementia of any kind       F00, F01, F02, F03,      **
**                                        G30, G31.1, G31.83       **
*********************************************************************;

/* Step 1.0 Recode dementia by three major types */
/* Step 1.0 Recode dementia by three major types */;

%let alzheimer = %str('331.0');  * Attention: need to adjust;
%let vascular = %str('290.4');   * Attention: need to adjust;
%let Lewy = %str('331.82');      * Attention: need to adjust;

data ha.final;
  set ha.dementia_full_data;
  array diag{15} DIAG_CD V11_A V12_A V13_A V14_A V15_A V16_A V17_A V18_A V19_A V20_A V21_A V22_A V23_A V24_A;   * Attention: this is Hong Kong specfic. Please adjust according to your own data structure;
  ad = 0;
  do _n_ = 1 to 15 until(ad = 1);
   if diag{_n_} in: (&alzheimer) then ad = 1;
  end;
  vad = 0;
  do _n_ = 1 to 15 until(vad = 1);
   if diag{_n_} in: (&vascular) then vad = 1;
  end;
  ld = 0;
  do _n_ = 1 to 15 until(ld = 1);
   if diag{_n_} in: (&Lewy) then ld = 1;
  end;
  diag_sum = ad + vad + ld;
  run;

****************************************************************** *;
**                 SPECIFY TYPES OF DEMENTIA                       **
**                                                                 **
**             type = 0 all other types of dementia                **
**             type = 1 331.0 Alzheimer's disease only             **           
**             type = 2 290.4 Vascular dementia only               **          
**             type = 3 331.82 Dementia with lewy bodies only      **
**                                                                 **
*********************************************************************;


data ha.hk_dementia;
  set ha.final;
  type = "all others";
  if (ad = 1) and (vad = 0) and (ld = 0) then type = "AD";                                                                 
  if (ad = 0) and (vad = 1) and (ld = 0) then type = "VaD";
  if (ad = 0) and (vad = 0) and (ld = 1) then type = "LBD";
  keep patid sex dob type entry_date exit_date vital_d;
run;

/* Main analysis start from here */

/* Step 1.1 Case identification - apply exclusion criteria and document number of cases removed from the study */
/* Step 1.1 Case identification - apply exclusion criteria and document number of cases removed from the study */

/* Prepare the main dataset "mydementia" for the main analysis */
/* Recode variables for applying exclusion criteria*/

data ha.mydementia_total;
  set ha.hk_dementia;
  lenfol = exit_date - entry_date;
  enter_year = year(entry_date);
  enter_age = enter_year - year(dob);
  survival_year = year(exit_date) - year(entry_date);
  age_group = "60-64";
   if (enter_age >=65) and (enter_age < 70) then age_group = "65-69";
   if (enter_age >=70) and (enter_age < 75) then age_group = "70-74";
   if (enter_age >=75) and (enter_age < 80) then age_group = "75-79";
   if (enter_age >=80) and (enter_age < 85) then age_group = "80-84";
   if (enter_age >=85) then age_group = "85+";
  /* add flag on cases to be excluded */
  exclude = 0;
   if entry_date =< input('31DEC2000', date9.) then exclude = 1; * Attention: need to adjust the date;
run;

/* Document number of cases to be excluded */
proc freq data = ha.mydementia_total;
  tables exclude;
run;

/*Exclude patients who had dementia diagnosis in the first year of country-specific study period. 
This is done to exclude possible prevalent cases with dementia 
i.e. to ensure that we are including incident cases with dementia who were diagnosed first time during the study period. 
Countries that have already ensured that they have incident cases with dementia can skip this exclusion criteria*/
/* Exclude patients who were younger than 60 at entering; */
data ha.mydementia;
  set ha.mydementia_total;
   if exclude = 0 & enter_age >=60;  * Attention: this is only for countries that cannot accurately identify the first diagnosis of dementia;
run;

/* Alternative code for countires that can confirm the first diagnosis */
* data ha.mydementia;
*  set ha.mydementia_total;
*  if enter_age >=60;
*  run;

/****************************************************************/
/*																*/
/* 				STEP 2:	ESTIMTE SURVIVAL		               	*/
/*																*/
/****************************************************************/


/* Step 2.1 GENERATE DESCRIPTIVE SATATISTICS */

proc univariate data=ha.mydementia; var enter_age; run;                 * Report the average (SD) age;
PROC FREQ DATA = ha.mydementia; TABLES type sex age_group vital_d; RUN; * Generate the distribution of age groups;
PROC FREQ DATA = ha.mydementia; TABLES enter_year*age_group; RUN;       * Generate the annual number of dementia diagnosis by age group;
PROC FREQ DATA = ha.mydementia; TABLES enter_year*sex; RUN;             * Generate the annual number of dementia diagnosis by gender;

/* Step 2.2 CALCULATE MEDIAN SURVIVAL TIME for the longest follow up*/

* Calculate the median survival time and plot the Kaplan-Meier estimate;
ods graphics on;
ods exclude ProductLimitEstimates;
proc lifetest data = ha.mydementia atrisk plots = survival(cb) ;
  time lenfol*vital_d(0);
run;
ods graphics off;


* Calculate median survival time by dementia type;
ods graphics on;
ods exclude ProductLimitEstimates;
proc lifetest data = ha.mydementia atrisk plots = survival(cb) ;
  time lenfol*vital_d(0);
  strata type;
  *ods select Quartiles;
run;
ods graphics off;

* By gender;
ods graphics on;
ods exclude ProductLimitEstimates;
proc lifetest data = ha.mydementia atrisk plots = survival(cb) ;
  time lenfol*vital_d(0);
  strata sex;
  *ods select Quartiles;
run;
ods graphics off;

* By age group;
ods graphics on;
ods exclude ProductLimitEstimates;
proc lifetest data = ha.mydementia atrisk plots = survival(cb) ;
  time lenfol*vital_d(0);
  strata age_group;
  * ods select Quartiles;
run;
ods graphics off;

ods graphics on;
ods exclude ProductLimitEstimates;
proc lifetest data=ha.mydementia plot=(s, lls);
  time lenfol*vital_d(0);
  strata type age_group sex;
run; 
ods graphics off;

/* COX MODELS */ 
* Cox proportional hazards regression 1 - include subtype;  /* Note that since subtypes of dementia are likely not accurate, we may choose not to report this analysis */
proc phreg data = ha.mydementia;
class sex (ref = "M") age_group (ref = "60-64") type (ref = "all others");
model lenfol*vital_d(0) =  sex age_group type/rl=wald ties=breslow;
run;

* Cox proportional hazards regression 2 - exclude subtype;
proc phreg data = ha.mydementia;
class sex (ref = "M") age_group (ref = "60-64");
model lenfol*vital_d(0) =  sex age_group /rl=wald ties=breslow;
run;

* Adjusting for the effect of calender year; /* Note that since subtypes of dementia are likely not accurate, we may choose not to report this analyssis */
proc phreg data = ha.mydementia;
class sex (ref = "M") age_group (ref = "60-64") type (ref = "all others") enter_year (ref='2001'); * Attention: Adjust reference year of the enter_year to the first calendar year of country-specific study period;
model lenfol*vital_d(0) =  sex age_group type enter_year/rl=wald ties=breslow;
run;

* Adjusting for the effect of calender year - exclude type; /* Note that since subtypes of dementia are likely not accurate, we may choose not to report this analyssis */
proc phreg data = ha.mydementia;
class sex (ref = "M") age_group (ref = "60-64") enter_year (ref='2001'); * Attention: Adjust reference year of the enter_year to the first calendar year of country-specific study period;
model lenfol*vital_d(0) =  sex age_group enter_year/rl=wald ties=breslow;
run;


/****************************************************************/
/*																*/
/* 	 STEP 3:  CALCULATE STANDARD MORTATLITY RATIO (SMR)     	*/
/*																*/
/****************************************************************/

/* Step 3.1 Prepare the aggregated table for the dementia population */
/* Step 3.1 Prepare the aggregated table for the dementia population */

/* Expand the data from one record-per-patient to on record-per-interval between each event time, per patient */
/* The SAS macro "cpdate" need to be used */
%let FILEPATH = D:\NeuroGEN\;     * Attention: Please specify your own path; 
%include "&FILEPATH.cpdata.sas";
%cpdata(data=ha.mydementia, time = survival_year, event = vital_d(0), outdata = ha.mydementia2);

data ha.smr1;
  set ha.mydementia2;
  age_calendaryear = enter_age + survival_year1; * This is to calculate age for each calendar year; 
  calendar_year = enter_year + survival_year1;
  age_calendar_group  = '60-64';
  if (age_calendaryear >=65) and (age_calendaryear < 70) then age_calendar_group = '65-69';
  if (age_calendaryear >=70) and (age_calendaryear < 75) then age_calendar_group = '70-74';
  if (age_calendaryear >=75) and (age_calendaryear < 80) then age_calendar_group = '75-79';
  if (age_calendaryear >=80) and (age_calendaryear < 85) then age_calendar_group = '80-84';
  if (age_calendaryear >=85) then age_calendar_group = '85+';
run;


/* 3.1.1. Create table with population count for each stratum of sex, age group, calendar year;*/
proc freq data = ha.smr1;
  tables sex age_calendar_group calendar_year sex*age_calendar_group*calendar_year / out = FreqCount;
  title 'aggregate table';
run;

data smr_dementia;    
  set FreqCount;
  drop percent;
  rename age_calendar_group = age
         calendar_year = year;
run;

proc sort data = smr_dementia;
  by year sex age;
run;

/* 3.1.2. Create table with death count for each stratum of sex, age group, calendar year */
proc tabulate data = ha.smr1 out = DeathCount;
  Title 'Number of deaths by sex age and calendar year';
  var vital_d;
  class sex age_calendar_group calendar_year;
  table sex*age_calendar_group*calendar_year*vital_d*SUM; 
run;

data DeathCount;
  set DeathCount;
drop _type_ _page_ _table_;
rename age_calendar_group = age
       calendar_year = year;
run;

proc sort data = DeathCount;
  by year sex age;
run;

/* 3.1.3 Merge tables to create table which is basis for SMR calculation */
data ha.smr_dementia;
  merge smr_dementia DeathCount; 
  by year sex age;
  rename vital_d_Sum = deaths
         count = population;
run;

PROC SORT DATA = ha.smr_dementia; BY year sex age; RUN;
PROC PRINT DATA = ha.smr_dementia; TITLE 'Dementia population for SMR calculation without adjustment of person-years'; RUN;


/* Step 3.2 Prepare the aggregated table for the general population */
/* Step 3.2 Prepare the aggregated table for the general population */

/* Import the general population data */
PROC IMPORT OUT= ha.smr_population 
            DATAFILE= "D:\NeuroGEN\population_5years.csv"  /* Attention: Please change to your own path */
            DBMS=CSV REPLACE;                            /* Attention: Subject to change according to your own data type */
     GETNAMES=YES;
     DATAROW=2; 
RUN;

proc sort data = ha.smr_population;
  by year sex age;
run;

/* Step 3.3 Compute SMR and its 95% CI stratified by age and gender*/
/* Step 3.3 Compute SMR and its 95% CI stratified by age and gender*/

ods graphics on;
ods select StdInfo StrataSmrPlot Smr;
proc stdrate data = ha.smr_dementia refdata = ha.smr_population
             stat = rate
			 method = indirect
			 plots = smr
             ;
	 population event = deaths total = population;
	 reference  event = deaths total = population;
	 strata age sex;
	 by year;
 ods output smr = ha.smr_hk;
 run;

*To print the overall table of the SMR results;
 proc print data=ha.smr_hk;
TITLE 'Dementia population for SMR calculation WITHOUT adjusting person-years';
 run;
title; 

ods graphics on;
ods select StdInfo StrataSmrPlot Smr;
proc stdrate data = ha.smr_dementia refdata = ha.smr_population
             stat = rate
			 method = indirect
			 plots = smr
             ;
	 population event = deaths total = population;
	 reference  event = deaths total = population;
	 strata age sex;
 ods output smr = ha.smr_hk_aggregate;
 run;

/* Main analysis completed */
***************************************************************************************************************************************************************************




/****************************************************************/
/*																*/
/* 	 STEP 4:  CALCULATE STANDARD MORTATLITY RATIO (SMR)         */
/*                   [ALTERNATIVE APPROACH]                     */
/*																*/
/****************************************************************/

/* cb: Option to adjust person-time under risk*/
/* cb: Option to adjust person-time under risk*/
/*For the dementia group:
  1) subtract 1/2 year in each calendar year for each person with the initial dementia diagnosis in this calendar year
  2) subtract 1/2 year in the calendar year a person exited (due to death or other reasons) if the calendar year was not the last year of the study,
  3) subtract 3/4 year in calendar year if person entered and exited the cohort in the same year
  Reasoning: a person diagnosed in October 2005 contributes only 1/4 year time at risk for dying for 2005, we assume mid-year as average time of diagnosis*/
/*For the population (reference) group: 
  substract 1/2 year for each death in this calendar year * For HK only, please revise according to your own dataset
  
  --> code replaces the dataset ha.smr_dementia created in 1.4. */;

/*For the dementia group*/
DATA ha.test;
	SET ha.smr1;
	exit_year = year(exit_date);
	IF enter_year = calendar_year THEN subtract = 0.5; *for calendar year of diagnosis;
	IF (exit_year = calendar_year) AND exit_date ne &study_end THEN subtract = 0.5;* for persons who exited before 2016 in calendar year of exit;
	IF (enter_year = calendar_year) AND ((exit_year = calendar_year) AND exit_date ne &study_end) THEN subtract = 0.75; *for persons who entered and exited in same calendar year if year was before 2016;
RUN;

PROC FREQ DATA = ha.test;
	TABLES subtract*calendar_year / missing;
	*TABLES substract*sex*age_cal_group*calendar_year / list missing;
RUN;

proc tabulate data = ha.test out = ha.subtracting_sum;
  Title 'Number of deaths by sex age and calendar year';
  var subtract;
  class sex age_calendar_group calendar_year;
  table sex*age_calendar_group*calendar_year*subtract*SUM; 
run;

data ha.subtracting_sum;
  set ha.subtracting_sum;
drop _type_ _page_ _table_;
rename age_calendar_group = age
       calendar_year = year;
run;

data ha.subtracting_sum; set ha.subtracting_sum; /* Code suggested by Marjaana to adjust for missing values in subtract_Sum */
if subtract_Sum=. then subtract_Sum=0;
run;


PROC SORT DATA = ha.subtracting_sum; BY sex year age; RUN;
PROC SORT DATA = ha.smr_dementia; BY sex year age; RUN; /* smr_dementia was generated in Step 3.1.1 */
DATA ha.smr_minus;
	MERGE ha.subtracting_sum  ha.smr_dementia;
	BY sex year age;
RUN;


DATA ha.smr_dementia_CB (drop=population);
	SET ha.smr_minus;
	new_count = population - subtract_sum;
RUN;
DATA ha.smr_dementia_CB (drop=subtract_sum);
	SET ha.smr_dementia_CB;
	RENAME new_count = population;
RUN;

PROC SORT DATA = ha.smr_dementia_CB; BY year sex age; RUN;
PROC PRINT DATA = ha.smr_dementia_CB; TITLE 'Dementia population for SMR calculation with person-years adjusted according to option 3.1.4'; RUN;

/*For the population (reference) group
  For HK only, please revise according to your own dataset*/
data ha.smr_population_CB (drop=population);
set ha.smr_population;
new_count=population-0.5*deaths;
run;

data ha.smr_population_CB;
set ha.smr_population_CB;
RENAME new_count=population;
run;
proc sort data=ha.smr_population_CB;
by year sex age;
run;

ods graphics on;
ods select StdInfo StrataSmrPlot Smr;
proc stdrate data = ha.smr_dementia_CB refdata = ha.smr_population_CB
             stat = rate
			 method = indirect
			 plots = smr
             ;
	 population event = deaths total = population;
	 reference  event = deaths total = population;
	 strata age sex;
	 by year;
 ods output smr = ha.smr_hk_opt314;
 run;

 proc print data=ha.smr_hk_opt314; 
TITLE 'Dementia population for SMR calculation with person-years adjusted according to option 3.1.4';
run; *to print the overall table of the SMR results;
title; 

proc stdrate data = ha.smr_dementia_CB refdata = ha.smr_population_CB
             stat = rate
			 method = indirect
			 plots = smr
             ;
	 population event = deaths total = population;
	 reference  event = deaths total = population;
	 strata age sex;
 ods output smr = ha.smr_hk_opt314_aggregate;
 run;

/* All analysis completed */
