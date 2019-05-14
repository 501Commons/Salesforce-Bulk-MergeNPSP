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

//
// Run Code FROM Developer Console
//  1) Debug -> Open Execute Anonymous Window
//  2) paste code
/*
      C501_MM_Rule_Discover discoverRule = new C501_MM_Rule_Discover();
      discoverRule.execute(null);
*/
//  3) click Execute
//
// Abort scheduled jobs
/*
    List<CronJobDetail> scheduledJobs = [SELECT Id FROM CronJobDetail WHERE Name like 'C501_%'];
    for (CronJobDetail scheduledJob :scheduledJobs) {
        Id jobId = [SELECT Id FROM CronTrigger WHERE CronJobDetailId = :scheduledJob.Id].Id;
        System.abortJob(jobId);
    }
*/

public class C501_MM_Rule_Discover implements Schedulable {

	// only need one instance of this class per transaction
	private static C501_MM_Rule_Discover instance;
	public static C501_MM_Rule_Discover get() {
		if (instance == null) instance = new C501_MM_Rule_Discover();
		return instance;
	}

    public void C501_MM_Rule_Discover() {
                
        C501_MassMerge_SharedCode c501MassMerge_SharedCode = new C501_MassMerge_SharedCode();
        c501MassMerge_SharedCode.ScheduleJobs();
    }

    public void execute(SchedulableContext SC) {

 		//
		// Perform all SOQL Queries outside of loop to avoid Salesforce Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
		//

        this.DiscoverReports();

        String strSoql = 'SELECT';
        strSoql += ' Id, Name, Confidence__c,';
        strSoql += ' Total_Unassigned_Accounts__c, Total_Unassigned_Contacts__c,';
        strSoql += ' Source_Report__c, Source_Report_LastModifiedDate__c, Source_Object__c, Source_Object_Account_Id__c,';
        strSoql += ' AutoMerge_Percentage__c, AutoMerge_Objects__c,';
        strSoql += ' Last_Discover_Date__c, Last_Merge_Date__c';
        strSoql += ' FROM C501_Merge_Metric__c';
        strSoql += ' WHERE Source_Object_Account_Id__c <> null AND Source_Object__c <> NULL AND Source_Report__c <> NULL';
        if (Test.isRunningTest()) {        
            strSoql += ' AND Name LIKE \'TESTDATA%\'';
        }
        List<C501_Merge_Metric__c> mergeMetrics = Database.Query(strSoql);

        Set<String> sourceReportIds = new Set<String>();
        for (C501_Merge_Metric__c mergeMetric : mergeMetrics) {
            if (!String.isBlank(mergeMetric.Source_Report__c)) {
                sourceReportIds.add(mergeMetric.Source_Report__c);
            }
        }

        List<Report> reports = [
            SELECT Id, DeveloperName, FolderName, LastModifiedDate
            FROM Report
            WHERE Id in :sourceReportIds OR DeveloperName in :sourceReportIds];

        // Walk through Merge Metrics
        String reportIdDiscover;
        C501_Merge_Metric__c mergeMetricDiscover = new C501_Merge_Metric__c();
        List<C501_Merge_Metric__c> mergeMetricsUpdate = new List<C501_Merge_Metric__c>();
        Set<Id> mergeMetricDeleteChildren = new Set<Id>();

        for (C501_Merge_Metric__c mergeMetric : mergeMetrics) {

            String reportId;
            for (Report report :reports) {

                if ((String)report.Id == mergeMetric.Source_Report__c || report.DeveloperName == mergeMetric.Source_Report__c) {

                    // Check for report change
                    if (mergeMetric.Source_Report_LastModifiedDate__c == null || mergeMetric.Source_Report_LastModifiedDate__c <> report.LastModifiedDate) {

                        mergeMetric.Source_Report_LastModifiedDate__c = report.LastModifiedDate;
                        mergeMetricsUpdate.add(mergeMetric);

                        // Queue merge metric to delete children since report changed
                        mergeMetricDeleteChildren.add(mergeMetric.Id);
                    }

                    reportId = (String)report.Id;

                    break;
                }
            }

            if (String.isBlank(reportId)) {
                continue;
            }

            if (mergeMetric.Last_Discover_Date__c == null) {

                reportIdDiscover = reportId;

                // Shallow Copy
                mergeMetricDiscover = mergeMetric;

                break;
            }
            else if (mergeMetricDiscover.Id == null || (mergeMetric.Last_Discover_Date__c <> null && mergeMetric.Last_Discover_Date__c < mergeMetricDiscover.Last_Discover_Date__c)) {

                reportIdDiscover = reportId;

                // Shallow Copy
                mergeMetricDiscover = mergeMetric;
            }
        }

        if (!mergeMetricsUpdate.isEmpty()) {
            update mergeMetricsUpdate;
        }

        if (!mergeMetricDeleteChildren.isEmpty()) {

            List<C501_Account_Merge__c> accountMergesDelete = [SELECT Id FROM C501_Account_Merge__c WHERE Merge_Metric__c in :mergeMetricDeleteChildren];
            if (!accountMergesDelete.isEmpty()) {
                delete accountMergesDelete;
            }

            List<C501_Contact_Merge__c> contactMergesDelete = [SELECT Id FROM C501_Contact_Merge__c WHERE Merge_Metric__c in :mergeMetricDeleteChildren];
            if (!contactMergesDelete.isEmpty()) {
                delete contactMergesDelete;
            }
        }

        if (mergeMetricDiscover.Id == null) {
            return;
        }

        System.debug('***** C501_MM_Rule_Discover:execute - Merge Metric: ' + String.valueOf(mergeMetricDiscover));

        mergeMetricDiscover.Last_Discover_Date__c = System.now();
        update mergeMetricDiscover;

        // NOTE: Calling Reports.ReportManager within this loop context get compile error ReportManager variable does not exist.  Future task - investigate why
        ProcessReport(reportIdDiscover, mergeMetricDiscover);
    }

