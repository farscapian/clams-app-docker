#!/usr/bin/env python3
import json
import os
import re
import time
import subprocess
import uuid
import csv
import pytz
from pyln.client import Plugin, RpcError
from datetime import datetime, timedelta

lnlive_provisioning_plugin_version = "v0.0.1"

plugin_out = "/tmp/plugin_out"
if os.path.isfile(plugin_out):
    os.remove(plugin_out)

# use this for debugging-
def printout(s):
    with open(plugin_out, "a") as output:
        output.write(s)

plugin = Plugin()

class HostMapping:
    def __init__(self, slot_name, mac_address, starting_external_port):
        self.slot_name = slot_name
        self.mac_address = mac_address
        self.starting_external_port = starting_external_port

    def __eq__(self, other):
        return self.slot_name == other.slot_name

    def __hash__(self):
        return hash(self.slot_name)

    def __repr__(self):
        return f"HostMapping(slot_name={self.slot_name}"

    def tostring(self):
        return f"slot: {self.slot_name} mac: {self.mac_address} port: {self.starting_external_port}"

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

        # if the description doesn't start with "lnplay.live", then we stop processing since the 
        # following business logic does not pertain to the transaction.
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

        connection_strings = []

        # Let's update the order detail for this, stating that we are current in the 
        # provisioning stage. We also provide 
        order_details = {
            "node_count": node_count,
            "hours": hours,
            "vm_expiration_date": expiration_date,
            "connection_strings": connection_strings
        }

        # add the order_details info to datastore with the invoice_id as the key
        plugin.rpc.datastore(key=invoice_id, string=json.dumps(order_details),mode="must-replace")

        # Log that we are starting the provisoining proces.s
        plugin.log(f"lnplay-live: invoice is associated with lnplay.live. Starting provisioning process. invoice_id: {invoice_id}")

        # we get the plugin path from the ENV /plugins for docker containers, /dev-plugins for local development
        plugin_path = os.environ.get('PLUGIN_PATH')

        # The path to the provisioning script.
        provision_script_path = f"{plugin_path}/lnplaylive/provision.sh"

        dt =  datetime.strptime(expiration_date, '%Y-%m-%dT%H:%M:%SZ')
        utc_dt = pytz.utc.localize(dt)
        unix_timestamp = int(utc_dt.timestamp())

        # so, what I need do here is determine what the next available slot is.
        # we will invoke incus project list from python to determine what slots taken,
        # then we will subtract that set from the list of total available slots.
        next_slot = None

        next_slot = get_next_available_slot(node_count)

        if next_slot is None:
            raise Exception("ERROR: the next_slot could not be determined.")

        # these are passed into the provisioning bash script.
        # read the connection details in from output file
        home_directory = os.environ.get('HOME')
        connection_info_dir = f"{home_directory}/connection_strings"
        
        # Create the directory
        if not os.path.exists(connection_info_dir):
            os.makedirs(connection_info_dir)

        connection_info_path= f"{connection_info_dir}/{invoice_id}.csv"

        params = [f"--invoice-id={invoice_id}", f"--expiration-date={unix_timestamp}", f"--node-count={node_count}", f"--slot={next_slot.slot_name}", f"--mac-addr={next_slot.mac_address}", f"--starting-ext-port={next_slot.starting_external_port}", f"--connection-strings-path={connection_info_path}" ]

        result = None

        try:
            plugin.log(f"Starting lnplay provisioning script for Order {invoice_id}")
            result = subprocess.run([provision_script_path] + params) #, capture_output=True, text=True, check=True)
            plugin.log(result.stdout)
            plugin.log(result.stderr)
            plugin.log(f"Completed provisioning script for order {invoice_id}")

        except subprocess.CalledProcessError as e:
            plugin.log(f"The bash script exited with error code: {e.returncode}")
            #plugin.log(f"Output: {e.output}")

        except Exception as e:
            plugin.log(f"An error occurred: {e}")

        if os.path.isfile(connection_info_path):
            actual_expiration_date = calculate_expiration_date(hours)

            with open(connection_info_path, 'r') as file:
                connection_strings = [line.strip() for line in file]

            # order_details response object
            order_details = {
                "node_count": node_count,
                "hours": hours,
                "lnlive_plugin_version": lnlive_provisioning_plugin_version,
                "vm_expiration_date": actual_expiration_date,
                "status": "provisioned",
                "connection_strings": connection_strings
            }

            # add the order_details info to datastore with the invoice_label as the key
            plugin.rpc.datastore(key=invoice_id, string=json.dumps(order_details),mode="must-replace")

            # Log that we are starting the provisoining proces.
            plugin.log(f"lnplay-live: Order: {invoice_id} has been provisioned.")

        else:
            raise Exception("ERROR: Something went wrong with your deployment.")

    except RpcError as e:
        printout("Payment error: {}".format(e))

def calculate_expiration_date(hours):

    # Get the current date and time
    current_datetime = datetime.now()
    time_delta = timedelta(hours=hours)
    expired_after_datetime = current_datetime + time_delta
    expiration_date_utc = expired_after_datetime.strftime('%Y-%m-%dT%H:%M:%SZ')
    return expiration_date_utc

# the objective of this function is to return the next available slot for a given product number
# if the the result is None, it should be understood as "not available".
def get_next_available_slot(node_count):

    all_slots = getAllSlots()

    if all_slots is None:
        raise Exception ("ERROR: all_slots could not be determined. Check host_mappings.csv.")

    # Extract the slots currently in use
    incus_output = subprocess.check_output(['incus', 'project', 'list', '--format', 'csv', '-q'], text=True).replace(' (current)', '').split('\n')
    filtered_strings = [s for s in incus_output if not s.startswith('default')]
    used_slots = [HostMapping(slot_name=line.split(',')[0], mac_address="", starting_external_port="") for line in filtered_strings if line != ""]

    # Select elements starting with the product number, then "slot"
    product_search_string = f"{node_count:03}slot"
    slots_matching_product = [slot for slot in all_slots if slot.slot_name.startswith(product_search_string)]
    slots_matching_product.sort(key=lambda x: x.slot_name)

    # subtract used_slots from slots_matching_product (set subtraction)
    current_available_slots_for_product = set(slots_matching_product) - set(used_slots)

    #raise Exception (f"output: {current_available_slots_for_product}")

    # grab the first available slot
    first_available_slot = None
    first_available_slot = list(current_available_slots_for_product)[0]

    if first_available_slot is None:
        raise Exception("Something went wrong.")

    return first_available_slot

def getAllSlots():

    home = os.environ["HOME"]
    host_mappings_path = f"{home}/host_mappings.csv"

    if not os.path.exists(host_mappings_path):
        print("ERROR: host_mappings_path must be set.")
        exit(1)

    host_mappings = []

    # each line is a slot. parse the csv and return HostMappings
    with open(host_mappings_path, 'r') as f:
        csvreader = csv.reader(f)

        for row in csvreader:
            slot_name = row[0]
            slot_mac_address = row[1]
            slot_starting_external_port = row[2]
            host_mapping = HostMapping(slot_name, slot_mac_address, slot_starting_external_port)
            host_mappings.append(host_mapping)

    return host_mappings

plugin.run()  # Run our plugin
