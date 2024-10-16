/************************************************************************************************************/
/*       NAME: IVY.SAS                                         				  	    */
/*      TITLE: SAS Macro for IV analyis          */
/*     AUTHOR: Gomathy Parvathinathan, Stanford University                                          	            */
/*         OS: Windows 7 Ultimate 64-bit								    */
/*   Software: SAS 9.4											    */
/*       DATE: Jul 15 2024                                       					    */
/*DESCRIPTION: This program produces a 2-page report to help users decide if IV is appropriate methd for thir data,and could then build the 2 
					2 stage residual model*/
/*													    */
/*    Copyright (C) <2024>  <Gomathy Parvathinathan,Sai Liu, Xingxing S. Cheng and Margaret R Stedman>				                    */
/*													    */
/*    This program is free software: you can redistribute it and/or modify				    */
/*    it under the terms of the GNU General Public License as published by			     	    */
/*    the Free Software Foundation, either version 3 of the License, or					    */
/*    (at your option) any later version.								    */
/*													    */
/*    This program is distributed in the hope that it will be useful,				            */
/*    but WITHOUT ANY WARRANTY; without even the implied warranty of					    */
/*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the					    */
/*    GNU General Public License for more details.							    */
/*													    */
/*    You should have received a copy of the GNU General Public License					    */
/*    along with this program.  If not, see <http://www.gnu.org/licenses/>.				    */
/************************************************************************************************************/


ods html close;
ods listing;
 
options nofmterr symbolgen mlogic notes SPOOL;

data combo;
input id1 id2;
cards;
1 2 
2 3 
1 3 
3 4 
2 4 
1 4 
4 5 
3 5 
2 5 
1 5 
;
run;





%macro assumption_checking;

/*******Report error message in log, if each of the below "MUST INPUT" variable is missing*********/;
%if &dataout.=   %then %do; 
    %put ERROR:  'dataout' variable is not specified.; %return;
%end;
%if &dataset.=   %then %do; 
    %put ERROR:  'dataset' variable is not specified.; %return;
%end;
%if &instrument.=   %then %do; 
    %put ERROR:  'instrument' variable is not specified.; %return;
%end;


%if &numvar.= & &catvar.=  %then %do; 
    %put ERROR:  'numvar & catvar' variable is not specified.; %return;
%end;
%if &exposure_var.=   %then %do; 
    %put ERROR:  'exposure_var' variable is not specified.; %return;
%end;

* Remove "" from dataout path;
%let dataout=%qsysfunc(dequote(&dataout));

***Checking if instrument and instrumentname are different;;
%if &instrument.= &instrumentname. %then %do;
 %let instrumentname = inst_&instrumentname.;
%end;


* Remove "" from dataout path;
%let dataout=%qsysfunc(dequote(&dataout));

*Reading the dataset from the folder that you assign, or read in dataset from work library, if datain is blank;

%if &datain.^=" "  %then %do;
	libname lib &datain.;
	data mydata ;
	set lib.&dataset.;
	run;
%end;

%else %do;
	data mydata ;
	set work.&dataset.;
	run;
%end;

**Checking if instrument and instrumentname are different;
%if &instrument.= &instrumentname. %then %do;
 %let instrumentname = inst_&instrumentname.;
%end;


****Macro part 1: *Relevance assumption;

**Checking if exposure_var is binary or linear,and deciding on whether to do logistic regression on linear regression;
**Calculate IV;


%if &isexposure_binary.="yes" %then %do;
proc logistic data=mydata;
model &exposure_var. =&instrument.  ;
	output out=work.IV_df  p=&instrumentname.;
run;
%end;

%else %do;
proc reg data=mydata PLOTS(MAXPOINTS=NONE) ;
var &instrument.;
model &exposure_var. =&instrument. ;
output out=work.IV_df  p=&instrumentname.;
run;
%end;



*Setting the reportname for the  assumption report;
%if &assumptionsreport.=  %then %do;
   %let reportname=Assumptions checking Report;				
%end;
%else %do;
   %let reportname = &assumptionsreport. ;
