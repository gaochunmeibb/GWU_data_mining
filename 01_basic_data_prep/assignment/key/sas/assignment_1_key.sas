*** import from csv **********************************************************; 

* use SAS macro variable for convenience; 
%let data_dir = C:\workspace\GWU_data_mining\01_basic_data_prep\assignment\raw;

* import offers.csv;
* . after macro variable signifies the end of the macro variable; 
proc import 
	datafile="&data_dir.\offers.csv"
	out=offers
	dbms=csv
	replace;
run;

* import testHistory.csv; 
proc import 
	datafile="&data_dir.\testHistory.csv"
	out=test
	dbms=csv
	replace;
run;
 
* import trainHistory.csv;
proc import 
	datafile="&data_dir.\trainHistory.csv"
	out=train
	dbms=csv
	replace;
run;

* import transactions.csv;
proc import 
	datafile="&data_dir.\transactions.csv"
	out=transactions (keep=id category purchaseamount purchasequantity)
	dbms=csv
	replace;
run;

*** drop repeattrips *********************************************************;

data train; 
	set train(drop=repeattrips);
run;

*** left join offers onto the training and test data *************************;

proc sql;
	create table joined_train as
	select * from train 
	left join offers 
	on train.offer = offers.offer;
quit;

proc sql;
	create table joined_test as
	select * from test 
	left join offers 
	on test.offer = offers.offer;
quit;

*** add past category transactions *********************************************;

proc sql;

	create table grouped_category as
	select id, category, mean(purchasequantity) as mean_category_quantity, 
		mean(purchaseamount) as mean_category_amount
	from transactions
	group by id, category;

quit; 

* join with SAS data step merge - easier imputation than SQL query;
proc sort
	data=Joined_train
	sortsize=MAX;
	by id category;
run;
data joined_train; 
	merge joined_train(in=x) grouped_category; 
	by id category; 
	if mean_category_amount = . then mean_category_amount = 0;
	if mean_category_quantity = . then mean_category_quantity = 0;
	if x;
run;

proc sort
	data=Joined_test
	sortsize=MAX;
	by id category;
run;
data joined_test; 
	merge joined_test(in=x) grouped_category; 
	by id category; 
	if mean_category_amount = . then mean_category_amount = 0;
	if mean_category_quantity = . then mean_category_quantity = 0;
	if x;
run;

*** bonus question ***********************************************************;

proc sort data=transactions sortsize=MAX; by category; run;
proc sort data=offers; by category; run;

data transactions_offers; 
	merge transactions offers;
	by category; 
	if offer ne .;
run;

proc sql;

	create table grouped_cat_brand_company as
	select  id, category, brand, company, sum(purchasequantity) as exact_item_bought
	from transactions_offers
	group by id, category, brand, company;

quit;

proc sort
	data=joined_train
	sortsize=MAX;
	by id category brand company;
run;
data joined_train; 
	merge joined_train(in=x) grouped_cat_brand_company(keep=id category brand company exact_item_bought); 
	by id category brand company; 
	if exact_item_bought = . then exact_item_bought = 0;
	if exact_item_bought > 0 then exact_item_bought = 1;
	else exact_item_bought = 0;
	if x;
run;

proc sort
	data=Joined_test
	sortsize=MAX;
	by id category brand company;
run;
data joined_test; 
	merge joined_test(in=x) Grouped_cat_brand_company(keep=id category brand company exact_item_bought); 
	by id category brand company; 
	if exact_item_bought = . then exact_item_bought = 0;
	if exact_item_bought > 0 then exact_item_bought = 1;
	else exact_item_bought = 0;
	if x;
run;

*** output submission files to csv *******************************************;

data joined_train_subset; 
	set joined_train; 
	where id < 14000000; 
run;
proc print; run;

proc export data=joined_train_subset
	outfile="&data_dir.\train_submit.csv"
	dbms=csv
	replace;
run; 

data joined_test_subset; 
	set joined_test; 
	where id > 4810000000; 
run;
proc print; run;

proc export data=joined_test_subset
	outfile="&data_dir.\test_submit.csv"
	dbms=csv
	replace;
run;

