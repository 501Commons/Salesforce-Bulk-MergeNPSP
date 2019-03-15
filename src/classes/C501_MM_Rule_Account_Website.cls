//
// Run Code FROM Developer Console
//  1) Debug -> Open Execute Anonymous Window
//  2) paste code
/*
      C501_MM_Rule_Account_Website accountWebsiteSchedule = new C501_MM_Rule_Account_Website();
      accountWebsiteSchedule.execute(null);
*/
//  3) click Execute
//

global class C501_MM_Rule_Account_Website implements Schedulable {

    global void execute(SchedulableContext SC) {

        system.debug('***** C501_MM_Rule_Account_Website:execute');

		//
		// Perform all SOQL Queries outside of loop to avoid Salesforce Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
		//

        String mergeMetricName = 'Account_Website';

        // Get Merge Metric
        List<C501_Merge_Metric__c> mergeMetrics = [
            SELECT Id, Name, Confidence__c, Total_Merge__c,
                Enable__c, AutoMerge_Percentage__c
            FROM C501_Merge_Metric__c
            WHERE Name = :mergeMetricName];
        if (mergeMetrics.isEmpty()) {
            mergeMetrics.add( new C501_Merge_Metric__c (
                Name = mergeMetricName,
                Confidence__c = 90.0,
                AutoMerge_Percentage__c = 0.0
            ));

            insert mergeMetrics;
        }

        if (!mergeMetrics[0].Enable__c) {
            return;
        }

        //
        // Testing in Workbench tips
        //      add LIMIT 10 at the end

		AggregateResult[] allAggregatedByShippingAddress = [
            SELECT Count(Id),
                MAX(Id)MaxAccountId,
                MIN(Id)MinAccountId
            FROM Account
            WHERE Website <> null
            GROUP BY Website,
                RecordTypeId
            HAVING Count(Id) > 1
            ORDER BY Count(Id) DESC];

        // Future Check - If you enable Geo Rules then you get ShippingGeocodeAccuracy, ShippingLatitude, and ShippingLongitude
        //      The problem is you can't use them in a GROUP BY so would need to add different strategy.  This would help for address
        //      values that are not exact text but same location like using St. vs Street or N. vs North would be same Long/Lat
        Map<String, C501_Account_Merge__c> mergeAccounts = new Map<String, C501_Account_Merge__c>();
        String uniqueId, minId, maxId;
        for (AggregateResult result : allAggregatedByShippingAddress)  {
            maxId = result.get('MaxAccountId').toString();
            minId = result.get('MinAccountId').toString();

            if (String.isEmpty(maxId) || String.isEmpty(minId) || maxId == minId) {
                continue;
            }

            uniqueId = mergeMetricName + maxId + minId;
            mergeAccounts.put(uniqueId, new C501_Account_Merge__c(
                Unique_Id__c = uniqueId,
                Merge_Confidence__c = mergeMetrics[0].Confidence__c,
                Account__c = minId,
                Merge_Target_Account__c = maxId,
                Merge_Metric__c = mergeMetrics[0].Id
            ));
        }

        C501_MassMerge_SharedCode c501MassMerge_SharedCode = new C501_MassMerge_SharedCode();
        c501MassMerge_SharedCode.ProcessMergeCandidates(mergeMetrics[0], mergeAccounts.values());
   }
}