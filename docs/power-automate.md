# Power Automate webhook relay

Create a separate cloud flow for every BC company and for every test/live separation. The flow does no item-level parsing, HMAC checking, matching, or accounting.

## Business Central API

The custom API is create-only:

```text
POST https://api.businesscentral.dynamics.com/v2.0/{tenant-id}/{environment}/api/genesisimport/adyen/v1.0/companies({company-id})/adyenWebhookRequests
```

- Entity: `adyenWebhookRequest`
- Entity set: `adyenWebhookRequests`
- OData key: `SystemId`

Request shape:

```json
{
  "receivedAtUtc": "2026-09-03T10:00:01Z",
  "contentType": "application/json",
  "flowRunId": "0858...",
  "payload": "{\"live\":\"false\",\"notificationItems\":[]}"
}
```

`payload` is the complete Adyen Standard webhook envelope serialized as JSON text. The API exposes it as an unsized text property so the Business Central connector can submit it; BC writes the UTF-8 text directly into the raw-request BLOB before validation and storage. Do not map the payload to the internal `payloadHash` field and do not attempt to write a BC BLOB field through **Create record (V3)**. See [the JSON schema](../contracts/adyen-webhook-request-v1.schema.json).

## Flow definition

1. Create an automated cloud flow owned by a non-person service owner with a documented backup owner.
2. Add **When an HTTP request is received**. Use the complete Adyen Standard webhook envelope as the request schema; do not select or loop through `notificationItems`.
3. Add a Compose action named `Webhook payload text` for the complete payload using:

   ```text
   string(triggerBody())
   ```

4. Add the Business Central connector's **Create record (V3)** action for the custom API and select the exact target environment and company. The `payload` property in this API is a connector-compatible unsized text input, not a BC BLOB input. Map:

   | BC field | Power Automate value |
   | --- | --- |
   | `receivedAtUtc` | `utcNow()` |
   | `contentType` | `triggerOutputs()?['headers']?['Content-Type']` |
   | `flowRunId` | `workflow()?['run']?['name']` |
   | `payload` | output of `Webhook payload text` |

   The action must not contain `payloadHash` or `status` inputs. If an older action still offers those fields, delete and recreate the action after publishing the corrected extension so Power Automate refreshes the API metadata.

5. Configure retry policy on the BC action for transient connector/BC failures. The stable `flowRunId` and payload hash make those retries idempotent.
6. Add a success **Response** action that runs only after the BC create action succeeds:
   - status: `200`;
   - header `Content-Type`: `text/plain`;
   - body: `[accepted]`.
7. Add a failure **Response** action configured with run-after for failed, timed-out, or skipped BC submission:
   - status: `500` (or the organization's generic retryable failure status);
   - header `Content-Type`: `text/plain`;
   - generic body such as `request not accepted`.

Never return `[accepted]` before BC has validated and persisted the request. A BC rejection, unavailable connector, or storage failure must remain non-2xx so Adyen can retry.

## Security and operations

- Use a dedicated BC connection identity assigned `ADYEN SERVICE`; do not assign `ADYEN PROCESSOR`, finance, journal, or posting permission to it.
- Enable **Secure Inputs** and **Secure Outputs** on the trigger, payload Compose, BC action, and both responses. Disable any custom diagnostics that capture request/response bodies.
- Treat the generated HTTP trigger URL as a secret. Put it only in Adyen configuration, restrict who can view/edit/export the flow, and regenerate it immediately after suspected exposure.
- Do not place HMAC keys or report credentials in the flow. BC validates HMAC from encrypted company-scoped storage.
- Confirm the selected BC environment/company after connection changes, flow imports, or ownership transfers. Keep test and live connections and URLs separate.
- Configure failure notifications for the flow owner, but do not include payloads or secrets in notification content.
- In Adyen Customer Area, configure a Standard webhook with the flow URL, the matching test/live environment, and the same HMAC key stored in the target BC company. Test `[accepted]`, then enable the webhook.

This repository intentionally provides a flow specification rather than an environment-bound Power Platform solution export.
