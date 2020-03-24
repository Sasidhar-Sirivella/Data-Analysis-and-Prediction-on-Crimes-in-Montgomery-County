libname project "/folders/myfolders/project";


/* Import the Crime dataset */
/* We will get error due to some missing values but the dataset will be imported*/
%web_drop_table(WORK.IMPORT);

FILENAME REFFILE '/folders/myfolders/Project/crime.csv';

PROC IMPORT DATAFILE=REFFILE
	DBMS=CSV
	OUT=WORK.IMPORT;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=WORK.IMPORT; RUN;

%web_open_table(WORK.IMPORT);


data project.maindata;
set WORK.IMPORT;
run;

/* selecting those zipcodes that belong to Montgomery county */
proc sql;
create table test as
select * from project.maindata
where zip_code in (20886,20895,20896,20899,20902,20901,20904,20903,20906,20905,20910,
20912,20810,20812,20811,20814,20816,20815,20818,20817,20833,20832,20838,20837,20841,20839,
20842,20851,20850,20853,20852,20855,20854,20859,20857,20861,20860,20866,20862,20871,20868,
20874,20872,20876,20875,20878,20877,20880,20879,20058,20882);
quit;


/* Adding Demographical data to the main dataset */

%web_drop_table(WORK.IMPORT);


FILENAME REFFILE '/folders/myfolders/Project/Unemployment crime.xlsx';

PROC IMPORT DATAFILE=REFFILE
	DBMS=XLSX
	OUT=WORK.IMPORT;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=WORK.IMPORT; RUN;


%web_open_table(WORK.IMPORT);

proc sql;
create table test1 as
select a.*,b.unemployment_rate,b.median_household_income,b.race_majority,b.race_percentage
from test a
left join import b
on a.zip_code=b.zipcode;
quit;

%web_drop_table(WORK.IMPORT);


FILENAME REFFILE '/folders/myfolders/Project/Race_Crime.xlsx';

PROC IMPORT DATAFILE=REFFILE
	DBMS=XLSX
	OUT=WORK.IMPORT;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=WORK.IMPORT; RUN;


%web_open_table(WORK.IMPORT);

proc sql;
create table test2 as
select a.*,b.white,b.black,b.hispanic_or_latino
from test1 a
left join import b
on a.zip_code=b.zipcode;
quit;

%web_drop_table(WORK.IMPORT);


FILENAME REFFILE '/folders/myfolders/Project/popgender.xlsx';

PROC IMPORT DATAFILE=REFFILE
	DBMS=XLSX
	OUT=WORK.IMPORT;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=WORK.IMPORT; RUN;


%web_open_table(WORK.IMPORT);

proc sql;
create table test3 as
select a.*,b.population,b.male,b.female
from test2 a
left join import b
on a.zip_code=b.zipcode;
quit;

data project.finaldata;
set test3;
run;

data project.finaldata1(keep=incident_id offence_code dispatch_date___time victims crime_name1 crime_name2
crime_name3 police_district_name city zip_code place sector beat pra start_date_time latitude 
longitude police_district_number unemployment_rate race_majority race_percentage white black 
hispanic_or_latino population male female);
set project.finaldata;
run;

/* Removing observations with missing values */
data project.finaldata1;
 set project.finaldata1;
 if cmiss(of _all_) then delete;
run;

/* Calculating Crime Rate */
proc sql;
create table crime_zipcode as
select count(incident_id) as count, zip_code, population
from project.finaldata1
group by zip_code,population;
quit;

data crime_rate;
set crime_zipcode;
crime_rate=(count/population)*100;
run;

proc sql;
create table project.finaldata1 as
select a.*,b.crime_rate
from project.finaldata1 a
left join crime_rate b
on a.zip_code=b.zip_code;
quit;

/* Deriving start & dispatch date and time */
data file3;
set project.finaldata1;
format start_date dispatch_date date9.;
format start_time dispatch_time time.;
start_date = datepart(start_date_time);
dispatch_date = datepart(dispatch_date___time);
start_time = timepart(start_date_time);
dispatch_time = timepart(dispatch_date___time);
run;