%end;


*Relevance assumption ;

ods graphics off;
ods exclude all;
proc reg data=work.IV_df ;
model &exposure_var. =&instrument. ;
ods output ParameterEstimates=ParameterEstimates;
run;
ods exclude none;

* Macro to caluclate smd for numeric variables;

%macro num_smd(var=);
proc means data=fortable1;
  class quintile;
  var &var.;
  output out=meansout mean=mean std=std;
run;

data sub;
  set meansout;
  id=_n_;
  where _type_=1;
run;

*****merge with means;
proc sql;
  create table tab1 as
  select a.id1,
         a.id2,  
         b.mean as mean1,
         b.std as std1
  from combo a, sub b
  where a.id1=b.id;
 
  create table tab2 as
    select a.*,  
         b.mean as mean2,
         b.std as std2
  from tab1 a, sub b
  where a.id2=b.id;
quit;

****estimate smd for continous variables;
data smdtab;
  set tab2;
  md=mean1-mean2;
  var1=std1**2;
  var2=std2**2;
  pstd=sqrt((var1+var2)/2);
  smd=md/pstd;
run;

*****find max;
proc sql;
  create table smd_&var. as
  select "&var." as var, abs(max(smd)) as smd_max
  from smdtab;
quit;

proc append base=smd data=smd_&var. force;run;
%mend;
*Macro to caluclate  for categorical vraiables;
%macro cat_smd(var=);
proc means data=fortable1;
  class quintile;
  var &var.;
  output out=meansout mean=mean std=std;
run;

data sub;
  set meansout;
  id=_n_;
  where _type_=1;
run;

*****merge with means;
proc sql;
  create table tab1 as
  select a.id1,
         a.id2,  
         b.mean as mean1,
         b.std as std1
  from combo a, sub b
  where a.id1=b.id;
 
  create table tab2 as
    select a.*,  
         b.mean as mean2,
         b.std as std2
  from tab1 a, sub b
  where a.id2=b.id;
quit;

****estimate smd for categorical vraiables;
data smdtab;
  set tab2;
  md=mean1-mean2;
  var1=mean1*(1-mean1);
  var2=mean2*(1-mean2);
  pstd=sqrt((var1+var2)/2);
  smd=md/pstd;
run;

*****find max;
proc sql;
  create table smd_&var. as
  select "&var." as var, abs(max(smd)) as smd_max
  from smdtab;
quit;

proc append base=smd data=smd_&var. force;run;
%mend;


*Exchangeability assumption;

*Sort the instrumnet;
proc sort data=work.IV_df;by &instrument.;run;
*get quintile;
proc rank data=work.IV_df out=IV_qt group=5;
    var &instrumentname.;run;

*Merging the quintile back to the original data;
proc sort data=IV_qt;by &instrument.;run;
proc sort data=work.IV_df;by &instrument.;run;



*merging the qunintile with the original data ;
data work.final_df;
	merge IV_qt(in=a rename=(&instrumentname.=group)) iv_df(keep=&instrument.  &instrumentname.);
	if a;
	by &instrument.;
run;

*Setting up data for smd;
data fortable1;
	set work.final_df;
	if group=0 then quintile=1;
	else if group=1 then quintile=2;
	else if group=2 then quintile=3;
	else if group=3 then quintile=4;
	else if group=4 then quintile=5;
keep  quintile &exposure_var.  &instrument. &instrumentname.  &numvar. &catvar.;
run;

*Using num_smd for numerical variables, and cat_smd for categorical vraiables smd caluclation;
option ls=100;

proc delete data=smd;run;
data smd;
length var $25. smd_max  8.4;
run;

%let i=1;
%let inp=&numvar. || "";
%let var=%scan(&inp,&i);
%do %while (&var ne "");
	%put var passed &var. ;
	%num_smd(var=&var); 
	%let i = %eval(&i+1);
	%let var=%scan(&inp,&i);
%end;



