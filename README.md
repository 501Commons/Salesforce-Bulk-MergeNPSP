Salesforce-Bulk-MergeNPSP-ServiceManagement
====================

Setup Steps after Deployment

## Deploy Project

Deploy to Production or Sandbox using; cci task run deploy

## Setup Schedules

    ```
      - Open Developer Console
      - Debug Menu select Open Execute Anonymous Window (CTRL+E)
      - Paste the following rules then click Execute

      C501_MM_Rule_Account_Address accountAddress = new C501_MM_Rule_Account_Address();
      accountAddress.execute(null);
      C501_MM_Rule_Account_Website accountWebsite = new C501_MM_Rule_Account_Website();
      accountWebsite.execute(null);
      C501_MM_Rule_Contact_NameDOB contactNameDOB = new C501_MM_Rule_Contact_NameDOB();
      contactNameDOB.execute(null);
      C501_MM_Rule_Contact_NameEmail contactNameEmail = new C501_MM_Rule_Contact_NameEmail();
      contactNameEmail.execute(null);

    ```

## Enable Merge Metrics

- Select the Mass Merge Application
- Select Merge Metrics
- Change List View to All

You should now see the new rules (e.g., Merge Metric names)

- Select a rule that you want to Enable, open the Rule and check Enable & Save.  Repeat for any other rules you want to enable
- Select a rule that you want to enable Automated Merging.  Set the AutoMerge Percentage which is the threshold for any potential merge found with Confidence greater or equal to the AutoMerge percentage will be automatically merge when the daily schedule runs.  The Merge Metric has the acive confidence value which means when the daily schedule runs any potential merges found based on this rule will get that confidence value.  The confidence value on a rule can change as you set more and more potential merges found by this rule to Ignore in the Mass Merge screen.

## Rule Definitions

* Account_Address - Shipping Street, City, State, PostalCode or Billing Street, City, State, PostalCode exact match between two accounts.  Two accounts must have the same Shipping or the same Billing Addresses.
* Account_Website - Website extact match between two accounts.
* Contact_NameDOB - FirstName, LastName, Birthdate exact match between 2 contacts from different Households.  FirstName and Birthdate must have a valid value.
* Contact_NameEmail - FirstName, LastName, Email exact match between 2 contacts from different Households.  FirstName and Email must have a valid value.
