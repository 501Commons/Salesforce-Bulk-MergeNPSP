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

    public class C501_MassMerge_SharedCodeException extends Exception {}

    global String GetAllIterableFields(String sObjectType) {

        Set<String> fieldNames = schema.describeSObjects(new String[] { sObjectType })[0].fields.getMap().keyset();
        List<String> iterableFields = new List<String>(fieldNames);

        return String.join(iterableFields, ',');
    }

    global void AccountsMerge(Account masterAccount, List<Account> duplicateAccounts) {

        // Merge accounts into master
        System.debug('***** C501_MassMerge_SharedCode::AccountsMerge masterAccount: ' + String.valueOf(masterAccount) + ' duplicateAccounts: ' + String.valueOf(duplicateAccounts));

        Database.MergeResult[] accountResults = Database.merge(masterAccount, duplicateAccounts, false);

        for(Database.MergeResult res : accountResults) {
            if (res.isSuccess()) {
                System.debug('***** C501_MassMerge_SharedCode::AccountsMerge Account Merge Successful');
            }
            else {
                for (Database.Error err : res.getErrors()) {
                    System.debug('***** C501_MassMerge_SharedCode::AccountsMerge Account Merge Exception: ' + err.getMessage());
                }

                throw new C501_MassMerge_SharedCodeException('Account Merge Attempt - ' + String.valueOf(res.getErrors()));
            }
        }

        Set<Id> accountIds = new Set<Id> { masterAccount.Id };
        for (Account duplicateAccount :duplicateAccounts) {
            accountIds.add(duplicateAccount.Id);
        }

        List<C501_Account_Merge__c> deleteMerges = [
            SELECT Id
            FROM C501_Account_Merge__c
            WHERE Account__c = null
                OR Merge_Target_Account__c = null
                OR Account__c in :accountIds
                OR Merge_Target_Account__c in :accountIds];

        if (!deleteMerges.isEmpty()) {
            delete deleteMerges;
        }
    }

    global void ContactsMerge(Contact masterContact, List<Contact> duplicateContacts) {

        // Merge contacts into master
        System.debug('***** C501_MassMerge_SharedCode::ContactsMerge masterContact: ' + String.valueOf(masterContact) + ' duplicateContacts: ' + String.valueOf(duplicateContacts));

        Database.MergeResult[] contactResults = Database.merge(masterContact, duplicateContacts, false);

        for(Database.MergeResult res : contactResults) {
            if (res.isSuccess()) {
                System.debug('***** C501_MassMerge_SharedCode::ContactsMerge Contact Merge Successful');
            }
            else {
                for (Database.Error err : res.getErrors()) {
                    System.debug('***** C501_MassMerge_SharedCode::ContactsMerge Contact Merge Exception: ' + err.getMessage());
                }

                throw new C501_MassMerge_SharedCodeException('Contact Merge Attempt - ' + String.valueOf(res.getErrors()));
            }
        }

        Set<Id> accountIds = new Set<Id> { masterContact.AccountId };
        for (Contact duplicateContact :duplicateContacts) {
            accountIds.add(duplicateContact.AccountId);
        }

        List<C501_Account_Merge__c> deleteMerges = [
            SELECT Id
            FROM C501_Account_Merge__c
            WHERE Account__c = null
                OR Merge_Target_Account__c = null
                OR Account__c in :accountIds
                OR Merge_Target_Account__c in :accountIds];

        if (!deleteMerges.isEmpty()) {
            delete deleteMerges;
        }
    }

    // the list of Accounts
    global List<SelectOption> listAccountsWithConfidence(String mergeRule, Decimal fromMergeConfidence, Decimal toMergeConfidence) {

        System.debug('***** C501_MassMerge_SharedCode::listAccountsWithConfidence - mergeRule: ' + mergeRule 
            + ' fromMergeConfidence: ' + fromMergeConfidence.toPlainString()
            + ' toMergeConfidence: ' + toMergeConfidence.toPlainString());

        Set<String> setSOUnique = new Set<String>();
        List<SelectOption> listSO = new List<SelectOption>();
        listSO.add(new SelectOption('', ''));

        if (String.isBlank(mergeRule)) {
            for (AggregateResult result : [
                SELECT Account__c, Account__r.Name
                FROM C501_Account_Merge__c
                WHERE Merge_Confidence__c >= :fromMergeConfidence
                    and Merge_Confidence__c <= :toMergeConfidence
                    and Merge_Action__c <> 'Ignore' 
                GROUP BY Account__c, Account__r.Name
                LIMIT 999]) {
                    listSO.add(new SelectOption(result.get('Account__c').toString(),
                        result.get('Name').toString()));
            }
        }
        else {
            for (AggregateResult result : [
                SELECT Account__c, Account__r.Name
                FROM C501_Account_Merge__c
                WHERE Merge_Confidence__c >= :fromMergeConfidence
                    and Merge_Confidence__c <= :toMergeConfidence
                    and Merge_Action__c <> 'Ignore' 
                    and Merge_Metric__r.Name = :mergeRule
                GROUP BY Account__c, Account__r.Name
                LIMIT 999]) {
                    listSO.add(new SelectOption(result.get('Account__c').toString(),
                        result.get('Name').toString()));
            }
        }

        List<SelectOption> listSOSorted = new List<SelectOption>();
        listSOSorted = selectOptionSortByLabel(listSO);

        return listSOSorted;
    }

    global List<SelectOption> listContactsWithConfidence(String mergeRule, Decimal fromMergeConfidence, Decimal toMergeConfidence) {

        System.debug('***** C501_MassMerge_SharedCode::listContactsWithConfidence - mergeRule: ' + mergeRule 
            + ' fromMergeConfidence: ' + fromMergeConfidence.toPlainString()
            + ' toMergeConfidence: ' + toMergeConfidence.toPlainString());

        Set<String> setSOUnique = new Set<String>();
        List<SelectOption> listSO = new List<SelectOption>();
        listSO.add(new SelectOption('', ''));

        if (String.isBlank(mergeRule)) {
            for (AggregateResult result : [
                SELECT Contact__c, Contact__r.Name
                FROM C501_Contact_Merge__c
                WHERE Merge_Confidence__c >= :fromMergeConfidence
                    and Merge_Confidence__c <= :toMergeConfidence
                    and Merge_Action__c <> 'Ignore' 
                GROUP BY Contact__c, Contact__r.Name
                LIMIT 999]) {
                    listSO.add(new SelectOption(result.get('Contact__c').toString(),
                        result.get('Name').toString()));
            }
        }
        else {
            for (AggregateResult result : [
                SELECT Contact__c, Contact__r.Name
                FROM C501_Contact_Merge__c
                WHERE Merge_Confidence__c >= :fromMergeConfidence
                    and Merge_Confidence__c <= :toMergeConfidence
                    and Merge_Action__c <> 'Ignore' 
                    and Merge_Metric__r.Name = :mergeRule
                GROUP BY Contact__c, Contact__r.Name
                LIMIT 999]) {
                    listSO.add(new SelectOption(result.get('Contact__c').toString(),
                        result.get('Name').toString()));
            }
        }

        List<SelectOption> listSOSorted = new List<SelectOption>();
        listSOSorted = selectOptionSortByLabel(listSO);

        return listSOSorted;
    }

    /*
        @Param:List of selectOption to be sort.
        @Return: Sorted list of selectOptions by Label
    */
    public static list<selectOption> selectOptionSortByLabel(list<selectOption>
                                                            selectOptionsToSort) {
        if(selectOptionsToSort == null || selectOptionsToSort.size() <= 1){
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

        list<selectOption> sortedSelectOptions = new list<selectOption>(); 
        sortedSelectOptions.addAll(selectOptionSortByLabel(lessSelectOption));
        sortedSelectOptions.add(pivotValue);
        sortedSelectOptions.addAll(selectOptionSortByLabel(greaterSelectOption));

        return SortedSelectOptions;
    }

    global void ProcessMergeCandidates(C501_Merge_Metric__c mergeMetric, List<C501_Account_Merge__c> mergeAccounts) {

        //
		// Perform all DML (Data Manipulation Language) calls (insert, update, merge, delete, restore) outside of loop to avoid Salesforce Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
        //
		if (!mergeAccounts.isEmpty()) {
			Database.SaveResult[] insertResults = Database.insert(mergeAccounts, false);

            for (Database.SaveResult result : insertResults) {
                System.debug('***** C501_MassMerge_SharedCode::ProcessMergeCandidates Merge Results: ' + String.valueOf(result));
                // TBD - Look for anything other than Duplicate Id Error on Unique_Id__c which is expected
            }
		}

        // Delete Merge Candidates that do not have valid accounts
        List<C501_Account_Merge__c> invalidMerges = new List<C501_Account_Merge__c>();
        for (C501_Account_Merge__c accountMerge :[
            SELECT Id, Account__c, Merge_Target_Account__c
            FROM C501_Account_Merge__c
            WHERE Merge_Metric__r.Name = :mergeMetric.Name
                AND (Account__c = null OR Merge_Target_Account__c = null)]) {
                
                invalidMerges.add(accountMerge);
            }

        if (!invalidMerges.IsEmpty()) {
            delete invalidMerges;
        }

        // Check if AutoMerge Enabled
        System.debug('***** C501_MassMerge_SharedCode::ProcessMergeCandidates Check AutoMerge AutoMerge_Percentage__c: ' + mergeMetric.AutoMerge_Percentage__c);
        if (mergeMetric.AutoMerge_Percentage__c == null || mergeMetric.AutoMerge_Percentage__c <= 0.0) {
            return;
        }

        List<String> automergeObjects = mergeMetric.AutoMerge_Objects__c.split(';');
        if (automergeObjects.contains('Account')) {

            System.debug('***** C501_MassMerge_SharedCode::ProcessMergeCandidates Process Merge Object: Account on Rule: ' + mergeMetric.Name);

            // 100 is the max merge job that can be sent to Flex Queue
            Integer mergeAttemptsRemaining = 99, mergeSuccesses = 0;

            Set<Id> accountsProcessed = new Set<Id>();
            for (C501_Account_Merge__c mergeCandidate : [
                SELECT Id, Account__c, Merge_Target_Account__c, Merge_Confidence__c
                FROM C501_Account_Merge__c
                WHERE Merge_Metric__r.Name = :mergeMetric.Name 
                    AND Merge_Confidence__c <= :mergeMetric.AutoMerge_Percentage__c
                    AND Merge_Action__c <> 'Ignore'
                LIMIT 100]) {

                // Check whether Account or Target Account Id merge already attempted
                if (accountsProcessed.contains(mergeCandidate.Account__c) || accountsProcessed.contains(mergeCandidate.Merge_Target_Account__c)) {
                    continue;
                }

                // Check Account and Target Account same Id
                if (mergeCandidate.Account__c == mergeCandidate.Merge_Target_Account__c) {
                    continue;
                }

                accountsProcessed.add(mergeCandidate.Account__c);
                accountsProcessed.add(mergeCandidate.Merge_Target_Account__c);

                System.debug('***** C501_MassMerge_SharedCode::ProcessMergeCandidates AutoMerge ' + mergeMetric.Name + ' - Account__c: ' + mergeCandidate.Account__c + ' Merge_Target_Account__c: ' + mergeCandidate.Merge_Target_Account__c);

                if (mergeAttemptsRemaining-- <= 0) {
                    break;
                }

                // Performance - Should be putting this on a Batch call but there is an exception thrown in NPSP code when this call is batched - look at C501_CTRL_MassMergeAccounts::SaveAccounts for details
                //
                AccountsMerge( 
                    new Account(
                        Id = mergeCandidate.Account__c,
                        C501_Merge_Action__c = 'Merge',
                        C501_Merge_Confidence__c = mergeCandidate.Merge_Confidence__c,
                        C501_Merge_Target__c = mergeCandidate.Merge_Target_Account__c,
                        C501_Merge_Metric_Name__c = mergeMetric.Name,
                        C501_Merge_Account__c = mergeCandidate.Id
                    ),
                    new List<Account> { new Account(
                        Id = mergeCandidate.Merge_Target_Account__c,
                        C501_Merge_Action__c = 'Merge',
                        C501_Merge_Confidence__c = mergeCandidate.Merge_Confidence__c,
                        C501_Merge_Target__c = mergeCandidate.Merge_Target_Account__c,
                        C501_Merge_Metric_Name__c = mergeMetric.Name,
                        C501_Merge_Account__c = mergeCandidate.Id
                    )
                } );

                mergeSuccesses++;

                // Limit to 1 account merge because an account merge with 5 contact merges is at SOQL limit of 100 - DML Merge must trigger a bunch of other SOQL calls (e.g., triggers).
                //      If more than 5 contacts then will probably throw exception and won't finish other contact merges.  Need a new rule Contact only merges that looks at contcats within a single account to catch these unmerged contacts
                break;
            }

            if (mergeSuccesses > 0) {
                mergeMetric.Total_Merge_Accounts__c = (mergeMetric.Total_Merge_Accounts__c == null) ? mergeSuccesses : (mergeMetric.Total_Merge_Accounts__c + mergeSuccesses);
                update mergeMetric;
            }
        }
    }

    global void ProcessContactMergeCandidates(C501_Merge_Metric__c mergeMetric, List<C501_Contact_Merge__c> mergeContacts) {

        //
		// Perform all DML (Data Manipulation Language) calls (insert, update, merge, delete, restore) outside of loop to avoid Salesforce Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
        //
		if (!mergeContacts.isEmpty()) {
			Database.SaveResult[] insertResults = Database.insert(mergeContacts, false);

            for (Database.SaveResult result : insertResults) {
                System.debug('***** C501_MassMerge_SharedCode::ProcessContactMergeCandidates Merge Results: ' + String.valueOf(result));
                // TBD - Look for anything other than Duplicate Id Error on Unique_Id__c which is expected
            }
		}

        // Delete Merge Candidates that do not have valid Contacts
        List<C501_Contact_Merge__c> invalidMerges = new List<C501_Contact_Merge__c>();
        for (C501_Contact_Merge__c contactMerge :[
            SELECT Id, Contact__c, Merge_Target_Contact__c
            FROM C501_Contact_Merge__c
            WHERE Merge_Metric__r.Name = :mergeMetric.Name
                AND (Contact__c = null OR Merge_Target_Contact__c = null)]) {
                
                invalidMerges.add(contactMerge);
            }

        if (!invalidMerges.IsEmpty()) {
            delete invalidMerges;
        }

        // Check if AutoMerge Enabled
        System.debug('***** C501_MassMerge_SharedCode::ProcessContactMergeCandidates Check AutoMerge AutoMerge_Percentage__c: ' + mergeMetric.AutoMerge_Percentage__c);
        if (mergeMetric.AutoMerge_Percentage__c == null || mergeMetric.AutoMerge_Percentage__c <= 0.0) {
            return;
        }

        List<String> automergeObjects = mergeMetric.AutoMerge_Objects__c.split(';');
        if (automergeObjects.contains('Contact')) {

            System.debug('***** C501_MassMerge_SharedCode::ProcessContactMergeCandidates Process Merge Object: Contact on Rule: ' + mergeMetric.Name);

            // 100 is the max merge job that can be sent to Flex Queue
            Integer mergeAttemptsRemaining = 99, mergeSuccesses = 0;

            Set<Id> contactsProcessed = new Set<Id>();
            for (C501_Contact_Merge__c mergeCandidate : [
                SELECT Id, Contact__c, Merge_Target_Contact__c, Merge_Confidence__c
                FROM C501_Contact_Merge__c
                WHERE Merge_Metric__r.Name = :mergeMetric.Name 
                    AND Merge_Confidence__c <= :mergeMetric.AutoMerge_Percentage__c
                    AND Merge_Action__c <> 'Ignore'
                LIMIT 100]) {

                // Check whether Contact or Target Contact Id merge already attempted
                if (contactsProcessed.contains(mergeCandidate.Contact__c) || contactsProcessed.contains(mergeCandidate.Merge_Target_Contact__c)) {
                    continue;
                }

                // Check Contact and Target Contact same Id
                if (mergeCandidate.Contact__c == mergeCandidate.Merge_Target_Contact__c) {
                    continue;
                }

                contactsProcessed.add(mergeCandidate.Contact__c);
                contactsProcessed.add(mergeCandidate.Merge_Target_Contact__c);

                System.debug('***** C501_MassMerge_SharedCode::ProcessContactMergeCandidates AutoMerge ' + mergeMetric.Name + ' - Contact__c: ' + mergeCandidate.Contact__c + ' Merge_Target_Contact__c: ' + mergeCandidate.Merge_Target_Contact__c);

                if (mergeAttemptsRemaining-- <= 0) {
                    break;
                }

                // Performance - Should be putting this on a Batch call but there is an exception thrown in NPSP code when this call is batched - look at C501_CTRL_MassMergeContacts::SaveContacts for details
                //
                ContactsMerge( 
                    new Contact(
                        Id = mergeCandidate.Contact__c,
                        C501_Merge_Action__c = 'Merge',
                        C501_Merge_Confidence__c = mergeCandidate.Merge_Confidence__c,
                        C501_Merge_Target__c = mergeCandidate.Merge_Target_Contact__c,
                        C501_Merge_Metric_Name__c = mergeMetric.Name,
                        C501_Merge_Contact__c = mergeCandidate.Id
                    ),
                    new List<Contact> { new Contact(
                        Id = mergeCandidate.Merge_Target_Contact__c,
                        C501_Merge_Action__c = 'Merge',
                        C501_Merge_Confidence__c = mergeCandidate.Merge_Confidence__c,
                        C501_Merge_Target__c = mergeCandidate.Merge_Target_Contact__c,
                        C501_Merge_Metric_Name__c = mergeMetric.Name,
                        C501_Merge_Contact__c = mergeCandidate.Id
                    )
                } );

                mergeSuccesses++;

                // Limit to 1 Contact merge because an Contact merge with 5 contact merges is at SOQL limit of 100 - DML Merge must trigger a bunch of other SOQL calls (e.g., triggers).
                //      If more than 5 contacts then will probably throw exception and won't finish other contact merges.  Need a new rule Contact only merges that looks at contcats within a single Contact to catch these unmerged contacts
                break;
            }

            if (mergeSuccesses > 0) {
                mergeMetric.Total_Merge_Contacts__c = (mergeMetric.Total_Merge_Contacts__c == null) ? mergeSuccesses : (mergeMetric.Total_Merge_Contacts__c + mergeSuccesses);
                update mergeMetric;
            }
        }
    }

    global void ScheduleJobs(C501_Merge_Metric__c mergeMetric) {

        // Hourly Offset to try to avoid rules running at the same time
        Integer hourlyOffset = 0;
        if (mergeMetric.Name == 'Account_Address') {
            hourlyOffset = 1;
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
        Boolean hourlySyncOnly = false;

        if (mergeMetric.AutoMerge_Percentage__c == null || mergeMetric.AutoMerge_Percentage__c <= 0.0 || ((mergeMetric.Total_Unassigned_Accounts__c + mergeMetric.Total_Unassigned_Contacts__c) < 100)) {
            hourlySyncOnly = true;
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
                        break;
                    }

                    continue;
                }

                // Optimization for future since this is a only unique code - call out here to a Virtual function that can be overloaded from a child (e.g., SM Rules - C501_SM_Rule_Contact_NameDOB)
                if (mergeMetric.Name == 'Account_Address') {
                    System.schedule(mergeMetricNameSchedule, cronExpression, new C501_MM_Rule_Account_Address());
                }
                else if (mergeMetric.Name == 'Account_Website') {
                    System.schedule(mergeMetricNameSchedule, cronExpression, new C501_MM_Rule_Account_Website());
                }
                else if (mergeMetric.Name == 'Contact_NameDOB') {
                    System.schedule(mergeMetricNameSchedule, cronExpression, new C501_MM_Rule_Contact_NameDOB());
                }
                else if (mergeMetric.Name == 'Contact_NameEmail') {
                    System.schedule(mergeMetricNameSchedule, cronExpression, new C501_MM_Rule_Contact_NameEmail());
                }

                if (hourlySyncOnly || foundAdditionalSyncTriggers) {
                    break;
                }
            }
        }
    }

    global void TestSetupMerge() {
        list<Account> listAccounts = new list<Account>();   
        integer cAccounts = 9;     
        for (integer i = 0; i < cAccounts; i++) {
            Account account = new Account(
                
                Name='Account Name',
                BillingStreet = 'BillingStreet',
                BillingCity = 'City',
                BillingState = 'WA',
                BillingPostalCode =  '12345',
                Website = 'https://www.web.org'
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

            listContacts.add( new Contact(
                LastName = 'Test1',
                FirstName = 'Test1',
                AccountId = account.Id,
                Birthdate = date.today().addYears(-21),
                Email = 'fred@bedrock.org',
                Gender__c = 'Male'
            ));
            
            listContacts.add( new Contact(
                LastName = 'Test1',
                FirstName = 'Test1',
                AccountId = account.Id,
                Birthdate = date.today().addYears(-21),
                Email = 'fred@bedrock.org',
                Gender__c = 'Male'
            ));
        }

        insert listOpportunityHouseholds.values();
        insert listContacts;

        // Print Structure
        PrintSalesforceStructure();
    }

    global void PrintSalesforceStructure() {

        System.debug('***** C501_MassMerge_SharedCode::PrintSalesforceStructure');

        System.debug('***** C501_MassMerge_SharedCode::PrintSalesforceStructure - Account ' + String.valueOf([select Id, Name from Account]));
        System.debug('***** C501_MassMerge_SharedCode::PrintSalesforceStructure - Contact ' + String.valueOf([select Id, AccountId, LastName, Birthdate from Contact]));
        System.debug('***** C501_MassMerge_SharedCode::PrintSalesforceStructure - Opportunity ' + String.valueOf([select Id, Name from Opportunity]));
    }
}