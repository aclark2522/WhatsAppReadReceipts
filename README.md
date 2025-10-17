# 📱 WhatsApp Webhook Integration

This repository provides Apex classes and supporting **Custom Metadata** for managing WhatsApp Webhook integrations in Salesforce.  
It is designed for flexibility — administrators can control webhook behavior through metadata, reducing the need for code deployments.

---

## 🧭 Table of Contents
- [Overview](#-whatsapp-webhook-integration)
- [Custom Metadata: Whatsapp Webhook](#-custom-metadata-whatsapp-webhook)
  - [Overview](#overview)
  - [Fields](#fields)
- [Apex Class: WhatsAppWebhookWrapper](#️-apex-class-whatsappwebhookwrapper)
  - [Description](#description)
  - [Methods](#methods)
- [Apex Class: WhatsappConfig](#-apex-class-whatsappconfig)
  - [Description](#description-1)
  - [Variable to Metadata Mapping](#variable-to-metadata-mapping)
- [Apex Class: WhatsappReceiver](#-apex-class-whatsappreceiver)
  - [Description](#description-2)
  - [Methods](#methods-1)
- [Salesforce Objects](#-salesforce-objects)
  - [MessagingSession](#messagingsession)
  - [WhatsAppReceipt__c](#whatsappreceipt__c)
- [Summary](#-summary)
- [Related Components](#related-components)
- [Example Endpoints](#example-endpoints)
- [Author](#author)

---

## 🧩 Custom Metadata: `Whatsapp Webhook`

### **Overview**
The **Whatsapp Webhook** custom metadata type provides configuration values that define webhook behavior and authentication details.  
This allows you to adjust webhook settings directly from Salesforce Setup without modifying Apex code.

---

### **Fields**

| **Field Name** | **Description** |
|-----------------|-----------------|
| `AppSecret__c` | Stores the app secret defined by the external webhook for HMAC signature validation. |
| `ErrorCode__c` | Typically `400`. Standard HTTP *Bad Request* response when validation fails. |
| `OrgWideEmail__c` | The Organization-Wide Email Address used for sending notification or debug emails. |
| `SendDebugEmail__c` | Boolean flag determining whether debug emails should be sent after each webhook event. |
| `SuccessCode__c` | Typically `200`. Standard HTTP response for successful requests. |
| `ToAddress__c` | The destination email address for debug emails. Can be any valid email address. |
| `VerifyToken__c` | The verification token configured in both Salesforce and the external Webhook. These values must match for authentication to succeed. |

---

## ⚙️ Apex Class: `WhatsAppWebhookWrapper`

### **Description**
Defines a strict JSON schema for the incoming webhook payload.  
Ensures that all incoming data follows the expected structure, providing strongly typed access to the JSON content.

---

### **Methods**

#### `parse(String jsonString)`
**Description:**  
Deserializes the incoming JSON string into a `WhatsAppWebhookWrapper` object based on the defined structure.

**Parameters:**  
- `jsonString` — The raw JSON string received from the webhook.

**Returns:**  
- A `WhatsAppWebhookWrapper` instance containing the deserialized data.

---

## ⚙️ Apex Class: `WhatsappConfig`

### **Description**
The `WhatsappConfig` class loads global constants from the `Whatsapp Webhook` metadata.  
It acts as a configuration object, holding values such as tokens, email addresses, and response codes that other classes can reference.  
The class includes a constructor that sets all configuration variables when initialized.

---

### **Variable to Metadata Mapping**

| **Variable** | **Mapped Metadata Field** |
|---------------|---------------------------|
| `TO_ADDRESS` | `ToAddress__c` |
| `ORG_WIDE_EMAIL_ADDRESS` | `OrgWideEmail__c` |
| `VERIFY_TOKEN` | `VerifyToken__c` |
| `ERROR_CODE` | `ErrorCode__c` |
| `SEND_EMAIL` | `SendDebugEmail__c` |
| `SUCCESS_CODE` | `SuccessCode__c` |
| `APP_SECRET` | `AppSecret__c` |

---

## 🌐 Apex Class: `WhatsappReceiver`

### **Description**
The `WhatsappReceiver` class acts as a RESTful Apex endpoint for handling WhatsApp webhook requests.  
It supports both **POST** and **GET** requests through the endpoint:  
`/services/apexrest/webhooks/whatsapp`

This class relies on the `WhatsappConfig` object for all configuration values.

---

### **Methods**

#### `initializeConfig()`
**Description:**  
If the global `CONFIG` variable is `null`, initializes an instance of `WhatsappConfig`.

---

#### `handlePost()`
**Annotation:** `@HttpPost`  
**Description:**  
Handles incoming **POST** requests from the WhatsApp Webhook.  
Validates the payload, processes message status updates, and optionally sends debug emails.

**Key Steps:**
1. Initialize configuration using `initializeConfig()`.  
2. Extract JSON body and headers from the incoming request.  
3. Validate authenticity using `verifySignature()`.  
4. If invalid, send an error response via `setResponse()`.  
5. Parse payload into a `Status` structure from `WhatsAppWebhookWrapper`.  
6. Retrieve the associated `MessagingSession` record.  
7. Call `upsertRecord()` to update `MessagingSession` and `upsertWhatsAppReceipts()` for `WhatsAppReceipt__c`.  
8. Optionally send debug emails via `sendJsonPackageToEmail()`.  
9. Set the response using `setResponse()`.

---

#### `verifySignature(String payload, String signatureHeader, String appSecret)`
**Description:**  
Validates the incoming webhook request using an HMAC-SHA256 signature comparison.

**Returns:**  
`true` if the signature matches; otherwise `false`.

---

#### `createExpectedSignature(String payload, String appSecret)`
**Description:**  
Generates the expected HMAC-SHA256 signature using the Salesforce `Crypto` class and returns the encoded hexadecimal string.

**Returns:**  
A `String` containing the expected signature.

---

#### `setResponse(RestResponse response, Integer statusCode, String body)`
**Description:**  
Sets the HTTP response status code and body for REST responses.

**Resturns:**
An updated `RestResponse`.

---

#### `getStatus(String jsonBody)`
**Description:**  
Parses the incoming JSON payload into a `WhatsAppWebhookWrapper` object and extracts the `Status` data for further processing.

**Returns:**  
A `Status` instance containing the webhook’s message status details.

---

#### `getMessagingSession(String recipientNumber)`
**Description:**  
Retrieves the `MessagingSession` record based on the recipient’s phone number (`MessagingPlatformKey`).

**Returns:**
A `MessagingSession` record.

---

#### `createDateTimeValue(String timeStamp)`
**Description:**  
Converts an epoch timestamp string into a Salesforce `Datetime` object using January 1, 1970 as the base epoch.

**Returns:**
A `Datetime` value from the converted timeStamp.

---

#### `upsertRecord(sObject sObjectToUpdate, WhatsAppWebhookWrapper.Status statusObject, Id messagingSessionId)`
**Description:**  
Generic method for updating or inserting either `MessagingSession` or `WhatsAppReceipt__c` records depending on the `sObject` type.  
Minimizes duplicate logic between similar operations.

---

#### `upsertWhatsAppReceipts(WhatsAppWebhookWrapper.Status status, Id messagingSessionId)`
**Description:**  
Retrieves or creates a `WhatsAppReceipt__c` record associated with the message, then updates it using `upsertRecord()`.

---

#### `getWhatsAppReceipt(String whatsAppMessageId)`
**Description:**  
Queries for an existing `WhatsAppReceipt__c` record where the `Name` matches the WhatsApp Message ID.  
Returns the record or a new instance if none exists.

**Returns:**
A `WhatsAppReceipt__c` record.

---

#### `sendJsonPackageToEmail(String toEmailAddress, String orgWideEmailAddress, String body)`
**Description:**  
Sends the webhook’s JSON payload to the specified email address for debugging purposes.

---

#### `handleGet()`
**Annotation:** `@HttpGet`  
**Description:**  
Handles incoming **GET** requests for webhook verification and validation.

**Behavior:**
1. Initialize configuration via `initializeConfig()`.  
2. Validate that `hub.mode` equals `subscribe`.  
3. Compare the provided `hub.verify_token` against the stored `VERIFY_TOKEN`.  
4. If valid, return the `hub.challenge` in the response; otherwise return an error message.

---

## 🧱 Salesforce Objects

### **MessagingSession**
Holds receipt data for messages.  
Since the `ConversationEntry` object is unwriteable, `MessagingSession` is used as a custom solution to store WhatsApp message delivery statuses.  
If prior state fields are missing, the Apex logic populates them automatically.

| **Field** | **Type** | **Description** |
|------------|-----------|-----------------|
| `SentDate__c` | Datetime | The timestamp when a message was marked as “sent”. |
| `DeliveredDate__c` | Datetime | The timestamp when a message was marked as “delivered”. |
| `ReadDate__c` | Datetime | The timestamp when a message was marked as “read”. |
| `SendFailed__c` | Boolean | Indicates if message delivery failed. |

---

### **WhatsAppReceipt__c**
Stores detailed receipt data related to `MessagingSession`.  
Automatically populated by the webhook to maintain a complete record of each message’s journey.

| **Field** | **Type** | **Description** |
|------------|-----------|-----------------|
| `SentDate__c` | Datetime | The timestamp when a message was marked as “sent”. |
| `DeliveredDate__c` | Datetime | The timestamp when a message was marked as “delivered”. |
| `ReadDate__c` | Datetime | The timestamp when a message was marked as “read”. |
| `SendFailed__c` | Boolean | True if the message failed to send. |
| `MessagingSession__c` | Master-Detail | Relationship to the `MessagingSession` record. Required. |
| `Name` | String | Stores the WhatsApp Messaging Id. |

---

## ✅ Summary

This implementation provides a **secure, configurable, and maintainable** Salesforce-based webhook for WhatsApp integrations.  
By leveraging **Custom Metadata**, it enables webhook management without code redeployment while maintaining full control over authentication and debugging.

---

## 🔗 Related Components
- **Custom Metadata:** `Whatsapp Webhook`  
- **Apex Classes:** `WhatsAppWebhookWrapper`, `WhatsappConfig`, `WhatsappReceiver`  
- **Salesforce Objects:** `MessagingSession`, `WhatsAppReceipt__c`

---

## 🌍 Example Endpoints

| **Method** | **Endpoint** | **Purpose** |
|-------------|--------------|-------------|
| `GET` | `/services/apexrest/webhooks/whatsapp?hub.mode={{mode}}&hub.challenge={{challenge}}&hub.verify_token={{verify_token}}` | Webhook verification handshake |
| `POST` | `/services/apexrest/webhooks/whatsapp` | Message event notifications |

---

## 👨‍💻 Author
**Andrew Clark**