    public void executeMetric(String mergeMetricId) {

        this.DiscoverReports();

        String strSoql = 'SELECT';
        strSoql += ' Id, Name, Confidence__c,';
        strSoql += ' Total_Unassigned_Accounts__c, Total_Unassigned_Contacts__c,';
        strSoql += ' Source_Report__c, Source_Report_LastModifiedDate__c, Source_Object__c, Source_Object_Account_Id__c,';
        strSoql += ' AutoMerge_Percentage__c, AutoMerge_Objects__c,';
        strSoql += ' Last_Discover_Date__c, Last_Merge_Date__c';
        strSoql += ' FROM C501_Merge_Metric__c';
        strSoql += ' WHERE Source_Object_Account_Id__c <> null AND Source_Object__c <> NULL AND Source_Report__c <> NULL';
        strSoql += ' AND Id = :mergeMetricId';
        if (Test.isRunningTest()) {        
            strSoql += ' AND Name LIKE \'TESTDATA%\'';
        }
        List<C501_Merge_Metric__c> mergeMetrics = Database.Query(strSoql);

        if (mergeMetrics.isEmpty()) {
          return;
        }

        List<Report> reports = [
            SELECT Id
            FROM Report
            WHERE Id = :mergeMetrics[0].Source_Report__c OR DeveloperName = :mergeMetrics[0].Source_Report__c];

        if (reports.isEmpty()) {
          return;
        }

        mergeMetrics[0].Last_Discover_Date__c = System.now();
        update mergeMetrics[0];

        ProcessReport(reports[0].Id, mergeMetrics[0]);
    }