/* Defining Timeshift based on Start Time */
data file4;
set file3;
format timeshift $10.;
   select;
      when ("00:00:00"t <= start_time < "06:00:00"t) timeshift="12am-6am";
      when ("06:00:00"t <= start_time< "12:00:00"t) timeshift="6am-12pm";
      when ("12:00:00"t <= start_time< "18:00:00"t) timeshift="12pm-6pm";
      when ("18:00:00"t <= start_time< "24:00:00"t) timeshift="6pm-12am";
      otherwise timeshift="";  * representing "unknown" day ;
   end;
run;

/* Calculating Response Time in minutes */
data file5;
set file4;
Response_time_min = (dispatch_date___time-start_date_time)/60;
run;

%web_drop_table(WORK.IMPORT);


FILENAME REFFILE '/folders/myfolders/Project/Police Dist.xlsx';

PROC IMPORT DATAFILE=REFFILE
	DBMS=XLSX
	OUT=WORK.IMPORT;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=WORK.IMPORT; RUN;


%web_open_table(WORK.IMPORT);

/* Calculating Distance between Police station and Crime Location */
proc sql;
create table file6 as
select a.*,b.latitude1,b.longitude1
from file5 a
left join import b
on a.police_district_name=b.police_district_name;
quit;

data Project.file7;
set file6;
distance_miles = geodist(latitude,longitude,latitude1,longitude1,'DM');
run;

/* Data Analysis response_time1 variable */
data project.file7;
set project.file7;
if response_time_min < 0 then response_time1=.;
else if response_time_min > 2880 then response_time1=.;
else response_time1 = response_time_min;
run;

/* Count of crimes vs Types of crimes */
proc sql;
create table crime_count as
select count(incident_id) as count, crime_name1
from project.file7
group by crime_name1;
quit;

title 'Count of crimes vs Type of crimes';
proc sgplot data=crime_count;
  hbar crime_name1 / response=count  datalabel
       categoryorder=respdesc nostatlabel;
  xaxis grid display=(nolabel);
  yaxis grid discreteorder=data display=(nolabel);
  run;

/* count of crimes vs Zipcode */
proc sql;
create table crime_zipcode as
select count(incident_id) as count, zip_code
from project.file7
group by zip_code;
quit;


title 'count of crimes vs Zipcode';
proc sgplot data=crime_zipcode;
  vbar Zip_Code / response=count  datalabel
       categoryorder=respdesc nostatlabel;
  yaxis grid display=(nolabel);
  xaxis grid discreteorder=data display=(nolabel);
  where count>5000;
  run;
  

/* crime count in sub crimes of property crime */
proc sql;
create table Subcrime_of_property as
select count(incident_id) as count, crime_name2
from project.file7
where crime_name1='Crime Against Property'
group by crime_name2;
quit;


title 'crime count in sub crimes of property crime';
proc sgplot data=Subcrime_of_property;
  hbar crime_name2 / response=count  datalabel
       categoryorder=respdesc nostatlabel;
  xaxis grid display=(nolabel);
  yaxis grid discreteorder=data display=(nolabel);
  run;



/* Victims vs types of crimes */
proc sql;
create table victims as
select count(incident_id) as count, victims,crime_name1
from project.file7
group by victims,crime_name1;
quit;

title 'Victims vs types of crimes';
proc sgplot data=victims;
  vbar victims / response=count stat=sum group=crime_name1 nostatlabel;
  xaxis display=(nolabel);
  yaxis grid;
  where victims ~= 1;
  run;

/* Response Time vs TimeShift */
proc sql;
create table response_time as
select mean(response_time1) as mean_res_time, timeshift
from project.file7
group by timeshift;
quit;

/* Response Time vs Type of Crimes */
proc sql;
create table response_time as
select mean(response_time1) as mean_res_time, crime_name1
from project.file7
group by crime_name1;
quit;


/* times shift vs types of crimes */
proc sql;
create table time_shift as
select count(incident_id) as count,crime_name1,timeshift
from project.file7
group by crime_name1,timeshift;
quit;

