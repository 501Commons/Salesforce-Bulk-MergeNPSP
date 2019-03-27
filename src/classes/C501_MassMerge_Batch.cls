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

global class C501_MassMerge_Batch implements Database.Batchable<sObject> { 

  global String query;

  global Database.querylocator start(Database.BatchableContext BC) {
    System.debug('***** C501_MassMerge_Batch::start - query: ' + query);
    return Database.getQueryLocator(query);
  }

  global void execute(Database.BatchableContext info, List<sObject> scope) {
    
    List<Account> accountDuplicates = new List<Account>();
    Account masterAccount = null;
    for (sObject accountObject :scope) {
      if (masterAccount == null) {
        masterAccount = (Account)accountObject;
      }
      else {
        accountDuplicates.add((Account)accountObject);
      }
    }

    C501_MassMerge_SharedCode c501MassMerge_SharedCode = new C501_MassMerge_SharedCode();
    System.debug('***** C501_MassMerge_Batch::execute - masterAccount: ' + String.valueOf(masterAccount));
    System.debug('***** C501_MassMerge_Batch::execute - accountDuplicates: ' + String.valueOf(accountDuplicates));
    c501MassMerge_SharedCode.AccountsMerge(masterAccount, accountDuplicates);
  }

  global void finish(Database.BatchableContext info) {
  }
}