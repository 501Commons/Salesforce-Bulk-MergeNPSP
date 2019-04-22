//
// Run Code FROM Developer Console
//  1) Debug -> Open Execute Anonymous Window
//  2) paste code
/*
      C501_MM_Rule_Discover discover = new C501_MM_Rule_Discover();
      discover.execute(null);
*/
//  3) click Execute
//

global class C501_MM_Rule_Discover implements Schedulable {

    global void execute(SchedulableContext SC) {

 		//
		// Perform all SOQL Queries outside of loop to avoid Salesforce Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
		//

        List<C501_Merge_Metric__c> mergeMetrics = [
            SELECT
                Id, Name, Confidence__c,
                Total_Unassigned_Accounts__c, Total_Unassigned_Contacts__c,
                Enable__c, Source_Report__c,
                AutoMerge_Percentage__c, AutoMerge_Objects__c
            FROM C501_Merge_Metric__c];

        Set<String> sourceReportIds = new Set<String>();
        for (C501_Merge_Metric__c mergeMetric : mergeMetrics) {
            if (!String.isEmpty(mergeMetric.Source_Report__c)) {
                sourceReportIds.add(mergeMetric.Source_Report__c);
            }
        }

        List<Report> reports = [
            SELECT Id, DeveloperName
            FROM Report
            WHERE Id in :sourceReportIds OR DeveloperName in :sourceReportIds];

        // Walk through Merge Metrics
        String reportId;
        for (C501_Merge_Metric__c mergeMetric : [
            SELECT
                Id, Name, Confidence__c,
                Total_Unassigned_Accounts__c, Total_Unassigned_Contacts__c,
                Enable__c, Source_Report__c,
                AutoMerge_Percentage__c, AutoMerge_Objects__c
            FROM C501_Merge_Metric__c]) {

            if (!mergeMetric.Enable__c) {
                continue;
            }

            //String reportId;
            reportId = '';
            for (Report report :reports) {
                if (report.Id == mergeMetric.Source_Report__c || report.DeveloperName == mergeMetric.Source_Report__c) {
                    reportId = (String)report.Id;
                    break;
                }
            }
            
            if (String.isEmpty(reportId)) {
                continue;
            }

            System.debug('***** C501_MM_Rule_Discover:execute - Merge Metric Name: ' + mergeMetric.Name + ' reportId: ' + reportId);

            // NOTE: Calling Reports.ReportManager within this loop context get compile error ReportManager variable does not exist.  Future task - investigate why
            ProcessReport(reportId);
        }
    }

    global void ProcessReport(String reportId) {

        // Get the report metadata
        Reports.ReportMetadata reportMetadata = Reports.ReportManager.describeReport(reportId).getReportMetadata();

        System.debug('***** C501_MM_Rule_Discover:ProcessReport Name: ' + reportMetadata.getName());
        System.debug('***** C501_MM_Rule_Discover:ProcessReport ID: ' + reportMetadata.getId());
        System.debug('***** C501_MM_Rule_Discover:ProcessReport Description: ' + reportMetadata.getDescription());
        System.debug('***** C501_MM_Rule_Discover:ProcessReport Developer name: ' + reportMetadata.getDeveloperName());
        System.debug('***** C501_MM_Rule_Discover:ProcessReport Report format: ' + reportMetadata.getReportFormat());
        System.debug('***** C501_MM_Rule_Discover:ProcessReport Report type: ' + reportMetadata.getReportType());
        System.debug('***** C501_MM_Rule_Discover:ProcessReport Scope: ' + reportMetadata.getScope());

        // Build SELECT Statement
        //
        String strSOQL = 'SELECT ';
        List<String> detailColumns = reportMetadata.getDetailColumns();
        List<String> detailColumnsChecked = new List<String>();
        for (String detailColumn : detailColumns) {
            detailColumnsChecked.add(CheckReportColumnName(detailColumn));
        }
        System.debug('***** C501_MM_Rule_Discover:ProcessReport Detail columns - Report Format: ' + detailColumns);
        String selectColumns = String.join(detailColumnsChecked, ',');
        System.debug('***** C501_MM_Rule_Discover:ProcessReport Detail columns - Select Format: ' + selectColumns);

        strSoql += selectColumns;

        // Build FROM Statement
        //
        strSoql += ' FROM Contact ';

        // Build WHERE Statement
        //
        List<Reports.ReportFilter> reportFilters = reportMetadata.getReportFilters();
        System.debug('Filters - Report Format: ' + reportFilters);
        List<String> whereClauses = new List<String>();
        for (Reports.ReportFilter reportFilter :reportFilters) {
            System.debug('***** C501_MM_Rule_Discover:ProcessReport Filters - Report Format Expanded Column: ' + reportFilter.getColumn() + ' Operator: ' + reportFilter.getOperator() + ' Value: ' + reportFilter.getValue());
            String whereClause = CheckReportOperator(reportFilter.getColumn(), reportFilter.getOperator(), reportFilter.getValue());
            System.debug('***** C501_MM_Rule_Discover:ProcessReport Filters - Where Format Expanded Column: ' + whereClause);
            whereClauses.add(whereClause);
        }
        
        strSOQL += ' WHERE ' + String.join(whereClauses, ' AND ');

        System.debug('***** C501_MM_Rule_Discover:ProcessReport SOQL Statement: ' + strSoql);

        System.debug('***** C501_MM_Rule_Discover:ProcessReport Cross filters: ' + reportMetadata.getCrossFilters());
        System.debug('***** C501_MM_Rule_Discover:ProcessReport Boolean filter: ' + reportMetadata.getReportBooleanFilter());
        System.debug('***** C501_MM_Rule_Discover:ProcessReport Standard Filters: ' + reportMetadata.getStandardFilters());
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