title 'time shift vs types of crimes';
proc sgplot data=time_shift;
  vbar crime_name1 / response=count stat=sum group=timeshift statlabel dataskin=gloss datalabel;
  xaxis display=(nolabel);
  yaxis grid;
  run;
  
  
/* 20910 vs types of crimes */
proc sql;
create table zip_20910 as
select count(incident_id) as count,crime_name1
from project.file7
where zip_code=20910
group by crime_name1;
quit;

title 'types of crimes count in 20910 zipcode';  
proc sgplot data=zip_20910;
  vbar crime_name1 / response=count dataskin=crisp  datalabel fill fillattrs=(color=teal transparency=.6)
        nostatlabel;
  yaxis grid display=(nolabel);
  xaxis grid  display=(nolabel);
run;


/* Place vs count of crimes */
data project.file7;
set project.file7;
format place1 $20.;
if substr(place,1,6) = "Retail" then place1="Retail";
else if substr(place,1,7) = "Parking" then place1="Parking Lot";
else if substr(place,1,9) = "Residence" then place1="Residence";
else if substr(place,1,6) = "Street" then place1="Street";
else place1="Others";
run;

proc sql;
create table place as
select count(incident_id) as count, place1
from project.file7
group by place1;
quit;

ods graphics / reset width=6.4in height=4.8in imagemap;

proc sgplot data=WORK.PLACE;
	vbar place1 / response=count group=count groupdisplay=cluster dataskin=gloss datalabel;
	yaxis grid;
run;

ods graphics / reset;


proc sql;
create table place1 as
select count(incident_id) as count, place1,crime_name1
from project.file7
group by place1,crime_name1;
quit;

ods graphics / reset width=6.4in height=4.8in imagemap;

proc sgplot data=WORK.PLACE1;
	vbar place1 / response=count stat=sum group=crime_name1 groupdisplay=cluster dataskin=gloss datalabel;
	yaxis grid;
run;

ods graphics / reset;


/* "No of Crimes by Time Shift" for Crime Against Property */
proc sql;
create table crime_property as
select count(incident_id) as count,timeshift
from project.file7
where crime_name1="Crime Against Property"
group by timeshift;
quit;

title '"No of Crimes by Time Shift" for Crime Against Property';
proc template;
	define statgraph SASStudio.Pie;
		begingraph;
		layout region;
		piechart category=timeshift response=count /
		    DATALABELLOCATION = INSIDE
		    DATALABELATTRS=(size=12pt color=WHITE)
            DATALABELCONTENT = ALL
            CATEGORYDIRECTION = CLOCKWISE
            START = 180 NAME = 'pie';
		endlayout;
		endgraph;
	end;
run;

ods graphics / reset width=6.4in height=4.8in imagemap;

proc sgrender template=SASStudio.Pie data=WORK.crime_property;
run;

ods graphics / reset;


/* "No of Crimes by Time Shift" for Crime Against Society'; */
proc sql;
create table crime_society as
select count(incident_id) as count,timeshift
from project.file7
where crime_name1="Crime Against Society"
group by timeshift;
quit;

title '"No of Crimes by Time Shift" for Crime Against Society';
proc template;
	define statgraph SASStudio.Pie;
		begingraph;
		layout region;
		piechart category=timeshift response=count /
		    DATALABELLOCATION = INSIDE
		    DATALABELATTRS=(size=12pt color=WHITE)
            DATALABELCONTENT = ALL
            CATEGORYDIRECTION = CLOCKWISE
            START = 180 NAME = 'pie';
		endlayout;
		endgraph;
	end;
run;

ods graphics / reset width=6.4in height=4.8in imagemap;

proc sgrender template=SASStudio.Pie data=WORK.crime_society;
run;

ods graphics / reset;


/* "No of Crimes by Time Shift" for Crime Against Person' */
proc sql;
create table crime_person as
select count(incident_id) as count,timeshift
from project.file7
where crime_name1="Crime Against Person"
group by timeshift;
quit;

title '"No of Crimes by Time Shift" for Crime Against Person';
proc template;
	define statgraph SASStudio.Pie;
		begingraph;
		layout region;
		piechart category=timeshift response=count /
		    DATALABELLOCATION = INSIDE
		    DATALABELATTRS=(size=12pt color=WHITE)
            DATALABELCONTENT = ALL
            CATEGORYDIRECTION = CLOCKWISE
            START = 180 NAME = 'pie';
		endlayout;
		endgraph;
	end;
