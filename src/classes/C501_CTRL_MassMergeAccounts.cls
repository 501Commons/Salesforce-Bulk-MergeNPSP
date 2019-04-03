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

global virtual with sharing class C501_CTRL_MassMergeAccounts {

    global integer cEmptyAccountRecords {
        get {
            return 1;
        }
    }
    
    private C501_MassMerge_SharedCode c501MassMerge_SharedCode;
    private List<String> listStrFields;
    
    global boolean redirect { get; private set; }
    global ID idRedirect { get; private set; }
    
    // constructor
    global C501_CTRL_MassMergeAccounts() {

        System.debug('***** C501_CTRL_MassMergeAccounts::C501_CTRL_MassMergeAccounts Constructor');

        redirect = false;
        c501MassMerge_SharedCode = new C501_MassMerge_SharedCode();
        
        // handle optional parameters (must use string, not ID, to handle null)
        string id = ApexPages.currentPage().getParameters().get('id');
        if (id != null && id != '') accountFilter.Id = id;
        
        // Get list of fields FROM fieldset
        listStrFields = new List<String>();
        for (Schema.FieldSetMember f : SObjectType.Account.FieldSets.MassMergeAccounts.getFields()) {
            listStrFields.add(f.getFieldPath());
        }

        // Required fields
        listStrFields.add('Id');
        listStrFields.add('C501_Merge_Action__c');
    }   
    
    global list<SelectOption> listSOAccounts {
        get {
            if (listSOAccounts == null )
                listSOAccounts = c501MassMerge_SharedCode.listSOAccountsWithConfidence(accountFilter.C501_Merge_Rule__c, accountFilter.C501_Merge_Confidence_From__c, accountFilter.C501_Merge_Confidence_To__c);

            return listSOAccounts;
        }

        set;
        }

    global list<SelectOption> listSORules {
        get {
            if (listSORules == null ) {
                listSORules = new List<System.SelectOption>();
                listSORules.add(new SelectOption('', ''));

          		AggregateResult[] allAggregatedByRule = [
                    SELECT Merge_Metric__r.Name
                    FROM C501_Account_Merge__c
                    GROUP BY Merge_Metric__r.Name
                    ORDER BY Merge_Metric__r.Name ASC];

                for (AggregateResult result : allAggregatedByRule)  {
                    String ruleName = result.get('Name').toString();
                    listSORules.add(new SelectOption(ruleName, ruleName));
                }
            }

            return listSORules;
        }

        set;
        }

    // Confidence to filter the list of accounts
    global Account accountFilter {
        get {
            if (accountFilter == null) {
                accountFilter = new Account();
                
                accountFilter.C501_Merge_Rule__c = null;
                accountFilter.C501_Merge_Confidence_From__c = 90.0;
                accountFilter.C501_Merge_Confidence_To__c = 100.0;
            }
            return accountFilter;
        }
        set;
    }

    // the user has changed the Account dropdown
    global virtual PageReference ChangeAccount() {

        listAccounts = null;
        strSaveResults = null;

        return null;
    }

    // the user has changed the Rule dropdown
    global virtual PageReference ChangeRule() {

        listSOAccounts = null;
        accountFilter.Id = null;
        listAccounts = null;
        strSaveResults = null;

        return null;
    }

    // the user has changed the Confidence query
    global virtual PageReference ChangeMergeConfidence() {

        listSOAccounts = null;
        accountFilter.Id = null;
        listAccounts = null;
        strSaveResults = null;

        return null;
    }

    global virtual void ResetAccounts() {

        System.debug('***** C501_CTRL_MassMergeAccounts::ResetAccounts');

        listSOAccounts = null;
        accountFilter.Id = null;
        listAccounts = null;
    }

    // status string for reporting the results of saving.
    global String strSaveResults { get; set; }
      
    // The list of Accounts.
    global list<Account> listAccounts {
        get {
            if (listAccounts == null) {
                FillListAccounts();

                System.debug('***** C501_CTRL_MassMergeAccounts::listAccounts listAccounts: ' + String.valueOf(listAccounts));
            }

            return listAccounts;
        }
        
        set;
    }
        
    // helper function that the client can override, to query for the appropriate fields in Accounts.
    global virtual void FillListAccounts() {

		Map<Id,C501_Account_Merge__c> accountsMerge = new Map<Id,C501_Account_Merge__c>();

        if (accountFilter.Id <> null) {
        
            for(C501_Account_Merge__c accountMerge : [
                SELECT Id, Account__c, Merge_Target_Account__c, Merge_Confidence__c, Merge_Action__c, Merge_Metric__c, Merge_Metric__r.Name
                FROM C501_Account_Merge__c
                WHERE (Account__c = :accountFilter.Id OR Merge_Target_Account__c = :accountFilter.Id) AND isDeleted = false]) {

                    accountsMerge.put(
                        accountMerge.Account__c,
                        new C501_Account_Merge__c(
                            Merge_Action__c = accountMerge.Merge_Action__c,
                            Merge_Confidence__c = null,
                            Account__c = accountMerge.Account__c,
                            Merge_Target_Account__c = accountMerge.Merge_Target_Account__c,
                            Merge_Metric__c = accountMerge.Merge_Metric__c,
                            Merge_Metric_Name__c = 'Merge ' + accountMerge.Merge_Metric__r.Name
                    ));

                    accountsMerge.put(
                        accountMerge.Merge_Target_Account__c,
                        new C501_Account_Merge__c(
                            Merge_Action__c = accountMerge.Merge_Action__c,
                            Merge_Confidence__c = accountMerge.Merge_Confidence__c,
                            Account__c = accountMerge.Account__c,
                            Merge_Target_Account__c = accountMerge.Merge_Target_Account__c,
                            Merge_Metric__c = accountMerge.Merge_Metric__c,
                            Merge_Metric_Name__c = 'Merge ' + accountMerge.Merge_Metric__r.Name
                    ));
            }
        }
        else {

            Set<String> accountIds = new Set<String>();
            for (SelectOption option : listSOAccounts) {
                accountIds.add(option.getValue());

                // Performance: Only allow 50 at a time to load in the webpage
                if (accountIds.size() >= 50) {
                    break;
                }
            }

            Integer mergeIndex = 1;
            String mergeBuffer = '0';

            String mergeRule = accountFilter.C501_Merge_Rule__c;
            String strRuleSoql = '';
            if (mergeRule <> null && !String.isBlank(mergeRule)) {
                strRuleSoql = ' and Merge_Metric__r.Name = :mergeRule';
            }

            string strSoql = 'SELECT Id, Account__c, Merge_Target_Account__c, Merge_Confidence__c, Merge_Action__c, Merge_Metric__c, Merge_Metric__r.Name';

            strSoql += ' FROM C501_Account_Merge__c';
            strSoql += ' WHERE (Account__c in :accountIds OR Merge_Target_Account__c in :accountIds) AND isDeleted = false';
            strSoql += strRuleSoql;
            strSoql += ' ORDER BY Account__r.Name ASC';

            for(C501_Account_Merge__c accountMerge : Database.Query(strSoql)) {

                    if (accountsMerge.containsKey(accountMerge.Account__c) || accountsMerge.containsKey(accountMerge.Merge_Target_Account__c)) {
                        continue;
                    }
                    
                    accountsMerge.put(
                        accountMerge.Account__c,
                        new C501_Account_Merge__c(
                            Merge_Action__c = accountMerge.Merge_Action__c,
                            Merge_Confidence__c = null,
                            Account__c = accountMerge.Account__c,
                            Merge_Target_Account__c = accountMerge.Merge_Target_Account__c,
                            Merge_Metric__c = accountMerge.Merge_Metric__c,
                            Merge_Metric_Name__c = 'Merge ' + mergeBuffer + mergeIndex + ' ' + accountMerge.Merge_Metric__r.Name
                    ));

                    accountsMerge.put(
                        accountMerge.Merge_Target_Account__c,
                        new C501_Account_Merge__c(
                            Merge_Action__c = accountMerge.Merge_Action__c,
                            Merge_Confidence__c = accountMerge.Merge_Confidence__c,
                            Account__c = accountMerge.Account__c,
                            Merge_Target_Account__c = accountMerge.Merge_Target_Account__c,
                            Merge_Metric__c = accountMerge.Merge_Metric__c,
                            Merge_Metric_Name__c = 'Merge ' + mergeBuffer + mergeIndex + ' ' + accountMerge.Merge_Metric__r.Name
                    ));

                    mergeIndex++;
                    if (mergeIndex >= 10) {
                        mergeBuffer = '';
                    }
            }
        }

        String strSoql = 'SELECT ' + String.join(listStrFields, ',');

        Set<Id> accountsMergeIds = accountsMerge.keySet();
        strSoql += ' FROM Account WHERE Id in :accountsMergeIds';
        strSoql += ' order by C501_Merge_Metric_Name__c ASC NULLS FIRST';
        
        listAccounts = Database.Query(strSoql);

        for ( Account account :listAccounts ) {
            if (accountsMerge.containsKey(account.Id)) {
                C501_Account_Merge__c mergeAccount = accountsMerge.get(account.Id);
                account.C501_Merge_Action__c = mergeAccount.Merge_Action__c;
                account.C501_Merge_Confidence__c = mergeAccount.Merge_Confidence__c;
                account.C501_Merge_Account__c = mergeAccount.Account__c;
                account.C501_Merge_Target__c = mergeAccount.Merge_Target_Account__c;
                account.C501_Merge_Metric_Name__c = mergeAccount.Merge_Metric_Name__c;
            }
        }

        // Update Accounts w/ Merge fields then query to get the correct sort order by Metric Name
        update listAccounts;

        listAccounts = Database.Query(strSoql);
    }
    
    global Boolean fHasListAccounts {
        get {
            return listAccounts != null && listAccounts.size() > 0;
        }
    }     
 
    // used to track the Id's of all Account records that get modified.
    global Set<ID> setAccountsIdDirty {
        get {
            if (setAccountsIdDirty == null) {
                setAccountsIdDirty = new Set<ID>();
            }
            return setAccountsIdDirty;
        }
        set;
    }
    
    // to allow vf page to see how many Account records are dirty
    global Integer numberOfRecordsDirty {
        get { 
            if (setAccountsIdDirty == null)
                return 0;
            else
                return setAccountsIdDirty.size();
        }
    }
    
    // this gets called whenever a field in the Accounts datatable is modified.
    // use this to remember which existing Accounts records have been modified.
    global virtual PageReference AccountsRecordModified() {
        String strId = ApexPages.currentPage().getParameters().get('usersIdDirtied');
        if (strId != null && strId != '') setAccountsIdDirty.add(strId);
        return null;
    }
    
    //save the Accounts created or modified
    global virtual PageReference SaveAccounts() {
        
        if (listAccounts == null) return null;
        
        strSaveResults = null;
        
        try {
            Map<String, List<Account>> listAccountsMerge = new Map<String, List<Account>>();
            List<C501_Account_Merge__c> listAccountsMergeIgnore = new List<C501_Account_Merge__c>();

            System.debug('***** C501_CTRL_MassMergeAccounts::SaveAccounts listAccounts: ' + String.valueOf(listAccounts));

            for (Account account : listAccounts) {

                if (account.Id != null && account.C501_Merge_Action__c == 'Merge') {

                    System.debug('***** C501_CTRL_MassMergeAccounts::SaveAccounts Check Merge Action - Merge Rule: ' + account.C501_Merge_Metric_Name__c);

                    // we couldn't reliably mark dirty records in all scenarios,
                    // so we've decided it is better to always update all records.
                    //if (setAccountsIdDirty.contains(account.Id)) 
                    if (listAccountsMerge.containsKey(account.C501_Merge_Metric_Name__c)) {
                        List<Account> accounts = listAccountsMerge.remove(account.C501_Merge_Metric_Name__c);
                        accounts.add(account);
                        listAccountsMerge.put(account.C501_Merge_Metric_Name__c, accounts);
                    }
                    else {
                        listAccountsMerge.put(account.C501_Merge_Metric_Name__c, new List<Account> { account });
                    }

                    System.debug('***** C501_CTRL_MassMergeAccounts::SaveAccounts Update Merge Action - account: ' + String.valueOf(account)
                        + ' listAccountsMerge Keys: ' + String.valueOf(listAccountsMerge.keySet()));
                }

                if (account.Id != null && account.C501_Merge_Action__c == 'Ignore') {

                    // we couldn't reliably mark dirty records in all scenarios,
                    // so we've decided it is better to always update all records.
                    //if (setAccountsIdDirty.contains(account.Id)) 
                    listAccountsMergeIgnore.add(new C501_Account_Merge__c(
                        Id = account.C501_Merge_Account__c,
                        Account__c = account.Id,
                        Merge_Target_Account__c = account.C501_Merge_Target__c,
                        Merge_Action__c = account.C501_Merge_Action__c
                    ));
                }
            }

            Integer recordsUpdated = listAccountsMergeIgnore.size() + listAccountsMerge.size();
            
            if (!listAccountsMergeIgnore.isEmpty()) {
                update listAccountsMergeIgnore;
            }


            for (List<Account> accounts :listAccountsMerge.values()) {
                if (accounts.size() >= 2) {

                    // Investigation Needed: Scheduling in batch the merge throws an exception in NPSP code
/*
                    List<String> accountsMergeIds = new List<String>();
                    for (Account account :accounts) {
                        accountsMergeIds.add(String.valueOf(account.Id));
                    }

                    // Schedule Batch Job in Flex Queue (can schedule up to 100 jobs)
                    C501_MassMerge_Batch batchMerge = new C501_MassMerge_Batch();
                    batchMerge.query = 'SELECT Id FROM Account WHERE Id in (\'' + String.join(accountsMergeIds, '\',\'') + '\') ORDER BY CreatedDate DESC';
                    Database.executeBatch(batchMerge);
*/
                    c501MassMerge_SharedCode.AccountsMerge(new Account(Id = accounts[0].Id), new List<Account> { new Account( Id = accounts[1].Id) });
                }
            }

            strSaveResults = recordsUpdated + ' ' + Label.labelMassMergeSaveSuccess;
            ApexPages.addMessage(new ApexPages.message(ApexPages.Severity.CONFIRM, strSaveResults));

            // successful save, so clear out dirty list
            setAccountsIdDirty = null;

            // Refresh Account and Account Table
            ResetAccounts();

            return null;            

        } catch (Exception e) {
            strSaveResults = Label.labelMassMergeErrorOnSave;
            ApexPages.addMessages(e); 
            return null;
        }
    }

    //save the Accounts modified, and then close the page.
    global virtual PageReference SaveAndCloseAccounts() {
        SaveAccounts();
        if (ApexPages.hasMessages(ApexPages.Severity.ERROR) ||
           ApexPages.hasMessages(ApexPages.Severity.FATAL) ||
            ApexPages.hasMessages(ApexPages.Severity.WARNING)) {
                return null; // don't close window.
        }
        return Cancel();    
    }
    
    // user wants to close this page
    global virtual PageReference Cancel() {
        // figure out which object to return to.
        idRedirect = accountFilter.Id;
        
        // trigger our redirect component to redirect using javascript.
        redirect = true;
        return null;
    }
    
    // this was a testmethod which can't be compiled in this class under api 31.  
    // but because it was marked global, it could not be completely removed.
    global static void CodeCoverageTests() {}
}