//
// Run Code FROM Developer Console
//  1) Debug -> Open Execute Anonymous Window
//  2) paste code
/*
      C501_MM_Rule_Contact_NameDOB_Process contactNameDOBProcess = new C501_MM_Rule_Contact_NameDOB_Process();
      contactNameDOBProcess.execute(null);
*/
//  3) click Execute
//

global class C501_MM_Rule_Contact_NameDOB_Process implements Schedulable {

    global void execute(SchedulableContext SC) {

        System.debug('***** C501_MM_Rule_Contact_NameDOB_Process:execute');

		//
		// Perform all SOQL Queries outside of loop to avoid Salesforce Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
		//

        String mergeMetricName = 'Contact_NameDOB';
   }
}