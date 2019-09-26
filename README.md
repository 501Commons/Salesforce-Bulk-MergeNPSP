Salesforce-Mass-Merge-ServiceManagement
====================

Setup Steps after Deployment

## Installation Package


## How To Document

501 Commons Duplicate Management

Summary

Duplicate Management supports
•	Individual merging between 2 Accounts or 2 Contacts
•	Mass merging between 50+ Accounts and/or Contacts from a single Screen
•	Automated merging that runs on a schedule to automatically perform merging
Setup

1)	Setup a Sandbox to perform your validation

2)	Managed Package installation link: https://test.salesforce.com/packaging/installPackage.apexp?p0=04t4P000000gZwj 

NOTE: This link cannot be used to install in a Production organization.  Once you’ve validated the functionality is working correctly in a Sandbox environment then send an email to 501 Commons for a Production install URL mailto:sfconsulting@501commons.org.

3)	Select the ‘Mass Merge’ App from the App Launcher

 


4)	Create a new merge rule by saving a report into the ‘Mass Merge Rules’ report folder

•	Click on Reports then All Folders 

Merge rules are based on reports that you create and specific which fields to use for Merge by adding report columns.

 

•	Report Folders
i.	Mass Merge Rules – Initially this folder is empty.  To create a new merge rule, create and save a report into the Mass Merge Rules folder.
ii.	Mass Merge Templates – There are a copy of sample reports saved in the Templates folder.  Feel free to Save one or more of those reports into the Rules folder to help get you started.

 

•	Edit Report

For instance in the Template folder there is a report called Merge Rule Contact Name and DOB.  This report has 3 columns; First Name, Last Name, and Birthdate.  When you run this rule any Contacts that have the same First Name, Last Name, and Birthdate will be discovered and associated with this rule.  You can add/remove columns based on what you want to use for the merge criteria.  You can also add report filters to restrict the data that will be evaluated for merging.

 



5)	Discover any potential duplicates based on your new rules

•	Select Merge Metrics

 

•	Select the All NPSP List View

 

•	Go ahead and pin the Listview so this view shows any time you click on Merge Metrics

 

•	Click the Discover Action Button

i.	Lightning this is a Discover button on the upper right of the screen.

 

ii.	Classic this is a Discover button on the upper left of the screen

 

iii.	Before clicking Discover Button – there aren’t any merge metrics discovered

 

iv.	After click Discover Button – there will be a new merge metric for each report you save in the Rules folder.

 

6)	Perform 1 of the 3 merge scenarios

•	Individual Merge and Mass Merge

i.	Click on Mass Merge Contacts

 

ii.	Click on Household to select a specific Household

 

iii.	Pick the Master Record then hit Save

 

Select Ignore then Save will block this same merge candidate related to the 2 contacts from appearing in the list.

Mass Merge – if there are multiple merge candidates that will be listed on the screen and you can go through and update the Merge Action for each of the ones you want to merge then hit Save.

•	Automated Merge

i.	Edit the Merge Metric record that you want to setup automated merging

 

ii.	There are 2 fields that control when to Automerge which by default is turned off

1.	AutoMerge Percentage – automerge will automatically merge any merge candidates for this rule where the Confidence value is greater than or equal to the AutoMerge Percentage.  The default percentage confidence for merge candidates found by this rule is 90% so setting this value to 90% will auto merge candidates found by this rule that qualify for the default confidence value.  Confidence is an algorithm based on how closely related the merge candidates are between the fields specified for the rule.  If the fields are an exact match then the confidence is 90%.  If the fields are somewhat related then the confidence would be less than 90%.

 

2.	AutoMerge Objects – there are 3 options

a.	Account – Merge both Accounts into a single account.  Merge any contacts that match otherwise leave the unmatched contacts in the non-Master Account.
b.	Contacts Within Account – Merge Contacts that are found within the same Account.
c.	Contacts Across Accounts – Merge Contacts that are found between two different Accounts.

You can turn on 1 or more of these merge rules for auto merging.

