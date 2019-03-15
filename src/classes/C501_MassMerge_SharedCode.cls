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

    public class C501_CTRL_MassMergeAccountsException extends Exception {}

    global String GetAllIterableFields(String sObjectType) {

        Set<String> fieldNames = schema.describeSObjects(new String[] { sObjectType })[0].fields.getMap().keyset();
        List<String> iterableFields = new List<String>(fieldNames);

        return String.join(iterableFields, ',');
    }

    global void AccountsMerge(Account masterAccount, List<Account> duplicateAccounts) {

        // Merge accounts into master
        System.debug('C501_MassMerge_SharedCodeMaster::AccountsMerge masterAccount: ' + String.valueOf(masterAccount) + ' duplicateAccounts: ' + String.valueOf(duplicateAccounts));

        Database.MergeResult[] accountResults = Database.merge(masterAccount, duplicateAccounts, false);

        for(Database.MergeResult res : accountResults) {
            if (res.isSuccess()) {
                System.debug('C501_MassMerge_SharedCodeMaster::AccountsMerge Account Merge Successful');
            }
            else {
                for (Database.Error err : res.getErrors()) {
                    System.debug('C501_MassMerge_SharedCodeMaster::AccountsMerge Account Merge Exception: ' + err.getMessage());
                }

                return;
            }
        }

        Set<Id> accountIds = new Set<Id> { masterAccount.Id };
        for (Account duplicateAccount :duplicateAccounts) {
            accountIds.add(duplicateAccount.Id);
        }

        // Merge Master Contacts - load all fields to make sure merge process does not hit a null reference
        String strSoql  = 'SELECT Id, FirstName, LastName, Birthdate FROM Contact WHERE AccountId = \'' + masterAccount.Id + '\' AND FirstName <> null AND Birthdate <> null ORDER BY CreatedDate DESC';
        List<Contact> masterContacts = Database.Query(strSoql);

        Set<Id> contactsProcessed = new Set<Id>();
        for (Contact masterContact :masterContacts) {
            for (Contact duplicateContact :masterContacts) {

                if (masterContact.Id == duplicateContact.Id || contactsProcessed.contains(masterContact.Id) || contactsProcessed.contains(duplicateContact.Id)) {
                    continue;
                }

                if (masterContact.FirstName == duplicateContact.FirstName && masterContact.LastName == duplicateContact.LastName && masterContact.Birthdate == duplicateContact.Birthdate) {

                    contactsProcessed.add(masterContact.Id);
                    contactsProcessed.add(duplicateContact.Id);

                    // Merge contact into master
                    System.debug('C501_MassMerge_SharedCodeMaster::AccountsMerge masterContact: ' + String.valueOf(masterContact) + ' duplicateContact: ' + String.valueOf(duplicateContact));

                    Database.MergeResult[] contactResults = Database.merge(masterContact, new List<Contact> { duplicateContact }, false);

                    for(Database.MergeResult res : contactResults) {
                        if (res.isSuccess()) {
                            System.debug('C501_MassMerge_SharedCodeMaster::AccountsMerge Contact Merge Successful');
                        }
                        else {
                            for(Database.Error err : res.getErrors()) {
                                System.debug('C501_MassMerge_SharedCodeMaster::AccountsMerge Contact Merge Exception: ' + err.getMessage());
                            }
                        }
                    }
                }
            }
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
    global list<SelectOption> listSOAccountsWithConfidence(String mergeRule, Decimal fromMergeConfidence, Decimal toMergeConfidence) {

        system.debug('***** C501_MassMerge_SharedCode::listSOAccountsWithConfidence - mergeRule: ' + mergeRule 
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

            // TBD - Look for anything other than Duplicate Id Error on Unique_Id__c which is expected
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
        system.debug('***** C501_MassMerge_SharedCode::ProcessMergeCandidates Check AutoMerge AutoMerge_Percentage__c: ' + mergeMetric.AutoMerge_Percentage__c);
        if (mergeMetric.AutoMerge_Percentage__c == null || mergeMetric.AutoMerge_Percentage__c <= 0.0) {
            return;
        }

        // 100 is the max merge job that can be sent to Flex Queue
        Integer mergeAttemptsRemaining = 99;

        Set<Id> accountsProcessed = new Set<Id>();
        List<C501_Account_Merge__c> deleteMerges = new List<C501_Account_Merge__c>();
        for (C501_Account_Merge__c mergeCandidate : [
            SELECT Id, Account__c, Merge_Target_Account__c, Merge_Confidence__c
            FROM C501_Account_Merge__c
            WHERE Merge_Metric__r.Name = :mergeMetric.Name 
                AND Merge_Confidence__c <= :mergeMetric.AutoMerge_Percentage__c]) {

            // Check whether Account or Target Account Id merge already attempted
            if (accountsProcessed.contains(mergeCandidate.Account__c) || accountsProcessed.contains(mergeCandidate.Merge_Target_Account__c)) {
                deleteMerges.add(mergeCandidate);
                continue;
            }

            // Check Account and Target Account same Id
            if (mergeCandidate.Account__c == mergeCandidate.Merge_Target_Account__c) {
                deleteMerges.add(mergeCandidate);
                continue;
            }

            accountsProcessed.add(mergeCandidate.Account__c);
            accountsProcessed.add(mergeCandidate.Merge_Target_Account__c);

            system.debug('***** C501_MassMerge_SharedCode::ProcessMergeCandidates AutoMerge ' + mergeMetric.Name + ' - Account__c: ' + mergeCandidate.Account__c + ' Merge_Target_Account__c: ' + mergeCandidate.Merge_Target_Account__c);

            if (mergeAttemptsRemaining-- <= 0) {
                break;
            }

            try {
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
            } catch (Exception e) {

                // NoOp for now since Sandbox has partial data
                system.debug('***** C501_MassMerge_SharedCode::ProcessMergeCandidates ' + mergeMetric.Name + ' Account__c: ' + mergeCandidate.Account__c + ' Merge_Target_Account__c: ' + mergeCandidate.Merge_Target_Account__c);
                system.debug('***** C501_MassMerge_SharedCode::ProcessMergeCandidates ' + mergeMetric.Name + ' General Exception: ' + String.valueOf(e) + '\n\n' + e.getStackTraceString());

                continue;
            }

            deleteMerges.add(mergeCandidate);
        }

        if (!deleteMerges.isEmpty()) {
            delete deleteMerges;
        }
    }

    global void TestSetupMerge() {
        list<Account> listAccounts = new list<Account>();   
        integer cAccounts = 9;     
        for (integer i = 0; i < cAccounts; i++) {
            Account account = new Account(
                
                // Request Information
                Name='Account Name'
            );
            listAccounts.add(account);
        }                      

        insert listAccounts;

        Map<Id, Opportunity> listOpportunityHouseholds = new Map<Id, Opportunity>();
        List<Contact> listContacts = new List<Contact>();
        for (Account account :listAccounts) {

            listOpportunityHouseholds.put(account.Id, new Opportunity(
                Name = 'Name ' + account.Id
            ));

            listContacts.add( new Contact(
                LastName = 'Test1',
                FirstName = 'Test1',
                AccountId = account.Id,
                Birthdate = date.today().addYears(-21)
            ));
        }

        insert listOpportunityHouseholds.values();
        insert listContacts;

        // Print Structure
        PrintSalesforceStructure();
    }

    global void PrintSalesforceStructure() {

        system.debug('***** C501_MassMerge_SharedCode::PrintSalesforceStructure');

        system.debug('***** C501_MassMerge_SharedCode::PrintSalesforceStructure - Account ' + String.valueOf([select Id, Name from Account]));
        system.debug('***** C501_MassMerge_SharedCode::PrintSalesforceStructure - Contact ' + String.valueOf([select Id, AccountId, LastName, Birthdate from Contact]));
        system.debug('***** C501_MassMerge_SharedCode::PrintSalesforceStructure - Opportunity ' + String.valueOf([select Id, Name from Opportunity]));
    }
}