%let i=1;
%let inp=&catvar. || "";
%let var=%scan(&inp,&i);
%do %while (&var ne "");
	%put var passed &var. ;
	%cat_smd(var=&var); 
	%let i = %eval(&i+1);
	%let var=%scan(&inp,&i);
%end;

*Cleaning smd data;
data smd1;
set smd;
label var="Variable" smd_max="Maximum absolute SMD";
run;

*Copying relevance assumption results and exchangeability results to the report;
ods pdf file="&dataout.\&reportname..pdf";
title  j=c "Relevance Assumption:"; 
title2 j=c "Checking if there is a strong association between exposuregenous variable and IV";
title4 j=c "Check for P-values for the IV in the parameter estimates";
proc print data= ParameterEstimates; run;

title j=c 'Exchangeability Assumption';
 title2 j=c "The exogenous variables and IV are uncorrelated";
title4 j=c "Check for max absolute value of SMD <= 0.5";
proc print data=smd1 noobs label;run;
ods pdf close;


%mend;

%macro bootstrap;
/*******Report error message in log, if each of the below "MUST INPUT" variable is missing*********/;

%if &instrument.=   %then %do; 
    %put ERROR:  'instrument' variable is not specified.; %return;
%end;
%if &numvar.= & &catvar.=  %then %do; 
    %put ERROR:  'numvar & catvar' variable is not specified.; %return;
%end;

%if &outcome.=   %then %do; 
    %put ERROR:  'outcome' variable is not specified.; %return;
%end;

%if &exposure_var.=   %then %do; 
    %put ERROR:  'exposure_var' variable is not specified.; %return;
%end;

* Remove "" from dataout path;
%let dataout=%qsysfunc(dequote(&dataout));

***Bootstrapping;
proc surveyselect data=final_df out=outsample NOPRINT 
seed=96543
method=urs  /*resample with replacement */
samprate=1	 /* each bootstrap sample has N observations */
outhits
reps=1000; 	/* generate resamples, eg: 1000 times*/
run;

proc sort data=outsample;by replicate  ;run;

* run residual model;
proc reg data=outsample plots(maxpoints=none);
	model &exposure_var.=&catvar. &numvar. &instrument.;
	output out=foriv_prerun_residual residual=insu_residual;
	by replicate;
run;
quit;

* IV model with residual;
proc sort data=foriv_prerun_residual;by replicate;run;

Proc syslin data=foriv_prerun_residual 2sls;
exposuregenous &exposure_var.; 
Instruments &instrument.; 
Model &exposure_var.=&catvar. &numvar. &instrument.;

ods output parameterestimates=est;
Model &outcome.= &exposure_var. insu_residual &catvar. &numvar. ; *****Y is primary outcome;
by replicate;
run;

*Setting up the estimates from bootstrapping to calculate estimates with 95% confidence interval;

data want;
set est;
by Replicate;
if first.replicate and Variable='Intercept'  then cm_sum=0; 
cm_sum + Variable='Intercept' ;
run;
data want1;
set want;
where cm_sum=2 ;run;


proc sort data=want1;
by replicate;run;

proc transpose data=want1 out=want2(rename =(insu_residual=&instrumentname._residual));
by replicate;
id variable;
var estimate;
run;
proc contents data=want2;run;

*calculating estimats with 95% confidence interval;
ods select none;


proc means data=want2 stackods mean clm alpha=0.05 ; 
 var intercept &catvar. &numvar. &exposure_var.  ;
ods output summary=BT_estimates;run;
ods select all;


*Setting the reportname for the estimates with 95% CI ;
%if &estimatesreport.=  %then %do;
   %let reportname=Estimates Report;				
%end;
%else %do;
   %let reportname = &estimatesreport. ;
%end;

* Copying the estimates to the report;
ods pdf file="&dataout.\&reportname..pdf"; 
title 'Estimates from Bootstrapping';
proc print data=BT_estimates LABEL;
    label Mean='Parameter Estimates'
		LCLM = 'Lower 95% CL for Estimate'
		  UCLM = 'Upper 95% CL for Estimate';
run;
ods pdf close;
%mend;


