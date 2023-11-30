#!/usr/bin/env python3
import json
import os
import re
import time
import subprocess
import uuid
from pyln.client import Plugin, RpcError
from datetime import datetime, timedelta

lnlive_plugin_api_version = "v0.0.1"

plugin_out = "/tmp/plugin_out"
if os.path.isfile(plugin_out):
    os.remove(plugin_out)

# use this for debugging-
def printout(s):
    with open(plugin_out, "a") as output:
        output.write(s)

plugin = Plugin()

@plugin.init()  # this runs when the plugin starts.
def init(options, configuration, plugin, **kwargs):

    # get the plugin path from the os env
    plugin_path = os.environ.get('PLUGIN_PATH')

    script_path = f"{plugin_path}/lnplaylive/incus_client_init.sh"
    subprocess.run([script_path]) #, capture_output=True, text=True, check=True)
    plugin.log("lnplay.live - rpc plugin initialized")


@plugin.method("lnplaylive-createorder")
def lnplaylive_createorder(plugin, node_count, hours):
    '''Returns a BOLT11 invoice for the given node count and time.'''
    try:
        # The rate is 200 sats per node-hour.
        #rate_to_charge = 200000

        # 1 sats per node-hour
        rate_to_charge = 1000

        # ensure node_count is an int
        if not isinstance(node_count, int):
            raise Exception("ERROR: node_count MUST be a positive integer.")

        # ensure the node_count is set according to the product definition.
        if not node_count in (8, 16, 24, 32):
            raise Exception("ERROR: lnplay.live only supports node counts of 8, 16, 24, or 32.")

        # ensure hours is an int
        if not isinstance(hours, int):
            raise Exception("ERROR: hours MUST be a positive integer.")

        # ensure 'hours' is within acceptable limits
        if hours < 1:
            raise Exception("ERROR: The minimum hours you can set is 1.")
        elif hours > 504:
            raise Exception("ERROR: The maximum hours you can set is 504.")

        # calcuate the amount to charge in the invoice (msats) (msats per node hour)
        amount_to_charge = rate_to_charge * node_count * hours

        # we just need a guid to for cross referencing invoices. Order details for paid invoices are also stored in the
        # database under the label/guid bolt11_guid_str.
        bolt11_guid = uuid.uuid4()
        bolt11_guid_str = f"lnplaylive-{str(bolt11_guid)}"
        
        # generate the invoice
        description = f"lnplay.live - {node_count} nodes for {hours} hours."
        bolt11_invoice = plugin.rpc.invoice(amount_to_charge, bolt11_guid_str, description, 300)

        # get an expiration datetime estimate for the vm.
        estimated_expiration_date = calculate_expiration_date(hours)

        # build an object to send back to the caller.
        createorder_response = {
            "node_count": node_count,
            "hours": hours,
            "lnlive_plugin_api_version": lnlive_plugin_api_version,
            "expiration_date": estimated_expiration_date,
            "bolt11_invoice_id": bolt11_guid_str,
            "bolt11_invoice": bolt11_invoice["bolt11"],
        }

        # everything in this object gets stored in the database and gets built upon by later scripts.
        createorder_dbdetails = {
            "node_count": node_count,
            "hours": hours,
            "expiration_date": estimated_expiration_date,
            "lnlive_plugin_api_version": lnlive_plugin_api_version,
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

        deployment_details_json = ""
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

def calculate_expiration_date(hours):

    # Get the current date and time
    current_datetime = datetime.now()
    time_delta = timedelta(hours=hours)
    expired_after_datetime = current_datetime + time_delta
    expiration_date_utc = expired_after_datetime.strftime('%Y-%m-%dT%H:%M:%SZ')
    return expiration_date_utc

plugin.run()  # Run our plugin
