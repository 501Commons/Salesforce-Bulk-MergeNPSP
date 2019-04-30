/*
    Copyright (c) 2016, Salesforce.org
    All rights reserved.
    
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Salesforce.org nor the names of
      its contributors may be used to endorse or promote products derived
      FROM this software without specific prior written permission.
 
    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN 
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
    POSSIBILITY OF SUCH DAMAGE.
*/

global with sharing class C501_MassMerge_SharedCode { 

    // Legacy functions - delete
    void ScheduleJobs(C501_Merge_Metric__c mergeMetric) {

    }

    global String GetAllIterableFields(String sObjectType) {

        Set<String> fieldNames = schema.describeSObjects(new String[] { sObjectType })[0].fields.getMap().keyset();
        List<String> iterableFields = new List<String>(fieldNames);

        return String.join(iterableFields, ',');
    }

    global void InitializeMassMergeInstances(String reportFolder) {

        List<C501_Merge_Metric__c> mergeMetrics = [
            SELECT
                Id, Name, Confidence__c,
                Total_Unassigned_Accounts__c, Total_Unassigned_Contacts__c,
                Enable__c, Source_Report__c,
                AutoMerge_Percentage__c, AutoMerge_Objects__c,
                Last_Discover_Date__c
            FROM C501_Merge_Metric__c];

        System.debug('***** C501_MassMerge_SharedCode::InitializeMassMergeInstances Check for merge reports - Folder: ' + reportFolder);

        // Initialize Merge Metrics - make sure there is a merge metric for each report in Mass Merge folder
        List<C501_Merge_Metric__c> mergeMetricsInsert = new List<C501_Merge_Metric__c>();
        for (Report report :[
            SELECT Id, DeveloperName, FolderName, Name
            FROM Report
            WHERE
                FolderName = :reportFolder]) {

                System.debug('***** C501_MassMerge_SharedCode::InitializeMassMergeInstances report - Name: ' + report.Name);

                Boolean foundMergeMetric = false;
                for (C501_Merge_Metric__c mergeMetric :mergeMetrics) {
                    if (mergeMetric.Source_Report__c == (String)report.Id || mergeMetric.Source_Report__c == report.DeveloperName) {
                        foundMergeMetric = true;
                        break;
                    }
                }

                if (!foundMergeMetric) {
                    mergeMetricsInsert.add( new C501_Merge_Metric__c (
                        Name = (Test.isRunningTest() ? ('TESTDATA ' + report.Name) : report.Name),
                        Confidence__c = 90.0,
                        Source_Report__c = report.DeveloperName,
                        Source_Object__c = (report.DeveloperName.contains('Account') ? 'Account' : 'Contact'),
                        Source_Aggregate__c = (report.DeveloperName.contains('Account') ? 'Id' : 'AccountId'),
                        AutoMerge_Percentage__c = 0.0
                    ));
                }
        }

        if (!mergeMetricsInsert.isEmpty()) {
            insert mergeMetricsInsert;
        }
    }

    global void ObjectsMerge_Account(Account masterAccount, List<Account> duplicateAccounts) {
    }

    global void ObjectsMerge_Contact(Contact masterContact, List<Contact> duplicateContacts) {

        if (masterContact == null || duplicateContacts == null || duplicateContacts.isEmpty()) {
            return;
        }

        // Merge contacts into master
        System.debug('***** C501_MassMerge_SharedCode::ContactsMerge masterContact: ' + String.valueOf(masterContact) + ' duplicateContacts: ' + String.valueOf(duplicateContacts));

        String mergeMetricName = 'Merge Rule Account No Contacts';
        List<C501_Merge_Metric__c> mergeMetrics = [
            SELECT
                Id, Name, Confidence__c,
                Total_Unassigned_Accounts__c, Total_Unassigned_Contacts__c,
                Enable__c,
                AutoMerge_Percentage__c, AutoMerge_Objects__c
            FROM C501_Merge_Metric__c
            WHERE Name = :mergeMetricName];

        if (mergeMetrics.isEmpty()) {
            mergeMetrics.add( new C501_Merge_Metric__c (
                Name = (Test.isRunningTest() ? ('TESTDATA ' + mergeMetricName) : mergeMetricName),
                Enable__c = true,
                Confidence__c = 90.0,
                AutoMerge_Percentage__c = 90.0,
                AutoMerge_Objects__c = 'Account',
                Description__c = 'Accounts with no contacts.'
            ));

            insert mergeMetrics;
        }

        Set<Id> contactIds = new Set<Id> { masterContact.Id };
        for (Contact contact :duplicateContacts) {
            contactIds.add(contact.Id);
        }
        Map<Id, Account> contactAccounts = new Map<Id, Account>();
        for (Contact contact : [
            SELECT Id, AccountId, Account.npsp__Number_of_Household_Members__c FROM Contact WHERE Id in :contactIds]) {

            contactAccounts.put(contact.Id, new Account(
                Id = contact.AccountId,
                npsp__Number_of_Household_Members__c = contact.Account.npsp__Number_of_Household_Members__c));
        }

        System.debug('***** C501_MassMerge_SharedCode::ContactsMerge contactIds: ' + String.valueOf(contactIds) + ' contactAccounts: ' + String.valueOf(contactAccounts));

        // Check to add an account merge request - can not Account merge here because might be in a batch call which is not supported for Account merging
        Account masterAccount = contactAccounts.get(masterContact.Id);
        Map<String, C501_Account_Merge__c> accountMergeInserts = new Map<String, C501_Account_Merge__c>();
        for (Contact contact :duplicateContacts) {
            Account account = contactAccounts.get(contact.Id);
            if (account.Id <> masterAccount.Id && account.npsp__Number_of_Household_Members__c <= 1) {

                // Create an account merge because the duplicate account now has no children
                String maxId = (masterAccount.Id > account.Id) ? masterAccount.Id : account.Id;
                String minId = (masterAccount.Id <= account.Id) ? masterAccount.Id : account.Id;
                String uniqueId = mergeMetricName + maxId + minId;
                accountMergeInserts.put(uniqueId, new C501_Account_Merge__c(
                    Unique_Id__c = uniqueId,
                    Merge_Confidence__c = mergeMetrics[0].Confidence__c,
                    Account__c = minId,
                    Merge_Target_Account__c = maxId,
                    Merge_Metric__c = mergeMetrics[0].Id
                ));
            }
        }

        if (!accountMergeInserts.values().isEmpty()) {
            insert accountMergeInserts.values();
        }
    }

    /*
        @Param:List of selectOption to be sort.
        @Return: Sorted list of selectOptions by Label
    */
    global List<selectOption> SelectOptionSortByLabel(List<selectOption> selectOptionsToSort) {

        if (selectOptionsToSort == null || selectOptionsToSort.size() <= 1) {
            return selectOptionsToSort;
        }

        List<SelectOption> lessSelectOption = new List<SelectOption>();
        List<SelectOption> greaterSelectOption = new List<SelectOption>();
        integer pivot = selectOptionsToSort.size() / 2;
        
        //save the pivot and remove it FROM the selectOption list
        SelectOption pivotValue = selectOptionsToSort[pivot];
        selectOptionsToSort.remove(pivot);
        for(selectOption SO : selectOptionsToSort){
            if(SO.getLabel() <= pivotValue.getLabel()){
                lessSelectOption.add(SO);
            }else if(SO.getLabel() > pivotValue.getLabel()){
                greaterSelectOption.add(SO);   
            }
        }

        List<selectOption> sortedSelectOptions = new List<selectOption>(); 
        sortedSelectOptions.addAll(SelectOptionSortByLabel(lessSelectOption));
        sortedSelectOptions.add(pivotValue);
        sortedSelectOptions.addAll(SelectOptionSortByLabel(greaterSelectOption));

        return SortedSelectOptions;
    }

    global void ProcessMergeCandidates(C501_Merge_Metric__c mergeMetric, List<C501_Account_Merge__c> mergeAccounts) {

        C501_MassMerge_SharedCode_Account c501MassMerge_SharedCode_Account = new C501_MassMerge_SharedCode_Account();
        c501MassMerge_SharedCode_Account.InsertObjectMergeCandidates(mergeMetric, mergeAccounts);

        c501MassMerge_SharedCode_Account.ProcessObjectMergeCandidates(mergeMetric);
    }

    global void ProcessObjectMergeCandidates_Account(C501_Merge_Metric__c mergeMetric, List<C501_Account_Merge__c> pendingAutoMerges, Map<Id, Id> contactHouseholdMap) {

        List<String> automergeObjects = mergeMetric.AutoMerge_Objects__c.split(';');
        if (automergeObjects.contains('Account')) {

            if (!pendingAutoMerges.isEmpty()) {
                System.debug('***** C501_MassMerge_SharedCode::ProcessMergeCandidates Process auto merge candidates pendingAutoMerges: ' + String.valueOf(pendingAutoMerges));
                C501_MassMerge_SharedCode_Account c501MassMerge_SharedCode_Account = new C501_MassMerge_SharedCode_Account();
                c501MassMerge_SharedCode_Account.ProcessObjectMerges(pendingAutoMerges, false);
            }
        }
    }

    global void ProcessObjectMergeCandidates_Contact(C501_Merge_Metric__c mergeMetric, List<C501_Contact_Merge__c> pendingAutoMerges, Map<Id, Id> contactHouseholdMap) {

        List<String> automergeObjects = mergeMetric.AutoMerge_Objects__c.split(';');
        if (automergeObjects.contains('Contacts Within Account') || automergeObjects.contains('Contacts Across Accounts')) {

            List<C501_Contact_Merge__c> pendingAutoMergeCandidates = new List<C501_Contact_Merge__c>();
            for (C501_Contact_Merge__c pendingAutoMerge :pendingAutoMerges) {

                if (!contactHouseholdMap.containsKey(pendingAutoMerge.Contact__c) || !contactHouseholdMap.containsKey(pendingAutoMerge.Merge_Target_Contact__c)) {
                    continue;
                }

                if (automergeObjects.contains('Contacts Within Account') && contactHouseholdMap.get(pendingAutoMerge.Contact__c) == contactHouseholdMap.get(pendingAutoMerge.Merge_Target_Contact__c)) {
                    pendingAutoMergeCandidates.add(pendingAutoMerge);
                }
                
                if (automergeObjects.contains('Contacts Across Accounts') && contactHouseholdMap.get(pendingAutoMerge.Contact__c) != contactHouseholdMap.get(pendingAutoMerge.Merge_Target_Contact__c)) {
                    pendingAutoMergeCandidates.add(pendingAutoMerge);
                }
            }

            if (!pendingAutoMergeCandidates.isEmpty()) {
                C501_MassMerge_SharedCode_Contact c501MassMerge_SharedCode_Contact = new C501_MassMerge_SharedCode_Contact();
                c501MassMerge_SharedCode_Contact.ProcessObjectMerges(pendingAutoMergeCandidates, true);
            }
        }
    }

    global void ScheduleJobs(String scheduleName) {

        System.debug('***** C501_MassMerge_SharedCode::ScheduleJobs scheduleName: ' + scheduleName);

        List<CronJobDetail> cronJobDetails = [SELECT Id, JobType, Name FROM CronJobDetail];
        Set<String> scheduledJobs = new Set<String>();
        for (CronJobDetail jobDetail :cronJobDetails) {

            scheduledJobs.add(jobDetail.Name);
        }

        // Offset Discover and Merge so not running at the same time
        Integer minuteOffset = 0;
        if (scheduleName == C501_MM_Rule_Merge.class.getName()) {
            minuteOffset = 2; 
        }

        String cronExpression, scheduleJobName;
        Integer triggerNumber = 0;
        for (integer i = minuteOffset; i <= 59; i += 5) {
            cronExpression = '0 ' + String.valueOf(i) + ' * * * ?';
            scheduleJobName = scheduleName + '_' + (triggerNumber <= 9 ? '0' : '') + String.valueOf(triggerNumber++);

            if (scheduledJobs.contains(scheduleJobName)) {
                continue;
            }

            System.debug('***** C501_MassMerge_SharedCode::ScheduleJobs schedule job scheduleJobName: ' + scheduleJobName + ' cronExpression: ' + cronExpression);

            // Optimization for future since this is a only unique code - call out here to a Virtual function that can be overloaded from a child (e.g., SM Rules - C501_SM_Rule_Contact_NameDOB)
            if (scheduleName == C501_MM_Rule_Discover.class.getName()) {
                System.schedule(scheduleJobName, cronExpression, new C501_MM_Rule_Discover());
            }
            else if (scheduleName == C501_MM_Rule_Merge.class.getName()) {
                System.schedule(scheduleJobName, cronExpression, new C501_MM_Rule_Merge());
            }
        }
    }

    global void TestSetupMerge() {

        InitializeMassMergeInstances('Mass Merge Tests');

        List<Account> listAccounts = new List<Account>();   
        integer cAccounts = 9;     
        for (integer i = 0; i < cAccounts; i++) {
            Account account = new Account(
                
                Name='TESTDATA Flintstone Household',
                BillingStreet = 'BillingStreet',
                BillingCity = 'BillingCity',
                BillingState = 'WA',
                BillingPostalCode =  '12345',
                Website = 'https://www.flintstone.org'
            );

            listAccounts.add(account);
        }                      

        insert listAccounts;

        Map<Id, Opportunity> listOpportunityHouseholds = new Map<Id, Opportunity>();
        List<Contact> listContacts = new List<Contact>();
        for (Account account :listAccounts) {

            listOpportunityHouseholds.put(account.Id, new Opportunity(
                Name = 'TESTDATA Name ' + account.Id,
                StageName = 'Closed Won',
                CloseDate = System.today()
            ));

            for (integer i = 0; i < cAccounts; i++) {

                listContacts.add( new Contact(
                    LastName = 'TESTDATA Flintstone',
                    FirstName = 'Fred',
                    AccountId = account.Id,
                    Birthdate = date.today().addYears(-21),
                    Email = 'fred@bedrock.org',
                    Gender__c = 'Male'
                ));

                listContacts.add( new Contact(
                    LastName = 'TESTDATA Flintstone',
                    FirstName = 'Wilma',
                    AccountId = account.Id,
                    Birthdate = date.today().addYears(-21),
                    Email = 'wilma@bedrock.org',
                    Gender__c = 'Female'
                ));

                listContacts.add( new Contact(
                    LastName = 'TESTDATA Flintstone',
                    FirstName = 'Dino',
                    AccountId = account.Id,
                    Birthdate = date.today().addYears(-2),
                    Email = 'dino@bedrock.org'
                ));
            }
        }

        insert listOpportunityHouseholds.values();
        insert listContacts;

        // Print Structure
        //PrintSalesforceStructure();
    }

    global void PrintSalesforceStructure() {

        System.debug('***** C501_MassMerge_SharedCode::PrintSalesforceStructure');

        System.debug('***** C501_MassMerge_SharedCode::PrintSalesforceStructure - Account ' + String.valueOf([select Id, Name from Account]));
        System.debug('***** C501_MassMerge_SharedCode::PrintSalesforceStructure - Contact ' + String.valueOf([select Id, AccountId, LastName, Birthdate from Contact]));
        System.debug('***** C501_MassMerge_SharedCode::PrintSalesforceStructure - Opportunity ' + String.valueOf([select Id, Name from Opportunity]));

        for (C501_Account_Merge__c mergeAccount :[select Id, Merge_Confidence__c, Merge_Action__c from C501_Account_Merge__c]) {
            System.debug('***** C501_MassMerge_SharedCode::PrintSalesforceStructure - C501_Account_Merge__c ' + String.valueOf(mergeAccount));
        }

        for (C501_Contact_Merge__c mergeContact :[select Id, Merge_Confidence__c, Merge_Action__c from C501_Contact_Merge__c]) {
            System.debug('***** C501_MassMerge_SharedCode::PrintSalesforceStructure - C501_Contact_Merge__c ' + String.valueOf(mergeContact));
        }
    }
}