run;

ods graphics / reset width=6.4in height=4.8in imagemap;

proc sgrender template=SASStudio.Pie data=WORK.crime_person;
run;

ods graphics / reset;


/* "No of Crimes by Time Shift" for Other crime' */
proc sql;
create table crime_other as
select count(incident_id) as count,timeshift
from project.file7
where crime_name1="Other"
group by timeshift;
quit;

title '"No of Crimes by Time Shift" for Other crime';
proc template;
	define statgraph SASStudio.Pie;
		begingraph;
		layout region;
		piechart category=timeshift response=count /
		    DATALABELLOCATION = INSIDE
		    DATALABELATTRS=(size=12pt color=WHITE)
            DATALABELCONTENT = ALL
            CATEGORYDIRECTION = CLOCKWISE
            START = 180 NAME = 'pie';
		endlayout;
		endgraph;
	end;
run;

ods graphics / reset width=6.4in height=4.8in imagemap;

proc sgrender template=SASStudio.Pie data=WORK.crime_other;
run;

ods graphics / reset;


/* times shift vs Place of the crime */
proc sql;
create table timevplace as
select count(incident_id) as count,timeshift,place1
from project.file7
group by timeshift,place1;
quit;

title 'Times Shift vs Place of the crime';
proc sgplot data=timevplace;
  vbar place1 / response=count stat=sum group=timeshift categoryorder=respdesc
  dataskin=gloss statlabel datalabel;
  xaxis grid discreteorder=data display=(nolabel);
   yaxis grid display=(nolabel);
  run;
  
/* Mean Response Time vs Place of the crime */
proc sql;
create table Responsevplace as
select response_time1,place1
from project.file7;
quit;

ods graphics / reset width=6.4in height=4.8in imagemap;

title 'Mean Response Time vs Place of the crime';
proc sgplot data=WORK.RESPONSEVPLACE;
	vbox response_time1 / category=place1 nooutliers;
	yaxis grid;
run;

ods graphics / reset;


proc sql;
create table Responsevzip as
select count(incident_id) as count,mean(response_time1) as mean,mean(distance_miles) as dist,zip_code
from project.file7
group by zip_code;
quit;

/* Creating Season variable */
data project.file7;
set project.file7;
FORMAT date_new yymmn6.;
date_new = start_date;
Format season $10.;
if month(start_date) in (12,1,2) then season = "Winter";
else if month(start_date) in (3,4,5) then season = "Spring";
else if month(start_date) in (6,7,8) then season = "Summer";
else if month(start_date) in (9,10,11) then season = "Fall";
Format start_month start_year 8.;
start_month = month(start_date);
start_year = year(start_date);
run;

  
/* Count vs types of crimes */
proc sql;
create table count_type as
select count(incident_id) as count,crime_name1
from project.file7
group by crime_name1;
quit;

title 'types of crimes vs count';
proc sgplot data=count_type;
  vbar crime_name1 / response=count stat=sum statlabel dataskin=gloss datalabel;
  xaxis discreteorder=data display=(nolabel);
  yaxis grid;
  run;
  
  
/* count of crimes vs type of crimes for Zipcode>5000 */
proc sql;
create table file_count as
select a.*,b.count
from project.file7 a
left join crime_zipcode b
on a.zip_code=b.zip_code;
quit;

proc sql;
create table crime_zipcode1 as
select count(incident_id) as count1,crime_name1,zip_code
from file_count
where count>5000
group by crime_name1,zip_code;
quit;

proc sql;
create table test1 as
select mean(count1) as mean1,crime_name1
from crime_zipcode1
group by crime_name1;
quit;

proc sgplot data=test1;
  vbar crime_name1 / response=mean1 dataskin=crisp  datalabel fill fillattrs=(color=teal transparency=.6)
        nostatlabel;
  yaxis grid display=(nolabel);
  xaxis grid  display=(nolabel);
run;


