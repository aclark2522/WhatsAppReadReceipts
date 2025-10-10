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
- [Apex Class: WhatsappReceiver](#-apex-class-whatsappreceiver)
  - [Description](#description-1)
  - [Global Variables and Metadata Mapping](#global-variables-and-metadata-mapping)
  - [Methods](#methods-1)
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
| `ErrorCode__c` | Typically `400`. Indicates an HTTP *Bad Request* response when the webhook fails validation. |
| `OrgWideEmail__c` | The Organization-Wide Email Address used for sending notification or debug emails. |
| `SendDebugEmail__c` | Boolean flag that determines whether debug emails should be sent after each webhook event. |
| `SuccessCode__c` | Typically `200`. Indicates a successful HTTP response. |
| `ToAddress__c` | The destination email address for debug emails. This can be any valid email address. |
| `VerifyToken__c` | The verification token configured in both Salesforce and the external PIPS Webhook. These values must match for authentication to succeed. |
| `AppSecret__c` | Secret key used to validate request authenticity via HMAC signature verification. |

---

## ⚙️ Apex Class: `WhatsAppWebhookWrapper`

### **Description**
The `WhatsAppWebhookWrapper` class defines a strict JSON schema for the incoming webhook payload.  
It ensures that all incoming data follows the expected structure, providing strongly typed access to the JSON content.

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

## 🌐 Apex Class: `WhatsappReceiver`

### **Description**
The `WhatsappReceiver` class acts as a RESTful Apex endpoint for handling WhatsApp webhook requests.  
It supports both **POST** and **GET** requests through the endpoint:


This class also leverages the `Whatsapp Webhook` custom metadata for configuration, making it flexible and easy to maintain.

---

### **Global Variables and Metadata Mapping**

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

### **Methods**

#### `setConstants()`
**Description:**  
Initializes configuration constants from the `Whatsapp Webhook` custom metadata record.  
If any global variables are `null`, they are fetched and assigned dynamically.

---

#### `handlePost()`
**Annotation:** `@HttpPost`  
**Description:**  
Handles incoming **POST** requests from the WhatsApp Webhook.  
Validates signatures, processes payloads, updates Salesforce records, and sends responses.

**Key Steps:**
1. Initialize constants using `setConstants()`.  
2. Parse the incoming request body (`jsonBody`).  
3. Validate authenticity using `verifySignature()`.  
4. If invalid, send an error response.  
5. Parse payload into a `Status` structure from `WhatsAppWebhookWrapper`.  
6. Retrieve and update the related `MessagingSession`.  
7. Optionally send debug emails using `sendJsonPackageToEmail()`.  
8. Send a success response.

---

#### `verifySignature(String payload, String signatureHeader, String appSecret)`
**Description:**  
Verifies that the webhook request came from WhatsApp using an HMAC-SHA256 signature comparison.

**Returns:**  
`true` if the signature matches; otherwise `false`.

---

#### `createExpectedSignature(String payload, String appSecret)`
**Description:**  
Generates the expected HMAC-SHA256 signature using the Salesforce `Crypto` class and encodes it as a hexadecimal string.

**Returns:**  
A `String` containing the expected signature.

---

#### `setResponse(RestResponse response, Integer statusCode, String body)`
**Description:**  
Sets the HTTP response code and body for REST responses.  
Used for both success and error handling.

---

#### `getStatus(String jsonBody)`
**Description:**  
Parses the incoming JSON payload into a `WhatsAppWebhookWrapper` object and extracts the `Status` inner class instance.

**Returns:**  
A `Status` instance containing the webhook’s message status details.

---

#### `getMessagingSession(String recipientNumber)`
**Description:**  
Retrieves the associated `MessagingSession` record based on the recipient’s phone number (`MessagingPlatformKey`).  
Links to the correct `MessagingEndUser` record.

---

#### `createDateTimeValue(String timeStamp)`
**Description:**  
Converts an epoch timestamp string (sent from the webhook) into a Salesforce `Datetime` object.

---

#### `updateMessagingSession(MessagingSession session, String status, Datetime updatedTimeStamp)`
**Description:**  
Updates the `MessagingSession` record according to the webhook event status (`sent`, `delivered`, `read`, `failed`).  
Prevents unnecessary DML by only updating when required.

---

#### `sendJsonPackageToEmail(String toEmailAddress, String orgWideEmailAddress, String body)`
**Description:**  
Sends the webhook’s JSON payload via email for debugging purposes using the `SingleEmailMessage` class.

---

#### `handleGet()`
**Annotation:** `@HttpGet`  
**Description:**  
Handles incoming **GET** requests used for webhook verification and validation.

**Behavior:**
- Retrieves constants via `setConstants()`.  
- Validates the `hub.mode` parameter to ensure it equals `subscribe`.  
- Verifies the `hub.verify_token` matches the stored `VERIFY_TOKEN`.  
- Returns the `hub.challenge` on success, or an error message otherwise.

---

## ✅ Summary

This implementation provides a **secure, configurable, and maintainable** Salesforce-based webhook for WhatsApp integrations.  
By leveraging **Custom Metadata**, it minimizes the need for redeployment when updating configuration values such as tokens, email settings, or response codes.

---

## 🔗 Related Components
- **Custom Metadata:** `Whatsapp Webhook`  
- **Apex Classes:** `WhatsAppWebhookWrapper`, `WhatsappReceiver`

---

## 🌍 Example Endpoints

| **Method** | **Endpoint** | **Purpose** |
|-------------|--------------|-------------|
| `GET` | `/services/apexrest/webhooks/whatsapp?hub.mode={{mode}}&hub.challenge={{challenge}}&hub.verify_token={{verify_token}}` | Webhook verification handshake |
| `POST` | `/services/apexrest/webhooks/whatsapp` | Message event notifications |

---

## 👨‍💻 Author
**Andrew Clark**

---
