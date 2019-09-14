/*
    Copyright (c) 2019, 501Commons.org
    All rights reserved.
    
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of 501Commons.org nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.
 
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

    // global utility used to detect whether the Non Profit Starter Pack is installed in this instance.
    private static boolean fCheckedForNPSP = false;
    global static boolean IsNPSPInstalled {
        get {
            if (!fCheckedForNPSP) {
                Schema.SObjectType token = Schema.getGlobalDescribe().get('npe01__OppPayment__c');
                IsNPSPInstalled = (token != null);
                fCheckedForNPSP = true;
            }
            return IsNPSPInstalled;
        }
        set;
    }   

    // global utility used to get current namespace
    private static boolean fCheckedForCurrentNamespace = false;
    global static String CurrentNamespace {
        get {
            if (!fCheckedForCurrentNamespace) {
                String thisClassName = C501_MassMerge_SharedCode.class.getName();
                if (thisClassName.contains('.')) {
                    CurrentNamespace = thisClassName.split('\\.')[0] + '__';
                }
                fCheckedForCurrentNamespace = true;
            }
            return CurrentNamespace;
        }
        set;
    }   

    global static String GetSafeSoqlList(List<String> strList) {

        List<String> strCleanList = new List<String>();
        for (String strToken :strList) {
            if (String.isBlank(strToken)) {
                continue;
            }
            strCleanList.add(String.valueOf(strToken));
        }

        if (strCleanList.isEmpty()) {
            return '(\'\')';
        }

        System.debug('***** C501_MassMerge_SharedCode::GetSafeSoqlList strCleanList: ' + strCleanList);
        String safeSoqlList = '(\'' + String.join(strCleanList, '\',\'') + '\')';
        System.debug('***** C501_MassMerge_SharedCode::GetSafeSoqlList safeSoqlList: ' + safeSoqlList);

        return safeSoqlList;
    }

    global static String GetSafeSoqlList(Set<String> strSet) {

        if (strSet.isEmpty()) {
            return '(\'\')';
        }

        List<String> strList = new List<String>();
        for (String strToken :strSet) {
            strList.add(String.valueOf(strToken));
        }

        return C501_MassMerge_SharedCode.GetSafeSoqlList(strList);
    }

    global static String GetSafeSoqlList(Set<Id> idSet) {

        if (idSet.isEmpty()) {
            return '(\'\')';
        }

        List<String> strList = new List<String>();
        for (Id idToken :idSet) {
            strList.add(String.valueOf(idToken));
        }

        return C501_MassMerge_SharedCode.GetSafeSoqlList(strList);
    }

    /*******************************************************************************************************
    * @description returns whether the field should be treated as an NPSP hidden field, typically one
    * of our deprecated or system fields
    * @return boolean true if should be treated as hidden, false if not.
    */
    global boolean isNPSPHiddenField(string strField) {
        list<string> listStrField = new list<string>{
            'npe01__SystemAccountProcessor__c',
            'npo02__SystemHouseholdProcessor__c',
            'npe01__SystemIsIndividual__c',
            'Current_Address__c'
        };

        for (string strF : listStrField) {
           if (strField.equalsIgnoreCase(strF))
               return true;
        }
        return false;
    }

    global String GetAllIterableFields(String sObjectType) {

        Set<String> fieldNames = schema.describeSObjects(new String[] { sObjectType })[0].fields.getMap().keyset();
        List<String> iterableFields = new List<String>(fieldNames);

        return String.join(iterableFields, ',');
    }

    global String GetC501MergeMetricQuery() {

        String strSoql = 'SELECT';
        strSoql += ' Id, Name, Confidence__c,';
        strSoql += ' Total_Unassigned_Accounts__c, Total_Unassigned_Contacts__c,';
        strSoql += ' Source_Report__c, Source_Report_LastModifiedDate__c, Source_Object__c, Source_Object_Account_Id__c, Source_Object_Contact_Id__c,';
        strSoql += ' AutoMerge_Percentage__c, AutoMerge_Objects__c,';
        strSoql += ' Last_Discover_Date__c, Last_Merge_Date__c';
        strSoql += ' FROM C501_Merge_Metric__c';
        strSoql += ' WHERE isDeleted = false';
        strSoql += ' AND Source_Object__c <> NULL AND Source_Report__c <> NULL AND (Source_Object_Account_Id__c <> NULL OR Source_Object_Contact_Id__c <> NULL)';

        if (Test.isRunningTest()) {        
            strSoql += ' AND Name LIKE \'TESTDATA%\'';
        }

        return strSoql;
    }

    global String GetC501AccountMergeQuery() {

        String strSoql = 'SELECT';
        strSoql += ' Id, Unique_Id__c,';
        strSoql += ' Account__c, Account__r.C501_Household_Id__c, Account__r.IsDeleted,';
        strSoql += ' Merge_Target_Account__c, Merge_Target_Account__r.C501_Household_Id__c, Merge_Target_Account__r.IsDeleted,';
        strSoql += ' Merge_Confidence__c, Merge_Action__c,';
        strSoql += ' Merge_Metric__c, Merge_Metric__r.Name';
        strSoql += ' FROM C501_Account_Merge__c';
        strSoql += ' WHERE isDeleted = false';

        if (Test.isRunningTest()) {        
            strSoql += ' AND Merge_Metric__r.Name LIKE \'TESTDATA%\'';
        }

        return strSoql;
    }

    global String GetC501ContactMergeQuery() {

        String strSoql = 'SELECT';
        strSoql += ' Id, Unique_Id__c,';
        strSoql += ' Contact__c, Contact__r.C501_Household_Id__c, Contact__r.IsDeleted,';
        strSoql += ' Merge_Target_Contact__c, Merge_Target_Contact__r.C501_Household_Id__c, Merge_Target_Contact__r.IsDeleted,';
        strSoql += ' Merge_Confidence__c, Merge_Action__c,';
        strSoql += ' Merge_Metric__c, Merge_Metric__r.Name';
        strSoql += ' FROM C501_Contact_Merge__c';
        strSoql += ' WHERE isDeleted = false';

        if (Test.isRunningTest()) {        
            strSoql += ' AND Merge_Metric__r.Name LIKE \'TESTDATA%\'';
        }

        return strSoql;
    }

    global void InitializeMassMergeInstances() {

        this.ScheduleJobs();

        String reportFolder = 'Mass Merge Rules';
        if (Test.isRunningTest()) {
            reportFolder = 'Mass Merge Tests';
        }
        
        String strSoql = this.GetC501MergeMetricQuery();

        System.debug('***** ' + String.valueOf(this).substring(0,String.valueOf(this).indexOf(':')) + '::InitializeMassMergeInstances strSoql: ' + strSoql);

        List<C501_Merge_Metric__c> mergeMetrics = Database.Query(strSoql);

        // Initialize Merge Metrics - make sure there is a merge metric for each report in Mass Merge folder
        List<C501_Merge_Metric__c> mergeMetricsInsert = new List<C501_Merge_Metric__c>();
        for (Report report :[
            SELECT Id, DeveloperName, FolderName, Name
            FROM Report
            WHERE FolderName = :reportFolder]) {

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
                        Source_Object_Account_Id__c = (report.DeveloperName.contains('Account') ? 'Id' : 'AccountId'),
                        Source_Object_Contact_Id__c = (report.DeveloperName.contains('Contact') ? 'Id' : 'Id'),
                        AutoMerge_Percentage__c = 100.0
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
        String mergeMetricName = 'User Merge Rule Account No Contacts';
        String strSoql = GetC501MergeMetricQuery();
        strSoql += ' AND Name = \'' + mergeMetricName + '\'';

        System.debug('***** ' + String.valueOf(this).substring(0,String.valueOf(this).indexOf(':')) + '::ObjectsMerge_Contact strSoql: ' + strSoql);

        List<C501_Merge_Metric__c> mergeMetrics = Database.Query(strSoql);

        if (mergeMetrics.isEmpty()) {
            mergeMetrics.add( new C501_Merge_Metric__c (
                Name = (Test.isRunningTest() ? ('TESTDATA ' + mergeMetricName) : mergeMetricName),
                Confidence__c = 90.0,
                AutoMerge_Percentage__c = 90.0,
                AutoMerge_Objects__c = 'Account',
                Source_Report__c = 'User_Merge_Rule_Account_No_Contacts',
                Source_Object__c = 'Account',
                Source_Object_Account_Id__c = 'Id',
                Source_Object_Contact_Id__c = 'Id',
                Description__c = mergeMetricName
            ));

            insert mergeMetrics;
        }

        Set<Id> contactIds = new Set<Id> { masterContact.Id };
        for (Contact contact :duplicateContacts) {
            contactIds.add(contact.Id);
        }

        Map<Id, String> contactAccounts = new Map<Id, String>();
        for (Contact contact : [
            SELECT Id, AccountId FROM Contact WHERE Id in :contactIds]) {

            contactAccounts.put(contact.Id, contact.AccountId);
        }

        Map<Id, Integer> accountMembers = new Map<Id, Integer>();
        for (AggregateResult result : [
            SELECT AccountId, Count(Id) NumberOfMembers FROM Contact WHERE AccountId in :contactAccounts.values() group by AccountId]) {

            String accountId = result.get('AccountId').toString();
            Integer numberOfMembers = Integer.valueOf(result.get('NumberOfMembers'));
            accountMembers.put(accountId, numberOfMembers);
        }

        // Check to add an account merge request - can not Account merge here because might be in a batch call which is not supported for Account merging
        String masterAccountId = contactAccounts.get(masterContact.Id);
        Map<String, C501_Account_Merge__c> accountMergeInserts = new Map<String, C501_Account_Merge__c>();
        for (String accountId :contactAccounts.values()) {

            if (accountId <> masterAccountId && accountMembers.get(accountId) <= 1) {

                System.debug('*****C501_MassMerge_SharedCode::ObjectsMerge_Contact queue empty accountId: ' + accountId + ' for merge into masterAccountId: ' + masterAccountId);

                // Create an account merge because the duplicate account now has no children
                String maxId = (masterAccountId > accountId) ? masterAccountId : accountId;
                String minId = (masterAccountId <= accountId) ? masterAccountId : accountId;
                String uniqueId = mergeMetricName + maxId + minId;
                accountMergeInserts.put(uniqueId, new C501_Account_Merge__c(
                    Unique_Id__c = uniqueId,
                    Merge_Confidence__c = mergeMetrics[0].Confidence__c,
                    Account__c = masterAccountId,
                    Merge_Target_Account__c = accountId,
                    Merge_Metric__c = mergeMetrics[0].Id
                ));
            }
        }

        // Delete any account merges for accounts where contact was merged
        strSoql = this.GetC501AccountMergeQuery();
        
        strSoql += ' AND (Account__c = null OR Merge_Target_Account__c = null OR Account__c in ' + C501_MassMerge_SharedCode.GetSafeSoqlList(contactAccounts.values()) + ' OR Merge_Target_Account__c in ' + C501_MassMerge_SharedCode.GetSafeSoqlList(contactAccounts.values()) + ')';

        System.debug('***** ' + String.valueOf(this).substring(0,String.valueOf(this).indexOf(':')) + '::ObjectsMerge_Contact strSoql: ' + strSoql);

        List<C501_Account_Merge__c> deleteMerges = Database.query(strSoql);

        if (!deleteMerges.isEmpty()) {
            delete deleteMerges;
        }

        // Queue empty household merge
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
        Integer pivot = selectOptionsToSort.size() / 2;
        
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

    global Integer ProcessObjectMergeCandidates_Account(C501_Merge_Metric__c mergeMetric, List<C501_Account_Merge__c> pendingAutoMerges, Map<Id, Id> contactHouseholdMap) {

        System.debug('*****C501_MassMerge_SharedCode::ProcessObjectMergeCandidates_Account pendingAutoMerges: ' + pendingAutoMerges);

        if (String.isBlank(mergeMetric.AutoMerge_Objects__c)) {
            return 0;
        }

        List<String> automergeObjects = new List<String> { mergeMetric.AutoMerge_Objects__c };
        if (mergeMetric.AutoMerge_Objects__c.contains(';')) {
            automergeObjects = mergeMetric.AutoMerge_Objects__c.split(';');
        }

        System.debug('*****C501_MassMerge_SharedCode::ProcessObjectMergeCandidates_Account automergeObjects: ' + automergeObjects);

        if (automergeObjects.contains('Account')) {

            if (!pendingAutoMerges.isEmpty()) {
                C501_MassMerge_SharedCode_Account c501MassMerge_SharedCode_Account = new C501_MassMerge_SharedCode_Account();
                c501MassMerge_SharedCode_Account.ProcessObjectMerges(new List<C501_Merge_Metric__c> {mergeMetric}, pendingAutoMerges, false);

                return pendingAutoMerges.size();
            }
        }

        return 0;
    }

    global Integer ProcessObjectMergeCandidates_Contact(C501_Merge_Metric__c mergeMetric, List<C501_Contact_Merge__c> pendingAutoMerges, Map<Id, Id> contactHouseholdMap) {

        if (String.isBlank(mergeMetric.AutoMerge_Objects__c)) {
            return 0;
        }

        List<String> automergeObjects = new List<String> { mergeMetric.AutoMerge_Objects__c };
        if (mergeMetric.AutoMerge_Objects__c.contains(';')) {
            automergeObjects = mergeMetric.AutoMerge_Objects__c.split(';');
        }

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
                c501MassMerge_SharedCode_Contact.ProcessObjectMerges(new List<C501_Merge_Metric__c> {mergeMetric}, pendingAutoMergeCandidates, true);

                return pendingAutoMergeCandidates.size();
            }
        }

        return 0;
    }

    global void ScheduleJobs() {

        List<CronJobDetail> cronJobDetails = [SELECT Id, JobType, Name FROM CronJobDetail];
        Set<String> scheduledJobs = new Set<String>();
        for (CronJobDetail jobDetail :cronJobDetails) {

            scheduledJobs.add(jobDetail.Name);
        }

        String cronExpression, scheduleJobName;
        Integer triggerNumber = 0;
        for (Integer i = 0; i <= 59; i += 2) {

            cronExpression = '0 ' + String.valueOf(i) + ' * * * ?';

            // Schedule discover every 10 minutes otherwise schedule merge
            if (math.mod(i, 10) == 0) {

                scheduleJobName = C501_MM_Rule_Discover.class.getName() + '_' + (triggerNumber <= 9 ? '0' : '') + String.valueOf(triggerNumber++);

                if (scheduledJobs.contains(scheduleJobName)) {
                    continue;
                }

                if (!Test.isRunningTest()) {
                    System.schedule(scheduleJobName, cronExpression, new C501_MM_Rule_Discover());
                }
            }
            else {
                scheduleJobName = C501_MM_Rule_Merge.class.getName() + '_' + (triggerNumber <= 9 ? '0' : '') + String.valueOf(triggerNumber++);

                if (scheduledJobs.contains(scheduleJobName)) {
                    continue;
                }

                if (!Test.isRunningTest()) {
                    System.schedule(scheduleJobName, cronExpression, new C501_MM_Rule_Merge());
                }
            }
        }
    }

    global void TestSetupMerge() {

        InitializeMassMergeInstances();

        List<Account> listAccounts = new List<Account>();   
        Integer cAccounts = 10;     
        Integer matchIndex = 1;
        for (Integer i = 0; i < cAccounts; i++) {

            if (math.mod((i + 2), 2) == 0) {
                matchIndex++;
            }

            Account account = new Account(
                
                Name='TESTDATA Flintstone Household',
                BillingStreet = String.valueOf(matchIndex) + ' BillingStreet',
                BillingCity = 'BillingCity',
                BillingState = 'WA',
                BillingPostalCode =  '12345',
                Website = 'https://www.flintstone.org' + String.valueOf(matchIndex)
            );

            listAccounts.add(account);
        }                      

        insert listAccounts;

        Map<Id, Opportunity> listOpportunityHouseholds = new Map<Id, Opportunity>();
        List<Contact> listContacts = new List<Contact>();
        for (Integer i = 0; i < cAccounts; i++) {

            if (math.mod((i + 2), 2) == 0) {
                matchIndex++;
            }

            listOpportunityHouseholds.put(listAccounts[i].Id, new Opportunity(
                Name = 'TESTDATA Name ' + listAccounts[i].Id,
                StageName = 'Closed Won',
                CloseDate = System.today()
            ));

            listContacts.add( new Contact(
                LastName = 'TESTDATA Flintstone' + String.valueOf(matchIndex),
                FirstName = 'Fred' + String.valueOf(matchIndex),
                AccountId = listAccounts[i].Id,
                Birthdate = date.today().addYears(-21 - matchIndex),
                Email = String.valueOf(matchIndex) + 'fred@bedrock.org',
                Gender__c = 'Male'
            ));

            listContacts.add( new Contact(
                LastName = 'TESTDATA Flintstone' + String.valueOf(matchIndex),
                FirstName = 'Fred' + String.valueOf(matchIndex),
                AccountId = listAccounts[i].Id,
                Birthdate = date.today().addYears(-21 - matchIndex),
                Email = String.valueOf(matchIndex) + 'fred@bedrock.org',
                Gender__c = 'Male'
            ));

            listContacts.add( new Contact(
                LastName = 'TESTDATA Flintstone' + String.valueOf(matchIndex),
                FirstName = 'Wilma' + String.valueOf(matchIndex),
                AccountId = listAccounts[i].Id,
                Birthdate = date.today().addYears(-21 - matchIndex),
                Email = String.valueOf(matchIndex) + 'wilma@bedrock.org',
                Gender__c = 'Female'
            ));

            listContacts.add( new Contact(
                LastName = 'TESTDATA Flintstone' + String.valueOf(matchIndex),
                FirstName = 'Dino' + String.valueOf(matchIndex),
                AccountId = listAccounts[i].Id,
                Birthdate = date.today().addYears(-2 - matchIndex),
                Email = String.valueOf(matchIndex) + 'dino@bedrock.org'
            ));
        }

        insert listOpportunityHouseholds.values();
        insert listContacts;

        //this.PrintSalesforceStructure();
    }

    // Legacy Method for Managed Package
    global void TestDiscoverHelper(String queryNameCriteria) {
        this.TestDiscoverHelper_v2(queryNameCriteria);
    }

    global List<C501_Merge_Metric__c> TestDiscoverHelper_v2(String queryNameCriteria) {

        this.TestSetupMerge();

        // Reset report change detected during a merge process call
        C501_MM_Rule_Merge.get().execute(null);

        String strSoql = this.GetC501MergeMetricQuery();
        strSoql += ' AND Name LIKE \'%' + queryNameCriteria + '%\'';

        System.debug('***** ' + String.valueOf(this).substring(0,String.valueOf(this).indexOf(':')) + '::TestDiscoverHelper_v2 strSoql: ' + strSoql);

        List<C501_Merge_Metric__c> mergeMetrics = Database.Query(strSoql);
        System.Assert(mergeMetrics.size() > 0);
        for (C501_Merge_Metric__c mergeMetric :mergeMetrics) {

            C501_MM_Rule_Discover.get().executeMetricById(mergeMetric.Id);
            mergeMetric.AutoMerge_Objects__c = 'Account;Contacts Within Account;Contacts Across Accounts';
        }

        update mergeMetrics;

        this.PrintSalesforceStructure();

        return mergeMetrics;
    }

    global String TestHelperAutoMergeObjects(String sourceObject, String autoMergeType) {

        if (sourceObject.equals('Account')) {
            if (autoMergeType.equals('Object')) {
                return 'Account';
            }
        }
        else if (sourceObject.equals('Contact')) {
            if (autoMergeType.equals('ObjectsWithinObject')) {
                return 'Contacts Within Account';
            }
            else if (autoMergeType.equals('ObjectsAcrossObjects')) {
                return 'Contacts Across Accounts';
            }
        }

        return null;
    }

    global void PrintSalesforceLimits() {

        System.debug('***** C501_MassMerge_SharedCode::NearSalesforceLimits - Aggregate Queries ' + Limits.getAggregateQueries() + ' of ' + Limits.getLimitAggregateQueries());
        System.debug('***** C501_MassMerge_SharedCode::NearSalesforceLimits - DML Rows ' + Limits.getDMLRows() + ' of ' + Limits.getLimitDMLRows());
        System.debug('***** C501_MassMerge_SharedCode::NearSalesforceLimits - DML Statments ' + Limits.getDMLStatements() + ' of ' + Limits.getLimitDMLStatements());
        System.debug('***** C501_MassMerge_SharedCode::NearSalesforceLimits - Queies ' + Limits.getQueries() + ' of ' + Limits.getLimitQueries());
        System.debug('***** C501_MassMerge_SharedCode::NearSalesforceLimits - Query Rows ' + Limits.getQueryRows() + ' of ' + Limits.getLimitQueryRows());
        System.debug('***** C501_MassMerge_SharedCode::NearSalesforceLimits - Sosl Queries ' + Limits.getSoslQueries() + ' of ' + Limits.getLimitSoslQueries());
    }

    global Integer GetMaximumLimitSize(Integer groupByNumberFields) {

        Integer percentageMultiple = 9;
        // Add 100 to allow just more than 90% to make sure to trip the NearSalesforceLimits check
        Integer maximumLimitSize = ((Limits.getLimitQueryRows() / 10) * percentageMultiple) - Limits.getQueryRows() + 100;

        // Check for groupByNumberFields which count 1 query row per group by field for each query row
        //  https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_SOQL_agg_fns.htm
        if (groupByNumberFields > 1) {
            return maximumLimitSize / groupByNumberFields;
        }

        return maximumLimitSize;
    }

    global Boolean NearSalesforceLimits() {

        Boolean nearLimit = false;
        Integer percentageMultiple = 9;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_methods_system_limits.htm

        if (Limits.getAggregateQueries() > ((Limits.getLimitAggregateQueries() / 10) * percentageMultiple)) {
            System.debug('***** C501_MassMerge_SharedCode::NearSalesforceLimits - Aggregate Queries - Query Rows ' + String.valueOf(percentageMultiple) + '0% of Limit - ' + Limits.getAggregateQueries() + ' of ' + Limits.getLimitAggregateQueries());
            nearLimit = true;
        }
        if (Limits.getDMLRows() > ((Limits.getLimitDMLRows() / 10) * percentageMultiple)) {
            System.debug('***** C501_MassMerge_SharedCode::NearSalesforceLimits - DML Rows - Query Rows ' + String.valueOf(percentageMultiple) + '0% of Limit - ' + Limits.getDMLRows() + ' of ' + Limits.getLimitDMLRows());
            nearLimit = true;
        }
        if (Limits.getDMLStatements() > ((Limits.getLimitDMLStatements() / 10) * percentageMultiple)) {
            System.debug('***** C501_MassMerge_SharedCode::NearSalesforceLimits - DML Statments - Query Rows ' + String.valueOf(percentageMultiple) + '0% of Limit - ' + Limits.getDMLStatements() + ' of ' + Limits.getLimitDMLStatements());
            nearLimit = true;
        }
        if (Limits.getQueries() > ((Limits.getLimitQueries() / 10) * percentageMultiple)) {
            System.debug('***** C501_MassMerge_SharedCode::NearSalesforceLimits - Queies - Query Rows ' + String.valueOf(percentageMultiple) + '0% of Limit - ' + Limits.getQueries() + ' of ' + Limits.getLimitQueries());
            nearLimit = true;
        }
        if (Limits.getQueryRows() > ((Limits.getLimitQueryRows() / 10) * percentageMultiple)) {
            System.debug('***** C501_MassMerge_SharedCode::NearSalesforceLimits - Query Rows ' + String.valueOf(percentageMultiple) + '0% of Limit - ' + Limits.getQueryRows() + ' of ' + Limits.getLimitQueryRows());
            nearLimit = true;
        }
        if (Limits.getSoslQueries() > ((Limits.getLimitSoslQueries() / 10) * percentageMultiple)) {
            System.debug('***** C501_MassMerge_SharedCode::NearSalesforceLimits - Sosl Queries - Query Rows ' + String.valueOf(percentageMultiple) + '0% of Limit - ' + Limits.getSoslQueries() + ' of ' + Limits.getLimitSoslQueries());
            nearLimit = true;
        }

        return nearLimit;
    }

    global void PrintSalesforceStructure() {

        System.debug('***** C501_MassMerge_SharedCode::PrintSalesforceStructure');

        PrintSalesforceLimits();

/*
        for (Account account :[select Id, Name, Website, BillingStreet from Account WHERE Name LIKE 'TESTDATA%']) {
            System.debug('***** C501_MassMerge_SharedCode::PrintSalesforceStructure - ' + String.valueOf(account));
        }
        for (Contact contact :[select Id, Account.Name, LastName, FirstName, Birthdate, Email from Contact WHERE LastName LIKE 'TESTDATA%']) {
            System.debug('***** C501_MassMerge_SharedCode::PrintSalesforceStructure - ' + String.valueOf(contact));
        }
        for (Opportunity opportunity :[select Id, Name from Opportunity WHERE Name LIKE 'TESTDATA%']) {
            System.debug('***** C501_MassMerge_SharedCode::PrintSalesforceStructure - ' + String.valueOf(opportunity));
        }
*/       
        String strSoql = this.GetC501MergeMetricQuery();
        String strSoqlAccountMerges = this.GetC501AccountMergeQuery();
        String strSoqlContactMerges = this.GetC501ContactMergeQuery();

        System.debug('***** ' + String.valueOf(this).substring(0,String.valueOf(this).indexOf(':')) + '::PrintSalesforceStructure strSoql: ' + strSoql);

        for (C501_Merge_Metric__c mergeMetric :Database.Query(strSoql)) {

            System.debug('***** C501_MassMerge_SharedCode::PrintSalesforceStructure - Merge Metric: ' + mergeMetric.Name);

            for (C501_Account_Merge__c mergeAccount :Database.query(strSoqlAccountMerges + ' AND Merge_Metric__c = \'' + mergeMetric.Id + '\'')) {
                System.debug('***** C501_MassMerge_SharedCode::PrintSalesforceStructure - Merge Accounts: ' + String.valueOf(mergeAccount));
            }
            for (C501_Contact_Merge__c mergeContact :Database.query(strSoqlContactMerges + ' AND Merge_Metric__c = \'' + mergeMetric.Id + '\'')) {
                System.debug('***** C501_MassMerge_SharedCode::PrintSalesforceStructure - Merge Contacts: ' + String.valueOf(mergeContact));
            }
        }
    }
}