    public void ProcessReport(String reportId, C501_Merge_Metric__c mergeMetric) {

        System.debug('***** C501_MM_Rule_Discover:ProcessReport reportId: ' + reportId + ' mergeMetric: ' + String.valueOf(mergeMetric));

        // Get the report metadata
        Reports.ReportMetadata reportMetadata = Reports.ReportManager.describeReport(reportId).getReportMetadata();

        System.debug('***** C501_MM_Rule_Discover:ProcessReport Name: ' + reportMetadata.getName());
        System.debug('***** C501_MM_Rule_Discover:ProcessReport ID: ' + reportMetadata.getId());
        if (String.isNotBlank(reportMetadata.getDescription())) {
            System.debug('***** C501_MM_Rule_Discover:ProcessReport Description: ' + reportMetadata.getDescription());
        }
        System.debug('***** C501_MM_Rule_Discover:ProcessReport Developer name: ' + reportMetadata.getDeveloperName());
        System.debug('***** C501_MM_Rule_Discover:ProcessReport Report format: ' + reportMetadata.getReportFormat());
        System.debug('***** C501_MM_Rule_Discover:ProcessReport Report Type - Label: ' + reportMetadata.getReportType().getLabel());
        System.debug('***** C501_MM_Rule_Discover:ProcessReport Report Type - Type: ' + reportMetadata.getReportType().getType());
        System.debug('***** C501_MM_Rule_Discover:ProcessReport Scope: ' + reportMetadata.getScope());
        if (String.isNotBlank(reportMetadata.getReportBooleanFilter())) {
            System.debug('***** C501_MM_Rule_Discover:ProcessReport Boolean filter: ' + reportMetadata.getReportBooleanFilter());
        }
        Reports.StandardDateFilter standardDateFilter = reportMetadata.getStandardDateFilter();
        if (standardDateFilter <> null) {
            System.debug('***** C501_MM_Rule_Discover:ProcessReport Standard Filters: ' + String.valueOf(standardDateFilter));
        }

        List<String> detailColumns = reportMetadata.getDetailColumns();
        if (detailColumns.size() > 0) {
            System.debug('***** C501_MM_Rule_Discover:ProcessReport getDetailColumns: ' + String.valueOf(detailColumns));
        }
        List<Reports.ReportFilter> reportFilters = reportMetadata.getReportFilters();
        if (reportFilters.size() > 0) {
            System.debug('***** C501_MM_Rule_Discover:ProcessReport getReportFilters: ' + String.valueOf(reportFilters));
        }
        List<Reports.CrossFilter> crossFilters = reportMetadata.getCrossFilters();
        if (crossFilters.size() > 0) {
            System.debug('***** C501_MM_Rule_Discover:ProcessReport Cross filters: ' + String.valueOf(crossFilters));
        }
        List<Reports.StandardFilter> standardFilters = reportMetadata.getStandardFilters();
        if (standardFilters.size() > 0) {
            System.debug('***** C501_MM_Rule_Discover:ProcessReport Standard Filters: ' + String.valueOf(standardFilters));
        }

        // Translate Report columns to Soql fields

        // Get FK - Foriegn Key Object
        String foriegnKey;
        List<String> foriegnKeyObjects = reportMetadata.getReportType().getType().split('\\.');
        if (!foriegnKeyObjects.isEmpty()) {
            foriegnKey = foriegnKeyObjects[foriegnKeyObjects.size() - 1].replace('__c', '__r.');
        }

        Boolean usingAddressColumns = false;
        List<String> detailColumnsChecked = new List<String>();
        for (String column :detailColumns) {

            if (column.contains('ACCOUNT.ADDRESS')) {
                usingAddressColumns = true;
            }

            String checkColumn = CheckReportColumnName(mergeMetric, foriegnKey, column, false);
            System.Debug('***** 1 column: ' + column + ' checkColumn: ' + checkColumn);
            if (String.isNotBlank(checkColumn)) {
                detailColumnsChecked.add(checkColumn);
            }
        }

        // Discover merge candidates
        ProcessReportDiscover(mergeMetric, foriegnKey, detailColumnsChecked, reportFilters);

        // Check for Address columns
        //  When using address columns need to query both the Billing and Shipping address because regardless of
        //  which you specify in the report the column name comes in as Address1 instead of Shipping or Billing
        if (usingAddressColumns) {

            List<String> detailColumnsCheckedAddressReverse = new List<String>();
            for (String column :detailColumnsChecked) {
                if (column.contains('Account.Billing')) {
                    detailColumnsCheckedAddressReverse.add(column.replace('Account.Billing', 'Account.Shipping'));
                }
                else if (column.contains('Account.Shipping')) {
                    detailColumnsCheckedAddressReverse.add(column.replace('Account.Shipping', 'Account.Billing'));
                }
                else {
                    detailColumnsCheckedAddressReverse.add(column);
                }
            }

            // Discover merge candidates
            ProcessReportDiscover(mergeMetric, foriegnKey, detailColumnsChecked, reportFilters);
        }
    }

