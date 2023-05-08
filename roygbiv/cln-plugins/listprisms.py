#!/usr/bin/env python3
import json
from math import floor
from pyln.client import Plugin, RpcError, LightningRpc, Millisatoshi

path_to_rpc = "/root/.lightning/regtest/lightning-rpc"
plugin = Plugin()


@plugin.init()
def init(options, configuration, plugin, **kwargs):
    plugin.log("Plugin listprism in prism.py initialized")


@plugin.method("listprisms")
def listprisms(plugin):
    try:
        lrpc = LightningRpc(path_to_rpc)

        offers = lrpc.listoffers()["offers"]
        offer_ids = [offer["offer_id"] for offer in offers]

        datastore = lrpc.listdatastore()["datastore"]

        # extract all datastore entries with a key that matches our offer_ids
        prisms = [i for i in datastore if any(
            offer_id in i["key"] for offer_id in offer_ids)]

        prism_data_string = list(
            map(lambda prism: prism['string'].replace('\\"', '"'), prisms))

        prism_data_json = list(
            map(lambda prism: json.loads(prism), prism_data_string))

        return prism_data_json
    except RpcError as e:
        plugin.log(e)
        return e


plugin.run()
