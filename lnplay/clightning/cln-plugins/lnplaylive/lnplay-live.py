#!/usr/bin/env python3
import json
import os
import re
import time
import subprocess
import uuid
from pyln.client import Plugin, RpcError
from datetime import datetime, timedelta

lnlive_plugin_version = "v0.0.1"

plugin_out = "/tmp/plugin_out"
if os.path.isfile(plugin_out):
    os.remove(plugin_out)

# use this for debugging-
def printout(s):
    with open(plugin_out, "a") as output:
        output.write(s)

plugin = Plugin()

@plugin.init()  # Decorator to define a callback once the `init` method call has successfully completed
def init(options, configuration, plugin, **kwargs):
    plugin.log("lnplay.live - plugin initialized")


@plugin.method("lnplaylive-createorder")
def lnplaylive_createorder(plugin, node_count, hours):
    '''Returns a BOLT11 invoice for the given node count and time.'''
    try:
        # The rate is 200 sats per node-hour.
        rate_to_charge = 200000

        # ensure node_count is an int
        if not isinstance(node_count, int):
            raise Exception("ERROR: node_count MUST be a positive integer.")

        # Check if the node_count is evenly divisible by 8
        if node_count % 8 != 0:
            print(f"{node_count} is not evenly divisible by 8.")
            raise Exception("ERROR: node_count MUST be evenly divisible by 8.")

        # ensure hours is an int
        if not isinstance(hours, int):
            raise Exception("ERROR: hours MUST be a positive integer.")

        # ensure 'hours' is within acceptable limits
        if hours < 3:
            raise Exception("ERROR: The minimum hours you can set is 3.")
        elif hours > 504:
            raise Exception("ERROR: The maximum hours you can set is 504.")

        # calcuate the amount to charge in the invoice (msats) (msats per node hour)
        amount_to_charge = rate_to_charge * node_count * hours

        # we just need a guid to for cross referencing invoices. Order details for paid invoices are also stored in the
        # database under the label/guid bolt11_guid_str.
        bolt11_guid = uuid.uuid4()
        bolt11_guid_str = str(bolt11_guid)
        
        # generate the invoice
        description = f"lnplay.live - {node_count} nodes for {hours} hours."
        bolt11_invoice = plugin.rpc.invoice(amount_to_charge, bolt11_guid_str, description, 300)

        # get an expiration datetime estimate for the vm.
        estimated_expiration_date = calculate_expiration_date(hours)

        # build an object to send back to the caller.
        createorder_response = {
            "node_count": node_count,
            "hours": hours,
            "expires_after": estimated_expiration_date,
            "bolt11_invoice_id": bolt11_guid_str,
            "bolt11_invoice": bolt11_invoice["bolt11"]
        }

        # everything in this object gets stored in the database and gets built upon by later scripts.
        createorder_dbdetails = {
            "node_count": node_count,
            "hours": hours
        }

        # let's store the order details in the datastore under the bolt11_guid_str
        # later execution logic can use this data in downstream calculations, and it's inconvenient 
        # to embed the order details in the actual invoice.
        plugin.rpc.datastore(key=bolt11_guid_str, string=json.dumps(createorder_dbdetails),mode="must-create")

        # now return the order details to the caller.
        json_data = json.dumps(createorder_response)
        json_dict = json.loads(json_data)
        return json_dict

    except RpcError as e:
        plugin.log(e)
        return e