    public void ProcessReportDiscover(C501_Merge_Metric__c mergeMetric, String foriegnKey, List<String> detailColumnsChecked, List<Reports.ReportFilter> reportFilters) {

        // Process by Accounts to find any potential Account merges
        ProcessReportByAccounts(mergeMetric, foriegnKey, detailColumnsChecked, reportFilters);

        if (mergeMetric.Source_Object__c.equals('Contact')) {

            // Process by Contacts different Accounts to find any potential contact merges across different accounts
            ProcessReportByContacts(mergeMetric, foriegnKey, detailColumnsChecked, reportFilters, null);

            // Process by Contacts same Account to find any potential contacts merges within same account
            ProcessReportByContacts(mergeMetric, foriegnKey, detailColumnsChecked, reportFilters, 'AccountId');
        }
    }
    public void ProcessReportByAccounts(C501_Merge_Metric__c mergeMetric, String foriegnKey, List<String> detailColumnsChecked, List<Reports.ReportFilter> reportFilters) {

        // Find Contact matches across Accounts
        //
        String strSoqlSelect = 'SELECT Count(' + mergeMetric.Source_Object_Account_Id__c + '), MAX(' + mergeMetric.Source_Object_Account_Id__c + ')MaxId, MIN(' + mergeMetric.Source_Object_Account_Id__c + ')MinId ';
        String strSoqlFrom = ' FROM ' + mergeMetric.Source_Object__c;

        // Build WHERE statement
        //
        List<String> whereFields = new List<String>();
        List<String> whereInValues = new List<String>();

        // Add Null checks
        for (String column :detailColumnsChecked) {
            // Skip Null check on fields not required to uniquely group contacts
            if (column.contains('Gender')) {
                continue;
            }

            whereFields.add(column + ' <> null ');
        }

        // Check if Full Contact Match meaning every contact in the households have to match
        Boolean fullContactMatch = false;

        // Add filters
        for (Reports.ReportFilter reportFilter :reportFilters) {

            // Check for full contact match
            if (reportFilter.getValue().equals('Full Contact Match')) {

                // Schedule Full Contact Match Processing
//                C501_MassMerge_Fx_Base fxBase = new C501_MassMerge_Fx_FullContactMatch();
                fullContactMatch = true;
                continue;
            }
            // Check for Partial Match - part of the field matches; Example Tom and Tomas would be considered a match
            else if (reportFilter.getValue().equals('Partial Match')) {

                // Schedule Partial Match Processing
//                C501_MassMerge_Fx_Base fxBase = new C501_MassMerge_Fx_PartialMatch();
                continue;
            }

            String whereField = CheckReportOperator(mergeMetric, foriegnKey, reportFilter.getColumn(), reportFilter.getOperator(), reportFilter.getValue());
            if (String.isNotBlank(whereField)) {

                // Check if value contains a list of Strings
                if (reportFilter.getValue().contains(',')) {
                    whereInValues = reportFilter.getValue().split(',');

                    whereField = CheckReportColumnName(mergeMetric, foriegnKey, reportFilter.getColumn(), true) + ' in :whereInValues';
                    System.Debug('***** 2 reportFilter.getColumn(): ' + reportFilter.getColumn() + ' whereField: ' + whereField);
                }

                whereFields.add(whereField);
            }
        }

        String strSoqlWhere = ' WHERE ' + String.join(whereFields, ' and ');

        // Add aggregate check
        List<String> groupByFields = new List<String>();
        for (String column :detailColumnsChecked) {

            if (column.contains(mergeMetric.Source_Object_Account_Id__c)) {
                continue;
            }

            groupByFields.add(column);
        }

        // Check for valid group fields
        if (groupByFields.size() <= 0) {
            return;
        }

        String strSoqlGroupBy = ' GROUP BY ' + String.join(groupByFields, ', ');
        String strSoqlHaving = ' HAVING Count(' + mergeMetric.Source_Object_Account_Id__c + ') > 1 ';
        String strSoqlOrderBy = ' ORDER BY Count(' + mergeMetric.Source_Object_Account_Id__c + ') DESC';

        System.debug('***** C501_MM_Rule_Discover:ProcessReportByAccounts aggregate SOQL');
        System.debug(strSoqlSelect);
        System.debug(strSoqlFrom);
        System.debug(strSoqlWhere);
        System.debug(strSoqlGroupBy);
        System.debug(strSoqlHaving);
        System.debug(strSoqlOrderBy);

		AggregateResult[] allAggregatedByAccounts = Database.Query(strSoqlSelect + strSoqlFrom + strSoqlWhere + strSoqlGroupBy + strSoqlHaving + strSoqlOrderBy);

        // Filter out account ids already associated with merge metric
        Set<Id> existingAccountIds = new Set<Id>();
        for(C501_Account_Merge__c existingMerge : [
            SELECT Account__c, Merge_Target_Account__c
            FROM C501_Account_Merge__c
            WHERE Merge_Metric__c = :mergeMetric.Id]) {
                existingAccountIds.add(existingMerge.Account__c);
                existingAccountIds.add(existingMerge.Merge_Target_Account__c);
        }

        // Check for Full Contact Match
        //
        Map<Id,String> accountContacts = new Map<Id,String>();
        if (fullContactMatch) {

            Set<Id> mergeAccountIds = new Set<Id>();
            String minId, maxId;
            for (AggregateResult result : allAggregatedByAccounts)  {
                
                maxId = result.get('MaxId').toString();
                minId = result.get('MinId').toString();

                if (String.isBlank(maxId) || String.isBlank(minId) || maxId == minId) {
                    continue;
                }

                if (existingAccountIds.contains(maxId) || existingAccountIds.contains(minId)) {
                    continue;
                }

                mergeAccountIds.add(maxId);
                mergeAccountIds.add(minId);
            }

            // Get Household Sizes
            Map<Id, Integer> existingAccountSizes = new Map<Id, Integer>();
            for (AggregateResult result : [
                SELECT AccountId, Count(Id) NumberOfMembers FROM Contact WHERE AccountId in :mergeAccountIds group by AccountId HAVING Count(Id) > 1]) {

                String accountId = result.get('AccountId').toString();
                Integer numberOfMembers = Integer.valueOf(result.get('NumberOfMembers'));
                existingAccountSizes.put(accountId, numberOfMembers);
            }

            Set<Id> mergeAccountIdsMatching = new Set<Id>();
            for (AggregateResult result : allAggregatedByAccounts)  {
                
                maxId = result.get('MaxId').toString();
                minId = result.get('MinId').toString();

                if (!existingAccountSizes.containsKey(maxId) || !existingAccountSizes.containsKey(minId)) {
                    continue;
                }

                // Make sure household contact count equal
                if (existingAccountSizes.get(maxId) <> existingAccountSizes.get(minId)) {
                    continue;
                }

                mergeAccountIdsMatching.add(maxId);
                mergeAccountIdsMatching.add(minId);
            }

            List<Contact> contacts = [
                SELECT AccountId, FirstName, LastName, Birthdate, Gender__c
                FROM Contact
                WHERE AccountId in :mergeAccountIdsMatching
                ORDER BY AccountId, FirstName, LastName, Birthdate, Gender__c DESC];

            if (contacts.isEmpty()) {
                return;
            }

            for (Contact contactInfo :contacts) {
                String contactsInfo;
                if (accountContacts.containsKey(contactInfo.AccountId)) {
                    contactsInfo = accountContacts.remove(contactInfo.AccountId);
                }

                contactsInfo += 
                    (String.isNotBlank(contactInfo.FirstName) ? contactInfo.FirstName.mid(1,1) : '')
                    + (String.isNotBlank(contactInfo.LastName) ? contactInfo.LastName : '')
                    + (contactInfo.Birthdate <> null ? String.valueOf(contactInfo.Birthdate) : '')
                    + (String.isNotBlank(contactInfo.Gender__c) ? contactInfo.Gender__c : '');

                accountContacts.put(contactInfo.AccountId, contactsInfo);
            }
        }

        Map<String, C501_Account_Merge__c> mergeAccounts = new Map<String, C501_Account_Merge__c>();
        String uniqueId, minId, maxId;
        for (AggregateResult result : allAggregatedByAccounts)  {
            maxId = result.get('MaxId').toString();
            minId = result.get('MinId').toString();

            if (String.isBlank(maxId) || String.isBlank(minId) || maxId == minId) {
                continue;
            }

            // Check if merge metric already created
            if (existingAccountIds.contains(maxId) || existingAccountIds.contains(minId)) {
                continue;
            }

            // Check if Full Contact Match meaning every contact in the households have to match
            if (fullContactMatch) {
                if (!accountContacts.containsKey(maxId) || !accountContacts.containsKey(minId)) {
                    continue;
                }

                // Validate Contacts same between both accounts
                if (accountContacts.get(maxId) <> accountContacts.get(minId)) {
                    continue;
                }
            }

            uniqueId = mergeMetric.Name + maxId + minId;
            mergeAccounts.put(uniqueId, new C501_Account_Merge__c(
                Unique_Id__c = uniqueId,
                Merge_Confidence__c = mergeMetric.Confidence__c,
                Account__c = minId,
                Merge_Target_Account__c = maxId,
                Merge_Metric__c = mergeMetric.Id
            ));
        }

        C501_MassMerge_SharedCode_Account c501MassMerge_SharedCode_Account = new C501_MassMerge_SharedCode_Account();
        c501MassMerge_SharedCode_Account.InsertObjectMergeCandidates(mergeMetric, mergeAccounts.values());
    }

