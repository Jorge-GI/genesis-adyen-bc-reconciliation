page 72022 "Adyen Reconciliation RC"
{
    PageType = RoleCenter;
    Caption = 'Adyen Reconciliation';

    layout
    {
        area(RoleCenter)
        {
            part(Headline; "Headline RC Accountant")
            {
                ApplicationArea = Basic, Suite;
            }
            part(AdyenActivities; "Adyen Activities")
            {
                AccessByPermission = tabledata "Adyen Role Center Cue" = I;
                ApplicationArea = All;
            }
            part(AdyenQuickAccess; "Adyen Role Center Actions")
            {
                AccessByPermission = tabledata "Adyen Role Center Cue" = I;
                ApplicationArea = All;
            }
            part(AccountantActivities; "Accountant Activities")
            {
                ApplicationArea = Basic, Suite;
            }
            part(MyAccounts; "My Accounts")
            {
                ApplicationArea = Basic, Suite;
            }
            part(AdyenJobQueueTasks; "Adyen Job Queue Activities")
            {
                AccessByPermission = tabledata "Job Queue Entry" = R;
                ApplicationArea = Suite;
            }
            part(ReportInbox; "Report Inbox Part")
            {
                AccessByPermission = tabledata "Report Inbox" = IMD;
                ApplicationArea = Basic, Suite;
            }
            systempart(MyNotes; MyNotes)
            {
                ApplicationArea = Basic, Suite;
            }
        }
    }

    actions
    {
        area(Embedding)
        {
            action(PaymentExceptions)
            {
                AccessByPermission = tabledata "Imported Adyen Payment" = R;
                ApplicationArea = All;
                Caption = 'Payment Exceptions';
                RunObject = Page "Adyen Payment Exceptions";
                RunPageView = sorting("Created At UTC", "Merchant Account", "PSP Reference") order(descending);
                ToolTip = 'Review Adyen payments that are unmatched, errored, require reversal, or contain conflicting data.';
            }
            action(ImportedPayments)
            {
                AccessByPermission = tabledata "Imported Adyen Payment" = R;
                ApplicationArea = All;
                Caption = 'Imported Adyen Payments';
                RunObject = Page "Imported Adyen Payments";
                RunPageView = sorting("Created At UTC", "Merchant Account", "PSP Reference") order(descending);
                ToolTip = 'View imported Adyen payments, their matching results, report state, and posting outcome.';
            }
            action(PostedAdyenPayments)
            {
                AccessByPermission = tabledata "Imported Adyen Payment" = R;
                ApplicationArea = All;
                Caption = 'Posted Adyen Payments';
                RunObject = Page "Posted Adyen Payments";
                ToolTip = 'Review Adyen payments that have a linked posted customer ledger entry and open all related posting entries.';
            }
            action(ReportRuns)
            {
                AccessByPermission = tabledata "Adyen Report Run" = R;
                ApplicationArea = All;
                Caption = 'Adyen Report Runs';
                RunObject = Page "Adyen Report Runs";
                ToolTip = 'Monitor Adyen report downloads, loading, reconciliation, row counts, and errors.';
            }
            action(ChartOfAccounts)
            {
                AccessByPermission = tabledata "G/L Account" = R;
                ApplicationArea = Basic, Suite;
                Caption = 'Chart of Accounts';
                RunObject = Page "Chart of Accounts";
                ToolTip = 'View or organize the general ledger accounts that store the company''s financial data.';
            }
            action(Customers)
            {
                AccessByPermission = tabledata Customer = R;
                ApplicationArea = Basic, Suite;
                Caption = 'Customers';
                RunObject = Page "Customer List";
                ToolTip = 'View or edit customers and open their related receivables information.';
            }
            action(Vendors)
            {
                AccessByPermission = tabledata Vendor = R;
                ApplicationArea = Basic, Suite;
                Caption = 'Vendors';
                RunObject = Page "Vendor List";
                ToolTip = 'View or edit vendors and open their related payables information.';
            }
            action(BankAccounts)
            {
                AccessByPermission = tabledata "Bank Account" = R;
                ApplicationArea = Basic, Suite;
                Caption = 'Bank Accounts';
                RunObject = Page "Bank Account List";
                ToolTip = 'View bank accounts, balances, posting settings, and bank-file configuration.';
            }
        }
        area(Sections)
        {
            group(AdyenReconciliation)
            {
                Caption = 'Adyen Reconciliation';
                ToolTip = 'Review, monitor, and configure the Adyen reconciliation workflow.';

                action(AdyenPaymentExceptions)
                {
                    AccessByPermission = tabledata "Imported Adyen Payment" = R;
                    ApplicationArea = All;
                    Caption = 'Payment Exceptions';
                    RunObject = Page "Adyen Payment Exceptions";
                    RunPageView = sorting("Created At UTC", "Merchant Account", "PSP Reference") order(descending);
                    ToolTip = 'Review Adyen payments that are unmatched, errored, require reversal, or contain conflicting data.';
                }
                action(AdyenImportedPayments)
                {
                    AccessByPermission = tabledata "Imported Adyen Payment" = R;
                    ApplicationArea = All;
                    Caption = 'Imported Adyen Payments';
                    RunObject = Page "Imported Adyen Payments";
                    RunPageView = sorting("Created At UTC", "Merchant Account", "PSP Reference") order(descending);
                    ToolTip = 'View every imported Adyen payment and its matching, report, and posting state.';
                }
                action(AdyenPostedPayments)
                {
                    AccessByPermission = tabledata "Imported Adyen Payment" = R;
                    ApplicationArea = All;
                    Caption = 'Posted Adyen Payments';
                    RunObject = Page "Posted Adyen Payments";
                    ToolTip = 'Review Adyen payments that have a linked posted customer ledger entry and open all related posting entries.';
                }
                action(AdyenWebhookRequests)
                {
                    AccessByPermission = tabledata "Adyen Webhook Request" = R;
                    ApplicationArea = All;
                    Caption = 'Webhook Requests';
                    RunObject = Page "Adyen Webhook Requests";
                    ToolTip = 'Monitor accepted webhook envelopes, normalization status, retries, and retained payloads.';
                }
                action(AdyenEventEntries)
                {
                    AccessByPermission = tabledata "Adyen Event Entry" = R;
                    ApplicationArea = All;
                    Caption = 'Event Entries';
                    RunObject = Page "Adyen Event Entries";
                    ToolTip = 'Monitor normalized webhook and report events, processing decisions, and errors.';
                }
                action(AdyenReportRunsSection)
                {
                    AccessByPermission = tabledata "Adyen Report Run" = R;
                    ApplicationArea = All;
                    Caption = 'Report Runs';
                    RunObject = Page "Adyen Report Runs";
                    ToolTip = 'Monitor Adyen report downloads, loading, reconciliation, row counts, and errors.';
                }
                action(AdyenSetup)
                {
                    AccessByPermission = tabledata "Adyen Setup" = M;
                    ApplicationArea = All;
                    Caption = 'Adyen Setup';
                    RunObject = Page "Adyen Setup";
                    ToolTip = 'Configure integration credentials, processing limits, report access, retention, and the background queue.';
                }
                action(AdyenMerchants)
                {
                    AccessByPermission = tabledata "Adyen Merchant" = I;
                    ApplicationArea = All;
                    Caption = 'Merchants';
                    RunObject = Page "Adyen Merchants";
                    ToolTip = 'Configure Adyen merchant accounts, posting journals, clearing accounts, and automatic posting.';
                }
                action(AdyenPaymentMethodPolicies)
                {
                    AccessByPermission = tabledata "Adyen Merchant Method Policy" = I;
                    ApplicationArea = All;
                    Caption = 'Payment Method Policies';
                    RunObject = Page "Adyen Payment Method Policies";
                    ToolTip = 'Configure which payment methods are eligible for automatic matching and posting for each merchant.';
                }
                action(AdyenPaymentJournal)
                {
                    AccessByPermission = tabledata "Gen. Journal Line" = RIMD;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Payment Journal';
                    RunObject = Page "Payment Journal";
                    ToolTip = 'Open payment journals to review and post manual Adyen payment lines.';
                }
                action(AdyenJobQueue)
                {
                    AccessByPermission = tabledata "Job Queue Entry" = R;
                    ApplicationArea = Suite;
                    Caption = 'Adyen Job Queue';
                    RunObject = Page "Job Queue Entries";
                    RunPageView = where("Object Type to Run" = const(Codeunit), "Object ID to Run" = const(72044));
                    ToolTip = 'View the background Job Queue entry that runs the Adyen dispatcher.';
                }
            }
            group(Receivables)
            {
                Caption = 'Receivables';
                ToolTip = 'Manage customers, sales documents, and incoming payments.';

                action(ReceivablesCustomers)
                {
                    AccessByPermission = tabledata Customer = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Customers';
                    RunObject = Page "Customer List";
                    ToolTip = 'View or edit customers and open their related receivables information.';
                }
                action(SalesInvoices)
                {
                    AccessByPermission = tabledata "Sales Header" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Sales Invoices';
                    RunObject = Page "Sales Invoice List";
                    ToolTip = 'View and prepare sales invoices before they are posted.';
                }
                action(SalesCreditMemos)
                {
                    AccessByPermission = tabledata "Sales Header" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Sales Credit Memos';
                    RunObject = Page "Sales Credit Memos";
                    ToolTip = 'View and prepare sales credit memos before they are posted.';
                }
                action(CashReceiptJournalSection)
                {
                    AccessByPermission = tabledata "Gen. Journal Line" = RIMD;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Cash Receipt Journal';
                    RunObject = Page "Cash Receipt Journal";
                    ToolTip = 'Record customer receipts and apply them to open customer entries.';
                }
            }
            group(Payables)
            {
                Caption = 'Payables';
                ToolTip = 'Manage vendors, purchase documents, and outgoing payments.';

                action(PayablesVendors)
                {
                    AccessByPermission = tabledata Vendor = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Vendors';
                    RunObject = Page "Vendor List";
                    ToolTip = 'View or edit vendors and open their related payables information.';
                }
                action(PurchaseInvoices)
                {
                    AccessByPermission = tabledata "Purchase Header" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Purchase Invoices';
                    RunObject = Page "Purchase Invoices";
                    ToolTip = 'View and prepare purchase invoices before they are posted.';
                }
                action(PurchaseCreditMemos)
                {
                    AccessByPermission = tabledata "Purchase Header" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Purchase Credit Memos';
                    RunObject = Page "Purchase Credit Memos";
                    ToolTip = 'View and prepare purchase credit memos before they are posted.';
                }
                action(PaymentJournalSection)
                {
                    AccessByPermission = tabledata "Gen. Journal Line" = RIMD;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Payment Journal';
                    RunObject = Page "Payment Journal";
                    ToolTip = 'Prepare and post payments to vendors.';
                }
            }
            group(CashManagement)
            {
                Caption = 'Cash Management';
                ToolTip = 'Manage bank accounts, ledger entries, and bank reconciliations.';

                action(CashManagementBankAccounts)
                {
                    AccessByPermission = tabledata "Bank Account" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Bank Accounts';
                    RunObject = Page "Bank Account List";
                    ToolTip = 'View bank accounts, balances, posting settings, and bank-file configuration.';
                }
                action(BankAccountLedgerEntries)
                {
                    AccessByPermission = tabledata "Bank Account Ledger Entry" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Bank Account Ledger Entries';
                    RunObject = Page "Bank Account Ledger Entries";
                    ToolTip = 'View posted transactions and balances for bank accounts.';
                }
                action(BankAccountReconciliations)
                {
                    AccessByPermission = tabledata "Bank Acc. Reconciliation" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Bank Account Reconciliations';
                    RunObject = Page "Bank Acc. Reconciliation List";
                    ToolTip = 'View current bank account reconciliations and open one for matching and posting.';
                }
                action(PaymentReconciliationJournals)
                {
                    AccessByPermission = tabledata "Bank Acc. Reconciliation" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Payment Reconciliation Journals';
                    RunObject = Page "Pmt. Reconciliation Journals";
                    ToolTip = 'Reconcile imported bank transactions with open customer and vendor entries.';
                }
            }
            group(GeneralLedger)
            {
                Caption = 'General Ledger';
                ToolTip = 'Manage general ledger accounts, journals, dimensions, currencies, and financial statements.';

                action(GLChartOfAccounts)
                {
                    AccessByPermission = tabledata "G/L Account" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Chart of Accounts';
                    RunObject = Page "Chart of Accounts";
                    ToolTip = 'View or organize the general ledger accounts that store the company''s financial data.';
                }
                action(GeneralJournals)
                {
                    AccessByPermission = tabledata "Gen. Journal Batch" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'General Journals';
                    RunObject = Page "General Journal Batches";
                    RunPageView = where("Template Type" = const(General), Recurring = const(false));
                    ToolTip = 'Open nonrecurring general journal batches for direct financial postings.';
                }
                action(RecurringGeneralJournals)
                {
                    AccessByPermission = tabledata "Gen. Journal Batch" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Recurring General Journals';
                    RunObject = Page "General Journal Batches";
                    RunPageView = where("Template Type" = const(General), Recurring = const(true));
                    ToolTip = 'Open recurring general journal batches for transactions that repeat on a schedule.';
                }
                action(Currencies)
                {
                    AccessByPermission = tabledata Currency = R;
                    ApplicationArea = Suite;
                    Caption = 'Currencies';
                    RunObject = Page Currencies;
                    ToolTip = 'View currencies and maintain exchange rates.';
                }
                action(Dimensions)
                {
                    AccessByPermission = tabledata Dimension = R;
                    ApplicationArea = Dimensions;
                    Caption = 'Dimensions';
                    RunObject = Page Dimensions;
                    ToolTip = 'View or edit dimensions used to categorize and analyze financial transactions.';
                }
                action(FinancialReports)
                {
                    AccessByPermission = tabledata "Financial Report" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Financial Reports';
                    RunObject = Page "Financial Reports";
                    ToolTip = 'Configure and run financial statements based on general ledger accounts.';
                }
            }
            group(History)
            {
                Caption = 'History';
                ToolTip = 'Review posted documents, ledger entries, and posting registers.';

                action(GeneralLedgerEntries)
                {
                    AccessByPermission = tabledata "G/L Entry" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'General Ledger Entries';
                    RunObject = Page "General Ledger Entries";
                    ToolTip = 'View the history of transactions posted to general ledger accounts.';
                }
                action(GLRegisters)
                {
                    AccessByPermission = tabledata "G/L Register" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'G/L Registers';
                    RunObject = Page "G/L Registers";
                    ToolTip = 'View posting registers and the ranges of entries created by each posting operation.';
                }
                action(CustomerLedgerEntries)
                {
                    AccessByPermission = tabledata "Cust. Ledger Entry" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Customer Ledger Entries';
                    RunObject = Page "Customer Ledger Entries";
                    ToolTip = 'View posted customer invoices, payments, credit memos, and remaining amounts.';
                }
                action(VendorLedgerEntries)
                {
                    AccessByPermission = tabledata "Vendor Ledger Entry" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Vendor Ledger Entries';
                    RunObject = Page "Vendor Ledger Entries";
                    ToolTip = 'View posted vendor invoices, payments, credit memos, and remaining amounts.';
                }
                action(HistoryBankAccountLedgerEntries)
                {
                    AccessByPermission = tabledata "Bank Account Ledger Entry" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Bank Account Ledger Entries';
                    RunObject = Page "Bank Account Ledger Entries";
                    ToolTip = 'View posted transactions and balances for bank accounts.';
                }
                action(HistoryPostedAdyenPayments)
                {
                    AccessByPermission = tabledata "Imported Adyen Payment" = R;
                    ApplicationArea = All;
                    Caption = 'Posted Adyen Payments';
                    RunObject = Page "Posted Adyen Payments";
                    ToolTip = 'Review Adyen payments that have a linked posted customer ledger entry and open all related posting entries.';
                }
                action(PostedSalesInvoices)
                {
                    AccessByPermission = tabledata "Sales Invoice Header" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Posted Sales Invoices';
                    RunObject = Page "Posted Sales Invoices";
                    ToolTip = 'View posted sales invoices.';
                }
                action(PostedSalesCreditMemos)
                {
                    AccessByPermission = tabledata "Sales Cr.Memo Header" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Posted Sales Credit Memos';
                    RunObject = Page "Posted Sales Credit Memos";
                    ToolTip = 'View posted sales credit memos.';
                }
                action(PostedPurchaseInvoices)
                {
                    AccessByPermission = tabledata "Purch. Inv. Header" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Posted Purchase Invoices';
                    RunObject = Page "Posted Purchase Invoices";
                    ToolTip = 'View posted purchase invoices.';
                }
                action(PostedPurchaseCreditMemos)
                {
                    AccessByPermission = tabledata "Purch. Cr. Memo Hdr." = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Posted Purchase Credit Memos';
                    RunObject = Page "Posted Purchase Credit Memos";
                    ToolTip = 'View posted purchase credit memos.';
                }
                action(FindEntries)
                {
                    AccessByPermission = tabledata "G/L Entry" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Find Entries';
                    RunObject = Page Navigate;
                    ToolTip = 'Find posted entries and documents from document numbers, posting dates, or related business contacts.';
                }
            }
            group(Setup)
            {
                Caption = 'Setup';
                ToolTip = 'Maintain core financial posting, payment, numbering, and journal configuration.';

                action(GeneralLedgerSetup)
                {
                    AccessByPermission = tabledata "General Ledger Setup" = M;
                    ApplicationArea = Basic, Suite;
                    Caption = 'General Ledger Setup';
                    RunObject = Page "General Ledger Setup";
                    ToolTip = 'Configure general ledger defaults, local currency, posting periods, and related finance settings.';
                }
                action(GeneralPostingSetup)
                {
                    AccessByPermission = tabledata "General Posting Setup" = M;
                    ApplicationArea = Basic, Suite;
                    Caption = 'General Posting Setup';
                    RunObject = Page "General Posting Setup";
                    ToolTip = 'Map business and product posting groups to sales, purchase, inventory, and cost accounts.';
                }
                action(CustomerPostingGroups)
                {
                    AccessByPermission = tabledata "Customer Posting Group" = M;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Customer Posting Groups';
                    RunObject = Page "Customer Posting Groups";
                    ToolTip = 'Configure receivables, payment discount, interest, and related customer posting accounts.';
                }
                action(VendorPostingGroups)
                {
                    AccessByPermission = tabledata "Vendor Posting Group" = M;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Vendor Posting Groups';
                    RunObject = Page "Vendor Posting Groups";
                    ToolTip = 'Configure payables, payment discount, interest, and related vendor posting accounts.';
                }
                action(BankAccountPostingGroups)
                {
                    AccessByPermission = tabledata "Bank Account Posting Group" = M;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Bank Account Posting Groups';
                    RunObject = Page "Bank Account Posting Groups";
                    ToolTip = 'Configure the general ledger account used for each bank account posting group.';
                }
                action(PaymentMethods)
                {
                    AccessByPermission = tabledata "Payment Method" = M;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Payment Methods';
                    RunObject = Page "Payment Methods";
                    ToolTip = 'Configure the payment methods used on customers, vendors, and documents.';
                }
                action(PaymentTerms)
                {
                    AccessByPermission = tabledata "Payment Terms" = M;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Payment Terms';
                    RunObject = Page "Payment Terms";
                    ToolTip = 'Configure due-date and payment-discount calculations for customers and vendors.';
                }
                action(NumberSeries)
                {
                    AccessByPermission = tabledata "No. Series" = M;
                    ApplicationArea = Basic, Suite;
                    Caption = 'No. Series';
                    RunObject = Page "No. Series";
                    ToolTip = 'Configure number series used to identify master data and transactions.';
                }
                action(GeneralJournalTemplates)
                {
                    AccessByPermission = tabledata "Gen. Journal Template" = M;
                    ApplicationArea = Basic, Suite;
                    Caption = 'General Journal Templates';
                    RunObject = Page "General Journal Templates";
                    ToolTip = 'Configure journal templates, types, number series, and source codes.';
                }
            }
        }
        area(Creation)
        {
            action(CreateSalesInvoice)
            {
                AccessByPermission = tabledata "Sales Header" = IMD;
                ApplicationArea = Basic, Suite;
                Caption = 'Sales Invoice';
                RunObject = Page "Sales Invoice";
                RunPageMode = Create;
                ToolTip = 'Create a sales invoice for goods or services supplied to a customer.';
            }
            action(CreateSalesCreditMemo)
            {
                AccessByPermission = tabledata "Sales Header" = IMD;
                ApplicationArea = Basic, Suite;
                Caption = 'Sales Credit Memo';
                RunObject = Page "Sales Credit Memo";
                RunPageMode = Create;
                ToolTip = 'Create a sales credit memo to correct or reverse a posted sales invoice.';
            }
            action(CreatePurchaseInvoice)
            {
                AccessByPermission = tabledata "Purchase Header" = IMD;
                ApplicationArea = Basic, Suite;
                Caption = 'Purchase Invoice';
                RunObject = Page "Purchase Invoice";
                RunPageMode = Create;
                ToolTip = 'Create a purchase invoice for goods or services received from a vendor.';
            }
            action(CreatePurchaseCreditMemo)
            {
                AccessByPermission = tabledata "Purchase Header" = IMD;
                ApplicationArea = Basic, Suite;
                Caption = 'Purchase Credit Memo';
                RunObject = Page "Purchase Credit Memo";
                RunPageMode = Create;
                ToolTip = 'Create a purchase credit memo to correct or reverse a posted purchase invoice.';
            }
            action(CreateGeneralJournal)
            {
                AccessByPermission = tabledata "Gen. Journal Line" = IMD;
                ApplicationArea = Basic, Suite;
                Caption = 'General Journal';
                RunObject = Page "General Journal";
                ToolTip = 'Prepare a journal entry for posting directly to general ledger and related accounts.';
            }
            action(CreatePaymentJournal)
            {
                AccessByPermission = tabledata "Gen. Journal Line" = IMD;
                ApplicationArea = Basic, Suite;
                Caption = 'Payment Journal';
                RunObject = Page "Payment Journal";
                ToolTip = 'Prepare a payment journal for outgoing payments.';
            }
        }
        area(Processing)
        {
            group(PaymentProcessing)
            {
                Caption = 'Payments and Reconciliation';

                action(CashReceiptJournal)
                {
                    AccessByPermission = tabledata "Gen. Journal Line" = RIMD;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Cash Receipt Journal';
                    Image = CashReceiptJournal;
                    RunObject = Page "Cash Receipt Journal";
                    ToolTip = 'Record customer receipts and apply them to open customer entries.';
                }
                action(PaymentJournal)
                {
                    AccessByPermission = tabledata "Gen. Journal Line" = RIMD;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Payment Journal';
                    Image = PaymentJournal;
                    RunObject = Page "Payment Journal";
                    ToolTip = 'Prepare and post payments to vendors.';
                }
                action(BankAccountReconciliation)
                {
                    AccessByPermission = tabledata "Bank Acc. Reconciliation" = RIMD;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Bank Account Reconciliation';
                    Image = BankAccountRec;
                    RunObject = Page "Bank Acc. Reconciliation";
                    ToolTip = 'Match bank statement lines with bank account ledger entries and post the reconciliation.';
                }
                action(PaymentReconciliation)
                {
                    AccessByPermission = tabledata "Bank Acc. Reconciliation" = RIMD;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Payment Reconciliation Journals';
                    Image = ApplyEntries;
                    RunObject = Page "Pmt. Reconciliation Journals";
                    RunPageMode = View;
                    ToolTip = 'Reconcile imported bank transactions with open customer and vendor entries.';
                }
            }
            group(AdyenProcessing)
            {
                Caption = 'Adyen';

                action(ProcessPaymentExceptions)
                {
                    AccessByPermission = tabledata "Imported Adyen Payment" = R;
                    ApplicationArea = All;
                    Caption = 'Payment Exceptions';
                    Image = Warning;
                    RunObject = Page "Adyen Payment Exceptions";
                    RunPageView = sorting("Created At UTC", "Merchant Account", "PSP Reference") order(descending);
                    ToolTip = 'Review Adyen payments that are unmatched, errored, require reversal, or contain conflicting data.';
                }
                action(ProcessImportedPayments)
                {
                    AccessByPermission = tabledata "Imported Adyen Payment" = R;
                    ApplicationArea = All;
                    Caption = 'Imported Adyen Payments';
                    Image = Payment;
                    RunObject = Page "Imported Adyen Payments";
                    RunPageView = sorting("Created At UTC", "Merchant Account", "PSP Reference") order(descending);
                    ToolTip = 'View every imported Adyen payment and its matching, report, and posting state.';
                }
                action(ProcessWebhookRequests)
                {
                    AccessByPermission = tabledata "Adyen Webhook Request" = R;
                    ApplicationArea = All;
                    Caption = 'Webhook Requests';
                    Image = Entries;
                    RunObject = Page "Adyen Webhook Requests";
                    ToolTip = 'Monitor accepted webhook envelopes, normalization status, retries, and retained payloads.';
                }
                action(ProcessEventEntries)
                {
                    AccessByPermission = tabledata "Adyen Event Entry" = R;
                    ApplicationArea = All;
                    Caption = 'Event Entries';
                    Image = EntriesList;
                    RunObject = Page "Adyen Event Entries";
                    ToolTip = 'Monitor normalized webhook and report events, processing decisions, and errors.';
                }
                action(ProcessReportRuns)
                {
                    AccessByPermission = tabledata "Adyen Report Run" = R;
                    ApplicationArea = All;
                    Caption = 'Report Runs';
                    Image = Report;
                    RunObject = Page "Adyen Report Runs";
                    ToolTip = 'Monitor Adyen report downloads, loading, reconciliation, row counts, and errors.';
                }
                action(ProcessFindEntries)
                {
                    AccessByPermission = tabledata "G/L Entry" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Find Entries';
                    Image = Navigate;
                    RunObject = Page Navigate;
                    ToolTip = 'Find posted entries and documents from document numbers, posting dates, or related business contacts.';
                }
            }
        }
        area(Reporting)
        {
            group(CoreFinanceReports)
            {
                Caption = 'Core Finance Reports';

                action(ReportingFinancialReports)
                {
                    AccessByPermission = tabledata "Financial Report" = R;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Financial Reports';
                    RunObject = Page "Financial Reports";
                    ToolTip = 'Configure and run financial statements based on general ledger accounts.';
                }
                action(DetailTrialBalance)
                {
                    AccessByPermission = report "Detail Trial Balance" = X;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Detail Trial Balance';
                    RunObject = Report "Detail Trial Balance";
                    ToolTip = 'Run a detailed trial balance showing general ledger entries and balances for selected accounts and periods.';
                }
                action(TrialBalanceByPeriod)
                {
                    AccessByPermission = report "Trial Balance by Period" = X;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Trial Balance by Period';
                    RunObject = Report "Trial Balance by Period";
                    ToolTip = 'Show opening balances, period movements, and closing balances by general ledger account.';
                }
                action(BankAccountDetailTrialBalance)
                {
                    AccessByPermission = report "Bank Acc. - Detail Trial Bal." = X;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Bank Account Detail Trial Balance';
                    RunObject = Report "Bank Acc. - Detail Trial Bal.";
                    ToolTip = 'Run a detailed trial balance for selected bank accounts and periods.';
                }
                action(CustomerTrialBalance)
                {
                    AccessByPermission = report "Customer - Trial Balance" = X;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Customer Trial Balance';
                    RunObject = Report "Customer - Trial Balance";
                    ToolTip = 'Run a trial balance of customer transactions and balances for a selected period.';
                }
                action(VendorTrialBalance)
                {
                    AccessByPermission = report "Vendor - Trial Balance" = X;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Vendor Trial Balance';
                    RunObject = Report "Vendor - Trial Balance";
                    ToolTip = 'Run a trial balance of vendor transactions and balances for a selected period.';
                }
                action(CustomerVendorReconciliation)
                {
                    AccessByPermission = report "Reconcile Cust. and Vend. Accs" = X;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Customer/Vendor Reconciliation';
                    RunObject = Report "Reconcile Cust. and Vend. Accs";
                    ToolTip = 'Compare customer and vendor ledger balances with their general ledger control accounts.';
                }
                action(CustomerStatement)
                {
                    AccessByPermission = report "Customer Statement" = X;
                    ApplicationArea = Basic, Suite;
                    Caption = 'Customer Statement';
                    RunObject = Report "Customer Statement";
                    ToolTip = 'Prepare a statement of customer transactions and outstanding balances.';
                }
            }
        }
    }

}
