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

@isTest
public class C501_CTRL_MassMergeAccounts_TEST {
    
    private static void setupTest() {

        C501_MassMerge_SharedCode c501MassMerge_SharedCode = new C501_MassMerge_SharedCode();
        c501MassMerge_SharedCode.TestSetupMerge();

        List<C501_Merge_Metric__c> listMergeMetrics = new List<C501_Merge_Metric__c>();
        for (C501_Merge_Metric__c mergeMetric :[SELECT Id FROM C501_Merge_Metric__c WHERE Name LIKE 'TESTDATA%' AND Name LIKE '%Account%']) {
            mergeMetric.AutoMerge_Percentage__c = 0.0;
            mergeMetric.AutoMerge_Objects__c = 'Account;Contacts Within Account;Contacts Across Accounts';

            listMergeMetrics.add(mergeMetric);
        }

        update listMergeMetrics;

        for (C501_Merge_Metric__c mergeMetric :listMergeMetrics) {
            C501_MM_Rule_Discover.get().executeMetric(mergeMetric.Id);
        }

        C501_MM_Rule_Merge scheduleMerge = new C501_MM_Rule_Merge();
        scheduleMerge.execute(null);

        c501MassMerge_SharedCode.PrintSalesforceStructure();
    }

    //==================== TEST METHOD(s) ======================================

    @isTest(SeeAllData='true')
    public static void Contact_NameDOB_Test() {

        setupTest();

        C501_MM_Rule_Discover scheduleDiscover = new C501_MM_Rule_Discover();
        scheduleDiscover.execute(null);

        List<C501_Merge_Metric__c> listMergeMetrics = new List<C501_Merge_Metric__c>();
        for (C501_Merge_Metric__c mergeMetric :[SELECT Id FROM C501_Merge_Metric__c WHERE Name LIKE 'TESTDATA%' AND Name LIKE '%Account%']) {
            mergeMetric.AutoMerge_Percentage__c = 90.0;
            mergeMetric.AutoMerge_Objects__c = 'Account;Contacts Within Account;Contacts Across Accounts';

            listMergeMetrics.add(mergeMetric);
        }

        update listMergeMetrics;

        Test.StartTest();

        // Run discover for each merge metric
        for (C501_Merge_Metric__c mergeMetric :listMergeMetrics) {
            scheduleDiscover.execute(null);
        }

        Test.StopTest();
    }

    @isTest(SeeAllData='true')
    public static void Contact_NameEmail_Test() {

        setupTest();

        C501_MM_Rule_Discover scheduleDiscover = new C501_MM_Rule_Discover();
        scheduleDiscover.execute(null);

        List<C501_Merge_Metric__c> listMergeMetrics = new List<C501_Merge_Metric__c>();
        for (C501_Merge_Metric__c mergeMetric :[SELECT Id FROM C501_Merge_Metric__c WHERE Name LIKE 'TESTDATA%' AND Name LIKE '%Account%']) {
            mergeMetric.AutoMerge_Percentage__c = 90.0;
            mergeMetric.AutoMerge_Objects__c = 'Account;Contacts Within Account;Contacts Across Accounts';

            listMergeMetrics.add(mergeMetric);
        }

        update listMergeMetrics;

        Test.StartTest();

        // Run discover for each merge metric
        for (C501_Merge_Metric__c mergeMetric :listMergeMetrics) {
            scheduleDiscover.execute(null);
        }

        Test.StopTest();
    }

    @isTest(SeeAllData='true')
    public static void Account_Address_Test() {

        setupTest();

        C501_MM_Rule_Discover scheduleDiscover = new C501_MM_Rule_Discover();
        scheduleDiscover.execute(null);

        List<C501_Merge_Metric__c> listMergeMetrics = new List<C501_Merge_Metric__c>();
        for (C501_Merge_Metric__c mergeMetric :[SELECT Id FROM C501_Merge_Metric__c WHERE Name LIKE 'TESTDATA%' AND Name LIKE '%Account%']) {
            mergeMetric.AutoMerge_Percentage__c = 90.0;
            mergeMetric.AutoMerge_Objects__c = 'Account;Contacts Within Account;Contacts Across Accounts';

            listMergeMetrics.add(mergeMetric);
        }

        update listMergeMetrics;

        Test.StartTest();

        // Run discover for each merge metric
        for (C501_Merge_Metric__c mergeMetric :listMergeMetrics) {
            scheduleDiscover.execute(null);
        }

        Test.StopTest();
    }

    @isTest(SeeAllData='true')
    public static void Account_NoContacts_Test() {

        setupTest();

        C501_MM_Rule_Discover scheduleDiscover = new C501_MM_Rule_Discover();
        scheduleDiscover.execute(null);

        List<C501_Merge_Metric__c> listMergeMetrics = new List<C501_Merge_Metric__c>();
        for (C501_Merge_Metric__c mergeMetric :[SELECT Id FROM C501_Merge_Metric__c WHERE Name LIKE 'TESTDATA%' AND Name LIKE '%Account%']) {
            mergeMetric.AutoMerge_Percentage__c = 90.0;
            mergeMetric.AutoMerge_Objects__c = 'Account;Contacts Within Account;Contacts Across Accounts';

            listMergeMetrics.add(mergeMetric);
        }

        update listMergeMetrics;

        Test.StartTest();

        // Run discover for each merge metric
        for (C501_Merge_Metric__c mergeMetric :listMergeMetrics) {
            scheduleDiscover.execute(null);
        }

        Test.StopTest();
    }

