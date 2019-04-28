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
                Enable__c, Source_Report__c, Source_Report_LastModifiedDate__c, Source_Object__c, Source_Aggregate__c,
                AutoMerge_Percentage__c, AutoMerge_Objects__c,
                Last_Discover_Date__c
            FROM C501_Merge_Metric__c];

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

        for (C501_Merge_Metric__c mergeMetric : [
            SELECT
                Id, Name, Confidence__c,
                Total_Unassigned_Accounts__c, Total_Unassigned_Contacts__c,
                Enable__c, Source_Report__c, Source_Report_LastModifiedDate__c, Source_Object__c, Source_Aggregate__c,
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

                    System.debug('***** C501_MM_Rule_Discover:execute - Report Found - Merge Metric: ' + String.valueOf(mergeMetric.Name) + ' Report: ' + report.DeveloperName);

                    // Check for report change
                    if (mergeMetric.Source_Report_LastModifiedDate__c == null || mergeMetric.Source_Report_LastModifiedDate__c <> report.LastModifiedDate) {

                        mergeMetric.Source_Report_LastModifiedDate__c = report.LastModifiedDate;
                        mergeMetricsUpdate.add(mergeMetric);

                        // Queue merge metric to delete children since report changed
                        mergeMetricDeleteChildren.add(mergeMetric.Id);

                        System.debug('***** C501_MM_Rule_Discover:execute - Report Change Detected: ' + String.valueOf(mergeMetric.Name) + ' Report: ' + report.DeveloperName);
                    }

                    reportId = (String)report.Id;

                    break;
                }
            }

            if (String.isBlank(reportId)) {
                continue;
            }

            if (mergeMetric.Last_Discover_Date__c == null || mergeMetricDiscover.Id == null) {

                reportIdDiscover = reportId;

                // Shallow Copy
                mergeMetricDiscover = mergeMetric;
            }
            else if (mergeMetricDiscover.Last_Discover_Date__c <> null && mergeMetric.Last_Discover_Date__c < mergeMetricDiscover.Last_Discover_Date__c) {

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
                FolderName = 'Mass Merge Rules']) {

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
                        Source_Aggregate__c = (report.DeveloperName.contains('Account') ? 'Account' : 'Contact'),
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

    global void ProcessReportDiscover(C501_Merge_Metric__c mergeMetric, String foriegnKey, List<String> detailColumnsChecked, List<Reports.ReportFilter> reportFilters) {

        // Process by Accounts to find any potential Account merges
        ProcessReportByAccounts(mergeMetric, foriegnKey, detailColumnsChecked, reportFilters);

        if (mergeMetric.Source_Object__c.equals('Contact')) {

            // Process by Contacts different Accounts to find any potential contact merges across different accounts
            ProcessReportByContacts(mergeMetric, foriegnKey, detailColumnsChecked, reportFilters);

            // Process by Contacts same Account to find any potential contacts merges within same account
            detailColumnsChecked.add('AccountId');
            ProcessReportByContacts(mergeMetric, foriegnKey, detailColumnsChecked, reportFilters);
        }
    }
    global void ProcessReportByAccounts(C501_Merge_Metric__c mergeMetric, String foriegnKey, List<String> detailColumnsChecked, List<Reports.ReportFilter> reportFilters) {

        // Find Contact matches across Accounts
        //
        String strSoqlSelect = 'SELECT Count(' + mergeMetric.Source_Aggregate__c + '), MAX(' + mergeMetric.Source_Aggregate__c + ')MaxId, MIN(' + mergeMetric.Source_Aggregate__c + ')MinId ';
        String strSoqlFrom = ' FROM ' + mergeMetric.Source_Object__c;

        // Build WHERE statement
        //
        List<String> whereFields = new List<String>();
        List<String> whereInValues = new List<String>();

        // Add Null checks
        for (String column :detailColumnsChecked) {
            whereFields.add(column + ' <> null ');
        }

        // Check if Full Contact Match meaning every contact in the households have to match
        Boolean fullContactMatch = false;

        // Add filters
        for (Reports.ReportFilter reportFilter :reportFilters) {

            // Check for full contact match
            if (reportFilter.getValue().contains('Full Contact Match')) {

                fullContactMatch = true;
                continue;
            }

            String whereField = CheckReportOperator(mergeMetric, foriegnKey, reportFilter.getColumn(), reportFilter.getOperator(), reportFilter.getValue());
            if (String.isNotBlank(whereField)) {

                // Check if value contains a list of Strings
                if (reportFilter.getValue().contains(',')) {
                    whereInValues = reportFilter.getValue().split(',');
                    whereField = CheckReportColumnName(mergeMetric, foriegnKey, reportFilter.getColumn(), true) + ' in :whereInValues';
                }

                whereFields.add(whereField);
            }
        }

        String strSoqlWhere = ' WHERE ' + String.join(whereFields, ' and ');
        String strSoqlGroupBy = ' GROUP BY ' + String.join(detailColumnsChecked, ', ');
        String strSoqlHaving = ' HAVING Count(' + mergeMetric.Source_Aggregate__c + ') > 1 ';
        String strSoqlOrderBy = ' ORDER BY Count(' + mergeMetric.Source_Aggregate__c + ') DESC';

        System.debug('***** C501_MM_Rule_Discover:ProcessReportByAccounts aggregate SOQL');
        System.debug(strSoqlSelect);
        System.debug(strSoqlFrom);
        System.debug(strSoqlWhere);
        System.debug(strSoqlGroupBy);
        System.debug(strSoqlHaving);
        System.debug(strSoqlOrderBy);

		AggregateResult[] allAggregatedByAccounts = Database.Query(strSoqlSelect + strSoqlFrom + strSoqlWhere + strSoqlGroupBy + strSoqlHaving + strSoqlOrderBy);

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

                mergeAccountIds.add(maxId);
                mergeAccountIds.add(minId);
            }

            List<Contact> contacts = [
                SELECT AccountId, FirstName, LastName, Birthdate, Gender__c
                FROM Contact
                WHERE
                    AccountId in :mergeAccountIds
                    and FirstName <> null 
                    and Birthdate <> null 
                    and Gender__c <> null
                ORDER BY AccountId, FirstName, LastName, Birthdate, Gender__c DESC
                LIMIT 999];

            if (contacts.isEmpty()) {
                return;
            }

            for (Contact contactInfo :contacts) {
                String contactsInfo;
                if (accountContacts.containsKey(contactInfo.AccountId)) {
                    contactsInfo = accountContacts.remove(contactInfo.AccountId);
                }

                contactsInfo += contactInfo.FirstName.mid(1,1) + contactInfo.LastName + contactinfo.Birthdate + contactInfo.Gender__c;
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

    global void ProcessReportByContacts(C501_Merge_Metric__c mergeMetric, String foriegnKey, List<String> detailColumnsChecked, List<Reports.ReportFilter> reportFilters) {

        //
        // Testing in Workbench tips
        //      add LIMIT 10 at the end

        // Find Contact matches across Accounts
        //
        String strSoqlSelect = 'SELECT Count(' + mergeMetric.Source_Aggregate__c + '), MAX(' + mergeMetric.Source_Aggregate__c + ')MaxId, MIN(' + mergeMetric.Source_Aggregate__c + ')MinId ';
        String strSoqlFrom = ' FROM ' + mergeMetric.Source_Object__c;

        // Build WHERE statement
        //
        List<String> whereFields = new List<String>();
        List<String> whereInValues = new List<String>();
 
        // Add Null checks
        for (String column :detailColumnsChecked) {
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
                }

                whereFields.add(whereField);
            }
        }

        String strSoqlWhere = ' WHERE ' + String.join(whereFields, ' and ');
        String strSoqlGroupBy = ' GROUP BY ' + String.join(detailColumnsChecked, ', ');
        String strSoqlHaving = ' HAVING Count(' + mergeMetric.Source_Aggregate__c + ') > 1 ';
        String strSoqlOrderBy = ' ORDER BY Count(' + mergeMetric.Source_Aggregate__c + ') DESC';

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
    global String CheckReportColumnName(C501_Merge_Metric__c mergeMetric, String foriegnKey, String columnFieldName, Boolean filterColumn) {

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
            System.debug('***** C501_MM_Rule_Discover:CheckReportColumnName aggregate foriegnKey: ' + foriegnKey + ' columnFieldName: ' + columnFieldName);

            List<String> foriegnKeyFields = columnFieldName.split('\\.');
            System.debug('***** C501_MM_Rule_Discover:CheckReportColumnName foriegnKeyFields: ' + String.valueOf(foriegnKeyFields) + ' size(): ' + foriegnKeyFields.size());
            if (foriegnKeyFields.size() == 2) {
                System.debug('***** C501_MM_Rule_Discover:CheckReportColumnName return value: ' + foriegnKey + foriegnKeyFields[1]);
                return foriegnKey + foriegnKeyFields[1];
            }

            return null;
        }

        // Check for Source Object in Column Name
        else if (columnFieldName.startsWith(mergeMetric.Source_Object__c + '.')) {
            return columnFieldName.replace(mergeMetric.Source_Object__c + '.', '');
        }

        // General Columns
        else if (columnFieldName == 'LAST_UPDATE') {
            return 'LastModifiedDate';
        }
        else if (columnFieldName == 'CREATED_DATE') {
            return 'CreatedDate';
        }
        
        // Contact Report Columns
        //
        else if (columnFieldName == 'FIRST_NAME') {
            return 'FirstName';
        }
        else if (columnFieldName == 'LAST_NAME') {
            return 'LastName';
        }
        else if (columnFieldName.equals('CONTACT_ID')) {
            return 'Id';
        }

        // Account Report Columns
        //
        else if (columnFieldName.equals('ACCOUNT_ID')) {
            if (mergeMetric.Source_Object__c.equals('Account')) {
                return 'Id';
            }
            else {
                return 'AccountId';
            }
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

    global String CheckReportOperator(C501_Merge_Metric__c mergeMetric, String foriegnKey, String reportColumnName, String operator, String value) {

        String columnName = CheckReportColumnName(mergeMetric, foriegnKey, reportColumnName, true);
        System.debug('***** C501_MM_Rule_Discover:CheckReportOperator columnName: ' + columnName);
        
        if (String.isBlank(columnName)) {
            System.debug('***** C501_MM_Rule_Discover:CheckReportOperator columnName inValid');
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
}