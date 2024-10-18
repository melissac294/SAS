/***********************************************************************************************************/
/* Original data source:                                                                                   */
/* https://healthdata.gov/dataset/Cardiovascular-Disease-Death-Rates-Trends-and-Exce/au45-g5w7/about_data  */              
/* Purpose: What is the highest cardiac disease rate by State?                                             */ 
/***********************************************************************************************************/

%global ds;

%let ds=rates_healthdata_gov;

/*setup access to external data*/
filename cardio '/home/u63568107/Data/csv/Cardio_Data.csv';

/*use DATA Step to prep data*/

data &ds.;
  infile cardio delimiter = ',' truncover dsd firstobs=2;
  length Class $25 Topic $40 Data_Value_Unit $20 Data_Value_Type $75
         StratificationCategory1 Stratification1 $25 ;
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
format Data_Value 5.2 Confidence_limit_Low 5.2 Confidence_limit_High 5.2
       X_long 12.7 Y_lat 12.7;
/*data set option or statement*/
rename Stratification1=Age_Group Data_Value=Cardiovascular_Disease_Rate;
run;

/* Use macro to create new variable for specific data sets - macros could be called from another file 
   using %include but leaving here for this program.
*/
%macro run_max_val_states;
%local i state_names getstate nextval;
%let state_names = NC SC;
%let i=1;


%do %while (%scan(&state_names., &i) ne );
   %let getstate = %scan(&state_names., &i);

/*output data for North Carolina, South Carolina, and Virgina to new data sets*/
data &ds._&getstate.;
  set &ds.;

/*subset data - some raw data for Year is string*/
 where Year in ('2016','2017','2018') and Age_Group ne '';
 
 if Location_Abbr = %upcase("&getstate.") then output &ds._&getstate.;
run;

proc sort data=&ds._&getstate. out=&getstate._sorted;
 by Year descending Cardiovascular_Disease_Rate;
run;

data &ds._&getstate._max;
    set &getstate._sorted; 
    by Year;
    keep Year Age_Group Cardiovascular_Disease_Rate Confidence_limit_Low Confidence_limit_High ;

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

%mend;
%run_max_val_states;