/* times shift vs zipcode "Response Time"*/
proc sql;
create table timevzip as
select count(incident_id) as count,zip_code,timeshift
from project.file7
where zip_code=20910
group by zip_code,timeshift;
quit;


title 'No of crimes vs Times Shift "20910"';
proc template;
	define statgraph SASStudio.Pie;
		begingraph;
		layout region;
		piechart category=timeshift response=count /
		    DATALABELLOCATION = INSIDE
		    DATALABELATTRS=(size=12pt color=WHITE)
            DATALABELCONTENT = ALL
            CATEGORYDIRECTION = CLOCKWISE
            START = 180 NAME = 'pie';
		endlayout;
		endgraph;
	end;
run;

ods graphics / reset width=6.4in height=4.8in imagemap;

proc sgrender template=SASStudio.Pie data=WORK.timevzip;
run;

ods graphics / reset;


proc sql;
create table file1 as
select count(incident_id) as count,start_year
from project.file7
group by start_year;
quit;

ods graphics / reset width=6.4in height=4.8in imagemap;

proc sort data=WORK.FILE1 out=_SeriesPlotTaskData;
	by start_year;
run;

proc sgplot data=_SeriesPlotTaskData;
	series x=start_year y=count /;
	xaxis grid;
	yaxis grid;
run;

ods graphics / reset;

proc datasets library=WORK noprint;
	delete _SeriesPlotTaskData;
	run;

data file2;
set project.file7;
format date1 $10.;
if start_month=7 and start_year=2016 then date1="201607";
else if start_month=8 and start_year=2016 then date1="201608";
else if start_month=9 and start_year=2016 then date1="201609";
else if start_month=10 and start_year=2016 then date1="201610";
else if start_month=11 and start_year=2016 then date1="201611";
else if start_month=12 and start_year=2016 then date1="201612";
else if start_month=1 and start_year=2017 then date1="201701";
else if start_month=2 and start_year=2017 then date1="201702";
else if start_month=3 and start_year=2017 then date1="201703";
else if start_month=4 and start_year=2017 then date1="201704";
else if start_month=5 and start_year=2017 then date1="201705";
else if start_month=6 and start_year=2017 then date1="201706";
else if start_month=7 and start_year=2017 then date1="201707";
else if start_month=8 and start_year=2017 then date1="201708";
else if start_month=9 and start_year=2017 then date1="201709";
else if start_month=10 and start_year=2017 then date1="201710";
else if start_month=11 and start_year=2017 then date1="201711";
else if start_month=12 and start_year=2017 then date1="201712";
else if start_month=1 and start_year=2018 then date1="201801";
else if start_month=2 and start_year=2018 then date1="201802";
else if start_month=3 and start_year=2018 then date1="201803";
else if start_month=4 and start_year=2018 then date1="201804";
else if start_month=5 and start_year=2018 then date1="201805";
else if start_month=6 and start_year=2018 then date1="201806";
else if start_month=7 and start_year=2018 then date1="201807";
else if start_month=8 and start_year=2018 then date1="201808";
else if start_month=9 and start_year=2018 then date1="201809";
else if start_month=10 and start_year=2018 then date1="201810";
else if start_month=11 and start_year=2018 then date1="201811";
else if start_month=12 and start_year=2018 then date1="201812";
else if start_month=1 and start_year=2019 then date1="201901";
else if start_month=2 and start_year=2019 then date1="201902";
else if start_month=3 and start_year=2019 then date1="201903";
else if start_month=4 and start_year=2019 then date1="201904";
else if start_month=5 and start_year=2019 then date1="201905";
else if start_month=6 and start_year=2019 then date1="201906";
else if start_month=7 and start_year=2019 then date1="201907";
else if start_month=8 and start_year=2019 then date1="201908";
else if start_month=9 and start_year=2019 then date1="201909";
else if start_month=10 and start_year=2019 then date1="201910";
else if start_month=11 and start_year=2019 then date1="201911";
else if start_month=12 and start_year=2019 then date1="201912";
else if start_month=1 and start_year=2020 then date1="202001";
else if start_month=2 and start_year=2020 then date1="202002";
else if start_month=3 and start_year=2020 then date1="202003";
else date1="";
run;