    public void ProcessReportByContacts(C501_Merge_Metric__c mergeMetric, String foriegnKey, List<String> detailColumnsChecked, List<Reports.ReportFilter> reportFilters, String additionalGroupByField) {
        // Find Contact matches across Accounts
        //
        String strSoqlSelect = 'SELECT Count(Id), MAX(Id)MaxId, MIN(Id)MinId ';
        String strSoqlFrom = ' FROM ' + mergeMetric.Source_Object__c;

        // Build WHERE statement
        //
        List<String> whereFields = new List<String>();
        List<String> whereInValues = new List<String>();
 
        // Add Null checks
        for (String column :detailColumnsChecked) {

            // Skip Null check on fields not required to uniquely group contacts
            if (column.contains('Gender')) {
                continue;
            }

            whereFields.add(column + ' <> null ');
        }

        // Add filters
        for (Reports.ReportFilter reportFilter :reportFilters) {
            String whereField = CheckReportOperator(mergeMetric, foriegnKey, reportFilter.getColumn(), reportFilter.getOperator(), reportFilter.getValue());
            if (!String.isBlank(whereField)) {

                // Check if value contains a list of Strings
                if (reportFilter.getValue().contains(',')) {
                    whereInValues = reportFilter.getValue().split(',');
                    whereField = CheckReportColumnName(mergeMetric, foriegnKey, reportFilter.getColumn(), true) + ' in :whereInValues';
                    System.Debug('***** 3 reportFilter.getColumn(): ' + reportFilter.getColumn() + ' whereField: ' + whereField);
                }

                whereFields.add(whereField);
            }
        }

        String strSoqlWhere = ' WHERE ' + String.join(whereFields, ' and ');

        // Add aggregate check
        List<String> groupByFields = new List<String>();
        for (String column :detailColumnsChecked) {

            if (column.contains(mergeMetric.Source_Object_Account_Id__c)) {
                continue;
            }

            groupByFields.add(column);
        }

        // Check to add additional groupByFields
        if (String.isNotBlank(additionalGroupByField)) {
            groupByFields.add(additionalGroupByField);
        }

        String strSoqlGroupBy = ' GROUP BY ' + String.join(groupByFields, ', ');
        String strSoqlHaving = ' HAVING Count(Id) > 1 ';
        String strSoqlOrderBy = ' ORDER BY Count(Id) DESC';

        System.debug('***** C501_MM_Rule_Discover:ProcessReportByContacts aggregate SOQL');
        System.debug(strSoqlSelect);
        System.debug(strSoqlFrom);
        System.debug(strSoqlWhere);
        System.debug(strSoqlGroupBy);
        System.debug(strSoqlHaving);
        System.debug(strSoqlOrderBy);

		AggregateResult[] allAggregatedByContacts = Database.Query(strSoqlSelect + strSoqlFrom + strSoqlWhere + strSoqlGroupBy + strSoqlHaving + strSoqlOrderBy);

        Map<String, C501_Contact_Merge__c> mergeContacts = new Map<String, C501_Contact_Merge__c>();
        String uniqueId, minId, maxId;
        for (AggregateResult result : allAggregatedByContacts)  {
            maxId = result.get('MaxId').toString();
            minId = result.get('MinId').toString();

            if (String.isBlank(maxId) || String.isBlank(minId) || maxId == minId) {
                continue;
            }

            uniqueId = mergeMetric.Name + maxId + minId;
            mergeContacts.put(uniqueId, new C501_Contact_Merge__c(
                Unique_Id__c = uniqueId,
                Merge_Confidence__c = mergeMetric.Confidence__c,
                Contact__c = minId,
                Merge_Target_Contact__c = maxId,
                Merge_Metric__c = mergeMetric.Id
            ));
        }

        C501_MassMerge_SharedCode_Contact c501MassMerge_SharedCode_Contact = new C501_MassMerge_SharedCode_Contact();
        c501MassMerge_SharedCode_Contact.InsertObjectMergeCandidates(mergeMetric, mergeContacts.values());
    }

