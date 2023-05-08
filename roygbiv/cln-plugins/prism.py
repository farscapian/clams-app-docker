#!/usr/bin/env python3
import json
import os
import re
from math import floor
from pyln.client import Plugin, RpcError, LightningRpc, Millisatoshi
plugin = Plugin()

pubkeyRegex = re.compile(r'^0[2-3][0-9a-fA-F]{64}$')

@plugin.init()  # Decorator to define a callback once the `init` method call has successfully completed
def init(options, configuration, plugin, **kwargs):
    plugin.log("Plugin prism.py initialized")


@plugin.method("prism")
def prism(plugin, label, members):
    try:
        # check members is of form [{"name": "alias", "destination": "pubkey", "split": number}]
        # todo: validate destination is a valid pubkey.
        validate_members(members)
        # maybe try to find a route first, and if no route can be found then
        # fail because that destination will not be payable

        lrpc = LightningRpc(os.getenv('RPC_PATH'))
        # returns object containing bolt12 offer
        offer = lrpc.offer("any", label)

        existing_offer = lrpc.listdatastore(offer["offer_id"])
        if existing_offer:
            raise Exception('Existing offer already exists')

        # todo: requesting to add an offer with exact same params will not create a new offer
        # that means we get the same offer_id, and then trying to add to the datastore will not work
        # because that key already exists
        # We need to check if an offer already exists with the same params.

        # add the prism info to datastore with the offer_id as the key
        lrpc.datastore(offer["offer_id"],
                       string=json.dumps({"label": label, "members": members}))

        return offer
    except RpcError as e:
        plugin.log(e)
        return e


plugin.add_option('destination', 'destination', 'default_destination')


@plugin.subscribe("invoice_payment")
def on_payment(plugin, invoice_payment, **kwargs):
    try:      
        # label is of form offer_id-invreq_payer_id-0, but I do not if know thats always the case
        offer_id = invoice_payment["label"].split("-")[0]

        # check offers with listoffers and confirm there is an offer with offer_id
        # if not that means our node received an invoice unrelated to the prism
        # todo: end execution if no existing bolt12 offers
        #   if there is an existing offer that check that it exists in our datastore

        plugin.log("Received invoice_payment event for label {label}, preimage {preimage},"
                " and split of {msat}".format(**invoice_payment))

        # we will check if bolt12 we stored earlier in the prism call is in the label of the bolt11 invoice
        # at that point keysend pubkeys in the members
        # todo: set this as an env var
        lrpc = LightningRpc(os.getenv('RPC_PATH'))


        # check datastore
        #   todo: check if data store is empty. When you ask for offer_id,
        #       it should be empty if no offers exist
        # should return one item matching the offer_id,
        #   todo: check that ^^
        datastore = lrpc.listdatastore(offer_id)
        data_string = datastore['datastore'][0]['string'].replace('\\"', '"')
        data_json = json.loads(data_string)

        # returns list of members or empty list
        members = data_json.get("members", [])
        # todo: check to make sure members has all expected values

        plugin.log("Members: {}".format(members))

        # determine how many satoshis to send each member
        total_split = sum(map(lambda member: member['split'], members))

        plugin.log("Invoice payment: {}".format(invoice_payment['msat']))

        for member in members:
            # iterate over each prism member and send them their split
            # msat comes as "5000msat"
            deserved_msats = floor((member['split'] / total_split) *
                                int(invoice_payment['msat'][:-4]))

            lrpc.keysend(destination=member["destination"], amount_msat=Millisatoshi(
                deserved_msats))
            # todo:
            #   check for failed payments,
            #   check for confirmation,
            #   add to an object to return payment success info

        # from the docs: "Notifications are not confirmable by definition, since they do not have a Response object to be returned. As such, the Client would not be aware of any errors (like e.g. “Invalid params”,”Internal error”)." https://lightning.readthedocs.io/PLUGINS.html#event-notifications
        # we will want to do some error handling if payments don't go through, so maybe we use a hook which can return? https://lightning.readthedocs.io/PLUGINS.html#hooks
        return invoice_payment
    except RpcError as e:
        plugin.log(e)
        return e


def validate_members(members):
    if not isinstance(members, list):
        raise ValueError("Members must be a list.")

    for member in members:
        if not isinstance(member, dict):
            raise ValueError("Each member in the list must be a dictionary.")

        required_keys = ["name", "destination", "split"]
        for key in required_keys:
            if key not in member:
                raise ValueError(f"Member must contain '{key}' key.")

        if not isinstance(member["name"], str):
            raise ValueError("Member 'name' must be a string.")

        if not isinstance(member["destination"], str):
            raise ValueError("Member 'destination' must be a valid pubkey")
        
        valid_pubkey = member["destination"] if pubkeyRegex.match(member["destination"]) else None
        if valid_pubkey is None:
            raise Exception("Invalid pubkey was provided")
        
        if not isinstance(member["split"], int):
            raise ValueError("Member 'split' must be an integer")


plugin.run()  # Run our plugin