proc sql;
create table file3 as
select count(incident_id) as count, date1
from file2
group by date1;
quit;

proc means data=project.file7;
var distance_miles;
run;

data project.file7;
set project.file7;
Format quarter $20.;
if month(start_date) in (6,7,8) and year(start_date)=2016 then quarter = "16.3Summer";
else if month(start_date) in (9,10,11) and year(start_date)=2016 then quarter = "16.4Fall";
else if month(start_date)=12 and year(start_date)=2016 then quarter = "17.1Winter";
else if month(start_date) in (1,2) and year(start_date)=2017 then quarter = "17.1Winter";
else if month(start_date) in (3,4,5) and year(start_date)=2017 then quarter = "17.2Spring";
else if month(start_date) in (6,7,8) and year(start_date)=2017 then quarter = "17.3Summer";
else if month(start_date) in (9,10,11) and year(start_date)=2017 then quarter = "17.4Fall";
else if month(start_date)=12 and year(start_date)=2017 then quarter = "18.1Winter";
else if month(start_date) in (1,2) and year(start_date)=2018 then quarter = "18.1Winter";
else if month(start_date) in (3,4,5) and year(start_date)=2018 then quarter = "18.2Spring";
else if month(start_date) in (6,7,8) and year(start_date)=2018 then quarter = "18.3Summer";
else if month(start_date) in (9,10,11) and year(start_date)=2018 then quarter = "18.4Fall18";
else if month(start_date)=12 and year(start_date)=2018 then quarter = "19.1Winter";
else if month(start_date) in (1,2) and year(start_date)=2019 then quarter = "19.1Winter";
else if month(start_date) in (3,4,5) and year(start_date)=2019 then quarter = "19.2Spring";
else if month(start_date) in (6,7,8) and year(start_date)=2019 then quarter = "19.3Summer";
else if month(start_date) in (9,10,11) and year(start_date)=2019 then quarter = "19.4Fall";
else if month(start_date)=12 and year(start_date)=2019 then quarter = "20.1Winter";
else if month(start_date) in (12,1,2) and year(start_date)=2020 then quarter = "20.1Winter";
else if month(start_date) in (3,4,5) and year(start_date)=2020 then quarter = "20.2Spring";
run;

proc sql;
create table test as
select count(incident_id) as crimes_reported,mean(crime_rate) as Avg_crime_rate,
quarter
from project.file7
group by quarter;
quit;

proc sgplot data=test noborder;
    vbarparm category=quarter response=crimes_reported / dataskin=pressed;
    series x=quarter y=Avg_crime_rate / y2axis lineattrs=(color=Red thickness=4) datalabel;
    xaxis discreteorder=data;
    yaxis ;
    y2axis values=(18 to 20 by 0.2) offsetmin=0;
run;

proc sql;
create table test as
select count(incident_id) as crimes_reported,season
from project.file7
where start_year in (2017,2018,2019)
group by season;
quit;

proc template;
	define statgraph SASStudio.Pie;
		begingraph;
		layout region;
		piechart category=season response=crimes_reported /
		    DATALABELLOCATION = INSIDE
		    DATALABELATTRS=(size=12pt color=WHITE)
            DATALABELCONTENT = ALL
            CATEGORYDIRECTION = CLOCKWISE
            START = 180 NAME = 'pie';
		endlayout;
		endgraph;
	end;
run;

ods graphics / reset width=6.4in height=4.8in imagemap;

proc sgrender template=SASStudio.Pie data=WORK.test;
run;

proc sql;
create table test as
select count(incident_id) as crimes_reported,timeshift,place,zip_code
from project.file7
group by timeshift,place,zip_code;
quit;

proc sql;
create table test as
select count(incident_id) as crimes_reported,mean(crime_rate) as Avg_crime_rate,
quarter
from project.file7
group by quarter;
quit;

proc sgplot data=test noborder;
    vbarparm category=quarter response=crimes_reported / dataskin=pressed;
    series x=quarter y=Avg_crime_rate / y2axis lineattrs=(color=Red thickness=4) datalabel;
    xaxis discreteorder=data;
    yaxis ;
    y2axis values=(18 to 20 by 0.2) offsetmin=0;