    // Report Column Field Names don't always match the Object Field Name
    public String CheckReportColumnName(C501_Merge_Metric__c mergeMetric, String foriegnKey, String columnFieldName, Boolean filterColumn) {

        // Filter columns - some columns not supported except in filters (i.e., Group )
        //
        if (!filterColumn) {
            if (columnFieldName.contains('npsp__')) {
                return null;
            }
            else if (columnFieldName == 'LAST_UPDATE') {
                return null;
            }
            else if (columnFieldName == 'CREATED_DATE') {
                return null;
            }
            else if (columnFieldName.equals('ACCOUNT_ID')) {
                if (mergeMetric.Source_Object__c.equals('Account')) {
                    return null;
                }
                else {
                    return 'AccountId';
                }
            }
        }

        // Check for FK - Foriegn Key
        if (columnFieldName.startsWith('FK_')) {
            List<String> foriegnKeyFields = columnFieldName.split('\\.');
            if (foriegnKeyFields.size() == 2) {
                return foriegnKey + foriegnKeyFields[1];
            }

            return null;
        }

        // Check to add RecordTypeId
        if (columnFieldName.endsWith('_RECORDTYPE')) {

            String fieldName = 'RecordTypeId';
            if (mergeMetric.Source_Object__c.equals('Account')) {

                Map<String, Schema.SObjectField> objectFields = Schema.SObjectType.Account.fields.getMap();
                if (objectFields.keySet().contains(fieldName)) {
                    Schema.SObjectField f = objectFields.get(fieldName);
                    Schema.DescribeFieldResult fResult = f.getDescribe();

                    if (fResult.isAccessible()) {
                        return 'Account.RecordTypeId';
                    }
                }
            }
            else if (mergeMetric.Source_Object__c.equals('Contact')) {

                Map<String, Schema.SObjectField> objectFields = Schema.SObjectType.Contact.fields.getMap();
                if (objectFields.keySet().contains(fieldName)) {
                    Schema.SObjectField f = objectFields.get(fieldName);
                    Schema.DescribeFieldResult fResult = f.getDescribe();

                    if (fResult.isAccessible()) {
                        return 'RecordTypeId';
                    }
                }
            }
        }

        // Check for Source Object in Column Name
        else if (columnFieldName.startsWith(mergeMetric.Source_Object__c + '.')) {
            return columnFieldName.replace(mergeMetric.Source_Object__c + '.', '');
        }

        // Contact General Columns
        //
        else if (columnFieldName == 'NAME') {
            return 'Name';
        }
        else if (columnFieldName == 'FIRST_NAME') {
            return 'FirstName';
        }
        else if (columnFieldName == 'LAST_NAME') {
            return 'LastName';
        }
        else if (columnFieldName == 'MIDDLE_NAME') {
            return 'MiddleName';
        }
        else if (columnFieldName == 'BIRTHDATE') {
            return 'Birthdate';
        }
        else if (columnFieldName == 'REPORTS_TO') {
            return 'ReportsTo.Name';
        }
        else if (columnFieldName == 'CONTACT_LAST_UPDATE_BY_ALIAS') {
            return 'LastModifiedBy.Alias';
        }
        else if (columnFieldName == 'CONTACT_LAST_UPDATE_BY') {
            return 'LastModifiedBy.Name';
        }
        else if (columnFieldName == 'CONTACT_CREATED_ALIAS') {
            return 'CreatedBy.Alias';
        }
        else if (columnFieldName == 'CONTACT_CREATED') {
            return 'CreatedBy.Name';
        }
        else if (columnFieldName == 'CONTACT_ALIAS') {
            return 'Owner.Alias';
        }
        else if (columnFieldName == 'CONTACT_OWNER') {
            return 'Owner.Name';
        }

        // Contact Address Columns
        //
        else if (columnFieldName.startsWith('ADDRESS1_LINE')) {
            return null;
        }
        else if (columnFieldName.startsWith('ADDRESS2_LINE')) {
            return null;
        }
        else if (columnFieldName.startsWith('ADDRESS1_ZIP')) {
            return columnFieldName.replace('ADDRESS1_ZIP', 'MailingPostalCode');
        }
        else if (columnFieldName.startsWith('ADDRESS2_ZIP')) {
            return columnFieldName.replace('ADDRESS2_ZIP', 'OtherPostalCode');
        }
        else if (columnFieldName.startsWith('ADDRESS1_')) {
            return columnFieldName.replace('ADDRESS1_', 'Mailing');
        }
        else if (columnFieldName.startsWith('ADDRESS2_')) {
            return columnFieldName.replace('ADDRESS2_', 'Other');
        }

        // Contact PhFxEmail Columns
        //
        else if (columnFieldName.equals('IS_EMAIL_BOUNCED')) {
            return 'IsEmailBounced';
        }
        else if (columnFieldName.equals('FAX_OPT_OUT')) {
            return 'HasOptedOutOfFax';
        }
        else if (columnFieldName.equals('EMAIL_OPT_OUT')) {
            return 'HasOptedOutOfEmail';
        }
        else if (columnFieldName.equals('PHONE1')) {
            return 'Phone';
        }
        else if (columnFieldName.startsWith('ASSISTANT_NAME')) {
            return 'AssistantName';
        }
        else if (columnFieldName.startsWith('LEAD_SOURCE')) {
            return 'LeadSource';
        }

        // Account General Columns
        //
        else if (columnFieldName.equals('ACCOUNT_ID')) {
            if (mergeMetric.Source_Object__c.equals('Contact')) {
                return 'AccountId';
            }
        }
        else if (columnFieldName.equals('ACCOUNT.NAME')) {
            return 'Account.Name';
        }
        else if (columnFieldName.equals('ACCOUNT_NUMBER')) {
            return 'Account.AccountNumber';
        }
        else if (columnFieldName.equals('ACCOUNT_SOURCE')) {
            return 'Account.AccountSource';
        }
        else if (columnFieldName.equals('SIC_DESC')) {
            return 'Account.SicDesc';
        }        
        else if (columnFieldName.equals('TICKER')) {
            return 'Account.TickerSymbol';
        }        
        else if (columnFieldName.equals('PARENT_ID')) {
            return 'Account.ParentId';
        }
        else if (columnFieldName.equals('OWNER_FULL_NAME')) {
            return 'Account.Owner.Name';
        }
        else if (columnFieldName.equals('ALIAS')) {
            return 'Account.Owner.Alias';
        }

        // Account Address Columns
        //
        else if (columnFieldName.startsWith('ACCOUNT.ADDRESS1_LINE')) {
            return null;
        }
        else if (columnFieldName.startsWith('ACCOUNT.ADDRESS2_LINE')) {
            return null;
        }
        else if (columnFieldName.startsWith('ACCOUNT.ADDRESS1_ZIP')) {
            return columnFieldName.replace('ACCOUNT.ADDRESS1_ZIP', 'ACCOUNT.BillingPostalCode');
        }
        else if (columnFieldName.startsWith('ACCOUNT.ADDRESS2_ZIP')) {
            return columnFieldName.replace('ACCOUNT.ADDRESS2_ZIP', 'ACCOUNT.ShippingPostalCode');
        }
        else if (columnFieldName.startsWith('ACCOUNT.ADDRESS1_')) {
            return columnFieldName.replace('ACCOUNT.ADDRESS1_', 'ACCOUNT.Billing');
        }
        else if (columnFieldName.startsWith('ACCOUNT.ADDRESS2_')) {
            return columnFieldName.replace('ACCOUNT.ADDRESS2_', 'ACCOUNT.Shipping');
        }

        // Account PhFxURL Columns
        //
        else if (columnFieldName.equals('URL')) {
            return 'Account.Website';
        }
        else if (columnFieldName.equals('ACCOUNT.PHONE1')) {
            return 'Account.Phone';
        }

        // Check for Custom Field
        else if (columnFieldName.endsWith('__c')) {
            return columnFieldName;
        }

        return null;
    }

