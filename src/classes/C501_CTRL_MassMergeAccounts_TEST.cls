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
private with sharing class C501_CTRL_MassMergeAccounts_TEST {
    
    @testSetup static void setup() {
        C501_MassMerge_SharedCode c501MassMerge_SharedCode = new C501_MassMerge_SharedCode();
        c501MassMerge_SharedCode.TestSetupMerge();

        C501_MM_Rule_Contact_NameDOB scheduleNameDOB = new C501_MM_Rule_Contact_NameDOB();
        scheduleNameDOB.execute(null);

        C501_MM_Rule_Contact_NameEmail scheduleNameEmail = new C501_MM_Rule_Contact_NameEmail();
        scheduleNameEmail.execute(null);

        C501_MM_Rule_Account_Address scheduleAccountAddress = new C501_MM_Rule_Account_Address();
        scheduleAccountAddress.execute(null);

        C501_MM_Rule_Account_Website scheduleAccountWebsite = new C501_MM_Rule_Account_Website();
        scheduleAccountWebsite.execute(null);

        List<C501_Merge_Metric__c> listMergeMetrics = new List<C501_Merge_Metric__c>();
        for (C501_Merge_Metric__c mergeMetric :[SELECT Id FROM C501_Merge_Metric__c]) {
            mergeMetric.Enable__c = true;
            mergeMetric.AutoMerge_Percentage__c = 0.0;
            mergeMetric.AutoMerge_Objects__c = 'Account;Contact';

            listMergeMetrics.add(mergeMetric);
        }

        update listMergeMetrics;

        // Create Account Merges
        scheduleNameDOB.execute(null);
        scheduleNameEmail.execute(null);
        scheduleAccountAddress.execute(null);
        scheduleAccountWebsite.execute(null);

        // Attempt to create Account Merges again
        scheduleNameDOB.execute(null);
        scheduleNameEmail.execute(null);
        scheduleAccountAddress.execute(null);
        scheduleAccountWebsite.execute(null);
    }

    //==================== TEST METHOD(s) ======================================

    private static testmethod void CodeCoverageTests() {

        Id masterAccountId = [SELECT Id FROM Account ORDER BY Id ASC LIMIT 1].Id;

        //point to our VF page
        PageReference p = new PageReference('Page.MassMergeAccounts');
        p.getParameters().put('Id', masterAccountId);
        Test.setCurrentPageReference(p);
        
        //instantiate the controller for this opp
        C501_CTRL_MassMergeAccounts ctrl = new C501_CTRL_MassMergeAccounts();
        System.AssertEquals(masterAccountId, ctrl.accountFilter.Id);
        System.Assert(ctrl.listSOAccounts.size() > 1);
        System.Assert(ctrl.listAccounts.size() > 0);

        ctrl.accountFilter.Id = null;
        ctrl.ChangeMergeConfidence();
        ctrl.ChangeRule();
        ctrl.ChangeAccount();
        ctrl.ResetAccounts();
        
        System.Assert(ctrl.listSORules.size() > 0);

        // Check filter by Rule
        ctrl.accountFilter.Id = masterAccountId;
        ctrl.accountFilter.C501_Merge_Rule__c = 'Contact_NameDOB';
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
        for (Account accountMerge :ctrl.listAccounts) {
            accountMerge.C501_Merge_Action__c = 'Merge';
        }
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
    }

    private static testMethod void testPageMessagesController() {

        ApexPages.addMessage(new ApexPages.message(ApexPages.Severity.WARNING,'warning'));
        ApexPages.addMessage(new ApexPages.message(ApexPages.Severity.INFO,'info'));
        ApexPages.addMessage(new ApexPages.message(ApexPages.Severity.FATAL,'fatal'));
        ApexPages.addMessage(new ApexPages.message(ApexPages.Severity.ERROR,'error'));
        ApexPages.addMessage(new ApexPages.message(ApexPages.Severity.CONFIRM,'confirm'));

        C501_UTIL_PageMessages_CTRL controller = new C501_UTIL_PageMessages_CTRL();
        List<C501_UTIL_PageMessages_CTRL.Message> messages = controller.getPageMessages();

        System.assertEquals(5, messages.size(), 'There should be 5 messages on the page.');

        System.assertEquals(Label.PageMessagesWarning, messages[0].getSeverityLabel(), 'The label should be WARNING.');
        System.assertEquals('', messages[1].getSeverityLabel(), 'The label should be INFO.');
        System.assertEquals(Label.PageMessagesFatal, messages[2].getSeverityLabel(), 'The label should be FATAL.');
        System.assertEquals(Label.PageMessagesError, messages[3].getSeverityLabel(), 'The label should be ERROR.');
        System.assertEquals(Label.PageMessagesConfirm, messages[4].getSeverityLabel(), 'The label should be CONFIRM.');

        System.assertEquals('warning', messages[0].getSeverityTheme(), 'The theme should be warning.');
        System.assertEquals('info', messages[1].getSeverityTheme(), 'The theme should be info.');
        System.assertEquals('error', messages[2].getSeverityTheme(), 'The theme should be fatal.');
        System.assertEquals('error', messages[3].getSeverityTheme(), 'The theme should be error.');
        System.assertEquals('success', messages[4].getSeverityTheme(), 'The theme should be confirm.');
    }
}