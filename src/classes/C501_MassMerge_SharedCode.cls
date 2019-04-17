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

    global String GetAllIterableFields(String sObjectType) {

        Set<String> fieldNames = schema.describeSObjects(new String[] { sObjectType })[0].fields.getMap().keyset();
        List<String> iterableFields = new List<String>(fieldNames);

        return String.join(iterableFields, ',');
    }

    global void ObjectsMerge_Account(Account masterAccount, List<Account> duplicateAccounts) {
    }

    global void ObjectsMerge_Contact(Contact masterContact, List<Contact> duplicateContacts) {

        if (masterContact == null || duplicateContacts == null || duplicateContacts.isEmpty()) {
            return;
        }

        // Merge contacts into master
        System.debug('***** C501_MassMerge_SharedCode::ContactsMerge masterContact: ' + String.valueOf(masterContact) + ' duplicateContacts: ' + String.valueOf(duplicateContacts));

        String mergeMetricName = 'Account_NoContacts';
        List<C501_Merge_Metric__c> mergeMetrics = [
            SELECT
                Id, Name, Confidence__c,
                Total_Unassigned_Accounts__c, Total_Unassigned_Contacts__c,
                Enable__c,
                AutoMerge_Percentage__c, AutoMerge_Objects__c
            FROM C501_Merge_Metric__c
            WHERE Name = :mergeMetricName];

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

    global void ScheduleJobs(C501_Merge_Metric__c mergeMetric) {

        System.debug('***** C501_MassMerge_SharedCode::ScheduleJobs mergeMetric: ' + String.valueOf(mergeMetric));

        // Hourly Offset to try to avoid rules running at the same time
        Integer hourlyOffset = 0;
        if (mergeMetric.Name == 'Account_Address') {
            hourlyOffset = 1;
        }
        else if (mergeMetric.Name == 'Account_NoContacts') {
            hourlyOffset = 4;
        }
        else if (mergeMetric.Name == 'Account_Website') {
            hourlyOffset = 2;
        }
        else if (mergeMetric.Name == 'Contact_NameDOB') {
            hourlyOffset = 0;
        }
        else if (mergeMetric.Name == 'Contact_NameEmail') {
            hourlyOffset = 3;
        }

        Boolean hourlySyncOnly = true;

        if (mergeMetric.AutoMerge_Percentage__c <> null && mergeMetric.AutoMerge_Percentage__c > 0.0) {
            List<String> automergeObjects = mergeMetric.AutoMerge_Objects__c.split(';');

            System.debug('***** C501_MassMerge_SharedCode::ScheduleJobs automergeObjects: ' + String.valueOf(automergeObjects));

            for (String automergeObject : automergeObjects) {
                if ((automergeObject.equals('Contacts Within Account') || automergeObject.equals('Contacts Across Accounts')) && mergeMetric.Total_Unassigned_Contacts__c > 0) {
                    System.debug('***** C501_MassMerge_SharedCode::ScheduleJobs Enable 5min merging based on Contact match');
                    hourlySyncOnly = false;

                    break;
                }

                if (automergeObject.equals('Account') && mergeMetric.Total_Unassigned_Accounts__c > 0) {
                    System.debug('***** C501_MassMerge_SharedCode::ScheduleJobs Enable 5min merging based on Account match');
                    hourlySyncOnly = false;

                    break;
                }
            }
        }

        List<CronJobDetail> cronJobDetails = [SELECT Id, JobType, Name FROM CronJobDetail];
        List<CronTrigger> cronTriggers = [SELECT Id, CronJobDetailId FROM CronTrigger];
        Boolean foundHourlySyncTrigger = false, foundAdditionalSyncTriggers = false;
        for (CronJobDetail jobDetail :cronJobDetails) {

            // Check for hourly trigger
            if (jobDetail.Name.equals(mergeMetric.Name + '_0')) {
                foundHourlySyncTrigger = true;
            }
            else if (jobDetail.Name.startsWith(mergeMetric.Name + '_')) {

                foundAdditionalSyncTriggers = true;
                if (hourlySyncOnly) {
                    for (CronTrigger cronTrigger :cronTriggers) {
                        
                        // Stop Sync
                        if (cronTrigger.CronJobDetailId == jobDetail.Id) {
                            System.abortJob(cronTrigger.Id);
                        }
                    }
                }
            }
        }

        // Check to disable rule when creating the schedule to avoid overloading system
        Boolean resetMergeMetricEnabled = mergeMetric.Enable__c;
        if (resetMergeMetricEnabled) {
            mergeMetric.Enable__c = false;
            update mergeMetric;
        }

        if (!foundHourlySyncTrigger || !foundAdditionalSyncTriggers) {

            // Run every 5 minutes if there are more than 100 pending merges based on the automerge percentage otherwise set to hourly (abort all other hourly scheduled jobs except 0 one)
            // Check scheduled jobs limits - online thread mentioned 100
            // Salesforce only supports hourly not minute interval format 0 0/5 00 for s m h not supported which is every 5 minutes
            String cronExpression, mergeMetricNameSchedule;

            Integer triggerNumber = 0;
            for (integer i = hourlyOffset; i <= 59; i += 5) {
                cronExpression = '0 ' + String.valueOf(i) + ' * * * ?';
                mergeMetricNameSchedule = mergeMetric.Name + '_' + String.valueOf(triggerNumber++);

                // Check if Hourly Sync Trigger already created
                if (foundHourlySyncTrigger && i == hourlyOffset) {

                    if (hourlySyncOnly || foundAdditionalSyncTriggers) {
                        System.debug('***** C501_MassMerge_SharedCode::ScheduleJobs break out');
                        break;
                    }

                    continue;
                }

                System.debug('***** C501_MassMerge_SharedCode::ScheduleJobs schedule job mergeMetricNameSchedule: ' + mergeMetricNameSchedule + ' cronExpression: ' + cronExpression);

                // Optimization for future since this is a only unique code - call out here to a Virtual function that can be overloaded from a child (e.g., SM Rules - C501_SM_Rule_Contact_NameDOB)
                if (mergeMetric.Name == 'Account_Address') {
                    System.schedule(mergeMetricNameSchedule, cronExpression, new C501_MM_Rule_Account_Address());
                }
                else if (mergeMetric.Name == 'Account_NoContacts') {
                    System.schedule(mergeMetricNameSchedule, cronExpression, new C501_MM_Rule_Account_NoContacts());
                }
                else if (mergeMetric.Name == 'Account_Website') {
                    System.schedule(mergeMetricNameSchedule, cronExpression, new C501_MM_Rule_Account_Website());
                }
                else if (mergeMetric.Name == 'Contact_NameDOB') {
                    if (i == hourlyOffset) {
                        // Hourly discovery of new merge candidates
                        System.schedule(mergeMetricNameSchedule, cronExpression, new C501_MM_Rule_Contact_NameDOB());
                    }
                    else {
                        // 5 min increments for processing merge candidates
                        System.schedule(mergeMetricNameSchedule, cronExpression, new C501_MM_Rule_Contact_NameDOB_Process());
                    }
                }
                else if (mergeMetric.Name == 'Contact_NameEmail') {
                    System.schedule(mergeMetricNameSchedule, cronExpression, new C501_MM_Rule_Contact_NameEmail());
                }

                if (hourlySyncOnly || foundAdditionalSyncTriggers) {
                    break;
                }
            }
        }

        if (resetMergeMetricEnabled) {
            mergeMetric.Enable__c = true;
            update mergeMetric;
        }
    }

    global void TestSetupMerge() {

        List<Account> listAccounts = new List<Account>();   
        integer cAccounts = 9;     
        for (integer i = 0; i < cAccounts; i++) {
            Account account = new Account(
                
                Name='Flintstone Household',
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
                Name = 'Name ' + account.Id,
                StageName = 'Closed Won',
                CloseDate = System.today()
            ));

            for (integer i = 0; i < cAccounts; i++) {

                listContacts.add( new Contact(
                    LastName = 'Flintstone',
                    FirstName = 'Fred',
                    AccountId = account.Id,
                    Birthdate = date.today().addYears(-21),
                    Email = 'fred@bedrock.org',
                    Gender__c = 'Male'
                ));

                listContacts.add( new Contact(
                    LastName = 'Flintstone',
                    FirstName = 'Wilma',
                    AccountId = account.Id,
                    Birthdate = date.today().addYears(-21),
                    Email = 'wilma@bedrock.org',
                    Gender__c = 'Female'
                ));

                listContacts.add( new Contact(
                    LastName = 'Flintstone',
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