# todo over time convert this to the wait rpc semantics.
@plugin.method("lnplaylive-invoicestatus")
def lnplaylive_invoicestatus(plugin, payment_type, invoice_id):
    '''Retuns the status of an invoice.'''

    try:
        valid_payment_types = ["bolt11", "bolt12"]

        if payment_type not in valid_payment_types:
            raise Exception("Invalid payment type. Should be 'bolt11' or 'bolt12'.")

        # get info about the invoice and return it to the caller.
        invoices = plugin.rpc.listinvoices(invoice_id)

        matching_invoice = None
        for invoice in invoices["invoices"]:
            if invoice.get("label") == invoice_id:
              matching_invoice = invoice
              break

        if matching_invoice is None:
            raise Exception("BOLT11 invoice not found. Wrong invoice_id?")

        invoice_status = matching_invoice["status"]

        deployment_details = None
        matching_record = None

        if invoice_status == "paid":
            # the deployment details I need to pull from the datastore.
            # since the invoice is paid, we will need to consult the object in the data store.
            deployment_details = plugin.rpc.listdatastore(invoice_id)

            for record in deployment_details["datastore"]:
                if record.get("key")[0] == invoice_id:
                    matching_record = record
                    break

        deployment_details_json = None
        if matching_record is not None:
            deployment_details = matching_record["string"]
            deployment_details_json = json.loads(str(deployment_details))

        dbdetails_records = plugin.rpc.listdatastore(invoice_id)
        dbdetails = None
        for record in dbdetails_records["datastore"]:
            if record.get("key")[0] == invoice_id:
                dbdetails = record
                break

        node_count = None
        hours = None
        dbdetails_json = None
        if dbdetails is not None:
            dbdetails = dbdetails["string"]
            dbdetails_json = json.loads(str(dbdetails))

            if dbdetails_json is not None:
                node_count = dbdetails_json["node_count"]
                hours = dbdetails_json["hours"]

        invoicestatus_response = {
            "invoice_id": invoice_id,
            "node_count": node_count,
            "hours": hours,
            "payment_type": payment_type,
            "invoice_status": invoice_status,
            "deployment_details": deployment_details_json
        }

        json_data = json.dumps(invoicestatus_response)
        json_dict = json.loads(json_data)

        return json_dict

    except RpcError as e:
        plugin.log(e)
        return e