    public String CheckReportOperator(C501_Merge_Metric__c mergeMetric, String foriegnKey, String reportColumnName, String operator, String value) {

        String columnName = CheckReportColumnName(mergeMetric, foriegnKey, reportColumnName, true);
        System.Debug('***** 4 reportColumnName: ' + reportColumnName + ' columnName: ' + columnName);
        if (String.isBlank(columnName)) {
            return null;
        }

        String checkedValue = (value.isNumeric() ? value : ('\'' + value + '\''));

        if (operator == 'equals') {
            return columnName + ' = ' + checkedValue;
        }
        else if (operator == 'notEqual') {
            return columnName + ' != ' + checkedValue;
        }
        else if (operator == 'lessThan') {
            return columnName + ' < ' + checkedValue;
        }
        else if (operator == 'greaterThan') {
            return columnName + ' > ' + checkedValue;
        }
        else if (operator == 'lessOrEqual') {
            return columnName + ' <= ' + checkedValue;
        }
        else if (operator == 'greaterOrEqual') {
            return columnName + ' >= ' + checkedValue;
        }
        else if (operator == 'contains') {
            return columnName + ' LIKE \'%' + value + '%\'';
        }
        else if (operator == 'notContain') {
            return ' (NOT ' + columnName + ' LIKE \'%' + value + '%\')';
        }
        else if (operator == 'startsWith') {
            return columnName + ' LIKE \'' + value + '%\'';
        }

        return null;
    }

    public void DiscoverReports() {

        System.debug('***** C501_MM_Rule_Discover:intialize');

        String reportFolder = 'Mass Merge Rules';
        if (Test.isRunningTest()) {
            reportFolder = 'Mass Merge Tests';
        }
        
        C501_MassMerge_SharedCode c501MassMerge_SharedCode = new C501_MassMerge_SharedCode();
        c501MassMerge_SharedCode.InitializeMassMergeInstances(reportFolder);
    }
}