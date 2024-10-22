/***********************************************************************************************************/
/* Original data source:                                                                                   */
/* https://healthdata.gov/dataset/Cardiovascular-Disease-Death-Rates-Trends-and-Exce/au45-g5w7/about_data  */              
/* Purpose: Review cardiovascular disease rates                                                            */ 
/***********************************************************************************************************/

%global ds;

%let ds=rates_healthdata_gov;

/*setup access to external data*/
filename cardio '/home/u63568107/Data/csv/Cardiovascular_Disease_Death_Rates__Trends__and_Excess_Death_Rates_Among_US_Adults__35___by_County_and_Age_Group___2010-2020.csv';

/*use DATA Step to prep data*/

data first;
  infile cardio delimiter = ',' truncover dsd firstobs=2;
  length Class $25 Topic $40 Data_Value_Unit $20 Data_Value_Type $75
         StratificationCategory1 Stratification1 $25 Year $10;
  input Location_ID $
        Year $
        Location_Abbr $
        Geographical_Level $
        DataSource $
        Class $
        Topic $
        Data_Value 
        Data_Value_Unit $
        Data_Value_Type $
        Data_Value_Footnote_Symbol  $
        Data_Value_Footnote $
        Confidence_limit_Low 
        Confidence_limit_High
        StratificationCategory1 $
        Stratification1 $
        TopicID $
        X_long
        Y_lat ;  

informat Data_Value best32. Confidence_limit_Low best32. Confidence_limit_High best32.
         X_long 12.7 Y_lat 12.7;
format Data_Value 6.1 Confidence_limit_Low 5.2 Confidence_limit_High 5.2
       X_long 12.7 Y_lat 12.7;
/*data set option or statement*/
rename Stratification1=Age_Group Data_Value=Cardiovascular_Disease_Rate;

run;

data &ds.;
    set first;
    length Age_Group_Cat 8.;
   
    if Age_Group='Ages 35-64 years' then Age_Group_Cat=1;
        else if Age_Group='Ages ≥65 years' then Age_Group_Cat=2;
        else Age_Group_Cat=3;
run;

/* Use macro to create new variable for specific data sets - macros could be called from another file 
   using %include but leaving here for this program.
*/


/*Macro: Calculate maximum rate for states*/
%macro run_max_rate_states;

%local i getstate state_names nextval;
%let state_names = NC SC VA;
%let i=1;

%do %while (%scan(&state_names., &i) ne );
   %let getstate = %scan(&state_names., &i);

/*output data for North Carolina, South Carolina, and Virgina to new data sets*/
data &ds._&getstate.;
  set &ds.;

/*subset data - some raw data for Year is string*/
 where Year in ('2016','2017','2018') and Age_Group_Cat ^= 3;
 
 if Location_Abbr = %upcase("&getstate.") then output &ds._&getstate.;
run;

proc sort data=&ds._&getstate. out=&getstate._sorted;
 by Age_Group_Cat Year descending Cardiovascular_Disease_Rate;
run;

data &ds._&getstate._max;
    set &getstate._sorted; 
    by Age_Group_Cat Year descending Cardiovascular_Disease_Rate;
    keep Year Age_Group_Cat Age_Group Cardiovascular_Disease_Rate Confidence_limit_Low Confidence_limit_High;
    format Cardiovascular_Disease_Rate Confidence_limit_Low Confidence_limit_High best12.;

/*output the highest rate for each state and year*/
    if first.Year then output;
run;

title "Print of Maximum Cardiovascular Rate between 2016 and 2018";
title2 "State = &getstate.";
footnote "Original data from https://healthdata.gov/dataset/Cardiovascular-Disease-Death-Rates-Trends-and-Exce/au45-g5w7/about_data";

proc print data=&ds._&getstate._max noobs;
run;

title;
footnote;

%let i = %eval(&i + 1);
%end;
%mend run_max_rate_states;

/*Macro: SQL Summarizations*/
/*Macro with positional parameters*/
%macro run_sql_stats(state, age_category,cardio_exp);

/*show summarizations, using column labels, group by*/

title "State of &state. data review: Cardiovascular Disease Rate Summary Statistics for years between 2016 and 2018";
title2 "Data by Year, Age Group Category=&age_category, only %001 facilities";
proc sql;

select Age_Group,
    Age_Group_Cat,
    Year,
    Location_ID,
    Cardiovascular_Disease_Rate,
    N(Cardiovascular_Disease_Rate) as N_CDR_&getstate. LABEL="N of Cardiovascular rate by Year, Age Group for &state.",
    mean(Cardiovascular_Disease_Rate) as Mean_CDR_&getstate. LABEL="Mean Cardiovascular rate by Year, Age Group for &state.",
    min(Cardiovascular_Disease_Rate) as Min_CDR_&getstate. LABEL="Minimum Cardiovascular rate by Year, Age Group for &state.",
    max(Cardiovascular_Disease_Rate) as Max_CDR_&getstate. LABEL="Maximum Cardiovascular rate by Year, Age Group for &state.", 
    range(Cardiovascular_Disease_Rate) as Range_CDR_&getstate. LABEL="Range of Cardiovascular rate by Year, Age Group for &state.",
    count(*) as NumRows_&getstate. LABEL="Total count of Cardiovascular rate records by Year, Age Group for &state.",
    Nmiss(Cardiovascular_Disease_Rate) as NMiss_&getstate. LABEL="Number of missing values for Cardiovascular rate by Year, Age Group for &state."
    from &state._sorted

    where Age_Group_Cat=&age_category
    group by Year
        having Location_ID in ('37001','45001','51001');
quit;

/*create new table with summarizations, column labels, ORDER BY*/

title2 "Data ordered by Facility_Code, Year desc";
title3 "Age Group Category=&age_category";
proc sql number;

create table &state._sql as select
    Age_Group,
    Age_Group_Cat,
    Year,
    Location_Abbr as State,
    Location_ID as Facility_Code,
    Cardiovascular_Disease_Rate,
    N(Cardiovascular_Disease_Rate) as N_CDR_&getstate. LABEL="N of Cardiovascular rate",
    mean(Cardiovascular_Disease_Rate) as Mean_CDR_&getstate. LABEL="Mean Cardiovascular rate",
    min(Cardiovascular_Disease_Rate) as Min_CDR_&getstate. LABEL="Minimum Cardiovascular rate",
    max(Cardiovascular_Disease_Rate) as Max_CDR_&getstate. LABEL="Maximum Cardiovascular rate", 
    range(Cardiovascular_Disease_Rate) as Range_CDR_&getstate. LABEL="Range of Cardiovascular rate",
    count(*) as NumRows_&getstate. LABEL="Total count of Cardiovascular rate records",
    Nmiss(Cardiovascular_Disease_Rate) as NMiss_&getstate. LABEL="Number of missing values for Cardiovascular rate"
    from &state._sorted

    where Age_Group_Cat=&age_category
    order by Facility_Code, Year desc;
quit;

title4"Cardiovascular Disease Rate &cardio_exp.";

proc sql;
select * from &state._sql
where Age_Group_Cat=&age_category and Cardiovascular_Disease_Rate &cardio_exp
order by Facility_Code, Year desc;
quit;

title;
footnote;

%mend run_sql_stats;

/*Macro: Calculate maximum rate for states*/
%run_max_rate_states;

/*Macro: SQL summarizations by state and age group category*/
%run_sql_stats(NC,1, %str(< 130));
%run_sql_stats(VA,2, %str(> 1600));