@plugin.subscribe("invoice_payment")
def on_payment(plugin, invoice_payment, **kwargs):
    try:
        invoice_id = invoice_payment["label"]

        # let's get the invoice details.
        invoices = plugin.rpc.listinvoices(invoice_id)

        matching_invoice = None
        for invoice in invoices["invoices"]:
            if invoice.get("label") == invoice_id:
              matching_invoice = invoice
              break

        if matching_invoice is None:
            raise Exception("ERROR: Invoice not found. Wrong invoice_id?")

        # let's grab the invoice description.
        invoice_description = matching_invoice["description"]
        if not invoice_description.startswith("lnplay.live"):
            return

        # we pull the order details from the database. We'll be replacing that record here soonish.
        order_details_records = plugin.rpc.listdatastore(invoice_id)
        order_details = None
        for record in order_details_records["datastore"]:
            if record.get("key")[0] == invoice_id:
                order_details = record
                break

            if order_details is None:
                raise Exception("Could not locate the order details.")

        node_count = 0
        hours = 0
        if order_details is not None:
            dbdetails = order_details["string"]
            dbdetails_json = json.loads(str(dbdetails))

            if dbdetails_json is not None:
                node_count = dbdetails_json["node_count"]
                hours = dbdetails_json["hours"]

        if hours == 0:
            raise Exception("Could not extract number_of_hours from invoice description.")


        if node_count == 0:
            raise Exception("Could not extract node_count from invoice description.")

        expiration_date = calculate_expiration_date(hours)

        connection_strings = None

        # order_details resonse
        order_details = {
            "node_count": node_count,
            "hours": hours,
            "lnlive_plugin_version": lnlive_plugin_version,
            "vm_expiration_date": expiration_date,
            "status": "deploying",
            "connection_strings": connection_strings
        }

        # add the order_details info to datastore with the invoice_label as the key
        plugin.rpc.datastore(key=invoice_id, string=json.dumps(order_details),mode="must-replace")

        # This is where we can start integregrating sovereign stack, calling sovereign stack scripts
        # to bring up a new VM on a remote LXD endpoint. Basically we bring it up,

        # Log that we are starting the provisoining proces.s
        plugin.log(f"lnplay-live: invoice is associated with lnplay.live. Starting provisioning process. invoice_id: {invoice_id}")


        # The path to the Bash script
        script_path = '/dev-plugins/lnplaylive/provision_lxd.sh'

        #subprocess.run([script_path]) #, capture_output=True, text=True, check=True)

        time.sleep(3)

        connection_strings = ["https://app.clams.tech/connect?address=02d657b3506b4f011cef3da12f2468b1dc5ade93241da2f713dc60aeabcf9e010e@lnplay.dev:6001&type=direct&value=wss:&rune=ZZQA8QjGEP9xpeqFF_F9jFlxUm-EZyjD9cSMPVF0ADc9Mg==", "https://app.clams.tech/connect?address=026176428622df17bfea3cc3405fc7516ae3a03daa27a99978cdc544b3bc737990@lnplay.dev:6002&type=direct&value=wss:&rune=VB0htCDqFjZXaxSsqQ7rrMPTg71T8QGWczNWZQrYd7M9Mg==", "https://app.clams.tech/connect?address=02fed5f686dffcac71431fc8b904379f2932581e2f3b7bffc632520bee3d300547@lnplay.dev:6003&type=direct&value=wss:&rune=5Yw_s8AAA0DvALvQk524kcNEBg8HhYJw6_SmS16hnPY9MQ==", "https://app.clams.tech/connect?address=02b7bbe03a26b6c5259078fba9858bdaafe295c079301129fa175823ca0d15b6b7@lnplay.dev:6004&type=direct&value=wss:&rune=4FCdsNq73prQRz-RA7SBjzN5R9NqDDYmLQDEYHiYPys9MQ==", "https://app.clams.tech/connect?address=03a3d29eb2ee71ddbd65cc1bbeafa9dff3800a8f2fc590ac7aa0d4f4ff3c126fd7@lnplay.dev:6005&type=direct&value=wss:&rune=UbWNJbjJbWHO7CakY07EVGdQgJXS7jtSC-7a9lNHz1I9MQ==", "https://app.clams.tech/connect?address=036281353c9c6ea1b1cd28c027645dfa5a9cbe616e85aaf991df8b7155edf51a1e@lnplay.dev:6006&type=direct&value=wss:&rune=imY0Rh2pCpL8_e_JdBmYzcaohV16QUKDsjcjgy3PlS49MQ==", "https://app.clams.tech/connect?address=02adbcfed6d5931dda2d61b9de0313cb6cfd0492d0f582e00fdd91e20c1b996df6@lnplay.dev:6007&type=direct&value=wss:&rune=URf3ldN92wye5kq8WMsxGCMJEKRttiOXKC-ndtyUJBs9MQ==", "https://app.clams.tech/connect?address=0205234927872808975cdda0ba16baef5b7c733fb5e570e698c58c3f74e3ca0cb2@lnplay.dev:6008&type=direct&value=wss:&rune=l3hP7JN1sGfoEq-ISf3gSpwRXMAtxOowPxQhzpb3eIQ9MQ=="]

        # order_details resonse
        order_details = {
            "node_count": node_count,
            "hours": hours,
            "lnlive_plugin_version": lnlive_plugin_version,
            "vm_expiration_date": expiration_date,
            "status": "provisioned",
            "connection_strings": connection_strings
        }

         # Log that we are starting the provisoining proces.s
        plugin.log(f"lnplay-live: Order: {invoice_id} has been provisioned.")

        # add the order_details info to datastore with the invoice_label as the key
        plugin.rpc.datastore(key=invoice_id, string=json.dumps(order_details),mode="must-replace")

    except RpcError as e:
        printout("Payment error: {}".format(e))

def calculate_expiration_date(hours):

    # Get the current date and time
    current_datetime = datetime.now()
    time_delta = timedelta(hours=hours)
    expired_after_datetime = current_datetime + time_delta
    expiration_date_utc = expired_after_datetime.strftime('%Y-%m-%dT%H:%M:%SZ')
    return expiration_date_utc

plugin.run()  # Run our plugin
