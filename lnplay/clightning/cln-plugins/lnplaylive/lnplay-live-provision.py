#!/usr/bin/env python3
import json
import os
import re
import time
import subprocess
import uuid
import pytz
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
    plugin.log("lnplay.live - Provisioning plugin initialized.")

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

        dt =  datetime.strptime(expiration_date, '%Y-%m-%dT%H:%M:%SZ')
        utc_dt = pytz.utc.localize(dt)
        unix_timestamp = int(utc_dt.timestamp())

        params = [f"--invoice-label={invoice_id}", f"--expiration-date={unix_timestamp}"]

        subprocess.run([script_path] + params) #, capture_output=True, text=True, check=True)

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