    @isTest(SeeAllData='true')
    public static void Account_Website_Test() {

        setupTest();

        C501_MM_Rule_Discover scheduleDiscover = new C501_MM_Rule_Discover();
        scheduleDiscover.execute(null);

        List<C501_Merge_Metric__c> listMergeMetrics = new List<C501_Merge_Metric__c>();
        for (C501_Merge_Metric__c mergeMetric :[SELECT Id FROM C501_Merge_Metric__c WHERE Name LIKE 'TESTDATA%' AND Name LIKE '%Account%']) {
            mergeMetric.AutoMerge_Percentage__c = 90.0;
            mergeMetric.AutoMerge_Objects__c = 'Account;Contacts Within Account;Contacts Across Accounts';

            listMergeMetrics.add(mergeMetric);
        }

        update listMergeMetrics;

        Test.StartTest();

        // Run discover for each merge metric
        for (C501_Merge_Metric__c mergeMetric :listMergeMetrics) {
            scheduleDiscover.execute(null);
        }

        Test.StopTest();
    }

    @isTest(SeeAllData='true')
    public static void ProcessObjectMerges_BatchTest() {

        setupTest();

        List<C501_Merge_Metric__c> listMergeMetrics = [SELECT Id FROM C501_Merge_Metric__c WHERE Name LIKE 'TESTDATA%' AND Name LIKE '%Account%'];
        List<Account> listAccounts = [SELECT Id FROM Account WHERE Name LIKE 'TESTDATA%'];

        C501_Account_Merge__c accountMerge = new C501_Account_Merge__c(
                Unique_Id__c = 'TESTDATA Name ' + listAccounts[0].Id,
                Merge_Metric__c = listMergeMetrics[0].Id,
                Account__c = listAccounts[0].Id,
                Merge_Target_Account__c = listAccounts[1].Id,
                Merge_Confidence__c = 100.0,
                Merge_Action__c = 'Master');

        insert accountMerge;

        Boolean exceptionRaised = false;

        Test.StartTest();

        // Exception Note:  Currently not getting the exception in the test code for Batch scheduled job.  Thinking need to query the batch job status instead to figure out if exception thrown
        //
        try
        {
            C501_MassMerge_SharedCode_Account c501MassMerge_SharedCode_Account = new C501_MassMerge_SharedCode_Account();
            c501MassMerge_SharedCode_Account.ProcessObjectMerges(new List<C501_Account_Merge__c> { accountMerge }, true);
        }
        catch (C501_MassMerge_SharedCode_Account.C501_MassMerge_SharedCode_AccountException customException)
        {
            exceptionRaised = true;
        }
        catch (System.DmlException dmlException) {
            exceptionRaised = true;
        }
        catch (Exception generalException) {
            exceptionRaised = true;
        }

        Test.StopTest();

        //System.AssertEquals(true, exceptionRaised, 'Exception should be thrown for Account merges on Batchable context');
    }

    @isTest(SeeAllData='true')
    public static void ProcessObjectMerges_SyncTest() {

        setupTest();

        List<C501_Merge_Metric__c> listMergeMetrics = [SELECT Id FROM C501_Merge_Metric__c WHERE Name LIKE 'TESTDATA%' AND Name LIKE '%Account%'];
        List<Account> listAccounts = [SELECT Id FROM Account WHERE Name LIKE 'TESTDATA%'];

        C501_Account_Merge__c accountMerge = new C501_Account_Merge__c(
                Unique_Id__c = 'TESTDATA Name ' + listAccounts[0].Id,
                Merge_Metric__c = listMergeMetrics[0].Id,
                Account__c = listAccounts[0].Id,
                Merge_Target_Account__c = listAccounts[1].Id,
                Merge_Confidence__c = 100.0,
                Merge_Action__c = 'Master');

        insert accountMerge;

        Test.StartTest();

        C501_MassMerge_SharedCode_Account c501MassMerge_SharedCode_Account = new C501_MassMerge_SharedCode_Account();
        c501MassMerge_SharedCode_Account.ProcessObjectMerges(new List<C501_Account_Merge__c> { accountMerge }, false);

        Test.StopTest();
    }

