// Shared public field allowlist. Credentials are never uploaded.
const portalTableFields = <String, List<String>>{
  "beneficiaries": ["id", "name", "baseCapital", "accountCodeRange"],
  "products_catalog": [
    "id",
    "product",
    "beneficiary",
    "accountCode",
    "profile",
    "capital",
    "email"
  ],
  "campaigns": [
    "seq",
    "date",
    "beneficiary",
    "accountCode",
    "product",
    "profile",
    "email",
    "cost",
    "clicks",
    "orderedItems",
    "orderedRevenue",
    "shippedItems",
    "returnedItems",
    "totalRevenue",
    "commission",
    "bonus",
    "isPending"
  ],
  "amazon_accounts": [
    "beneficiary",
    "code",
    "name",
    "storeId",
    "country",
    "status",
    "product1",
    "promoStatus1",
    "product2",
    "promoStatus2",
    "email"
  ],
  "historical_links": [
    "beneficiary",
    "accountName",
    "product",
    "linkType",
    "url"
  ],
  "emails": ["email", "gologin", "status", "country", "phone"],
  "gologin": [
    "email",
    "platform",
    "profile1",
    "profile2",
    "profile3",
    "country"
  ],
  "proxies": ["country", "isUsed", "portType", "protocol", "host", "port"],
  "bank_accounts": [
    "beneficiaryName",
    "bankName",
    "status",
    "amazonEmail",
    "amazonAccountName"
  ],
  "platforms": ["category", "name"],
  "promo_times": ["windowName", "syriaTime", "usTime"],
  "workflow_steps": ["stepNumber", "title", "details", "stage", "isCompleted"]
};
const portalIdentities = <String, List<String>>{
  "beneficiaries": ["id"],
  "products_catalog": ["id"],
  "campaigns": ["seq"],
  "amazon_accounts": ["code"],
  "historical_links": [
    "beneficiary",
    "accountName",
    "product",
    "linkType",
    "url"
  ],
  "emails": ["email"],
  "gologin": ["email", "platform"],
  "proxies": ["host", "port"],
  "bank_accounts": ["amazonEmail", "bankName", "beneficiaryName"],
  "platforms": ["category", "name"],
  "promo_times": ["windowName"],
  "workflow_steps": ["stepNumber"]
};
