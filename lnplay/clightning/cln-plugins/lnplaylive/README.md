# lnplay.live-plugin

Core Lightning plugin for lnplay.live. Developed for the tabconf2023 hackathon.

When developing plugins, you can run the ./reload_dev_plugins.sh script and it'll reload the plugin you're working on.

## lnplaylive-createorder

`lnplaylive-createorder` is called by the front end web app to get an invoice for a product. Required parameters are node count (see product definition), number of hours the environment should be active (`hours`) (minimum 3). Any future product customizations REQUIRE an update to the backend plugin to support associated business logic.

### example

```bash
lightning-cli -k lnplaylive-createorder node_count=8 hours=48
{
   "node_count": 8,
   "hours": 48,
   "expires_after": "2023-09-06T23:34:31Z",
   "bolt11_invoice_id": "8d33e17d-0385-46c0-82f2-16c989f7b112",
   "bolt11_invoice": "lnbcrt768u1pj0v6v8sp59u36emrmm4g8yspg6a584yagwwyuzmjjgvfsefruan457xrl9mmspp53ms372dg6lnxyr0jal2hla8ljwhcrck3lej9gngerjjxpts6ehqqdpcd3h8qmrp0yhxc6tkv5sz6gpcyphx7er9wvsxvmmjyq6rsgrgda6hyuewxqzfvcqp29qxpqysgqc8tw7v0ddjn9kctg9xsx9925yl2fnwzstrylle8yhpq3fccwjlxz57rf6tyx627f3u54pkec4em6vnjekf4ayngcr6uylt24xlstkesp4407tz"
}
```

## lnplaylive-invoicestatus

The `lnplaylive-invoicestatus` rpc method returns the status of a BOLT11 invoice. The two required parameters are `payment_type=bolt11` (bolt12 not yet supported), and `invoice_id`, which is [invoice label](https://docs.corelightning.org/reference/lightning-invoice) in the CLN database and is provided in the `lnplaylive-createorder` return value.

Before the invoice is paid, you'll see this:

```bash
lightning-cli -k lnplaylive-invoicestatus payment_type=bolt11 invoice_id=lnplaylive-8d33e17d-0385-46c0-82f2-16c989f7b112
{
   "invoice_id": "8d33e17d-0385-46c0-82f2-16c989f7b112",
   "payment_type": "bolt11",
   "invoice_status": "unpaid",
   "deployment_details": "not_deployed"
}
```

When the invoice gets paid, the output will change:

```bash
lightning-cli -k lnplaylive-invoicestatus payment_type=bolt11 invoice_id=2b5549a9-807b-4a07-b873-22ef2db4f53d
{
   "invoice_id": "2b5549a9-807b-4a07-b873-22ef2db4f53d",
   "payment_type": "bolt11",
   "invoice_status": "paid",
   "deployment_details": {
      "lnlive_plugin_version": "v0.0.1",
      "vm_expiration_date": "2023-09-07T00:07:24Z",
      "status": "starting_deployment"
   }
}
```

The `vm_expiration_date` is the actual expiration date of the VM. Directly after that date/time (within ten minutes after) the VM will be culled.

## TODO

The above output indicates that the VM instance is being provisioned. Run the command again, and you should see something like this:

```bash
lightning-cli -k lnplaylive-invoicestatus payment_type=bolt11 invoice_id=2b5549a9-807b-4a07-b873-22ef2db4f53d
{
   "invoice_id": "2b5549a9-807b-4a07-b873-22ef2db4f53d",
   "payment_type": "bolt11",
   "invoice_status": "paid",
   "deployment_details": {
      "lnlive_plugin_version": "v0.0.1",
      "vm_expiration_date": "2023-09-07T00:07:24Z",
      "status": "provisioned"
      "connection_strings": [
         "http://app.clams.tech:80/connect?address=0334c635a61adfc7ea53a0c20a808002c732da05506e248b5582238d0e9c43bebb@127.0.0.1:6001&type=direct&value=ws:&rune=gJIrc38yC277E_bwolwBcXhI6YEX7LVv0YjxIkkswME9NSZtZXRob2QvbGlzdGRhdGFzdG9yZSZtZXRob2RebGlzdHxtZXRob2ReZ2V0fG1ldGhvZD13YWl0YW55aW52b2ljZXxtZXRob2Q9d2FpdGludm9pY2V8bWV0aG9kPWxpc3RwYXlzfG1ldGhvZD13YWl0YW55aW52b2ljZXxtZXRob2Q9d2FpdGludm9pY2V8bWV0aG9kPWludm9pY2V8bWV0aG9kXm9mZmVyfG1ldGhvZD1wYXl8bWV0aG9kPWZldGNoaW52b2ljZXxtZXRob2Q9Y3JlYXRlaW52b2ljZXxtZXRob2R-YmtwciZyYXRlPTYw",
         "http://app.clams.tech:80/connect?address=03433876611974a0114790570072960f42ec3853d104f7d6be6a1dc256e9a21fab@127.0.0.1:6002&type=direct&value=ws:&rune=gQ_ER59JiMEAze11IXNE6pYJOCAdM3D6gmEj1Q8neaA9NSZtZXRob2QvbGlzdGRhdGFzdG9yZSZtZXRob2RebGlzdHxtZXRob2ReZ2V0fG1ldGhvZD13YWl0YW55aW52b2ljZXxtZXRob2Q9d2FpdGludm9pY2V8bWV0aG9kPWxpc3RwYXlzfG1ldGhvZD13YWl0YW55aW52b2ljZXxtZXRob2Q9d2FpdGludm9pY2V8bWV0aG9kPWludm9pY2V8bWV0aG9kXm9mZmVyfG1ldGhvZD1wYXl8bWV0aG9kPWZldGNoaW52b2ljZXxtZXRob2Q9Y3JlYXRlaW52b2ljZXxtZXRob2R-YmtwcnxtZXRob2Q9bGlzdHByaXNtc3xtZXRob2Q9Y3JlYXRlcHJpc20mcmF0ZT02MA==",
         "http://app.clams.tech:80/connect?address=02bd23289c67af513073022b10fefab925b3d75f796cdcae11feb3a4a32c622cf3@127.0.0.1:6003&type=direct&value=ws:&rune=uGEqAvbAEh2PXEwQCyokG2o3XWPxtm290kqShxxNUNE9NSZtZXRob2QvbGlzdGRhdGFzdG9yZSZtZXRob2RebGlzdHxtZXRob2ReZ2V0fG1ldGhvZD13YWl0YW55aW52b2ljZXxtZXRob2Q9d2FpdGludm9pY2V8bWV0aG9kPWxpc3RwYXlzfG1ldGhvZD13YWl0YW55aW52b2ljZXxtZXRob2Q9d2FpdGludm9pY2V8bWV0aG9kPWludm9pY2V8bWV0aG9kXm9mZmVyfG1ldGhvZD1wYXl8bWV0aG9kPWZldGNoaW52b2ljZXxtZXRob2Q9Y3JlYXRlaW52b2ljZXxtZXRob2R-YmtwciZyYXRlPTYw"
      ]
   }
}
```