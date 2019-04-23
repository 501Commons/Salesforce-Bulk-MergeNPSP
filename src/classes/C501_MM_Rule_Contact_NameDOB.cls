//
// Run Code FROM Developer Console
//  1) Debug -> Open Execute Anonymous Window
//  2) paste code
/*
      C501_MM_Rule_Contact_NameDOB contactNameDOB = new C501_MM_Rule_Contact_NameDOB();
      contactNameDOB.execute(null);
*/
//  3) click Execute
//

global class C501_MM_Rule_Contact_NameDOB implements Schedulable {

    global void execute(SchedulableContext SC) {

        System.debug('***** C501_MM_Rule_Contact_NameDOB:execute');

		//
		// Perform all SOQL Queries outside of loop to avoid Salesforce Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
		//

        String mergeMetricName = 'Contact_NameDOB';

        // Get Merge Metric
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
                Name = mergeMetricName,
                Confidence__c = 90.0,
                AutoMerge_Percentage__c = 0.0,
                Description__c = 'FirstName, LastName, Birthdate exact match between 2 contacts from different Households.  FirstName and Birthdate must have a valid value.'
            ));

            insert mergeMetrics;
        }

        if (!mergeMetrics[0].Enable__c) {
            return;
        }

        //
        // Testing in Workbench tips
        //      add LIMIT 10 at the end

        // Find Contact matches across Accounts
        //
		AggregateResult[] allAggregatedByContacts = [
            SELECT Count(AccountId),
                MAX(AccountId)MaxAccountId,
                MIN(AccountId)MinAccountId
            FROM Contact
            WHERE
                FirstName <> null
                and Birthdate <> null
            GROUP BY FirstName,
                LastName,
                Birthdate,
                Gender__c
            HAVING Count(AccountId) > 1
            ORDER BY Count(AccountId) DESC];

        Map<String, C501_Account_Merge__c> mergeAccounts = new Map<String, C501_Account_Merge__c>();
        String uniqueId, minId, maxId;
        for (AggregateResult result : allAggregatedByContacts)  {
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

        C501_MassMerge_SharedCode_Account c501MassMerge_SharedCode_Account = new C501_MassMerge_SharedCode_Account();
        c501MassMerge_SharedCode_Account.InsertObjectMergeCandidates(mergeMetrics[0], mergeAccounts.values());

        // Find Contact matches within an Account
        //
		AggregateResult[] allAggregatedByContactsWithinAccount = [
            SELECT
                Count(Id),
                MAX(Id)MaxContactId,
                MIN(Id)MinContactId
            FROM Contact
            WHERE FirstName <> null
                and Birthdate <> null
            GROUP BY 
                AccountId,
                FirstName,
                LastName,
                Birthdate,
                Gender__c
            HAVING Count(Id) > 1
            ORDER BY Count(Id) DESC];

        Map<String, C501_Contact_Merge__c> mergeContacts = new Map<String, C501_Contact_Merge__c>();
        for (AggregateResult result : allAggregatedByContactsWithinAccount)  {
            maxId = result.get('MaxContactId').toString();
            minId = result.get('MinContactId').toString();

            if (String.isEmpty(maxId) || String.isEmpty(minId) || maxId == minId) {
                continue;
            }

            uniqueId = mergeMetricName + maxId + minId;
            mergeContacts.put(uniqueId, new C501_Contact_Merge__c(
                Unique_Id__c = uniqueId,
                Merge_Confidence__c = mergeMetrics[0].Confidence__c,
                Contact__c = minId,
                Merge_Target_Contact__c = maxId,
                Merge_Metric__c = mergeMetrics[0].Id
            ));
        }

        // Find Contact matches across Accounts
        //
		AggregateResult[] allAggregatedByContactsBetweenAccounts = [
            SELECT
                Count(Id),
                MAX(Id)MaxContactId,
                MIN(Id)MinContactId
            FROM Contact
            WHERE FirstName <> null
                and Birthdate <> null
            GROUP BY 
                FirstName,
                LastName,
                Birthdate,
                Gender__c
            HAVING Count(Id) > 1
            ORDER BY Count(Id) DESC];

        for (AggregateResult result : allAggregatedByContactsBetweenAccounts)  {
            maxId = result.get('MaxContactId').toString();
            minId = result.get('MinContactId').toString();

            if (String.isEmpty(maxId) || String.isEmpty(minId) || maxId == minId) {
                continue;
            }

            uniqueId = mergeMetricName + maxId + minId;
            mergeContacts.put(uniqueId, new C501_Contact_Merge__c(
                Unique_Id__c = uniqueId,
                Merge_Confidence__c = mergeMetrics[0].Confidence__c,
                Contact__c = minId,
                Merge_Target_Contact__c = maxId,
                Merge_Metric__c = mergeMetrics[0].Id
            ));
        }

        C501_MassMerge_SharedCode_Contact c501MassMerge_SharedCode_Contact = new C501_MassMerge_SharedCode_Contact();
        c501MassMerge_SharedCode_Contact.InsertObjectMergeCandidates(mergeMetrics[0], mergeContacts.values());
   }
}