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

global class C501_MM_Rule_Discover implements Schedulable {

    global void execute(SchedulableContext SC) {

 		//
		// Perform all SOQL Queries outside of loop to avoid Salesforce Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
		//

        // Make sure mass merge instances exist for Mass Merge reports
        InitializeMassMergeInstances();

        C501_MassMerge_SharedCode c501MassMerge_SharedCode = new C501_MassMerge_SharedCode();
        c501MassMerge_SharedCode.ScheduleJobs(C501_MM_Rule_Discover.class.getName());

        List<C501_Merge_Metric__c> mergeMetrics = [
            SELECT
                Id, Name, Confidence__c,
                Total_Unassigned_Accounts__c, Total_Unassigned_Contacts__c,
                Enable__c, Source_Report__c,
                AutoMerge_Percentage__c, AutoMerge_Objects__c,
                Last_Discover_Date__c
            FROM C501_Merge_Metric__c];

        Set<String> sourceReportIds = new Set<String>();
        for (C501_Merge_Metric__c mergeMetric : mergeMetrics) {
            if (!String.isEmpty(mergeMetric.Source_Report__c)) {
                sourceReportIds.add(mergeMetric.Source_Report__c);
            }
        }

        List<Report> reports = [
            SELECT Id, DeveloperName, FolderName
            FROM Report
            WHERE Id in :sourceReportIds OR DeveloperName in :sourceReportIds];

        // Walk through Merge Metrics
        String reportIdDiscover;
        C501_Merge_Metric__c mergeMetricDiscover = new C501_Merge_Metric__c();

        for (C501_Merge_Metric__c mergeMetric : [
            SELECT
                Id, Name, Confidence__c,
                Total_Unassigned_Accounts__c, Total_Unassigned_Contacts__c,
                Enable__c, Source_Report__c, Source_Object__c,
                AutoMerge_Percentage__c, AutoMerge_Objects__c,
                Last_Discover_Date__c
            FROM C501_Merge_Metric__c]) {

            if (!mergeMetric.Enable__c) {
                continue;
            }

            //String reportId;
            String reportId = '';
            for (Report report :reports) {
                if ((String)report.Id == mergeMetric.Source_Report__c || report.DeveloperName == mergeMetric.Source_Report__c) {

                    reportId = (String)report.Id;
                    break;
                }
            }
            
            if (String.isEmpty(reportId) || String.isEmpty(mergeMetric.Source_Object__c)) {
                continue;
            }

            if (mergeMetric.Last_Discover_Date__c == null || mergeMetricDiscover.Last_Discover_Date__c == null) {

                reportIdDiscover = reportId;

                // Shallow Copy
                mergeMetricDiscover = mergeMetric;

                break;
            }
            else if (mergeMetric.Last_Discover_Date__c < mergeMetricDiscover.Last_Discover_Date__c) {

                reportIdDiscover = reportId;

                // Shallow Copy
                mergeMetricDiscover = mergeMetric;
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

    global void InitializeMassMergeInstances() {

        List<C501_Merge_Metric__c> mergeMetrics = [
            SELECT
                Id, Name, Confidence__c,
                Total_Unassigned_Accounts__c, Total_Unassigned_Contacts__c,
                Enable__c, Source_Report__c,
                AutoMerge_Percentage__c, AutoMerge_Objects__c,
                Last_Discover_Date__c
            FROM C501_Merge_Metric__c];

        // Initialize Merge Metrics - make sure there is a merge metric for each report in Mass Merge folder
        List<C501_Merge_Metric__c> mergeMetricsInsert = new List<C501_Merge_Metric__c>();
        for (Report report :[
            SELECT Id, DeveloperName, FolderName, Name
            FROM Report
            WHERE
                FolderName = 'Mass Merge']) {

                Boolean foundMergeMetric = false;
                for (C501_Merge_Metric__c mergeMetric :mergeMetrics) {
                    if (mergeMetric.Source_Report__c == (String)report.Id || mergeMetric.Source_Report__c == report.DeveloperName) {
                        foundMergeMetric = true;
                        break;
                    }
                }

                if (!foundMergeMetric) {
                    mergeMetricsInsert.add( new C501_Merge_Metric__c (
                        Name = report.Name,
                        Confidence__c = 90.0,
                        Source_Report__c = report.DeveloperName,
                        Source_Object__c = (report.DeveloperName.contains('Account') ? 'Account' : 'Contact'),
                        AutoMerge_Percentage__c = 0.0
                    ));
                }
        }

        if (!mergeMetricsInsert.isEmpty()) {
            insert mergeMetricsInsert;
        }
    }

    global void ProcessReport(String reportId, C501_Merge_Metric__c mergeMetric) {

        System.debug('***** C501_MM_Rule_Discover:ProcessReport reportId: ' + reportId + ' mergeMetric: ' + String.valueOf(mergeMetric));

        // Get the report metadata
        Reports.ReportMetadata reportMetadata = Reports.ReportManager.describeReport(reportId).getReportMetadata();

        System.debug('***** C501_MM_Rule_Discover:ProcessReport Name: ' + reportMetadata.getName());
        System.debug('***** C501_MM_Rule_Discover:ProcessReport ID: ' + reportMetadata.getId());
        if (!String.isEmpty(reportMetadata.getDescription())) {
            System.debug('***** C501_MM_Rule_Discover:ProcessReport Description: ' + reportMetadata.getDescription());
        }
        System.debug('***** C501_MM_Rule_Discover:ProcessReport Developer name: ' + reportMetadata.getDeveloperName());
        System.debug('***** C501_MM_Rule_Discover:ProcessReport Report format: ' + reportMetadata.getReportFormat());
        System.debug('***** C501_MM_Rule_Discover:ProcessReport Report type: ' + reportMetadata.getReportType());
        System.debug('***** C501_MM_Rule_Discover:ProcessReport Scope: ' + reportMetadata.getScope());
        if (!String.isEmpty(reportMetadata.getReportBooleanFilter())) {
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

        Boolean usingAddressColumns = false;
        List<String> detailColumnsChecked = new List<String>();
        for (String column :detailColumns) {

            if (column.contains('ACCOUNT.ADDRESS')) {
                usingAddressColumns = true;
            }

            detailColumnsChecked.add(CheckReportColumnName(column));
        }

        // Discover merge candidates
        ProcessReportDiscover(mergeMetric, detailColumnsChecked, reportFilters);

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
            ProcessReportDiscover(mergeMetric, detailColumnsChecked, reportFilters);
        }
    }

    global void ProcessReportDiscover(C501_Merge_Metric__c mergeMetric, List<String> detailColumnsChecked, List<Reports.ReportFilter> reportFilters) {

        // Process by Accounts to find any potential Account merges
        ProcessReportByAccounts(mergeMetric, detailColumnsChecked, reportFilters);

        if (mergeMetric.Source_Object__c.equals('Contact')) {

            // Process by Contacts different Accounts to find any potential contact merges across different accounts
            ProcessReportByContacts(mergeMetric, detailColumnsChecked, reportFilters);

            // Process by Contacts same Account to find any potential contacts merges within same account
            detailColumnsChecked.add('AccountId');
            ProcessReportByContacts(mergeMetric, detailColumnsChecked, reportFilters);
        }
    }
    global void ProcessReportByAccounts(C501_Merge_Metric__c mergeMetric, List<String> detailColumnsChecked, List<Reports.ReportFilter> reportFilters) {

        //
        // Testing in Workbench tips
        //      add LIMIT 10 at the end

        String accountId = 'AccountId';
        if (mergeMetric.Source_Object__c.equals('Account')) {
            accountId = 'Id';
        }

        // Find Contact matches across Accounts
        //
        String strSoql = 'SELECT Count(' + accountId + '), MAX(' + accountId + ')MaxAccountId, MIN(' + accountId + ')MinAccountId ';
        strSoql += ' FROM ' + mergeMetric.Source_Object__c;

        // Build WHERE statement
        //
        List<String> whereFields = new List<String>();

        // Add Null checks
        for (String column :detailColumnsChecked) {
            whereFields.add(column + ' <> null ');
        }

        // Add filters
        for (Reports.ReportFilter reportFilter :reportFilters) {
            whereFields.add(CheckReportOperator(reportFilter.getColumn(), reportFilter.getOperator(), reportFilter.getValue()));
        }

        strSoql += ' WHERE ' + String.join(whereFields, ' and ');
        strSoql += ' GROUP BY ' + String.join(detailColumnsChecked, ', ');
        strSoql += ' HAVING Count(' + accountId + ') > 1 ';
        strSoql += ' ORDER BY Count(' + accountId + ') DESC';

        System.debug('***** C501_MM_Rule_Discover:ProcessReportByAccounts strSoql: ' + strSoql);

		AggregateResult[] allAggregatedByAccounts = Database.Query(strSoql);

        Map<String, C501_Account_Merge__c> mergeAccounts = new Map<String, C501_Account_Merge__c>();
        String uniqueId, minId, maxId;
        for (AggregateResult result : allAggregatedByAccounts)  {
            maxId = result.get('MaxAccountId').toString();
            minId = result.get('MinAccountId').toString();

            if (String.isEmpty(maxId) || String.isEmpty(minId) || maxId == minId) {
                continue;
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

    global void ProcessReportByContacts(C501_Merge_Metric__c mergeMetric, List<String> detailColumnsChecked, List<Reports.ReportFilter> reportFilters) {

        //
        // Testing in Workbench tips
        //      add LIMIT 10 at the end

        // Find Contact matches across Accounts
        //
        String strSoql = 'SELECT Count(Id), MAX(Id)MaxContactId, MIN(Id)MinContactId ';
        strSoql += ' FROM Contact';

        // Build WHERE statement
        //
        List<String> whereFields = new List<String>();

        // Add Null checks
        for (String column :detailColumnsChecked) {
            whereFields.add(column + ' <> null ');
        }

        // Add filters
        for (Reports.ReportFilter reportFilter :reportFilters) {
            whereFields.add(CheckReportOperator(reportFilter.getColumn(), reportFilter.getOperator(), reportFilter.getValue()));
        }

        strSoql += ' WHERE ' + String.join(whereFields, ' and ');
        strSoql += ' GROUP BY ' + String.join(detailColumnsChecked, ', ');
        strSoql += ' HAVING Count(Id) > 1 ';
        strSoql += ' ORDER BY Count(Id) DESC';

        System.debug('***** C501_MM_Rule_Discover:ProcessReportByContacts strSoql: ' + strSoql);

		AggregateResult[] allAggregatedByContacts = Database.Query(strSoql);

        Map<String, C501_Contact_Merge__c> mergeContacts = new Map<String, C501_Contact_Merge__c>();
        String uniqueId, minId, maxId;
        for (AggregateResult result : allAggregatedByContacts)  {
            maxId = result.get('MaxContactId').toString();
            minId = result.get('MinContactId').toString();

            if (String.isEmpty(maxId) || String.isEmpty(minId) || maxId == minId) {
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
    global String CheckReportColumnName(String columnFieldName) {

        // Contact Report Columns
        //
        if (columnFieldName == 'FIRST_NAME') {
            return 'FirstName';
        }
        else if (columnFieldName == 'LAST_NAME') {
            return 'LastName';
        }

        // Account Report Columns
        //
        else if (columnFieldName.equals('ACCOUNT_ID')) {
            return 'AccountId';
        }
        else if (columnFieldName.equals('ACCOUNT_RECORDTYPE')) {
            return 'Account.RecordTypeId';
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
        else if (columnFieldName.equals('URL')) {
            return 'Account.Website';
        }

        return columnFieldName;
    }

    global String CheckReportOperator(String reportColumnName, String operator, String value) {

        String columnName = CheckReportColumnName(reportColumnName);

        if (operator == 'equals') {
            return columnName + ' = ' + value;
        }
        else if (operator == 'startsWith') {
            return columnName + ' LIKE \'' + value + '%\'';
        }
        else if (operator == 'contains') {
            return columnName + ' LIKE \'%' + value + '%\'';
        }

        return null;
    }    
}