run;


/* MODEL BUILDING */
/* GLM regression for Avg Crime Rate */
proc sql;
create table test1 as
select mean(crime_rate) as Avg_crime_rate,quarter
from project.file7
group by quarter;
quit;

data test1;
set test1(drop=quarter);
Tslot=_N_;
run;

proc reg data=test1 outest=RegOut;
   OxyHat: model Avg_crime_rate = Tslot;
   title 'Regression Scoring Example';
run;
proc print data=RegOut;
   title2 'OUTEST= Data Set from PROC REG';
run;
proc score data=test1 score=RegOut out=RScoreP type=parms;
   var Tslot;
run;
proc print data=RScoreP;
   title2 'Predicted Scores for Regression';
run;
proc score data=test1 score=RegOut out=RScoreR type=parms;
   var Avg_crime_rate Tslot;
run;
proc print data=RScoreR;
   title2 'Negative Residual Scores for Regression';
run;





/* Prediction GLM model on Response Time */

data project.model_base;
 set project.file7;
 if cmiss(of _all_) then delete;
run;

proc sql;
create table base as
select zip_code,unemployment_rate,race_majority,
race_percentage,white,black,hispanic_or_latino,population,male,female
from project.model_base
group by zip_code;
quit;

proc sql;
create table test as
select distinct beat,zip_code
from project.model_base
group by zip_code;
quit;

proc sql;
create table base1 as
select count(beat) as count_beats,zip_code
from test
group by zip_code;
quit;

proc sql;
create table base2 as
select a.*,b.count_beats
from base a
left join base1 b
on a.zip_code=b.zip_code;
quit;

proc sql;
create table base4 as
select zip_code,crime_name1,place,mean(distance_miles) as Avg_distance,
timeshift,season,mean(response_time1) as Avg_Response_time
from project.model_base
group by zip_code,crime_name1,place,timeshift,season;
quit;

proc sql;
create table base3 as
select a.*,b.*
from base4 a
left join base2 b
on a.zip_code=b.zip_code;
quit;


%web_drop_table(WORK.IMPORT);


FILENAME REFFILE '/folders/myfolders/Project/final_SAS_data.csv';

PROC IMPORT DATAFILE=REFFILE
	DBMS=CSV
	OUT=WORK.IMPORT;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=WORK.IMPORT; RUN;


%web_open_table(WORK.IMPORT);

data model;
set work.import;
run;

proc reg data=model outest=RegOut;
   OxyHat: model Avg_Response_time=Avg_distance Unemployment_rate Race_Percentage
		Black Hispanic_or_Latino Population Male Female count_beats 
		Crime_Name1_Crime_Against_Person Crime_Name1_Crime_Against_Proper 
		Crime_Name1_Crime_Against_Societ Crime_Name1_Not_a_Crime Crime_Name1_Other 
		place1_Others place1_Parking_Lot place1_Residence place1_Retail place1_Street 
		timeshift_12am_6am timeshift_12pm_6pm timeshift_6am_12pm timeshift_6pm_12am 
		season_Fall season_Spring season_Summer season_Winter;
   title 'Regression Scoring Example';
run;   


   
/* Principal Component Analysis */

ods noproctitle;
ods graphics / imagemap=on;

proc princomp data=model plots(only)=(scree);
    var Avg_distance Avg_Response_time Unemployment_rate Race_Percentage White 
        Black Hispanic_or_Latino Population Male Female count_beats 
        Crime_Name1_Crime_Against_Person Crime_Name1_Crime_Against_Proper 
        Crime_Name1_Crime_Against_Societ Crime_Name1_Not_a_Crime Crime_Name1_Other 
        place1_Others place1_Parking_Lot place1_Residence place1_Retail place1_Street 
        timeshift_12am_6am timeshift_12pm_6pm timeshift_6am_12pm timeshift_6pm_12am 
        season_Fall season_Spring season_Summer season_Winter 
        Race_Majority_African_American Race_Majority_Black Race_Majority_Hispanic 
        Race_Majority_White;
run;