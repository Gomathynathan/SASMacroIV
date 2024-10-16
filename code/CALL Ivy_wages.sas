/********************************************************************************************************/
/*       NAME: CALL IVY.SAS                                         				  	*/
/*      TITLE: Calling IVY macro with an example 		*/
/*     AUTHOR: Gomathy Parvathinathan, MS, Stanford University                                          		*/
/*		   OS: Windows 7 Ultimate 64-bit							*/
/*	 Software: SAS 9.4										*/
/*       DATE: July 15 2024                                       					*/
/*DESCRIPTION: This program shows how to call the IVY.sas macro			 */
/********************************************************************************************************/


/*Imported data from the website: https://www.cengage.com/cgi-wadsworth/course_products_wp.pl?fid=M20b&product_isbn_issn=9781111531041 
Data:card.xls
Ref: Wooldridge Source: D. Card (1995), Using Geographic Variation in College Proximity to Estimate the Return to Schooling,
in Aspects of Labour Market Behavior: Essays in Honour of John Vanderkamp. Ed. L.N. Christophides, E.K. Grant, 
and R. Swidinsky, 201-222. Toronto: University of Toronto Press.   */;
proc import datafile="C:\Users\gparvathinathan\Box\IV methods paper\JSM\Data\educ_wages.csv" dbms=csv out=wages ;
run;
proc contents data=wages;
run;

data wages_1;
set wages;
married_1=(married=1);
wages_binary=(wage > 500);
drop var1 married;
run; 
proc contents data=wages_1;run;
proc freq data=wages_1;
table wages_binary married_1;run;

/************************************************************************************************************
* Now, let's set up parameters below
*************************************************************************************************************/

%include "C:\Users\gparvathinathan\Box\IV methods paper\JSM\GitHub\IVY.sas";
%let datain=" "; 				/*Location of permanent SAS dataset. Leave it blank, if your dataset is in the work library*/	
%let dataout="C:\Users\gparvathinathan\Box\IV methods paper\JSM\GitHUB";				/*Location of one-pager report will be saved*/												
%let dataset=wages_1;					/*Name of the dataset*/	;				

%let instrument= nearc4;   /*Instrument variable . It could be more than 1 variable too. */;

%let exposure_var=educ;     /*exposuregenous variable  */;

%let instrumentname=distance; /* Label of the instrument*/;

%let isexposure_binary="no";  /* Is exposuregnous variable binary? .Answer "yes" or "no" as appropriate       */;

%let numvar=  age exper expersq ;   /*Numerical covariates  */;

%let catvar=  black married_1;  /*Categorical covariates. Each categorical covariates should be of 2 levels only.For example: if there are 3 different illness say illness<=1,  1 to3 illness, and >3 illness.
Then 3 categorical covariates to be created each with 2 levels :0 and 1 for illness<=1, illness between 1 and 3, and illness>3 */;

%let assumptionsreport=Recentwages_assumption;  /*Name of the report for  relevance and exchangeability assumption checking 
 If you leave it blank, this program will give a name as "Assumptions checking Report" */;


  
%let outcome=wages_binary;  /*Outcome variable.It should be categorical variable  */;


%let estimatesreport=Recentwages Estimates report /*Name of the report for the estimates from bootstrapped sample.
If you leave it blank, this program will give a name as "Estimates Report" */;


%assumption_checking; /*Relevance assumption:There is a strong association between exposuregenous variable and IV. 
Check for significance in the estimates of  instrument, and confirm that relevance assumption is satisfied. 
If not staisfied, then this IV doesnot meet the assumption.
In this example , in the "Parameter estimates" table, we could see under nearc4, P value <0.001, which shows relevance asssumption is satisfied.
 /*Exchangeability assumption: The exogenous variables and IV are uncorrelated. Check for max absolute value of 
SMD <0.5, and confirm if the exchangeability assumption is satisfied.If not staisfied, then this IV doesnot meet the assumption.
In this example, we see that smd_max for all variables are <0.5, and exchangeability assumption is satisfied.*/;

%bootstrap;   /* Build 2SRI model with 1,000 bootstrap samples  and gets the estimates  */;


/*Note that for continous outcomes, you could use the standard SAS procedure: PROC SYSLIN:
 
proc syslin data= wages_1;
 exposure educ;
instrument nearc4;
model educ=nearc4;
model wage= educ black married_1 age exper expersq;
run;

*/;