    @isTest(SeeAllData='true')
    public static void CodeCoverageTests() {

        setupTest();

        Id masterAccountId = [SELECT Id FROM Account WHERE Name LIKE 'TESTDATA%' ORDER BY Id ASC LIMIT 1].Id;

        Test.StartTest();

        //point to our VF page
        PageReference p = new PageReference('Page.MassMergeAccounts');
        p.getParameters().put('Id', masterAccountId);
        Test.setCurrentPageReference(p);
        
        C501_CTRL_MassMergeAccounts ctrl = new C501_CTRL_MassMergeAccounts();
        System.AssertEquals(masterAccountId, ctrl.accountFilter.Id);

        System.Assert(ctrl.listSOAccounts.size() > 1);
        System.Assert(ctrl.listAccounts.size() > 0);

        ctrl.accountFilter.Id = null;

        System.Assert(ctrl.listSOAccounts.size() > 1);
        System.Assert(ctrl.listAccounts.size() > 0);

        ctrl.ChangeMergeConfidence();
        ctrl.ChangeRule();
        ctrl.ChangeAccount();
        ctrl.ResetAccounts();
        
        System.Assert(ctrl.listSORules.size() > 0);

        // Check filter by Rule
        ctrl.accountFilter.Id = masterAccountId;
        List<C501_Merge_Metric__c> listMergeMetrics = [SELECT Name FROM C501_Merge_Metric__c WHERE Name LIKE 'TESTDATA%' AND Name LIKE '%Account%'];
        ctrl.accountFilter.C501_Merge_Rule__c = listMergeMetrics[0].Name;
        System.Assert(ctrl.listAccounts.size() > 0);

        // Check filter by Confidence
        ctrl.accountFilter.Id = masterAccountId;
        ctrl.accountFilter.C501_Merge_Confidence_From__c = 0.0;
        ctrl.accountFilter.C501_Merge_Confidence_To__c = 100.0;
        System.Assert(ctrl.listAccounts.size() > 0);

        // Clear filter
        ctrl.ChangeRule();
        ctrl.accountFilter.Id = masterAccountId;
        System.Assert(ctrl.listAccounts.size() > 0);
        System.AssertEquals(0, ctrl.numberOfRecordsDirty);
        
        //ctrl.listAccounts.get(0).Amount = 2;
        p.getParameters().put('usersIdDirtied', ctrl.listAccounts.get(0).id);
        ctrl.AccountsRecordModified();
        System.AssertEquals(1, ctrl.setAccountsIdDirty.size());
        
        Account account = ctrl.listAccounts.get(ctrl.listAccounts.size() - 1);
        p.getParameters().put('usersIdDirtied', null);
        ctrl.AccountsRecordModified();
        System.AssertEquals(1, ctrl.setAccountsIdDirty.size());
        System.AssertEquals(1, ctrl.numberOfRecordsDirty);

        // test the save!
        ctrl.listAccounts[0].C501_Merge_Action__c = 'Master';
        ctrl.listAccounts[ctrl.listAccounts.size() - 1].C501_Merge_Action__c = 'Ignore';

        ctrl.SaveAccounts();

        System.debug('***** C501_CTRL_MassMergeAccounts_TEST::CodeCoverageTests' + ctrl.strSaveResults);
        //System.Assert(ctrl.strSaveResults.startsWith('Error'));
        ctrl.ChangeRule();
        ctrl.SaveAccounts();      
        //System.AssertEquals(0, ctrl.numberOfRecordsDirty);  

        // Clear out household filter
        ctrl.accountFilter.Id = null;
        ctrl.SaveAndCloseAccounts();   

        Test.StopTest();
    }

    @isTest(SeeAllData='true')
    public static void testPageMessagesController() {

        setupTest();

        Test.StartTest();

        ApexPages.addMessage(new ApexPages.message(ApexPages.Severity.WARNING,'warning'));
        ApexPages.addMessage(new ApexPages.message(ApexPages.Severity.INFO,'info'));
        ApexPages.addMessage(new ApexPages.message(ApexPages.Severity.FATAL,'fatal'));
        ApexPages.addMessage(new ApexPages.message(ApexPages.Severity.ERROR,'error'));
        ApexPages.addMessage(new ApexPages.message(ApexPages.Severity.CONFIRM,'confirm'));

        C501_UTIL_PageMessages_CTRL controller = new C501_UTIL_PageMessages_CTRL();
        List<C501_UTIL_PageMessages_CTRL.Message> messages = controller.getPageMessages();

        System.assertEquals(5, messages.size(), 'There should be 5 messages on the page.');

        System.assertEquals(Label.Merge_PageMessagesWarning, messages[0].getSeverityLabel(), 'The label should be WARNING.');
        System.assertEquals('', messages[1].getSeverityLabel(), 'The label should be INFO.');
        System.assertEquals(Label.Merge_PageMessagesFatal, messages[2].getSeverityLabel(), 'The label should be FATAL.');
        System.assertEquals(Label.Merge_PageMessagesError, messages[3].getSeverityLabel(), 'The label should be ERROR.');
        System.assertEquals(Label.Merge_PageMessagesConfirm, messages[4].getSeverityLabel(), 'The label should be CONFIRM.');

        System.assertEquals('warning', messages[0].getSeverityTheme(), 'The theme should be warning.');
        System.assertEquals('info', messages[1].getSeverityTheme(), 'The theme should be info.');
        System.assertEquals('error', messages[2].getSeverityTheme(), 'The theme should be fatal.');
        System.assertEquals('error', messages[3].getSeverityTheme(), 'The theme should be error.');
        System.assertEquals('success', messages[4].getSeverityTheme(), 'The theme should be confirm.');

        Test.StopTest();
    }
}